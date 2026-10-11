local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.DataService)
local CafeService = require(ServerScriptService.Server.CafeService)

return function(context, target: Player?)
	local player = target or context.Executor
	if not DataService.wipe(player) then
		return "Dados ainda não carregados."
	end
	CafeService.resetSession(player)
	-- recarregar do zero é o jeito mais limpo de resetar câmera, UI, decoração etc.
	task.delay(0.5, function()
		player:Kick("Seus dados foram apagados! Entre de novo para começar do zero.")
	end)
	return `Dados de {player.Name} apagados.`
end
