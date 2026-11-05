class_name PremiumGlow
extends Control
## Glow behind a premium skin in the style screen: a soft pulsing halo in the rarity colour, slow
## light rays and two glints. `on` false = nothing drawn.

var on := false
var color := Color.WHITE
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if on and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	if not on:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	draw_circle(c, r * (0.72 + 0.06 * pulse), Color(color, 0.14 + 0.08 * pulse))
	draw_circle(c, r * 0.5, Color(color, 0.12))
	for i in 8:
		var a := i * TAU / 8.0 + _t * 0.35
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * r * 0.55, c + d * r * (0.86 + 0.08 * sin(_t * 3.0 + i)), Color(color, 0.35), 2.0)
	for i in 2:
		var ph := fmod(_t * 0.6 + i * 0.5, 1.0)
		var a2 := i * PI + _t * 0.9
		var p := (c + Vector2(cos(a2), sin(a2)) * r * 0.78).round()
		var k := sin(ph * PI)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, k))
		if k > 0.5:
			for o in [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
				draw_rect(Rect2(p + o - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 1, 1, k * 0.7))
