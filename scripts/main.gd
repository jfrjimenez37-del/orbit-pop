extends Node2D
## ORBIT POP — game state machine and core loop.

enum S { MENU, PLAYING, DYING, OVER, SKINS, PAUSED, RESUMING, SHOP, RANKING, ABILITIES }

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
var bubbles_popped := 0
var picked_coins := 0         # coins collected on the orbits this run
var _hist: Array = []         # [time, angle, dir, orbit, omega] every ~20 ms (death report)
var coins_awarded := 0        # coins already paid out for this run (continue-safe)
var run_coins := 0            # coins shown on game over (doubled by a rewarded ad)
var coins_doubled := false
var shield_hits := 0          # SHIELD ability: hits left this run
var shield_recharge_at := -1.0
var teleports := 0            # TELEPORT ability charges left in this run
var slowmo_charges := 0       # SLOW-MO ability charges left in this run
var slowmo_left := 0.0        # real seconds of slow motion still running
var second_life := false      # SECOND LIFE ability unused in this run
var start_score := 0          # HEADSTART: points granted by the start world
var xp_awarded := 0           # XP already paid out for this run (continue-safe)
var stage := 0                # current world (Stages index)
var world_no := 1             # world number shown to the player
var _stage_pending := -1
var _morph_t := -1.0
const MORPH_TIME := 1.3
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
	apply_style()
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
	ui.double_pressed.connect(func():
		if not Monetization.show_rewarded("double_coins"):
			ui.toast(L.t("NO_AD"), Color8(255, 150, 160)))
	ui.teleport_pressed.connect(use_teleport)
	ui.slowmo_pressed.connect(use_slowmo)
	ui.share_pressed.connect(_share)
	ui.ability_video_pressed.connect(func():
		if not Monetization.show_rewarded("ability_video"):
			ui.toast(L.t("NO_AD"), Color8(255, 150, 160)))
	ui.ranking_pressed.connect(open_ranking)
	ui.abilities_pressed.connect(open_abilities)
	ui.pause_pressed.connect(_pause)
	ui.resume_pressed.connect(_resume)
	ui.quit_pressed.connect(_quit_run)
	ui.language_changed.connect(func(): get_tree().reload_current_scene())
	ui.style_changed.connect(apply_style)
	ui.daily_claim.connect(_on_daily_claim)
	ui.free_coins_pressed.connect(func():
		if Save.free_ads_left() > 0 and not Monetization.show_rewarded("free_coins"):
			ui.toast(L.t("NO_AD"), Color8(255, 150, 160)))
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
	var cy := (sz.y + 8.0) * 0.5 if state in [S.MENU, S.SKINS, S.SHOP, S.RANKING, S.ABILITIES] else sz.y * 0.5 + 14.0
	_world_y_target = roundf(cy)


# ------------------------------------------------------------------ states

func go_menu() -> void:
	state = S.MENU
	Monetization.run_active = false
	Monetization.hide_banner()
	stage = 0
	world_no = 1
	_stage_pending = -1
	_morph_t = -1.0
	Orbit.reset()
	apply_style()
	_state_t = 0.0
	_clear_field()
	player.reset(player.angle)
	player.omega = 1.5
	player.happy = true
	planet.mood = Planet.Mood.SMILE
	_layout()
	bg.reset_climb()
	ui.show_menu()
	if Save.daily_available():
		ui.show_daily()
	elif Monetization.should_offer_starter():
		Save.starter_seen = true
		Save.save_data()
		ui.show_starter()


func open_skins() -> void:
	state = S.SKINS
	ui.show_skins()
	_menu_banner(ui.STYLE_H)


func open_abilities() -> void:
	state = S.ABILITIES
	ui.show_abilities()
	_menu_banner(ui.ABILITIES_H)


## Banner on a menu screen, only when the screen has room for it below its box.
func _menu_banner(box_h: int) -> void:
	if ui.banner_room(box_h):
		Monetization.show_banner()
	else:
		Monetization.hide_banner()


func open_ranking() -> void:
	state = S.RANKING
	ui.show_ranking()
	Monetization.show_banner()


func _resume() -> void:
	if state != S.PAUSED:
		return
	_resume_left = 1.2
	state = S.RESUMING
	ui.show_countdown(3)
	Sfx.play("tick")


