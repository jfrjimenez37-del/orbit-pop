extends Node
## Google Play Games Services through the "godot-play-game-services" plugin (Iakobs, v3.x).
## Leaderboards (with the player's rank and the top scores), player name, achievements and
## cloud save (Saved Games). Every call is a safe no-op when
## the plugin is not installed or the player is not signed in.

signal signed_in_changed(signed: bool)
signal cloud_loaded(data: Dictionary)
signal player_loaded(name: String)
## rank: position on the board (1 = first), -1 if unknown. board: our board key (GLOBAL, SOUTH_AMERICA...)
signal rank_loaded(board: String, rank: int, score: int)
## rows: [{"rank": int, "name": String, "score": int, "me": bool}]
signal top_loaded(board: String, rows: Array)

const ALL_TIME := 2   # PlayGamesLeaderboardVariant.TimeSpan.TIME_SPAN_ALL_TIME
const PUBLIC := 0     # PlayGamesLeaderboardVariant.Collection.COLLECTION_PUBLIC
const TOP_ROWS := 25  # Play Games returns at most 25 scores per request

var available := false
var signed_in := false
var _sign: Node
var _lb: Node
var _ach: Node
var _snap: Node
var _players: Node
var player_name := ""
var player_id := ""
var ranks := {}       # board -> last known rank


static func _client(cls: String) -> Node:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return load(c["path"]).new()
	return null


func start() -> void:
	var pgs := get_node_or_null("/root/GodotPlayGameServices")
	if pgs == null or not OS.has_feature("android"):
		return
	if int(pgs.call("initialize")) != 0:
		return
	_sign = _client("PlayGamesSignInClient")
	_lb = _client("PlayGamesLeaderboardsClient")
	_ach = _client("PlayGamesAchievementsClient")
	_snap = _client("PlayGamesSnapshotsClient")
	_players = _client("PlayGamesPlayersClient")
	if _sign == null or _lb == null or _ach == null or _snap == null or _players == null:
		return
	for n in [_sign, _lb, _ach, _snap, _players]:
		add_child(n)
	available = true
	_sign.connect("user_authenticated", _on_auth)
	_snap.connect("game_loaded", _on_game_loaded)
	_players.connect("current_player_loaded", _on_player)
	_lb.connect("score_submitted", _on_submitted)
	_lb.connect("score_loaded", _on_score_loaded)
	_lb.connect("top_scores_loaded", _on_top_loaded)
	_sign.call("is_authenticated")


func sign_in() -> void:
	if available:
		_sign.call("sign_in")


func _on_auth(ok: bool) -> void:
	signed_in = ok
	signed_in_changed.emit(ok)
	if ok:
		_snap.call("load_game", PlayGamesConfig.CLOUD_SLOT, false)
		_players.call("load_current_player", false)


func _on_player(p) -> void:
	if p == null:
		return
	player_name = str(p.get("display_name"))
	player_id = str(p.get("player_id"))
	player_loaded.emit(player_name)


func _board_key(leaderboard_id: String) -> String:
	for k in PlayGamesConfig.LEADERBOARDS:
		if PlayGamesConfig.LEADERBOARDS[k] == leaderboard_id:
			return k
	return ""


## After a score is stored, ask for the player's position on that board.
func _on_submitted(ok: bool, leaderboard_id: String) -> void:
	if ok:
		_lb.call("load_player_score", leaderboard_id, ALL_TIME, PUBLIC)


func _on_score_loaded(leaderboard_id: String, score) -> void:
	var board := _board_key(leaderboard_id)
	if board == "" or score == null:
		return
	var rank := int(score.get("rank"))
	ranks[board] = rank
	rank_loaded.emit(board, rank, int(score.get("raw_score")))


func load_rank(board: String) -> void:
	var id: String = PlayGamesConfig.LEADERBOARDS.get(board, "")
	if signed_in and id != "":
		_lb.call("load_player_score", id, ALL_TIME, PUBLIC)


func load_top(board: String) -> bool:
	var id: String = PlayGamesConfig.LEADERBOARDS.get(board, "")
	if not signed_in or id == "":
		return false
	_lb.call("load_top_scores", id, ALL_TIME, PUBLIC, TOP_ROWS, true)
	return true


func _on_top_loaded(leaderboard_id: String, scores) -> void:
	var board := _board_key(leaderboard_id)
	if board == "" or scores == null:
		return
	var rows: Array = []
	for sc in scores.get("scores"):
		var holder = sc.get("score_holder")
		var pid := str(holder.get("player_id")) if holder != null else ""
		rows.append({"rank": int(sc.get("rank")), "name": str(sc.get("score_holder_display_name")),
			"score": int(sc.get("raw_score")), "me": pid != "" and pid == player_id})
	top_loaded.emit(board, rows)


func _on_game_loaded(snapshot) -> void:
	if snapshot == null:
		return
	var bytes: PackedByteArray = snapshot.get("content")
	var data = JSON.parse_string(bytes.get_string_from_utf8())
	if data is Dictionary:
		cloud_loaded.emit(data)


func save_cloud(data: Dictionary) -> void:
	if not signed_in:
		return
	var bytes := JSON.stringify(data).to_utf8_buffer()
	_snap.call("save_game", PlayGamesConfig.CLOUD_SLOT, "ORBIT POP", bytes, 0, int(data.get("best", 0)))


func submit_score(board: String, score: int) -> void:
	var id: String = PlayGamesConfig.LEADERBOARDS.get(board, "")
	if signed_in and id != "":
		_lb.call("submit_score", id, score)


func show_board(board: String) -> bool:
	var id: String = PlayGamesConfig.LEADERBOARDS.get(board, "")
	if not signed_in or id == "":
		return false
	_lb.call("show_leaderboard", id)
	return true


func unlock(ach: String) -> void:
	var id: String = PlayGamesConfig.ACHIEVEMENTS.get(ach, "")
	if signed_in and id != "":
		_ach.call("unlock_achievement", id)


func show_achievements() -> bool:
	if not signed_in:
		return false
	_ach.call("show_achievements")
	return true
