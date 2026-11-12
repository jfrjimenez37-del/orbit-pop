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
## Second argument: the variant. "epic" (default, 33 s) or one of the 11-12 s social shorts, each
## cut to its own part of the song (offsets in tools/render_shorts.sh, beat 0 = clip start):
##   duel (viewer challenge + a real duel code), slowmo (near miss), worlds (all 16 worlds),
##   skins (a skin per beat), fail (a death one point short of the record).

const FPS := 60.0
const DT := 1.0 / 60.0
const BEAT := 60.0 / 120.2
const DUEL_TARGET := 131
const SHORT_TARGET := 150     # the score the "duel" short dares the viewer to beat
const SHORT_NAME := "ORBITPOP"
const SHORT_SEED := 777
const SKIN_SHOW := ["poppy", "minty", "berry", "frosty", "ember", "volt", "ghosty", "alien",
	"crystal", "luna", "ninja", "neon", "magma", "royal", "prism", "nova"]

var main: Node
var variant := "epic"
var lang := "en"              # third argument: "es" uses the Spanish captions (<id>_es.png) and game texts
var slow_lo := 0.12           # game speed in the slow motion
var b0 := 0.110               # time of the first beat in the clip
var end_t := 33.0
var low := 258.0
var mid := 230.0
# scripted shot (fail): the recorded taps of an off-camera run are replayed frame by frame
var scripted := false
var script_taps := {}
var script_step := 0
var _was_playing := false
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
var bot_off := false          # the bot stops tapping (the run goes on: the player gets hit)
var slowmo := Vector2(-1, -1) # real-time window of the slow motion


func bt(n: float) -> float:
	return b0 + n * BEAT


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		caps_dir = args[0].trim_suffix("/") + "/"
	if args.size() > 1:
		variant = args[1]
	if args.size() > 2:
		lang = args[2]
	if variant != "epic":
		b0 = 0.0
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await process_frame
	sv = get_root().get_node("Save")
	sv.path = "user://promo_%s_%s.cfg" % [variant, lang]
	sv.reset_all()
	sv.best = 2400; sv.games = 60; sv.coins = 2350; sv.level = 18; sv.sessions = 9
	sv.daily_last = sv._day_string()
	sv.starter_seen = true
	sv.tutorial_done = true; sv.jump_tip_done = true   # no tutorial in recordings and bots
	sv.welcome_shown = true; sv.welcome_count = 99      # no welcome offer over the footage
	sv.seen_obstacles = []
	for kd in Director.KINDS:
		sv.seen_obstacles.append(kd[0])               # no NEW OBSTACLE tips
	sv.ability_tips = ["turbo", "swipe"]
	sv.music = false
	sv.skin = Catalog.find("skins", "cosmo")
	sv.trail = "galaxy"
	if variant == "chick":
		sv.skin = Catalog.find("skins", "goldie")
		sv.trail = "sparkle"
	for a in get_root().get_node("Progress").ACHIEVEMENTS:
		sv.achievements.append(a["id"])
	if variant == "duel":
		sv.best = SHORT_TARGET   # "my score" on the game over screen
	get_root().get_node("L").set_lang(lang)
	get_root().get_node("Monetization").offer_this_session = true   # no store offer over the footage
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
	low = vh - 62.0
	mid = vh * 0.5 + 70.0
	match variant:
		"epic": _build_timeline()
		"duel": _tl_duel()
		"slowmo": _tl_slowmo()
		"worlds": _tl_worlds()
		"skins": _tl_skins()
		"fail": _tl_fail()
		"stills": _tl_stills()
		"solo": _tl_solo()
		"button": _tl_button()
		"levels": _tl_levels()
		"jumps": _tl_jumps()
		"moving": _tl_moving()
		"daily": _tl_daily()
		"ad": _tl_ad()
		"fila": _tl_fila()
		"stills16": _tl_stills16()
		"phone": _tl_phone()
		"hard": _tl_hard()
		"chick": _tl_chick()
		"hooks": _tl_hooks()
		"surges": _tl_surges()
	events.sort_custom(func(a, b): return a[0] < b[0])


