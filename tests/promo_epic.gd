extends SceneTree
## Epic promo video (portrait 1080x1920, 60 fps, ~33 s), cut to the beat of "Spin Bonk Repeat"
## (120.2 BPM, first beat at 0.110 s): a close-up hook, the drop, a slow-motion near miss, a world
## montage, the climb to deep space, a duel, skins, the finale and the end card.
## Captions are PNGs made by tools/gen_video_caps.py. Render (see store/promo_video.md):
##   python3 tools/gen_video_caps.py /tmp/epic/caps
##   (override.cfg for 1080x1920, as for promo_videos.gd)
##   xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/epic/f/f.png \
##       --fixed-fps 60 --script tests/promo_epic.gd -- /tmp/epic/caps
## Every shot is set up and pre-played off camera (the game runs inside one frame), so each cut
## lands on a busy field; the bot dodges like the test bot and jumps planet at crossings.

const FPS := 60.0
const DT := 1.0 / 60.0
const B0 := 0.110
const BEAT := 60.0 / 120.2
const END_T := 33.0
const DUEL_TARGET := 131

var main: Node
var sv: Node
var caps_dir := "/tmp/epic/caps/"
var frame := 0
var vw := 180.0
var vh := 320.0

# camera
var zoom_base := 1.0
var zoom_to := 1.0
var zoom_from := 1.0
var zoom_t0 := 0.0
var zoom_dur := 0.0
var follow := false
var punch_t := -9.0
var punch_amp := 0.0
var shake_t := -9.0
var shake_amp := 0.0
var cam_focus := Vector2.ZERO
# overlays
var layer: CanvasLayer
var flash: ColorRect
var dim: ColorRect
var flash_t := -9.0
var flash_amp := 0.0
var logo: Sprite2D
var logo_t0 := -1.0
var caps: Array = []          # [sprite, t0, t1, y, size]
var events: Array = []        # [time, callable]
var ev_i := 0
var shot := ""
var gameplay := false
var banners := false
var bot_jumps := true
var _last_switch := -9.0
var _bot_gt := -9.0
var _near_seen := 0
var slowmo := Vector2(-1, -1) # real-time window of the slow motion


func bt(n: float) -> float:
	return B0 + n * BEAT


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		caps_dir = args[0].trim_suffix("/") + "/"
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await process_frame
	sv = get_root().get_node("Save")
	sv.path = "user://promo_epic.cfg"
	sv.reset_all()
	sv.best = 412; sv.games = 60; sv.coins = 2350; sv.level = 18; sv.sessions = 9
	sv.daily_last = sv._day_string()
	sv.starter_seen = true
	sv.music = false
	sv.skin = Catalog.find("skins", "cosmo")
	sv.trail = "galaxy"
	for a in get_root().get_node("Progress").ACHIEVEMENTS:
		sv.achievements.append(a["id"])
	get_root().get_node("L").set_lang("en")
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	get_root().get_node("Sfx").set_music(false)
	var r: Rect2 = main.get_viewport().get_visible_rect()
	vw = r.size.x
	vh = r.size.y
	layer = CanvasLayer.new()
	layer.layer = 100
	get_root().add_child(layer)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.15, 0.0)
	dim.size = Vector2(vw, vh)
	layer.add_child(dim)
	flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.size = Vector2(vw, vh)
	layer.add_child(flash)
	logo = Sprite2D.new()
	logo.texture = load("res://assets/sprites/logo.png")
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.visible = false
	layer.add_child(logo)
	_build_timeline()


# ------------------------------------------------------------------ timeline

