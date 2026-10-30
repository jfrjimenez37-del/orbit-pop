extends Node
## Local persistent progress: stats, coins, player level and abilities, cosmetics, purchases,
## daily gift, missions and settings.

signal changed

const PATH := "user://orbitpop_save.cfg"
const VERSION := 3
## Old consumable boosts are refunded in coins when an old save loads (they became abilities).
const BOOST_REFUND := {"shield": 150, "rush": 100, "teleport": 120}
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
var seen_unlocks: Array = ["poppy"] # skin ids the player was already told about
var purchases: Array = []     # owned non-consumable product ids (mirrors the store)
var coins := 0
var owned_items: Array = []   # "cat:id" bought with coins
var level := 1
var xp := 0                   # XP inside the current level
var abilities := {}           # ability id -> level (see Upgrades)
var start_world := 1          # chosen HEADSTART world (1 = normal start)
var region := ""              # leaderboard region, "" = from the device locale
var daily_day := 0            # last claimed streak day (1..7)
var daily_last := ""          # local date of the last claim (YYYY-MM-DD)
var free_ads_date := ""
var free_ads_used := 0
var starter_seen := false
var reduce_motion := false   # Settings: no ascent scroll / sway
var sessions := 0             # app launches (no interstitial in the very first one)
var free_continue_day := -1   # NO ADS: one free continue a day
var video_up := {}            # {"id": ability, "n": videos watched, "day": day of the last video level}
var offers := {}              # offer id -> day it was last shown
var notifications := true     # Settings: daily reminders
var notif_asked := false      # Android permission already requested
var review_asks := 0          # times the Play review sheet was requested
var review_day := -9999       # day_number() of the last request
var vibration := true
var lang := ""                # "" = follow the device
var stats := {}               # near_total, bubbles_total, switch_total, teleport_total, missions_done, best_world
var achievements: Array = []  # unlocked achievement ids
var top_scores: Array = []    # [{"s": score, "w": world, "d": "YYYY-MM-DD"}] best 10
## daily: {"day", "list": [{"i", "p", "done"}]}, weekly: {"week", "i", "p", "done"}
var missions := {"day": -1, "list": [], "week": -1, "weekly": {}}
var saved_at := 0
var path := PATH
var clock_override := -1.0    # tests: fake unix time
var _snapshot := {}


func _ready() -> void:
	load_data()
	sessions += 1
	save_data()


func load_data() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	best = int(cfg.get_value("stats", "best", 0))
	games = int(cfg.get_value("stats", "games", 0))
	total = int(cfg.get_value("stats", "total", 0))
	recent = cfg.get_value("stats", "recent", [])
	skin = Catalog.skin_index(cfg.get_value("player", "skin_id", cfg.get_value("player", "skin", 0)))
	trail = str(cfg.get_value("player", "trail", "classic"))
	world = str(cfg.get_value("player", "world", "sky"))
	seen_unlocks = _seen_ids(cfg.get_value("player", "seen_unlocks", ["poppy"]))
	purchases = cfg.get_value("shop", "purchases", [])
	coins = int(cfg.get_value("shop", "coins", 0))
	owned_items = cfg.get_value("shop", "owned_items", [])
	var old_boosts: Dictionary = cfg.get_value("shop", "boosts", {})
	for b in old_boosts:
		coins += int(old_boosts[b]) * int(BOOST_REFUND.get(b, 100))
	level = clampi(int(cfg.get_value("player", "level", 1)), 1, Upgrades.MAX_LEVEL)
	xp = int(cfg.get_value("player", "xp", 0))
	abilities = cfg.get_value("player", "abilities", {})
	start_world = int(cfg.get_value("player", "start_world", 1))
	region = str(cfg.get_value("settings", "region", ""))
	starter_seen = bool(cfg.get_value("shop", "starter_seen", false))
	review_asks = int(cfg.get_value("meta", "review_asks", 0))
	reduce_motion = bool(cfg.get_value("settings", "reduce_motion", false))
	sessions = int(cfg.get_value("meta", "sessions", 0))
	free_continue_day = int(cfg.get_value("shop", "free_continue_day", -1))
	video_up = cfg.get_value("player", "video_up", {})
	offers = cfg.get_value("shop", "offers", {})
	notifications = bool(cfg.get_value("settings", "notifications", true))
	notif_asked = bool(cfg.get_value("meta", "notif_asked", false))
	review_day = int(cfg.get_value("meta", "review_day", -9999))
	daily_day = int(cfg.get_value("daily", "day", 0))
	daily_last = str(cfg.get_value("daily", "last", ""))
	free_ads_date = str(cfg.get_value("daily", "free_ads_date", ""))
	free_ads_used = int(cfg.get_value("daily", "free_ads_used", 0))
	sound = bool(cfg.get_value("settings", "sound", true))
	music = bool(cfg.get_value("settings", "music", true))
	vibration = bool(cfg.get_value("settings", "vibration", true))
	lang = str(cfg.get_value("settings", "lang", ""))
	stats = cfg.get_value("progress", "stats", {})
	achievements = cfg.get_value("progress", "achievements", [])
	top_scores = cfg.get_value("progress", "top_scores", [])
	missions = cfg.get_value("progress", "missions", {"day": -1, "list": [], "week": -1, "weekly": {}})
	saved_at = int(cfg.get_value("meta", "saved_at", 0))
	if skin < 0 or skin >= SKINS.size() or not is_unlocked(skin):
		skin = 0
	if not unlocked("trails", Catalog.find("trails", trail)):
		trail = "classic"


