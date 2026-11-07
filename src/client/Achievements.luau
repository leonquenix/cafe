--!strict
-- Conquistas do livro de receitas no cliente: marcos de "sirva N vezes" (Recipes.Milestones) de cada
-- bebida e de cada doce. Junta as contagens e os resgates do State para o livro, a bolinha "!" e os avisos.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

local Achievements = {}

export type Kind = "Drink" | "Pastry"

-- Receitas de cada aba do livro, na ordem
function Achievements.ids(kind: Kind): { string }
	return if kind == "Drink" then Recipes.DrinkOrder else Catalog.PastryOrder
end

function Achievements.name(kind: Kind, id: string): string
	return if kind == "Drink" then Recipes.Drinks[id].Name else Catalog.Pastries[id].Name
end

-- Quantos marcos estão prontos para resgatar numa aba (stats = contagens daquela aba, claims = todos os resgates)
function Achievements.pending(kind: Kind, stats: { [string]: number }, claims: { [string]: number }): number
	local total = 0
	for _, id in Achievements.ids(kind) do
		local count, claimed = stats[id] or 0, claims[id] or 0
		total += math.max(0, Recipes.milestonesReached(count) - claimed)
	end
	return total
end

return Achievements
