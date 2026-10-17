extends SceneTree
## Screenshots of the skins (by rarity), ranking with names and game over with rank (run under Xvfb):
## xvfb-run -a godot --path . --script tests/shots_ui.gd -- <out_dir> [lang]

var main: Node
var out_dir := "user://shots"
var frame := 0
var pg: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DisplayServer.window_set_size(Vector2i(540, 960))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var sv = get_root().get_node("Save")
	sv.path = "user://shots_ui_save.cfg"
	sv.reset_all()
	sv.best = 268; sv.games = 40; sv.total = 3100; sv.coins = 4600
	sv.stats = {"best_world": 7, "near_total": 140}
	sv.owned_items = ["skins:cookie", "skins:ninja"]
	sv.daily_last = sv._day_string()
	sv.achievements = ["first", "score25", "score50", "score100", "score200", "world3", "world5", "world7", "near100"]
	get_root().get_node("L").set_lang(args[1] if args.size() > 1 else "es")
	pg = get_root().get_node("Progress").games
	pg.signed_in = true
	pg.available = true
	pg.player_name = "Javier Feliz"
	pg.player_id = "me"
	pg.ranks = {"GLOBAL": 734, "LATAM": 41}
	var names := ["NEBULA_77", "Ana Lucía", "orbitKing", "Pedro M", "ZETA", "Lu", "Maria Jose", "TapTap", "Kai", "Sol"]
	var rows: Array = []
	for i in 10:
		rows.append({"rank": i + 1, "name": names[i], "score": 1240 - i * 87, "me": false})
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	main.ui._board_rows = {"GLOBAL": rows}


func shot(name: String) -> void:
	get_root().get_texture().get_image().save_png(out_dir + "/" + name + ".png")
	print("shot ", name)


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	var ui = main.ui
	match frame:
		30:
			main.ui.hide_popup()
			main.player.set_skin(Catalog.find("skins", "royal"))
			ui.refresh_menu()
		60: shot("ui_01_menu")
		62:
			main.open_skins()
			ui._style_focus = Catalog.find("skins", "ghosty")
			ui._style_page = 1
			ui._refresh_style()
		70: shot("ui_02_skins_p2")
		72:
			ui._style_page = 2
			ui._style_focus = Catalog.find("skins", "nova")
			ui._refresh_style()
		80: shot("ui_03_skins_p3")
		82:
			ui._style_page = 0
			ui._style_focus = 0
			ui._refresh_style()
		90: shot("ui_04_skins_p1")
		92:
			main.state = main.S.RANKING
			ui.show_ranking()
			ui._rank_board = "GLOBAL"
			ui.refresh_ranking()
		100: shot("ui_05_ranking_global")
		102:
			ui._rank_tab = "achievements"
			ui._rank_page = 1
			ui.refresh_ranking()
		110: shot("ui_06_achievements")
		112:
			main.state = main.S.OVER
			ui.show_game_over(268, 268, true, [Catalog.find("skins", "alien")])
			ui._on_rank_loaded("GLOBAL", 734, 268)
			ui._on_rank_loaded("LATAM", 41, 268)
		140: shot("ui_07_game_over_rank")
		142:
			main.ui.hide_popup()
			main.start_run()
			main.player.set_skin(Catalog.find("skins", "omega"))
		200: shot("ui_08_omega_fx")
		202: main.player.set_skin(Catalog.find("skins", "magma"))
		230: shot("ui_09_magma_fx")
		232: return true
	return false
