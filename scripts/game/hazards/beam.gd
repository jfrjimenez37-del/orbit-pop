class_name Beam
extends Barrier
## World 15 (PENDULUM): pulsar beams. Two opposite beams turn slowly around the planet and
## blink on and off: slip through while they are off.
## Warning: both dotted rays; while off, they stay as faint dotted lines.

const ON := 0.6
const OFF := 0.5


func is_on(time: float) -> bool:
	if time < t_danger_start or time > t_danger_end:
		return false
	return fmod(time - t_danger_start, ON + OFF) < ON


func danger(time: float, out: Array, k := 0) -> void:
	if not is_on(time):
		return
	var a := theta_at(time)
	ray_danger(a, out, k)
	ray_danger(a + PI, out, k)


func _draw() -> void:
	var hc := home_now()
	if t > t_end:
		return
	var fade := 1.0 if t <= t_danger_end else 1.0 - (t - t_danger_end) / 0.2
	var lit := is_on(t)
	var k := clampf((t - t_spawn) / maxf(0.01, t_danger_start - t_spawn), 0.0, 1.0)
	for e in [0.0, PI]:
		var a: float = theta_at(t) + e
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var p_in := hc + d * R_IN
		var p_out := hc + d * r_out
		if lit:
			draw_line(p_in, p_out, Color(0.15, 0.1, 0.25, 0.8 * fade), 5.0)
			draw_line(p_in, p_out, Color(0.75, 0.45, 1.0, fade), 3.0)
			draw_line(p_in + n * 0.5, p_out + n * 0.5, Color(1, 0.9, 1.0, fade), 1.0)
		else:
			# soon on again: the dots get brighter
			var soon := 0.0
			if t >= t_danger_start:
				soon = clampf(fmod(t - t_danger_start, ON + OFF) - ON, 0.0, OFF) / OFF
			else:
				soon = k
			var on := fmod(t * (5.0 + 12.0 * soon), 1.0) < 0.6
			var r := R_IN
			while r < r_out:
				if on or int(r) % 8 < 4:
					draw_rect(Rect2((hc + d * r).floor(), Vector2(1, 1)), Color(0.85, 0.6, 1.0, (0.5 + 0.5 * soon) * fade))
				r += 4.0
	draw_arc(hc, R_IN - 2.0, 0.0, TAU, 20, Color(0.8, 0.55, 1.0, (0.8 if lit else 0.35) * fade), 1.0)
