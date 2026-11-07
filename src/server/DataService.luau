--!strict
-- Persistência com ProfileStore.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

export type Data = {
	Money: number,
	TotalEarned: number,
	Level: number,
	XP: number, -- XP dentro do level atual
	Day: number, -- dia atual (1 = primeiro dia)
	DrinksServed: number,
	Upgrades: { [string]: number },
	Pastries: { [string]: boolean },
	Decor: { [string]: boolean },
	DecorHidden: { [string]: boolean }, -- decorações compradas que o jogador desligou na loja
	Menu: { string },
	DrinkStats: { [string]: number }, -- bebidas servidas certas, por receita
	Mastered: { [string]: boolean }, -- bebidas dominadas (+10%): marco de 50 resgatado (ou maestria antiga)
	PastryStats: { [string]: number }, -- doces entregues ok/perfeitos, por receita
	DrinkClaims: { [string]: number }, -- marcos de conquista resgatados por bebida (Recipes.Milestones)
	PastryClaims: { [string]: number }, -- marcos de conquista resgatados por doce
	AchievementsVersion: number, -- migração das conquistas já aplicada (0 = save de antes dos marcos)
	RadioTrack: number, -- estação escolhida no rádio (1 = bossa nova)
	RadioVolume: number, -- 0-100
	CatColor: string, -- pelagem do gatinho da vitrine (Catalog.CatColors)
	Themes: { [string]: boolean }, -- temas da fachada comprados (Catalog.Themes)
	Theme: string, -- tema da fachada em uso
	WallPaint: boolean, -- comprou o kit de tintas (Catalog.WallPaint)
	WallColor: string, -- cor das paredes de dentro (Catalog.WallColors)
	IntroSeen: boolean, -- já viu a fala da vovó no começo do primeiro dia
	PastryTutorialSeen: boolean, -- já viu o tutorial do forno (primeiro dia com um quitute comprado)
}

local TEMPLATE: Data = {
	Money = 0,
	TotalEarned = 0,
	Level = 1,
	XP = 0,
	Day = 1,
	DrinksServed = 0,
	Upgrades = {},
	Pastries = {},
	Decor = {},
	DecorHidden = {},
	Menu = {},
	DrinkStats = {},
	Mastered = {},
	PastryStats = {},
	DrinkClaims = {},
	PastryClaims = {},
	AchievementsVersion = 0,
	RadioTrack = 1,
	RadioVolume = 70,
	CatColor = "Gray",
	Themes = {},
	Theme = "Original",
	WallPaint = false,
	WallColor = "Cream",
	IntroSeen = false,
	PastryTutorialSeen = false,
}

local Store = ProfileStore.New("CafeData_v1", TEMPLATE)
local profiles: { [Player]: any } = {}
local loadedCallbacks: { (Player, Data) -> () } = {}

local DataService = {}

-- Save de teste (só no Studio): com o atributo TestSave no ServerScriptService preenchido (ex.: "novo1"),
-- o jogo usa um perfil separado, Player_<id>_Test_<nome>, que começa do zero. O save real não é tocado.
-- Apagar o atributo volta para o save real; trocar o nome começa outro perfil novo.
local function profileKey(player: Player): string
	local key = `Player_{player.UserId}`
	local slot = if RunService:IsStudio() then ServerScriptService:GetAttribute("TestSave") else nil
	if type(slot) == "string" and slot ~= "" then
		key = `{key}_Test_{slot}`
		warn(`[DataService] usando o SAVE DE TESTE "{slot}" ({key}); o save real não é alterado`)
	end
	return key
end

-- Conquistas v1 (marcos 5/10/25/50/100): a maestria antiga era uma missão só por bebida
-- (Recipes.legacyMasteryTarget: 50, 35 ou 25). Quem já tinha resgatado fica com os marcos até essa meta
-- marcados como resgatados (sem pagar de novo) e continua Dominado. As contagens não mudam.
-- Idempotente: só aumenta o que já foi resgatado, e roda uma vez por save (AchievementsVersion).
local ACHIEVEMENTS_VERSION = 1

local function migrateAchievements(data: Data)
	if (data.AchievementsVersion or 0) >= ACHIEVEMENTS_VERSION then
		return
	end
	for drink in data.Mastered do
		if Recipes.hasMilestones(drink) then
			local n = Recipes.milestonesReached(Recipes.legacyMasteryTarget(drink))
			data.DrinkClaims[drink] = math.max(data.DrinkClaims[drink] or 0, n)
		end
	end
	data.AchievementsVersion = ACHIEVEMENTS_VERSION
end

DataService.migrateAchievements = migrateAchievements

local function onPlayerAdded(player: Player)
	local profile = Store:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Não foi possível carregar seus dados. Tente novamente.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	-- "Morceguinhos e Teias" (HalloweenWall) virou dois itens: quem já tinha ganha as Teias de Aranha também
	-- (e, se tinha desligado, as teias começam desligadas)
	local data = profile.Data
	if data.Decor.HalloweenWall and data.Decor.HalloweenWebs == nil then
		data.Decor.HalloweenWebs = true
		if data.DecorHidden.HalloweenWall then
			data.DecorHidden.HalloweenWebs = true
		end
	end
	migrateAchievements(data)
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sua sessão foi aberta em outro servidor.")
	end)

	if player.Parent == Players then
		profiles[player] = profile
		for _, callback in loadedCallbacks do
			task.spawn(callback, player, profile.Data)
		end
	else
		profile:EndSession()
	end
end

function DataService.get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

local function deepCopy<T>(t: T): T
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t :: any do
		out[k] = deepCopy(v)
	end
	return out :: any
end

-- Apaga todo o progresso do jogador (volta ao template)
function DataService.wipe(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local data = profile.Data
	for k in data do
		data[k] = nil
	end
	for k, v in deepCopy(TEMPLATE) :: any do
		data[k] = v
	end
	data.AchievementsVersion = ACHIEVEMENTS_VERSION -- save zerado não tem nada para migrar
	return true
end

function DataService.onLoaded(callback: (Player, Data) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile.Data)
	end
end

function DataService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession()
		end
	end)
end

return DataService
