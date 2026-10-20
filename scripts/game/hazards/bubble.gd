class_name Bubble
extends Node2D
## Collectible sitting on an orbit (never a hazard): a bonus bubble (+2 points, +1 coin),
## a coin (+1) or a big coin (+5). With the MAGNET ability it flies to the player.

const TEX := preload("res://assets/sprites/bubble.png")
const COIN_TEX := preload("res://assets/sprites/coin_pick.png")
const BIG_TEX := preload("res://assets/sprites/coin_big.png")
const RADIUS := 6.0
const COIN_RADIUS := 4.0

var theta := 0.0
var orbit := 0
var t_spawn := 0.0
var t_end := 0.0
var t := 0.0
var kind := "bubble"     # bubble | coin | big
var value := 0           # coins it is worth (coin / big)
var flying := false      # pulled by the magnet
var fpos := Vector2.ZERO
var _fspeed := 0.0


func setup(p_theta: float, p_t: float, life: float, p_orbit := 0, p_kind := "bubble") -> Bubble:
	theta = p_theta
	t_spawn = p_t
	t_end = p_t + life
	orbit = mini(p_orbit, Orbit.count() - 1)
	kind = p_kind
	value = 5 if kind == "big" else (1 if kind == "coin" else 0)
	return self


func is_coin() -> bool:
	return kind != "bubble"


func world_pos() -> Vector2:
	return fpos if flying else Orbit.pos(orbit, theta)


func ready_to_take() -> bool:
	return t >= t_spawn + 0.2


func tick(time: float) -> void:
	t = time
	queue_redraw()


## `extra`: additional pickup range.
func touches(angle: float, k := 0, extra := 0.0) -> bool:
	var r := (COIN_RADIUS if is_coin() else RADIUS) + Orbit.PLAYER_R + extra
	return ready_to_take() and Orbit.pos(k, angle).distance_to(world_pos()) <= r


## MAGNET: leave the orbit and home in on `target`. Returns true when it reaches it.
func fly_to(target: Vector2, dt: float) -> bool:
	if not flying:
		flying = true
		fpos = Orbit.pos(orbit, theta)
		_fspeed = 60.0
		t_end = INF
	_fspeed += 520.0 * dt
	fpos = fpos.move_toward(target, _fspeed * dt)
	return fpos.distance_to(target) < 3.0


func _draw() -> void:
	var life := t - t_spawn
	var left := t_end - t
	if not flying and left < 1.0 and fmod(t * 8.0, 1.0) < 0.4:
		return
	var s := clampf(life / 0.2, 0.2, 1.0)
	var bob := Vector2(0, roundf(sin(t * 4.0 + theta * 3.0))) if not flying else Vector2.ZERO
	draw_set_transform(world_pos().round() + bob, 0.0, Vector2(s, s))
	if kind == "bubble":
		draw_texture(TEX, Vector2(-7, -7))
	else:
		var tex: Texture2D = BIG_TEX if kind == "big" else COIN_TEX
		var sz := tex.get_height()
		var f := int(t * 10.0 + theta * 7.0) % 4
		draw_texture_rect_region(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), Rect2(f * sz, 0, sz, sz))
	draw_set_transform(Vector2.ZERO)
