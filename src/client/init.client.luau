-- Ponto de entrada do cliente: câmera, fila de clientes, minigame, HUD, loja e ciclo de dias.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Characters = require(ReplicatedStorage.Shared.Characters)
local Net = require(ReplicatedStorage.Shared.Net)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Achievements = require(script.Achievements)
local BackButton = require(script.UI.BackButton)
local Bubble = require(script.UI.Bubble)
local CameraController = require(script.CameraController)
local Customers = require(script.Customers)
local DayCycle = require(script.DayCycle)
local Decor = require(script.Decor)
local OutsideTheme = require(script.OutsideTheme)
local State = require(script.State)
local Sfx = require(script.Sfx)
local DaySummary = require(script.UI.DaySummary)
local FreeCelebration = require(script.UI.FreeCelebration)
local Hud = require(script.UI.Hud)
local Minigame = require(script.UI.Minigame)
local PastryPopup = require(script.UI.PastryPopup)
local PrepScreen = require(script.UI.PrepScreen)
local MenuMusic = require(script.UI.MenuMusic)
local Radio = require(script.UI.Radio)
local RecipeBook = require(script.UI.RecipeBook)
local Theme = require(script.UI.Theme)
local ThemePicker = require(script.UI.ThemePicker)
local TitleScreen = require(script.UI.TitleScreen)
local Transition = require(script.UI.Transition)
local WalkHud = require(script.UI.WalkHud)
local WallPicker = require(script.UI.WallPicker)
local WallPaint = require(script.WallPaint)

local peek = Fusion.peek
local Kind = Characters.Kind

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)

CameraController.start()
-- começa do lado de fora, olhando a fachada (tela de início)
CameraController.focus(TitleScreen.CameraPosition, TitleScreen.CameraTarget, 0, TitleScreen.FieldOfView)
DayCycle.morning(0)
Decor.start()
OutsideTheme.start()
WallPaint.start()
-- pop de bolha em todos os botões (antes das telas serem criadas)
Sfx.init(playerGui)
TitleScreen.init(playerGui)
FreeCelebration.init(playerGui)
BackButton.init(playerGui)
WalkHud.init(playerGui)
Transition.init(playerGui)
DaySummary.init(playerGui)
PrepScreen.init(playerGui)
ThemePicker.init(playerGui)
WallPicker.init(playerGui)
RecipeBook.init(playerGui)
Hud.new(playerGui)
PastryPopup.init(playerGui)
Hud.setVisible(false)

-- Cmdr (comandos de admin): ";" (ou F2) abre o console
task.spawn(function()
	local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient") :: ModuleScript) :: any
	CmdrClient:SetActivationKeys({ Enum.KeyCode.Semicolon, Enum.KeyCode.F2 })
end)

local minigame = Minigame.new(playerGui)
local currentOrder = nil
local currentCustomer = nil
local pendingRetry: { orderId: number, done: (boolean) -> () }? = nil
-- tempo com o balão do pedido na tela antes do pop-up do forno (dá pra ver qual doce é)
local PASTRY_POPUP_DELAY = 1.7
local dayActive = false
local startingDay = false
local dayPlan = {}

local pendingDecor: { [string]: boolean } = {} -- comprada, esperando a câmera chegar para aparecer
local showcasing = false
local prepareDay: (day: number, tab: string?) -> ()

Hud.onOpenBook = function()
	RecipeBook.show()
end
PrepScreen.onOpenBook = function()
	RecipeBook.show()
end
RecipeBook.onClaim = function(drink)
	Net.ClaimMastery.send(drink)
end
PrepScreen.onBuy = function(id)
	if Catalog.Decor[id] and not Decor.isBuilt(id) then
		pendingDecor[id] = true
	end
	Net.Buy.send(id)
end
PrepScreen.onSetMenu = function(list)
	Net.SetMenu.send(list)
end
PrepScreen.onSetCatColor = function(color)
	Net.SetCatColor.send(color)
end
PrepScreen.onSetDecorShown = function(id, shown)
	Net.SetDecorShown.send({ id = id, shown = shown })
end

