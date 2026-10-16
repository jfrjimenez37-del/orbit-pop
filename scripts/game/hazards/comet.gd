class_name Comet
extends Hazard
## Fast icy comet that crosses the whole playfield in a straight line (not toward a planet).
## Warning: dotted path across the screen + blinking entry marker.

const TEX := preload("res://assets/sprites/meteor.png")
const RADIUS := 4.0
const LEN := 230.0

var p0 := Vector2.ZERO
var vel := Vector2.ZERO
var t_launch := 0.0
var _rr := RADIUS + Orbit.PLAYER_R


## Crosses `target` (world point) `pre + LEN/2/speed` seconds after spawning, heading `heading`.
func setup(target: Vector2, heading: float, p_t_spawn: float, pre: float, speed: float) -> Comet:
	var d := Vector2(cos(heading), sin(heading))
	p0 = target - d * LEN * 0.5
	vel = d * speed
	t_spawn = p_t_spawn
	t_launch = t_spawn + pre
	# danger window: when the comet is close to any orbit (sampled along the path)
	var s_lo := INF
	var s_hi := -INF
	var s := 0.0
	while s <= LEN:
		var p := p0 + d * s
		for k in Orbit.count():
			var v := p - Orbit.center(k)
			if absf(v.length() - Orbit.radius(k, v.angle())) < _rr + 3.0:
				s_lo = minf(s_lo, s)
				s_hi = maxf(s_hi, s)
		s += 2.0
	if s_lo == INF:
		s_lo = LEN * 0.5; s_hi = s_lo
	t_danger_start = t_launch + maxf(0.0, s_lo - _rr) / speed
	t_danger_end = t_launch + (s_hi + _rr) / speed
	t_end = t_launch + LEN / speed + 0.1
	return self


func pos_at(time: float) -> Vector2:
	return p0 + vel * maxf(0.0, time - t_launch)


func label_angle(time: float) -> float:
	return Orbit.angle_of(0, pos_at(time))


func danger(time: float, out: Array, k := 0) -> void:
	if time >= t_danger_start and time <= t_danger_end:
		point_danger(pos_at(time), _rr, k, out)


func _draw() -> void:
	var d := vel.normalized()
	if t < t_danger_end:
		var on := fmod(t * 10.0, 1.0) < 0.6
		var s := maxf(0.0, (pos_at(t) - p0).dot(d)) + 8.0
		while s < LEN:
			if on or int(s) % 8 < 4:
				draw_rect(Rect2((p0 + d * s).floor(), Vector2(1, 1)), Color(0.6, 0.95, 1.0, 0.75))
			s += 6.0
	if t >= t_launch and t < t_end:
		var p := pos_at(t)
		for i in 6:
			var q := p - d * (i * 3.0 + 3.0)
			draw_rect(Rect2(q.floor() - Vector2(1, 1), Vector2(2, 2)), Color(0.7, 0.95, 1.0, 0.8 - i * 0.12))
		draw_set_transform(p.round(), d.angle() - PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(TEX, Rect2(-6, -14, 12, 20), Rect2((int(t * 14.0) % 2) * 12, 0, 12, 20), Color(0.65, 0.95, 1.2))
		draw_set_transform(Vector2.ZERO)