func save_data() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("stats", "best", best)
	cfg.set_value("stats", "games", games)
	cfg.set_value("stats", "total", total)
	cfg.set_value("stats", "recent", recent)
	cfg.set_value("player", "skin_id", SKINS[skin]["id"])
	cfg.set_value("player", "trail", trail)
	cfg.set_value("player", "world", world)
	cfg.set_value("player", "seen_unlocks", seen_unlocks)
	cfg.set_value("shop", "purchases", purchases)
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "owned_items", owned_items)
	cfg.set_value("player", "level", level)
	cfg.set_value("player", "xp", xp)
	cfg.set_value("player", "abilities", abilities)
	cfg.set_value("player", "start_world", start_world)
	cfg.set_value("settings", "region", region)
	cfg.set_value("shop", "starter_seen", starter_seen)
	cfg.set_value("meta", "review_asks", review_asks)
	cfg.set_value("settings", "reduce_motion", reduce_motion)
	cfg.set_value("meta", "sessions", sessions)
	cfg.set_value("shop", "free_continue_day", free_continue_day)
	cfg.set_value("player", "video_up", video_up)
	cfg.set_value("shop", "offers", offers)
	cfg.set_value("settings", "notifications", notifications)
	cfg.set_value("meta", "notif_asked", notif_asked)
	cfg.set_value("meta", "review_day", review_day)
	cfg.set_value("daily", "day", daily_day)
	cfg.set_value("daily", "last", daily_last)
	cfg.set_value("daily", "free_ads_date", free_ads_date)
	cfg.set_value("daily", "free_ads_used", free_ads_used)
	cfg.set_value("settings", "sound", sound)
	cfg.set_value("settings", "music", music)
	cfg.set_value("settings", "vibration", vibration)
	cfg.set_value("settings", "lang", lang)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "achievements", achievements)
	cfg.set_value("progress", "top_scores", top_scores)
	cfg.set_value("progress", "missions", missions)
	saved_at = int(_now())
	cfg.set_value("meta", "saved_at", saved_at)
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
	var fresh := note_unlocks()
	save_data()
	return {"record": record, "unlocked": fresh}


## Marks newly unlocked skins as seen and returns their indices.
func note_unlocks() -> Array:
	var fresh := []
	for i in SKINS.size():
		if is_unlocked(i) and not seen_unlocks.has(SKINS[i]["id"]):
			seen_unlocks.append(SKINS[i]["id"])
			fresh.append(i)
	return fresh


## Legacy saves stored skin indices; convert them to ids.
static func _seen_ids(list: Array) -> Array:
	var out: Array = []
	for v in list:
		var id: String = v if v is String else Catalog.SKINS[Catalog.skin_index(v)]["id"]
		if not out.has(id):
			out.append(id)
	return out


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
	if purchases.has(product):
		return true
	if purchases.has("supporter") and MonetizationConfig.SUPPORTER_INCLUDES.has(product):
		return true
	return product == "no_ads" and purchases.has("starter")


