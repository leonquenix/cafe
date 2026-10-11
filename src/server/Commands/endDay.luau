return {
	Name = "endDay",
	Aliases = {},
	Description = "Encerra o dia atual; todos os pedidos restantes contam como entregues com sucesso.",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "player",
			Name = "jogador",
			Description = "De quem é o dia (padrão: você)",
			Optional = true,
		},
	},
}
