class_name Spiky
extends Hazard
## Spiky star that materializes on the orbit, stays (optionally drifting) and pops away.

const TEX := preload("res://assets/sprites/spiky.png")
const RADIUS := 5.0

var theta0 := 0.0
var drift := 0.0
var _half := Orbit.chord_half(RADIUS + Orbit.PLAYER_R)


func setup(p_theta: float, p_t_spawn: float, warn: float, active: float, p_drift := 0.0) -> Spiky:
	theta0 = p_theta
	t_spawn = p_t_spawn
	drift = p_drift
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.25
	return self


func theta_at(time: float) -> float:
	return theta0 + drift * maxf(0.0, time - t_danger_start)


func label_angle(time: float) -> float:
	return theta_at(time)


func danger(time: float, out: Array) -> void:
	if time >= t_danger_start and time <= t_danger_end:
		out.append(Vector2(wrapf(theta_at(time), -PI, PI), _half))


func _draw() -> void:
	var p := ring_pos(theta_at(t)).round()
	if t < t_danger_start:
		var k := clampf((t - t_spawn) / (t_danger_start - t_spawn), 0.0, 1.0)
		var on := fmod(t * (5.0 + 10.0 * k), 1.0) < 0.6
		var a := 0.35 + 0.4 * k if on else 0.2
		var s := 0.5 + 0.5 * k
		draw_arc(p, 9.0 + 6.0 * (1.0 - k), 0.0, TAU, 14, Color(1, 0.4, 0.85, 0.8), 1.0)
		draw_set_transform(p, 0.0, Vector2(s, s))
		draw_texture_rect_region(TEX, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17), Color(1, 1, 1, a))
	elif t <= t_danger_end:
		var fr := int(t * 8.0) % 2
		var pulse := 1.0 + 0.08 * sin(t * 20.0)
		draw_set_transform(p, 0.0, Vector2(pulse, pulse))
		draw_texture_rect_region(TEX, Rect2(-8, -8, 17, 17), Rect2(fr * 17, 0, 17, 17))
	else:
		var e := (t - t_danger_end) / 0.25
		draw_set_transform(p, e * 2.0, Vector2.ONE * (1.0 + e))
		draw_texture_rect_region(TEX, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17), Color(1, 1, 1, 1.0 - e))
	draw_set_transform(Vector2.ZERO)