func grant(product: String) -> void:
	var fresh := not purchases.has(product)
	if fresh:
		purchases.append(product)
		var bonus: Dictionary = MonetizationConfig.BUNDLE_BONUS.get(product, {})
		coins += int(bonus.get("coins", 0))
	note_unlocks()
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
		"world":
			return int(stats.get("best_world", 1)) >= int(need[1])
		"level":
			return level >= int(need[1])
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
		"world":
			return "WORLD %d" % need[1]
		"level":
			return "LEVEL %d" % need[1]
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


# ------------------------------------------------------------------ coins

func add_coins(n: int) -> void:
	coins += maxi(0, n)
	save_data()


func spend(n: int) -> bool:
	if coins < n:
		return false
	coins -= n
	save_data()
	return true


# ------------------------------------------------------------------ level & abilities

## Adds XP. Returns the player levels reached (each grants coins; abilities may unlock).
func add_xp(n: int) -> Array:
	var gained: Array = []
	if level >= Upgrades.MAX_LEVEL:
		return gained
	xp += maxi(0, n)
	while level < Upgrades.MAX_LEVEL and xp >= Upgrades.xp_next(level):
		xp -= Upgrades.xp_next(level)
		level += 1
		gained.append(level)
		coins += Upgrades.level_coins(level)
		for a in Upgrades.unlocked_at(level):
			if not a.has("buy"):
				abilities[a["id"]] = maxi(1, int(abilities.get(a["id"], 0)))
	if level >= Upgrades.MAX_LEVEL:
		xp = 0
	note_unlocks()
	save_data()
	return gained


func ability(id: String) -> int:
	return int(abilities.get(id, 0))


func ability_unlocked(id: String) -> bool:
	return level >= int(Upgrades.find(id)["unlock"])


## Buys the next level of an ability with coins. Returns true on success.
func buy_ability(id: String) -> bool:
	var cost := Upgrades.price(id, ability(id))
	if cost < 0 or not ability_unlocked(id) or coins < cost:
		return false
	coins -= cost
	abilities[id] = ability(id) + 1
	save_data()
	return true


# ------------------------------------------------------------------ ability levels by video

## Ability the "watch videos" upgrade goes to: the lowest unlocked one at level 1 or 2.
func video_target() -> String:
	var best_id := ""
	var best_lv := 99
	for a in Upgrades.ABILITIES:
		var id: String = a["id"]
		var lv := ability(id)
		if ability_unlocked(id) and lv >= 1 and lv < mini(int(a["max"]), MonetizationConfig.VIDEO_UPGRADE_ADS.size()) and lv < best_lv:
			best_id = id
			best_lv = lv
	if video_up.get("id", "") != "" and video_up.get("id") != best_id and int(video_up.get("n", 0)) > 0:
		return video_up["id"]   # keep the one in progress
	return best_id


func video_needed(id: String) -> int:
	var lv := ability(id)
	return MonetizationConfig.VIDEO_UPGRADE_ADS[lv] if lv < MonetizationConfig.VIDEO_UPGRADE_ADS.size() else 0


## True if a video level can still be earned today.
func video_open_today() -> bool:
	return int(video_up.get("day", -1)) != day_number() and video_target() != ""


## One video watched. Returns the ability upgraded when it completes the level, else "".
func video_ad_watched() -> String:
	var id := video_target()
	if id == "" or not video_open_today():
		return ""
	var n := int(video_up.get("n", 0)) + 1 if video_up.get("id", "") == id else 1
	if n >= video_needed(id):
		abilities[id] = ability(id) + 1
		video_up = {"id": "", "n": 0, "day": day_number()}
		save_data()
		return id
	video_up = {"id": id, "n": n, "day": int(video_up.get("day", -1))}
	save_data()
	return ""


## Highest world the player may start in (HEADSTART), never above a world already passed.
func headstart_max() -> int:
	var cap: int = Upgrades.HEADSTART_WORLD[mini(ability("headstart"), Upgrades.HEADSTART_WORLD.size() - 1)]
	return maxi(1, mini(cap, int(stats.get("best_world", 1)) - 1))


func chosen_start_world() -> int:
	return clampi(start_world, 1, headstart_max())


# ------------------------------------------------------------------ daily gift

func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_unix_time_from_system()


func _day_string(offset_days := 0) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(_now()) + bias + offset_days * 86400)


