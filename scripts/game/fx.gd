class_name Fx
extends Node2D
## Lightweight pixel particle + floating text system (single draw call node, no allocations per frame).

const FONT := preload("res://assets/font/pixel.fnt")

var _parts := []   # [pos, vel, life, max_life, color, size, gravity]
var _texts := []   # [text, pos, life, max_life, color, scale]
var _rings := []   # [pos, life, max_life, color, r0, r1]


func clear() -> void:
	_parts.clear(); _texts.clear(); _rings.clear()


func burst(pos: Vector2, n: int, colors: Array, speed := 50.0, life := 0.4, size := 2.0, gravity := 0.0, dir := Vector2.ZERO, spread := PI) -> void:
	for i in n:
		var a := randf() * TAU if dir == Vector2.ZERO else dir.angle() + randf_range(-spread, spread)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0)
		_parts.append([pos, v, life * randf_range(0.6, 1.0), life, colors[i % colors.size()], size, gravity])


func ring(pos: Vector2, color: Color, r0 := 4.0, r1 := 16.0, life := 0.25) -> void:
	_rings.append([pos, life, life, color, r0, r1])


func text(s: String, pos: Vector2, color := Color.WHITE, scale := 1.0, life := 0.7) -> void:
	_texts.append([s, pos, life, life, color, scale])


func _process(delta: float) -> void:
	for p in _parts:
		p[1].y += p[6] * delta
		p[1] *= 1.0 - 2.5 * delta
		p[0] += p[1] * delta
		p[2] -= delta
	for x in _texts:
		x[1].y -= 18.0 * delta * (x[2] / x[3])
		x[2] -= delta
	for r in _rings:
		r[1] -= delta
	_parts = _parts.filter(func(p): return p[2] > 0.0)
	_texts = _texts.filter(func(x): return x[2] > 0.0)
	_rings = _rings.filter(func(r): return r[1] > 0.0)
	queue_redraw()


func _draw() -> void:
	for r in _rings:
		var k: float = 1.0 - r[1] / r[2]
		var c: Color = r[3]
		c.a *= 1.0 - k
		draw_arc(r[0].round(), lerpf(r[4], r[5], k), 0.0, TAU, 20, c, 1.0)
	for p in _parts:
		var k: float = p[2] / p[3]
		var s := maxf(1.0, roundf(p[5] * (0.5 + 0.5 * k)))
		draw_rect(Rect2((p[0] - Vector2(s, s) * 0.5).round(), Vector2(s, s)), p[4])
	for x in _texts:
		var k: float = x[2] / x[3]
		var pop: float = x[5]
		var w := FONT.get_string_size(x[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var c: Color = x[4]
		c.a = clampf(k * 3.0, 0.0, 1.0)
		draw_set_transform(x[1].round(), 0.0, Vector2(pop, pop))
		draw_string(FONT, Vector2(-w * 0.5, 3).round(), x[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
	draw_set_transform(Vector2.ZERO)
