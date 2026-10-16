class_name Meteor
extends Hazard
## Falls straight toward the planet along angle `theta`, crossing the orbit once.
## Warning: target reticle on the ring + dotted path, shown `pre` seconds before launch.

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


func setup(p_theta: float, p_t_spawn: float, pre: float, p_speed: float) -> Meteor:
	theta = wrapf(p_theta, -PI, PI)
	t_spawn = p_t_spawn
	speed = p_speed
	t_launch = t_spawn + pre
	t_danger_start = t_launch + (R0 - Orbit.R - _rr) / speed
	t_danger_end = t_launch + (R0 - Orbit.R + _rr) / speed
	t_impact = t_launch + (R0 - Orbit.PLANET_R - 2.0) / speed
	t_end = t_impact + 0.4
	return self


func radius_at(time: float) -> float:
	return R0 - speed * maxf(0.0, time - t_launch)


func label_angle(_time: float) -> float:
	return theta


func danger(time: float, out: Array) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var r := radius_at(time)
	var R := Orbit.R
	var c := (R * R + r * r - _rr * _rr) / (2.0 * R * r)
	if c >= 1.0:
		return
	out.append(Vector2(theta, acos(clampf(c, -1.0, 1.0))))


func tick(time: float) -> void:
	super(time)
	if time >= t_impact and not _impact_fx_done:
		_impact_fx_done = true
		impacted.emit(position + ring_pos(theta, Orbit.PLANET_R + 1.0))


func _draw() -> void:
	var warn_col := Color(1.0, 0.35, 0.3)
	var dir := Vector2(cos(theta), sin(theta))
	var r := radius_at(t)
	if t < t_danger_end:
		# dotted incoming path
		var blink := 0.55 + 0.45 * sin(t * 30.0)
		var from_r := maxf(Orbit.R + 6.0, minf(r - 8.0, R0))
		var d := from_r
		while d > Orbit.R + 6.0:
			draw_rect(Rect2((dir * d).floor(), Vector2(1, 1)), Color(1, 0.55, 0.35, 0.8 * blink))
			d -= 5.0
		# shrinking reticle
		var k := clampf((t_danger_start - t) / maxf(0.01, t_danger_start - t_spawn), 0.0, 1.0)
		var rad := 6.0 + 8.0 * k
		var col := warn_col if fmod(t * (6.0 + 10.0 * (1.0 - k)), 1.0) < 0.6 else Color(1, 0.9, 0.4)
		var c := ring_pos(theta).round()
		draw_arc(c, rad, 0.0, TAU, 16, Color(0.15, 0.1, 0.25, 0.7), 3.0)
		draw_arc(c, rad, 0.0, TAU, 16, col, 1.0)
		for i in 4:
			var a := i * PI * 0.5 + t * 2.0
			draw_rect(Rect2((c + Vector2(cos(a), sin(a)) * (rad + 2.0)).floor(), Vector2(1, 1)), col)
	if t >= t_launch and t < t_impact:
		var p := dir * r
		draw_set_transform(p.round(), theta + PI * 0.5, Vector2.ONE)
		var fr := int(t * 14.0) % 2
		draw_texture_rect_region(TEX, Rect2(-6, -14, 12, 20), Rect2(fr * 12, 0, 12, 20))
		draw_set_transform(Vector2.ZERO)
	elif t >= t_impact:
		var e := (t - t_impact) / 0.4
		var c := dir * (Orbit.PLANET_R + 2.0)
		for i in 5:
			var a := theta + (i - 2) * 0.6
			var q := c + Vector2(cos(a), sin(a)) * (2.0 + 9.0 * e)
			var s := maxf(1.0, 3.0 * (1.0 - e))
			draw_rect(Rect2(q.floor(), Vector2(s, s)), Color(0.95, 0.85, 0.8, 1.0 - e))