# ------------------------------------------------------------------ timeline

func _build_timeline() -> void:
	end_t = 33.0
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
	_cap_at(44, 48, "dare", low)
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


func _end_card(n: float) -> void:
	_at(bt(n), func(): _shot_end(); _flash(1.0); _punch(0.2))
	_cap_at(n + 1, 99, "free", vh - 92.0)
	_cap_at(n + 2, 99, "gplay", vh - 58.0)


func _beats(from: int, to: int, amp: float) -> void:
	for k in range(from, to):
		_at(bt(k), func(): _punch(amp))


## Game footage for "One Game While We Wait" (store/ad/fila): no captions. 0-1.4 the challenges
## screen (DUEL A FRIEND) · 1.4-4.6 a duel, overtaking MAYA at 3.6 · 4.6-6.6 the duel result ·
## 6.6-9.6 the logo end card.
func _tl_fila() -> void:
	end_t = 9.6
	_at(0.0, func(): _shot_challenges())
	_at(1.4, func(): _shot_duel(); _cam(1.0, false); _flash(0.6); _punch(0.2))
	_at(3.6, func():
		if main.state == main.S.PLAYING and not main.duel_lead:
			_duel_win())
	_at(4.6, func(): _shot_over(main.score); _flash(0.5))
	_at(6.6, func(): _shot_end(); _flash(1.0); _punch(0.2))


## Game footage for the live-action commercial (store/ad/): six segments in seconds, no captions
## (they are added in the edit with the actors' shots):
##   A 0-3 near miss in slow motion (4 planets) · B 3-7 a duel (goes on the green phone screen)
##   C 7-10 the same duel, overtaking the friend's score · D 10-12.5 the real duel result
##   E 12.5-15.5 moving planets with pulsar beams · F 15.5-18.5 the logo.
func _tl_ad() -> void:
	end_t = 18.5
	_at(0.0, func(): _shot_near(Vector2(0.8, 2.4), 1.6, 10, 28.0); _cam(1.7, true))
	_at(3.0, func(): _shot_duel(); _cam(1.0, false); _flash(0.6))
	_at(9.4, func():
		if main.state == main.S.PLAYING and not main.duel_lead:
			_duel_win())
	_at(10.0, func(): _shot_over(main.score); _flash(0.5))
	_at(12.5, func(): _shot_play("ad_e", 14, 30.0, 6.0, 131); _cam(1.0, false); _flash(0.8); _punch(0.2))
	_at(15.5, func(): _shot_end(); _flash(1.0); _punch(0.2))


## Short: "can you beat my score?" with a real duel code for the comments.
func _tl_duel() -> void:
	end_t = 12.0
	print("DUEL CODE: ", Duel.encode(SHORT_SEED, SHORT_TARGET, SHORT_NAME))
	_at(0.0, func(): _shot_play("d1", 12, 24.0, 6.0, 11, false, 52); _cam(1.0, false); _punch(0.2))
	_cap_at(0, 4, "can_beat", low)
	_beats(1, 4, 0.07)
	_at(bt(4), func(): _shot_play("d2", 9, 24.0, 5.5, 41, false, 96); _cam(1.0, false); _flash(0.8); _punch(0.25); _shake(2.5))
	_cap_at(4, 8, "same_run", low)
	_beats(5, 8, 0.07)
	_at(bt(8), func(): _shot_play("d3", 14, 26.0, 5.5, 61, false, 133); _cam(1.0, false); _flash(0.8); _punch(0.25); _shake(2.5))
	_cap_at(8, 12, "no_powers", low)
	_beats(9, 12, 0.07)
	_at(bt(12), func(): _shot_over(SHORT_TARGET); _flash(0.8); _punch(0.2))
	_cap_at(12.5, 16, "your_turn", 28.0)
	_at(bt(16), func(): _shot_dare(Duel.encode(SHORT_SEED, SHORT_TARGET, SHORT_NAME)); _flash(0.6); _punch(0.15))
	_cap_at(16, 20, "code", low)
	_end_card(20)


