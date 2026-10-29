local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.DataService)
local CafeService = require(ServerScriptService.Server.CafeService)

return function(context, level: number, target: Player?)
	local player = target or context.Executor
	local data = DataService.get(player)
	if not data then
		return "Dados ainda não carregados."
	end
	data.Level = math.clamp(level, 1, 255)
	data.XP = 0
	CafeService.refresh(player)
	return `{player.Name} agora está no nível {data.Level}.`
end
