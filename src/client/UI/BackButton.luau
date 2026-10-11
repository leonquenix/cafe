--!strict
-- Botãozinho com uma seta no canto esquerdo da tela (volta pro menu inicial).

local TweenService = game:GetService("TweenService")

local PixelArt = require(script.Parent.Parent.Art.PixelArt)
local Sprites = require(script.Parent.Parent.Art.Sprites)
local Theme = require(script.Parent.Theme)

local BackButton = {}

local gui: ScreenGui

function BackButton.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "BackButton"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = playerGui
end

function BackButton.show(onBack: () -> ())
	local button = Instance.new("TextButton")
	button.Name = "Back"
	button.Text = ""
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromOffset(18, 18)
	button.Size = UDim2.fromOffset(56, 56)
	button.BackgroundColor3 = Theme.WoodDark
	button.AutoButtonColor = true
	button.Parent = gui
	Theme.corner(button, 0.3)
	Theme.stroke(button, 3)
	local arrow = PixelArt.draw(Sprites.ArrowLeft)
	arrow.Size = UDim2.fromScale(0.6, 0.6)
	arrow.Parent = button
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = button
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local used = false
	button.Activated:Connect(function()
		if used then
			return
		end
		used = true
		local t = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		t.Completed:Once(function()
			button:Destroy()
		end)
		t:Play()
		task.spawn(onBack)
	end)
end

return BackButton
