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
var home_k := 0              # orbit whose planet this hazard belongs to
var home := Vector2.ZERO     # that planet's center (world space)


func set_home(k: int) -> void:
	home_k = mini(k, Orbit.count() - 1)
	home = Orbit.center(home_k)


## Danger interval on orbit k caused by a round object of radius `rr` at world point p.
static func point_danger(p: Vector2, rr: float, k: int, out: Array) -> void:
	var v := p - Orbit.center(k)
	var d := v.length()
	if d < 1.0:
		return
	var phi := v.angle()
	var R := Orbit.radius(k, phi)
	if absf(d - R) >= rr:
		return
	var c := (R * R + d * d - rr * rr) / (2.0 * R * d)
	if c >= 1.0:
		return
	out.append(Vector2(phi, acos(clampf(c, -1.0, 1.0))))


## Appends Vector2(center_angle, half_width) for every dangerous interval of orbit `k` at `time`.
func danger(_time: float, _out: Array, _k := 0) -> void:
	pass


func tick(time: float) -> void:
	t = time
	queue_redraw()


func is_done(time: float) -> bool:
	return time > t_end


## Clearance between the player and the closest danger edge (rad, <0 = hit, INF = harmless).
func clearance(time: float, angle: float, k := 0) -> float:
	var iv: Array = []
	danger(time, iv, k)
	var best := INF
	for v in iv:
		best = minf(best, absf(Orbit.ang_diff(angle, v.x)) - v.y)
	return best


func ring_pos(a: float, k := 0) -> Vector2:
	return Orbit.pos(k, a)


## Where to show feedback for this hazard (ring angle).
func label_angle(_time: float) -> float:
	return 0.0
