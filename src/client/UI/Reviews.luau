--!strict
-- Reviews divertidos gerados a partir dos pedidos do dia (só cosmético, no cliente).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

export type Review = { Name: string, Text: string, Stars: number, Tag: string? }
export type DeliveredOrder = { drink: string, tier: number, earned: number, kind: number?, wrong: boolean?, problem: string? }

local NAMES = {
	"Dona Cida",
	"Pedrinho, 8 anos",
	"Seu Almeida",
	"Titia Bia",
	"Tia Neide",
	"Marcos (estagiário)",
	"Um pombo",
	"Crítico Gastronômico Anônimo",
	"Juju",
	"Vó Lurdes",
	"O cara do violão",
	"Gato do vizinho",
	"Dra. Helena",
	"Zezo",
}

local CRITIC: { [number]: { string } } = {
	[5] = {
		"Excepcional. O {drink} tem textura, alma e pontualidade. Três xícaras de ouro.",
		"Raro encontrar um {drink} tão honesto. Recomendo sem reservas.",
	},
	[4] = { "Um {drink} competente e acolhedor. Voltarei com o caderno." },
	[3] = { "O {drink} era correto. O serviço, contemplativo demais." },
	[2] = { "O vapor do {drink} tinha mais personalidade que a espera." },
}

local UNMIXED = {
	"Meu {drink} veio em camadas. Tive que mexer com o dedo.",
	"Ninguém mexeu meu {drink}. Bebi o chocolate primeiro e o resto depois.",
}

local STIRRED = {
	"Pedi SEM mexer. As camadas eram o motivo da minha visita.",
	"Meu {drink} era pra ser listradinho. Veio tudo bege.",
}

local WRONG = {
	"Pedi {drink} e veio outra coisa. Pelo menos estava quentinho.",
	"Surpresa! Não era o meu {drink}. Vou considerar uma aventura.",
	"O barista é criativo. Criativo demais para um {drink}.",
}

local TEXTS: { [number]: { string } } = {
	[5] = {
		"Meu {drink} chegou antes de eu terminar de pedir. Magia?",
		"Melhor {drink} da cidade. Volto amanhã. E depois. E depois.",
		"O barista é um ninja do café. Não vi as mãos se mexendo.",
		"Chorei com o {drink}. De felicidade. Acho.",
		"Pedi um {drink} e recebi um abraço em forma de bebida.",
		"Rápido, quentinho e fofo. 10/10, adotaria esse café.",
	},
	[4] = {
		"{drink} delicioso! Ambiente cozy demais.",
		"Atendimento simpático e o {drink} tava no ponto :)",
		"Ótimo {drink}. Tirei 1 estrela porque a planta não falou comigo.",
		"Voltaria só pelo cheirinho. O {drink} também é bom.",
	},
	[3] = {
		"Demorou um pouquinho, mas o {drink} compensou.",
		"Deu tempo de ler meio livro da estante. Bom {drink}.",
		"O {drink} tava bom! Minha paciência nem tanto.",
	},
	[2] = {
		"Esperei tanto que meu gato sentiu saudade.",
		"O {drink} tava gostoso, mas envelheci uns 3 anos na fila.",
		"Cheguei jovem. Saí com o {drink} e cabelo branco.",
	},
}

local Reviews = {}

function Reviews.stars(tier: number): number
	return math.clamp(tier + 2, 2, 5)
end

function Reviews.generate(orders: { DeliveredOrder }, count: number): { Review }
	local rng = Random.new()
	local names = table.clone(NAMES)
	local result: { Review } = {}

	local function pick(list: { string }, drink: string?): string
		local text = list[rng:NextInteger(1, #list)]
		return (string.gsub(text, "{drink}", if drink then Recipes.Drinks[drink].Name else ""))
	end

	-- crítico e um pedido errado primeiro (são os mais divertidos de ler)
	local pool = {}
	local wrongDone = false
	for _, o in orders do
		if o.wrong then
			if not wrongDone and #result < count then
				wrongDone = true
				table.insert(result, { Name = table.remove(names, rng:NextInteger(1, #names)) :: string, Text = pick(if o.problem == "Unmixed" then UNMIXED elseif o.problem == "Stirred" then STIRRED else WRONG, o.drink), Stars = 1 })
			end
		elseif o.kind == Characters.Kind.Critic and #result < count then
			local stars = Reviews.stars(o.tier)
			table.insert(result, { Name = "Crítico Gastronômico", Text = pick(CRITIC[stars], o.drink), Stars = stars, Tag = "CRÍTICO" })
		else
			table.insert(pool, o)
		end
	end

	while #result < count and #pool > 0 do
		local order = table.remove(pool, rng:NextInteger(1, #pool)) :: DeliveredOrder
		local stars = Reviews.stars(order.tier)
		local name = table.remove(names, rng:NextInteger(1, #names)) :: string
		table.insert(result, { Name = name, Text = pick(TEXTS[stars], order.drink), Stars = stars })
	end
	return result
end

return Reviews
