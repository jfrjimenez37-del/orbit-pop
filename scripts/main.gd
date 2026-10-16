extends Node2D
## ORBIT POP — game state machine and core loop.

enum S { MENU, PLAYING, DYING, OVER, SKINS, PAUSED, RESUMING, SHOP }

const SUBSTEP := 1.0 / 120.0
const HIT_STOP := 0.09
const DEATH_DELAY := 0.8

@onready var bg: Backdrop = $Background
@onready var world: Node2D = $World
@onready var planet: Planet = $World/Planet
@onready var hazards_root: Node2D = $World/Hazards
@onready var player: OrbitPlayer = $World/Player
@onready var fx: Fx = $World/Fx
@onready var ui: GameUI = $UI

var state := S.MENU
var director := Director.new()
var gt := 0.0                 # gameplay clock (drives every hazard)
var score := 0
var best_at_start := 0
var record_announced := false
var hazards: Array = []
var bubbles: Array = []
var tapped_once := false
var near_count := 0
var continued := false        # rewarded continue already used this run
var shield_until := 0.0
var _death_angle := 0.0

var _grace := 0.0
var _state_t := 0.0
var _shake := 0.0
var _world_y := 0.0
var _world_y_target := 0.0
var _menu_flip := 2.0
var _resume_left := 0.0
var _tween: Tween


func _ready() -> void:
	randomize()
	player.set_skin(Save.skin)
	player.reset()
	ui.play_pressed.connect(start_run)
	ui.retry_pressed.connect(func(): Monetization.between_runs(start_run))
	ui.menu_pressed.connect(func():
		if state == S.OVER:
			Monetization.between_runs(go_menu)
		else:
			go_menu())
	ui.skins_pressed.connect(open_skins)
	ui.shop_pressed.connect(open_shop)
	ui.skin_selected.connect(_on_skin_selected)
	ui.continue_pressed.connect(_on_continue_pressed)
	ui.buy_pressed.connect(func(id): Monetization.buy(id))
	ui.restore_pressed.connect(func(): Monetization.restore())
	Monetization.rewarded_finished.connect(_on_rewarded)
	Monetization.purchase_result.connect(_on_purchase_result)
	Monetization.store_changed.connect(func(): if state == S.SHOP: ui.refresh_shop())
	get_viewport().size_changed.connect(_layout)
	_layout()
	_world_y = _world_y_target
	go_menu()
	Sfx.set_music(true)


func _layout() -> void:
	var sz := get_viewport_rect().size
	var cy := (sz.y + 8.0) * 0.5 if state in [S.MENU, S.SKINS, S.SHOP] else sz.y * 0.5 + 14.0
	_world_y_target = roundf(cy)


# ------------------------------------------------------------------ states

func go_menu() -> void:
	state = S.MENU
	Monetization.run_active = false
	_state_t = 0.0
	_clear_field()
	player.reset(player.angle)
	player.omega = 1.5
	player.happy = true
	planet.mood = Planet.Mood.SMILE
	_layout()
	ui.show_menu()


func open_skins() -> void:
	state = S.SKINS
	ui.show_skins()


func open_shop() -> void:
	state = S.SHOP
	ui.show_shop()


func _on_purchase_result(id: String, ok: bool, message: String) -> void:
	ui.toast(message, Color8(120, 255, 200) if ok else Color8(255, 150, 160))
	Sfx.play("unlock" if ok and id != "restore" else ("select" if ok else "deny"))
	if state == S.SHOP:
		ui.refresh_shop()


func _on_continue_pressed() -> void:
	if not Monetization.show_rewarded("continue"):
		ui.toast("NO AD AVAILABLE", Color8(255, 150, 160))


func _on_rewarded(placement: String, granted: bool) -> void:
	if placement == "continue" and state == S.OVER:
		if granted:
			revive()
		else:
			ui.toast("NO REWARD", Color8(255, 150, 160))
			ui.show_game_over(score, Save.best, false, [], false)


