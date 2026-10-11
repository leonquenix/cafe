-- Ponto de entrada do servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Net) -- registra os pacotes do ByteNet antes de tudo

local ServerScriptService = game:GetService("ServerScriptService")

local Cmdr = require(ServerScriptService.ServerPackages.Cmdr)
local Scenery = require(script.Scenery)
local DataService = require(script.DataService)
local CafeService = require(script.CafeService)
local Barista = require(script.Barista)

Scenery.build()
DataService.start()
CafeService.start()
Barista.start()

-- Comandos de admin (abre com F2)
Cmdr.Registry:RegisterDefaultCommands(function(command)
	return command.Name == "help"
end)
Cmdr.Registry:RegisterCommandsIn(script.Commands)
Cmdr.Registry:RegisterHooksIn(script.Hooks)
