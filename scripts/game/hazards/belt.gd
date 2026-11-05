class_name Belt
extends Hazard
## World 13 (CHAIN): an asteroid belt, a row of small rocks drifting along the orbit. Too
## tight to slip through: go the other way or jump to another planet.
## Warning: the rocks fade in, blinking, before they become solid.

const ROCK_R := 3.0

var orbit := 0
var a_mid := 0.0
var spacing := 0.36
var n := 5
var drift := 0.5
var offs: Array = []      # small radial offset of each rock (looks less like a line)
var _rr := ROCK_R + Orbit.PLAYER_R


func setup(p_orbit: int, p_mid: float, p_n: int, p_spacing: float, p_drift: float, p_t_spawn: float, warn: float, active: float, seed_value := 0) -> Belt:
	orbit = mini(p_orbit, Orbit.count() - 1)
	set_home(orbit)
	a_mid = p_mid
	n = p_n
	spacing = p_spacing
	drift = p_drift
	t_spawn = p_t_spawn
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.3
	offs.clear()
	for i in n:
		offs.append(float((seed_value * 7 + i * 5) % 5 - 2) * 0.8)
	return self


func rock_angle(i: int, time: float) -> float:
	return a_mid + (i - (n - 1) * 0.5) * spacing + drift * clampf(time - t_danger_start, 0.0, t_danger_end - t_danger_start)


func rock_pos(i: int, time: float) -> Vector2:
	var a := rock_angle(i, time)
	var p := Orbit.pos(orbit, a)
	return p + (p - Orbit.center(orbit)).normalized() * float(offs[i])


func label_angle(time: float) -> float:
	return rock_angle(n / 2, time)


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	for i in n:
		point_danger(rock_pos(i, time), _rr + absf(float(offs[i])), k, out)


func _draw() -> void:
	if t > t_end:
		return
	var warm := t < t_danger_start
	var k := clampf((t - t_spawn) / maxf(0.01, t_danger_start - t_spawn), 0.0, 1.0)
	var on := fmod(t * (5.0 + 10.0 * k), 1.0) < 0.6
	var fade := 1.0 if t <= t_danger_end else 1.0 - (t - t_danger_end) / 0.3
	for i in n:
		var p := rock_pos(i, t).round()
		var al := (0.3 + 0.5 * k if on else 0.2) if warm else fade
		var s := 3.0 + float((i * 3) % 2)
		draw_circle(p, s + 1.0, Color(0.15, 0.1, 0.25, 0.9 * al))
		draw_circle(p, s, Color(0.78, 0.52, 0.36, al))
		draw_circle(p + Vector2(-1, -1), s * 0.5, Color(0.95, 0.75, 0.55, al))
		draw_rect(Rect2(p + Vector2(1, 0), Vector2(1, 1)), Color(0.45, 0.28, 0.22, al))
		if warm:
			draw_arc(p, 6.0 + 4.0 * (1.0 - k), 0.0, TAU, 10, Color(1, 0.45, 0.35, 0.6 * al), 1.0)