-- Decoração nova: fecha o menu, a câmera voa até o lugar, a peça se monta, volta e reabre o menu
local function showcaseDecor(id: string)
	showcasing = true
	PrepScreen.close(function()
		local focus = Decor.Focus[id]
		if focus then
			CameraController.focus(focus[1], focus[2], 1.3)
			task.wait(1.35)
		end
		local duration = Decor.reveal(id)
		local item = Catalog.Decor[id]
		Transition.banner(`Nova decoração: {item.Name}!`, `Aconchego +{item.Cozy}  ·  {item.Description}`, item.Icon, duration + 1.4)
		task.wait(duration + 1.8)
		CameraController.release(1.1)
		task.wait(1.1)
		showcasing = false
		prepareDay(peek(State.Day), "Decor")
	end)
end

-- pelagem do gato do balcão (antes do Owned, pra ele já ser montado na cor certa)
State.scope:Observer(State.CatColor):onBind(function()
	Decor.setCatColor(peek(State.CatColor))
end)

-- tema da fachada salvo (a prévia do pop-up de temas manda no visual enquanto está aberto)
local previewingTheme = false
State.scope:Observer(State.Theme):onBind(function()
	if not previewingTheme then
		OutsideTheme.set(peek(State.Theme))
	end
end)

-- cor das paredes salva (a prévia do pop-up das paredes manda enquanto está aberto)
local previewingWalls = false
State.scope:Observer(State.WallColor):onBind(function()
	if not previewingWalls then
		WallPaint.set(peek(State.WallColor), 0.6)
	end
end)

-- decorações ligadas/desligadas na loja (antes do Owned: o café já nasce sem as desligadas)
State.scope:Observer(State.Hidden):onBind(function()
	Decor.setHidden(peek(State.Hidden))
	Decor.apply(peek(State.Owned), pendingDecor)
end)

State.scope:Observer(State.Owned):onBind(function()
	local owned = peek(State.Owned)
	Decor.apply(owned, pendingDecor)
	for id in pendingDecor do
		if owned[id] then
			pendingDecor[id] = nil
			if not showcasing then
				task.spawn(showcaseDecor, id)
			end
		end
	end
end)

-- avisa quando uma receita (bebida ou doce) alcança um marco de conquista novo para resgatar
local function watchMilestones(kind: Achievements.Kind, value: any)
	local last: { [string]: number }? = nil
	State.scope:Observer(value):onChange(function()
		local stats = peek(value) :: { [string]: number }
		if last then
			for _, id in Achievements.ids(kind) do
				local count = stats[id] or 0
				local reached = Recipes.milestonesReached(count)
				if reached > Recipes.milestonesReached(last[id] or 0) and reached > (peek(State.Claims)[id] or 0) then
					local m = Recipes.Milestones[reached]
					Hud.toast(`Conquista: {m.Count}x {Achievements.name(kind, id)}! Colete no livro`, Theme.Mustard)
				end
			end
		end
		last = table.clone(stats)
	end)
end
watchMilestones("Drink", State.Stats)
watchMilestones("Pastry", State.PastryStats)

local INTRO_LINE = "Preciso fazer isso pela vovó, ela amava tanto esse lugar, talvez eu só precise de uma cidadezinha tranquila e um novo começo."