## Leaving a paused run from the pause menu: it still counts (stats, coins, missions).
func _quit_run() -> void:
	if state != S.PAUSED:
		return
	Save.submit_run(score)
	Monetization.on_game_over()
	Progress.run_finished(score, world_no, gt)
	var earned := _run_coins()
	Save.add_coins(earned - coins_awarded)
	coins_awarded = earned
	_award_xp()
	Monetization.between_runs(go_menu)


func _share() -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
	if not Progress.share(score, img):
		ui.toast(L.t("COPIED"), Color8(120, 255, 200))


func open_shop(tab := "packs") -> void:
	state = S.SHOP
	ui.show_shop(tab)
	Monetization.show_banner()


func apply_style() -> void:
	player.set_skin(Save.skin)
	player.trail_style = Save.trail
	_apply_world(stage, false)


func _apply_world(i: int, animated: bool) -> void:
	var w := Stages.world(i)
	bg.apply_world(w, animated)
	planet.set_world(w.get("planets", [w["planet"], w.get("planet2", w["planet"])]))


func _on_daily_claim(doubled: bool) -> void:
	if doubled:
		if not Monetization.show_rewarded("daily_double"):
			ui.toast(L.t("NO_AD"), Color8(255, 150, 160))
		return
	_give_daily(1)


func _give_daily(mult: int) -> void:
	var g := Save.claim_daily(mult)
	if g.is_empty():
		return
	ui.toast(L.t("PLUS_COINS", int(g["coins"]) * mult), Color8(255, 222, 70))
	Sfx.play("unlock")
	ui.hide_popup()
	ui.refresh_menu()


const _STORE_MSG := {"TEST PURCHASE": "TEST_PURCHASE", "THANK YOU!": "THANKS", "CANCELLED": "CANCELLED", "PENDING": "PENDING",
	"FAILED": "FAILED", "RESTORED": "RESTORED", "OWNED": "OWNED", "STORE OFFLINE": "STORE_OFFLINE", "STORE ERROR": "STORE_ERROR"}


func _on_purchase_result(id: String, ok: bool, message: String) -> void:
	var text := L.t(_STORE_MSG[message]) if _STORE_MSG.has(message) else message
	if MonetizationConfig.CONSUMABLES.has(id) and ok:
		text = L.t("PLUS_COINS", MonetizationConfig.CONSUMABLES[id])
	ui.toast(text, Color8(120, 255, 200) if ok else Color8(255, 150, 160))
	Sfx.play("unlock" if ok and id != "restore" else ("select" if ok else "deny"))
	if state == S.SHOP:
		ui.refresh_shop()
	elif state == S.MENU:
		ui.refresh_menu()


func _on_continue_pressed() -> void:
	if Monetization.continue_is_free():
		Save.free_continue_day = Save.day_number()
		Save.save_data()
		revive()
		return
	if not Monetization.show_rewarded("continue"):
		ui.toast(L.t("NO_AD"), Color8(255, 150, 160))


