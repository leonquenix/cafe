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
	Menu = scope:Value({} :: { string }),
	Stats = scope:Value({} :: { [string]: number }),
	Mastered = scope:Value({} :: { [string]: boolean }),
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

	local upgrades = {}
	for _, u in s.upgrades do
		upgrades[u.id] = u.level
	end
	State.Upgrades:set(upgrades)

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

	local mastered = {}
	for _, id in s.mastered do
		mastered[id] = true
	end
	State.Mastered:set(mastered)
	State.Loaded:set(true)
end

return State
