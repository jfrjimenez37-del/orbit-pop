class_name Planet
extends Node2D
## The cute planet(s) with reactive faces and the dotted orbit track(s).
## Two-planet worlds draw one planet per orbit center.

var BODY: Texture2D = preload("res://assets/sprites/planet.png")
var _names: Array = ["planet"]   # sprite base name per planet (size suffix added per radius)
var _cache := {}
const FACE := preload("res://assets/sprites/planet_face.png")

enum Mood { SMILE, OH, WORRY }

var look := Vector2.ZERO   # kept for compatibility (direction toward the player)
var mood := Mood.SMILE
var ring_alpha := 0.85
var player_angle := 0.0
var player_orbit := 0
var player_pos := Vector2.ZERO
var _t := 0.0
var _blink := 2.0
var _oh_time := 0.0
var _squash := 0.0


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(1.8, 4.0)
	_oh_time = maxf(0.0, _oh_time - delta)
	_squash = maxf(0.0, _squash - delta * 4.0)
	queue_redraw()


func bump() -> void:
	_oh_time = 0.35
	_squash = 1.0


func set_world(names: Array) -> void:
	_names = names
	BODY = _tex(names[0], Orbit.PLANET_R)


func _tex(base: String, r: float) -> Texture2D:
	var suffix := "" if r >= 27.0 else ("_m" if r >= 19.0 else "_s")
	var key := base + suffix
	if not _cache.has(key):
		_cache[key] = load("res://assets/sprites/%s.png" % key)
	return _cache[key]


func _draw() -> void:
	var n := 44
	for k in Orbit.count():
		var tint := Color(1, 1, 1, ring_alpha) if k == 0 else Color(1, 0.95, 0.7, ring_alpha)
		for i in n:
			var a := TAU * i / n + _t * 0.15 * (1 if k == 0 else -1)
			var p := Orbit.pos(k, a).floor()
			var sz := Vector2(2, 2) if i % 2 == 0 else Vector2(1, 1)
			draw_rect(Rect2(p + Vector2(0, 1), sz), Color(0.15, 0.1, 0.3, 0.3))  # contrast on light skies
			draw_rect(Rect2(p, sz), tint)
	# crossing points: glowing diamonds, brighter when the player can switch there
	if Orbit.count() >= 2 and not Orbit.morphing():
		for c in Orbit.cross_list():
			var p2 := Orbit.pos(c["k"][0], c["a"][0]).round()
			var side: int = c["k"].find(player_orbit)
			var hot := side >= 0 and absf(Orbit.ang_diff(player_angle, c["a"][side])) <= Orbit.CROSS_WINDOW
			var col := Color8(255, 236, 90) if hot else Color(1, 1, 1, 0.7)
			var s := 3 + (1 if hot and fmod(_t, 0.2) < 0.1 else 0)
			for dy in range(-s, s + 1):
				var w := s - absi(dy)
				draw_rect(Rect2(p2 + Vector2(-w, dy), Vector2(w * 2 + 1, 1)), col)
	var planets := Orbit.planets()
	for i in planets.size():
		var p: Dictionary = planets[i]
		_draw_planet(p["c"], _tex(_names[mini(i, _names.size() - 1)], p["r"]), p["r"])


func _draw_planet(c: Vector2, body: Texture2D, r: float) -> void:
	var bob := roundf(sin(_t * 1.6 + c.y * 0.05) * 1.0)
	var sq := 1.0 + 0.06 * _squash * sin(_t * 40.0)
	var f := r / Orbit.PLANET_R
	draw_set_transform(c.round() + Vector2(0, bob), 0.0, Vector2(sq, 2.0 - sq))
	draw_texture(body, -(body.get_size() * 0.5).floor())
	var to_player := player_pos - c
	var e := (to_player.normalized() * 1.4).round() if to_player.length() > 1.0 else Vector2.ZERO
	var blink := _blink < 0.0 or mood == Mood.WORRY and fmod(_t, 0.5) < 0.1
	var eye_src := Rect2(8 if blink else 0, 0, 8, 8)
	draw_texture_rect_region(FACE, Rect2((Vector2(-14, -9) * f).round() + e, Vector2(8, 8)), eye_src)
	draw_texture_rect_region(FACE, Rect2((Vector2(6, -9) * f).round() + Vector2(0 if f > 0.9 else 1, 0) + e, Vector2(8, 8)), eye_src)
	var m := 2
	if mood == Mood.WORRY:
		m = 4
	elif mood == Mood.OH or _oh_time > 0.0:
		m = 3
	draw_texture_rect_region(FACE, Rect2((Vector2(-4, -1) * f).round() + e * 0.5, Vector2(8, 8)), Rect2(m * 8, 0, 8, 8))
	draw_set_transform(Vector2.ZERO)
