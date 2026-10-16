class_name Bubble
extends Node2D
## Collectible bonus bubble sitting on the orbit. Not a hazard.

const TEX := preload("res://assets/sprites/bubble.png")
const RADIUS := 6.0

var theta := 0.0
var t_spawn := 0.0
var t_end := 0.0
var t := 0.0
var half := Orbit.chord_half(RADIUS + Orbit.PLAYER_R)


func setup(p_theta: float, p_t: float, life: float) -> Bubble:
	theta = p_theta
	t_spawn = p_t
	t_end = p_t + life
	return self


func tick(time: float) -> void:
	t = time
	queue_redraw()


func touches(angle: float) -> bool:
	return t >= t_spawn + 0.2 and absf(Orbit.ang_diff(angle, theta)) < half


func _draw() -> void:
	var life := t - t_spawn
	var left := t_end - t
	if left < 1.0 and fmod(t * 8.0, 1.0) < 0.4:
		return
	var s := clampf(life / 0.2, 0.2, 1.0)
	var bob := Vector2(0, roundf(sin(t * 4.0)))
	draw_set_transform((Vector2(cos(theta), sin(theta)) * Orbit.R).round() + bob, 0.0, Vector2(s, s))
	draw_texture(TEX, Vector2(-7, -7))
	draw_set_transform(Vector2.ZERO)
