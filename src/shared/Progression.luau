--!strict
-- Regras de progressão: dias, pagamento por velocidade, XP e desbloqueios.
-- Compartilhado para o cliente conseguir mostrar a mesma conta que o servidor faz.

local Recipes = require(script.Parent.Recipes)

local Progression = {}

Progression.OrdersPerDay = 6
Progression.DayBonusXp = 25

-- Tempo (s) contado a partir do pedido. É o mesmo pra toda receita:
-- receitas mais complexas pagam mais, mas o relógio não fica mais generoso.
Progression.GraceTime = 0.8 -- compensa a animação do balão antes do minigame abrir
Progression.FastTime = 8 -- até aqui: pagamento máximo
Progression.SlowTime = 32 -- a partir daqui: pagamento mínimo
Progression.MaxMultiplier = 1.5
Progression.MinMultiplier = 0.5

-- tier 3..0
Progression.TierNames = {
	[0] = "Demorou...",
	[1] = "Ufa!",
	[2] = "Bom trabalho!",
	[3] = "Relâmpago!",
}

function Progression.multiplier(elapsed: number): number
	local a = math.clamp((elapsed - Progression.FastTime) / (Progression.SlowTime - Progression.FastTime), 0, 1)
	return Progression.MaxMultiplier + (Progression.MinMultiplier - Progression.MaxMultiplier) * a
end

function Progression.tier(multiplier: number): number
	if multiplier >= 1.3 then
		return 3
	elseif multiplier >= 0.95 then
		return 2
	elseif multiplier >= 0.7 then
		return 1
	end
	return 0
end

-- Retorna (dinheiro, tier) para uma bebida entregue após `elapsed` segundos.
function Progression.payout(drinkId: string, elapsed: number): (number, number)
	local mult = Progression.multiplier(elapsed)
	local price = Recipes.Drinks[drinkId].Price
	return math.max(1, math.floor(price * mult + 0.5)), Progression.tier(mult)
end

function Progression.orderXp(tier: number): number
	return 10 + tier * 5
end

function Progression.xpToNext(level: number): number
	return 100 + (level - 1) * 75
end

-- Aplica XP ganho: retorna (novoLevel, novoXpDentroDoLevel)
function Progression.applyXp(level: number, xp: number, gained: number): (number, number)
	xp += gained
	while xp >= Progression.xpToNext(level) do
		xp -= Progression.xpToNext(level)
		level += 1
	end
	return level, xp
end

function Progression.drinksForLevel(level: number): { string }
	local list = {}
	for _, id in Recipes.DrinkOrder do
		if Recipes.Drinks[id].Level <= level then
			table.insert(list, id)
		end
	end
	return list
end

-- Sorteia uma bebida da lista, com mais chance para as receitas recém-aprendidas.
function Progression.randomFrom(list: { string }, level: number, rng: Random): string
	local total = 0
	local weights = {}
	for i, id in list do
		local age = level - Recipes.Drinks[id].Level
		weights[i] = if age == 0 then 3 elseif age == 1 then 2 else 1
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i, id in list do
		roll -= weights[i]
		if roll <= 0 then
			return id
		end
	end
	return list[#list]
end

function Progression.randomDrink(level: number, rng: Random): string
	return Progression.randomFrom(Progression.drinksForLevel(level), level, rng)
end

Progression.MinMenu = 3

-- Cardápio efetivo: receitas escolhidas que estão desbloqueadas (ou todas, se faltar)
function Progression.effectiveMenu(chosen: { string }, level: number): { string }
	local unlocked = Progression.drinksForLevel(level)
	local list = {}
	for _, id in Recipes.DrinkOrder do
		if table.find(chosen, id) and Recipes.Drinks[id].Level <= level then
			table.insert(list, id)
		end
	end
	if #list < math.min(Progression.MinMenu, #unlocked) then
		return unlocked
	end
	return list
end

function Progression.ingredientUnlocked(id: string, level: number): boolean
	return Recipes.Ingredients[id].Level <= level
end

-- O que foi desbloqueado ao sair de `fromLevel` e chegar em `toLevel`
function Progression.unlocksBetween(fromLevel: number, toLevel: number): ({ string }, { string })
	local drinks, ingredients = {}, {}
	for _, id in Recipes.DrinkOrder do
		local lv = Recipes.Drinks[id].Level
		if lv > fromLevel and lv <= toLevel then
			table.insert(drinks, id)
		end
	end
	for _, id in Recipes.IngredientOrder do
		local lv = Recipes.Ingredients[id].Level
		if lv > fromLevel and lv <= toLevel then
			table.insert(ingredients, id)
		end
	end
	return drinks, ingredients
end

return Progression