func _build_timeline() -> void:
	var low := vh - 62.0
	var mid := vh * 0.5 + 70.0
	# hook: close-up on the player, two words
	_at(0.0, func(): _shot_play("hook", 12, 22.0, 6.0, 11); _cam(2.1, true); _zoom_to(2.4, 2.11))
	_cap_at(0, 2, "one_tap", low)
	_cap_at(2, 4, "to_flip", low)
	for n in [0, 1, 2, 3]:
		_at(bt(n), func(): _punch(0.06))
	# the drop
	_at(bt(4), func(): _shot_play("drop", 13, 26.0, 6.0, 21); _cam(1.0, false); _flash(1.0); _punch(0.3); _shake(3.0))
	var words := ["flip", "dodge", "jump", "repeat"]
	for i in 4:
		_cap_at(4 + i, 5 + i, words[i], mid)
		if i > 0:
			_at(bt(4 + i), func(): _punch(0.12); _shake(2.0))
	# slow motion near miss (the music breaks)
	_at(bt(8), func(): _shot_near(); _cam(1.0, true); _zoom_to(2.6, 0.5); _flash(0.6))
	_cap_at(9, 11.8, "too_close", low)
	# montage: one world per bar
	var montage := [[12, 5, "jump_planets", 31], [16, 7, "dodge_all", 41], [20, 10, "four", 51], [24, 14, "move", 61]]
	for m in montage:
		_at(bt(m[0]), func(): _shot_play("w%d" % m[1], m[1], 22.0, 5.5, m[3]); _cam(1.0, false); _flash(0.8); _punch(0.25); _shake(2.5))
		_cap_at(m[0], m[0] + 4, m[2], low)
		for k in [1, 2, 3]:
			_at(bt(m[0] + k), func(): _punch(0.07))
	# the climb: a world every two beats, with the world banner
	var climb := [[28, 0], [30, 1], [32, 3], [34, 4], [36, 6], [38, 9], [40, 11], [42, 15]]
	for c in climb:
		_at(bt(c[0]), func(): _shot_play("c%d" % c[1], c[1], 20.0, 5.0, 70 + c[1], true); _cam(1.0, false); _flash(0.5); _punch(0.18))
		_at(bt(c[0] + 1), func(): _punch(0.07))
	_cap_at(28, 30, "worlds", low)
	_cap_at(30, 34, "clouds", low)
	_cap_at(34, 38, "space", low)
	_cap_at(38, 44, "how_high", low)
	# duel
	_at(bt(44), func(): _shot_dare(); _cam(1.0, false); _flash(0.8); _punch(0.2))
	_cap_at(44, 48, "dare", 56.0)
	_at(bt(48), func(): _shot_duel(); _cam(1.0, false); _flash(0.6); _punch(0.2))
	_cap_at(48, 50, "beat", low)
	_at(bt(50), func(): _duel_win(); _flash(0.9); _punch(0.3); _shake(3.0))
	_cap_at(50, 52, "win", mid)
	# skins and trails, one per beat, close on the player
	_at(bt(52), func(): _shot_play("skins", 13, 18.0, 5.0, 91); _cam(1.0, true); _zoom_to(2.0, 0.25); _flash(0.7))
	var looks := [["nova", "rainbow"], ["magma", "fire"], ["prism", "ice"], ["ninja", "galaxy"]]
	for i in 4:
		_at(bt(52 + i), func(): _look(looks[i][0], looks[i][1]); _punch(0.12))
	_cap_at(52, 54, "skins", low)
	_cap_at(54, 56, "trails", low)
	# finale: the hardest world, hits on every beat
	_at(bt(56), func(): _shot_play("finale", 15, 34.0, 6.0, 101); _cam(1.0, false); _flash(1.0); _punch(0.3); _shake(3.5))
	_cap_at(56, 60, "survive", low)
	for k in [1, 2, 3, 4, 5, 6, 7]:
		_at(bt(56 + k), func(): _punch(0.1 + 0.02 * k); _shake(1.0 + 0.3 * k))
	# end card
	_at(bt(60), func(): _shot_end(); _flash(1.0); _punch(0.2))
	_cap_at(61, 99, "free", vh - 92.0)
	_cap_at(62, 99, "gplay", vh - 58.0)
	events.sort_custom(func(a, b): return a[0] < b[0])


func _at(t: float, f: Callable) -> void:
	events.append([t, f])


func _cap_at(n0: float, n1: float, id: String, y: float) -> void:
	var img := Image.load_from_file(caps_dir + id + ".png")
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.visible = false
	layer.add_child(sp)
	caps.append([sp, bt(n0) if n0 > 0 else 0.0, bt(n1), y])


# ------------------------------------------------------------------ shots

func _reset_run(sd: int) -> void:
	seed(sd)
	main.duel = {}
	main.state = main.S.MENU
	main.start_run()
	main.ui.hide_hint()


func _place(si: int, offset: float) -> void:
	main._clear_field()
	main.stage = si
	main.world_no = Stages.number_for_score(int(Stages.LIST[si]["score"]))
	main.score = int(Stages.LIST[si]["score"]) + 2
	Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
	main._apply_world(si, false)
	main.director.stage = si
	main.director.world = main.world_no
	main.director.offset = offset
	main._layer = Stages.layer(main.score)
	main.ui.set_score(main.score)
	main.ui.set_altitude(main.score)


## Plays the game off camera for `secs` (inside this frame). Returns false if the bot died.
func _preplay(steps: int) -> bool:
	for i in steps:
		if main.state != main.S.PLAYING:
			return false
		main._grace = 0.0
		if i % 2 == 0:
			_bot()
		main._process(DT)
	return main.state == main.S.PLAYING


## After the off-camera play: no sounds or effects left over from it.
func _quiet() -> void:
	for p in get_root().get_node("Sfx")._players:
		p.stop()
	main.fx.clear()
	main.ui._banner.visible = false
	main._shake = 0.0
	_bot_gt = main.gt - 1.0 / 30.0


