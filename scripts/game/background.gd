class_name Backdrop
extends Node2D
## SKY POP backdrop: banded sky gradient, sun, drifting clouds, far islands, cloud sea.

const CLOUDS := [
	preload("res://assets/sprites/cloud_big.png"),
	preload("res://assets/sprites/cloud_mid.png"),
	preload("res://assets/sprites/cloud_small.png"),
]
const ISLANDS := [preload("res://assets/sprites/island_a.png"), preload("res://assets/sprites/island_b.png")]
const SUN := preload("res://assets/sprites/sun.png")
const FLOOR := preload("res://assets/sprites/cloud_floor.png")
var TOP := Color8(70, 152, 255)
var BOTTOM := Color8(176, 230, 255)
var cloud_tint := Color(1, 1, 1)
var stars := false

var size := Vector2(180, 320)
var _t := 0.0
var _clouds := []   # [tex_index, x, y, speed]
var _islands := []
var speed_mul := 1.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 7:
		var k := 2 if i < 3 else (1 if i < 5 else 0)
		_clouds.append([k, rng.randf_range(-40, 200), 0.0, (3.0 + 4.0 * (2 - k)) * rng.randf_range(0.8, 1.2), rng.randf()])
	_islands = [[0, 30.0, 0.62, 1.2], [1, 130.0, 0.44, 0.8]]
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	size = get_viewport_rect().size
	for c in _clouds:
		c[2] = 20.0 + c[4] * (size.y * 0.72)


func _process(delta: float) -> void:
	_t += delta * speed_mul
	for c in _clouds:
		c[1] -= c[3] * delta * speed_mul
		var w: float = CLOUDS[c[0]].get_width()
		if c[1] < -w - 4:
			c[1] = size.x + randf_range(4, 40)
			c[4] = randf()
			c[2] = 20.0 + c[4] * (size.y * 0.72)
	for isl in _islands:
		isl[1] -= isl[3] * delta * speed_mul
		if isl[1] < -30:
			isl[1] = size.x + 10
	queue_redraw()


func _draw() -> void:
	# banded gradient with a 1-row checker dither between bands
	var bands := 10
	var bh := ceilf(size.y / bands)
	for i in bands:
		var c := TOP.lerp(BOTTOM, float(i) / (bands - 1))
		draw_rect(Rect2(0, i * bh, size.x, bh), c)
		if i > 0:
			var prev := TOP.lerp(BOTTOM, float(i - 1) / (bands - 1))
			var x := 0
			while x < size.x:
				draw_rect(Rect2(x, i * bh, 1, 1), prev)
				x += 2
	if stars:
		for i in 40:
			var sx := fmod(i * 73.0 + _t * 0.5, size.x)
			var sy := fmod(i * 131.0, size.y * 0.8)
			if (i + int(_t * 2.0)) % 7 != 0:
				draw_rect(Rect2(Vector2(sx, sy).floor(), Vector2(1, 1)), Color(1, 1, 1, 0.8))
	draw_texture(SUN, Vector2(size.x - 40, 14), Color(1, 1, 1, 0.55) if stars else Color.WHITE)
	for isl in _islands:
		var y: float = size.y * isl[2] + roundf(sin(_t * 0.6 + isl[1]) * 1.0)
		draw_texture(ISLANDS[isl[0]], Vector2(roundf(isl[1]), roundf(y)), Color(1, 1, 1, 0.75))
	for c in _clouds:
		var tex: Texture2D = CLOUDS[c[0]]
		var a := 0.75 if c[0] == 2 else 0.95
		var tint := cloud_tint
		tint.a *= a
		draw_texture(tex, Vector2(roundf(c[1]), roundf(c[2])), tint)
	# cloud sea at the bottom
	var fw := FLOOR.get_width()
	var off := fmod(_t * 6.0, fw)
	var x2 := -off
	while x2 < size.x:
		draw_texture(FLOOR, Vector2(roundf(x2), size.y - 20))
		x2 += fw


func apply_world(w: Dictionary) -> void:
	TOP = w["top"]
	BOTTOM = w["bottom"]
	cloud_tint = w["cloud"]
	stars = w["stars"]
	RenderingServer.set_default_clear_color(BOTTOM)
