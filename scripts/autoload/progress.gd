extends Node
## Missions (3 a day from a pool of 15 + 1 weekly challenge), player XP and levels,
## achievements, local top scores, leaderboard submission (global + regional) and cloud save sync.

signal mission_completed(text: String, reward: int)
signal achievement_unlocked(name: String)
signal level_up(level: int)

const PlayGames := preload("res://scripts/services/play_games.gd")
const Sharer := preload("res://scripts/services/sharer.gd")

## mode: "sum" adds per event, "max" keeps the best value. reward: coins, xp: player XP.
const MISSIONS := [
	{"id": "runs", "text": "M_RUNS", "goal": 3, "reward": 60, "xp": 40, "mode": "sum"},
	{"id": "score_run", "text": "M_SCORE_RUN", "goal": 25, "reward": 80, "xp": 50, "mode": "max"},
	{"id": "near", "text": "M_NEAR", "goal": 10, "reward": 80, "xp": 50, "mode": "sum"},
	{"id": "bubble", "text": "M_BUBBLE", "goal": 8, "reward": 70, "xp": 40, "mode": "sum"},
	{"id": "world", "text": "M_WORLD", "goal": 3, "reward": 100, "xp": 60, "mode": "max"},
	{"id": "flip", "text": "M_FLIP", "goal": 150, "reward": 60, "xp": 40, "mode": "sum"},
	{"id": "score_total", "text": "M_SCORE_TOTAL", "goal": 120, "reward": 90, "xp": 60, "mode": "sum"},
	{"id": "near_run", "text": "M_NEAR_RUN", "goal": 4, "reward": 100, "xp": 60, "mode": "max"},
	{"id": "time_run", "text": "M_TIME_RUN", "goal": 45, "reward": 90, "xp": 60, "mode": "max"},
	{"id": "score_run", "text": "M_SCORE_RUN", "goal": 50, "reward": 150, "xp": 90, "mode": "max"},
	{"id": "bubble_run", "text": "M_BUBBLE_RUN", "goal": 3, "reward": 90, "xp": 60, "mode": "max"},
	{"id": "coins_run", "text": "M_COINS_RUN", "goal": 15, "reward": 100, "xp": 60, "mode": "max"},
	{"id": "score_total", "text": "M_SCORE_TOTAL", "goal": 300, "reward": 150, "xp": 90, "mode": "sum"},
	{"id": "near", "text": "M_NEAR", "goal": 25, "reward": 120, "xp": 70, "mode": "sum"},
	{"id": "world", "text": "M_WORLD", "goal": 5, "reward": 150, "xp": 100, "mode": "max"},
]
const WEEKLY := [
	{"id": "score_total", "text": "M_SCORE_TOTAL", "goal": 2000, "reward": 600, "xp": 400, "mode": "sum"},
	{"id": "runs", "text": "M_RUNS", "goal": 40, "reward": 500, "xp": 300, "mode": "sum"},
	{"id": "world", "text": "M_WORLD", "goal": 7, "reward": 800, "xp": 500, "mode": "max"},
	{"id": "bubble", "text": "M_BUBBLE", "goal": 150, "reward": 500, "xp": 300, "mode": "sum"},
	{"id": "near", "text": "M_NEAR", "goal": 150, "reward": 600, "xp": 400, "mode": "sum"},
]
const DAILY_COUNT := 3

