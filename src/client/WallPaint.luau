--!strict
-- Cor das paredes de dentro (só no cliente). O servidor marca o reboco com a tag "WallPaint" e o atributo
-- WallPaint = "Plaster" (parede) ou "Shade" (faixa perto do teto); aqui as peças trocam de cor com um fade.
-- Peças que chegam depois (streaming) já entram na cor atual.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)

local WallPaint = {}

local current = Catalog.DefaultWallColor

local function colorFor(p: Instance, id: string): Color3?
	local wall = Catalog.WallColors[id] or Catalog.WallColors[Catalog.DefaultWallColor]
	local role = p:GetAttribute("WallPaint")
	if role == "Plaster" then
		return wall.Plaster
	elseif role == "Shade" then
		return wall.Shade
	end
	return nil
end

local function paint(p: Instance, duration: number)
	if not p:IsA("BasePart") then
		return
	end
	local color = colorFor(p, current)
	if not color or p.Color == color then
		return
	end
	if duration > 0 then
		TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Sine), { Color = color }):Play()
	else
		p.Color = color
	end
end

-- Troca a cor de todas as paredes (prévia ou cor salva)
function WallPaint.set(id: string, duration: number?)
	if not Catalog.WallColors[id] then
		id = Catalog.DefaultWallColor
	end
	current = id
	for _, p in CollectionService:GetTagged("WallPaint") do
		paint(p, duration or 0.6)
	end
end

function WallPaint.start()
	CollectionService:GetInstanceAddedSignal("WallPaint"):Connect(function(p)
		paint(p, 0)
	end)
end

return WallPaint
