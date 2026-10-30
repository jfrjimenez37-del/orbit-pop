extends SceneTree
## Store promo video (portrait, ~27 s, with the game's own music and sounds). Run with:
##   xvfb-run -a -s "-screen 0 1200x2000x24" godot47 --path . --write-movie /tmp/orbitpop.avi \
##       --fixed-fps 30 --script tests/promo_video.gd
##   ffmpeg -i /tmp/orbitpop.avi -vf scale=1080:1920:flags=neighbor -c:v libx264 -pix_fmt yuv420p \
##       -crf 20 -c:a aac -b:a 128k -movflags +faststart store/promo_video.mp4
## (the movie is recorded at the game's 180x320 and scaled x6 without smoothing)
## A bot plays (same one as the fairness tests); the worlds are jumped to so the video shows many.

const FPS := 30
var main: Node
var frame := 0
var cap: Label
var cap_bg: ColorRect
var segments := [
	# [start s, what, caption]
	[0.0, "menu", "ONE-TAP\nARCADE"],
	[2.5, "run:0", "TAP TO FLIP\nYOUR ORBIT"],
	[8.0, "world:5", "JUMP BETWEEN\nPLANETS"],
	[12.5, "world:10", "16 WORLDS\nTO EXPLORE"],
	[17.0, "world:13", "PLANETS IN\nMOTION!"],
	[21.5, "duel", "DUEL YOUR\nFRIENDS"],
	[24.5, "end", "FREE ON\nGOOGLE PLAY"],
]
const END := 27.5
var seg := -1


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1080, 1920))
	await process_frame
	var sv = get_root().get_node("Save")
	sv.path = "user://promo_save.cfg"
	sv.reset_all()
	sv.best = 412; sv.games = 60; sv.coins = 2350; sv.level = 18
	sv.daily_last = sv._day_string()
	sv.skin = Catalog.find("skins", "cosmo")
	get_root().get_node("L").set_lang("en")
	seed(2025)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_root().add_child(layer)
	cap_bg = ColorRect.new()
	cap_bg.color = Color(0.1, 0.07, 0.25, 0.78)
	layer.add_child(cap_bg)
	cap = Label.new()
	cap.add_theme_font_override("font", load("res://assets/font/pixel.fnt"))
	cap.add_theme_font_size_override("font_size", 8)
	cap.add_theme_color_override("font_color", Color8(255, 236, 140))
	cap.scale = Vector2(2, 2)
	layer.add_child(cap)


## Two short lines, centered, in a band at the bottom (below the orbits).
func _caption(text: String) -> void:
	cap.text = text
	var vw: float = main.get_viewport().get_visible_rect().size.x
	var vh: float = main.get_viewport().get_visible_rect().size.y
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size = Vector2(vw / 2.0, 20)
	cap.position = Vector2(0, vh - 47)
	cap_bg.position = Vector2(0, vh - 50)
	cap_bg.size = Vector2(vw, 50)


func _jump(si: int) -> void:
	main._clear_field()
	main.stage = si
	main.world_no = Stages.number_for_score(int(Stages.LIST[si]["score"]))
	main.score = int(Stages.LIST[si]["score"]) + 2
	Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
	main._apply_world(si, false)
	main.director.stage = si
	main.director.offset = 20.0
	main.ui.set_score(main.score)
	var w := Stages.world(si)
	var tip: String = get_root().get_node("L").t("MOVE_TIP") if not Stages.motion(si).is_empty() else ""
	main.ui.world_banner(main.world_no, get_root().get_node("L").t("WORLD_" + str(w["id"]).to_upper()), tip)


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	var t := frame / float(FPS)
	if frame == 2:
		main.ui.hide_popup()
		main.ui.refresh_menu()
	while seg + 1 < segments.size() and t >= float(segments[seg + 1][0]):
		seg += 1
		var what: String = segments[seg][1]
		_caption(segments[seg][2])
		if what.begins_with("run"):
			main.duel = {}
			main.start_run()
			main.ui.hide_hint()
		elif what.begins_with("world"):
			if main.state != main.S.PLAYING:
				main.start_run()
			_jump(int(what.split(":")[1]))
		elif what == "duel":
			main.start_duel(Duel.decode(Duel.encode(4242, 131, "MAYA")))
			main.score = 148
			main._game_over()
		elif what == "end":
			main.go_menu()
			main.ui.hide_popup()
	if main.state == main.S.PLAYING:
		main._grace = 0.0
		if frame % 2 == 0 and TestBot.decide(main):
			main._flip()
	elif main.state in [main.S.DYING, main.S.OVER] and (segments[seg][1].begins_with("world") or segments[seg][1].begins_with("run")):
		main.start_run()   # the bot missed: keep the footage going
		if segments[seg][1].begins_with("world"):
			_jump(int(segments[seg][1].split(":")[1]))
	return t >= END
