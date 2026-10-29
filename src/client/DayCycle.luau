--!strict
-- Iluminação ao longo do dia (só no cliente: cada jogador tem o seu próprio dia).
-- Manhã -> fim de tarde conforme os pedidos são entregues; noite quando o dia acaba.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local rgb = Color3.fromRGB

type Preset = {
	ClockTime: number,
	Brightness: number,
	ExposureCompensation: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Tint: Color3,
	Lamps: number, -- multiplicador das luminárias
}

local PRESETS: { [string]: Preset } = {
	Morning = {
		ClockTime = 8.6,
		Brightness = 1.6,
		ExposureCompensation = -0.3,
		Ambient = rgb(78, 70, 64),
		OutdoorAmbient = rgb(120, 116, 110),
		Tint = rgb(250, 248, 240),
		Lamps = 0.5,
	},
	Evening = {
		ClockTime = 17.4,
		Brightness = 1.3,
		ExposureCompensation = -0.35,
		Ambient = rgb(70, 56, 48),
		OutdoorAmbient = rgb(110, 96, 86),
		Tint = rgb(255, 238, 218),
		Lamps = 1,
	},
	Night = {
		ClockTime = 20.8,
		Brightness = 0.15,
		ExposureCompensation = -0.75,
		Ambient = rgb(28, 24, 38),
		OutdoorAmbient = rgb(26, 30, 56),
		Tint = rgb(214, 206, 255),
		Lamps = 1.35,
	},
}

-- Clima do tema da fachada (client/OutsideTheme): ajusta qualquer momento do dia por cima do preset
export type Weather = {
	Brightness: number, -- multiplicador
	Exposure: number, -- somado
	Tint: Color3, -- puxa o tint e a luz de fora para esta cor...
	Amount: number, -- ...nesta proporção (0-1)
}

local DayCycle = {}

local current: Preset? = nil
local weather: Weather? = nil

local lamps: { { Light: PointLight, Base: number } } = {}
local lampFactor = Instance.new("NumberValue")
lampFactor.Value = 1

local function collectLamps()
	if #lamps > 0 then
		return
	end
	local cafe = workspace:WaitForChild("Cafe", 30)
	local lights = cafe and cafe:WaitForChild("Lights", 10)
	if not lights then
		return
	end
	for _, l in lights:GetDescendants() do
		if l:IsA("PointLight") then
			table.insert(lamps, { Light = l, Base = l.Brightness })
		end
	end
end

lampFactor.Changed:Connect(function(v)
	for _, lamp in lamps do
		lamp.Light.Brightness = lamp.Base * v
	end
end)

local function lerpPreset(a: Preset, b: Preset, t: number): Preset
	return {
		ClockTime = a.ClockTime + (b.ClockTime - a.ClockTime) * t,
		Brightness = a.Brightness + (b.Brightness - a.Brightness) * t,
		ExposureCompensation = a.ExposureCompensation + (b.ExposureCompensation - a.ExposureCompensation) * t,
		Ambient = a.Ambient:Lerp(b.Ambient, t),
		OutdoorAmbient = a.OutdoorAmbient:Lerp(b.OutdoorAmbient, t),
		Tint = a.Tint:Lerp(b.Tint, t),
		Lamps = a.Lamps + (b.Lamps - a.Lamps) * t,
	}
end

local function withWeather(p: Preset): Preset
	local w = weather
	if not w then
		return p
	end
	local out = table.clone(p)
	out.Brightness = p.Brightness * w.Brightness
	out.ExposureCompensation = p.ExposureCompensation + w.Exposure
	out.OutdoorAmbient = p.OutdoorAmbient:Lerp(w.Tint:Lerp(Color3.new(0, 0, 0), 0.45), w.Amount)
	out.Tint = p.Tint:Lerp(w.Tint, w.Amount)
	return out
end

local function apply(base: Preset, duration: number)
	current = base
	local p = withWeather(base)
	collectLamps()
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	if duration <= 0 then
		Lighting.ClockTime = p.ClockTime
		Lighting.Brightness = p.Brightness
		Lighting.ExposureCompensation = p.ExposureCompensation
		Lighting.Ambient = p.Ambient
		Lighting.OutdoorAmbient = p.OutdoorAmbient
		lampFactor.Value = p.Lamps
	else
		TweenService:Create(Lighting, info, {
			ClockTime = p.ClockTime,
			Brightness = p.Brightness,
			ExposureCompensation = p.ExposureCompensation,
			Ambient = p.Ambient,
			OutdoorAmbient = p.OutdoorAmbient,
		}):Play()
		TweenService:Create(lampFactor, info, { Value = p.Lamps }):Play()
	end
	local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if cc then
		if duration <= 0 then
			cc.TintColor = p.Tint
		else
			TweenService:Create(cc, info, { TintColor = p.Tint }):Play()
		end
	end
end

-- progress: 0 = começo do dia, 1 = último pedido entregue
function DayCycle.setProgress(progress: number, duration: number?)
	apply(lerpPreset(PRESETS.Morning, PRESETS.Evening, math.clamp(progress, 0, 1)), duration or 2)
end

function DayCycle.night(duration: number?)
	apply(PRESETS.Night, duration or 3)
end

function DayCycle.morning(duration: number?)
	apply(PRESETS.Morning, duration or 0)
end

-- nil = sem clima (tema original)
function DayCycle.setWeather(w: Weather?, duration: number?)
	weather = w
	if current then
		apply(current, duration or 1.5)
	end
end

return DayCycle