-- Primeiro dia: o barista pensa em voz alta antes de abrir (só uma vez, salvo no perfil).
-- O texto aparece letra por letra; um toque completa o texto, outro fecha o balão.
local function introLine()
	local character = player.Character or player.CharacterAdded:Wait()
	local head = character:WaitForChild("Head", 5) :: BasePart?
	if not head then
		return
	end
	local gui, label, hint = Bubble.speech(head, INTRO_LINE)
	Sfx.play("CutePop")
	local tapped = false
	local conn = UserInputService.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			tapped = true
		end
	end)
	task.wait(0.45)
	local count = utf8.len(INTRO_LINE) or #INTRO_LINE
	local shown = 0
	for _, code in utf8.codes(INTRO_LINE) do
		if tapped then
			break
		end
		shown += 1
		label.MaxVisibleGraphemes = shown
		local ch = utf8.char(code)
		task.wait(if ch == "," then 0.3 else 0.035)
	end
	label.MaxVisibleGraphemes = -1
	-- respiro pra o toque que completou o texto não fechar o balão junto
	task.wait(0.2)
	tapped = false
	TweenService:Create(hint, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	local t0 = os.clock()
	while not tapped and os.clock() - t0 < (if shown >= count then 3.5 else 6) do
		task.wait()
	end
	conn:Disconnect()
	Bubble.pop(gui)
	task.wait(0.4)
end

local function startDay(day: number)
	if startingDay then
		return
	end
	startingDay = true
	-- os grilos da noite somem quando o jogador manda começar o dia
	DaySummary.stopNight(2)
	-- a música do menu vai sumindo durante a transição e o rádio entra no lugar
	TitleScreen.stopMusic(2)
	MenuMusic.stop(2)
	Transition.play(day, function()
		DayCycle.morning(0)
		Hud.setVisible(true)
		-- música da gameplay: toca durante o expediente
		Radio.play()
	end, function()
		-- os clientes (e o dia) só começam depois da fala da vovó
		if day <= 1 and not peek(State.IntroSeen) then
			introLine()
		end
		Net.StartDay.send(1)
	end)
end

-- loja + cardápio antes de abrir, depois a transição de manhã.
-- No primeiro dia não tem loja nem cardápio: começa direto com o básico.
function prepareDay(day: number, tab: string?)
	Hud.setVisible(false)
	if day <= 1 then
		startDay(day)
		return
	end
	-- entre os dias toca o piano do menu no lugar da música da tela de início
	TitleScreen.stopMusic(2)
	MenuMusic.play()
	PrepScreen.show(function()
		startDay(day)
	end, tab)
end

-- Temas da fachada: a câmera sai pra olhar a loja e o pop-up troca o tema ao vivo
PrepScreen.onThemes = function()
	PrepScreen.close(function()
		previewingTheme = true
		-- entre os dias é noite: a prévia acontece no fim de tarde pra dar pra ver o tema
		DayCycle.setProgress(1, 1.8)
		CameraController.focus(ThemePicker.CameraPosition, ThemePicker.CameraTarget, 1.8, ThemePicker.FieldOfView)
		task.wait(1.6)
		ThemePicker.show({
			OnPreview = function(id)
				OutsideTheme.set(id)
			end,
			OnBuy = function(id)
				local before = peek(State.Money) :: number
				Net.Buy.send(id)
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < 2 do
						if (peek(State.Money) :: number) < before then
							Sfx.play("Cash")
							task.delay(0.25, Sfx.play, "CutePop")
							OutsideTheme.celebrate()
							return
						end
						task.wait()
					end
					Sfx.play("Denied")
				end)
			end,
			OnUse = function(id)
				Net.SetTheme.send(id)
				OutsideTheme.celebrate()
			end,
			OnClose = function()
				previewingTheme = false
				OutsideTheme.set(peek(State.Theme))
				DayCycle.night(1.6)
				CameraController.release(1.6)
				task.wait(1.6)
				prepareDay(peek(State.Day), "Decor")
			end,
		})
	end)
end

-- Cores das paredes: a câmera olha a loja por dentro e o pop-up pinta as paredes ao vivo
PrepScreen.onWalls = function()
	PrepScreen.close(function()
		previewingWalls = true
		-- entre os dias é noite: a prévia acontece de dia pra dar pra ver a cor de verdade
		DayCycle.setProgress(0.5, 1.6)
		CameraController.focus(WallPicker.CameraPosition, WallPicker.CameraTarget, 1.6, WallPicker.FieldOfView)
		task.wait(1.5)
		WallPicker.show({
			OnPreview = function(id)
				WallPaint.set(id, 0.5)
			end,
			OnBuy = function(id)
				local before = peek(State.Money) :: number
				-- o servidor processa em ordem: se o kit for comprado, a cor escolhida já entra em uso
				Net.Buy.send(Catalog.WallPaint.Id)
				Net.SetWallColor.send(id)
				task.spawn(function()
					local t0 = os.clock()
					while os.clock() - t0 < 2 do
						if (peek(State.Money) :: number) < before then
							Sfx.play("Cash")
							task.delay(0.25, Sfx.play, "CutePop")
							return
						end
						task.wait()
					end
					Sfx.play("Denied")
				end)
			end,
			OnUse = function(id)
				Net.SetWallColor.send(id)
			end,
			OnClose = function()
				previewingWalls = false
				WallPaint.set(peek(State.WallColor), 0.5)
				DayCycle.night(1.6)
				CameraController.release(1.6)
				task.wait(1.6)
				prepareDay(peek(State.Day), "Decor")
			end,
		})
	end)