## Rewarded continue: same run, same score, field cleared and a short shield.
func revive() -> void:
	Save.undo_last_run()
	for h in hazards:
		h.queue_free()
	hazards.clear()
	continued = true
	state = S.PLAYING
	Monetization.run_active = true
	_grace = 0.3
	player.reset(_death_angle)
	player.happy = false
	shield_until = gt + MonetizationConfig.CONTINUE_SHIELD
	director.next_t = gt + 1.0
	planet.mood = Planet.Mood.SMILE
	ui.show_hud_continue(score, best_at_start)
	if record_announced:
		ui.announce_record()
	Sfx.play("go")


func _on_skin_selected(i: int) -> void:
	Save.skin = i
	Save.save_data()
	player.set_skin(i)


func start_run() -> void:
	_clear_field()
	state = S.PLAYING
	_state_t = 0.0
	_grace = 0.12
	gt = 0.0
	score = 0
	near_count = 0
	tapped_once = false
	record_announced = false
	continued = false
	shield_until = 0.0
	Monetization.run_active = true
	best_at_start = Save.best
	director.reset(randi(), Save.recent_average())
	player.reset(-PI * 0.5)
	player.happy = false
	player.omega = director.omega(0.0)
	planet.mood = Planet.Mood.SMILE
	bg.speed_mul = 1.0
	_layout()
	ui.show_hud(best_at_start, Save.games < 5)
	Sfx.play("go")


func _clear_field() -> void:
	for h in hazards:
		h.queue_free()
	for b in bubbles:
		b.queue_free()
	hazards.clear()
	bubbles.clear()
	fx.clear()


func _die() -> void:
	state = S.DYING
	Monetization.run_active = false
	_death_angle = player.angle
	_state_t = 0.0
	player.die()
	planet.mood = Planet.Mood.WORRY
	_shake = 5.0
	fx.burst(player.position, 22, [Color.WHITE, OrbitPlayer.SKIN_COLORS[player.skin], Color8(255, 236, 90)], 110.0, 0.6, 3.0, 120.0)
	fx.ring(player.position, Color.WHITE, 4.0, 26.0, 0.35)
	ui.flash()
	Sfx.play("hit")
	Input.vibrate_handheld(70)


func _game_over() -> void:
	state = S.OVER
	var res := Save.submit_run(score)
	Monetization.on_game_over()
	ui.show_game_over(score, Save.best, res["record"], res["unlocked"], Monetization.can_continue(score, continued))
	if res["record"] and score > 0:
		Sfx.play("record")
	elif not res["unlocked"].is_empty():
		Sfx.play("unlock")


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventScreenTouch and event.pressed:
		tap = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		tap = true
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_UP, KEY_ENTER, KEY_DOWN]:
		if state == S.OVER and _state_t > 0.3:
			start_run()
			return
		if state == S.MENU:
			start_run()
			return
		tap = true
	if not tap:
		return
	match state:
		S.PLAYING:
			if _grace <= 0.0:
				_flip()
		S.PAUSED:
			_resume_left = 1.2
			state = S.RESUMING
			ui.show_countdown(3)
			Sfx.play("tick")


func _flip() -> void:
	player.flip()
	if not tapped_once:
		tapped_once = true
		ui.hide_hint()
	var back := -Vector2(-sin(player.angle), cos(player.angle)) * player.dir
	fx.burst(player.position, 5, [Color.WHITE, OrbitPlayer.SKIN_COLORS[player.skin]], 40.0, 0.25, 2.0, 0.0, back, 0.7)
	Sfx.play("flip", randf_range(0.95, 1.08))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			S.PLAYING, S.RESUMING:
				_pause()
			S.PAUSED, S.OVER, S.SKINS, S.SHOP:
				go_menu()
			S.MENU:
				get_tree().quit()