## Local day counter (days since epoch), used to rotate daily missions.
func day_number() -> int:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return int(floor((_now() + bias) / 86400.0))


func add_top_score(score: int, world_no: int) -> void:
	top_scores.append({"s": score, "w": world_no, "d": _day_string()})
	top_scores.sort_custom(func(a, b): return int(a["s"]) > int(b["s"]))
	if top_scores.size() > 10:
		top_scores.resize(10)


func vibrate(ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(ms)


# ------------------------------------------------------------------ cloud save

const _CLOUD_KEYS := ["best", "games", "total", "coins", "owned_items", "purchases", "stats", "level", "xp", "abilities",
	"achievements", "top_scores", "seen_unlocks", "skin", "trail", "daily_day", "daily_last", "missions", "saved_at"]


func export_data() -> Dictionary:
	var d := {}
	for k in _CLOUD_KEYS:
		d[k] = get(k)
	d["skin"] = SKINS[skin]["id"]
	return d


## Merges a cloud snapshot: records, level and unlocks are combined, the wallet follows the newer save.
## Returns true if anything changed.
func merge(d: Dictionary) -> bool:
	var before := JSON.stringify(export_data())
	var newer := int(d.get("saved_at", 0)) > saved_at
	best = maxi(best, int(d.get("best", 0)))
	games = maxi(games, int(d.get("games", 0)))
	total = maxi(total, int(d.get("total", 0)))
	d["seen_unlocks"] = _seen_ids(d.get("seen_unlocks", []))
	for key in ["owned_items", "purchases", "achievements", "seen_unlocks"]:
		var mine: Array = get(key)
		for v in d.get(key, []):
			if not mine.has(v):
				mine.append(v)
	var lv := int(d.get("level", 1))
	if lv > level or (lv == level and int(d.get("xp", 0)) > xp):
		level = clampi(lv, 1, Upgrades.MAX_LEVEL)
		xp = int(d.get("xp", 0))
	var ab: Dictionary = d.get("abilities", {})
	for k in ab:
		abilities[k] = maxi(ability(k), int(ab[k]))
	var st: Dictionary = d.get("stats", {})
	for k in st:
		stats[k] = maxi(int(stats.get(k, 0)), int(st[k]))
	for e in d.get("top_scores", []):
		if not top_scores.has(e):
			top_scores.append(e)
	top_scores.sort_custom(func(a, b): return int(a["s"]) > int(b["s"]))
	if top_scores.size() > 10:
		top_scores.resize(10)
	if newer:
		coins = int(d.get("coins", coins))
		daily_day = int(d.get("daily_day", daily_day))
		daily_last = str(d.get("daily_last", daily_last))
		missions = d.get("missions", missions)
		skin = Catalog.skin_index(d.get("skin", SKINS[skin]["id"]))
		trail = str(d.get("trail", trail))
	if skin < 0 or skin >= SKINS.size() or not is_unlocked(skin):
		skin = 0
	var changed_any := JSON.stringify(export_data()) != before
	save_data()
	return changed_any


func daily_available() -> bool:
	return daily_last != _day_string()


## The gift waiting today: {"day": 1..7, "coins": int}
func daily_preview() -> Dictionary:
	var day := 1
	if daily_last == _day_string(-1):
		day = daily_day % 7 + 1
	var r: Dictionary = MonetizationConfig.DAILY_REWARDS[day - 1]
	return {"day": day, "coins": int(r["coins"])}


func claim_daily(multiplier := 1) -> Dictionary:
	if not daily_available():
		return {}
	var g := daily_preview()
	coins += int(g["coins"]) * multiplier
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
	recent = []; seen_unlocks = ["poppy"]; purchases = []
	coins = 0; owned_items = []
	level = 1; xp = 0; abilities = {}; start_world = 1; region = ""
	daily_day = 0; daily_last = ""; free_ads_date = ""; free_ads_used = 0
	starter_seen = false
	review_asks = 0
	review_day = -9999
	reduce_motion = false
	sessions = 0
	free_continue_day = -1
	video_up = {}
	offers = {}
	notifications = true
	notif_asked = false
	stats = {}; achievements = []; top_scores = []
	missions = {"day": -1, "list": [], "week": -1, "weekly": {}}
	save_data()
