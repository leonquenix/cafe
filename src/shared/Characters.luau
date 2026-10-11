--!strict
-- Tipos de cliente e clientes de visual fixo (compartilhado).

local Characters = {}

Characters.Kind = {
	Normal = 0,
	Kid = 1,
	Critic = 2,
	Regular = 3,
}

-- Visual fixo (opcional) de um cliente: qualquer campo omitido é sorteado
export type Look = {
	Kid: boolean?,
	Skin: Color3?,
	Hair: Color3?,
	HairStyle: string?, -- "Long" | "Fringe" | "Bangs" | "Bun" | "Short"
	Bow: Color3?, -- lacinho no cabelo
	Beard: Color3?,
	ShortBeard: boolean?, -- barba rente
	DressFlowers: Color3?, -- estampa de florzinhas no vestido
	Glasses: Color3?, -- armação dos óculos
	RightArm: Color3?, -- cor só do braço direito (abaixo da manga, se for manga curta)
	ShortSleeves: boolean?, -- camiseta de manga curta (antebraço aparece)
	Tattoo: boolean?, -- detalhes de tatuagem no braço direito
	Top: Color3?, -- camisa/blusa
	TopStripe: Color3?, -- listras do xadrez
	Dress: Color3?, -- vestido (saia por cima das pernas)
	DressTrim: Color3?, -- barrado/bordado do vestido
	Pants: Color3?,
	Shoes: Color3?,
}

-- Cliente com aparência fixa (o nome é só referência interna, não aparece no jogo)
export type Regular = {
	Id: number,
	Name: string,
	Seed: number, -- aparência fixa
	Look: Look?,
	Order: string?, -- easter egg: sempre pede essa bebida (id em Recipes.Drinks)
	NoPastry: boolean?, -- nunca pede doce, só a bebida
}

local rgb = Color3.fromRGB

Characters.Regulars = {
	{ Id = 1, Name = "Seu Almeida", Seed = 101 },
	{ Id = 2, Name = "Dona Cida", Seed = 202 },
	{
		Id = 3,
		Name = "Titia Bia",
		Seed = 303,
		Look = {
			Skin = rgb(241, 196, 158),
			Hair = rgb(110, 70, 44),
			HairStyle = "Bun",
			Glasses = rgb(46, 36, 34),
			Dress = rgb(96, 140, 206),
			DressTrim = rgb(200, 56, 62),
			DressFlowers = rgb(214, 60, 66),
			Shoes = rgb(120, 70, 50),
		},
	},
	{ Id = 4, Name = "Juju", Seed = 404 },
	{
		Id = 5,
		Name = "Zezo",
		Seed = 505,
		Look = {
			Skin = rgb(226, 178, 138),
			Hair = rgb(110, 70, 44),
			HairStyle = "Short",
			Beard = rgb(110, 70, 44),
			ShortBeard = true,
			Glasses = rgb(46, 36, 34),
			Top = rgb(92, 140, 210),
			ShortSleeves = true,
			RightArm = rgb(30, 28, 32),
			Tattoo = true,
			Pants = rgb(60, 60, 66),
		},
	},
	{
		Id = 6,
		Name = "Aretyssa",
		Seed = 606,
		Order = "CinnamonCappuccino",
		Look = {
			Skin = rgb(243, 204, 170),
			Hair = rgb(178, 132, 90),
			HairStyle = "Long",
			Top = rgb(250, 248, 240),
			Dress = rgb(250, 248, 240),
			DressTrim = rgb(214, 110, 100),
			Shoes = rgb(150, 100, 64),
		},
	},
	{
		Id = 7,
		Name = "Leonardo",
		Seed = 707,
		Order = "Espresso",
		Look = {
			Skin = rgb(236, 190, 150),
			Hair = rgb(64, 40, 28),
			HairStyle = "Fringe",
			Beard = rgb(64, 40, 28),
			Top = rgb(196, 38, 44),
			TopStripe = rgb(30, 28, 32),
			Pants = rgb(36, 36, 42),
			Shoes = rgb(46, 38, 34),
		},
	},
	{
		Id = 8,
		Name = "Maduda",
		Seed = 808,
		Order = "TripleMilk", -- bebida secreta, fora do cardápio
		NoPastry = true,
		Look = {
			Kid = true,
			Skin = rgb(243, 204, 170),
			Hair = rgb(64, 40, 28),
			HairStyle = "Long",
			Bow = rgb(240, 130, 160),
			Top = rgb(250, 196, 206),
			Pants = rgb(120, 150, 204),
			Shoes = rgb(240, 130, 160),
		},
	},
} :: { Regular }

return Characters