## stat: Save.stats key (or "best"/"games"/"total"/"skins"), name: [l10n key, arg]
const ACHIEVEMENTS := [
	{"id": "first", "name": ["A_FIRST"], "stat": "games", "goal": 1},
	{"id": "score25", "name": ["A_SCORE", 25], "stat": "best", "goal": 25},
	{"id": "score50", "name": ["A_SCORE", 50], "stat": "best", "goal": 50},
	{"id": "score100", "name": ["A_SCORE", 100], "stat": "best", "goal": 100},
	{"id": "score200", "name": ["A_SCORE", 200], "stat": "best", "goal": 200},
	{"id": "score350", "name": ["A_SCORE", 350], "stat": "best", "goal": 350},
	{"id": "score500", "name": ["A_SCORE", 500], "stat": "best", "goal": 500},
	{"id": "score750", "name": ["A_SCORE", 750], "stat": "best", "goal": 750},
	{"id": "score1000", "name": ["A_SCORE", 1000], "stat": "best", "goal": 1000},
	{"id": "world3", "name": ["A_WORLD", 3], "stat": "best_world", "goal": 3},
	{"id": "world5", "name": ["A_WORLD", 5], "stat": "best_world", "goal": 5},
	{"id": "world7", "name": ["A_WORLD", 7], "stat": "best_world", "goal": 7},
	{"id": "world10", "name": ["A_WORLD", 10], "stat": "best_world", "goal": 10},
	{"id": "world15", "name": ["A_WORLD", 15], "stat": "best_world", "goal": 15},
	{"id": "near100", "name": ["A_NEAR", 100], "stat": "near_total", "goal": 100},
	{"id": "near500", "name": ["A_NEAR", 500], "stat": "near_total", "goal": 500},
	{"id": "near2000", "name": ["A_NEAR", 2000], "stat": "near_total", "goal": 2000},
	{"id": "bubbles250", "name": ["A_BUBBLES", 250], "stat": "bubbles_total", "goal": 250},
	{"id": "bubbles1000", "name": ["A_BUBBLES", 1000], "stat": "bubbles_total", "goal": 1000},
	{"id": "games100", "name": ["A_GAMES", 100], "stat": "games", "goal": 100},
	{"id": "games500", "name": ["A_GAMES", 500], "stat": "games", "goal": 500},
	{"id": "games1000", "name": ["A_GAMES", 1000], "stat": "games", "goal": 1000},
	{"id": "total5000", "name": ["A_TOTAL", 5000], "stat": "total", "goal": 5000},
	{"id": "total25000", "name": ["A_TOTAL", 25000], "stat": "total", "goal": 25000},
	{"id": "total100000", "name": ["A_TOTAL", 100000], "stat": "total", "goal": 100000},
	{"id": "missions10", "name": ["A_MISSIONS", 10], "stat": "missions_done", "goal": 10},
	{"id": "missions30", "name": ["A_MISSIONS", 30], "stat": "missions_done", "goal": 30},
	{"id": "missions100", "name": ["A_MISSIONS", 100], "stat": "missions_done", "goal": 100},
	{"id": "switch50", "name": ["A_SWITCH", 50], "stat": "switch_total", "goal": 50},
	{"id": "switch250", "name": ["A_SWITCH", 250], "stat": "switch_total", "goal": 250},
	{"id": "warp25", "name": ["A_TELEPORT", 25], "stat": "teleport_total", "goal": 25},
	{"id": "skins10", "name": ["A_SKINS", 10], "stat": "skins", "goal": 10},
	{"id": "skins20", "name": ["A_SKINS", 20], "stat": "skins", "goal": 20},
	{"id": "skins_all", "name": ["A_SKINS_ALL"], "stat": "skins", "goal": 26},
]

var games: Node     # Play Games adapter
var sharer: Node
var pending: Array = []   # messages to show once the run is over
var _run := {}


func _ready() -> void:
	games = PlayGames.new()
	add_child(games)
	sharer = Sharer.new()
	add_child(sharer)
	games.cloud_loaded.connect(_on_cloud)
	games.signed_in_changed.connect(func(ok): if ok: _sync_all())
	games.start()
	sharer.start()


# ------------------------------------------------------------------ missions

## Pool indices of today's missions (3 distinct, the set rotates every day).
static func daily_indices(day: int) -> Array:
	var base := posmod(day * 7, MISSIONS.size())
	return [base, (base + 5) % MISSIONS.size(), (base + 10) % MISSIONS.size()]


func _roll() -> void:
	var today := Save.day_number()
	if int(Save.missions.get("day", -1)) != today:
		var list: Array = []
		for i in daily_indices(today):
			list.append({"i": i, "p": 0, "done": false})
		Save.missions["day"] = today
		Save.missions["list"] = list
	var week := floori(today / 7.0)
	if int(Save.missions.get("week", -1)) != week:
		Save.missions["week"] = week
		Save.missions["weekly"] = {"i": posmod(week, WEEKLY.size()), "p": 0, "done": false}


func _view(def: Dictionary, st: Dictionary) -> Dictionary:
	return {"text": L.t(def["text"], def["goal"]), "goal": int(def["goal"]), "reward": int(def["reward"]), "xp": int(def["xp"]),
		"progress": mini(int(st["p"]), int(def["goal"])), "done": bool(st["done"])}


## Today's 3 missions: [{text, goal, reward, xp, progress, done}]
func missions() -> Array:
	_roll()
	var out: Array = []
	for st in Save.missions["list"]:
		out.append(_view(MISSIONS[int(st["i"])], st))
	return out


func weekly() -> Dictionary:
	_roll()
	var st: Dictionary = Save.missions["weekly"]
	return _view(WEEKLY[int(st["i"])], st)


func missions_left() -> int:
	return missions().filter(func(m): return not m["done"]).size()


