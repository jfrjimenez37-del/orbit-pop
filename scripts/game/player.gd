class_name OrbitPlayer
extends Node2D
## The orbiting critter. Owns the orbital state (angle, direction) and its look:
## flapping wings, blinking, squash on flip, colored trail, death tumble.

const TRAIL_LEN := 12
const SKIN_COLORS := [Color8(255, 212, 60), Color8(110, 230, 160), Color8(255, 128, 178),
	Color8(172, 226, 255), Color8(255, 122, 58), Color8(152, 104, 255),
	Color8(255, 204, 44), Color8(64, 232, 226), Color8(246, 246, 252)]

var angle := -PI * 0.5
var dir := 1
var orbit := 0      # which orbit (0/1) when two orbits cross
var _r_smooth := -1.0
var omega := 2.4
var alive := true
var tex: Texture2D
var skin := 0
var face_right := true
var happy := false
var shield := 0.0   # seconds of continue-shield left (blinking bubble)
var shield_boost := false  # SHIELD boost armed: steady bubble until it absorbs a hit
var trail_style := "classic"
const RAINBOW := [Color8(255, 90, 90), Color8(255, 170, 60), Color8(255, 230, 70), Color8(110, 220, 110), Color8(90, 170, 255), Color8(170, 110, 255)]

var _t := 0.0
var _blink := 2.5
var _squash := 0.0
var _trail: Array[Vector2] = []
var _dead_vel := Vector2.ZERO
var _dead_pos := Vector2.ZERO
var _dead_rot := 0.0


func set_skin(i: int) -> void:
	skin = i
	tex = load("res://assets/sprites/char_%s.png" % Save.SKINS[i]["id"])


func reset(a := -PI * 0.5) -> void:
	angle = a
	dir = 1
	alive = true
	_trail.clear()
	_dead_rot = 0.0
	orbit = 0
	_r_smooth = -1.0
	position = Orbit.pos(orbit, angle)


## Tap: reverse, or switch orbit when inside a crossing window. Returns true on switch.
func tap() -> bool:
	var res := Orbit.tap_result(angle, orbit, dir)
	var switched: bool = res[0] != orbit
	if switched:
		orbit = res[0]
		dir = res[1]
		angle = res[2]
		_r_smooth = -1.0
		_squash = 1.0
	else:
		flip()
	return switched


func teleport() -> void:
	angle = wrapf(angle + PI, -PI, PI)
	_trail.clear()
	_r_smooth = -1.0
	position = Orbit.pos(orbit, angle)


func flip() -> void:
	dir = -dir
	_squash = 1.0


func advance(delta: float) -> void:
	angle = wrapf(angle + dir * omega * delta, -PI, PI)


func die() -> void:
	alive = false
	_dead_pos = position
	_dead_vel = Vector2(cos(angle), sin(angle)) * 90.0 + Vector2(0, -60)


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(1.5, 3.5)
	_squash = maxf(0.0, _squash - delta * 8.0)
	if alive:
		var r := Orbit.radius(orbit, angle)
		_r_smooth = r if _r_smooth < 0.0 else lerpf(_r_smooth, r, minf(1.0, delta * 25.0))
		position = Orbit.center(orbit) + Vector2(cos(angle), sin(angle)) * _r_smooth
		var tangent_x := -sin(angle) * dir
		if absf(tangent_x) > 0.25:
			face_right = tangent_x > 0.0
		_trail.push_front(position)
		if _trail.size() > TRAIL_LEN:
			_trail.pop_back()
	else:
		_dead_vel.y += 260.0 * delta
		_dead_pos += _dead_vel * delta
		_dead_rot += delta * 12.0
		position = _dead_pos
		if not _trail.is_empty():
			_trail.pop_back()
	queue_redraw()


func _draw() -> void:
	if tex == null:
		return
	var col: Color = SKIN_COLORS[skin]
	for i in range(_trail.size() - 1, 1, -1):
		var p := (_trail[i] - position).round()
		var k := 1.0 - float(i) / TRAIL_LEN
		var s := maxf(1.0, roundf(4.0 * k))
		var c := col if i % 2 == 0 else Color(1, 1, 1)
		match trail_style:
			"sparkle":
				c = Color(1, 1, 1) if (i + int(_t * 20.0)) % 3 else Color8(255, 240, 140)
			"rainbow":
				c = RAINBOW[i % RAINBOW.size()]
			"hearts":
				c = Color8(255, 100, 150)
			"stars":
				c = Color8(255, 220, 60)
		c.a = 0.8 * k
		if (trail_style == "hearts" or trail_style == "stars") and i % 3 == 0:
			var shape := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)] \
				if trail_style == "hearts" else [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]
			for o in shape:
				draw_rect(Rect2(p + o, Vector2(1, 1)), c)
		elif trail_style == "sparkle" and i % 2 == 0:
			draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), c)
			draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), c)
		elif trail_style == "classic" or trail_style == "rainbow":
			draw_rect(Rect2((p - Vector2(s, s) * 0.5).round(), Vector2(s, s)), c)
	var frame := 1
	if not alive:
		frame = 4
	elif happy:
		frame = 5 if fmod(_t, 1.2) < 0.9 else 3
	elif _blink < 0.0:
		frame = 3
	else:
		frame = [0, 1, 2, 1][int(_t * 12.0) % 4]
	var sx := 1.0 + 0.35 * _squash
	var sy := 1.0 - 0.3 * _squash
	var flipx := 1.0 if face_right else -1.0
	if shield_boost and alive:
		draw_arc(Vector2(0, -1), 10.0 + roundf(sin(_t * 6.0)), 0.0, TAU, 20, Color(0.55, 0.9, 1.0, 0.95), 1.0)
	if shield > 0.0 and alive:
		if shield > 0.6 or fmod(shield, 0.2) < 0.1:
			draw_arc(Vector2(0, -1), 10.0, 0.0, TAU, 20, Color(0.7, 0.95, 1.0, 0.9), 1.0)
	draw_set_transform(Vector2.ZERO, _dead_rot, Vector2(sx * flipx, sy))
	draw_texture_rect_region(tex, Rect2(-8, -9, 16, 16), Rect2(frame * 16, 0, 16, 16))
	draw_set_transform(Vector2.ZERO)
