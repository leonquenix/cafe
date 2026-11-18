return {
	Name = "restoreLevel",
	Aliases = { "bloquear" },
	Description = "Sai do modo de teste: devolve o nível/XP guardados pelo unlockAll.",
	Group = "CafeAdmin",
	Args = {
		{
			Type = "player",
			Name = "jogador",
			Description = "Quem volta (padrão: você)",
			Optional = true,
		},
	},
}
