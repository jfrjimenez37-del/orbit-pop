class_name Barrier
extends Hazard
## Electric spoke from the planet surface beyond every orbit. Flickers as a dashed
## warning first, then becomes a lethal beam for a while. Can rotate (`spin`).

const NODE_TEX := preload("res://assets/sprites/node.png")
const BEAM_HALF := 1.5

var theta0 := 0.0
var spin := 0.0
var r_out := 80.0
var R_IN := Orbit.PLANET_R + 4.0


func setup(p_theta: float, p_t_spawn: float, warn: float, active: float, p_spin := 0.0, p_home := 0) -> Barrier:
	set_home(p_home)
	theta0 = p_theta
	t_spawn = p_t_spawn
	spin = p_spin
	t_danger_start = t_spawn + warn
	t_danger_end = t_danger_start + active
	t_end = t_danger_end + 0.2
	r_out = Orbit.max_radius(home_k) + 18.0
	R_IN = Orbit.planet_r(home_k) + 4.0
	return self


func theta_at(time: float) -> float:
	return theta0 + spin * (time - t_spawn)


func label_angle(time: float) -> float:
	return theta_at(time)


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	var a := theta_at(time)
	var hc := home_now()
	if Orbit.center(k).distance_to(hc) < 1.0:
		out.append(Vector2(wrapf(a, -PI, PI), asin((Orbit.PLAYER_R + BEAM_HALF) / Orbit.radius(k, a))))
		return
	# beam of another planet: orbit samples close enough to the beam segment are dangerous
	var d := Vector2(cos(a), sin(a))
	var mid := hc + d * (R_IN + r_out) * 0.5
	if mid.distance_to(Orbit.center(k)) > Orbit.rmax_k[mini(k, Orbit.rmax_k.size() - 1)] + (r_out - R_IN) * 0.5 + 8.0:
		return
	segment_danger(hc + d * R_IN, hc + d * r_out, Orbit.PLAYER_R + BEAM_HALF + 1.5, k, out)


func _draw() -> void:
	var hc := home_now()
	var a := theta_at(t)
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	var p_in := hc + d * R_IN
	var p_out := hc + d * r_out
	if t < t_danger_start:
		var k := clampf((t - t_spawn) / (t_danger_start - t_spawn), 0.0, 1.0)
		var on := fmod(t * (5.0 + 12.0 * k), 1.0) < 0.55
		var r := R_IN
		while r < r_out:
			if on:
				draw_rect(Rect2((hc + d * r).floor(), Vector2(1, 1)), Color(1, 0.95, 0.4, 0.5 + 0.5 * k))
			r += 4.0
		var gc := Color(1, 1, 1, 0.4 + 0.5 * k)
		draw_texture(NODE_TEX, (p_in - Vector2(5, 5)).round(), gc)
		draw_texture(NODE_TEX, (p_out - Vector2(5, 5)).round(), gc)
		return
	var alive := t <= t_danger_end
	if alive:
		var pts := PackedVector2Array()
		var segs := 10
		var seed_t := int(t * 24.0)
		for i in segs + 1:
			var f := float(i) / segs
			var j := 0.0 if i == 0 or i == segs else (float((seed_t * 31 + i * 17) % 7) - 3.0) * 0.8
			pts.append((p_in.lerp(p_out, f) + n * j).round())
		draw_polyline(pts, Color(0.15, 0.1, 0.25, 0.85), 4.0)
		draw_polyline(pts, Color(1, 0.92, 0.3), 2.0)
		draw_polyline(pts, Color(1, 1, 1), 1.0)
	var fade := 1.0 if alive else 1.0 - (t - t_danger_end) / 0.2
	draw_texture(NODE_TEX, (p_in - Vector2(5, 5)).round(), Color(1, 1, 1, fade))
	draw_texture(NODE_TEX, (p_out - Vector2(5, 5)).round(), Color(1, 1, 1, fade))