func _on_rewarded(placement: String, granted: bool) -> void:
	match placement:
		"double_coins":
			if granted and not coins_doubled:
				coins_doubled = true
				Save.add_coins(run_coins)
				run_coins *= 2
				ui.set_over_coins(run_coins, false)
				Sfx.play("unlock")
			return
		"daily_double":
			if granted:
				_give_daily(2)
			return
		"ability_video":
			if granted:
				var up: String = Save.video_ad_watched()
				if up != "":
					ui.toast(L.t("UPGRADED", L.t("AB_" + up.to_upper())), Color8(120, 255, 200))
					Sfx.play("unlock")
				ui.refresh_abilities()
			return
		"free_coins":
			if granted:
				Save.note_free_ad()
				Save.add_coins(MonetizationConfig.FREE_COIN_AD_REWARD)
				ui.toast(L.t("PLUS_COINS", MonetizationConfig.FREE_COIN_AD_REWARD), Color8(255, 222, 70))
				Sfx.play("unlock")
				ui.refresh_shop()
			return
	if placement == "continue" and state == S.OVER:
		if granted:
			revive()
		else:
			ui.toast(L.t("NO_REWARD"), Color8(255, 150, 160))
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
	var k := player.orbit
	player.reset(_death_angle)
	player.orbit = mini(k, Orbit.count() - 1)
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
	bubbles_popped = 0
	picked_coins = 0
	_hist.clear()
	coins_awarded = 0
	run_coins = 0
	coins_doubled = false
	Monetization.run_active = true
	Monetization.hide_banner()
	shield_hits = Upgrades.shield_hits(Save.ability("shield"))
	shield_recharge_at = -1.0
	player.shield_boost = shield_hits > 0
	player.shield_layers = shield_hits
	teleports = Save.ability("teleport")
	slowmo_charges = Save.ability("slowmo")
	slowmo_left = 0.0
	player.slowmo = false
	second_life = Save.ability("secondlife") > 0
	xp_awarded = 0
	start_score = 0
	stage = 0
	world_no = 1
	_stage_pending = -1
	_morph_t = -1.0
	Orbit.set_time(0.0)
	Orbit.reset()
	_apply_world(0, false)
	Progress.run_started()
	best_at_start = Save.best
	director.reset(randi(), Save.recent_average())
	director.bubble_rate = 1.0
	# HEADSTART: begin in a world already passed, with that world's points
	var sw := Save.chosen_start_world()
	if sw > 1:
		stage = sw - 1
		world_no = sw
		start_score = int(Stages.LIST[stage]["score"])
		score = start_score
		Orbit.set_shape(Stages.LIST[stage]["orbits"], true, Stages.motion(stage))
		_apply_world(stage, false)
		director.stage = stage
	player.reset(-PI * 0.5)
	player.happy = false
	player.omega = director.omega(0.0)
	planet.mood = Planet.Mood.SMILE
	bg.speed_mul = 1.0
	_layout()
	ui.show_hud(best_at_start, Save.games < 5)
	ui.set_score(score)
	ui.set_world_progress(score, best_at_start)
	ui.set_teleport(teleports)
	ui.set_slowmo(slowmo_charges)
	ui.set_run_coins(0)
	ui.set_altitude(score)
	bg.reset_climb()
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
	_death_report()
	if second_life:
		_use_second_life()
		return
	state = S.DYING
	Monetization.run_active = false
	_death_angle = player.angle
	_state_t = 0.0
	player.die()
	planet.mood = Planet.Mood.WORRY
	_shake = 5.0
	fx.burst(player.position, 22, [Color.WHITE, player.color(), Color8(255, 236, 90)], 110.0, 0.6, 3.0, 120.0)
	fx.ring(player.position, Color.WHITE, 4.0, 26.0, 0.35)
	ui.flash()
	Sfx.play("hit")
	Save.vibrate(70)


func _game_over() -> void:
	state = S.OVER
	var res := Save.submit_run(score)
	Monetization.on_game_over(res["record"] and score > 0)
	Progress.run_finished(score, world_no, gt)
	var earned := _run_coins()
	Save.add_coins(earned - coins_awarded)
	run_coins = earned - coins_awarded
	coins_awarded = earned
	var xp_gain := _award_xp()
	ui.show_game_over(score, Save.best, res["record"], res["unlocked"], Monetization.can_continue(score, continued),
		Monetization.continue_is_free())
	ui.set_over_coins(run_coins, run_coins > 0 and not coins_doubled and Monetization.rewarded_ready())
	ui.set_over_xp(xp_gain)
	for msg in Progress.take_pending():
		ui.toast(msg, Color8(255, 236, 140))
	if res["record"] and score > 0:
		Sfx.play("record")
	elif not res["unlocked"].is_empty():
		Sfx.play("unlock")
	# a fresh record is the happiest moment to ask for a rating (Google shows its own sheet)
	Progress.reviewer.maybe_ask(Save, res["record"], score)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var tap := false
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and state == S.PLAYING \
			and ui.blocks_tap(event.position):
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and state == S.PLAYING:
		use_teleport()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and state == S.PLAYING:
		use_slowmo()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
		if state == S.PLAYING:
			_pause()
		elif state == S.PAUSED:
			_resume()
		return
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
			pass  # use the CONTINUE / MENU buttons


