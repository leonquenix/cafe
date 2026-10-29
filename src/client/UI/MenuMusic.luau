--!strict
-- Música do menu entre os dias (loja, cardápio, livro): piano baixinho em loop.
-- No modo passear/decoração ela sobe 30%. Para quando o expediente começa.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MenuMusic = {}

MenuMusic.Id = "rbxassetid://104635174101528" -- "Poetic Piano Stories" (APM)
MenuMusic.Volume = 0.25
MenuMusic.DecorBoost = 1.3

local music: Sound? = nil
local decor = false

local function target(): number
	return MenuMusic.Volume * (if decor then MenuMusic.DecorBoost else 1)
end

local function tween(inst: Instance, time: number, props: { [string]: any }): Tween
	local t = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Sine), props)
	t:Play()
	return t
end

-- começa (ou continua) a tocar; chamadas repetidas não fazem nada
function MenuMusic.play()
	if music then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "MenuMusic"
	sound.SoundId = MenuMusic.Id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	music = sound
	tween(sound, 2.5, { Volume = target() })
end

function MenuMusic.stop(fade: number?)
	local sound = music
	if not sound then
		return
	end
	music = nil
	decor = false
	tween(sound, fade or 2, { Volume = 0 }).Completed:Once(function()
		sound:Destroy()
	end)
end

-- modo passear/decoração: +30% de volume
function MenuMusic.setDecor(on: boolean)
	decor = on
	if music then
		tween(music, 1, { Volume = target() })
	end
end

return MenuMusic
