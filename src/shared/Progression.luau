--!strict
-- Regras de progressão: dias, pagamento por velocidade, XP e desbloqueios.
-- Compartilhado para o cliente conseguir mostrar a mesma conta que o servidor faz.

local Catalog = require(script.Parent.Catalog)
local Recipes = require(script.Parent.Recipes)

local Progression = {}

Progression.DayBonusXp = 25

-- Clientes por dia: crescem com o nível (5 no nível 1 até 10 a partir do 16)
function Progression.ordersForLevel(level: number): number
	if level <= 1 then
		return 5
	elseif level <= 3 then
		return 6
	elseif level <= 6 then
		return 7
	elseif level <= 10 then
		return 8
	elseif level <= 15 then
		return 9
	end
	return 10
end

-- Tempo (s) contado a partir do pedido. É o mesmo pra toda receita:
-- receitas mais complexas pagam mais, mas o relógio não fica mais generoso.
Progression.GraceTime = 0.8 -- compensa a animação do balão antes do minigame abrir
Progression.FastTime = 8 -- até aqui: pagamento máximo
Progression.SlowTime = 32 -- a partir daqui: pagamento mínimo
Progression.MaxMultiplier = 1.5
Progression.MinMultiplier = 0.5

-- tier 3..0
Progression.TierNames = {
	[0] = "Demorou...",
	[1] = "Ufa!",
	[2] = "Bom trabalho!",
	[3] = "Relâmpago!",
}

function Progression.multiplier(elapsed: number): number
	local a = math.clamp((elapsed - Progression.FastTime) / (Progression.SlowTime - Progression.FastTime), 0, 1)
	return Progression.MaxMultiplier + (Progression.MinMultiplier - Progression.MaxMultiplier) * a
end

function Progression.tier(multiplier: number): number
	if multiplier >= 1.3 then
		return 3
	elseif multiplier >= 0.95 then
		return 2
	elseif multiplier >= 0.7 then
		return 1
	end
	return 0
end

-- Retorna (dinheiro, tier) para uma bebida entregue após `elapsed` segundos.
function Progression.payout(drinkId: string, elapsed: number): (number, number)
	local mult = Progression.multiplier(elapsed)
	local price = Recipes.Drinks[drinkId].Price
	return math.max(1, math.floor(price * mult + 0.5)), Progression.tier(mult)
end

function Progression.orderXp(tier: number): number
	return 10 + tier * 5
end

-- XP pra sair de cada nível (1..45). Como os clientes por dia crescem com o nível, o XP do dia vai de
-- ~150 no nível 1 até ~275 do 16 em diante: nível 2 no dia 2, 16 perto do dia 80 e 30 perto do dia 163.
-- Do 31 ao 46 vêm as festas novas (Dia do Amor, São Patrício, Carnaval e Festa Junina), uns 6 dias por nível.
-- O dia 1 (5 clientes) não chega aos 300, então o nível 2 nunca sai no primeiro dia.
-- O save guarda o nível (não o XP total): ninguém é rebaixado quando a tabela muda.
Progression.XpTable = {
	300, 525, 700, 800, 1000, 1000, 1100, 1350, 1350, 1350,
	1500, 1500, 1750, 1750, 1750, 1650, 1650, 1650, 1650, 1650,
	1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650,
	1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650, 1650,
	1650, 1650, 1650, 1650, 1650,
}

function Progression.xpToNext(level: number): number
	local n = #Progression.XpTable
	return Progression.XpTable[level] or Progression.XpTable[n] + (level - n) * 150
end

-- Aplica XP ganho: retorna (novoLevel, novoXpDentroDoLevel)
function Progression.applyXp(level: number, xp: number, gained: number): (number, number)
	xp += gained
	while xp >= Progression.xpToNext(level) do
		xp -= Progression.xpToNext(level)
		level += 1
	end
	return level, xp
end

function Progression.drinksForLevel(level: number): { string }
	local list = {}
	for _, id in Recipes.DrinkOrder do
		if Recipes.Drinks[id].Level <= level then
			table.insert(list, id)
		end
	end
	return list
end

