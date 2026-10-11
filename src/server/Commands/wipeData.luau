return {
	Name = "wipeData",
	Aliases = { "wipe" },
	Description = "Apaga todo o progresso e recomeça do zero (o jogador é desconectado para recarregar).",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "player",
			Name = "jogador",
			Description = "Quem terá os dados apagados (padrão: você)",
			Optional = true,
		},
	},
}
