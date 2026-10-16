class_name Pulse
extends Hazard
## Shockwave ring that bursts out of the planet. Only a gap in the ring is safe:
## the player has to be inside the gap (marked in green) when the wave passes the orbit.

const RADIUS := 3.0

var gap := 0.0          # gap center angle
var gap_half := 0.6
var speed := 70.0
var t_fire := 0.0
var _rr := RADIUS + Orbit.PLAYER_R
var _r_far := 80.0


func setup(p_gap: float, p_t_spawn: float, warn: float, p_gap_half: float, p_speed := 70.0) -> Pulse:
	gap = wrapf(p_gap, -PI, PI)
	gap_half = p_gap_half
	t_spawn = p_t_spawn
	speed = p_speed
	t_fire = t_spawn + warn
	var lo := INF
	_r_far = 0.0
	for k in Orbit.count():
		for i in 32:
			var r := Orbit.radius(k, TAU * i / 32.0)
			lo = minf(lo, r)
			_r_far = maxf(_r_far, r)
	t_danger_start = t_fire + (lo - Orbit.PLANET_R - _rr) / speed
	t_danger_end = t_fire + (_r_far - Orbit.PLANET_R + _rr) / speed
	t_end = t_fire + (_r_far + 40.0 - Orbit.PLANET_R) / speed
	return self


func wave_r(time: float) -> float:
	return Orbit.PLANET_R + speed * (time - t_fire)


func label_angle(_time: float) -> float:
	return gap + PI


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var rw := wave_r(time)
	var n := 48
	var step := TAU / n
	for i in n:
		var a := gap + PI + step * (i - n / 2)
		if absf(Orbit.ang_diff(a, gap)) < gap_half + step * 0.5:
			continue
		if absf(rw - Orbit.radius(k, a)) < _rr:
			out.append(Vector2(wrapf(a, -PI, PI), step * 0.5 + 0.01))


func _draw() -> void:
	# safe gap marker on the orbit
	if t < t_danger_end:
		var on := fmod(t * 6.0, 1.0) < 0.6
		for k in Orbit.count():
			for i in 9:
				var a := gap - gap_half + gap_half * 2.0 * i / 8.0
				draw_rect(Rect2(ring_pos(a, k).floor() - Vector2(1, 1), Vector2(2, 2)), Color(0.4, 1.0, 0.55, 0.95 if on else 0.5))
	if t < t_fire:
		var k2 := clampf((t - t_spawn) / (t_fire - t_spawn), 0.0, 1.0)
		draw_arc(Vector2.ZERO, Orbit.PLANET_R + 3.0 + 2.0 * sin(t * 30.0), gap + gap_half, gap + TAU - gap_half, 40, Color(1, 0.4, 0.5, 0.4 + 0.5 * k2), 2.0)
		return
	var rw := wave_r(t)
	if rw > _r_far + 40.0:
		return
	draw_arc(Vector2.ZERO, rw, gap + gap_half, gap + TAU - gap_half, 64, Color(0.15, 0.1, 0.25, 0.8), 4.0)
	draw_arc(Vector2.ZERO, rw, gap + gap_half, gap + TAU - gap_half, 64, Color(1, 0.45, 0.6), 2.0)
	draw_arc(Vector2.ZERO, rw, gap + gap_half, gap + TAU - gap_half, 64, Color(1, 0.9, 0.95), 1.0)
