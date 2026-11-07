--!strict
-- Bolinha "!" do botão do livro de receitas: aparece quando algum marco de conquista (bebida ou doce)
-- está pronto para resgatar e some quando todos forem resgatados. Usada no livro do HUD (expediente),
-- no do menu "Antes de abrir" e nas abas Bebidas/Doces do próprio livro (kind = só aquela aba).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Achievements = require(script.Parent.Parent.Achievements)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children

return function(scope: any, kind: Achievements.Kind?): Frame
	return scope:New("Frame")({
		Name = "Alert",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.9, 0.1),
		Size = UDim2.fromScale(0.36, 0.36),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, -- redonda mesmo em botão mais largo que alto
		BackgroundColor3 = Theme.Rose,
		ZIndex = 3,
		Visible = scope:Computed(function(use)
			local claims = use(State.Claims)
			local drinks = if kind ~= "Pastry" then Achievements.pending("Drink", use(State.Stats), claims) else 0
			local pastries = if kind ~= "Drink" then Achievements.pending("Pastry", use(State.PastryStats), claims) else 0
			return drinks + pastries > 0
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0.5, 0) }),
			scope:New("UIStroke")({ Thickness = 2, Color = Theme.Ink }),
			scope:New("TextLabel")({
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Theme.Font,
				TextScaled = true,
				TextColor3 = Theme.Paper,
				Text = "!",
				ZIndex = 4,
			}),
		},
	}) :: Frame
end
