class_name Link
extends Hazard
## Electric bond between two planets. Flickers as a dashed warning, then the whole
## segment between both planet surfaces becomes lethal for a while.

const BEAM_HALF := 2.0

var a_k := 0
var b_k := 1
var _pts: Array = []   # sample points along the beam (fixed while it exists)
var _p0 := Vector2.ZERO
var _p1 := Vector2.ZERO
var _iv: Array = []        # per orbit danger intervals (the beam never moves)
var _iv_ver := -1


func setup(p_a: int, p_b: int, p_t_spawn: float, warn: float, active: float) -> Link:
	a_k = p_a
	b_k = p_b
	set_home(p_a)
	t_spawn = p_t_spawn
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.2
	var ca := Orbit.center(a_k)
	var cb := Orbit.center(b_k)
	var d := (cb - ca).normalized()
	_p0 = ca + d * (Orbit.planet_r(a_k) + 2.0)
	_p1 = cb - d * (Orbit.planet_r(b_k) + 2.0)
	var n := maxi(2, ceili(_p0.distance_to(_p1) / 3.0))
	for i in n + 1:
		_pts.append(_p0.lerp(_p1, float(i) / n))
	return self


func label_angle(_time: float) -> float:
	return Orbit.angle_of(0, (_p0 + _p1) * 0.5)


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	if _iv_ver != Orbit.version or Orbit.morphing():
		_iv.clear()
		_iv_ver = Orbit.version
		for o in Orbit.count():
			var iv: Array = []
			segment_danger(_p0, _p1, Orbit.PLAYER_R + BEAM_HALF + 1.5, o, iv)
			_iv.append(iv)
	out.append_array(_iv[mini(k, _iv.size() - 1)])


func _draw() -> void:
	var n := (_p1 - _p0).normalized().orthogonal()
	if t < t_danger_start:
		var k := clampf((t - t_spawn) / (t_danger_start - t_spawn), 0.0, 1.0)
		if fmod(t * (5.0 + 12.0 * k), 1.0) < 0.55:
			for i in _pts.size():
				if i % 2 == 0:
					draw_rect(Rect2(_pts[i].floor(), Vector2(1, 1)), Color(0.6, 1.0, 1.0, 0.5 + 0.5 * k))
		return
	if t > t_danger_end:
		return
	var pts := PackedVector2Array()
	var seed_t := int(t * 24.0)
	for i in _pts.size():
		var j := 0.0 if i == 0 or i == _pts.size() - 1 else (float((seed_t * 13 + i * 7) % 5) - 2.0) * 0.9
		pts.append((_pts[i] + n * j).round())
	draw_polyline(pts, Color(0.15, 0.1, 0.25, 0.85), 4.0)
	draw_polyline(pts, Color(0.45, 0.95, 1.0), 2.0)
	draw_polyline(pts, Color(1, 1, 1), 1.0)
