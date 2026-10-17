class_name OrbitPlayer
extends Node2D
## The orbiting critter. Owns the orbital state (angle, direction) and its look:
## flapping wings, blinking, squash on flip, colored trail, death tumble.

const TRAIL_LEN := 12

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


func color() -> Color:
	return Save.SKINS[skin]["color"]


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
	var col := color()
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
	var fx: Array = Save.SKINS[skin].get("fx", [])
	if not fx.is_empty() and alive:
		_draw_fx(fx[0], fx[1], true)
	draw_set_transform(Vector2.ZERO, _dead_rot, Vector2(sx * flipx, sy))
	draw_texture_rect_region(tex, Rect2(-8, -9, 16, 16), Rect2(frame * 16, 0, 16, 16))
	draw_set_transform(Vector2.ZERO)
	if not fx.is_empty() and alive:
		_draw_fx(fx[0], fx[1], false)


func _px(p: Vector2, c: Color, s := 1.0) -> void:
	draw_rect(Rect2((p - Vector2(s, s) * 0.5).round(), Vector2(s, s)), c)


func _sparkle(p: Vector2, c: Color, k: float) -> void:
	_px(p, c)
	if k > 0.5:
		for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			_px(p + o, Color(c, 0.7))


## Rarity effects. `back`: drawn behind the sprite (auras), else in front (particles).
func _draw_fx(kind: String, c: Color, back: bool) -> void:
	var t := _t
	match kind:
		"sparkle", "stars":
			if back:
				return
			for i in 3:
				var ph := fmod(t * 0.9 + i / 3.0, 1.0)
				var a := i * TAU / 3.0 + t * 0.8
				var p := Vector2(cos(a), sin(a)) * (10.0 + 2.0 * sin(t * 2.0 + i)) + Vector2(0, -1)
				var k := sin(ph * PI)
				_sparkle(p, Color(c if kind == "sparkle" or i != 1 else Color.WHITE, k), k)
		"bolt":
			if back or fmod(t, 0.9) > 0.18:
				return
			var a2 := floorf(t / 0.9) * 2.4
			var p0 := Vector2(cos(a2), sin(a2)) * 7.0
			var p1 := Vector2(cos(a2 + 0.3), sin(a2 + 0.3)) * 11.0
			_px(p0, c); _px(p0.lerp(p1, 0.5) + Vector2(1, 0), c); _px(p1, c)
		"wisp":
			if back:
				return
			for i in 3:
				var ph2 := fmod(t * 0.5 + i / 3.0, 1.0)
				var a3 := i * TAU / 3.0 + t * 0.6
				var p2 := Vector2(cos(a3) * 11.0, sin(a3) * 8.0 - ph2 * 4.0)
				var al := sin(ph2 * PI)
				_px(p2, Color(c, al), 2.0)
				_px(p2 + Vector2(0, -2), Color(c.lightened(0.4), al * 0.8))
		"embers":
			if back:
				return
			for i in 4:
				var ph3 := fmod(t * 0.8 + i * 0.25, 1.0)
				var x := sin(i * 2.7 + floorf(t * 0.8 + i * 0.25) * 1.3) * 7.0
				_px(Vector2(x, 4.0 - ph3 * 18.0), Color(c, 1.0 - ph3), 2.0 if ph3 < 0.4 else 1.0)
		"aura", "nova":
			if back:
				var rr := 11.0 + roundf(sin(t * 3.0))
				draw_arc(Vector2(0, -1), rr, 0.0, TAU, 24, Color(c, 0.35), 2.0)
				return
			for i in 6:
				var a4 := i * TAU / 6.0 + t * (1.4 if kind == "aura" else -1.8)
				_px(Vector2(cos(a4), sin(a4)) * 12.0 + Vector2(0, -1), Color(c, 0.9))
			if kind == "nova":
				for i in 3:
					var ph4 := fmod(t * 0.7 + i / 3.0, 1.0)
					var a5 := i * 2.1 + t * 0.4
					_sparkle(Vector2(cos(a5), sin(a5)) * 15.0, Color(1, 1, 1, sin(ph4 * PI)), sin(ph4 * PI))
		"rainbow", "omega":
			if back:
				if kind == "omega":
					draw_arc(Vector2(0, -1), 12.0 + roundf(sin(t * 4.0)), 0.0, TAU, 24,
						Color.from_hsv(fmod(t * 0.3, 1.0), 0.7, 1.0, 0.45), 2.0)
				return
			var n := 6 if kind == "rainbow" else 8
			for i in n:
				var a6 := i * TAU / n + t * 1.2
				var rad := 11.0 + (2.0 * sin(t * 3.0 + i) if kind == "omega" else 0.0)
				_px(Vector2(cos(a6), sin(a6)) * rad + Vector2(0, -1), RAINBOW[i % RAINBOW.size()])