## Short: starts in slow motion on a near miss, then the drop.
func _tl_slowmo() -> void:
	end_t = 12.0
	_at(0.0, func(): _shot_near(Vector2(0.0, bt(8)), bt(4.6), 8, 28.0); _cam(2.6, true))
	_cap_at(0, 4.4, "wait", low)
	_at(bt(4.6), func(): _flash(0.5); _punch(0.15))
	_cap_at(4.6, 8, "too_close", low)
	_at(bt(8), func(): _shot_play("s2", 13, 26.0, 6.0, 21); _cam(1.0, false); _flash(1.0); _punch(0.3); _shake(3.0))
	var words := ["flip", "dodge", "jump", "repeat"]
	for i in 4:
		_cap_at(8 + i, 9 + i, words[i], mid)
	_beats(9, 12, 0.12)
	_at(bt(12), func(): _shot_play("s3", 15, 30.0, 6.0, 101); _cam(1.0, false); _flash(0.8); _punch(0.25); _shake(2.5))
	_cap_at(12, 16, "survive", low)
	_beats(13, 16, 0.08)
	_at(bt(16), func(): _shot_play("s4", 10, 24.0, 5.5, 51); _cam(1.0, false); _flash(0.8); _punch(0.25))
	_cap_at(16, 20, "worlds", low)
	_beats(17, 20, 0.07)
	_end_card(20)


## Short: all 16 worlds, one per beat, with their banners.
func _tl_worlds() -> void:
	end_t = 12.0
	_at(0.0, func(): _shot_play("w0", 0, 18.0, 5.0, 70, true); _cam(1.0, false))
	_cap_at(0, 5, "reach16", low)
	for i in range(1, 16):
		_at(bt(1 + i), func(): _shot_play("w%d" % i, i, 20.0, 5.0, 70 + i, true); _cam(1.0, false); _flash(0.3); _punch(0.12))
	_cap_at(5, 10, "clouds", low)
	_cap_at(10, 16, "space", low)
	_cap_at(16, 20, "how_far", low)
	_beats(17, 20, 0.08)
	_end_card(20)


## Short: a new skin and trail on every beat, close on the player.
func _tl_skins() -> void:
	end_t = 12.0
	_at(0.0, func(): _shot_play("sk", 13, 16.0, 5.0, 91); _cam(2.0, true))
	for i in SKIN_SHOW.size():
		var trail: String = Catalog.TRAILS[(i * 3 + 1) % Catalog.TRAILS.size()]["id"]
		_at(bt(i), func(): _look(SKIN_SHOW[i], trail); _punch(0.1))
		_cap_at(i, i + 1, "sk_" + SKIN_SHOW[i], vh * 0.46 + 40.0)
	_cap_at(0, 4, "pick", low)
	_cap_at(4, 10, "skins", low)
	_cap_at(10, 16, "trails", low)
	_cap_at(16, 20, "comment_fav", low)
	_beats(16, 20, 0.08)
	_end_card(20)


## A gameplay shot: a world, fresh hazards, then the camera reset (and a flash / punch on a cut).
func _cut(name: String, si: int, offset: float, sd: int, flash_a := 0.8, follow_z := 0.0) -> void:
	_shot_play(name, si, offset, 6.0, sd)
	if follow_z > 0.0:
		_cam(follow_z, true)
	else:
		_cam(1.0, false)
	if flash_a > 0.0:
		_flash(flash_a)
		_punch(0.22)


## Short: "I made this game alone" (song from bar 7).
func _tl_solo() -> void:
	end_t = 12.0
	_at(0.0, func(): _cut("so1", 12, 22.0, 11, 0.0, 1.8))
	_cap_at(0, 4, "solo1", low)
	_beats(1, 4, 0.06)
	_at(bt(4), func(): _cut("so2", 13, 26.0, 21); _shake(2.5))
	_cap_at(4, 8, "solo2", low)
	_at(bt(8), func(): _cut("so3", 10, 24.0, 51))
	_cap_at(8, 12, "solo3", low)
	_at(bt(12), func(): _cut("so4", 15, 30.0, 101))
	_cap_at(12, 16, "solo4", low)
	_at(bt(16), func(): _cut("so5", 9, 24.0, 41))
	_cap_at(16, 20, "solo5", low)
	_beats(5, 20, 0.07)
	_end_card(20)