func _shot_play(name: String, si: int, offset: float, pre: float, sd: int, banner := false) -> void:
	shot = name
	gameplay = true
	banners = banner
	bot_jumps = true
	main.ui.visible = true
	logo.visible = false
	for k in 12:
		_reset_run(sd + k * 1000)
		_place(si, offset)
		if _preplay(int(pre * FPS) & ~1):
			break
		print("shot %s: bot died in the warm-up (seed %d), next seed" % [name, sd + k * 1000])
	_quiet()
	if banner:
		var w := Stages.world(si)
		main.ui.world_banner(main.world_no, get_root().get_node("L").t("WORLD_" + str(w["id"]).to_upper()), "", "")


## The slow-motion shot: finds a near miss off camera, then replays the same run (same seed) up
## to just before it, so the closest moment lands in the middle of the slow motion.
func _shot_near() -> void:
	shot = "near"
	gameplay = true
	banners = false
	bot_jumps = false
	slowmo = Vector2(bt(8), bt(12))
	var lead := 0.0
	var t := bt(8)
	while t < bt(9.85):
		lead += DT * _time_scale(t)
		t += DT
	for sd in range(200, 320):
		_reset_run(sd)
		_place(8, 28.0)
		if not _preplay(300):
			continue
		var best := INF
		var best_step := -1
		for i in range(300, 600):
			if main.state != main.S.PLAYING:
				best_step = -1
				break
			main._grace = 0.0
			if i % 2 == 0:
				_bot()
			main._process(DT)
			for h in main.hazards:
				var c: float = h.clearance(main.gt, main.player.angle, main.player.orbit)
				if c >= 0.0 and c < best:
					best = c
					best_step = i
		if best_step < 330 or best > Orbit.NEAR:
			continue
		var start := (best_step - int(lead * FPS)) & ~1
		_reset_run(sd)
		_place(8, 28.0)
		if _preplay(start):
			print("near miss: seed %d, clearance %.3f, at step %d (lead %.3f s)" % [sd, best, best_step, lead])
			break
	_quiet()


func _shot_dare() -> void:
	shot = "dare"
	gameplay = false
	main.go_menu()
	main.ui.hide_popup()
	main.ui.show_duel_accept(Duel.decode(Duel.encode(4242, DUEL_TARGET, "MAYA")))


func _shot_duel() -> void:
	shot = "duel"
	gameplay = true
	banners = false
	bot_jumps = true
	main.ui.hide_popup()
	for k in 12:
		seed(500 + k)
		main.state = main.S.MENU
		main.start_duel(Duel.decode(Duel.encode(4242, DUEL_TARGET, "MAYA")))
		main.ui.hide_hint()
		_place(5, 20.0)
		if _preplay(300):
			break
	main.score = DUEL_TARGET - 5
	main.ui.set_score(main.score)
	main.ui.set_duel_target("MAYA", DUEL_TARGET)
	_quiet()


func _duel_win() -> void:
	if main.state != main.S.PLAYING:
		return
	main.score = maxi(main.score, DUEL_TARGET + 2)
	main.ui.set_score(main.score)
	main.duel_lead = true
	main.ui.announce_duel_lead()
	get_root().get_node("Sfx").play("unlock")


func _look(skin: String, trail: String) -> void:
	sv.skin = Catalog.find("skins", skin)
	sv.trail = trail
	main.apply_style()
	main.fx.burst(main.player.position, 14, [Color.WHITE, Color8(255, 214, 72)], 70.0, 0.35, 2.0)
	main.fx.ring(main.player.position, Color.WHITE, 6.0, 22.0, 0.25)


func _shot_end() -> void:
	shot = "end"
	gameplay = false
	sv.skin = Catalog.find("skins", "cosmo")
	sv.trail = "galaxy"
	main.go_menu()
	main.ui.hide_popup()
	main.ui.visible = false
	logo.visible = true
	logo_t0 = frame / FPS
	dim.color.a = 0.0


# ------------------------------------------------------------------ camera and effects

func _cam(z: float, f: bool) -> void:
	zoom_base = z
	zoom_from = z
	zoom_to = z
	zoom_dur = 0.0
	follow = f


func _zoom_to(z: float, dur: float) -> void:
	zoom_from = _zoom_now(frame / FPS)
	zoom_to = z
	zoom_t0 = frame / FPS
	zoom_dur = dur


func _zoom_now(t: float) -> float:
	if zoom_dur <= 0.0:
		return zoom_to
	var k := clampf((t - zoom_t0) / zoom_dur, 0.0, 1.0)
	return lerpf(zoom_from, zoom_to, k * k * (3.0 - 2.0 * k))


func _punch(a: float) -> void:
	punch_t = frame / FPS
	punch_amp = a


func _shake(a: float) -> void:
	shake_t = frame / FPS
	shake_amp = a


