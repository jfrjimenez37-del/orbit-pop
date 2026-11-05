class_name Satellite
extends Hazard
## World 10 (WARPED): a satellite on a long, tilted elliptic orbit around the planet. It
## starts at its far point and crosses the player's orbit on the way in and on the way out.
## Warning: its whole dotted path, then it flies for a while.

const RADIUS := 3.5

var tilt := 0.0
var A := 60.0          # far point (beyond the orbit)
var B := 20.0          # near point (inside the orbit)
var th0 := 0.0
var spin := 1.6        # rad/s along its ellipse
var _rr := RADIUS + Orbit.PLAYER_R


func setup(p_tilt: float, p_t_spawn: float, warn: float, active: float, p_spin: float, p_home := 0) -> Satellite:
	set_home(p_home)
	tilt = p_tilt
	var r := Orbit.radius(home_k, tilt)
	A = r + 26.0
	B = maxf(Orbit.planet_r(home_k) + 6.0, r - 14.0)
	spin = p_spin
	th0 = 0.0
	t_spawn = p_t_spawn
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.35
	return self


func _local(th: float) -> Vector2:
	return Vector2(A * cos(th), B * sin(th)).rotated(tilt)


func pos_at(time: float) -> Vector2:
	return home_now() + _local(th0 + spin * clampf(time - t_danger_start, 0.0, t_danger_end - t_danger_start + 0.35))


func label_angle(time: float) -> float:
	return Orbit.angle_of(home_k, pos_at(time))


func danger(time: float, out: Array, k := 0) -> void:
	if time >= t_danger_start and time <= t_danger_end:
		point_danger(pos_at(time), _rr, k, out)


func _draw() -> void:
	var hc := home_now()
	if t < t_danger_end:
		var k := clampf((t - t_spawn) / maxf(0.01, t_danger_start - t_spawn), 0.0, 1.0)
		var on := fmod(t * (4.0 + 8.0 * k), 1.0) < 0.6
		var n := 40
		for i in n:
			if on or i % 2 == 0:
				draw_rect(Rect2((hc + _local(TAU * i / n)).floor(), Vector2(1, 1)), Color(0.6, 0.95, 1.0, 0.55 if t >= t_danger_start else 1.0))
	if t > t_end:
		return
	var fade := 1.0 if t <= t_danger_end else 1.0 - (t - t_danger_end) / 0.35
	var al := fade if t >= t_danger_start else 0.35 + 0.3 * sin(t * 20.0)
	var p := pos_at(t).round()
	var heading := (pos_at(t + 0.02) - pos_at(t)).angle() if t >= t_danger_start else tilt + PI * 0.5
	if t >= t_danger_start and t <= t_danger_end:
		draw_arc(p, 8.0, 0.0, TAU, 14, Color(1, 0.4, 0.45, 0.35 + 0.25 * sin(t * 16.0)), 1.0)
	draw_set_transform(p, heading, Vector2.ONE)
	var dk := Color(0.15, 0.1, 0.25, 0.9 * al)
	draw_rect(Rect2(-10, -3, 6, 6), dk)
	draw_rect(Rect2(4, -3, 6, 6), dk)
	draw_rect(Rect2(-9, -2, 4, 4), Color(0.3, 0.55, 1.0, al))
	draw_rect(Rect2(5, -2, 4, 4), Color(0.3, 0.55, 1.0, al))
	draw_rect(Rect2(-9, -2, 4, 1), Color(0.6, 0.85, 1.0, al))
	draw_rect(Rect2(5, -2, 4, 1), Color(0.6, 0.85, 1.0, al))
	draw_rect(Rect2(-4, -4, 8, 8), dk)
	draw_rect(Rect2(-3, -3, 6, 6), Color(0.9, 0.9, 0.96, al))
	draw_rect(Rect2(-3, 1, 6, 2), Color(0.65, 0.65, 0.75, al))
	if fmod(t * 4.0, 1.0) < 0.5:
		draw_rect(Rect2(-1, -1, 2, 2), Color(1, 0.3, 0.35, al))
	draw_set_transform(Vector2.ZERO)
