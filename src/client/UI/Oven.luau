--!strict
-- Forno: quando o pedido vem com doce, aparece este painel.
-- "Assar" -> um ponteiro corre pela barra -> "Tirar!" na hora certa.
-- Zona dourada = perfeito, bordas = ok, começo = cru, fim = queimado.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Theme = require(script.Parent.Theme)

local Children, OnEvent, peek = Fusion.Children, Fusion.OnEvent, Fusion.peek

-- zonas da barra (fração do tempo de forno)
local RAW_END = 0.5
local PERFECT_START, PERFECT_END = 0.62, 0.82
local BURN_START = 0.9

export type Oven = {
	Root: Frame,
	reset: (self: Oven) -> (),
}

local Oven = {}

function Oven.new(scope: any, pastryId: any, quality: any, phase: any): Oven
	local status = scope:Value("idle") -- idle | baking | done | failed
	local needle = scope:Value(0)
	local message = scope:Value("")
	local bakeStart = 0

	local visible = scope:Computed(function(use)
		return use(pastryId) ~= "" and use(phase) ~= "Idle"
	end)
	local pos = scope:Spring(
		scope:Computed(function(use)
			return if use(visible) then UDim2.new(0.62, -36, 0.76, -52) else UDim2.new(0.62, -36, 1.6, 0)
		end),
		22,
		0.8
	)

	local ovenArt = PixelArt.draw(Sprites.Oven)
	ovenArt.Size = UDim2.fromScale(1, 1)

	-- doce que aparece "dentro" do forno / pronto no prato
	local pastryHolder = scope:New("Frame")({
		Name = "Pastry",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.4, 0.4),
		ZIndex = 3,
	})
	local function refreshPastry()
		pastryHolder:ClearAllChildren()
		local id = peek(pastryId)
		if id ~= "" then
			local art = PixelArt.draw((Sprites :: any)[Catalog.Pastries[id].Icon], 3)
			art.Parent = pastryHolder
		end
	end
	scope:Observer(pastryId):onBind(refreshPastry)

	local function zone(x0: number, x1: number, color: Color3): Frame
		return scope:New("Frame")({
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x0, 0),
			Size = UDim2.fromScale(x1 - x0, 1),
			BackgroundColor3 = color,
		})
	end

	local function finish(result: number)
		if result > 0 then
			quality:set(result)
			status:set("done")
			message:set(if result == 2 then "Perfeito!" else "Tá bom!")
		else
			status:set("failed")
			message:set(if peek(needle) >= BURN_START then "Queimou!" else "Ainda cru!")
		end
	end

	local function onButton()
		local s = peek(status)
		if peek(phase) ~= "Making" and peek(phase) ~= "Ready" then
			return
		end
		if s == "idle" or s == "failed" then
			status:set("baking")
			message:set("")
			needle:set(0)
			bakeStart = os.clock()
		elseif s == "baking" then
			local t = peek(needle)
			if t >= PERFECT_START and t <= PERFECT_END then
				finish(2)
			elseif t >= RAW_END and t < BURN_START then
				finish(1)
			else
				finish(0)
			end
		end
	end

	RunService.RenderStepped:Connect(function()
		if peek(status) ~= "baking" then
			return
		end
		local id = peek(pastryId)
		if id == "" then
			return
		end
		local t = (os.clock() - bakeStart) / Catalog.Pastries[id].BakeTime
		needle:set(math.min(t, 1))
		if t >= 1 then
			finish(0)
		end
	end)

	local glow = scope:Computed(function(use)
		return if use(status) == "baking" then 0.35 else 1
	end)

	local root = scope:New("Frame")({
		Name = "Oven",
		AnchorPoint = Vector2.new(1, 1),
		Position = pos,
		Size = UDim2.fromScale(0.17, 0.34),
		BackgroundColor3 = Theme.Wood,
		[Children] = {
			scope:New("UIAspectRatioConstraint")({ AspectRatio = 0.78 }),
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			scope:New("UIStroke")({ Thickness = 4, Color = Theme.Ink }),
			scope:New("Frame")({
				Name = "Inner",
				BackgroundColor3 = Theme.Paper,
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.new(1, -16, 1, -16),
				[Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.02),
						Size = UDim2.fromScale(0.9, 0.12),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Ink,
						Text = scope:Computed(function(use)
							local id = use(pastryId)
							return if id ~= "" then `Forno: {Catalog.Pastries[id].Name}` else "Forno"
						end),
					}),
					scope:New("Frame")({
						Name = "OvenArt",
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.1, 0.15),
						Size = UDim2.fromScale(0.8, 0.42),
						[Children] = {
							ovenArt,
							scope:New("Frame")({
								Name = "Glow",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.55),
								Size = UDim2.fromScale(0.5, 0.35),
								BackgroundColor3 = Color3.fromRGB(255, 200, 90),
								BackgroundTransparency = glow,
								ZIndex = 2,
							}),
							pastryHolder,
						},
					}),
					-- barra de tempo
					scope:New("Frame")({
						Name = "Bar",
						Position = UDim2.fromScale(0.08, 0.6),
						Size = UDim2.fromScale(0.84, 0.08),
						BackgroundColor3 = Theme.PaperShade,
						ClipsDescendants = false,
						[Children] = {
							scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
							zone(0, RAW_END, Color3.fromRGB(214, 206, 196)),
							zone(RAW_END, PERFECT_START, Theme.Mustard),
							zone(PERFECT_START, PERFECT_END, Theme.Sage),
							zone(PERFECT_END, BURN_START, Theme.Mustard),
							zone(BURN_START, 1, Color3.fromRGB(90, 60, 50)),
							scope:New("Frame")({
								Name = "Needle",
								BorderSizePixel = 0,
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = scope:Computed(function(use)
									return UDim2.fromScale(use(needle), 0.5)
								end),
								Size = UDim2.new(0, 5, 1.8, 0),
								BackgroundColor3 = Theme.Ink,
								ZIndex = 3,
							}),
						},
					}),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.05, 0.7),
						Size = UDim2.fromScale(0.9, 0.09),
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = scope:Computed(function(use)
							return if use(status) == "failed" then Theme.Rose else Theme.SageDark
						end),
						Text = message,
					}),
					scope:New("TextButton")({
						Name = "Button",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.fromScale(0.5, 0.97),
						Size = UDim2.fromScale(0.84, 0.15),
						BackgroundColor3 = scope:Computed(function(use)
							local s = use(status)
							return if s == "baking" then Theme.Rose elseif s == "done" then Theme.PaperShade else Theme.SageDark
						end),
						AutoButtonColor = true,
						Font = Theme.Font,
						TextScaled = true,
						TextColor3 = Theme.Paper,
						Active = scope:Computed(function(use)
							return use(status) ~= "done"
						end),
						Text = scope:Computed(function(use)
							local s = use(status)
							return if s == "baking" then "Tirar!" elseif s == "done" then "Pronto!" elseif s == "failed" then "Assar de novo" else "Assar"
						end),
						[Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0.3, 0) }),
							scope:New("UIStroke")({ Thickness = 3, Color = Theme.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
							scope:New("UIPadding")({ PaddingTop = UDim.new(0.18, 0), PaddingBottom = UDim.new(0.18, 0) }),
						},
						[OnEvent("Activated")] = onButton,
					}),
				},
			}),
		},
	}) :: Frame

	-- tremidinha ao terminar
	scope:Observer(status):onChange(function()
		local s = peek(status)
		if s == "done" or s == "failed" then
			local r = root
			task.spawn(function()
				for _, a in { 5, -4, 2, 0 } do
					TweenService:Create(r, TweenInfo.new(0.05), { Rotation = a }):Play()
					task.wait(0.05)
				end
			end)
		end
	end)

	local self = { Root = root } :: any
	function self.reset(_self: Oven)
		status:set("idle")
		needle:set(0)
		message:set("")
		quality:set(0)
	end
	return self :: Oven
end

return Oven