## Short: "One button. How hard can it be?" calm world on the build-up, chaos on the drop (bar 25).
func _tl_button() -> void:
	end_t = 12.0
	_at(0.0, func(): _cut("b1", 0, 8.0, 70, 0.0))
	_cap_at(0, 4, "btn1", low)
	_cap_at(4, 8, "btn2", low)
	_at(bt(8), func(): _cut("b2", 15, 34.0, 101, 1.0); _punch(0.35); _shake(4.0))
	_cap_at(8, 12, "btn3", mid)
	_beats(9, 12, 0.12)
	_at(bt(12), func(): _cut("b3", 11, 28.0, 81))
	_cap_at(12, 16, "btn4", low)
	_at(bt(16), func(): _cut("b4", 14, 26.0, 61))
	_cap_at(16, 20, "survive", low)
	_beats(13, 20, 0.08)
	_end_card(20)


## Short: world 1 vs world 16, back and forth, faster and faster (bar 18).
func _tl_levels() -> void:
	end_t = 12.0
	var cuts := [[0, 0, "wn_1", 4], [4, 15, "wn_16", 4], [8, 2, "wn_3", 2], [10, 14, "wn_15", 2],
		[12, 5, "wn_6", 2], [14, 13, "wn_14", 2]]
	for c in cuts:
		var off: float = 12.0 if int(c[1]) < 6 else 30.0
		_at(bt(c[0]), func(): _cut("lv%d" % c[1], c[1], off, 200 + int(c[1]), 0.0 if c[0] == 0 else 0.7))
		_cap_at(c[0], c[0] + c[3], c[2], low)
	_at(bt(16), func(): _cut("lv9", 9, 24.0, 41))
	_cap_at(16, 20, "stop", low)
	_beats(1, 20, 0.07)
	_end_card(20)


## Short: planet jumps, close on the player (bar 9).
func _tl_jumps() -> void:
	end_t = 12.0
	var cuts := [[0, 7], [4, 10], [8, 12], [12, 13], [16, 11]]
	for c in cuts:
		_at(bt(c[0]), func(): _cut("j%d" % c[1], c[1], 14.0, 300 + int(c[1]), 0.0 if c[0] == 0 else 0.6, 1.6))
	_cap_at(0, 6, "sat1", low)
	_cap_at(6, 11, "sat2", low)
	_cap_at(11, 16, "sat3", low)
	_cap_at(16, 20, "sat4", low)
	_beats(1, 20, 0.05)
	_end_card(20)


## Short: "3 planets? Easy." then they start moving, in slow motion on the quiet bar (bar 14).
func _tl_moving() -> void:
	end_t = 12.0
	slowmo = Vector2(bt(4.5), bt(8))
	slow_lo = 0.35
	_at(0.0, func(): _cut("m1", 12, 22.0, 11, 0.0))
	_cap_at(0, 4, "mv1", low)
	_at(bt(4), func(): _cut("m2", 13, 22.0, 21, 0.5))
	_cap_at(4, 8, "mv2", low - 10.0)
	_at(bt(8), func(): _cut("m3", 14, 28.0, 61, 1.0); _shake(3.0))
	_cap_at(8, 12, "mv3", mid)
	_at(bt(12), func(): _cut("m4", 15, 30.0, 101))
	_cap_at(12, 16, "survive", low)
	_at(bt(16), func(): _cut("m5", 13, 26.0, 91))
	_cap_at(16, 20, "how_far", low)
	_beats(9, 20, 0.08)
	_end_card(20)


