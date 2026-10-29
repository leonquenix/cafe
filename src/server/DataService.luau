--!strict
-- Persistência com ProfileStore.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

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
	Menu: { string },
	DrinkStats: { [string]: number },
	Mastered: { [string]: boolean },
	RadioTrack: number, -- estação escolhida no rádio (1 = bossa nova)
	RadioVolume: number, -- 0-100
	CatColor: string, -- pelagem do gatinho da vitrine (Catalog.CatColors)
	Themes: { [string]: boolean }, -- temas da fachada comprados (Catalog.Themes)
	Theme: string, -- tema da fachada em uso
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
	Menu = {},
	DrinkStats = {},
	Mastered = {},
	RadioTrack = 1,
	RadioVolume = 70,
	CatColor = "Gray",
	Themes = {},
	Theme = "Original",
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
