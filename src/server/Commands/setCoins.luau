return {
	Name = "setCoins",
	Aliases = { "coins" },
	Description = "Define quantas moedas o jogador tem.",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "integer",
			Name = "moedas",
			Description = "Quantidade de moedas",
		},
		{
			Type = "player",
			Name = "jogador",
			Description = "Quem recebe (padrão: você)",
			Optional = true,
		},
	},
}
