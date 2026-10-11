-- Só o dono do jogo (ou qualquer um no Studio) pode usar os comandos do Cmdr.
local RunService = game:GetService("RunService")

-- Adicione aqui UserIds de outros admins
local ADMINS: { [number]: boolean } = {}

return function(registry)
	registry:RegisterHook("BeforeRun", function(context)
		local player = context.Executor
		if RunService:IsStudio() then
			return nil
		end
		if player and (player.UserId == game.CreatorId or ADMINS[player.UserId]) then
			return nil
		end
		return "Sem permissão para usar comandos."
	end)
end