end

-- Modo andar: solta o personagem pelo café (fora do expediente)
PrepScreen.onWalk = function()
	PrepScreen.close(function()
		Net.WalkMode.send(true)
		task.wait(0.1)
		CameraController.suspend()
		MenuMusic.setDecor(true)
		WalkHud.show(function()
			MenuMusic.setDecor(false)
			Net.WalkMode.send(false)
			CameraController.resume(1.2)
			task.wait(1.2)
			prepareDay(peek(State.Day), "Decor")
		end)
	end)
end

-- Modo Livre: sem fila, sem pedido; qualquer mistura pode ser servida
local function identifyDrink(portions: { string }, mix: number): (string?, string?)
	local level = peek(State.Level)
	local mixed, stirred = mix >= 1, mix > 0
	for _, id in Recipes.DrinkOrder do
		if Recipes.Drinks[id].Level <= level and Recipes.matchesOrder(id, nil, portions, mixed, stirred) then
			return id, nil
		end
	end
	for _, id in Recipes.DrinkOrder do
		if Recipes.Drinks[id].Level <= level then
			for _, mod in Recipes.ModifierOrder do
				if Recipes.Modifiers[mod].Level <= level and Recipes.modifierApplies(id, mod) and Recipes.matchesOrder(id, mod, portions, mixed, stirred) then
					return id, mod
				end
			end
		end
	end
	return nil, nil
end

minigame.onFreeServe = function(portions, mix)
	local drink, modifier = identifyDrink(portions, mix)
	if drink then
		local subtitle = if modifier then `{Recipes.Modifiers[modifier].Name} · receita perfeita!` else "Receita perfeita!"
		FreeCelebration.known(`{Recipes.Drinks[drink].Name}!`, subtitle, portions, mix)
	else
		FreeCelebration.unknown(portions, mix)
	end
end

local showTitle: () -> ()

local function enterFreeMode()
	CameraController.release(2.8)
	task.delay(2.9, function()
		minigame:openFree()
		BackButton.show(function()
			minigame:close()
			CameraController.focus(TitleScreen.CameraPosition, TitleScreen.CameraTarget, 2.4, TitleScreen.FieldOfView)
			task.wait(2.4)
			showTitle()
		end)
	end)
end

-- Tela de início: PLAY -> a câmera entra pela porta até o balcão -> dia (ou loja)
function showTitle()
	TitleScreen.show(function()
		CameraController.release(2.8)
		task.delay(2.9, function()
			prepareDay(peek(State.Day))
		end)
	end, enterFreeMode)
end
showTitle()

Customers.start(function(customer)
	Net.RequestOrder.send(customer.Index)
end)

Net.DayPlan.listen(function(plan)
	dayPlan = plan
end)

Net.PlayerState.listen(function(state)
	State.apply(state)

	if state.dayActive and not dayActive then
		-- o dia começou
		dayActive = true
		startingDay = false
		Customers.beginDay(dayPlan, state.served)
	elseif not state.dayActive then
		dayActive = false
		-- primeira carga: a tela de início já está esperando o PLAY
	end

	if state.dayActive then
		DayCycle.setProgress(state.served / state.perDay, 2.5)
	end
end)

-- o pacote de estado pode chegar antes do listener: pede de novo até receber
task.spawn(function()
	while not peek(State.Loaded) do
		Net.StartDay.send(0)
		task.wait(2)
	end
end)

local function tagFor(customer): (string?, Color3?)
	if customer.Kind == Kind.Critic then
		return "CRÍTICO", Color3.fromRGB(150, 40, 60)
	elseif customer.Kind == Kind.Kid then
		return "Pequeno cliente", Color3.fromRGB(120, 170, 220)
	end
	return nil, nil
end

