class_name AimPreview
extends Node2D
## TELEPORT aiming (main.gd): a dotted line from the player to the spot under the aim and a
## blinking ghost of the player there. Drawn in World coordinates, above the hazards.

const COL := Color8(220, 170, 255)
const DARK := Color(0.15, 0.1, 0.25, 0.85)

var from := Vector2.ZERO
var to := Vector2.ZERO
var cancel := false        # the finger is back on the player: letting go cancels
var _t := 0.0


func show_aim(p_from: Vector2, p_to: Vector2, p_cancel: bool) -> void:
	from = p_from
	to = p_to
	cancel = p_cancel
	visible = true
	queue_redraw()


func hide_aim() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if cancel:
		draw_arc(from.round(), 9.0, 0.0, TAU, 16, DARK, 3.0)
		draw_arc(from.round(), 9.0, 0.0, TAU, 16, Color(1, 1, 1, 0.6), 1.0)
		return
	var d := to - from
	var n := int(d.length() / 4.0)
	for i in range(1, n):
		var p := (from + d * (float(i) / n)).round()
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), DARK)
		var on := fmod(_t * 6.0 - i * 0.25, 1.0) < 0.6
		draw_rect(Rect2(p, Vector2(1, 1)), COL if on else Color(COL, 0.4))
	var c := to.round()
	var pulse := 0.5 + 0.5 * sin(_t * 14.0)
	draw_circle(c, 5.0, Color(COL, 0.25 + 0.2 * pulse))
	draw_arc(c, 6.0 + pulse, 0.0, TAU, 16, DARK, 3.0)
	draw_arc(c, 6.0 + pulse, 0.0, TAU, 16, COL, 1.0)
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var v := Vector2(cos(a), sin(a))
		draw_line(c + v * 9.0, c + v * 12.0, COL, 1.0)