func _flash(a: float) -> void:
	flash_t = frame / FPS
	flash_amp = a


func _time_scale(t: float) -> float:
	if t < slowmo.x or t >= slowmo.y:
		return 1.0
	var lo := 0.12
	if t < slowmo.x + 0.3:
		var k := (t - slowmo.x) / 0.3
		return lerpf(1.0, lo, k * k * (3.0 - 2.0 * k))
	if t > slowmo.y - 0.3:
		var k2 := (t - (slowmo.y - 0.3)) / 0.3
		return lerpf(lo, 1.0, k2 * k2)
	return lo


func _camera(t: float) -> void:
	var z := _zoom_now(t) * (1.0 + punch_amp * exp(-(t - punch_t) * 9.0))
	var center := Vector2(vw * 0.5, vh * 0.5)
	var target := center
	if follow and main.state == main.S.PLAYING:
		target = main.player.global_position
	cam_focus = target if cam_focus == Vector2.ZERO else cam_focus.lerp(target, 0.25)
	if not follow:
		cam_focus = center
	# keep the focus on screen, a bit above the middle (the captions are below)
	var screen_at := Vector2(vw * 0.5, vh * 0.46) if follow else center
	var off := screen_at - cam_focus * z
	var s := shake_amp * exp(-(t - shake_t) * 7.0)
	off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s
	get_root().canvas_transform = Transform2D(0.0, Vector2(z, z), 0.0, off)
	flash.color.a = clampf(flash_amp * exp(-(t - flash_t) * 7.0), 0.0, 1.0)
	var want_dim := 0.35 if t >= slowmo.x and t < slowmo.y - 0.2 else 0.0
	dim.color.a = lerpf(dim.color.a, want_dim, 0.15)


func _captions(t: float) -> void:
	var beat_k := fposmod(t - B0, BEAT)
	for c in caps:
		var sp: Sprite2D = c[0]
		var t0: float = c[1]
		var t1: float = c[2]
		if t < t0 or t >= t1 + 0.1:
			sp.visible = false
			continue
		sp.visible = true
		var a := t - t0
		var s := 1.0
		var rot := 0.0
		if a < 0.16:
			var k := a / 0.16
			s = lerpf(1.8, 1.0, 1.0 - pow(1.0 - k, 3.0)) + sin(k * PI) * 0.12
			rot = -0.14 * (1.0 - k)
		s *= 1.0 + 0.05 * exp(-beat_k * 10.0)
		var alpha := 1.0
		if t > t1:
			var o := (t - t1) / 0.1
			s *= 1.0 - 0.4 * o
			alpha = 1.0 - o
		sp.scale = Vector2(s, s) / 6.0
		sp.rotation = rot
		sp.modulate.a = alpha
		sp.position = Vector2(vw * 0.5, c[3])
	if logo.visible:
		var a2 := t - logo_t0
		var k2 := clampf(a2 / 0.2, 0.0, 1.0)
		var ls := lerpf(4.5, 2.6, 1.0 - pow(1.0 - k2, 3.0)) * (1.0 + 0.04 * exp(-beat_k * 10.0))
		logo.scale = Vector2(ls, ls)
		logo.position = Vector2(vw * 0.5, 74.0)
		logo.rotation = -0.2 * (1.0 - k2)


# ------------------------------------------------------------------ bot

func _bot() -> void:
	var p = main.player
	if TestBot.decide(main):
		main._flip()
		return
	if not bot_jumps or main.gt - _last_switch < 0.45 or Orbit.count() < 2:
		return
	if Orbit.crossing_at(p.angle, p.orbit) < 0:
		return
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	if r[0] == p.orbit:
		return
	var rate: float = main.director.omega_rate(main.gt)
	if Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate):
		main._flip()
		_last_switch = main.gt


func _process(_dt: float) -> bool:
	if main == null or layer == null:
		return false
	var t := frame / FPS
	while ev_i < events.size() and t >= float(events[ev_i][0]):
		(events[ev_i][1] as Callable).call()
		ev_i += 1
	Engine.time_scale = _time_scale(t)
	main.ui._toast.visible = false
	if not banners:
		main.ui._banner.visible = false
	if gameplay:
		if main.state == main.S.PLAYING:
			main._grace = 0.0
			if main.gt - _bot_gt >= 1.0 / 30.0 - 0.0001:
				_bot_gt = main.gt
				_bot()
		elif main.state in [main.S.DYING, main.S.OVER]:
			print("DIED in shot %s at %.2f s" % [shot, t])
	if main.near_count != _near_seen:
		_near_seen = main.near_count
		print("CLOSE at %.2f s (shot %s, gt %.3f)" % [t, shot, main.gt])
	_camera(t)
	_captions(t)
	frame += 1
	return t >= END_T
