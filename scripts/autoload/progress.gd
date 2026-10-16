extends Node
## Daily missions (10, one per day, cycling), achievements, local top scores,
## leaderboard submission (global + regional) and cloud save sync.

signal mission_completed(text: String, reward: int)
signal achievement_unlocked(name: String)

const PlayGames := preload("res://scripts/services/play_games.gd")
const Sharer := preload("res://scripts/services/sharer.gd")

## kind: how progress is counted. "sum" adds per event, "max" keeps the best value.
const MISSIONS := [
	{"id": "runs", "text": "M_RUNS", "goal": 3, "reward": 60, "mode": "sum"},
	{"id": "score_run", "text": "M_SCORE_RUN", "goal": 25, "reward": 80, "mode": "max"},
	{"id": "near", "text": "M_NEAR", "goal": 10, "reward": 80, "mode": "sum"},
	{"id": "bubble", "text": "M_BUBBLE", "goal": 8, "reward": 70, "mode": "sum"},
	{"id": "world", "text": "M_WORLD", "goal": 3, "reward": 100, "mode": "max"},
	{"id": "flip", "text": "M_FLIP", "goal": 150, "reward": 60, "mode": "sum"},
	{"id": "score_total", "text": "M_SCORE_TOTAL", "goal": 120, "reward": 90, "mode": "sum"},
	{"id": "near_run", "text": "M_NEAR_RUN", "goal": 4, "reward": 100, "mode": "max"},
	{"id": "time_run", "text": "M_TIME_RUN", "goal": 45, "reward": 90, "mode": "max"},
	{"id": "score_run", "text": "M_SCORE_RUN", "goal": 50, "reward": 150, "mode": "max"},
]

## stat: Save.stats key (or "best"/"games"), name: [l10n key, arg]
const ACHIEVEMENTS := [
	{"id": "first", "name": ["A_FIRST"], "stat": "games", "goal": 1},
	{"id": "score10", "name": ["A_SCORE", 10], "stat": "best", "goal": 10},
	{"id": "score25", "name": ["A_SCORE", 25], "stat": "best", "goal": 25},
	{"id": "score50", "name": ["A_SCORE", 50], "stat": "best", "goal": 50},
	{"id": "score100", "name": ["A_SCORE", 100], "stat": "best", "goal": 100},
	{"id": "score150", "name": ["A_SCORE", 150], "stat": "best", "goal": 150},
	{"id": "world2", "name": ["A_WORLD", 2], "stat": "best_world", "goal": 2},
	{"id": "world3", "name": ["A_WORLD", 3], "stat": "best_world", "goal": 3},
	{"id": "world4", "name": ["A_WORLD", 4], "stat": "best_world", "goal": 4},
	{"id": "world5", "name": ["A_WORLD", 5], "stat": "best_world", "goal": 5},
	{"id": "near50", "name": ["A_NEAR", 50], "stat": "near_total", "goal": 50},
	{"id": "bubbles100", "name": ["A_BUBBLES", 100], "stat": "bubbles_total", "goal": 100},
	{"id": "games50", "name": ["A_GAMES", 50], "stat": "games", "goal": 50},
	{"id": "missions7", "name": ["A_MISSIONS", 7], "stat": "missions_done", "goal": 7},
	{"id": "switch10", "name": ["A_SWITCH", 10], "stat": "switch_total", "goal": 10},
	{"id": "warp", "name": ["A_TELEPORT"], "stat": "teleport_total", "goal": 1},
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

func mission_index() -> int:
	return posmod(Save.day_number(), MISSIONS.size())


func mission() -> Dictionary:
	_roll_day()
	var m: Dictionary = MISSIONS[mission_index()]
	return {"text": L.t(m["text"], m["goal"]), "goal": int(m["goal"]), "reward": int(m["reward"]),
		"progress": mini(int(Save.mission["progress"]), int(m["goal"])), "done": bool(Save.mission["done"])}


func _roll_day() -> void:
	var today := Save.day_number()
	if int(Save.mission.get("day", -1)) != today:
		Save.mission = {"day": today, "progress": 0, "done": false}


func _mission_feed(id: String, value: int) -> void:
	_roll_day()
	var m: Dictionary = MISSIONS[mission_index()]
	if m["id"] != id or Save.mission["done"]:
		return
	if m["mode"] == "sum":
		Save.mission["progress"] = int(Save.mission["progress"]) + value
	else:
		Save.mission["progress"] = maxi(int(Save.mission["progress"]), value)
	if int(Save.mission["progress"]) >= int(m["goal"]):
		Save.mission["done"] = true
		Save.coins += int(m["reward"])
		Save.stats["missions_done"] = int(Save.stats.get("missions_done", 0)) + 1
		var txt := L.t("MISSION_DONE") + " " + L.t("PLUS_COINS", int(m["reward"]))
		pending.append(txt)
		mission_completed.emit(L.t(m["text"], m["goal"]), int(m["reward"]))
		_check_achievements()


# ------------------------------------------------------------------ run events

func run_started() -> void:
	_run = {"near": 0, "score": 0}


## Gameplay events: flip, switch, near, bubble, teleport, score_now(value), world(value)
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
			_stat_add("bubbles_total")
			_mission_feed("bubble", 1)
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
	games.submit_score(PlayGamesConfig.region(), Save.best)
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
	games.submit_score(PlayGamesConfig.region(), Save.best)


func _on_cloud(data: Dictionary) -> void:
	if Save.merge(data):
		pending.append(L.t("CLOUD_LOADED"))
	games.save_cloud(Save.export_data())


# ------------------------------------------------------------------ share

func share(score: int, img: Image) -> bool:
	return sharer.share_score(L.t("SHARE_TEXT", score), img)
