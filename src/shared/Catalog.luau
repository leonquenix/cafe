--!strict
-- Tudo que dá pra comprar entre os dias: melhorias, doces e decoração.

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- nome do sprite
	Costs: { number }, -- custo de cada degrau
	Level: number, -- nível do jogador necessário (vale para os degraus sem entrada em TierLevels)
	TierLevels: { [number]: number }?, -- degrau -> nível do jogador necessário (degraus mais altos)
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
	Group: string?, -- grupo na aba Decoração (Catalog.DecorGroups); nil = "Cafe"
	Requires: string?, -- só pode comprar depois desta outra decoração (ex.: gorro precisa do gato)
	Slot: string?, -- vaga exclusiva (Catalog.DecorSlots): ligar uma desliga as outras da mesma vaga
}

local Catalog = {}

Catalog.UpgradeOrder = { "Espresso", "Whisk", "TipJar" }
Catalog.Upgrades = {
	Espresso = {
		Id = "Espresso",
		Name = "Máquina Turbo",
		Description = "Os ingredientes despejam mais rápido.",
		Icon = "Coffee",
		Costs = { 80, 200, 450, 900, 1600 },
		Level = 1,
		TierLevels = { [4] = 14, [5] = 27 },
	},
	Whisk = {
		Id = "Whisk",
		Name = "Batedor Elétrico",
		Description = "Menos voltas para misturar.",
		Icon = "Spoon",
		Costs = { 60, 160, 380, 750, 1400 },
		Level = 1,
		TierLevels = { [4] = 18, [5] = 28 },
	},
	TipJar = {
		Id = "TipJar",
		Name = "Pote de Gorjetas",
		Description = "Clientes Relâmpago deixam gorjeta.",
		Icon = "Coin",
		Costs = { 100, 250, 500, 1000, 1800 },
		Level = 4,
		TierLevels = { [4] = 24, [5] = 30 },
	},
} :: { [string]: Upgrade }

-- ordem de desbloqueio dos doces: cookie e brownie no nível 3 e depois espaçando até o 28
-- (5, 6, 7, 8, 10, 12, 13, 15, 18, 20, 24, 26 e 28).
-- Cost e Price sobem junto com a ordem e o BakeTime cai (os últimos assam mais rápido, mais difícil de acertar).
-- o Icon tem que ter o mesmo nome do Id (o balão do pedido desenha Sprites[id])
Catalog.PastryOrder = {
	"Cookie",
	"Brownie",
	"Cupcake",
	"Beliscao",
	"CornCake",
	"Esfirra",
	"Pudim",
	"StrawberryTart",
	"Madeleines",
	"Empada",
	"CarrotCake",
	"Croissant",
	"Rocambole",
	"Strudel",
	"PaoDeQueijo",
}
Catalog.Pastries = {
	Cookie = { Id = "Cookie", Name = "Cookie", Icon = "Cookie", Cost = 120, Price = 6, Level = 3, BakeTime = 3.2 },
	Brownie = { Id = "Brownie", Name = "Brownie", Icon = "Brownie", Cost = 150, Price = 7, Level = 3, BakeTime = 3.2 },
	Cupcake = { Id = "Cupcake", Name = "Cupcake", Icon = "Cupcake", Cost = 170, Price = 8, Level = 5, BakeTime = 3.1 },
	Beliscao = { Id = "Beliscao", Name = "Beliscão de goiabada", Icon = "Beliscao", Cost = 200, Price = 9, Level = 6, BakeTime = 3.0 },
	CornCake = { Id = "CornCake", Name = "Bolo de fubá", Icon = "CornCake", Cost = 230, Price = 10, Level = 7, BakeTime = 2.9 },
	Esfirra = { Id = "Esfirra", Name = "Esfirra", Icon = "Esfirra", Cost = 250, Price = 10, Level = 8, BakeTime = 2.8 },
	Pudim = { Id = "Pudim", Name = "Pudim", Icon = "Pudim", Cost = 280, Price = 11, Level = 10, BakeTime = 2.8 },
	StrawberryTart = { Id = "StrawberryTart", Name = "Torta de morango", Icon = "StrawberryTart", Cost = 290, Price = 11, Level = 12, BakeTime = 2.8 },
	Madeleines = { Id = "Madeleines", Name = "Madeleines", Icon = "Madeleines", Cost = 300, Price = 11, Level = 13, BakeTime = 2.8 },
	Empada = { Id = "Empada", Name = "Empada", Icon = "Empada", Cost = 350, Price = 13, Level = 15, BakeTime = 2.6 },
	CarrotCake = { Id = "CarrotCake", Name = "Bolo de cenoura", Icon = "CarrotCake", Cost = 380, Price = 13, Level = 18, BakeTime = 2.5 },
	Croissant = { Id = "Croissant", Name = "Croissant", Icon = "Croissant", Cost = 400, Price = 14, Level = 20, BakeTime = 2.4 },
	Rocambole = { Id = "Rocambole", Name = "Rocambole", Icon = "Rocambole", Cost = 450, Price = 15, Level = 24, BakeTime = 2.4 },
	Strudel = { Id = "Strudel", Name = "Strudel", Icon = "Strudel", Cost = 470, Price = 15, Level = 26, BakeTime = 2.3 },
	PaoDeQueijo = { Id = "PaoDeQueijo", Name = "Pão de queijo", Icon = "PaoDeQueijo", Cost = 500, Price = 16, Level = 28, BakeTime = 2.2 },
} :: { [string]: Pastry }