## Short: the daily challenge (bar 20, ends on the quiet bars).
func _tl_daily() -> void:
	end_t = 12.0
	_at(0.0, func(): _shot_challenges())
	_cap_at(0, 4, "dl1", vh - 30.0)   # below the challenges window
	_at(bt(4), func(): _shot_daily("dy1", 9, 22.0, 41); _flash(0.8); _punch(0.2))
	_cap_at(4, 8, "dl2", low - 10.0)
	_at(bt(8), func(): _shot_daily("dy2", 13, 26.0, 21); _flash(0.7); _punch(0.2))
	_cap_at(8, 12, "dl3", mid)
	_at(bt(12), func(): _shot_daily("dy3", 15, 30.0, 101); _flash(0.7); _punch(0.2))
	_cap_at(12, 16, "dl4", low)
	_at(bt(16), func(): _shot_daily("dy4", 10, 24.0, 51); _flash(0.6); _punch(0.2))
	_cap_at(16, 20, "dl5", low)
	_beats(5, 20, 0.07)
	_end_card(20)


func _shot_challenges() -> void:
	_begin()
	shot = "challenges"
	gameplay = false
	sv.daily_run = {"day": sv.daily_today(), "tries": 0, "video": 0, "best": 142, "paid": false}
	main.go_menu()
	main.ui.hide_popup()
	main.ui.show_duel()
	get_root().get_node("Monetization").hide_banner()   # no test banner in the footage


## A daily-challenge run (its HUD shows today's best to beat), warmed up off camera.
func _shot_daily(name: String, si: int, offset: float, sd: int) -> void:
	_begin()
	shot = name
	gameplay = true
	banners = false
	bot_jumps = true
	main.ui.visible = true
	logo.visible = false
	for k in 12:
		sv.daily_run = {"day": sv.daily_today(), "tries": 0, "video": 0, "best": 142, "paid": false}
		seed(sd + k * 1000)
		main.state = main.S.MENU
		main.start_daily()
		main.ui.hide_hint()
		_place(si, offset)
		if _preplay(360):
			break
	main.score = 96 + si * 2
	main.ui.set_score(main.score)
	main.ui.set_daily_target(142)
	_quiet()


## Clean 1080x1920 game frames (no HUD, no captions) for the channel art: run without
## --write-movie (under xvfb); PNGs go to /tmp/epic/stills/.
func _tl_stills() -> void:
	end_t = 4.0
	DirAccess.make_dir_recursive_absolute("/tmp/epic/stills")
	var list := [[8, 28.0, 201], [13, 26.0, 21], [10, 24.0, 51], [3, 22.0, 31], [14, 24.0, 61], [5, 22.0, 41]]
	for i in list.size():
		var e: Array = list[i]
		_at(0.6 * i, func(): _shot_play("st%d" % i, e[0], e[1], 6.0, e[2]); _cam(1.0, false); main.ui.visible = false)
		_at(0.6 * i + 0.4, func(): get_root().get_texture().get_image().save_png("/tmp/epic/stills/%d.png" % i))


## 10 s of play with no captions, for a green-screen phone (render it at the phone's shape,
## e.g. 1080x2220): world 8 (3 planets) then world 13 (moving planets).
func _tl_phone() -> void:
	end_t = 10.0
	_at(0.0, func(): _shot_play("ph1", 7, 24.0, 6.0, 401); _cam(1.0, false))
	_at(5.5, func(): _shot_play("ph2", 12, 26.0, 6.0, 402); _cam(1.0, false); _flash(0.5))


## Hard gameplay, no captions (7.5 s): world 16 at full speed (0-2.2), a slow-motion near miss in
## world 15 (2.2-4.4), world 14 until the bot stops tapping at 5.4 and gets hit (death, game over).
func _tl_hard() -> void:
	end_t = 9.0
	_at(0.0, func(): _shot_play("hd1", 15, 34.0, 6.0, 501); _cam(1.0, false); _punch(0.2))
	_at(2.2, func(): _shot_near(Vector2(2.7, 3.9), 3.3, 14, 30.0); _cam(1.0, true); _zoom_to(1.8, 0.4); _flash(0.6))
	_at(4.4, func(): _shot_play("hd3", 13, 30.0, 6.0, 503); _cam(1.0, false); _flash(0.6))
	_at(5.4, func(): bot_off = true)


