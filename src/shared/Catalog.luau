--!strict
-- Tudo que dá pra comprar entre os dias: melhorias, doces e decoração.

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- nome do sprite
	Costs: { number }, -- custo de cada nível
	Level: number, -- nível do jogador necessário
}

export type Pastry = {
	Id: string,
	Name: string,
	Icon: string,
	Cost: number, -- para aprender
	Price: number, -- quanto paga no pedido
	Level: number,
	BakeTime: number, -- segundos até queimar
}

export type Decor = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	Cost: number,
	Cozy: number,
	Level: number,
}

local Catalog = {}

Catalog.UpgradeOrder = { "Espresso", "Whisk", "TipJar" }
Catalog.Upgrades = {
	Espresso = {
		Id = "Espresso",
		Name = "Máquina Turbo",
		Description = "Os ingredientes despejam mais rápido.",
		Icon = "Coffee",
		Costs = { 80, 200, 450 },
		Level = 1,
	},
	Whisk = {
		Id = "Whisk",
		Name = "Batedor Elétrico",
		Description = "Menos voltas para misturar.",
		Icon = "Spoon",
		Costs = { 60, 160, 380 },
		Level = 1,
	},
	TipJar = {
		Id = "TipJar",
		Name = "Pote de Gorjetas",
		Description = "Clientes Relâmpago deixam gorjeta.",
		Icon = "Coin",
		Costs = { 100, 250, 500 },
		Level = 2,
	},
} :: { [string]: Upgrade }

-- doces liberam no nível 3 (dois) e depois um a cada 2 níveis.
-- o Icon tem que ter o mesmo nome do Id (o balão do pedido desenha Sprites[id])
Catalog.PastryOrder = { "Cookie", "Beliscao", "Brownie", "Croissant", "Madeleines", "CornCake", "Strudel", "Cupcake", "CarrotCake", "Pudim" }
Catalog.Pastries = {
	Cookie = { Id = "Cookie", Name = "Cookie", Icon = "Cookie", Cost = 120, Price = 6, Level = 3, BakeTime = 3.2 },
	Beliscao = { Id = "Beliscao", Name = "Beliscão de goiabada", Icon = "Beliscao", Cost = 150, Price = 7, Level = 3, BakeTime = 3.2 },
	Brownie = { Id = "Brownie", Name = "Brownie", Icon = "Brownie", Cost = 200, Price = 9, Level = 5, BakeTime = 3.0 },
	Croissant = { Id = "Croissant", Name = "Croissant", Icon = "Croissant", Cost = 250, Price = 10, Level = 7, BakeTime = 2.8 },
	Madeleines = { Id = "Madeleines", Name = "Madeleines", Icon = "Madeleines", Cost = 280, Price = 11, Level = 9, BakeTime = 2.8 },
	CornCake = { Id = "CornCake", Name = "Bolo de fubá", Icon = "CornCake", Cost = 300, Price = 11, Level = 11, BakeTime = 2.8 },
	Strudel = { Id = "Strudel", Name = "Strudel", Icon = "Strudel", Cost = 350, Price = 13, Level = 13, BakeTime = 2.6 },
	Cupcake = { Id = "Cupcake", Name = "Cupcake", Icon = "Cupcake", Cost = 400, Price = 14, Level = 15, BakeTime = 2.4 },
	CarrotCake = { Id = "CarrotCake", Name = "Bolo de cenoura", Icon = "CarrotCake", Cost = 450, Price = 15, Level = 17, BakeTime = 2.4 },
	Pudim = { Id = "Pudim", Name = "Pudim", Icon = "Pudim", Cost = 500, Price = 16, Level = 19, BakeTime = 2.2 },
} :: { [string]: Pastry }

Catalog.DecorOrder = { "Rug", "HangingPlants", "Paintings", "Cat", "Lanterns", "Record", "Stove" }
Catalog.Decor = {
	Rug = { Id = "Rug", Name = "Tapete de Lã", Description = "Quentinho pros pés.", Icon = "Rug", Cost = 80, Cozy = 1, Level = 1 },
	HangingPlants = {
		Id = "HangingPlants",
		Name = "Plantas Pendentes",
		Description = "Verde caindo do teto.",
		Icon = "HangingPlant",
		Cost = 90,
		Cozy = 1,
		Level = 1,
	},
	Paintings = { Id = "Paintings", Name = "Galeria de Quadros", Description = "Arte local na parede.", Icon = "Painting", Cost = 120, Cozy = 1, Level = 2 },
	Cat = { Id = "Cat", Name = "Gatinho da Vitrine", Description = "Dorme em cima dos docinhos.", Icon = "Cat", Cost = 150, Cozy = 2, Level = 2 },
	Lanterns = { Id = "Lanterns", Name = "Lanternas de Papel", Description = "Luz suave e colorida.", Icon = "Lantern", Cost = 160, Cozy = 2, Level = 3 },
	Record = { Id = "Record", Name = "Vitrola", Description = "Um jazz baixinho no ar.", Icon = "Record", Cost = 220, Cozy = 2, Level = 3 },
	Stove = { Id = "Stove", Name = "Fogão a Lenha", Description = "Estalinhos e calor de vó.", Icon = "Stove", Cost = 400, Cozy = 3, Level = 4 },
} :: { [string]: Decor }

Catalog.CozyBonus = 0.02 -- cada ponto de aconchego: +2% em todos os pagamentos

function Catalog.upgradeCost(id: string, currentLevel: number): number?
	return Catalog.Upgrades[id].Costs[currentLevel + 1]
end

return Catalog
