--!strict
-- Estado do jogador no cliente (reativo, via Fusion). Atualizado pelo pacote PlayerState.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

local State = {
	scope = scope,
	Loaded = scope:Value(false),
	Money = scope:Value(0),
	Level = scope:Value(1),
	XP = scope:Value(0),
	Day = scope:Value(1),
	Served = scope:Value(0),
	PerDay = scope:Value(10),
	DayActive = scope:Value(false),
	Cozy = scope:Value(0),
	Upgrades = scope:Value({} :: { [string]: number }),
	Owned = scope:Value({} :: { [string]: boolean }),
	Hidden = scope:Value({} :: { [string]: boolean }), -- decorações compradas que estão desligadas
	Menu = scope:Value({} :: { string }),
	Stats = scope:Value({} :: { [string]: number }), -- bebidas servidas por receita
	PastryStats = scope:Value({} :: { [string]: number }), -- doces servidos por receita
	Claims = scope:Value({} :: { [string]: number }), -- marcos de conquista resgatados (bebidas e doces)
	Mastered = scope:Value({} :: { [string]: boolean }), -- bebidas dominadas (+10%)
	CatColor = scope:Value("Gray"),
	Themes = scope:Value({} :: { [string]: boolean }), -- temas da fachada comprados
	Theme = scope:Value("Original"), -- tema da fachada em uso
	WallPaint = scope:Value(false), -- comprou o kit de tintas
	WallColor = scope:Value("Cream"), -- cor das paredes de dentro
	IntroSeen = scope:Value(false), -- já viu a fala da vovó do primeiro dia
	PastryTutorialDue = scope:Value(false), -- o próximo dia começa com o tutorial do forno (o servidor decide)
}

function State.apply(s: any)
	State.Money:set(s.money)
	State.Level:set(s.level)
	State.XP:set(s.xp)
	State.Day:set(s.day)
	State.Served:set(s.served)
	State.PerDay:set(s.perDay)
	State.DayActive:set(s.dayActive)
	State.Cozy:set(s.cozy)
	-- antes do Owned: o gato do balcão já nasce com a pelagem certa
	State.CatColor:set(s.catColor)

	local upgrades = {}
	for _, u in s.upgrades do
		upgrades[u.id] = u.level
	end
	State.Upgrades:set(upgrades)

	-- antes do Owned: o café já se monta sem as decorações desligadas
	local hidden = {}
	for _, id in s.hidden do
		hidden[id] = true
	end
	State.Hidden:set(hidden)

	local owned = {}
	for _, id in s.owned do
		owned[id] = true
	end
	State.Owned:set(owned)

	State.Menu:set(s.menu)

	local stats = {}
	for _, st in s.stats do
		stats[st.drink] = st.count
	end
	State.Stats:set(stats)

	local pastryStats = {}
	for _, st in s.pastryStats do
		pastryStats[st.drink] = st.count
	end
	State.PastryStats:set(pastryStats)

	local claims = {}
	for _, c in s.claims do
		claims[c.id] = c.count
	end
	State.Claims:set(claims)

	local mastered = {}
	for _, id in s.mastered do
		mastered[id] = true
	end
	State.Mastered:set(mastered)

	local themes = {}
	for _, id in s.themes do
		themes[id] = true
	end
	State.Themes:set(themes)
	State.Theme:set(s.theme)
	State.WallPaint:set(s.wallPaint)
	State.WallColor:set(s.wallColor)
	State.IntroSeen:set(s.introSeen)
	State.PastryTutorialDue:set(s.pastryTutorialDue)
	State.Loaded:set(true)
end

return State