Catalog.DecorOrder = {
	"Rug",
	"HangingPlants",
	"Paintings",
	"Cat",
	"Lanterns",
	"Record",
	"Stove",
	"EasterBasket",
	"EasterWreath",
	"EasterBunting",
	"EasterPlantBunny",
	"EasterWindowGarland",
	"EasterFootprints",
	"HalloweenWebs",
	"HalloweenWall",
	"HalloweenPumpkins",
	"HalloweenGhosts",
	"HalloweenZombieHand",
	"HalloweenMummy",
	"ChristmasCatHat",
	"ChristmasWreath",
	"ChristmasGarland",
	"ChristmasTree",
	"LoveCatTiara",
	"LoveCounterCards",
	"LoveWallFrames",
	"LoveRug",
	"LoveWindowHearts",
	"LoveHeartBunting",
	"PatrickCatHat",
	"PatrickCauldron",
	"PatrickCloverBunting",
	"PatrickRug",
	"PatrickWindowClovers",
	"PatrickLeprechaun",
	"CarnivalCatMask",
	"CarnivalTambourine",
	"CarnivalConfetti",
	"CarnivalStreamers",
	"CarnivalWindowMasks",
	"CarnivalUmbrellas",
	"JuninaCatHat",
	"JuninaCounterBasket",
	"JuninaWallDaisies",
	"JuninaRug",
	"JuninaFlags",
	"JuninaWindowBalloons",
}
Catalog.Decor = {
	Rug = { Id = "Rug", Name = "Tapete de Lã", Description = "Quentinho pros pés.", Icon = "Rug", Cost = 80, Cozy = 1, Level = 1, Slot = "Rug" },
	HangingPlants = {
		Id = "HangingPlants",
		Name = "Plantas Pendentes",
		Description = "Verde caindo do teto.",
		Icon = "HangingPlant",
		Cost = 90,
		Cozy = 1,
		Level = 1,
	},
	Paintings = { Id = "Paintings", Name = "Galeria de Quadros", Description = "Arte local na parede.", Icon = "Painting", Cost = 120, Cozy = 1, Level = 3 },
	Cat = { Id = "Cat", Name = "Gatinho da Vitrine", Description = "Dorme em cima dos docinhos.", Icon = "Cat", Cost = 150, Cozy = 2, Level = 2 },
	Lanterns = { Id = "Lanterns", Name = "Lanternas de Papel", Description = "Luz suave e colorida.", Icon = "Lantern", Cost = 160, Cozy = 2, Level = 5 },
	Record = { Id = "Record", Name = "Vitrola", Description = "Um jazz baixinho no ar.", Icon = "Record", Cost = 220, Cozy = 2, Level = 5 },
	Stove = { Id = "Stove", Name = "Fogão a Lenha", Description = "Estalinhos e calor de vó.", Icon = "Stove", Cost = 400, Cozy = 3, Level = 7 },
	-- festas: cada enfeite é comprado separado e pode ser ligado/desligado na loja (perfil DecorHidden)
	EasterBasket = {
		Id = "EasterBasket",
		Name = "Cesta de Ovinhos",
		Description = "Ovos pintados e um pintinho no balcão.",
		Icon = "EasterBasket",
		Cost = 220,
		Cozy = 1,
		Level = 11,
		Group = "Easter",
	},
	EasterWreath = {
		Id = "EasterWreath",
		Name = "Guirlanda de Páscoa",
		Description = "Ovinhos e um coelhinho na parede.",
		Icon = "EasterWreath",
		Cost = 260,
		Cozy = 1,
		Level = 12,
		Group = "Easter",
	},
	EasterBunting = {
		Id = "EasterBunting",
		Name = "Bandeirinhas de Páscoa",
		Description = "Bandeirinhas e ovinhos no teto.",
		Icon = "EasterBunting",
		Cost = 300,
		Cozy = 1,
		Level = 13,
		Group = "Easter",
	},
	EasterPlantBunny = {
		Id = "EasterPlantBunny",
		Name = "Coelhinho Espião",
		Description = "Espia de dentro da planta do balcão.",
		Icon = "EasterPlantBunny",
		Cost = 280,
		Cozy = 1,
		Level = 13,
		Group = "Easter",
	},
	EasterWindowGarland = {
		Id = "EasterWindowGarland",
		Name = "Festão de Páscoa",
		Description = "Cenouras, coelhinhos e ovinhos nas janelas.",
		Icon = "EasterWindowGarland",
		Cost = 340,
		Cozy = 1,
		Level = 14,
		Group = "Easter",
	},
	EasterFootprints = {
		Id = "EasterFootprints",
		Name = "Pegadas de Coelhinho",
		Description = "Um caminho de pegadinhas da porta até o balcão.",
		Icon = "EasterFootprints",
		Cost = 240,
		Cozy = 1,
		Level = 12,
		Group = "Easter",
	},
	-- HalloweenWall era "Morceguinhos e Teias"; as teias viraram o HalloweenWebs (quem já tinha ganhou as duas)
	HalloweenWebs = {
		Id = "HalloweenWebs",
		Name = "Teias de Aranha",
		Description = "Teias nas janelas e aranhinhas descendo.",
		Icon = "HalloweenWebs",
		Cost = 220,
		Cozy = 1,
		Level = 16,
		Group = "Halloween",
	},
	HalloweenWall = {
		Id = "HalloweenWall",
		Name = "Morceguinhos",
		Description = "Morcegos batendo asas pelas paredes.",
		Icon = "HalloweenWall",
		Cost = 280,
		Cozy = 1,
		Level = 16,
		Group = "Halloween",
	},
	HalloweenPumpkins = {
		Id = "HalloweenPumpkins",
		Name = "Abóboras Iluminadas",
		Description = "Velinhas tremulando nas abóboras.",
		Icon = "HalloweenPumpkins",
		Cost = 320,
		Cozy = 1,
		Level = 17,
		Group = "Halloween",
	},
	HalloweenGhosts = {
		Id = "HalloweenGhosts",
		Name = "Fantasminhas",
		Description = "Fantasminhas fofos flutuando no teto.",
		Icon = "HalloweenGhosts",
		Cost = 360,
		Cozy = 1,
		Level = 19,
		Group = "Halloween",
	},
	HalloweenZombieHand = {
		Id = "HalloweenZombieHand",
		Name = "Mão de Zumbi",
		Description = "Uma mão sobe e desce lá fora, na segunda janela da direita.",
		Icon = "HalloweenZombieHand",
		Cost = 300,
		Cozy = 1,
		Level = 19,
		Group = "Halloween",
	},
	HalloweenMummy = {
		Id = "HalloweenMummy",
		Name = "Múmia Passeando",
		Description = "Uma múmia passa lá fora pelas janelas da esquerda.",
		Icon = "HalloweenMummy",
		Cost = 400,
		Cozy = 1,
		Level = 20,
		Group = "Halloween",
	},
	-- precisa do gatinho da vitrine (Requires): o gorro vai na cabeça dele
	ChristmasCatHat = {
		Id = "ChristmasCatHat",
		Name = "Gorro do Gatinho",
		Description = "Gorro de Papai Noel pro gato da vitrine.",
		Icon = "ChristmasCatHat",
		Cost = 200,
		Cozy = 1,
		Level = 23,
		Group = "Christmas",
		Requires = "Cat",
		Slot = "CatHat",
	},
	ChristmasWreath = {
		Id = "ChristmasWreath",
		Name = "Guirlandas de Natal",
		Description = "Laço vermelho e pisca-pisca em cada janela.",
		Icon = "ChristmasWreath",
		Cost = 300,
		Cozy = 1,
		Level = 23,
		Group = "Christmas",
	},
	ChristmasGarland = {
		Id = "ChristmasGarland",
		Name = "Festão de Natal",
		Description = "Festão e bolinhas penduradas no teto.",
		Icon = "ChristmasGarland",
		Cost = 380,
		Cozy = 1,
		Level = 25,
		Group = "Christmas",
	},
	ChristmasTree = {
		Id = "ChristmasTree",
		Name = "Árvore de Natal",
		Description = "Bolinhas, pisca-pisca e estrela no topo.",
		Icon = "ChristmasTree",
		Cost = 550,
		Cozy = 2,
		Level = 27,
		Group = "Christmas",
	},
	-- Dia do Amor (níveis 31 a 34)
	LoveCatTiara = {
		Id = "LoveCatTiara",
		Name = "Tiara de Coração",
		Description = "Anteninhas de coração pro gatinho.",
		Icon = "LoveCatTiara",
		Cost = 220,
		Cozy = 1,
		Level = 31,
		Group = "Love",
		Requires = "Cat",
		Slot = "CatHat",
	},
	LoveCounterCards = {
		Id = "LoveCounterCards",
		Name = "Cartinhas de Amor",
		Description = "Cartinhas de coração espalhadas pelo balcão.",
		Icon = "LoveCounterCards",
		Cost = 240,
		Cozy = 1,
		Level = 31,
		Group = "Love",
	},
	LoveWallFrames = {
		Id = "LoveWallFrames",
		Name = "Quadros de Coração",
		Description = "Quadrinhos de coração pelas paredes.",
		Icon = "LoveWallFrames",
		Cost = 280,
		Cozy = 1,
		Level = 32,
		Group = "Love",
	},
	LoveRug = {
		Id = "LoveRug",
		Name = "Tapete de Coração",
		Description = "Tapete fofinho de coração.",
		Icon = "LoveRug",
		Cost = 300,
		Cozy = 1,
		Level = 33,
		Group = "Love",
		Slot = "Rug",
	},
	LoveWindowHearts = {
		Id = "LoveWindowHearts",
		Name = "Pendentes de Coração",
		Description = "Coraçõezinhos pendurados em todas as janelas.",
		Icon = "LoveWindowHearts",
		Cost = 340,
		Cozy = 1,
		Level = 33,
		Group = "Love",
	},
	LoveHeartBunting = {
		Id = "LoveHeartBunting",
		Name = "Varal de Corações",
		Description = "Corações grandes e pequenos balançando no teto.",
		Icon = "LoveHeartBunting",
		Cost = 380,
		Cozy = 1,
		Level = 34,
		Group = "Love",
	},
	-- Dia de São Patrício (níveis 35 a 38)
	PatrickCatHat = {
		Id = "PatrickCatHat",
		Name = "Cartola de Duende",
		Description = "Cartola verde de duende pro gatinho.",
		Icon = "PatrickCatHat",
		Cost = 220,
		Cozy = 1,
		Level = 35,
		Group = "Patrick",
		Requires = "Cat",
		Slot = "CatHat",
	},
	PatrickCauldron = {
		Id = "PatrickCauldron",
		Name = "Caldeirão de Moedas",
		Description = "Um caldeirão cheio de moedas de ouro no balcão.",
		Icon = "PatrickCauldron",
		Cost = 260,
		Cozy = 1,
		Level = 35,
		Group = "Patrick",
	},
	PatrickCloverBunting = {
		Id = "PatrickCloverBunting",
		Name = "Varal de Trevos",
		Description = "Trevinhos pendurados no teto.",
		Icon = "PatrickCloverBunting",
		Cost = 300,
		Cozy = 1,
		Level = 36,
		Group = "Patrick",
	},
	PatrickRug = {
		Id = "PatrickRug",
		Name = "Tapete de Trevo",
		Description = "Tapete verdinho de trevo.",
		Icon = "PatrickRug",
		Cost = 320,
		Cozy = 1,
		Level = 37,
		Group = "Patrick",
		Slot = "Rug",
	},
	PatrickWindowClovers = {
		Id = "PatrickWindowClovers",
		Name = "Trevos nas Janelas",
		Description = "Trevos de vários tamanhos em volta das janelas.",
		Icon = "PatrickWindowClovers",
		Cost = 340,
		Cozy = 1,
		Level = 37,
		Group = "Patrick",
	},
	PatrickLeprechaun = {
		Id = "PatrickLeprechaun",
		Name = "Duende Espião",
		Description = "Um duende espia lá de fora, na janela da esquerda.",
		Icon = "PatrickLeprechaun",
		Cost = 420,
		Cozy = 1,
		Level = 38,
		Group = "Patrick",
	},
	-- Carnaval (níveis 39 a 42)
	CarnivalCatMask = {
		Id = "CarnivalCatMask",
		Name = "Tiara de Máscara",
		Description = "Tiara de máscara pro gatinho.",
		Icon = "CarnivalCatMask",
		Cost = 220,
		Cozy = 1,
		Level = 39,
		Group = "Carnival",
		Requires = "Cat",
		Slot = "CatHat",
	},
	CarnivalTambourine = {
		Id = "CarnivalTambourine",
		Name = "Pandeiro",
		Description = "Um pandeiro azulzinho e confetes no balcão.",
		Icon = "CarnivalTambourine",
		Cost = 260,
		Cozy = 1,
		Level = 39,
		Group = "Carnival",
	},
	CarnivalConfetti = {
		Id = "CarnivalConfetti",
		Name = "Confetes",
		Description = "Confetes coloridos espalhados pelo chão.",
		Icon = "CarnivalConfetti",
		Cost = 280,
		Cozy = 1,
		Level = 40,
		Group = "Carnival",
	},
	CarnivalStreamers = {
		Id = "CarnivalStreamers",
		Name = "Serpentinas",
		Description = "Serpentinas coloridas caindo do teto.",
		Icon = "CarnivalStreamers",
		Cost = 320,
		Cozy = 1,
		Level = 41,
		Group = "Carnival",
	},
	CarnivalWindowMasks = {
		Id = "CarnivalWindowMasks",
		Name = "Máscaras nas Janelas",
		Description = "Máscaras coloridas de vários tamanhos nas janelas.",
		Icon = "CarnivalWindowMasks",
		Cost = 360,
		Cozy = 1,
		Level = 41,
		Group = "Carnival",
	},
	CarnivalUmbrellas = {
		Id = "CarnivalUmbrellas",
		Name = "Sombrinhas de Frevo",
		Description = "Sombrinhas de frevo girando penduradas no teto.",
		Icon = "CarnivalUmbrellas",
		Cost = 420,
		Cozy = 1,
		Level = 42,
		Group = "Carnival",
	},
	-- Festa Junina (níveis 43 a 46)
	JuninaCatHat = {
		Id = "JuninaCatHat",
		Name = "Chapéu de Palha",
		Description = "Chapéu de palha pro gatinho.",
		Icon = "JuninaCatHat",
		Cost = 220,
		Cozy = 1,
		Level = 43,
		Group = "Junina",
		Requires = "Cat",
		Slot = "CatHat",
	},
	JuninaCounterBasket = {
		Id = "JuninaCounterBasket",
		Name = "Cestinha de Milho",
		Description = "Toalhinha xadrez e uma cestinha de milho no balcão.",
		Icon = "JuninaCounterBasket",
		Cost = 260,
		Cozy = 1,
		Level = 43,
		Group = "Junina",
	},
	JuninaWallDaisies = {
		Id = "JuninaWallDaisies",
		Name = "Girassóis",
		Description = "Trios de girassóis enfeitando as paredes.",
		Icon = "JuninaWallDaisies",
		Cost = 280,
		Cozy = 1,
		Level = 44,
		Group = "Junina",
	},
	JuninaRug = {
		Id = "JuninaRug",
		Name = "Tapete de Chita",
		Description = "Tapete florido de chita.",
		Icon = "JuninaRug",
		Cost = 320,
		Cozy = 1,
		Level = 44,
		Group = "Junina",
		Slot = "Rug",
	},
	JuninaFlags = {
		Id = "JuninaFlags",
		Name = "Bandeirinhas",
		Description = "Bandeirinhas coloridas cruzando o teto.",
		Icon = "JuninaFlags",
		Cost = 380,
		Cozy = 1,
		Level = 45,
		Group = "Junina",
	},
	JuninaWindowBalloons = {
		Id = "JuninaWindowBalloons",
		Name = "Balões Juninos",
		Description = "Balõezinhos de papel em todas as janelas.",
		Icon = "JuninaWindowBalloons",
		Cost = 420,
		Cozy = 1,
		Level = 46,
		Group = "Junina",
	},
} :: { [string]: Decor }

