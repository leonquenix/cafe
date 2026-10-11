--!strict
-- Ingredientes, bebidas e validação de receitas (compartilhado cliente/servidor).
-- "Level" = nível do jogador em que o item é desbloqueado.

export type Ingredient = {
	Id: string,
	Name: string,
	Liquid: Color3, -- cor da camada no copo
	Level: number,
}

export type Drink = {
	Id: string,
	Name: string,
	Ingredients: { [string]: number },
	Mix: boolean,
	Price: number,
	Level: number,
	Secret: boolean?, -- fora do cardápio/livro: só um cliente específico pede
}

local Recipes = {}

Recipes.MaxPortions = 4

Recipes.IngredientOrder = { "Coffee", "Milk", "Chocolate", "Caramel", "Matcha", "Cinnamon", "Cream" }

Recipes.Ingredients = {
	Coffee = { Id = "Coffee", Name = "Café", Liquid = Color3.fromRGB(74, 44, 30), Level = 1 },
	Milk = { Id = "Milk", Name = "Leite", Liquid = Color3.fromRGB(250, 243, 228), Level = 1 },
	Chocolate = { Id = "Chocolate", Name = "Chocolate", Liquid = Color3.fromRGB(110, 60, 38), Level = 1 },
	Caramel = { Id = "Caramel", Name = "Caramelo", Liquid = Color3.fromRGB(214, 142, 56), Level = 2 },
	Matcha = { Id = "Matcha", Name = "Matcha", Liquid = Color3.fromRGB(128, 170, 78), Level = 4 },
	Cinnamon = { Id = "Cinnamon", Name = "Canela", Liquid = Color3.fromRGB(176, 104, 58), Level = 5 },
	Cream = { Id = "Cream", Name = "Chantilly", Liquid = Color3.fromRGB(255, 250, 240), Level = 8 },
} :: { [string]: Ingredient }

Recipes.DrinkOrder = {
	"Espresso",
	"Macchiato",
	"HotChocolate",
	"Latte",
	"CaramelMacchiato",
	"Mocha",
	"MatchaLatte",
	"CinnamonCappuccino",
	"CinnamonChocolate",
	"Vienna",
	"SwissChocolate",
	"CaramelSupreme",
	"MatchaCloud",
	"HouseSpecial",
}

-- Bebidas secretas (easter egg): não entram no cardápio, no livro nem na maestria
Recipes.SecretDrinkOrder = { "TripleMilk" }

local function drink(id: string, name: string, level: number, price: number, mix: boolean, ingredients: { [string]: number }): Drink
	return { Id = id, Name = name, Level = level, Price = price, Mix = mix, Ingredients = ingredients }
end

Recipes.Drinks = {
	Espresso = drink("Espresso", "Espresso", 1, 8, false, { Coffee = 1 }),
	Macchiato = drink("Macchiato", "Macchiato", 1, 12, true, { Coffee = 1, Milk = 1 }),
	HotChocolate = drink("HotChocolate", "Chocolate Quente", 1, 12, true, { Chocolate = 1, Milk = 1 }),
	Latte = drink("Latte", "Latte", 2, 15, true, { Coffee = 1, Milk = 2 }),
	Mocha = drink("Mocha", "Mocha", 3, 18, true, { Coffee = 1, Chocolate = 1, Milk = 1 }),
	CaramelMacchiato = drink("CaramelMacchiato", "Caramel Macchiato", 2, 20, true, { Coffee = 1, Milk = 1, Caramel = 1 }),
	MatchaLatte = drink("MatchaLatte", "Matcha Latte", 4, 18, true, { Matcha = 1, Milk = 1 }),
	CinnamonCappuccino = drink("CinnamonCappuccino", "Cappuccino de Canela", 5, 22, true, { Coffee = 1, Milk = 1, Cinnamon = 1 }),
	CinnamonChocolate = drink("CinnamonChocolate", "Chocolate com Canela", 6, 22, true, { Chocolate = 1, Milk = 1, Cinnamon = 1 }),
	Vienna = drink("Vienna", "Café Vienense", 8, 24, false, { Coffee = 2, Cream = 1 }),
	SwissChocolate = drink("SwissChocolate", "Chocolate Suíço", 10, 26, true, { Chocolate = 2, Milk = 1, Cream = 1 }),
	CaramelSupreme = drink("CaramelSupreme", "Caramelo Supremo", 12, 30, true, { Coffee = 1, Milk = 1, Caramel = 1, Cream = 1 }),
	MatchaCloud = drink("MatchaCloud", "Matcha Nuvem", 14, 30, true, { Matcha = 1, Milk = 1, Cinnamon = 1, Cream = 1 }),
	HouseSpecial = drink("HouseSpecial", "Especial da Casa", 16, 36, true, { Coffee = 1, Chocolate = 1, Caramel = 1, Cream = 1 }),
} :: { [string]: Drink }