func _flip() -> void:
	var switched := player.tap()
	if not tapped_once:
		tapped_once = true
		ui.hide_hint()
	if switched:
		fx.ring(player.position, Color8(255, 236, 90), 4.0, 16.0, 0.25)
		fx.text(L.t("SWITCH_FX"), player.position + Vector2(0, -14), Color8(255, 236, 90))
		Sfx.play("close", 1.3, -4.0)
		Progress.event("switch")
		return
	Progress.event("flip")
	var back := -Vector2(-sin(player.angle), cos(player.angle)) * player.dir
	fx.burst(player.position, 5, [Color.WHITE, player.color()], 40.0, 0.25, 2.0, 0.0, back, 0.7)
	Sfx.play("flip", randf_range(0.95, 1.08))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match state:
			S.PLAYING, S.RESUMING:
				_pause()
			S.PAUSED, S.OVER, S.SKINS, S.SHOP, S.RANKING, S.ABILITIES:
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
	world.position = Vector2(roundf(get_viewport_rect().size.x * 0.5), roundf(_world_y + _sway())) + sh.round()
	_update_ascent(delta)
	match state:
		S.MENU, S.SKINS, S.SHOP, S.RANKING, S.ABILITIES:
			_menu_flip -= delta
			if _menu_flip <= 0.0:
				_menu_flip = randf_range(1.6, 3.6)
				player.flip()
			player.advance(delta)
		S.PLAYING:
			var left := delta
			if slowmo_left > 0.0:
				slowmo_left -= delta
				left *= Upgrades.SLOWMO_SCALE
				if slowmo_left <= 0.0:
					player.slowmo = false
					bg.speed_mul = 1.0
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
	planet.player_angle = player.angle
	planet.player_orbit = player.orbit
	planet.player_pos = player.position
	_cleanup()


## Visual only: the whole planetary system gently rises and falls in later worlds.
func _sway() -> float:
	if state != S.PLAYING or Save.reduce_motion or world_no < 6:
		return 0.0
	var amp := 2.0 if world_no < 11 else 4.0
	return amp * sin(gt * 1.1)


## Scenery scrolls down while playing (we climb), faster in later worlds; a short drop on
## each world change. Off with "Reduce motion".
func _update_ascent(delta: float) -> void:
	var target := 0.0
	if state == S.PLAYING and not Save.reduce_motion:
		target = (5.0 + 1.6 * mini(world_no, 16)) * (1.0 + director.level(gt) * 0.6)
		if _morph_t >= 0.0:
			target = -target * 0.7
	bg.vspeed = lerpf(bg.vspeed, target, minf(1.0, delta * 2.5))


func _sim(dt: float) -> void:
	gt += dt
	Orbit.set_time(gt)
	player.omega = director.omega(gt)
	player.advance(dt)
	# short history of the player's state for the death report
	if _hist.is_empty() or gt - float(_hist[-1][0]) >= 0.02:
		_hist.append([gt, player.angle, player.dir, player.orbit, player.omega])
		if _hist.size() > 150:
			_hist.pop_front()
	_update_world(dt)
	var spawn := director.update(gt, player.angle, player.dir, hazards, player.orbit)
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
	if shield_recharge_at > 0.0 and gt >= shield_recharge_at:
		shield_recharge_at = -1.0
		shield_hits = 1
		player.shield_boost = true
		player.shield_layers = 1
		fx.text(L.t("SHIELD_UP"), player.position + Vector2(0, -16), Color8(140, 230, 255))
		Sfx.play("unlock", 1.3, -6.0)
	var shielded := gt < shield_until
	player.shield = maxf(0.0, shield_until - gt)
	for h in hazards:
		var c: float = h.clearance(gt, player.angle, player.orbit)
		if c < 0.0 and not shielded:
			if shield_hits > 0:
				_break_shield()
				shielded = true
				continue
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
	# pickups: touch them, or with MAGNET they fly to the player from any orbit
	var reach: float = Upgrades.MAGNET_RADIUS[clampi(Save.ability("magnet"), 0, Upgrades.MAGNET_RADIUS.size() - 1)]
	var me := Orbit.pos(player.orbit, player.angle)
	for b in bubbles:
		if b.t_end <= gt:
			continue
		var take := false
		if b.flying or (reach > 0.0 and b.ready_to_take() and b.world_pos().distance_to(me) < reach):
			take = b.fly_to(me, dt)
		else:
			take = b.touches(player.angle, player.orbit)
		if take:
			_collect(b)
	bg.speed_mul = 1.0 + director.level(gt) * 1.5