-- Grupos da aba Decoração (um título por grupo, nesta ordem). Icon = sprite do título.
export type DecorGroup = { Id: string, Name: string, Icon: string }
Catalog.DecorGroupOrder = { "Cafe", "Easter", "Halloween", "Christmas", "Love", "Patrick", "Carnival", "Junina" }
Catalog.DecorGroups = {
	Cafe = { Id = "Cafe", Name = "Café", Icon = "Heart" },
	Easter = { Id = "Easter", Name = "Páscoa", Icon = "ThemeEaster" },
	Halloween = { Id = "Halloween", Name = "Halloween", Icon = "ThemeHalloween" },
	Christmas = { Id = "Christmas", Name = "Natal", Icon = "ThemeChristmas" },
	Love = { Id = "Love", Name = "Dia do Amor", Icon = "ThemeLove" },
	Patrick = { Id = "Patrick", Name = "São Patrício", Icon = "ThemePatrick" },
	Carnival = { Id = "Carnival", Name = "Carnaval", Icon = "ThemeCarnival" },
	Junina = { Id = "Junina", Name = "Festa Junina", Icon = "ThemeJunina" },
} :: { [string]: DecorGroup }

-- Vagas exclusivas: só uma decoração de cada vaga fica ligada (ligar ou comprar uma desliga as outras).
-- Text = aviso no card da loja.
Catalog.DecorSlots = {
	CatHat = { Text = "Um enfeite por vez." },
	Rug = { Text = "Um tapete por vez." },
} :: { [string]: { Text: string } }