Recipes.Drinks.TripleMilk = drink("TripleMilk", "Leite Triplo", 1, 10, true, { Milk = 3 })
Recipes.Drinks.TripleMilk.Secret = true

export type Modifier = {
	Id: string,
	Name: string,
	Level: number,
	Bonus: number, -- multiplicador extra no pagamento
}

-- Pedidos especiais que mudam a receita base
Recipes.ModifierOrder = { "NoMix", "Double", "ExtraCream" }
Recipes.Modifiers = {
	NoMix = { Id = "NoMix", Name = "Sem mexer", Level = 2, Bonus = 0.25 },
	Double = { Id = "Double", Name = "Dose dupla", Level = 3, Bonus = 0.25 },
	ExtraCream = { Id = "ExtraCream", Name = "Extra chantilly", Level = 8, Bonus = 0.25 },
} :: { [string]: Modifier }

local function totalPortions(ingredients: { [string]: number }): number
	local n = 0
	for _, c in ingredients do
		n += c
	end
	return n
end

function Recipes.modifierApplies(drinkId: string, modifierId: string): boolean
	local d = Recipes.Drinks[drinkId]
	local total = totalPortions(d.Ingredients)
	if modifierId == "NoMix" then
		return d.Mix
	elseif modifierId == "Double" then
		return d.Ingredients.Coffee ~= nil and total < Recipes.MaxPortions
	elseif modifierId == "ExtraCream" then
		return total < Recipes.MaxPortions
	end
	return false
end

-- Ingredientes exigidos e regra de mistura ("required" | "forbidden" | "none")
function Recipes.requirements(drinkId: string, modifierId: string?): ({ [string]: number }, string)
	local d = Recipes.Drinks[drinkId]
	local req = table.clone(d.Ingredients)
	local mixRule = if d.Mix then "required" else "none"
	if modifierId == "NoMix" then
		mixRule = "forbidden"
	elseif modifierId == "Double" then
		req.Coffee = (req.Coffee or 0) + 1
	elseif modifierId == "ExtraCream" then
		req.Cream = (req.Cream or 0) + 1
	end
	return req, mixRule
end

function Recipes.countsMatch(req: { [string]: number }, list: { string }): boolean
	local counts = Recipes.count(list)
	for id, n in counts do
		if req[id] ~= n then
			return false
		end
	end
	for id, n in req do
		if counts[id] ~= n then
			return false
		end
	end
	return true
end

-- O que está errado num pedido: "" (nada) | "Ingredients" | "Unmixed" (pedia mexer) | "Stirred" (pedia sem mexer)
function Recipes.orderProblem(drinkId: string, modifierId: string?, list: { string }, mixed: boolean, stirred: boolean): string
	if not Recipes.Drinks[drinkId] then
		return "Ingredients"
	end
	local req, mixRule = Recipes.requirements(drinkId, modifierId)
	if not Recipes.countsMatch(req, list) then
		return "Ingredients"
	end
	if mixRule == "required" and not mixed then
		return "Unmixed"
	elseif mixRule == "forbidden" and stirred then
		return "Stirred"
	end
	return ""