Net.OrderAssigned.listen(function(order)
	local customer = Customers.get(order.customerId)
	if not customer or Customers.front() ~= customer then
		return
	end
	currentOrder = order
	currentCustomer = customer
	local tag, tagColor = tagFor(customer)
	Customers.showOrder(customer, {
		drink = order.drink,
		modifier = order.modifier,
		pastry = order.pastry,
		tag = tag,
		tagColor = tagColor,
	})
	-- o doce vem primeiro (pop-up do forno); a bebida só abre depois
	local drinkOnly = table.clone(order)
	drinkOnly.pastry = ""
	task.delay(if order.pastry ~= "" then PASTRY_POPUP_DELAY else 0.6, function()
		if currentOrder ~= order then
			return
		end
		if order.pastry == "" then
			minigame:open(drinkOnly)
			return
		end
		PastryPopup.open(order.pastry, function(quality)
			if currentOrder ~= order then
				return
			end
			Net.PastryDone.send({ orderId = order.orderId, quality = quality })
			if quality == Catalog.PastryQuality.Skipped then
				Hud.toast("Sem o quitute: o cliente vai pagar só a bebida", Theme.Mustard)
			end
			minigame:open(drinkOnly)
		end, function(done)
			pendingRetry = { orderId = order.orderId, done = done }
			Net.PastryRetry.send(order.orderId)
		end)
	end)
end)

Net.PastryRetryResult.listen(function(result)
	local pending = pendingRetry
	if pending and pending.orderId == result.orderId then
		pendingRetry = nil
		pending.done(result.ok)
	end
end)

minigame.onServe = function(orderId, ingredients, mixed, stirred)
	Net.SubmitDrink.send({
		orderId = orderId,
		ingredients = ingredients,
		mixed = mixed,
		stirred = stirred,
	})
end

local function thanksFor(customer, tier: number): string
	if customer.Kind == Kind.Critic then
		return if tier >= 3 then "Magnífico." else "Hmm. Anotado."
	elseif customer.Kind == Kind.Kid then
		return "Ebaaa!"
	end
	return "Obrigado!"
end

Net.OrderResult.listen(function(result)
	if not currentOrder or result.orderId ~= currentOrder.orderId then
		return
	end
	local color = Recipes.blend(minigame:currentPortions())
	local customer = currentCustomer
	currentOrder = nil
	currentCustomer = nil
	minigame:serveDone(result.success)
	if result.success and (result.problem == "RawPastry" or result.problem == "BurntPastry") then
		-- doce cru/queimado: paga menos e sai insatisfeito
		Customers.serveFront(color, if result.problem == "RawPastry" then "Tá cru..." else "Queimado?!", false)
		Hud.payout(result.earned, result.tier, result.tip)
		Hud.toast(if result.problem == "RawPastry" then "Quitute cru: pagou só a bebida" else "Quitute queimado: pagou só a bebida", Theme.Rose)
	elseif result.success then
		Customers.serveFront(color, if customer then thanksFor(customer, result.tier) else nil, true)
		Hud.payout(result.earned, result.tier, result.tip)
	else
		local complaint, toast = "Não era isso...", "Pedido errado: sem pagamento"
		if result.problem == "Unmixed" then
			complaint, toast = "Nem mexeu!", "Faltou misturar: sem pagamento"
		elseif result.problem == "Stirred" then
			complaint, toast = "Pedi SEM mexer!", "Era sem mexer: sem pagamento"
		end
		if result.earned > 0 then
			-- bebida errada, mas o doce veio: paga só o doce
			complaint ..= " Mas o quitute tá bom."
			toast = string.gsub(toast, "sem pagamento", "pagou só o quitute")
			Hud.payout(result.earned, -1, 0) -- sem selo de velocidade: a bebida não contou
		end
		Customers.serveFront(color, complaint, false)
		Hud.toast(toast, Theme.Rose)
	end
end)

Net.DayEnded.listen(function(summary)
	Customers.endDay()
	-- o rádio para; o placar abre com o som de dia bom ou ruim
	Radio.stop(1.5)
	-- fim de dia forçado (comando endDay): fecha o preparo e despacha a fila
	PastryPopup.dismiss()
	pendingRetry = nil
	if currentOrder then
		currentOrder = nil
		currentCustomer = nil
		minigame:serveDone(true)
	end
	Customers.dismissAll()
	task.spawn(function()
		-- deixa o último cliente sair e a noite cair antes do placar
		task.wait(1.8)
		DayCycle.night(3)
		task.wait(2.6)
		Hud.setVisible(false)
		DaySummary.show(summary, function()
			prepareDay(summary.day + 1)
		end)
	end)
end)
