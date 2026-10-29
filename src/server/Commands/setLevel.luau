return {
	Name = "setLevel",
	Aliases = { "level" },
	Description = "Define o nível do jogador (o XP dentro do nível volta a zero).",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "integer",
			Name = "nivel",
			Description = "Nível (1-255)",
		},
		{
			Type = "player",
			Name = "jogador",
			Description = "Quem recebe (padrão: você)",
			Optional = true,
		},
	},
}
