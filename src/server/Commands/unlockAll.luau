return {
	Name = "unlockAll",
	Aliases = { "liberar" },
	Description = "Modo de teste: guarda o nível/XP atuais e sobe para o nível que libera tudo (volte com restoreLevel).",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "player",
			Name = "jogador",
			Description = "Quem recebe (padrão: você)",
			Optional = true,
		},
	},
}