-- Pelagens do gatinho da vitrine (escolhida no pop-up de compra; o visual fica em client/Decor).
-- Level = nível do jogador pra escolher; quem já usa uma pelagem bloqueada continua com ela.
Catalog.CatColorOrder = { "Gray", "Orange", "Black", "White", "Calico", "Tuxedo" }
Catalog.CatColors = {
	Gray = { Id = "Gray", Name = "CINZA", Level = 1 },
	Orange = { Id = "Orange", Name = "LARANJA", Level = 1 },
	Black = { Id = "Black", Name = "PRETO", Level = 7 },
	White = { Id = "White", Name = "BRANCO", Level = 10 },
	Calico = { Id = "Calico", Name = "TRICOLOR", Level = 21 },
	Tuxedo = { Id = "Tuxedo", Name = "FRAJOLINHA", Level = 29 },
} :: { [string]: { Id: string, Name: string, Level: number } }
Catalog.DefaultCatColor = "Gray"

-- Temas da fachada (só visual, sem aconchego): trocados no pop-up de temas; o visual fica em client/OutsideTheme.
-- "Original" é o visual de sempre, de graça. Natal e Halloween não exigem o tema base.
export type Theme = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	Cost: number,
	Level: number,
}

Catalog.DefaultTheme = "Original"
Catalog.ThemeOrder = { "Original", "Winter", "Autumn", "Rain", "Christmas", "Halloween", "Easter" }
Catalog.Themes = {
	Original = { Id = "Original", Name = "Primavera", Description = "O jardim florido de sempre.", Icon = "ThemeSpring", Cost = 0, Level = 1 },
	Winter = { Id = "Winter", Name = "Inverno", Description = "Neve caindo e tudo branquinho.", Icon = "ThemeWinter", Cost = 350, Level = 10 },
	Autumn = { Id = "Autumn", Name = "Outono", Description = "Folhas laranja voando pelo jardim.", Icon = "ThemeAutumn", Cost = 300, Level = 8 },
	Rain = { Id = "Rain", Name = "Dia de Chuva", Description = "Céu cinzinha e chuva lá fora.", Icon = "ThemeRain", Cost = 250, Level = 6 },
	Christmas = { Id = "Christmas", Name = "Natal", Description = "Pisca-pisca, enfeites e o Papai Noel no céu.", Icon = "ThemeChristmas", Cost = 500, Level = 22 },
	Halloween = { Id = "Halloween", Name = "Halloween", Description = "Abóboras, velinhas e morcegos.", Icon = "ThemeHalloween", Cost = 450, Level = 15 },
	Easter = { Id = "Easter", Name = "Páscoa", Description = "Ovinhos escondidos e coelhinhos no jardim.", Icon = "ThemeEaster", Cost = 400, Level = 11 },
} :: { [string]: Theme }

