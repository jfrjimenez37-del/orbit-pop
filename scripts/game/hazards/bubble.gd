class_name Bubble
extends Node2D
## Collectible bonus bubble sitting on an orbit. Not a hazard.

const TEX := preload("res://assets/sprites/bubble.png")
const RADIUS := 6.0

var theta := 0.0
var orbit := 0
var t_spawn := 0.0
var t_end := 0.0
var t := 0.0


func setup(p_theta: float, p_t: float, life: float, p_orbit := 0) -> Bubble:
	theta = p_theta
	t_spawn = p_t
	t_end = p_t + life
	orbit = mini(p_orbit, Orbit.count() - 1)
	return self


func tick(time: float) -> void:
	t = time
	queue_redraw()


func touches(angle: float, k := 0) -> bool:
	if t < t_spawn + 0.2 or Orbit.pos(k, angle).distance_to(Orbit.pos(orbit, theta)) > RADIUS + Orbit.PLAYER_R:
		return false
	return true


func _draw() -> void:
	var life := t - t_spawn
	var left := t_end - t
	if left < 1.0 and fmod(t * 8.0, 1.0) < 0.4:
		return
	var s := clampf(life / 0.2, 0.2, 1.0)
	var bob := Vector2(0, roundf(sin(t * 4.0)))
	draw_set_transform(Orbit.pos(orbit, theta).round() + bob, 0.0, Vector2(s, s))
	draw_texture(TEX, Vector2(-7, -7))
	draw_set_transform(Vector2.ZERO)
