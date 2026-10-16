extends SceneTree
## Renders screenshots of every screen (run under Xvfb):
## xvfb-run -a godot --path . --script tests/shots.gd -- <out_dir> [width height]

var main: Node
var out_dir := "user://shots"
var frame := 0
var phase := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	var save = get_root().get_node("Save")
	save.path = "user://shots_save.cfg"
	save.best = 37; save.games = 9; save.total = 260
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)


func shot(name: String) -> void:
	var img := get_root().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("shot ", name, " ", img.get_size())


func _process(_dt: float) -> bool:
	frame += 1
	if main.state == main.S.PLAYING and TestBot.decide(main):
		main._flip()
	match frame:
		40: shot("1_menu")
		50: main.ui.skins_pressed.emit()
		80: shot("2_skins")
		90: main.go_menu()
		100: main.start_run()
		130: shot("3_play_start")
		700: shot("4_play_10s")
		1500: shot("5_play_23s")
		1501:
			main.score = 41
			main._die()
		1510: shot("6_death")
		1600: shot("7_gameover")
		1610: return true
	return false
