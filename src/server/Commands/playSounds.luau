-- Toca em sequência os sons de clique, de dinheiro e do fim do dia, com os volumes do jogo.
-- Roda só no cliente (os sons são locais); lê os ids/volumes direto dos módulos Sfx e DaySummary.
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local GAP = 0.5 -- silêncio entre um som e outro
local MAX_LENGTH = 4 -- gravações longas (placar, grilos) tocam só um trecho

-- espera a gravação acabar (ou corta com fade se for longa demais)
local function waitFor(sound: Sound, start: number, length: number?)
	local t0 = os.clock()
	while not sound.IsLoaded and os.clock() - t0 < 3 do
		task.wait()
	end
	local duration = math.min(length or (sound.TimeLength - start) / sound.PlaybackSpeed, MAX_LENGTH)
	task.wait(math.max(duration, 0.2))
	if sound.Parent and sound.IsPlaying then
		local t = TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 })
		t.Completed:Once(function()
			sound:Destroy()
		end)
		t:Play()
	end
	task.wait(GAP)
end

-- mesmo jeito que o placar toca os sons dele (agudos abafados nos "soft")
local function playDay(id: string, volume: number, speed: number?, soft: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.Name = "PlaySoundsTest"
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	if soft then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = -2
		eq.MidGain = 0
		eq.HighGain = -6
		eq.Parent = sound
	end
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

local running = false

return {
	Name = "playSounds",
	Aliases = { "sounds" },
	Description = "Toca em sequência os sons de clique, de dinheiro e do fim do dia (com os volumes do jogo).",
	Group = "CafeAdmin",
	Args = {},
	ClientRun = function(context)
		if running then
			return "Já está tocando a sequência."
		end
		local client = (Players.LocalPlayer :: any).PlayerScripts:WaitForChild("Client")
		local Sfx = require(client.Sfx) :: any
		local DaySummary = require(client.UI.DaySummary) :: any

		local function sfx(name: string, label: string)
			return function()
				context:Reply(label)
				local def = Sfx.Sounds[name]
				waitFor(Sfx.play(name), def.Start or 0, def.Length)
			end
		end
		local function day(label: string, id: string, volume: number, speed: number?, soft: boolean?)
			return function()
				context:Reply(label)
				waitFor(playDay(id, volume, speed, soft), 0)
			end
		end

		local steps = {
			sfx("Click", "Clique: pop de bolha"),
			sfx("RadioTune", "Ícone do rádio: estática"),
			sfx("RadioOff", "Fechar o rádio"),
			sfx("BookOpen", "Ícone do livro: abrir"),
			sfx("BookClose", "Livro: fechar"),
			sfx("Coins", "Dinheiro: ka-ching do pagamento"),
			sfx("CoinsCount", "Dinheiro: moedas do placar"),
			sfx("Cash", "Dinheiro: compra na loja"),
			day("Fim do dia: dia bom (conquista)", DaySummary.GoodSound, DaySummary.GoodVolume, 1, true),
			day("Fim do dia: dia ruim", DaySummary.BadSound, DaySummary.BadVolume, 1, true),
			day("Fim do dia: nível novo", DaySummary.LevelUpSound, DaySummary.LevelUpVolume, DaySummary.LevelUpSpeed, true),
			day("Fim do dia: grilos", DaySummary.NightSound, DaySummary.NightVolume),
		}

		running = true
		task.spawn(function()
			for _, step in steps do
				local ok, err = pcall(step)
				if not ok then
					context:Reply(`Erro: {err}`, Color3.fromRGB(255, 120, 120))
				end
			end
			running = false
			context:Reply("Fim da sequência.")
		end)
		return `Tocando {#steps} sons em sequência...`
	end,
}
