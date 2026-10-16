extends SceneTree
## Renders screenshots of every screen (run under Xvfb):
## xvfb-run -a godot --path . --script tests/shots.gd -- <out_dir> [width height] [lang]

var main: Node
var out_dir := "user://shots"
var frame := 0
var sv: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	sv = get_root().get_node("Save")
	sv.path = "user://shots_save.cfg"
	sv.reset_all()
	sv.best = 37; sv.games = 3; sv.total = 260; sv.coins = 640
	sv.boosts = {"shield": 1, "rush": 0, "teleport": 2}
	sv.daily_last = sv._day_string()   # skip the daily popup
	sv.add_top_score(37, 2); sv.add_top_score(22, 2); sv.add_top_score(9, 1)
	sv.achievements = ["first", "score10", "score25", "world2"]
	get_root().get_node("L").set_lang(args[3] if args.size() > 3 else "es")
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)


func shot(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("shot ", name)


func world(i: int) -> void:
	Orbit.set_shape(Stages.LIST[i]["orbits"], true)
	main.stage = i
	main.director.stage = i
	main.world_no = i + 1
	main._apply_world(i, false)
	main.director.offset = 40.0


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	if main.state == main.S.PLAYING and TestBot.decide(main):
		main._flip()
	match frame:
		40: shot("01_menu")
		45: main.ui.show_boosts()
		60: shot("02_boosts")
		65: main.ui.show_mission()
		80: shot("03_mission")
		85: main.ui.show_settings()
		100: shot("04_settings")
		105:
			main.ui.hide_popup()
			main.open_ranking()
		130: shot("05_ranking")
		135:
			main.ui._rank_tab = "achievements"
			main.ui.refresh_ranking()
		145: shot("06_achievements")
		150:
			main.go_menu()
			main.armed["teleport"] = true
			main.start_run()
		300: shot("07_play_sky")
		305: main.score = 20; main._add_score(0)
		420: shot("08_world2_banner")
		700: shot("09_lagoon")
		705: world(3)
		900: shot("10_candy")
		905: world(4)
		1000: main.ui.world_banner(5, "NOCHE", "TOCA EN LA ESTRELLA")
		1100: shot("11_night_dual")
		1300: shot("12_night_2")
		1301:
			main.score = 63
			main._die()
		1400: shot("13_gameover")
		1405: return true
	return false
