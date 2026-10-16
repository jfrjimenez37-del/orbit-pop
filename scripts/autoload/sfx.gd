extends Node
## Tiny sound manager: a pool of players for effects plus one music player.
## The game runs fine if any sound is missing.

const NAMES := ["flip", "score", "close", "pop", "hit", "record", "unlock", "select", "deny", "tick", "go", "warn"]
const POOL := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


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
	_music.volume_db = -9.0
	add_child(_music)
	if ResourceLoader.exists("res://assets/sfx/music.wav"):
		var m: AudioStreamWAV = load("res://assets/sfx/music.wav")
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		m.loop_end = m.data.size() / 2
		_music.stream = m


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


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