## Epic gameplay, no captions (13 s): a meteor shower (world 12), a supernova (world 11), a
## slow-motion near miss (world 15), a comet storm in world 16 and a real death with the game over.
func _tl_surges() -> void:
	end_t = 13.2
	_at(0.0, func(): _shot_play("sg1", 11, 26.0, 6.0, 601); _surge_soon("shower"); _cam(1.0, false); _punch(0.25))
	_at(3.0, func(): _shot_play("sg2", 10, 24.0, 6.0, 602); _surge_soon("nova"); _cam(1.0, false); _flash(0.7); _punch(0.25))
	_at(6.0, func(): _shot_near(Vector2(6.5, 7.7), 7.1, 14, 30.0); _cam(1.0, true); _zoom_to(1.8, 0.4); _flash(0.6))
	_at(8.2, func(): _shot_play("sg4", 15, 34.0, 6.0, 604); _surge_soon("comets"); _cam(1.0, false); _flash(0.7); _punch(0.25))
	_at(10.2, func(): bot_off = true)


## Gameplay for the "chick" story edit: the yellow skin (GOLDIE) in a one-planet night world under
## a meteor shower, four planets with a supernova, a slow-motion near miss and a comet storm.
func _tl_chick() -> void:
	end_t = 13.2
	_at(0.0, func(): _shot_play("ck1", 4, 26.0, 6.0, 701); _surge_soon("shower"); _cam(1.0, false); _punch(0.25))
	_at(3.0, func(): _shot_play("ck2", 10, 24.0, 6.0, 702); _surge_soon("nova"); _cam(1.0, false); _flash(0.7); _punch(0.25))
	_at(6.0, func(): _shot_near(Vector2(6.5, 7.7), 7.1, 14, 30.0); _cam(1.0, true); _zoom_to(1.8, 0.4); _flash(0.6))
	_at(8.2, func(): _shot_play("ck4", 15, 34.0, 6.0, 704); _surge_soon("comets"); _cam(1.0, false); _flash(0.7); _punch(0.25))
	_at(10.2, func(): bot_off = true)


## Raw footage for the "first 3 seconds" hook tests (captions and cuts are added in the edit):
## 5 s of world 1, a ladder through worlds 2-4, a death in world 5, then a meteor shower in
## world 16 that ends in a death.
func _tl_hooks() -> void:
	end_t = 21.0
	_at(0.0, func(): _shot_play("hk1", 0, 22.0, 6.0, 801); _cam(1.0, false))
	_at(5.0, func(): _shot_play("hk2", 1, 22.0, 6.0, 802); _cam(1.0, false))
	_at(6.6, func(): _shot_play("hk3", 2, 22.0, 6.0, 803); _cam(1.0, false))
	_at(8.2, func(): _shot_play("hk4", 3, 22.0, 6.0, 804); _cam(1.0, false))
	_at(9.8, func(): _shot_play("hk5", 4, 24.0, 6.0, 805); _cam(1.0, false))
	_at(10.6, func(): bot_off = true)
	_at(13.0, func(): bot_off = false; _shot_play("hk6", 15, 34.0, 6.0, 806); _surge_soon("shower"); _cam(1.0, false))
	_at(18.2, func(): bot_off = true)


func _surge_soon(kind: String) -> void:
	main.director.surges = true
	main.director.surge_test = kind
	main.director.next_surge = main.gt + 0.25


## One clean still per world (no UI), saved as <caps dir>/w01.png .. w16.png, for social images.
func _tl_stills16() -> void:
	end_t = 16 * 0.7 + 0.5
	for i in 16:
		_at(0.7 * i, func(): _shot_play("s16_%d" % i, i, 22.0, 6.0, 300 + i); _cam(1.0, false); main.ui.visible = false)
		_at(0.7 * i + 0.5, func(): get_root().get_texture().get_image().save_png(caps_dir + "w%02d.png" % (i + 1)))