-- Sorteia uma bebida da lista, com mais chance para as receitas recém-aprendidas.
function Progression.randomFrom(list: { string }, level: number, rng: Random): string
	local total = 0
	local weights = {}
	for i, id in list do
		local age = level - Recipes.Drinks[id].Level
		weights[i] = if age == 0 then 3 elseif age == 1 then 2 else 1
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i, id in list do
		roll -= weights[i]
		if roll <= 0 then
			return id
		end
	end
	return list[#list]
end

function Progression.randomDrink(level: number, rng: Random): string
	return Progression.randomFrom(Progression.drinksForLevel(level), level, rng)
end

Progression.MinMenu = 3

-- Cardápio efetivo: receitas escolhidas que estão desbloqueadas (ou todas, se faltar)
function Progression.effectiveMenu(chosen: { string }, level: number): { string }
	local unlocked = Progression.drinksForLevel(level)
	local list = {}
	for _, id in Recipes.DrinkOrder do
		if table.find(chosen, id) and Recipes.Drinks[id].Level <= level then
			table.insert(list, id)
		end
	end
	if #list < math.min(Progression.MinMenu, #unlocked) then
		return unlocked
	end
	return list
end

function Progression.ingredientUnlocked(id: string, level: number): boolean
	return Recipes.Ingredients[id].Level <= level
end

-- O que foi desbloqueado ao sair de `fromLevel` e chegar em `toLevel`
function Progression.unlocksBetween(fromLevel: number, toLevel: number): ({ string }, { string })
	local drinks, ingredients = {}, {}
	for _, id in Recipes.DrinkOrder do
		local lv = Recipes.Drinks[id].Level
		if lv > fromLevel and lv <= toLevel then
			table.insert(drinks, id)
		end
	end
	for _, id in Recipes.IngredientOrder do
		local lv = Recipes.Ingredients[id].Level
		if lv > fromLevel and lv <= toLevel then
			table.insert(ingredients, id)
		end
	end
	return drinks, ingredients
end

-- Tudo o que um nível libera, na ordem da tela de "subiu de nível".
-- kind: "drink" | "ingredient" | "modifier" | "shop" (melhoria, quitute, decoração, tema, kit de tintas)
-- | "upgradeTier" (próximo degrau de uma melhoria; tier = degrau) | "radio" (id = índice da estação)
-- | "catColor" | "wallColor"
export type Reward = { kind: string, id: string, tier: number? }

function Progression.rewardsBetween(fromLevel: number, toLevel: number): { Reward }
	local list: { Reward } = {}
	local function between(lv: number): boolean
		return lv > fromLevel and lv <= toLevel
	end
	local drinks, ingredients = Progression.unlocksBetween(fromLevel, toLevel)
	for _, id in drinks do
		table.insert(list, { kind = "drink", id = id })
	end
	for _, id in ingredients do
		table.insert(list, { kind = "ingredient", id = id })
	end
	for _, id in Recipes.ModifierOrder do
		if between(Recipes.Modifiers[id].Level) then
			table.insert(list, { kind = "modifier", id = id })
		end
	end
	for _, id in Catalog.UpgradeOrder do
		local u = Catalog.Upgrades[id]
		if between(u.Level) then
			table.insert(list, { kind = "shop", id = id })
		end
		for tier = 1, #u.Costs do
			local lv = Catalog.upgradeTierLevel(id, tier)
			if lv ~= u.Level and between(lv) then
				table.insert(list, { kind = "upgradeTier", id = id, tier = tier })
			end
		end
	end
	for _, id in Catalog.PastryOrder do
		if between(Catalog.Pastries[id].Level) then
			table.insert(list, { kind = "shop", id = id })
		end
	end
	for _, id in Catalog.DecorOrder do
		if between(Catalog.Decor[id].Level) then
			table.insert(list, { kind = "shop", id = id })
		end
	end
	for _, id in Catalog.ThemeOrder do
		local th = Catalog.Themes[id]
		if th.Cost > 0 and between(th.Level) then
			table.insert(list, { kind = "shop", id = id })
		end
	end
	if between(Catalog.WallPaint.Level) then
		table.insert(list, { kind = "shop", id = Catalog.WallPaint.Id })
	end
	for _, id in Catalog.WallColorOrder do
		local lv = Catalog.WallColors[id].Level
		if lv > Catalog.WallPaint.Level and between(lv) then
			table.insert(list, { kind = "wallColor", id = id })
		end
	end
	for _, id in Catalog.CatColorOrder do
		local lv = Catalog.CatColors[id].Level
		if lv > Catalog.Decor.Cat.Level and between(lv) then
			table.insert(list, { kind = "catColor", id = id })
		end
	end
	for i, station in Catalog.RadioStations do
		if between(station.Level) then
			table.insert(list, { kind = "radio", id = tostring(i) })
		end
	end
	return list
end

return Progression
