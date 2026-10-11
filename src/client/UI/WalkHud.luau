--!strict
-- Modo andar: dica de controles + botão para voltar ao menu.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)

local WalkHud = {}

local gui: ScreenGui

function WalkHud.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "WalkHud"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	gui.Parent = playerGui
end

function WalkHud.show(onBack: () -> (), hintText: string?, buttonText: string?)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 18)
	panel.Size = UDim2.fromOffset(460, 64)
	panel.BackgroundColor3 = Theme.Paper
	panel.Parent = gui
	Theme.corner(panel, 0.5)
	Theme.stroke(panel, 3)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = panel

	local hint = Theme.label(hintText or (if UserInputService.TouchEnabled then "Passeie pelo café!" else "Passeie pelo café! (WASD + espaço)"), Theme.Ink)
	hint.Position = UDim2.fromOffset(22, 16)
	hint.Size = UDim2.new(1, -220, 0, 32)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = panel

	local back = Instance.new("TextButton")
	back.AnchorPoint = Vector2.new(1, 0.5)
	back.Position = UDim2.new(1, -10, 0.5, 0)
	back.Size = UDim2.fromOffset(180, 46)
	back.BackgroundColor3 = Theme.SageDark
	back.Font = Theme.Font
	back.TextScaled = true
	back.TextColor3 = Theme.Paper
	back.Text = buttonText or "Voltar ao menu"
	back.Parent = panel
	Theme.corner(back, 0.5)
	Theme.stroke(back, 3)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.PaddingLeft = UDim.new(0.08, 0)
	pad.PaddingRight = UDim.new(0.08, 0)
	pad.Parent = back

	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local used = false
	back.Activated:Connect(function()
		if used then
			return
		end
		used = true
		local t = TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		t.Completed:Once(function()
			panel:Destroy()
		end)
		t:Play()
		task.spawn(onBack)
	end)
end

return WalkHud
