local ServerScriptService = game:GetService("ServerScriptService")

local CafeService = require(ServerScriptService.Server.CafeService)

return function(context, target: Player?)
	local player = target or context.Executor
	local _, message = CafeService.forceEndDay(player)
	return message
end
