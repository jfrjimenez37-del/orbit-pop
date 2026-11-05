class_name ObstacleIcon
extends Control
## 20x20 picture of an obstacle kind (Director.KINDS) for the collection screen.
## Locked kinds are drawn as a dark silhouette.

const METEOR := preload("res://assets/sprites/meteor.png")
const SPIKY := preload("res://assets/sprites/spiky.png")
const SAW := preload("res://assets/sprites/saw.png")
const NODE := preload("res://assets/sprites/node.png")
const DARK := Color(0.15, 0.1, 0.25, 0.9)

var kind := "meteor"
var locked := false


func _init(p_kind := "meteor", p_locked := false) -> void:
	kind = p_kind
	locked = p_locked
	custom_minimum_size = Vector2(20, 20)
	size = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(10, 10)
	if locked:
		modulate = Color(0.25, 0.22, 0.35, 0.8)
	match kind:
		"meteor":
			draw_set_transform(c + Vector2(2, -1), 0.7, Vector2(0.85, 0.85))
			draw_texture_rect_region(METEOR, Rect2(-6, -10, 12, 20), Rect2(0, 0, 12, 20))
		"mine":
			draw_set_transform(c, 0.0, Vector2(1, 1))
			draw_texture_rect_region(SPIKY, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17))
		"saw":
			draw_set_transform(c, 0.3, Vector2(1, 1))
			draw_texture_rect_region(SAW, Rect2(-8, -8, 17, 17), Rect2(0, 0, 17, 17))
		"spoke":
			draw_line(Vector2(3, 17), Vector2(17, 3), DARK, 4.0)
			draw_line(Vector2(3, 17), Vector2(17, 3), Color(1, 0.92, 0.3), 2.0)
			draw_texture(NODE, Vector2(-2, 12))
			draw_texture(NODE, Vector2(12, -2))
		"pulse":
			draw_arc(c, 8.0, 0.9, TAU - 0.9, 20, DARK, 4.0)
			draw_arc(c, 8.0, 0.9, TAU - 0.9, 20, Color(1, 0.45, 0.6), 2.0)
			draw_arc(c, 8.0, -0.7, 0.7, 8, Color(0.4, 1.0, 0.55), 1.0)
		"link":
			var pts := PackedVector2Array([Vector2(3, 10), Vector2(7, 7), Vector2(10, 12), Vector2(13, 8), Vector2(17, 10)])
			draw_polyline(pts, DARK, 4.0)
			draw_polyline(pts, Color(1, 0.92, 0.3), 2.0)
			draw_circle(Vector2(2, 10), 2.5, Color(0.5, 0.8, 1.0))
			draw_circle(Vector2(18, 10), 2.5, Color(0.5, 0.8, 1.0))
		"comet":
			for i in 4:
				draw_rect(Rect2(Vector2(3 + i * 2, 15 - i * 2), Vector2(2, 2)), Color(0.7, 0.95, 1.0, 0.3 + i * 0.15))
			draw_set_transform(c + Vector2(3, -3), 0.785, Vector2(0.8, 0.8))
			draw_texture_rect_region(METEOR, Rect2(-6, -10, 12, 20), Rect2(0, 0, 12, 20), Color(0.65, 0.95, 1.2))
		"boomerang":
			var arm := PackedVector2Array([Vector2(3, 14), Vector2(10, 5), Vector2(17, 14)])
			draw_polyline(arm, DARK, 6.0)
			draw_polyline(arm, Color(1, 0.62, 0.2), 4.0)
			draw_polyline(PackedVector2Array([Vector2(4, 13), Vector2(10, 6), Vector2(16, 13)]), Color(1, 0.92, 0.6), 1.0)
		"satellite":
			draw_rect(Rect2(0, 7, 6, 6), DARK); draw_rect(Rect2(14, 7, 6, 6), DARK)
			draw_rect(Rect2(1, 8, 4, 4), Color(0.3, 0.55, 1.0)); draw_rect(Rect2(15, 8, 4, 4), Color(0.3, 0.55, 1.0))
			draw_rect(Rect2(6, 6, 8, 8), DARK)
			draw_rect(Rect2(7, 7, 6, 6), Color(0.9, 0.9, 0.96))
			draw_rect(Rect2(9, 9, 2, 2), Color(1, 0.3, 0.35))
		"flare":
			draw_circle(Vector2(3, 10), 4.0, Color(0.5, 1.0, 0.7))
			for layer in [[1.0, DARK], [0.8, Color(1, 0.45, 0.15)], [0.5, Color(1, 0.85, 0.3)], [0.2, Color(1, 1, 0.85)]]:
				var hw: float = 0.45 * float(layer[0])
				var pts2 := PackedVector2Array([Vector2(6, 10)])
				for i in 7:
					var a := -hw + hw * 2.0 * i / 6.0
					pts2.append(Vector2(6, 10) + Vector2(cos(a), sin(a)) * 13.0)
				draw_colored_polygon(pts2, layer[1])
		"ufo":
			draw_rect(Rect2(0, 9, 20, 6), DARK)
			draw_rect(Rect2(5, 4, 10, 6), DARK)
			draw_rect(Rect2(1, 10, 18, 4), Color(0.72, 0.76, 0.88))
			draw_rect(Rect2(6, 5, 8, 5), Color(0.5, 1.0, 0.6))
			for i in 4:
				draw_rect(Rect2(3 + i * 4, 12, 2, 1), Color(1, 0.9, 0.3))
		"belt":
			for p in [Vector2(4, 13), Vector2(10, 9), Vector2(16, 12)]:
				draw_circle(p, 4.0, DARK)
				draw_circle(p, 3.0, Color(0.78, 0.52, 0.36))
				draw_circle(p + Vector2(-1, -1), 1.5, Color(0.95, 0.75, 0.55))
		"split":
			draw_set_transform(Vector2(6, 9), 2.4, Vector2(0.6, 0.6))
			draw_texture_rect_region(METEOR, Rect2(-6, -10, 12, 20), Rect2(0, 0, 12, 20), Color(0.85, 0.55, 1.0))
			draw_set_transform(Vector2(14, 9), -2.4, Vector2(0.6, 0.6))
			draw_texture_rect_region(METEOR, Rect2(-6, -10, 12, 20), Rect2(0, 0, 12, 20), Color(0.85, 0.55, 1.0))
		"beams":
			draw_line(Vector2(1, 18), Vector2(19, 2), DARK, 5.0)
			draw_line(Vector2(1, 18), Vector2(19, 2), Color(0.75, 0.45, 1.0), 3.0)
			draw_line(Vector2(1, 18), Vector2(19, 2), Color(1, 0.9, 1.0), 1.0)
			draw_circle(c, 5.0, DARK)
			draw_circle(c, 4.0, Color(0.5, 1.0, 0.7))
	draw_set_transform(Vector2.ZERO)
