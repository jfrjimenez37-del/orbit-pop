extends Node
## Google Play Games Services through the "godot-play-game-services" plugin (Iakobs, v3.x).
## Leaderboards, achievements and cloud save (Saved Games). Every call is a safe no-op when
## the plugin is not installed or the player is not signed in.

signal signed_in_changed(signed: bool)
signal cloud_loaded(data: Dictionary)

var available := false
var signed_in := false
var _sign: Node
var _lb: Node
var _ach: Node
var _snap: Node


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
	if _sign == null or _lb == null or _ach == null or _snap == null:
		return
	for n in [_sign, _lb, _ach, _snap]:
		add_child(n)
	available = true
	_sign.connect("user_authenticated", _on_auth)
	_snap.connect("game_loaded", _on_game_loaded)
	_sign.call("is_authenticated")


func sign_in() -> void:
	if available:
		_sign.call("sign_in")


func _on_auth(ok: bool) -> void:
	signed_in = ok
	signed_in_changed.emit(ok)
	if ok:
		_snap.call("load_game", PlayGamesConfig.CLOUD_SLOT, false)


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