## Short: one point short of the record, a slow-motion death, "one more try?".
func _tl_fail() -> void:
	end_t = 11.0
	slowmo = Vector2(bt(8), bt(12))
	_at(0.0, func(): _shot_fail(bt(9), 7, 24.0); _cam(1.0, false))
	_cap_at(0, 8.6, "almost", low)
	_beats(1, 8, 0.05)
	_at(bt(8), func(): _cam(1.0, true); _zoom_to(2.4, 0.4))
	_at(bt(12), func(): _cam(1.0, false))
	_cap_at(13, 18, "one_more_1", vh - 16.0)
	_end_card(18)


func _at(t: float, f: Callable) -> void:
	events.append([t, f])


func _cap_at(n0: float, n1: float, id: String, y: float) -> void:
	var file := caps_dir + id + ".png"
	if lang != "en" and FileAccess.file_exists(caps_dir + id + "_" + lang + ".png"):
		file = caps_dir + id + "_" + lang + ".png"
	var img := Image.load_from_file(file)
	var sp := Sprite2D.new()
	sp.texture = ImageTexture.create_from_image(img)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.visible = false
	layer.add_child(sp)
	caps.append([sp, bt(n0) if n0 > 0 else 0.0, bt(n1), y])


func _cap_now(id: String, t0: float, t1: float, y: float) -> void:
	_cap_at(0, 0, id, y)
	caps[-1][1] = t0
	caps[-1][2] = t1


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


func _begin() -> void:
	scripted = false
	main.set_process(true)


func _shot_play(name: String, si: int, offset: float, pre: float, sd: int, banner := false, score := -1) -> void:
	_begin()
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
	if score >= 0:
		main.score = score
		main.record_announced = false
		main.ui.show_hud(main.best_at_start, false)
		main.ui.hide_hint()
		main.ui.set_score(score)
	_quiet()
	if banner:
		var w := Stages.world(si)
		main.ui.world_banner(main.world_no, get_root().get_node("L").t("WORLD_" + str(w["id"]).to_upper()), "", "")


## The slow-motion shot: finds a near miss off camera, then replays the same run (same seed) up
## to just before it, so the closest moment lands in the middle of the slow motion.
func _shot_near(win := Vector2(-1, -1), target := -1.0, si := 8, offset := 28.0) -> void:
	_begin()
	shot = "near"
	gameplay = true
	banners = false
	bot_jumps = false
	slowmo = win if win.y > 0.0 else Vector2(bt(8), bt(12))
	var lead := 0.0
	var t := slowmo.x
	var until := target if target > 0.0 else bt(9.85)
	while t < until:
		lead += DT * _time_scale(t)
		t += DT
	for sd in range(200, 320):
		_reset_run(sd)
		_place(si, offset)
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
		_place(si, offset)
		if _preplay(start):
			print("near miss: seed %d, clearance %.3f, at step %d (lead %.3f s)" % [sd, best, best_step, lead])
			break
	_quiet()


func _shot_dare(code := "") -> void:
	_begin()
	shot = "dare"
	gameplay = false
	main.go_menu()
	main.ui.hide_popup()
	main.ui.show_duel_accept(Duel.decode(code if code != "" else Duel.encode(4242, DUEL_TARGET, "MAYA")))


## The game over screen of the current run, at this score.
func _shot_over(score: int) -> void:
	shot = "over"
	gameplay = false
	if main.state != main.S.PLAYING:
		return
	main.score = score
	main.ui.set_score(score)
	main._game_over()


