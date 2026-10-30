extends SceneTree
## Short store / social promo videos (portrait 1080x1920, ~15 s, game music), rendered at full
## resolution (not upscaled). Variants: planets, climb, duel.
##   xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/v.avi \
##       --fixed-fps 30 --script tests/promo_videos.gd -- planets
##   ffmpeg -i /tmp/v.avi -c:v libx264 -preset slow -tune animation -crf 14 -pix_fmt yuv420p \
##       -c:a aac -b:a 192k -movflags +faststart store/promo_planets.mp4
## A showcase bot plays: it dodges like the test bot and jumps planet whenever it is at a
## crossing and the jump is safe. Worlds are jumped to so each video shows its idea quickly.

const FPS := 30.0
var main: Node
var L: Node
var frame := 0
var cap: Label
var cap_bg: ColorRect
var seg := -1
var variant := "planets"
var segments: Array = []
var end_t := 15.0
var switching := true
var _last_switch := -9.0

const VARIANTS := {
	"planets": {"end": 15.0, "switch": true, "segs": [
		[0.0, "world:5", "TAP TO JUMP\nPLANETS!"],
		[4.5, "world:7", "FLIP. DODGE.\nJUMP!"],
		[8.0, "world:10", "4 PLANETS..."],
		[11.0, "world:13", "...THAT MOVE!"],
		[13.0, "end", "PLAY FREE\nNOW!"]]},
	"climb": {"end": 15.5, "switch": true, "segs": [
		[0.0, "world:0", "HOW HIGH CAN\nYOU ORBIT?"],
		[2.6, "world:4", "FROM THE\nCLOUDS..."],
		[5.0, "world:7", "THROUGH THE\nSKY..."],
		[7.4, "world:9", "TO THE EDGE\nOF SPACE!"],
		[9.8, "world:13", "THE MOON..."],
		[12.0, "world:15", "AND BEYOND!"],
		[13.6, "end", "FREE ON\nGOOGLE PLAY"]]},
	"duel": {"end": 15.5, "switch": true, "segs": [
		[0.0, "dare", "YOUR FRIEND\nDARES YOU..."],
		[2.4, "duel", "BEAT THEIR\nSCORE!"],
		[8.6, "win", "WIN AND SEND\nIT BACK!"],
		[11.2, "daily", "NEW CHALLENGE\nEVERY DAY"],
		[13.6, "end", "PLAY FREE\nNOW!"]]},
}
const DUEL_TARGET := 131


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		variant = args[0]
	var v: Dictionary = VARIANTS[variant]
	segments = v["segs"]
	end_t = v["end"]
	switching = v["switch"]
	# full resolution: draw the 180x320 canvas at 6x instead of upscaling a small picture
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await process_frame
	var sv = get_root().get_node("Save")
	sv.path = "user://promo_%s.cfg" % variant
	sv.reset_all()
	sv.best = 412; sv.games = 60; sv.coins = 2350; sv.level = 18; sv.sessions = 9
	sv.daily_last = sv._day_string()
	sv.starter_seen = true   # no starter offer popping up over the footage
	sv.skin = Catalog.find("skins", "cosmo")
	sv.trail = "galaxy"
	var prog = get_root().get_node("Progress")
	for a in prog.ACHIEVEMENTS:
		sv.achievements.append(a["id"])   # no achievement toasts in the footage
	L = get_root().get_node("L")
	L.set_lang("en")
	seed({"planets": 31, "climb": 77, "duel": 4242}[variant])
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_root().add_child(layer)
	cap_bg = ColorRect.new()
	cap_bg.color = Color(0.1, 0.07, 0.25, 0.82)
	layer.add_child(cap_bg)
	cap = Label.new()
	cap.add_theme_font_override("font", load("res://assets/font/pixel.fnt"))
	cap.add_theme_font_size_override("font_size", 8)
	cap.add_theme_color_override("font_color", Color8(255, 236, 140))
	cap.add_theme_color_override("font_shadow_color", Color8(120, 40, 120))
	cap.add_theme_constant_override("shadow_offset_x", 1)
	cap.add_theme_constant_override("shadow_offset_y", 1)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(cap)


