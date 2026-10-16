extends SceneTree
## Renders screenshots of every screen (run under Xvfb):
## xvfb-run -a godot --path . --script tests/shots.gd -- <out_dir> [width height]

var main: Node
var out_dir := "user://shots"
var frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var save = get_root().get_node("Save")
	save.path = "user://shots_save.cfg"
	save.reset_all()
	save.best = 37; save.games = 3; save.total = 260; save.coins = 640
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)


func shot(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("shot ", name)


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	if main.state == main.S.PLAYING and TestBot.decide(main):
		main._flip()
	var sv = get_root().get_node("Save")
	match frame:
		40: shot("01_daily")
		45: main.ui.daily_claim.emit(false)
		60: shot("02_menu")
		65: main.ui.skins_pressed.emit()
		95: shot("03_skins")
		100:
			main.ui._style_page = 1
			main.ui._style_focus = 11
			main.ui._refresh_style()
		110: shot("04_skins_p2")
		115:
			main.ui._style_tab = "trails"
			main.ui._style_page = 0
			main.ui._style_focus = 2
			main.ui._refresh_style()
		125: shot("05_trails")
		130:
			main.ui._style_tab = "worlds"
			main.ui._style_page = 0
			main.ui._style_focus = 4
			main.ui._refresh_style()
		140: shot("06_worlds")
		145: main.open_shop()
		175: shot("07_shop_packs")
		180:
			main.ui._shop_tab = "boosts"
			main.ui.refresh_shop()
		190: shot("08_shop_coins")
		195:
			sv.grant("world_pack")
			sv.world = "night"
			sv.trail = "rainbow"
			main.go_menu()
		200: main.start_run()
		700: shot("09_play_night")
		701:
			main.score = 41
			main.bubbles_popped = 3
			main._die()
		800: shot("10_gameover")
		805:
			sv.games = 9
			sv.starter_seen = false
			sv.purchases = []
			main.go_menu()
		830: shot("11_starter")
		835: return true
	return false
