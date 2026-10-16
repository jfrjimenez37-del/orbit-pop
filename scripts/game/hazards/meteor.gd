class_name Meteor
extends Hazard
## Falls straight toward the planet along angle `theta`, crossing every orbit once.
## Warning: target reticle on each orbit + dotted path, shown `pre` seconds before launch.

const TEX := preload("res://assets/sprites/meteor.png")
const R0 := 150.0
const RADIUS := 4.5

var theta := 0.0
var speed := 100.0
var t_launch := 0.0
var t_impact := 0.0
var _rr := RADIUS + Orbit.PLAYER_R
var _impact_fx_done := false
signal impacted(pos: Vector2)


func setup(p_theta: float, p_t_spawn: float, pre: float, p_speed: float, p_home := 0) -> Meteor:
	set_home(p_home)
	theta = wrapf(p_theta, -PI, PI)
	t_spawn = p_t_spawn
	speed = p_speed
	t_launch = t_spawn + pre
	# distance along the fall where any orbit can be touched (sampled, conservative)
	var r_hi := 0.0
	var r_lo := INF
	var dir := Vector2(cos(theta), sin(theta))
	var r := R0
	var pr := Orbit.planet_r(home_k)
	while r > pr:
		var hit := false
		for k in Orbit.count():
			var p := home + dir * r
			var v := p - Orbit.center(k)
			if absf(v.length() - Orbit.radius(k, v.angle())) < _rr + 3.0:
				hit = true
		if hit:
			r_hi = maxf(r_hi, r)
			r_lo = minf(r_lo, r)
		r -= 2.0
	if r_hi <= 0.0:
		r_hi = Orbit.radius(home_k, theta); r_lo = r_hi
	t_danger_start = t_launch + (R0 - r_hi - _rr) / speed
	t_danger_end = t_launch + (R0 - r_lo + _rr) / speed
	t_impact = t_launch + (R0 - pr - 2.0) / speed
	t_end = t_impact + 0.4
	return self


## Time until this meteor reaches the orbit (for aiming patterns).
static func time_to_orbit(pre: float, spd: float, r: float) -> float:
	return pre + (R0 - r) / spd


func radius_at(time: float) -> float:
	return R0 - speed * maxf(0.0, time - t_launch)


func label_angle(_time: float) -> float:
	return theta


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	point_danger(home + Vector2(cos(theta), sin(theta)) * radius_at(time), _rr, k, out)


func tick(time: float) -> void:
	super(time)
	if time >= t_impact and not _impact_fx_done:
		_impact_fx_done = true
		impacted.emit(position + home + Vector2(cos(theta), sin(theta)) * (Orbit.planet_r(home_k) + 1.0))


func _draw() -> void:
	var warn_col := Color(1.0, 0.35, 0.3)
	var dir := Vector2(cos(theta), sin(theta))
	var r := radius_at(t)
	if t < t_danger_end:
		var inner := Orbit.radius(home_k, theta)
		var blink := 0.55 + 0.45 * sin(t * 30.0)
		var d := minf(r - 8.0, R0)
		while d > inner + 6.0:
			draw_rect(Rect2((home + dir * d).floor(), Vector2(1, 1)), Color(1, 0.55, 0.35, 0.8 * blink))
			d -= 5.0
		var k01 := clampf((t_danger_start - t) / maxf(0.01, t_danger_start - t_spawn), 0.0, 1.0)
		var rad := 6.0 + 8.0 * k01
		var col := warn_col if fmod(t * (6.0 + 10.0 * (1.0 - k01)), 1.0) < 0.6 else Color(1, 0.9, 0.4)
		for k in [home_k]:
			var c := ring_pos(theta, k).round()
			if r < Orbit.radius(k, theta) - _rr:
				continue
			draw_arc(c, rad, 0.0, TAU, 16, Color(0.15, 0.1, 0.25, 0.7), 3.0)
			draw_arc(c, rad, 0.0, TAU, 16, col, 1.0)
			for i in 4:
				var a := i * PI * 0.5 + t * 2.0
				draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * (rad + 2.0)).floor(), Vector2(1, 1)), col)
	if t >= t_launch and t < t_impact:
		var p := home + dir * r
		draw_set_transform(p.round(), theta + PI * 0.5, Vector2.ONE)
		var fr := int(t * 14.0) % 2
		draw_texture_rect_region(TEX, Rect2(-6, -14, 12, 20), Rect2(fr * 12, 0, 12, 20))
		draw_set_transform(Vector2.ZERO)
	elif t >= t_impact:
		var e := (t - t_impact) / 0.4
		var c2 := home + dir * (Orbit.planet_r(home_k) + 2.0)
		for i in 5:
			var a2 := theta + (i - 2) * 0.6
			var q := c2 + Vector2(cos(a2), sin(a2)) * (2.0 + 9.0 * e)
			var s := maxf(1.0, 3.0 * (1.0 - e))
			draw_rect(Rect2(q.floor(), Vector2(s, s)), Color(0.95, 0.85, 0.8, 1.0 - e))