## Death report (Settings > tap the version 5 times): from the moment the newest hazard could
## be seen (spawn + reaction time), was there still a way out? "IMPOSSIBLE" means a bug to fix.
func _death_report() -> void:
	if hazards.is_empty() or _hist.is_empty():
		return
	var newest := -INF
	for h in hazards:
		newest = maxf(newest, h.t_spawn)
	var seen := newest + Survival.HUMAN_REACT
	var st: Array = _hist[-1]
	for e in _hist:
		if float(e[0]) >= seen:
			st = e
			break
	var keep := Orbit.time
	var t0 := float(st[0])
	if Orbit.moving():
		Orbit.set_time(t0)
	var ok := t0 >= gt or Survival.can_survive(hazards, t0, float(st[1]), int(st[2]), float(st[4]), true, int(st[3]))
	if Orbit.moving():
		Orbit.set_time(keep)
	var names: Array = hazards.map(func(h): return h.get_script().get_global_name())
	Diag.log("death w%d %dpts %s [%s]" % [world_no, score, "avoidable" if ok else "IMPOSSIBLE", ",".join(names)])


func _collect(b: Bubble) -> void:
	var p := b.world_pos()
	b.t_end = -1.0
	b.visible = false
	if b.is_coin():
		picked_coins += b.value
		Progress.event("coin", b.value)
		ui.set_run_coins(picked_coins)
		fx.burst(p, 6 if b.value == 1 else 14, [Color8(255, 222, 70), Color.WHITE], 50.0, 0.3, 1.5)
		if b.value > 1:
			fx.ring(p, Color8(255, 220, 90), 4.0, 16.0, 0.3)
			fx.text("+%d" % b.value, p + Vector2(0, -10), Color8(255, 222, 70))
		Sfx.play("coin", 1.0 + minf(0.3, 0.05 * (picked_coins % 7)), -3.0)
		return
	_add_score(2)
	bubbles_popped += 1
	Progress.event("bubble")
	fx.burst(p, 14, [Color.WHITE, Color8(120, 220, 255), Color8(255, 222, 70)], 70.0, 0.4, 2.0)
	fx.ring(p, Color8(180, 240, 255), 4.0, 18.0, 0.3)
	fx.text(L.t("POP_FX"), p + Vector2(0, -12), Color8(255, 236, 90))
	Sfx.play("pop")


func use_teleport() -> void:
	if teleports <= 0 or state != S.PLAYING:
		return
	teleports -= 1
	var from := player.position
	player.teleport()
	shield_until = maxf(shield_until, gt + 0.5)
	fx.burst(from, 12, [Color8(200, 140, 255), Color.WHITE], 60.0, 0.35, 2.0)
	fx.ring(player.position, Color8(200, 140, 255), 14.0, 3.0, 0.3)
	fx.text(L.t("WARP_FX"), player.position + Vector2(0, -14), Color8(220, 170, 255))
	Sfx.play("pop", 1.4)
	ui.set_teleport(teleports)
	Progress.event("teleport")


func use_slowmo() -> void:
	if slowmo_charges <= 0 or state != S.PLAYING or slowmo_left > 0.0:
		return
	slowmo_charges -= 1
	slowmo_left = Upgrades.SLOWMO_TIME
	player.slowmo = true
	fx.ring(player.position, Color8(150, 190, 255), 6.0, 40.0, 0.4)
	fx.text(L.t("SLOWMO_FX"), player.position + Vector2(0, -14), Color8(170, 200, 255))
	Sfx.play("pop", 0.7)
	ui.set_slowmo(slowmo_charges)


## SECOND LIFE ability: a fatal hit clears the field and the run goes on (once per run).
func _use_second_life() -> void:
	second_life = false
	for h in hazards:
		h.queue_free()
	hazards.clear()
	shield_until = gt + 2.0
	director.next_t = gt + 1.0
	_shake = 4.0
	ui.flash()
	fx.burst(player.position, 20, [Color8(255, 110, 150), Color.WHITE], 100.0, 0.5, 2.5)
	fx.text(L.t("SECOND_LIFE_FX"), player.position + Vector2(0, -18), Color8(255, 130, 170), 1.0, 1.2)
	Sfx.play("record")
	Save.vibrate(50)


