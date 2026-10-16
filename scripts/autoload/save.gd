extends Node
## Local persistent progress: stats, coins, cosmetics, purchases, daily gift and settings.

signal changed

const PATH := "user://orbitpop_save.cfg"
const VERSION := 2
const SKINS := Catalog.SKINS

var best := 0
var games := 0
var total := 0
var skin := 0                 # index in Catalog.SKINS
var trail := "classic"
var world := "sky"
var sound := true
var music := true
var recent: Array = []        # last scores, used for adaptive difficulty
var seen_unlocks: Array = [0] # skin indices the player was already told about
var purchases: Array = []     # owned non-consumable product ids (mirrors the store)
var coins := 0
var owned_items: Array = []   # "cat:id" bought with coins
var boosts := {"shield": 0, "rush": 0}
var daily_day := 0            # last claimed streak day (1..7)
var daily_last := ""          # local date of the last claim (YYYY-MM-DD)
var free_ads_date := ""
var free_ads_used := 0
var starter_seen := false
var path := PATH
var clock_override := -1.0    # tests: fake unix time
var _snapshot := {}


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
	trail = str(cfg.get_value("player", "trail", "classic"))
	world = str(cfg.get_value("player", "world", "sky"))
	seen_unlocks = cfg.get_value("player", "seen_unlocks", [0])
	purchases = cfg.get_value("shop", "purchases", [])
	coins = int(cfg.get_value("shop", "coins", 0))
	owned_items = cfg.get_value("shop", "owned_items", [])
	boosts = cfg.get_value("shop", "boosts", {"shield": 0, "rush": 0})
	starter_seen = bool(cfg.get_value("shop", "starter_seen", false))
	daily_day = int(cfg.get_value("daily", "day", 0))
	daily_last = str(cfg.get_value("daily", "last", ""))
	free_ads_date = str(cfg.get_value("daily", "free_ads_date", ""))
	free_ads_used = int(cfg.get_value("daily", "free_ads_used", 0))
	sound = bool(cfg.get_value("settings", "sound", true))
	music = bool(cfg.get_value("settings", "music", true))
	if skin < 0 or skin >= SKINS.size() or not is_unlocked(skin):
		skin = 0
	if not unlocked("trails", Catalog.find("trails", trail)):
		trail = "classic"
	if not unlocked("worlds", Catalog.find("worlds", world)):
		world = "sky"


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("stats", "best", best)
	cfg.set_value("stats", "games", games)
	cfg.set_value("stats", "total", total)
	cfg.set_value("stats", "recent", recent)
	cfg.set_value("player", "skin", skin)
	cfg.set_value("player", "trail", trail)
	cfg.set_value("player", "world", world)
	cfg.set_value("player", "seen_unlocks", seen_unlocks)
	cfg.set_value("shop", "purchases", purchases)
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "owned_items", owned_items)
	cfg.set_value("shop", "boosts", boosts)
	cfg.set_value("shop", "starter_seen", starter_seen)
	cfg.set_value("daily", "day", daily_day)
	cfg.set_value("daily", "last", daily_last)
	cfg.set_value("daily", "free_ads_date", free_ads_date)
	cfg.set_value("daily", "free_ads_used", free_ads_used)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "music", music)
	cfg.save(path)
	changed.emit()


# ------------------------------------------------------------------ runs

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


func recent_average() -> float:
	if recent.is_empty():
		return 0.0
	var s := 0.0
	for v in recent:
		s += float(v)
	return s / recent.size()


# ------------------------------------------------------------------ purchases

## "supporter" includes every pack; "starter" includes NO ADS.
func owns(product: String) -> bool:
	if purchases.has(product) or purchases.has("supporter"):
		return true
	return product == "no_ads" and purchases.has("starter")


func grant(product: String) -> void:
	var fresh := not purchases.has(product)
	if fresh:
		purchases.append(product)
		var bonus: Dictionary = MonetizationConfig.BUNDLE_BONUS.get(product, {})
		coins += int(bonus.get("coins", 0))
		for b in bonus.get("boosts", {}):
			boosts[b] = int(boosts.get(b, 0)) + int(bonus["boosts"][b])
	for i in SKINS.size():
		if is_unlocked(i) and not seen_unlocks.has(i):
			seen_unlocks.append(i)
	save_data()


