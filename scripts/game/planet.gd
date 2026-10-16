class_name Planet
extends Node2D
## The cute central planet (with a reactive face) and the dotted orbit track.

const BODY := preload("res://assets/sprites/planet.png")
const FACE := preload("res://assets/sprites/planet_face.png")

enum Mood { SMILE, OH, WORRY }

var look := Vector2.ZERO   # direction toward the player
var mood := Mood.SMILE
var _t := 0.0
var _blink := 2.0
var _oh_time := 0.0
var _squash := 0.0
var ring_alpha := 0.85


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


func _draw() -> void:
	# orbit dots
	var n := 44
	for i in n:
		var a := TAU * i / n + _t * 0.15
		var p := (Vector2(cos(a), sin(a)) * Orbit.R).floor()
		draw_rect(Rect2(p, Vector2(2, 2) if i % 2 == 0 else Vector2(1, 1)), Color(1, 1, 1, ring_alpha))
	var bob := roundf(sin(_t * 1.6) * 1.0)
	var sq := 1.0 + 0.06 * _squash * sin(_t * 40.0)
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(sq, 2.0 - sq))
	draw_texture(BODY, Vector2(-32, -32))
	# face
	var e := (look * 1.4).round()
	var blink := _blink < 0.0 or mood == Mood.WORRY and fmod(_t, 0.5) < 0.1
	var eye_src := Rect2(8 if blink else 0, 0, 8, 8)
	draw_texture_rect_region(FACE, Rect2(Vector2(-14, -9) + e, Vector2(8, 8)), eye_src)
	draw_texture_rect_region(FACE, Rect2(Vector2(6, -9) + e, Vector2(8, 8)), eye_src)
	var m := 2
	if mood == Mood.WORRY:
		m = 4
	elif mood == Mood.OH or _oh_time > 0.0:
		m = 3
	draw_texture_rect_region(FACE, Rect2(Vector2(-4, -1) + e * 0.5, Vector2(8, 8)), Rect2(m * 8, 0, 8, 8))
	draw_set_transform(Vector2.ZERO)
