extends Node
## Tiny sound manager: a pool of players for effects plus one music player.
## The game runs fine if any sound is missing.

const NAMES := ["flip", "score", "close", "pop", "hit", "record", "unlock", "select", "deny", "tick", "go", "warn", "coin"]
const POOL := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _default: AudioStream          # assets/sfx/music.wav: menu, and any group without its own track
var _group := ""
var _fade: Tween

## Music by world group (1.0.18): assets/music/<group>.ogg or .mp3. A group without a file keeps
## the default song, so tracks can be added one by one.
const GROUPS := ["sky", "planets", "space", "moving"]
const MUSIC_DB := -9.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var p := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(p):
			_streams[n] = load(p)
	for i in POOL:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_players.append(pl)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	if ResourceLoader.exists("res://assets/sfx/music.wav"):
		var m: AudioStreamWAV = load("res://assets/sfx/music.wav")
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 2
		_music.stream = m
		_default = m


func play(n: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not Save.sound or not _streams.has(n):
		return
	var pl := _players[_next]
	_next = (_next + 1) % POOL
	pl.stream = _streams[n]
	pl.pitch_scale = pitch
	pl.volume_db = vol_db
	pl.play()


func set_music(on: bool) -> void:
	if _music.stream == null:
		return
	if on and Save.music and Save.sound:
		if not _music.playing:
			_music.play()
	else:
		_music.stop()


## Worlds 1-4 sky, 5-8 planets, 9-13 space, 14-16 moving planets (Stages index).
static func group_for_stage(si: int) -> String:
	if si < 4:
		return "sky"
	if si < 8:
		return "planets"
	if si < 13:
		return "space"
	return "moving"


static func track_path(group: String) -> String:
	for ext in ["ogg", "mp3"]:
		var p := "res://assets/music/%s.%s" % [group, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


## Switch to a group's track (crossfade); "" = the default song. Nothing changes if that group
## has no file or already plays.
func set_group(group: String) -> void:
	if group == _group:
		return
	_group = group
	var stream: AudioStream = _default
	var path := track_path(group) if group != "" else ""
	if path != "":
		stream = load(path)
		if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
			stream.loop = true
	if stream == null or stream == _music.stream:
		return
	if _fade:
		_fade.kill()
	var playing := _music.playing
	if not playing:
		_music.stream = stream
		return
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", -40.0, 0.5)
	_fade.tween_callback(func():
		_music.stream = stream
		if Save.music and Save.sound:
			_music.play())
	_fade.tween_property(_music, "volume_db", MUSIC_DB, 0.6)


func current_group() -> String:
	return _group


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