end

-- Validação completa de um pedido (ingredientes + mistura)
function Recipes.matchesOrder(drinkId: string, modifierId: string?, list: { string }, mixed: boolean, stirred: boolean): boolean
	return Recipes.orderProblem(drinkId, modifierId, list, mixed, stirred) == ""
end

-- Porções na ordem canônica para um pedido (com modificador)
function Recipes.orderPortions(drinkId: string, modifierId: string?): { string }
	local req = Recipes.requirements(drinkId, modifierId)
	local list = {}
	for _, id in Recipes.IngredientOrder do
		for _ = 1, req[id] or 0 do
			table.insert(list, id)
		end
	end
	return list
end

-- Maestria: quantas vezes servir a bebida para virar "Mestre" nela.
-- Receitas mais avançadas aparecem menos, então pedem menos.
Recipes.MasteryBonus = 0.1 -- bebidas dominadas pagam +10% para sempre

function Recipes.masteryTarget(drinkId: string): number
	if Recipes.Drinks[drinkId].Secret then
		return math.huge
	end
	local level = Recipes.Drinks[drinkId].Level
	return if level <= 2 then 50 elseif level <= 4 then 35 else 25
end

function Recipes.masteryReward(drinkId: string): number
	return Recipes.Drinks[drinkId].Price * 15
end

function Recipes.count(list: { string }): { [string]: number }
	local counts = {}
	for _, id in list do
		counts[id] = (counts[id] or 0) + 1
	end
	return counts
end

-- Ordem canônica das porções de uma bebida (usada pra desenhar ícones / o copo pronto)
function Recipes.portions(drinkId: string): { string }
	local d = Recipes.Drinks[drinkId]
	local list = {}
	for _, id in Recipes.IngredientOrder do
		for _ = 1, d.Ingredients[id] or 0 do
			table.insert(list, id)
		end
	end
	return list
end

-- Os ingredientes batem com a receita (ignorando a mistura)?
function Recipes.ingredientsMatch(drinkId: string, list: { string }): boolean
	local d = Recipes.Drinks[drinkId]
	if not d then
		return false
	end
	local counts = Recipes.count(list)
	for id, n in counts do
		if d.Ingredients[id] ~= n then
			return false
		end
	end
	for id, n in d.Ingredients do
		if counts[id] ~= n then
			return false
		end
	end
	return true
end

function Recipes.matches(drinkId: string, list: { string }, mixed: boolean): boolean
	local d = Recipes.Drinks[drinkId]
	if not d or not Recipes.ingredientsMatch(drinkId, list) then
		return false
	end
	return mixed or not d.Mix
end

-- Cor final (média) de uma lista de porções
function Recipes.blend(list: { string }): Color3
	if #list == 0 then
		return Color3.new(1, 1, 1)
	end
	local r, g, b = 0, 0, 0
	for _, id in list do
		local c = Recipes.Ingredients[id].Liquid
		r += c.R
		g += c.G
		b += c.B
	end
	local n = #list
	return Color3.new(r / n, g / n, b / n)
end

-- Cor da bebida pronta (misturada ou não)
function Recipes.finalColor(drinkId: string): Color3
	return Recipes.blend(Recipes.portions(drinkId))
end

-- Lista de ingredientes em texto: "Café + Leite + Canela"
function Recipes.describe(drinkId: string): string
	local names = {}
	for _, id in Recipes.IngredientOrder do
		local n = Recipes.Drinks[drinkId].Ingredients[id]
		if n then
			table.insert(names, if n > 1 then `{n}x {Recipes.Ingredients[id].Name}` else Recipes.Ingredients[id].Name)
		end
	end
	return table.concat(names, " + ")
end

return Recipes