# ------------------------------------------------------------------ cosmetics

func unlocked(cat: String, i: int) -> bool:
	var it: Dictionary = Catalog.items(cat)[i]
	var need: Array = it["need"]
	match need[0]:
		"shop":
			return owns(need[1])
		"coins":
			return owned_items.has(cat + ":" + it["id"])
		"total":
			return total >= int(need[1])
	return best >= int(need[1])


func is_unlocked(i: int) -> bool:
	return unlocked("skins", i)


func is_premium(i: int) -> bool:
	return SKINS[i]["need"][0] == "shop"


func need_text(cat: String, i: int) -> String:
	var need: Array = Catalog.items(cat)[i]["need"]
	match need[0]:
		"shop":
			return "SHOP"
		"coins":
			return str(need[1])
		"total":
			return "TOTAL %d" % need[1]
	return "BEST %d" % need[1]


func unlock_text(i: int) -> String:
	return need_text("skins", i)


## Buys a coin-priced cosmetic. Returns true on success.
func buy_item(cat: String, i: int) -> bool:
	var it: Dictionary = Catalog.items(cat)[i]
	if it["need"][0] != "coins" or unlocked(cat, i) or coins < int(it["need"][1]):
		return false
	coins -= int(it["need"][1])
	owned_items.append(cat + ":" + it["id"])
	save_data()
	return true


func select(cat: String, i: int) -> void:
	match cat:
		"skins":
			skin = i
		"trails":
			trail = Catalog.TRAILS[i]["id"]
		"worlds":
			world = Catalog.WORLDS[i]["id"]
	save_data()


func selected(cat: String) -> int:
	match cat:
		"trails":
			return Catalog.find("trails", trail)
		"worlds":
			return Catalog.find("worlds", world)
	return skin


func world_data() -> Dictionary:
	return Catalog.WORLDS[Catalog.find("worlds", world)]


# ------------------------------------------------------------------ coins & boosts

func add_coins(n: int) -> void:
	coins += maxi(0, n)
	save_data()


func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	save_data()
	return true


func add_boost(id: String, n := 1) -> void:
	boosts[id] = int(boosts.get(id, 0)) + n
	save_data()


func use_boost(id: String) -> bool:
	if int(boosts.get(id, 0)) <= 0:
		return false
	boosts[id] = int(boosts[id]) - 1
	save_data()
	return true


# ------------------------------------------------------------------ daily gift

func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()


func _day_string(offset_days := 0) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(_now()) + bias + offset_days * 86400)


func daily_available() -> bool:
	return daily_last != _day_string()


## The gift waiting today: {"day": 1..7, "coins": int, "boost": String}
func daily_preview() -> Dictionary:
	var day := 1
	if daily_last == _day_string(-1):
		day = daily_day % 7 + 1
	var r: Dictionary = MonetizationConfig.DAILY_REWARDS[day - 1]
	return {"day": day, "coins": int(r["coins"]), "boost": str(r.get("boost", ""))}


func claim_daily(multiplier := 1) -> Dictionary:
	if not daily_available():
		return {}
	var g := daily_preview()
	coins += int(g["coins"]) * multiplier
	if g["boost"] != "":
		boosts[g["boost"]] = int(boosts.get(g["boost"], 0)) + 1
	daily_day = int(g["day"])
	daily_last = _day_string()
	save_data()
	return g


func free_ads_left() -> int:
	if free_ads_date != _day_string():
		return MonetizationConfig.FREE_COIN_ADS_PER_DAY
	return maxi(0, MonetizationConfig.FREE_COIN_ADS_PER_DAY - free_ads_used)


func note_free_ad() -> void:
	if free_ads_date != _day_string():
		free_ads_date = _day_string()
		free_ads_used = 0
	free_ads_used += 1
	save_data()


func reset_all() -> void:
	best = 0; games = 0; total = 0; skin = 0
	trail = "classic"; world = "sky"
	recent = []; seen_unlocks = [0]; purchases = []
	coins = 0; owned_items = []; boosts = {"shield": 0, "rush": 0}
	daily_day = 0; daily_last = ""; free_ads_date = ""; free_ads_used = 0
	starter_seen = false
	save_data()
