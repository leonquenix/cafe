--!strict
-- Pedidos, pagamento, ciclo de dias, loja, cardápio e maestria.
-- O servidor é a autoridade de receita, tempo, dinheiro e de quem aparece no dia.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Characters = require(ReplicatedStorage.Shared.Characters)
local Net = require(ReplicatedStorage.Shared.Net)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Barista = require(script.Parent.Barista)
local DataService = require(script.Parent.DataService)

local Kind = Characters.Kind

type PlanEntry = { kind: number, regular: number, status: string }
type Order = {
	orderId: number,
	customerId: number,
	drink: string,
	modifier: string,
	pastry: string,
	assignedAt: number,
	kind: number,
	pastryQuality: number, -- Catalog.PastryQuality; -1 = o pop-up do forno ainda está aberto
}
type Delivered = {
	drink: string,
	tier: number,
	earned: number,
	kind: number,
	wrong: boolean,
	problem: string,
	pastry: string, -- "" = pedido sem doce
	pastryOk: boolean, -- doce entregue ok/perfeito (cru, queimado ou não feito = false)
}

type Session = {
	dayActive: boolean,
	resolved: number,
	earned: number,
	tips: number,
	xp: number,
	delivered: { Delivered },
	plan: { PlanEntry },
	order: Order?,
	wrong: number,
}

local sessions: { [Player]: Session } = {}
local nextOrderId = 0
local rng = Random.new()

local CafeService = {}

local function newSession(): Session
	return {
		dayActive = false,
		resolved = 0,
		earned = 0,
		tips = 0,
		xp = 0,
		delivered = {},
		plan = {},
		order = nil,
		wrong = 0,
	}
end

local function cozy(data: DataService.Data): number
	local total = 0
	for id in data.Decor do
		local d = Catalog.Decor[id]
		if d then
			total += d.Cozy
		end
	end
	return total
end

local function menuOf(data: DataService.Data): { string }
	return Progression.effectiveMenu(data.Menu, data.Level)
end

local function sendState(player: Player)
	local data = DataService.get(player)
	local session = sessions[player]
	if not data or not session then
		return
	end

	local upgrades = {}
	for _, id in Catalog.UpgradeOrder do
		table.insert(upgrades, { id = id, level = data.Upgrades[id] or 0 })
	end
	local owned = {}
	for id in data.Pastries do
		table.insert(owned, id)
	end
	for id in data.Decor do
		table.insert(owned, id)
	end
	local stats = {}
	for drink, count in data.DrinkStats do
		table.insert(stats, { drink = drink, count = math.clamp(count, 0, 65535) })
	end
	local mastered = {}
	for drink in data.Mastered do
		table.insert(mastered, drink)
	end

	Net.PlayerState.sendTo({
		money = math.clamp(data.Money, 0, 4294967295),
		level = math.clamp(data.Level, 1, 255),
		xp = data.XP,
		day = math.clamp(data.Day, 1, 65535),
		served = session.resolved,
		perDay = #session.plan > 0 and #session.plan or Progression.OrdersPerDay,
		dayActive = session.dayActive,
		cozy = math.clamp(cozy(data), 0, 255),
		upgrades = upgrades,
		owned = owned,
		menu = menuOf(data),
		stats = stats,
		mastered = mastered,
	}, player)
end

------------------------------------------------------------------ plano do dia