-- Cores das paredes de dentro (só visual, sem aconchego): o kit de tintas é comprado uma vez na aba Decoração
-- e libera as cores do nível do jogador (Level; 1 = vem com o kit); depois a troca é de graça.
-- "Cream" é a cor de sempre, grátis. Quem já usa uma cor bloqueada continua com ela.
-- Plaster = parede; Shade = faixa de cima, perto do teto (um tom mais escuro). O visual fica em client/WallPaint.
-- Os tons são um pouco mais fortes do que parecem: a luz quente do café puxa tudo pro amarelo.
export type WallColor = { Id: string, Name: string, Description: string, Level: number, Plaster: Color3, Shade: Color3 }

Catalog.WallPaint = {
	Id = "WallPaint",
	Name = "Cor das paredes",
	Description = "Pinte as paredes de dentro. Só visual.",
	Icon = "WallPaint",
	Cost = 300,
	Level = 8,
}
Catalog.DefaultWallColor = "Cream"
Catalog.WallColorOrder = { "Cream", "Peach", "Mint", "Pink", "Lilac", "Blue" }
Catalog.WallColors = {
	Cream = {
		Id = "Cream",
		Level = 1,
		Name = "Creme",
		Description = "O reboco clarinho de sempre.",
		Plaster = Color3.fromRGB(244, 230, 206),
		Shade = Color3.fromRGB(226, 206, 178),
	},
	Peach = {
		Id = "Peach",
		Level = 1,
		Name = "Laranja Pastel",
		Description = "Pêssego quentinho, cor de fim de tarde.",
		Plaster = Color3.fromRGB(250, 204, 172),
		Shade = Color3.fromRGB(234, 180, 148),
	},
	Mint = {
		Id = "Mint",
		Level = 1,
		Name = "Verde Pastel",
		Description = "Sálvia suave, combina com as plantinhas.",
		Plaster = Color3.fromRGB(190, 224, 186),
		Shade = Color3.fromRGB(164, 202, 160),
	},
	Pink = {
		Id = "Pink",
		Level = 10,
		Name = "Rosa Pastel",
		Description = "Rosinha de confeitaria.",
		Plaster = Color3.fromRGB(246, 190, 214),
		Shade = Color3.fromRGB(228, 166, 194),
	},
	Lilac = {
		Id = "Lilac",
		Level = 25,
		Name = "Lilás Pastel",
		Description = "Lavanda delicada, pra um café sonhador.",
		Plaster = Color3.fromRGB(192, 182, 246),
		Shade = Color3.fromRGB(170, 158, 230),
	},
	Blue = {
		Id = "Blue",
		Level = 29,
		Name = "Azul Pastel",
		Description = "Azul de céu limpo pela manhã.",
		Plaster = Color3.fromRGB(162, 198, 240),
		Shade = Color3.fromRGB(138, 176, 222),
	},
} :: { [string]: WallColor }

