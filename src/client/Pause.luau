--!strict
-- Pausa do expediente (livro de receitas aberto durante o dia): congela a chegada e o andar
-- dos clientes, o relógio do pedido (aqui e no servidor) e os minigames em andamento.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Pause = {}

local paused = false
local pausedAt = 0
local offset = 0 -- tempo total parado

function Pause.isPaused(): boolean
	return paused
end

-- relógio que não anda durante a pausa (use no lugar de os.clock nos timers de jogo)
function Pause.clock(): number
	return (if paused then pausedAt else os.clock()) - offset
end

function Pause.set(on: boolean)
	if on == paused then
		return
	end
	paused = on
	if on then
		pausedAt = os.clock()
	else
		offset += os.clock() - pausedAt
	end
	Net.Pause.send(on)
end

-- task.wait que só conta o tempo fora da pausa
function Pause.wait(seconds: number)
	local target = Pause.clock() + seconds
	while Pause.clock() < target do
		task.wait(target - Pause.clock())
	end
end

return Pause