func _pause() -> void:
	if state == S.PLAYING or state == S.RESUMING:
		state = S.PAUSED
		ui.show_pause()


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	_state_t += delta
	_grace -= delta
	_world_y = lerpf(_world_y, _world_y_target, minf(1.0, delta * 8.0))
	_shake = maxf(0.0, _shake - delta * 18.0)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	world.position = Vector2(roundf(get_viewport_rect().size.x * 0.5), roundf(_world_y)) + sh.round()
	match state:
		S.MENU, S.SKINS, S.SHOP:
			_menu_flip -= delta
			if _menu_flip <= 0.0:
				_menu_flip = randf_range(1.6, 3.6)
				player.flip()
			player.advance(delta)
		S.PLAYING:
			var left := delta
			while left > 0.0 and state == S.PLAYING:
				var step := minf(SUBSTEP, left)
				left -= step
				_sim(step)
		S.DYING:
			var vis_dt := 0.0 if _state_t < HIT_STOP else delta * 0.6
			gt += vis_dt
			_tick_objects()
			if _state_t >= DEATH_DELAY:
				_game_over()
		S.OVER:
			gt += delta
			_tick_objects()
		S.RESUMING:
			_resume_left -= delta
			ui.show_countdown(ceili(_resume_left / 0.4))
			if _resume_left <= 0.0:
				state = S.PLAYING
				ui.show_hud_resume()
	planet.look = Vector2(cos(player.angle), sin(player.angle))
	_cleanup()


func _sim(dt: float) -> void:
	gt += dt
	player.omega = director.omega(gt)
	player.advance(dt)
	var spawn := director.update(gt, player.angle, player.dir, hazards)
	for h in spawn["hazards"]:
		hazards.append(h)
		hazards_root.add_child(h)
		if h is Meteor:
			h.impacted.connect(_on_meteor_impact)
		if h.t_danger_start - gt < 2.0:
			Sfx.play("warn", 1.0, -6.0)
	for b in spawn["bubbles"]:
		bubbles.append(b)
		hazards_root.add_child(b)
	_tick_objects()
	# collisions + near misses
	var worry := false
	var shielded := gt < shield_until
	player.shield = maxf(0.0, shield_until - gt)
	for h in hazards:
		var c: float = h.clearance(gt, player.angle)
		if c < 0.0 and not shielded:
			_die()
			return
		if c < INF:
			h.min_clear = minf(h.min_clear, c)
			if c < 0.35:
				worry = true
		if not h.scored and gt > h.t_danger_end:
			h.scored = true
			_award(h)
	planet.mood = Planet.Mood.OH if worry else Planet.Mood.SMILE
	for b in bubbles:
		if b.t_end > gt and b.touches(player.angle):
			b.t_end = -1.0
			_add_score(2)
			var p := Orbit.on_ring(b.theta)
			fx.burst(p, 14, [Color.WHITE, Color8(120, 220, 255), Color8(255, 222, 70)], 70.0, 0.4, 2.0)
			fx.ring(p, Color8(180, 240, 255), 4.0, 18.0, 0.3)
			fx.text("POP! +2", p + Vector2(0, -12), Color8(255, 236, 90))
			Sfx.play("pop")
	bg.speed_mul = 1.0 + director.level(gt) * 1.5


func _award(h) -> void:
	var p := Orbit.on_ring(h.label_angle(gt), Orbit.R + 14.0)
	if h.min_clear < Orbit.NEAR:
		near_count += 1
		_add_score(2)
		fx.text("CLOSE! +2", player.position + Vector2(0, -14), Color8(120, 255, 200))
		fx.ring(player.position, Color.WHITE, 6.0, 20.0, 0.25)
		fx.burst(player.position, 8, [Color.WHITE, Color8(120, 255, 200)], 60.0, 0.3, 2.0)
		Sfx.play("close")
	else:
		_add_score(1)
		fx.text("+1", p, Color.WHITE)
		Sfx.play("score", 1.0, -4.0)


func _add_score(n: int) -> void:
	score += n
	ui.set_score(score)
	if not record_announced and best_at_start > 0 and score > best_at_start:
		record_announced = true
		ui.announce_record()
		fx.text("NEW BEST!", player.position + Vector2(0, -24), Color8(255, 128, 178), 1.0, 1.2)
		Sfx.play("record")


func _tick_objects() -> void:
	for h in hazards:
		h.tick(gt)
	for b in bubbles:
		b.tick(gt)


func _on_meteor_impact(_pos: Vector2) -> void:
	planet.bump()
	if state == S.PLAYING:
		_shake = maxf(_shake, 1.2)


func _cleanup() -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var h = hazards[i]
		if h.is_done(gt) and h.scored:
			hazards.remove_at(i)
			h.queue_free()
	for i in range(bubbles.size() - 1, -1, -1):
		var b = bubbles[i]
		if gt > b.t_end:
			bubbles.remove_at(i)
			b.queue_free()
