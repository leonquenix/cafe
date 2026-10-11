local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.DataService)
local CafeService = require(ServerScriptService.Server.CafeService)

return function(context, amount: number, target: Player?)
	local player = target or context.Executor
	local data = DataService.get(player)
	if not data then
		return "Dados ainda não carregados."
	end
	data.Money = math.clamp(amount, 0, 4294967295)
	CafeService.refresh(player)
	return `{player.Name} agora tem ${data.Money}.`
end
