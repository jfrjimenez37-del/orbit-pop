class_name Boomerang
extends Hazard
## World 9 (GIANTS): a spinning boomerang thrown across an orbit. It slows down, stops and
## flies back along the same line, so the same spot is dangerous twice.
## Warning: dotted line out to the turning point + blinking marker where it is thrown from.

const RADIUS := 4.0
const COL := Color(1.0, 0.62, 0.2)

var p0 := Vector2.ZERO      # thrown from here (relative to the home planet)
var dvec := Vector2.RIGHT
var dist := 110.0           # how far it goes before turning back
var flight := 2.0
var t_launch := 0.0
var _rr := RADIUS + Orbit.PLAYER_R


## Passes `target` (world point) at 0.25 and 0.75 of the flight, heading `heading`.
func setup(target: Vector2, heading: float, p_t_spawn: float, pre: float, p_flight: float, p_home := 0) -> Boomerang:
	set_home(p_home)
	dvec = Vector2(cos(heading), sin(heading))
	p0 = target - home - dvec * dist * 0.7
	flight = p_flight
	t_spawn = p_t_spawn
	t_launch = t_spawn + pre
	t_danger_start = t_launch
	t_danger_end = t_launch + flight
	t_end = t_danger_end + 0.3
	return self


## Time after launch when it passes its target the first time (sin(pi u) = 0.7).
static func first_pass(p_flight: float) -> float:
	return p_flight * asin(0.7) / PI


func pos_at(time: float) -> Vector2:
	var u := clampf((time - t_launch) / flight, 0.0, 1.0)
	return home_now() + p0 + dvec * dist * sin(PI * u)


func label_angle(time: float) -> float:
	return Orbit.angle_of(home_k, pos_at(time))


func danger(time: float, out: Array, k := 0) -> void:
	if time >= t_danger_start and time <= t_danger_end:
		point_danger(pos_at(time), _rr, k, out)


func _draw() -> void:
	var hc := home_now()
	if t < t_launch:
		var k := clampf((t - t_spawn) / maxf(0.01, t_launch - t_spawn), 0.0, 1.0)
		var on := fmod(t * (6.0 + 10.0 * k), 1.0) < 0.6
		var s := 6.0
		while s < dist:
			if on or int(s) % 8 < 4:
				draw_rect(Rect2((hc + p0 + dvec * s).floor(), Vector2(1, 1)), Color(1, 0.8, 0.35, 1.0))
			s += 4.0
		# the turning point
		var tp := (hc + p0 + dvec * dist).round()
		draw_arc(tp, 4.0, 0.0, TAU, 10, Color(0.15, 0.1, 0.25, 0.7), 3.0)
		draw_arc(tp, 4.0, 0.0, TAU, 10, Color(1, 0.6, 0.2) if on else Color(1, 0.95, 0.5), 1.0)
	if t > t_end:
		return
	var p := pos_at(t)
	var fade := 1.0 if t <= t_danger_end else 1.0 - (t - t_danger_end) / 0.3
	if t >= t_launch and t <= t_danger_end:
		# short trail behind it
		var prev := pos_at(t - 0.05)
		for i in 3:
			var q := p.lerp(prev, 0.5 + i * 0.5)
			draw_rect(Rect2(q.floor(), Vector2(1, 1)), Color(1, 0.8, 0.4, 0.6 - i * 0.18))
	var rot := t * 16.0 if t >= t_launch else 0.0
	draw_set_transform(p.round(), rot, Vector2.ONE)
	var dark := Color(0.15, 0.1, 0.25, 0.85 * fade)
	var arm := PackedVector2Array([Vector2(-7, 4), Vector2(0, -4), Vector2(7, 4)])
	draw_polyline(arm, dark, 6.0)
	draw_polyline(arm, Color(COL.r, COL.g, COL.b, fade), 4.0)
	draw_polyline(PackedVector2Array([Vector2(-6, 3), Vector2(0, -3), Vector2(6, 3)]), Color(1, 0.92, 0.6, fade), 1.0)
	draw_set_transform(Vector2.ZERO)
