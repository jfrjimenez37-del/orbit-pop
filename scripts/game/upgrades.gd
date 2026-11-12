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
	{"id": "bubbles", "icon": "bubble_up", "unlock": 6, "max": 4},
	{"id": "turbo", "icon": "bolt", "unlock": 8, "max": 3, "active": true},
	{"id": "teleport", "icon": "teleport", "unlock": 10, "max": 3, "active": true},
	{"id": "explorer", "icon": "world", "unlock": 12, "max": 3},
	{"id": "secondlife", "icon": "heart", "unlock": 15, "max": 1, "buy": 10000},
]
## Abilities replaced in 1.0.24 (old id -> new id): a save keeps the level it had.
const RENAMED := {"slowmo": "turbo", "headstart": "explorer"}
## TURBO: hold the screen; TURBO_TIME real seconds at TURBO_SCALE speed with every point worth
## TURBO_POINTS times as much. Charges per run = ability level. Risk for reward: the patterns
## are the same (still fair in game time), the player just has less time to react.
const TURBO_TIME := 4.0
const TURBO_SCALE := 1.5
const TURBO_POINTS := 2
## EXPLORER: coins for every new world reached in a run, per ability level (economy only: no
## points, nothing skipped). They count like picked coins (COINS+ applies).
const EXPLORER_COINS := [0, 5, 10, 15]
## TELEPORT: a swipe along the orbit jumps this far (rad); toward another planet, onto its orbit.
const TELEPORT_ARC := 1.25
## BUBBLES: each level adds this many points to every bubble popped (base 2).
const BUBBLE_BONUS := 1
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
