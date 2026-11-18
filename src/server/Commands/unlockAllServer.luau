local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.DataService)
local CafeService = require(ServerScriptService.Server.CafeService)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Catalog = require(ReplicatedStorage.Shared.Catalog)

-- Maior nível pedido por qualquer coisa dos catálogos (campos Level e TierLevels, em qualquer profundidade),
-- assim o comando continua certo quando entrarem itens novos.
local function maxUnlockLevel(): number
	local best = 1
	local seen = {}
	local function walk(t: { [any]: any })
		if seen[t] then
			return
		end
		seen[t] = true
		for k, v in t do
			if k == "Level" and type(v) == "number" then
				best = math.max(best, v)
			elseif k == "TierLevels" and type(v) == "table" then
				for _, lv in v do
					if type(lv) == "number" then
						best = math.max(best, lv)
					end
				end
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	walk(Recipes)
	walk(Catalog)
	return best
end

return function(context, target: Player?)
	local player = target or context.Executor
	local data = DataService.get(player)
	if not data then
		return "Dados ainda não carregados."
	end
	-- só guarda o backup na primeira vez: rodar de novo não sobrescreve o nível verdadeiro
	if not data.TestBackup then
		data.TestBackup = { Level = data.Level, XP = data.XP }
	end
	local level = maxUnlockLevel()
	data.Level = math.max(data.Level, level)
	data.XP = 0
	CafeService.refresh(player)
	return `{player.Name} agora está no nível {data.Level} (tudo liberado). Nível guardado: {data.TestBackup.Level}. Use restoreLevel para voltar.`
end
