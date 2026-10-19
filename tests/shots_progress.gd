extends SceneTree
## Screenshots of the progression screens: level in the menu, abilities, trails, HUD with
## world progress, game over XP, missions and settings (run under Xvfb):
## xvfb-run -a godot --path . --script tests/shots_progress.gd -- <out_dir> [lang]

var main: Node
var out_dir := "user://shots"
var frame := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DisplayServer.window_set_size(Vector2i(540, 960))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var sv = get_root().get_node("Save")
	sv.path = "user://shots_progress_save.cfg"
	sv.reset_all()
	sv.best = 186; sv.games = 60; sv.total = 4200; sv.coins = 3200
	sv.level = 12; sv.xp = 900
	sv.abilities = {"coins": 3, "shield": 0, "magnet": 1, "slowmo": 1, "teleport": 1, "headstart": 1}
	sv.stats = {"best_world": 6, "near_total": 140}
	sv.daily_last = sv._day_string()
	get_root().get_node("L").set_lang(args[1] if args.size() > 1 else "es")
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)


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
			ui.hide_popup()
			ui.refresh_menu()
		60: shot("pr_01_menu_level")
		62: main.open_abilities()
		70: shot("pr_02_abilities")
		72:
			main.open_skins()
			ui._style_tab = "trails"
			ui._style_page = 0
			ui._style_focus = Catalog.find("trails", "fire")
			ui._refresh_style()
		80: shot("pr_03_trails_p1")
		82:
			ui._style_page = 1
			ui._style_focus = Catalog.find("trails", "galaxy")
			ui._refresh_style()
		90: shot("pr_04_trails_p2")
		92:
			ui.show_mission()
		100: shot("pr_05_missions")
		102:
			ui.hide_popup()
			ui.show_settings()
		110: shot("pr_06_settings")
		112:
			ui.hide_popup()
			main.state = main.S.MENU
			main.start_run()
			main.player.trail_style = "galaxy"
		150:
			main.score = 160
			main._add_score(0)
		200: shot("pr_07_hud_progress")
		202:
			main.state = main.S.OVER
			ui.show_game_over(160, 186, false, [])
			ui.set_over_xp(175)
		230: shot("pr_08_game_over_xp")
		232:
			ui.hide_popup()
			main.state = main.S.MENU
			main.start_run()
		_:
			# trail gallery: every 30 frames a different trail, one shot each
			if frame > 260 and (frame - 260) % 30 == 0:
				var k := (frame - 260) / 30 - 1
				if k > 0:
					var c: Vector2 = main.player.get_global_transform_with_canvas().origin
					var img := get_root().get_texture().get_image()
					var r := Rect2i(Vector2i(c) - Vector2i(32, 32), Vector2i(64, 64)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
					img.get_region(r).save_png(out_dir + "/pr_trail_%02d_%s.png" % [k - 1, Catalog.TRAILS[k - 1]["id"]])
				if k >= Catalog.TRAILS.size():
					return true
				main.player.trail_style = Catalog.TRAILS[k]["id"]
				main.director.hold = true   # empty field so nothing kills the bird mid-gallery
				for h in main.hazards:
					h.queue_free()
				main.hazards.clear()
	return false