## Coins earned this run (HEADSTART points are not paid), with the COINS+ ability.
func _run_coins() -> int:
	var base := floorf((score - start_score) * MonetizationConfig.COINS_PER_SCORE) + bubbles_popped * MonetizationConfig.COINS_PER_BUBBLE \
		+ picked_coins
	var x2 := 2.0 if Save.owns("coins_x2") else 1.0   # COINS x2 FOREVER purchase
	return int(floor(base * Upgrades.coin_mult(Save.ability("coins")) * x2))


## Pays the run's XP not given yet (a continue pays only the difference). Returns XP added now.
func _award_xp() -> int:
	var total_xp := Upgrades.run_xp(maxi(0, score - start_score), Save.games == 1)
	var gain := total_xp - xp_awarded
	xp_awarded = total_xp
	Progress.award_xp(gain)
	return gain


func _break_shield() -> void:
	shield_hits -= 1
	player.shield_layers = shield_hits
	player.shield_boost = shield_hits > 0
	if shield_hits <= 0 and Save.ability("shield") >= 2:
		shield_recharge_at = gt + Upgrades.SHIELD_RECHARGE
	shield_until = gt + 1.0
	_shake = 3.0
	fx.burst(player.position, 16, [Color8(140, 230, 255), Color.WHITE], 90.0, 0.4, 2.0)
	fx.ring(player.position, Color8(140, 230, 255), 8.0, 26.0, 0.3)
	fx.text(L.t("SHIELD_FX"), player.position + Vector2(0, -16), Color8(140, 230, 255))
	Sfx.play("pop", 0.8)
	Save.vibrate(30)


func _award(h) -> void:
	var la: float = h.label_angle(gt)
	var p := Orbit.on_ring(la, Orbit.radius(0, la) + 14.0)
	if h.min_clear < Orbit.NEAR:
		near_count += 1
		Progress.event("near")
		_add_score(2)
		fx.text(L.t("CLOSE_FX"), player.position + Vector2(0, -14), Color8(120, 255, 200))
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
	ui.set_altitude(score)
	ui.set_world_progress(score, best_at_start)
	Progress.event("score_now", score)
	var target := Stages.number_for_score(score)
	if target > world_no and _stage_pending < 0:
		_stage_pending = Stages.index_for_score(score)
		director.hold = true
	if not record_announced and best_at_start > 0 and score > best_at_start:
		record_announced = true
		ui.announce_record()
		fx.text(L.t("NEW_BEST"), player.position + Vector2(0, -24), Color8(255, 128, 178), 1.0, 1.2)
		Sfx.play("record")


## World change: wait until the field is clear, then morph orbit + sky + planet.
func _update_world(dt: float) -> void:
	if _stage_pending >= 0 and _morph_t < 0.0 and hazards.is_empty():
		_morph_t = 0.0
		for b in bubbles:
			b.queue_free()
		bubbles.clear()
		Orbit.set_shape(Stages.LIST[_stage_pending]["orbits"], false, Stages.motion(_stage_pending))
		_apply_world(_stage_pending, true)
		planet.bump()
		world_no = Stages.number_for_score(score)
		var w := Stages.world(_stage_pending)
		var orbits: Array = Stages.LIST[_stage_pending]["orbits"]
		var tip := ""
		if not Stages.motion(_stage_pending).is_empty():
			tip = L.t("MOVE_TIP")
		elif orbits.size() >= 2:
			tip = L.t("JUMP_TIP") if orbits[1].has("center") else L.t("CROSS_TIP")
		ui.world_banner(world_no, L.t("WORLD_" + str(w["id"]).to_upper()), tip)
		Sfx.play("unlock")
		Progress.event("world", world_no)
	if _morph_t >= 0.0:
		_morph_t += dt
		var k := clampf(_morph_t / MORPH_TIME, 0.0, 1.0)
		Orbit.set_blend(k * k * (3.0 - 2.0 * k))
		if k >= 1.0:
			_morph_t = -1.0
			stage = _stage_pending
			_stage_pending = -1
			if player.orbit >= Orbit.count():
				player.orbit = 0
			director.stage = stage
			director.hold = false
			director.next_t = gt + 0.6
			director.next_bubble = gt + 2.0


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