local function makePlan(data: DataService.Data): { PlanEntry }
	local n = Progression.OrdersPerDay
	local plan: { PlanEntry } = {}
	for i = 1, n do
		plan[i] = { kind = Kind.Normal, regular = 0, status = "pending" }
	end
	local free = {}
	for i = 2, n do
		table.insert(free, i)
	end
	local function takeSlot(): number?
		if #free == 0 then
			return nil
		end
		return table.remove(free, rng:NextInteger(1, #free))
	end

	-- clientes de visual fixo (até 2 por dia); quem tem pedido fixo só aparece
	-- depois que você já sabe fazer a bebida dele
	local eligible = {}
	for _, r in Characters.Regulars do
		if not r.Order or Recipes.Drinks[r.Order].Level <= data.Level then
			table.insert(eligible, r)
		end
	end
	for _ = 1, math.min(2, #eligible) do
		local r = table.remove(eligible, rng:NextInteger(1, #eligible)) :: Characters.Regular
		local slot = takeSlot()
		if slot then
			plan[slot].kind = Kind.Regular
			plan[slot].regular = r.Id
		end
	end

	if data.Level >= 3 and rng:NextNumber() < 0.6 then
		local slot = takeSlot()
		if slot then
			plan[slot].kind = Kind.Critic
		end
	end

	if data.Level >= 2 then
		for _, slot in table.clone(free) do
			if rng:NextNumber() < 0.12 then
				plan[slot].kind = Kind.Kid
			end
		end
	end
	return plan
end

local function chooseDrink(data: DataService.Data, entry: PlanEntry): string
	local menu = menuOf(data)
	local regular = if entry.kind == Kind.Regular then Characters.Regulars[entry.regular] else nil
	if regular and regular.Order then
		return regular.Order
	elseif entry.kind == Kind.Kid then
		local choc = {}
		for _, id in Progression.drinksForLevel(data.Level) do
			if Recipes.Drinks[id].Ingredients.Chocolate and not Recipes.Drinks[id].Ingredients.Coffee then
				table.insert(choc, id)
			end
		end
		return choc[rng:NextInteger(1, #choc)]
	elseif entry.kind == Kind.Critic then
		-- o crítico prefere o que tem de mais caro no cardápio
		local sorted = table.clone(menu)
		table.sort(sorted, function(a, b)
			return Recipes.Drinks[a].Price > Recipes.Drinks[b].Price
		end)
		local top = math.max(1, math.ceil(#sorted / 2))
		return sorted[rng:NextInteger(1, top)]
	end
	return Progression.randomFrom(menu, data.Level, rng)
end

local function chooseModifier(data: DataService.Data, entry: PlanEntry, drink: string): string
	local regular = if entry.kind == Kind.Regular then Characters.Regulars[entry.regular] else nil
	if regular and regular.Order then
		return "" -- pedido fixo: sempre do mesmo jeito
	end
	if entry.kind == Kind.Kid then
		return ""
	end
	local chance = if entry.kind == Kind.Critic then 0.5 else 0.25
	if rng:NextNumber() > chance then
		return ""
	end
	local options = {}
	for _, id in Recipes.ModifierOrder do
		if Recipes.Modifiers[id].Level <= data.Level and Recipes.modifierApplies(drink, id) then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return ""
	end
	return options[rng:NextInteger(1, #options)]
end

local function choosePastry(data: DataService.Data, entry: PlanEntry): string
	local regular = if entry.kind == Kind.Regular then Characters.Regulars[entry.regular] else nil
	if regular and regular.NoPastry then
		return ""
	end
	local owned = {}
	for _, id in Catalog.PastryOrder do
		if data.Pastries[id] then
			table.insert(owned, id)
		end
	end
	if #owned == 0 then
		return ""
	end
	local chance = if entry.kind == Kind.Kid then 0.5 else 0.3
	if rng:NextNumber() > chance then
		return ""
	end
	return owned[rng:NextInteger(1, #owned)]
end

------------------------------------------------------------------ fim do dia

local function endDay(player: Player, session: Session, data: DataService.Data)
	session.dayActive = false
	session.order = nil

	local gained = session.xp + Progression.DayBonusXp
	local levelBefore, xpBefore = data.Level, data.XP
	data.Level, data.XP = Progression.applyXp(data.Level, data.XP, gained)
	local day = data.Day
	data.Day += 1

	-- receitas novas entram no cardápio automaticamente
	if #data.Menu > 0 then
		local newDrinks = Progression.unlocksBetween(levelBefore, data.Level)
		for _, id in newDrinks do
			if not table.find(data.Menu, id) then
				table.insert(data.Menu, id)
			end
		end
	end

	Net.DayEnded.sendTo({
		day = day,
		earned = session.earned,
		tips = session.tips,
		wrong = session.wrong,
		orders = session.delivered,
		xpGained = gained,
		levelBefore = levelBefore,
		xpBefore = xpBefore,
		levelAfter = data.Level,
		xpAfter = data.XP,
	}, player)
	sendState(player)
end

local function resolve(player: Player, session: Session, data: DataService.Data)
	session.resolved += 1
	if session.resolved >= #session.plan then
		endDay(player, session, data)
	else
		sendState(player)
	end
end

------------------------------------------------------------------ handlers

local function onStartDay(action: number, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return
	end
	if action == 0 or session.dayActive then
		if session.dayActive then
			Net.DayPlan.sendTo(session.plan, player)
		end
		sendState(player)
		return
	end
	Barista.setWalking(player, false)
	local fresh = newSession()
	fresh.dayActive = true
	fresh.plan = makePlan(data)
	sessions[player] = fresh
	Net.DayPlan.sendTo(fresh.plan, player)
	sendState(player)
end

local function onRequestOrder(index: number, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data or not session.dayActive then
		return
	end
	local entry = session.plan[index]
	if not entry or entry.status ~= "pending" then
		return
	end
	local order = session.order
	if not order or order.customerId ~= index then
		nextOrderId = nextOrderId % 65535 + 1
		local drink = chooseDrink(data, entry)
		order = {
			orderId = nextOrderId,
			customerId = index,
			drink = drink,
			modifier = chooseModifier(data, entry, drink),
			pastry = "",
			assignedAt = os.clock(),
			kind = entry.kind,
			pastryQuality = 0,
		}
		order.pastry = choosePastry(data, entry)
		order.pastryQuality = if order.pastry ~= "" then -1 else 0
		session.order = order
	end
	local o = order :: Order
	Net.OrderAssigned.sendTo({
		orderId = o.orderId,
		customerId = o.customerId,
		drink = o.drink,
		modifier = o.modifier,
		pastry = o.pastry,
	}, player)
end

-- Como o doce saiu: "" (ok/perfeito ou sem doce no pedido) | "NoPastry" | "RawPastry" | "BurntPastry"
local function pastryProblem(order: Order): string
	if order.pastry == "" then
		return ""
	end
	local q = order.pastryQuality
	if q == Catalog.PastryQuality.Raw then
		return "RawPastry"
	elseif q == Catalog.PastryQuality.Burnt then
		return "BurntPastry"
	elseif q == Catalog.PastryQuality.Ok or q == Catalog.PastryQuality.Perfect then
		return ""
	end
	return "NoPastry"
end

-- Paga uma entrega correta e registra no dia/perfil. Retorna (ganho, gorjeta, tier, problema do doce).
local function grant(session: Session, data: DataService.Data, order: Order, mult: number): (number, number, number, string)
	local d = Recipes.Drinks[order.drink]
	local modifier = if order.modifier ~= "" then order.modifier else nil
	local tier = Progression.tier(mult)
	local problem = pastryProblem(order)

	local value = d.Price * mult
	if modifier then
		value *= 1 + Recipes.Modifiers[modifier].Bonus
	end
	if order.pastry ~= "" then
		value += Catalog.pastryValue(order.pastry, math.max(order.pastryQuality, 0))
	end
	-- aconchego (decoração) e maestria da bebida
	value *= 1 + cozy(data) * Catalog.CozyBonus
	if data.Mastered[order.drink] then
		value *= 1 + Recipes.MasteryBonus
	end

	local xp = Progression.orderXp(tier)
	if order.kind == Kind.Kid then
		value *= 0.6
		xp *= 2
	elseif order.kind == Kind.Critic then
		value *= if tier == 3 then 2 else 1
		xp = math.floor(xp * 1.5)
	end
	local earned = math.max(1, math.floor(value + 0.5))

	local tip = 0
	local jar = data.Upgrades.TipJar or 0
	if tier == 3 and jar > 0 and problem == "" then
		tip = math.floor(d.Price * 0.12 * jar) + jar
	end

	session.order = nil
	local entry = session.plan[order.customerId]
	if entry then
		entry.status = "served"
	end
	session.earned += earned + tip
	session.tips += tip
	session.xp += xp
	table.insert(session.delivered, {
		drink = order.drink,
		tier = tier,
		earned = earned,
		kind = order.kind,
		wrong = false,
		problem = problem,
		pastry = order.pastry,
		pastryOk = order.pastry ~= "" and problem == "",
	})

	data.Money += earned + tip
	data.TotalEarned += earned + tip
	data.DrinksServed += 1
	data.DrinkStats[order.drink] = (data.DrinkStats[order.drink] or 0) + 1

	return earned, tip, tier, problem
end

local function onSubmit(payload: any, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	local order = session and session.order
	if not session or not data or not order or order.orderId ~= payload.orderId then
		return
	end
	local modifier = if order.modifier ~= "" then order.modifier else nil
	local problem = if #payload.ingredients > Recipes.MaxPortions
		then "Ingredients"
		else Recipes.orderProblem(order.drink, modifier, payload.ingredients, payload.mixed, payload.stirred)

	if problem ~= "" then
		-- bebida errada: o cliente leva mesmo assim e não paga a bebida;
		-- se o pedido tinha doce, o doce é pago normalmente (cru/queimado continua pagando menos)
		session.order = nil
		local entry = session.plan[order.customerId]
		if entry then
			entry.status = "wrong"
		end
		local earned = 0
		if order.pastry ~= "" then
			local value = Catalog.pastryValue(order.pastry, math.max(order.pastryQuality, 0))
			value *= 1 + cozy(data) * Catalog.CozyBonus
			if order.kind == Kind.Kid then
				value *= 0.6
			end
			earned = if value > 0 then math.max(1, math.floor(value + 0.5)) else 0
		end
		session.wrong += 1
		session.xp += 2
		session.earned += earned
		data.Money += earned
		data.TotalEarned += earned
		local q = order.pastryQuality
		table.insert(session.delivered, {
			drink = order.drink,
			tier = 0,
			earned = earned,
			kind = order.kind,
			wrong = true,
			problem = problem,
			pastry = order.pastry,
			pastryOk = q == Catalog.PastryQuality.Ok or q == Catalog.PastryQuality.Perfect,
		})
		Net.OrderResult.sendTo({ orderId = payload.orderId, success = false, problem = problem, earned = earned, tip = 0, tier = 0 }, player)
		resolve(player, session, data)
		return
	end

	local elapsed = os.clock() - order.assignedAt - Progression.GraceTime
	local earned, tip, tier, pastry = grant(session, data, order, Progression.multiplier(elapsed))

	Net.OrderResult.sendTo({ orderId = payload.orderId, success = true, problem = pastry, earned = earned, tip = tip, tier = tier }, player)
	resolve(player, session, data)
end

-- Pop-up do forno fechou: guarda como o doce saiu e o relógio da bebida começa agora
local function onPastryDone(payload: any, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local order = session and session.order
	if not order or order.orderId ~= payload.orderId or order.pastry == "" or order.pastryQuality ~= -1 then
		return
	end
	order.pastryQuality = math.clamp(payload.quality, 0, Catalog.PastryQuality.Burnt)
	order.assignedAt = os.clock()
end

local function onPastryRetry(orderId: number, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	local order = session and session.order
	if not session or not data or not order or order.orderId ~= orderId or order.pastry == "" or order.pastryQuality ~= -1 then
		return
	end
	local cost = Catalog.retryCost(order.pastry)
	local ok = data.Money >= cost
	if ok then
		data.Money -= cost
		session.earned = math.max(0, session.earned - cost)
	end
	Net.PastryRetryResult.sendTo({ orderId = orderId, ok = ok }, player)
	sendState(player)
end

local function onClaimMastery(drink: string, player: Player?)
	if not player then
		return
	end
	local data = DataService.get(player)
	if not data or not Recipes.Drinks[drink] or data.Mastered[drink] then
		return
	end
	if (data.DrinkStats[drink] or 0) >= Recipes.masteryTarget(drink) then
		local reward = Recipes.masteryReward(drink)
		data.Mastered[drink] = true
		data.Money += reward
		data.TotalEarned += reward
	end
	sendState(player)
end

local function onBuy(id: string, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data or session.dayActive then
		return
	end

	local cost: number? = nil
	local apply: (() -> ())? = nil
	local upgrade = Catalog.Upgrades[id]
	local pastry = Catalog.Pastries[id]
	local decor = Catalog.Decor[id]
	if upgrade then
		local lvl = data.Upgrades[id] or 0
		cost = if upgrade.Level <= data.Level then upgrade.Costs[lvl + 1] else nil
		apply = function()
			data.Upgrades[id] = lvl + 1
		end
	elseif pastry and not data.Pastries[id] and pastry.Level <= data.Level then
		cost = pastry.Cost
		apply = function()
			data.Pastries[id] = true
		end
	elseif decor and not data.Decor[id] and decor.Level <= data.Level then
		cost = decor.Cost
		apply = function()
			data.Decor[id] = true
		end
	end

	if cost and apply and data.Money >= cost then
		data.Money -= cost
		apply()
	end
	sendState(player)
end

local function onSetMenu(list: { string }, player: Player?)
	if not player then
		return
	end
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data or session.dayActive then
		return
	end
	local clean = {}
	for _, id in list do
		local d = Recipes.Drinks[id]
		if d and d.Level <= data.Level and not table.find(clean, id) then
			table.insert(clean, id)
		end
	end
	if #clean >= math.min(Progression.MinMenu, #Progression.drinksForLevel(data.Level)) then
		data.Menu = clean
	end
	sendState(player)
end

------------------------------------------------------------------ API para comandos (Cmdr)

function CafeService.refresh(player: Player)
	sendState(player)
end

-- Encerra o dia agora: todo cliente que faltava conta como entregue certinho ("Bom trabalho!")
function CafeService.forceEndDay(player: Player): (boolean, string)
	local session = sessions[player]
	local data = DataService.get(player)
	if not session or not data then
		return false, "Dados ainda não carregados"
	end
	if not session.dayActive then
		return false, "Nenhum dia em andamento"
	end
	local count = 0
	for index, entry in session.plan do
		if entry.status == "pending" then
			local current = session.order
			local order: Order
			if current and current.customerId == index then
				order = current
			else
				local drink = chooseDrink(data, entry)
				order = {
					orderId = 0,
					customerId = index,
					drink = drink,
					modifier = "",
					pastry = "",
					assignedAt = os.clock(),
					kind = entry.kind,
					pastryQuality = 0,
				}
			end
			if order.pastryQuality == -1 then
				order.pastryQuality = Catalog.PastryQuality.Ok
			end
			grant(session, data, order, 1)
			session.resolved += 1
			count += 1
		end
	end
	endDay(player, session, data)
	return true, `Dia encerrado ({count} pedidos concluídos automaticamente)`
end

-- Depois de apagar os dados: sessão zerada
function CafeService.resetSession(player: Player)
	sessions[player] = newSession()
end

function CafeService.start()
	DataService.onLoaded(function(player)
		sessions[player] = newSession()
		sendState(player)
	end)

	Net.StartDay.listen(onStartDay)
	Net.RequestOrder.listen(onRequestOrder)
	Net.ClaimMastery.listen(onClaimMastery)
	Net.WalkMode.listen(function(on: boolean, player: Player?)
		local session = player and sessions[player]
		if not player or not session then
			return
		end
		-- durante o expediente o barista fica no balcão
		Barista.setWalking(player, on and not session.dayActive)
	end)
	Net.SubmitDrink.listen(onSubmit)
	Net.PastryDone.listen(onPastryDone)
	Net.PastryRetry.listen(onPastryRetry)
	Net.Buy.listen(onBuy)
	Net.SetMenu.listen(onSetMenu)

	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
end

return CafeService
