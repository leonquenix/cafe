--!strict
-- Efeitos sonoros do cliente: "pop" de bolha no clique de todos os botões da UI
-- e os sons do preparo (copo, colher mexendo, forno). Tudo local, para resposta imediata.
-- Assets da Creator Store (Roblox / Pro Sound Effects); volumes medidos no playtest
-- (PlaybackLoudness) para ficarem um pouco abaixo da música/rádio e dos sons de fim do dia.
-- Botão que já tem som próprio (ou não é um "clique" de verdade) leva o atributo NoClickSound;
-- o atributo ClickSound troca o pop por outro som da lista (ex.: "BookOpen").

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sfx = {}

type Def = { Id: string, Volume: number, Speed: number?, Start: number? }

Sfx.Sounds = {
	-- clique de botão: bolha estourando (Roblox GUI - Bubble)
	Click = { Id = "rbxassetid://17208204604", Volume = 0.45 } :: Def,
	-- copo vazio chegando na bancada (caneca de cerâmica na mesa de madeira)
	CupDown = { Id = "rbxassetid://9117037749", Volume = 0.8 } :: Def,
	-- ingrediente despejado no copo (corta no fim do despejo)
	Pour = { Id = "rbxassetid://9117865991", Volume = 1.3, Start = 0.2 } :: Def,
	-- colher de chá girando na xícara (em loop enquanto o jogador mexe)
	Stir = { Id = "rbxassetid://9119946075", Volume = 1 } :: Def,
	-- bebida pronta: tilintar de vidro
	Ready = { Id = "rbxassetid://9114619221", Volume = 0.9 } :: Def,
	-- jogar fora: líquido descendo pelo ralo
	Trash = { Id = "rbxassetid://9125498766", Volume = 0.6 } :: Def,
	-- servir: xícara de porcelana pousando
	Serve = { Id = "rbxassetid://9119949554", Volume = 0.65 } :: Def,
	-- forno: assadeira entrando na grade e porta fechando
	OvenIn = { Id = "rbxassetid://9116642361", Volume = 0.55 } :: Def,
	OvenDoor = { Id = "rbxassetid://9117179507", Volume = 0.5 } :: Def,
	-- tirar do forno (porta abrindo) e o prato pousando no balcão
	OvenOut = { Id = "rbxassetid://9117180051", Volume = 0.8 } :: Def,
	Plate = { Id = "rbxassetid://9114076433", Volume = 1.2 } :: Def,
	-- loja: compra efetivada (caixa registradora "ka-ching", pula o silêncio do começo)
	Cash = { Id = "rbxassetid://7112275565", Volume = 0.8, Start = 0.4 } :: Def,
	-- loja: já comprado, no limite, nível baixo ou sem moedas (negação curtinha)
	Denied = { Id = "rbxassetid://17208353912", Volume = 0.18 } :: Def,
	-- cliente pagou / placar soma o faturamento: moedas caindo na caixa
	Coins = { Id = "rbxassetid://9117243937", Volume = 0.45 } :: Def,
	-- doce entregue no popup do forno: sininho de confirmação
	Deliver = { Id = "rbxassetid://17208361335", Volume = 0.3 } :: Def,
	-- ícone do rádio: sintonizando pela faixa AM
	RadioTune = { Id = "rbxassetid://9118028337", Volume = 0.9 } :: Def,
	-- livro de receitas abrindo e virando a página (pula o começo quase mudo)
	BookOpen = { Id = "rbxassetid://9118835414", Volume = 0.9, Start = 0.6 } :: Def,
}

-- loop da colher: só o trecho em que ela gira (sem o começo/fim mudos)
local STIR_LOOP = NumberRange.new(0.2, 7.4)
local STIR_FADE = 0.15 -- some rápido quando o dedo para

local folder: Folder
local templates: { [string]: Sound } = {}
local lastClick = 0

local function template(name: string): Sound
	local existing = templates[name]
	if existing then
		return existing
	end
	local def = (Sfx.Sounds :: any)[name] :: Def
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Speed or 1
	sound.Parent = folder
	templates[name] = sound
	return sound
end

-- toca uma cópia (permite sobrepor o mesmo som) e devolve para quem quiser cortar
function Sfx.play(name: string, volumeScale: number?): Sound
	local base = template(name)
	local def = (Sfx.Sounds :: any)[name] :: Def
	local sound = base:Clone()
	sound.Volume = def.Volume * (volumeScale or 1)
	sound.TimePosition = def.Start or 0
	sound.Parent = folder
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return sound
end

-- some com um som tocando (ex.: o despejo acabou antes da gravação)
function Sfx.fadeOut(sound: Sound, time: number?)
	local t = TweenService:Create(sound, TweenInfo.new(time or 0.15), { Volume = 0 })
	t.Completed:Once(function()
		sound:Destroy()
	end)
	t:Play()
end

------------------------------------------------------------------ colher mexendo

local stir: Sound? = nil
local stirTween: Tween? = nil
local stirToken = 0

-- chamado a cada movimento da colher: liga o loop e mantém audível enquanto mexe
function Sfx.stirring()
	stirToken += 1
	local token = stirToken
	local sound = stir
	if not sound then
		local s = template("Stir"):Clone()
		s.Name = "Stirring"
		s.Looped = true
		s.PlaybackRegionsEnabled = true
		s.LoopRegion = STIR_LOOP
		s.TimePosition = STIR_LOOP.Min
		s.Volume = 0
		s.Parent = folder
		s:Play()
		stir = s
		sound = s
	end
	assert(sound)
	if stirTween then
		stirTween:Cancel()
	end
	sound.Volume = Sfx.Sounds.Stir.Volume
	-- se não vier outro movimento logo, a colher "para"
	task.delay(0.12, function()
		if token == stirToken then
			Sfx.stopStirring()
		end
	end)
end

function Sfx.stopStirring()
	stirToken += 1
	local sound = stir
	if not sound then
		return
	end
	if stirTween then
		stirTween:Cancel()
	end
	local t = TweenService:Create(sound, TweenInfo.new(STIR_FADE), { Volume = 0 })
	stirTween = t
	t:Play()
end

------------------------------------------------------------------ clique dos botões

local hooked: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function hook(button: GuiButton)
	if hooked[button] then
		return
	end
	hooked[button] = true
	button.Activated:Connect(function()
		if button:GetAttribute("NoClickSound") then
			return
		end
		-- um clique = um pop (evita somar quando dois botões reagem juntos)
		local now = os.clock()
		if now - lastClick < 0.05 then
			return
		end
		lastClick = now
		local custom = button:GetAttribute("ClickSound")
		Sfx.play(if type(custom) == "string" and (Sfx.Sounds :: any)[custom] then custom else "Click")
	end)
end

local function hookTree(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiButton") then
			hook(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d:IsA("GuiButton") then
			hook(d)
		end
	end)
end

function Sfx.init(playerGui: PlayerGui)
	folder = Instance.new("Folder")
	folder.Name = "Sfx"
	folder.Parent = SoundService
	-- já carrega todos para o primeiro toque não sair atrasado
	for name in Sfx.Sounds do
		template(name)
	end
	hookTree(playerGui)
end

return Sfx
