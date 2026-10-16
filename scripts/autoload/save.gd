extends Node
## Local persistent progress: best score, stats, skins and settings.

signal changed

const PATH := "user://orbitpop_save.cfg"
const VERSION := 1

## Skin catalog. `need` = [stat, value]; stat is "best", "total" or "shop" (value = product id).
const SKINS := [
	{"id": "poppy", "name": "POPPY", "need": ["best", 0]},
	{"id": "minty", "name": "MINTY", "need": ["best", 10]},
	{"id": "berry", "name": "BERRY", "need": ["best", 25]},
	{"id": "frosty", "name": "FROSTY", "need": ["total", 250]},
	{"id": "ember", "name": "EMBER", "need": ["best", 50]},
	{"id": "cosmo", "name": "COSMO", "need": ["best", 80]},
	{"id": "goldie", "name": "GOLDIE", "need": ["shop", "star_pack"]},
	{"id": "neon", "name": "NEON", "need": ["shop", "star_pack"]},
	{"id": "panda", "name": "PANDA", "need": ["shop", "star_pack"]},
]

var best := 0
var games := 0
var total := 0
var skin := 0
var sound := true
var music := true
var recent: Array = []        # last few scores, used for adaptive difficulty
var seen_unlocks: Array = [0] # skin indices the player was already told about
var purchases: Array = []     # owned non-consumable product ids (mirrors the store)
var _snapshot := {}           # stats before the last submit_run (for "continue")
var path := PATH


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	best = int(cfg.get_value("stats", "best", 0))
	games = int(cfg.get_value("stats", "games", 0))
	total = int(cfg.get_value("stats", "total", 0))
	recent = cfg.get_value("stats", "recent", [])
	skin = int(cfg.get_value("player", "skin", 0))
	seen_unlocks = cfg.get_value("player", "seen_unlocks", [0])
	purchases = cfg.get_value("shop", "purchases", [])
	sound = bool(cfg.get_value("settings", "sound", true))
	music = bool(cfg.get_value("settings", "music", true))
	if skin < 0 or skin >= SKINS.size() or not is_unlocked(skin):
		skin = 0


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("stats", "best", best)
	cfg.set_value("stats", "games", games)
	cfg.set_value("stats", "total", total)
	cfg.set_value("stats", "recent", recent)
	cfg.set_value("player", "skin", skin)
	cfg.set_value("player", "seen_unlocks", seen_unlocks)
	cfg.set_value("shop", "purchases", purchases)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "music", music)
	cfg.save(path)
	changed.emit()


## Registers a finished run. Returns {"record": bool, "unlocked": Array[int]}.
func submit_run(score: int) -> Dictionary:
	_snapshot = {"best": best, "games": games, "total": total, "recent": recent.duplicate(), "seen": seen_unlocks.duplicate()}
	games += 1
	total += score
	var record := score > best
	if record:
		best = score
	recent.append(score)
	while recent.size() > 5:
		recent.pop_front()
	var fresh := []
	for i in SKINS.size():
		if is_unlocked(i) and not seen_unlocks.has(i):
			seen_unlocks.append(i)
			fresh.append(i)
	save_data()
	return {"record": record, "unlocked": fresh}


## Reverts the last submit_run (the player continued that same run).
func undo_last_run() -> void:
	if _snapshot.is_empty():
		return
	best = _snapshot["best"]; games = _snapshot["games"]; total = _snapshot["total"]
	recent = _snapshot["recent"]; seen_unlocks = _snapshot["seen"]
	_snapshot = {}
	save_data()


## "supporter" includes every other product.
func owns(product: String) -> bool:
	return purchases.has(product) or purchases.has("supporter")


func grant(product: String) -> void:
	if not purchases.has(product):
		purchases.append(product)
	for i in SKINS.size():
		if is_unlocked(i) and not seen_unlocks.has(i):
			seen_unlocks.append(i)
	save_data()


func is_premium(i: int) -> bool:
	return SKINS[i]["need"][0] == "shop"


func is_unlocked(i: int) -> bool:
	var need: Array = SKINS[i]["need"]
	if need[0] == "shop":
		return owns(need[1])
	var v := best if need[0] == "best" else total
	return v >= int(need[1])


func unlock_text(i: int) -> String:
	var need: Array = SKINS[i]["need"]
	if need[0] == "shop":
		return "SHOP"
	if need[0] == "best":
		return "BEST %d" % need[1]
	return "TOTAL %d" % need[1]


func recent_average() -> float:
	if recent.is_empty():
		return 0.0
	var s := 0.0
	for v in recent:
		s += float(v)
	return s / recent.size()


func reset_all() -> void:
	best = 0; games = 0; total = 0; skin = 0
	recent = []; seen_unlocks = [0]; purchases = []
	save_data()