## Two short lines, centered, popping in: in a band below the orbits (the end card: higher,
## so the menu's PLAY button stays visible under it).
func _caption(text: String, high := false) -> void:
	var vw: float = main.get_viewport().get_visible_rect().size.x
	var vh: float = main.get_viewport().get_visible_rect().size.y
	var y := vh - 112 if high else vh - 50
	cap.text = text
	cap.size = Vector2(vw / 2.0, 20)
	cap.pivot_offset = cap.size * 0.5   # scaled x2 around its middle: centered on screen
	cap.position = Vector2(vw / 4.0, y + 15)   # its middle at y + 25, the middle of the band
	cap_bg.position = Vector2(0, y)
	cap_bg.size = Vector2(vw, 50)
	cap.scale = Vector2(2.6, 2.6)
	create_tween().tween_property(cap, "scale", Vector2(2, 2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _jump(si: int) -> void:
	main._clear_field()
	main.stage = si
	main.world_no = Stages.number_for_score(int(Stages.LIST[si]["score"]))
	main.score = int(Stages.LIST[si]["score"]) + 2
	Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
	main._apply_world(si, false)
	main.director.stage = si
	main.director.offset = 22.0
	main.ui.set_score(main.score)
	main.ui.set_altitude(main.score)
	if si == 0:
		return
	var w := Stages.world(si)
	var tip: String = L.t("MOVE_TIP") if not Stages.motion(si).is_empty() else ""
	var ly := Stages.layer(main.score)
	var layer_name: String = L.t(Stages.LAYERS[ly][1]) if ly != main._layer else ""
	main._layer = ly
	main.ui.world_banner(main.world_no, L.t("WORLD_" + str(w["id"]).to_upper()), tip, layer_name)


func _start(what: String) -> void:
	if what.begins_with("world"):
		main.ui.hide_popup()
		if main.state != main.S.PLAYING:
			main.duel = {}
			main.start_run()
			main.ui.hide_hint()
		_jump(int(what.split(":")[1]))
	elif what == "dare":
		main.go_menu()
		main.ui.hide_popup()
		main.ui.show_duel_accept(Duel.decode(Duel.encode(4242, DUEL_TARGET, "MAYA")))
	elif what == "duel":
		main.start_duel(Duel.decode(Duel.encode(4242, DUEL_TARGET, "MAYA")))
		main.ui.hide_hint()
		_jump(5)
		main.score = DUEL_TARGET - 6
		main.ui.set_score(main.score)
		main.ui.set_duel_target("MAYA", DUEL_TARGET)
	elif what == "win":
		if main.state == main.S.PLAYING:
			if main.score <= DUEL_TARGET:
				main.score = DUEL_TARGET + 4
			main._game_over()
	elif what == "daily":
		main.go_menu()
		main.ui.hide_popup()
		main.ui.show_duel()
	elif what == "end":
		main.go_menu()
		main.ui.hide_popup()


## Dodge like the test bot; otherwise jump planet at crossings when that is safe too.
func _bot(t: float) -> void:
	var p = main.player
	if TestBot.decide(main):
		main._flip()
		return
	if not switching or t - _last_switch < 0.45 or Orbit.count() < 2:
		return
	if Orbit.crossing_at(p.angle, p.orbit) < 0:
		return
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	if r[0] == p.orbit:
		return
	var rate: float = main.director.omega_rate(main.gt)
	if Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate):
		main._flip()
		_last_switch = t


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	var t := frame / FPS
	while seg + 1 < segments.size() and t >= float(segments[seg + 1][0]):
		seg += 1
		_caption(segments[seg][2], segments[seg][1] == "end")
		_start(segments[seg][1])
	main.ui._toast.visible = false
	if main.state == main.S.PLAYING:
		main._grace = 0.0
		if frame % 2 == 0:
			_bot(t)
		# the duel: make sure the lead is shown before the result
		if variant == "duel" and segments[seg][1] == "duel" and t > 7.4 and main.score <= DUEL_TARGET:
			main.score = DUEL_TARGET + 1
			main.ui.set_score(main.score)
	elif main.state in [main.S.DYING, main.S.OVER] and str(segments[seg][1]).begins_with("world"):
		main.start_run()   # the bot missed: keep the footage going (cut)
		_jump(int(str(segments[seg][1]).split(":")[1]))
	return t >= end_t
