class_name Spiky
extends Hazard
## Spiky star that materializes on an orbit, stays (optionally drifting) and pops away.
## style "saw": a spinning saw blade that races along the orbit over a marked arc.

const TEX := preload("res://assets/sprites/spiky.png")
const SAW := preload("res://assets/sprites/saw.png")
const RADIUS := 5.0

var theta0 := 0.0
var drift := 0.0
var orbit := 0
var style := "star"
var _rr := RADIUS + Orbit.PLAYER_R


func setup(p_theta: float, p_t_spawn: float, warn: float, active: float, p_drift := 0.0, p_orbit := 0, p_style := "star") -> Spiky:
	theta0 = p_theta
	t_spawn = p_t_spawn
	drift = p_drift
	orbit = mini(p_orbit, Orbit.count() - 1)
	style = p_style
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.25
	return self


func theta_at(time: float) -> float:
	return theta0 + drift * clampf(time - t_danger_start, 0.0, t_danger_end - t_danger_start)


func label_angle(time: float) -> float:
	return theta_at(time)


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var a := theta_at(time)
	var rk := Orbit.radius(k, a)
	if absf(rk - Orbit.radius(orbit, a)) >= _rr:
		return
	out.append(Vector2(wrapf(a, -PI, PI), Orbit.chord_half(_rr, rk)))


func _draw() -> void:
	var a := theta_at(t)
	var p := ring_pos(a, orbit).round()
	var tex: Texture2D = SAW if style == "saw" else TEX
	var rot := t * 14.0 if style == "saw" else 0.0
	if t < t_danger_start:
		var k := clampf((t - t_spawn) / (t_danger_start - t_spawn), 0.0, 1.0)
		var on := fmod(t * (5.0 + 10.0 * k), 1.0) < 0.6
		if style == "saw":
			# dotted arc showing the path the saw will race along
			var span := drift * (t_danger_end - t_danger_start)
			for i in 24:
				var aa := theta0 + span * i / 23.0
				if on or i % 2 == 0:
					draw_rect(Rect2(ring_pos(aa, orbit).floor(), Vector2(1, 1)), Color(1, 0.35, 0.3, 0.9))
		var al := 0.35 + 0.4 * k if on else 0.2
		var s := 0.5 + 0.5 * k
		draw_arc(p, 9.0 + 6.0 * (1.0 - k), 0.0, TAU, 14, Color(1, 0.4, 0.85, 0.8), 1.0)
		draw_set_transform(p, rot, Vector2(s, s))
		draw_texture_rect_region(tex, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17), Color(1, 1, 1, al))
	elif t <= t_danger_end:
		var fr := int(t * 8.0) % 2
		var pulse := 1.0 + 0.08 * sin(t * 20.0)
		draw_set_transform(p, rot, Vector2(pulse, pulse))
		draw_texture_rect_region(tex, Rect2(-8, -8, 17, 17), Rect2(fr * 17, 0, 17, 17))
	else:
		var e := (t - t_danger_end) / 0.25
		draw_set_transform(p, e * 2.0, Vector2.ONE * (1.0 + e))
		draw_texture_rect_region(tex, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17), Color(1, 1, 1, 1.0 - e))
	draw_set_transform(Vector2.ZERO)
