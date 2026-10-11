--!strict
-- Posições do mundo compartilhadas entre o gerador de cenário (servidor) e o cliente.
-- Chão fica em Y = 0. O barista olha para -Z (em direção à porta/fila).

local Layout = {}

Layout.Room = {
	MinX = -18,
	MaxX = 18,
	MinZ = -22,
	MaxZ = 12,
	Height = 14,
}

Layout.CounterZ = 0 -- centro do balcão
Layout.CounterHeight = 3.4
Layout.BaristaSpot = Vector3.new(-2.6, 0, 3.2) -- pés do barista (fora da linha de visão do cliente)

-- Onde o cliente para em frente ao balcão e direção da fila
Layout.ServeSpot = Vector3.new(0, 0, -2.8)
Layout.QueueDirection = Vector3.new(0, 0, -1)
Layout.QueueSpacing = 3.4
Layout.MaxQueue = 4

Layout.DoorX = 9
Layout.Outside = Vector3.new(Layout.DoorX, 0, -28)
Layout.Entrance = Vector3.new(Layout.DoorX, 0, -18)
-- entrada: da porta vai até o fim da fila pelo corredor da esquerda da porta
Layout.QueueEntry = Vector3.new(1.2, 0, -16.5)
-- saída: quem foi atendido dá um passo pro lado (libera o balcão) e sai por uma faixa própria
Layout.PickupSpot = Vector3.new(3.4, 0, -3.6)
Layout.ExitLane = { Vector3.new(5.6, 0, -6), Vector3.new(5.6, 0, -15.5) }

Layout.Camera = {
	Position = Vector3.new(3.2, 9, 11),
	LookAt = Vector3.new(2.6, 3.6, -6),
	FieldOfView = 64,
}

function Layout.queueSlot(index: number): Vector3
	return Layout.ServeSpot + Layout.QueueDirection * Layout.QueueSpacing * (index - 1)
end

return Layout
