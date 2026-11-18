local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.DataService)
local CafeService = require(ServerScriptService.Server.CafeService)

return function(context, target: Player?)
	local player = target or context.Executor
	local data = DataService.get(player)
	if not data then
		return "Dados ainda não carregados."
	end
	local backup = data.TestBackup
	if not backup then
		return `{player.Name} não tem nível guardado (unlockAll não foi usado).`
	end
	data.Level = backup.Level
	data.XP = backup.XP
	data.TestBackup = nil
	CafeService.refresh(player)
	return `{player.Name} voltou ao nível {data.Level} ({data.XP} XP).`
end
