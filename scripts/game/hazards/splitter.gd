class_name Splitter
extends Hazard
## World 14 (DANCE): a big meteor that falls toward the planet and splits in two just before the
## orbit; the halves fly apart and cross it on both sides of where it was heading.
## Warning: dotted fall path forking at the split point + a reticle where each half crosses.

const TEX := preload("res://assets/sprites/meteor.png")
const R0 := 150.0
const RADIUS := 3.5

var theta := 0.0
var speed := 100.0
var spread := 0.5
var r_split := 70.0
var t_launch := 0.0
var t_split := 0.0
var _rr := RADIUS + Orbit.PLAYER_R
var _cross: Array = []   # [orbit point of each half (relative to home)]


func setup(p_theta: float, p_t_spawn: float, pre: float, p_speed: float, p_spread: float, p_home := 0) -> Splitter:
	set_home(p_home)
	theta = wrapf(p_theta, -PI, PI)
	speed = p_speed
	spread = p_spread
	t_spawn = p_t_spawn
	t_launch = t_spawn + pre
	r_split = Orbit.max_radius(home_k) + 22.0
	t_split = t_launch + (R0 - r_split) / speed
	var pr := Orbit.planet_r(home_k)
	# the halves stop at the planet surface (or after 120 px)
	t_danger_start = t_launch
	t_danger_end = t_split + 120.0 / speed
	t_end = t_danger_end + 0.2
	_cross.clear()
	for e in [-1.0, 1.0]:
		var hit := Vector2.INF
		var s := 0.0
		while s < 120.0:
			var q := _half_local(e, s)
			if q.length() < pr:
				break
			if absf(q.length() - Orbit.radius(home_k, q.angle())) < 2.0 and Orbit.center(home_k).distance_to(home) < 1.0:
				hit = q
				break
			s += 1.0
		_cross.append(hit)
	return self


func _dir() -> Vector2:
	return Vector2(cos(theta), sin(theta))


## Position of one half (e = -1 / 1) `s` px after the split, relative to the home planet.
func _half_local(e: float, s: float) -> Vector2:
	var v := (-_dir()).rotated(e * spread)
	return _dir() * r_split + v * s


func label_angle(_time: float) -> float:
	return theta


## World positions of the pieces alive at `time` (1 before the split, 2 after).
func pieces(time: float) -> Array:
	var hc := home_now()
	if time < t_split:
		return [hc + _dir() * (R0 - speed * maxf(0.0, time - t_launch))]
	var s := speed * (time - t_split)
	var out: Array = []
	var pr := Orbit.planet_r(home_k)
	for e in [-1.0, 1.0]:
		var q := _half_local(e, s)
		if q.length() >= pr:
			out.append(hc + q)
	return out


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var big := time < t_split
	for p in pieces(time):
		point_danger(p, _rr + (1.5 if big else 0.0), k, out)


func _draw() -> void:
	var hc := home_now()
	var col := Color(0.85, 0.55, 1.0)
	if t < t_split:
		var on := fmod(t * 10.0, 1.0) < 0.6
		var blink := 0.55 + 0.45 * sin(t * 30.0)
		var r := R0 - speed * maxf(0.0, t - t_launch) - 8.0
		while r > r_split:
			draw_rect(Rect2((hc + _dir() * r).floor(), Vector2(1, 1)), Color(0.95, 0.65, 1.0, blink))
			r -= 4.0
		for e in [-1.0, 1.0]:
			var s := 4.0
			while s < 60.0:
				if on or int(s) % 8 < 4:
					draw_rect(Rect2((hc + _half_local(e, s)).floor(), Vector2(1, 1)), Color(0.95, 0.65, 1.0, 1.0))
				s += 4.0
	for c in _cross:
		if c != Vector2.INF and t < t_danger_end - 0.3:
			var p: Vector2 = (hc + c).round()
			var on2 := fmod(t * 9.0, 1.0) < 0.6
			draw_arc(p, 5.0, 0.0, TAU, 12, Color(0.15, 0.1, 0.25, 0.6), 3.0)
			draw_arc(p, 5.0, 0.0, TAU, 12, warn(Color(1, 0.4, 0.9)) if on2 else Color(1, 0.9, 0.5), 1.0)
	if t < t_launch or t > t_end:
		return
	var ps := pieces(t)
	var fr := Rect2((int(t * 14.0) % 2) * 12, 0, 12, 20)
	if t < t_split:
		draw_set_transform(ps[0].round(), theta + PI * 0.5, Vector2(1.25, 1.25))
		draw_texture_rect_region(TEX, Rect2(-6, -14, 12, 20), fr, col)
	else:
		if t < t_split + 0.15:
			var e2 := (t - t_split) / 0.15
			draw_arc(hc + _dir() * r_split, 3.0 + 8.0 * e2, 0.0, TAU, 12, Color(1, 0.85, 1.0, 1.0 - e2), 1.0)
		var i := 0
		for p in ps:
			var v := (-_dir()).rotated((-1.0 if i == 0 else 1.0) * spread)
			draw_set_transform(p.round(), v.angle() - PI * 0.5, Vector2(0.85, 0.85))
			draw_texture_rect_region(TEX, Rect2(-6, -14, 12, 20), fr, col)
			i += 1
	draw_set_transform(Vector2.ZERO)