-- Estações do rádio, na ordem salva no perfil (RadioTrack = índice); o som fica em client/UI/Radio.
-- Level = nível do jogador pra ouvir; o painel mostra as estações em ordem de nível.
Catalog.RadioStations = {
	{ Name = "Bossa Nova", Level = 1 },
	{ Name = "Metal", Level = 30 },
	{ Name = "K-pop", Level = 26 },
	{ Name = "Jazz", Level = 5 },
	{ Name = "Lo-fi Hip Hop", Level = 1 },
	{ Name = "New Age", Level = 9 },
	{ Name = "Halloween", Level = 15 },
	{ Name = "Natal", Level = 22 },
	{ Name = "Romantica", Level = 31 },
	{ Name = "Celta", Level = 35 },
	{ Name = "Carnaval", Level = 39 },
	{ Name = "Arraiá", Level = 43 },
} :: { { Name: string, Level: number } }
Catalog.DefaultRadioTrack = 1

function Catalog.radioUnlocked(index: number, level: number): boolean
	local station = Catalog.RadioStations[index]
	return station ~= nil and station.Level <= level
end

Catalog.CozyBonus = 0.02 -- cada ponto de aconchego: +2% em todos os pagamentos

-- Resultado do pop-up do forno (o cliente manda; o servidor paga de acordo)
Catalog.PastryQuality = { Skipped = 0, Ok = 1, Perfect = 2, Raw = 3, Burnt = 4 }
Catalog.PerfectPastryBonus = 1.25
Catalog.BadPastryFactor = 0 -- cru ou queimado conta como item errado: o cliente leva, mas não paga o doce
Catalog.RetryPastryFactor = 0.7 -- assar de novo custa 70% do preço do doce

