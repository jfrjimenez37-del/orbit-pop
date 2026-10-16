class_name Hazard
extends Node2D
## Base for everything that can kill the player. Hazards are fully deterministic
## functions of game time, so the very same `danger()` drives both collisions and
## the fairness checker (Survival). Local origin = planet center.

var t_spawn := 0.0
var t_danger_start := 0.0
var t_danger_end := 0.0
var t_end := 0.0
var scored := false
var min_clear := INF
var t := 0.0  # last game time seen (for drawing)


## Appends Vector2(center_angle, half_width) for every dangerous ring interval at time `time`.
func danger(_time: float, _out: Array) -> void:
	pass


func tick(time: float) -> void:
	t = time
	queue_redraw()


func is_done(time: float) -> bool:
	return time > t_end


## Signed-free clearance between the player and the closest danger edge (rad, <0 = hit).
func clearance(time: float, angle: float) -> float:
	var iv: Array = []
	danger(time, iv)
	var best := INF
	for v in iv:
		best = minf(best, absf(Orbit.ang_diff(angle, v.x)) - v.y)
	return best


func ring_pos(a: float, r := Orbit.R) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


## Where to show feedback for this hazard (ring angle).
func label_angle(_time: float) -> float:
	return 0.0
