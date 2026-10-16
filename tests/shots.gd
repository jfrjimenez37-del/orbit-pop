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
	save.best = 37; save.games = 9; save.total = 260
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
	match frame:
		40: shot("01_menu")
		45: main.ui.skins_pressed.emit()
		75: shot("02_skins")
		80: main.ui.shop_pressed.emit()
		110: shot("03_shop")
		115: main.ui.buy_pressed.emit("star_pack")
		120: shot("04_bought")
		125: main.ui.skins_pressed.emit()
		150: shot("05_skins_owned")
		155: main.go_menu()
		160: main.start_run()
		700: shot("06_play")
		701:
			main.score = 41
			main._die()
		800: shot("07_gameover_continue")
		805: main._on_continue_pressed()
		840: shot("08_test_ad")
		1040: shot("09_revived")
		1050: return true
	return false
