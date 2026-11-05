class_name Ufo
extends Hazard
## World 12 (GIANT): a UFO flies around the planet just outside the orbit and drops mines on
## it, one after another. Each mine falls onto the orbit, stays a moment and pops.
## Warning: the UFO itself plus a blinking reticle where every mine will land.

const SPIKY := preload("res://assets/sprites/spiky.png")
const FALL := 0.3
const MINE_R := 4.0

var a0 := 0.0
var fly := 1.2            # rad/s around the planet (sign = direction)
var r_fly := 70.0
var drops: Array = []     # [drop time, angle]
var stay := 1.3
var _rr := MINE_R + Orbit.PLAYER_R


## `n` mines, the first `warn` s after spawning, then every `gap` s.
func setup(p_a0: float, p_fly: float, p_t_spawn: float, warn: float, n: int, gap: float, p_stay: float, p_home := 0) -> Ufo:
	set_home(p_home)
	a0 = p_a0
	fly = p_fly
	stay = p_stay
	t_spawn = p_t_spawn
	r_fly = Orbit.max_radius(home_k) + 22.0
	drops.clear()
	for i in n:
		var td := t_spawn + warn + i * gap
		drops.append([td, wrapf(ufo_angle(td), -PI, PI)])
	t_danger_start = float(drops[0][0]) + FALL * 0.3
	t_danger_end = float(drops[-1][0]) + FALL + stay
	t_end = t_danger_end + 0.6
	return self


func ufo_angle(time: float) -> float:
	return a0 + fly * (time - t_spawn)


func mine_pos(i: int, time: float) -> Vector2:
	var td: float = drops[i][0]
	var a: float = drops[i][1]
	var land := Orbit.pos(home_k, a)
	var top := home_now() + Vector2(cos(a), sin(a)) * r_fly
	return top.lerp(land, clampf((time - td) / FALL, 0.0, 1.0))


func label_angle(time: float) -> float:
	return wrapf(ufo_angle(time), -PI, PI)


func danger(time: float, out: Array, k := 0) -> void:
	if time < t_danger_start or time > t_danger_end:
		return
	for i in drops.size():
		var td: float = drops[i][0]
		if time >= td and time <= td + FALL + stay:
			point_danger(mine_pos(i, time), _rr, k, out)


func _draw() -> void:
	var hc := home_now()
	# landing reticles until each mine lands
	for i in drops.size():
		var td: float = drops[i][0]
		var a: float = drops[i][1]
		var c := Orbit.pos(home_k, a).round()
		if t < td + FALL:
			var on := fmod(t * 8.0 + i * 0.3, 1.0) < 0.6
			draw_arc(c, 6.0, 0.0, TAU, 12, Color(0.15, 0.1, 0.25, 0.6), 3.0)
			draw_arc(c, 6.0, 0.0, TAU, 12, Color(0.5, 1.0, 0.5) if on else Color(1, 1, 0.6), 1.0)
		if t >= td and t <= td + FALL + stay + 0.25:
			var p := mine_pos(i, t).round()
			var e := clampf((t - td - FALL - stay) / 0.25, 0.0, 1.0)
			var s := 0.8 + 0.08 * sin(t * 20.0) if e <= 0.0 else 0.8 * (1.0 + e)
			draw_set_transform(p, e * 2.0, Vector2(s, s))
			draw_texture_rect_region(SPIKY, Rect2(-8, -8, 17, 17), Rect2((int(t * 8.0) % 2) * 17, 0, 17, 17), Color(0.75, 1.15, 0.7, 1.0 - e))
			draw_set_transform(Vector2.ZERO)
	if t > t_end:
		return
	# the UFO: comes in, flies, leaves fading
	var fade := clampf((t - t_spawn) / 0.3, 0.0, 1.0) * clampf((t_end - t) / 0.4, 0.0, 1.0)
	var ua := ufo_angle(t)
	var up := (hc + Vector2(cos(ua), sin(ua)) * r_fly).round()
	var dark := Color(0.15, 0.1, 0.25, 0.9 * fade)
	up += Vector2(0, roundf(sin(t * 6.0)))
	draw_rect(Rect2(up + Vector2(-10, -1), Vector2(20, 6)), dark)
	draw_rect(Rect2(up + Vector2(-5, -6), Vector2(10, 6)), dark)
	draw_rect(Rect2(up + Vector2(-9, 0), Vector2(18, 4)), Color(0.72, 0.76, 0.88, fade))
	draw_rect(Rect2(up + Vector2(-9, 0), Vector2(18, 1)), Color(0.92, 0.94, 1.0, fade))
	draw_rect(Rect2(up + Vector2(-4, -5), Vector2(8, 5)), Color(0.5, 1.0, 0.6, fade))
	draw_rect(Rect2(up + Vector2(-3, -4), Vector2(2, 2)), Color(0.85, 1.0, 0.9, fade))
	for i in 4:
		var lit := int(t * 8.0) % 4 == i
		draw_rect(Rect2(up + Vector2(-7 + i * 4, 2), Vector2(2, 1)), Color(1, 0.9, 0.3, fade) if lit else Color(0.45, 0.45, 0.6, fade))
