class_name Upgrades
## Player level (XP) and permanent abilities. An ability unlocks for free at its player level
## (level 1), then each further level is bought with coins. Nothing is consumed.
## Tuned with a progression simulation: an average player (25 min/day) unlocks every ability
## in ~5 days, maxes them in ~1.5 months and reaches level 50 in ~4 months.

const MAX_LEVEL := 50
## Coins to buy ability level i+1 (index 0 = level 1, free on unlock).
const PRICES := [0, 300, 1200, 4000, 12000]   # first upgrade within the first session
const RUN_XP_BONUS := 15          # XP for finishing any run, on top of the score
const FIRST_RUN_XP := 50          # the very first run always reaches level 2

## icon: sprite icon_<icon>.png. active: has an in-run button.
const ABILITIES := [
	{"id": "coins", "icon": "coin", "unlock": 2, "max": 5},
	{"id": "shield", "icon": "shield", "unlock": 3, "max": 3},
	{"id": "magnet", "icon": "magnet", "unlock": 5, "max": 5},
	{"id": "slowmo", "icon": "slowmo", "unlock": 8, "max": 3, "active": true},
	{"id": "teleport", "icon": "teleport", "unlock": 10, "max": 3, "active": true},
	{"id": "headstart", "icon": "rocket", "unlock": 12, "max": 3},
	{"id": "secondlife", "icon": "heart", "unlock": 15, "max": 1, "buy": 10000},
]
const HEADSTART_WORLD := [1, 3, 5, 8]   # highest start world per headstart level
const SLOWMO_TIME := 2.0
const SLOWMO_SCALE := 0.5
const SHIELD_RECHARGE := 60.0
## MAGNET: coins and bubbles closer than this (px, any orbit) fly to the player.
const MAGNET_RADIUS := [0.0, 22.0, 30.0, 38.0, 46.0, 56.0]


static func xp_next(level: int) -> int:
	return int(40 + 10 * pow(level, 1.8))


static func level_coins(level: int) -> int:
	return 20 * level


static func find(id: String) -> Dictionary:
	for a in ABILITIES:
		if a["id"] == id:
			return a
	return {}


## Coins to raise `id` from `current` to current+1 (-1 when maxed).
static func price(id: String, current: int) -> int:
	var a := find(id)
	if current >= int(a["max"]):
		return -1
	if a.has("buy"):
		return int(a["buy"])
	return PRICES[current]


## Abilities that unlock exactly at this player level.
static func unlocked_at(level: int) -> Array:
	return ABILITIES.filter(func(a): return int(a["unlock"]) == level)


## XP a run is worth (the first run ever is boosted so level 2 comes right away).
static func run_xp(score: int, first_run: bool) -> int:
	var xp := score + RUN_XP_BONUS
	return maxi(xp, FIRST_RUN_XP) if first_run else xp


static func coin_mult(level: int) -> float:
	return 1.0 + 0.1 * level


## Hits the starting shield absorbs (0 = no shield).
static func shield_hits(level: int) -> int:
	return 0 if level <= 0 else (2 if level >= 3 else 1)