## Finds (off camera) a run where the bot plays well, then stops tapping and gets hit; replays
## the same run with the recorded taps so the hit lands at clip time `death_t` (slow motion).
## The best score is set one point above the score at the hit.
func _shot_fail(death_t: float, si: int, offset: float) -> void:
	_begin()
	shot = "fail"
	gameplay = false
	var lead := 0.0
	var t := 0.0
	while t < death_t:
		lead += DT * _time_scale(t)
		t += DT
	var lead_steps := int(round(lead * FPS))
	for sd in range(300, 420):
		_reset_run(sd)
		_place(si, offset)
		var taps := {}
		var dead_at := -1
		var off_step := 420
		for i in 900:
			if main.state != main.S.PLAYING:
				dead_at = i
				break
			main._grace = 0.0
			if i < off_step and i % 2 == 0 and _bot_tap():
				taps[i] = true
			main._process(DT)
		if dead_at < 0 or dead_at <= off_step:
			continue
		var start := dead_at - 1 - lead_steps
		if start < 120 or off_step > start + int(death_t * FPS) - 60:
			continue
		var score_at: int = main.score
		sv.best = score_at + 1
		_reset_run(sd)
		_place(si, offset)
		for i in start:
			main._grace = 0.0
			if taps.has(i):
				main._flip()
			main._process(DT)
		print("fail: seed %d, hit at step %d, start %d, score %d, best %d" % [sd, dead_at, start, score_at, sv.best])
		script_taps = taps
		script_step = start
		scripted = true
		main.set_process(false)
		break
	_quiet()


func _shot_duel() -> void:
	_begin()
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
	_begin()
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
	var lo := slow_lo
	if t < slowmo.x + 0.3 and slowmo.x > 0.0:
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
	# never show past the edges of the scene
	off = Vector2(clampf(off.x, vw - vw * z, 0.0), clampf(off.y, vh - vh * z, 0.0))
	var s := shake_amp * exp(-(t - shake_t) * 7.0)
	off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * s
	get_root().canvas_transform = Transform2D(0.0, Vector2(z, z), 0.0, off)
	flash.color.a = clampf(flash_amp * exp(-(t - flash_t) * 7.0), 0.0, 1.0)
	var want_dim := 0.35 if t >= slowmo.x and t < slowmo.y - 0.2 else 0.0
	dim.color.a = lerpf(dim.color.a, want_dim, 0.15)


func _captions(t: float) -> void:
	var beat_k := fposmod(t - b0, BEAT)
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
		var ls := lerpf(2.4, 1.3, 1.0 - pow(1.0 - k2, 3.0)) * (1.0 + 0.04 * exp(-beat_k * 10.0))
		logo.scale = Vector2(ls, ls)
		logo.position = Vector2(vw * 0.5, 84.0)
		logo.rotation = -0.2 * (1.0 - k2)


# ------------------------------------------------------------------ bot

func _bot() -> void:
	_bot_tap()


func _bot_tap() -> bool:
	var p = main.player
	if TestBot.decide(main):
		main._flip()
		return true
	if not bot_jumps or main.gt - _last_switch < 0.45 or Orbit.count() < 2:
		return false
	if Orbit.crossing_at(p.angle, p.orbit) < 0:
		return false
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	if r[0] == p.orbit:
		return false
	var rate: float = main.director.omega_rate(main.gt)
	if Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate):
		main._flip()
		_last_switch = main.gt
		return true
	return false


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
	if scripted:
		if main.state == main.S.PLAYING:
			main._grace = 0.0
			if script_taps.has(script_step):
				main._flip()
		main._process(DT * _time_scale(t))
		script_step += 1
		var playing: bool = main.state == main.S.PLAYING
		if _was_playing and not playing:
			_flash(0.7)
			_shake(4.0)
			_cap_now("nooo", t, t + 1.8, mid)
		_was_playing = playing
	elif gameplay:
		if main.state == main.S.PLAYING:
			main._grace = 0.0
			if main.gt - _bot_gt >= 1.0 / 30.0 - 0.0001:
				_bot_gt = main.gt
				if not bot_off:
					_bot()
		elif main.state in [main.S.DYING, main.S.OVER]:
			print("DIED in shot %s at %.2f s" % [shot, t])
	if main.near_count != _near_seen:
		_near_seen = main.near_count
		print("CLOSE at %.2f s (shot %s, gt %.3f)" % [t, shot, main.gt])
	_camera(t)
	_captions(t)
	frame += 1
	return t >= end_t
