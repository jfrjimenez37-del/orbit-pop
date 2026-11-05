class_name Flare
extends Hazard
## World 11 (MOONS): a solar flare. A wedge of the planet's surface glows, then a burst of fire
## shoots out through every orbit inside that wedge and burns for a moment.
## Warning: dotted wedge edges + glowing surface.

const SPEED := 260.0
const BURN := 0.55

var theta := 0.0
var half := 0.3          # half angle of the wedge, seen from the planet center
var t_fire := 0.0
var r_out := 100.0
var _pr := Orbit.PLANET_R


func setup(p_theta: float, p_t_spawn: float, warn: float, p_half: float, p_home := 0) -> Flare:
	set_home(p_home)
	theta = wrapf(p_theta, -PI, PI)
	half = p_half
	t_spawn = p_t_spawn
	t_fire = t_spawn + warn
	_pr = Orbit.planet_r(home_k)
	r_out = Orbit.max_radius(home_k) + 30.0
	var r_lo := INF
	for k in Orbit.count():
		for i in 48:
			var v := Orbit.pos(k, TAU * i / 48.0) - home
			if absf(Orbit.ang_diff(v.angle(), theta)) < half + 0.3:
				r_lo = minf(r_lo, v.length())
	if r_lo == INF:
		r_lo = Orbit.radius(home_k, theta)
	t_danger_start = t_fire + maxf(0.0, r_lo - _pr - Orbit.PLAYER_R - 4.0) / SPEED
	t_danger_end = t_fire + BURN
	t_end = t_danger_end + 0.25
	return self


func reach(time: float) -> float:
	return minf(r_out, _pr + SPEED * maxf(0.0, time - t_fire))


func label_angle(_time: float) -> float:
	return theta


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var re := reach(time)
	var pr2 := Orbit.PLAYER_R + 1.0
	if Orbit.center(k).distance_to(home) < 1.0 and Orbit.is_round(k):
		var R := Orbit.radius(k, theta)
		if re >= R - pr2:
			out.append(Vector2(theta, half + asin(clampf(pr2 / R, 0.0, 1.0))))
		return
	var smp := Orbit.samples(k)
	var hs := TAU / Orbit.SAMPLES * 0.5 + 0.01
	for i in range(0, smp.size(), 3):
		var v := Vector2(smp[i + 1], smp[i + 2]) - home
		var d := v.length()
		if d < _pr or d > re + pr2:
			continue
		if absf(Orbit.ang_diff(v.angle(), theta)) < half + pr2 / maxf(d, 1.0):
			out.append(Vector2(smp[i], hs))


func _draw() -> void:
	var hc := home
	if t < t_fire:
		var k := clampf((t - t_spawn) / maxf(0.01, t_fire - t_spawn), 0.0, 1.0)
		var on := fmod(t * (5.0 + 12.0 * k), 1.0) < 0.6
		for e in [-1.0, 1.0]:
			var a: float = theta + e * half
			var r := _pr + 4.0
			while r < r_out:
				if on:
					draw_rect(Rect2((hc + Vector2(cos(a), sin(a)) * r).floor(), Vector2(1, 1)), Color(1, 0.6, 0.2, 0.5 + 0.5 * k))
				r += 4.0
		draw_arc(hc, _pr + 1.5, theta - half, theta + half, 10, Color(1, 0.85, 0.3, 0.4 + 0.6 * k * (1.0 if on else 0.5)), 2.0 + k)
		return
	if t > t_end:
		return
	var fade := 1.0 if t <= t_danger_end else 1.0 - (t - t_danger_end) / 0.25
	var re := reach(t)
	var flick := 0.85 + 0.15 * sin(t * 50.0)
	for layer in [[1.0, Color(0.15, 0.1, 0.25, 0.6)], [0.85, Color(1, 0.45, 0.15, 0.9)], [0.55, Color(1, 0.85, 0.3, 1.0)], [0.25, Color(1, 1, 0.85, 1.0)]]:
		var hw: float = half * float(layer[0]) * flick
		var c: Color = layer[1]
		c.a *= fade
		var pts := PackedVector2Array([hc + Vector2(cos(theta), sin(theta)) * _pr])
		for i in 9:
			var a := theta - hw + hw * 2.0 * i / 8.0
			pts.append(hc + Vector2(cos(a), sin(a)) * (re * (0.9 + 0.1 * float(layer[0]))))
		draw_colored_polygon(pts, c)