func _mission_feed(id: String, value: int) -> void:
	_roll()
	var entries: Array = []
	for st in Save.missions["list"]:
		entries.append([MISSIONS[int(st["i"])], st])
	entries.append([WEEKLY[int(Save.missions["weekly"]["i"])], Save.missions["weekly"]])
	for e in entries:
		var m: Dictionary = e[0]
		var st: Dictionary = e[1]
		if m["id"] != id or st["done"]:
			continue
		st["p"] = int(st["p"]) + value if m["mode"] == "sum" else maxi(int(st["p"]), value)
		if int(st["p"]) >= int(m["goal"]):
			st["done"] = true
			Save.coins += int(m["reward"])
			Save.stats["missions_done"] = int(Save.stats.get("missions_done", 0)) + 1
			pending.append(L.t("MISSION_DONE") + " " + L.t("PLUS_COINS", int(m["reward"])))
			mission_completed.emit(L.t(m["text"], m["goal"]), int(m["reward"]))
			award_xp(int(m["xp"]))
			_check_achievements()


# ------------------------------------------------------------------ level

## Adds player XP; level-ups pay coins and may unlock abilities (messages shown after the run).
func award_xp(n: int) -> Array:
	var levels: Array = Save.add_xp(n)
	for lv in levels:
		pending.append(L.t("LEVEL_UP", lv) + " " + L.t("PLUS_COINS", Upgrades.level_coins(lv)))
		for a in Upgrades.unlocked_at(lv):
			pending.append(L.t("NEW_ABILITY", L.t("AB_" + str(a["id"]).to_upper())))
		level_up.emit(lv)
	return levels


## Leaderboard region: the player's choice, or the one guessed from the device locale.
func region() -> String:
	return Save.region if PlayGamesConfig.REGION_NAMES.has(Save.region) else PlayGamesConfig.region()


# ------------------------------------------------------------------ run events

func run_started() -> void:
	_run = {"near": 0, "score": 0, "bubbles": 0, "coins": 0}


## Gameplay events: flip, switch, near, bubble, coin(value), teleport, score_now(value), world(value)
func event(name: String, value := 1) -> void:
	match name:
		"flip":
			_mission_feed("flip", 1)
		"switch":
			_stat_add("switch_total")
		"teleport":
			_stat_add("teleport_total")
		"near":
			_run["near"] = int(_run.get("near", 0)) + 1
			_stat_add("near_total")
			_mission_feed("near", 1)
			_mission_feed("near_run", int(_run["near"]))
		"bubble":
			_run["bubbles"] = int(_run.get("bubbles", 0)) + 1
			_stat_add("bubbles_total")
			_mission_feed("bubble", 1)
			_mission_feed("bubble_run", int(_run["bubbles"]))
		"coin":
			_run["coins"] = int(_run.get("coins", 0)) + value
			_stat_add("coins_picked", value)
			_mission_feed("coins_run", int(_run["coins"]))
		"score_now":
			_run["score"] = value
			_mission_feed("score_run", value)
		"world":
			Save.stats["best_world"] = maxi(int(Save.stats.get("best_world", 1)), value)
			_mission_feed("world", value)
			_check_achievements()


func _stat_add(key: String, n := 1) -> void:
	Save.stats[key] = int(Save.stats.get(key, 0)) + n


func run_finished(score: int, world_no: int, time_s := 0.0) -> void:
	_mission_feed("runs", 1)
	_mission_feed("score_total", score)
	_mission_feed("time_run", int(time_s))
	Save.add_top_score(score, world_no)
	_check_achievements()
	Save.save_data()
	games.submit_score("GLOBAL", Save.best)
	games.submit_score(region(), Save.best)
	games.save_cloud(Save.export_data())


## Messages collected during the run (missions, achievements), shown on game over.
func take_pending() -> Array:
	var p := pending.duplicate()
	pending.clear()
	return p


# ------------------------------------------------------------------ achievements

func stat(key: String) -> int:
	match key:
		"best":
			return Save.best
		"games":
			return Save.games
		"total":
			return Save.total
		"skins":
			var n := 0
			for i in Save.SKINS.size():
				if Save.is_unlocked(i):
					n += 1
			return n
	return int(Save.stats.get(key, 1 if key == "best_world" else 0))


func achievement_name(a: Dictionary) -> String:
	var n: Array = a["name"]
	return L.t(n[0], n[1]) if n.size() > 1 else L.t(n[0])


func _check_achievements() -> void:
	for a in ACHIEVEMENTS:
		if Save.achievements.has(a["id"]):
			continue
		if stat(a["stat"]) >= int(a["goal"]):
			Save.achievements.append(a["id"])
			games.unlock(a["id"])
			pending.append(L.t("ACH_UNLOCKED", achievement_name(a)))
			achievement_unlocked.emit(achievement_name(a))


func _sync_all() -> void:
	for id in Save.achievements:
		games.unlock(id)
	games.submit_score("GLOBAL", Save.best)
	games.submit_score(region(), Save.best)


func _on_cloud(data: Dictionary) -> void:
	if Save.merge(data):
		pending.append(L.t("CLOUD_LOADED"))
	games.save_cloud(Save.export_data())


# ------------------------------------------------------------------ share

func share(score: int, img: Image) -> bool:
	return sharer.share_score(L.t("SHARE_TEXT", score), img)
