--!strict
-- Bolinha "!" do botão do livro de receitas: aparece quando tem recompensa de maestria para coletar
-- e some quando todas forem resgatadas. Usada no livro do HUD (expediente) e no do menu "Antes de abrir".

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Theme)

local Children = Fusion.Children

return function(scope: any): Frame
	return scope:New("Frame")({
		Name = "Alert",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.9, 0.1),
		Size = UDim2.fromScale(0.36, 0.36),
		SizeConstraint = Enum.SizeConstraint.RelativeYY, -- redonda mesmo em botão mais largo que alto
		BackgroundColor3 = Theme.Rose,
		ZIndex = 3,
		Visible = scope:Computed(function(use)
			local stats, mastered = use(State.Stats), use(State.Mastered)
			for id in Recipes.Drinks do
				if not mastered[id] and (stats[id] or 0) >= Recipes.masteryTarget(id) then
					return true
				end
			end
			return false
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