function Catalog.isBadPastry(quality: number): boolean
	return quality == Catalog.PastryQuality.Raw or quality == Catalog.PastryQuality.Burnt
end

-- Quanto o doce rende no pedido (antes de aconchego/maestria/tipo de cliente)
function Catalog.pastryValue(id: string, quality: number): number
	local pastry = Catalog.Pastries[id]
	if not pastry or quality == Catalog.PastryQuality.Skipped then
		return 0
	elseif quality == Catalog.PastryQuality.Perfect then
		return pastry.Price * Catalog.PerfectPastryBonus
	elseif Catalog.isBadPastry(quality) then
		return pastry.Price * Catalog.BadPastryFactor
	end
	return pastry.Price
end

-- Custo de assar de novo: 70% do preço do doce (pelo menos $1)
function Catalog.retryCost(id: string): number
	local price = Catalog.Pastries[id].Price
	return math.clamp(math.floor(price * Catalog.RetryPastryFactor + 0.5), 1, price)
end

function Catalog.upgradeCost(id: string, currentLevel: number): number?
	return Catalog.Upgrades[id].Costs[currentLevel + 1]
end

-- Nível do jogador necessário para comprar o degrau `tier` (1..#Costs) de uma melhoria
function Catalog.upgradeTierLevel(id: string, tier: number): number
	local u = Catalog.Upgrades[id]
	return (u.TierLevels and u.TierLevels[tier]) or u.Level
end

return Catalog
