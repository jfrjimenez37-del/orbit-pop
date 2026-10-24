extends SceneTree
## Raw 180x320 frames for the Play Store screenshots (captions are added by
## tools/gen_store_shots.py). Run under Xvfb:
##   xvfb-run -a godot --path . --script tests/shots_store.gd -- <out_dir> <lang>
## Gameplay scenes save several candidate frames (g<scene>_<n>.png); pick the best.

var main: Node
var out_dir := "user://store_shots"
var frame := 0
var sv: Node
var pg: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else out_dir
	DisplayServer.window_set_size(Vector2i(540, 960))
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	sv = get_root().get_node("Save")
	sv.path = "user://store_shots_save.cfg"
	sv.reset_all()
	sv.best = 214; sv.games = 120; sv.total = 9800; sv.coins = 4250
	sv.level = 18; sv.xp = 600
	sv.abilities = {"coins": 3, "shield": 2, "magnet": 3, "slowmo": 2, "teleport": 2, "headstart": 1, "secondlife": 1}
	sv.stats = {"best_world": 7, "near_total": 640}
	sv.owned_items = ["skins:cookie", "skins:ninja", "skins:drake", "trails:fire", "trails:notes"]
	sv.purchases = ["no_ads"]   # no test banner in the store pictures
	sv.daily_last = sv._day_string()
	sv.achievements = ["first", "score25", "score50", "score100", "score200", "world3", "world5", "world7", "near100", "near500"]
	sv.add_top_score(214, 7); sv.add_top_score(188, 6); sv.add_top_score(151, 5)
	get_root().get_node("L").set_lang(args[1] if args.size() > 1 else "en")
	pg = get_root().get_node("Progress").games
	pg.signed_in = true
	pg.available = true
	pg.player_name = "OrbitAce"
	pg.player_id = "me"
	pg.ranks = {"GLOBAL": 128, "NORTH_AMERICA": 23}
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	var names := ["NOVA_77", "Jessie", "orbitKing", "MaxP", "ZETA", "Luna", "TapTap", "Kai", "SkyRider", "Mo"]
	var rows: Array = []
	for i in 10:
		rows.append({"rank": i + 1, "name": names[i], "score": 1460 - i * 97, "me": false})
	main.ui._board_rows = {"GLOBAL": rows}


func shot(name: String) -> void:
	get_root().get_texture().get_image().save_png(out_dir + "/" + name + ".png")
	print("shot ", name)


func world(i: int, score: int) -> void:
	Orbit.set_shape(Stages.LIST[i]["orbits"], true)
	main.stage = i
	main.director.stage = i
	main.world_no = i + 1
	main._apply_world(i, false)
	main.director.offset = 35.0
	main.score = score
	main.ui.set_score(score)
	main.ui.set_world_progress(score, sv.best)


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	if main.state == main.S.PLAYING:
		if TestBot.decide(main):
			main._flip()
		main.shield_until = main.gt + 1.0   # the camera never catches a death
	var ui = main.ui
	match frame:
		20:
			ui.hide_popup()
			main.player.set_skin(Catalog.find("skins", "royal"))
			main.player.trail_style = "rainbow"
		# 1: first world, plenty of action
		30:
			seed(4242)   # same run in every language
			main.start_run()
			main.player.trail_style = "rainbow"
			world(0, 18)
		# 2: night (two crossing orbits)
		400:
			main.player.set_skin(Catalog.find("skins", "cosmo"))
			main.player.trail_style = "galaxy"
			world(4, 163)
		# 3: three planets
		800:
			main.player.set_skin(Catalog.find("skins", "magma"))
			main.player.trail_style = "fire"
			world(7, 331)
		# 4: coins flying in with the magnet
		1200:
			sv.abilities["magnet"] = 5
			main.player.set_skin(Catalog.find("skins", "omega"))
			main.player.trail_style = "aurora"
			world(5, 216)
			main.director.next_coin = main.gt + 0.3
		1500:
			main.state = main.S.MENU
			main.go_menu()
			main.open_abilities()
		1520: shot("u5_abilities")
		1525:
			main.go_menu()
			main.open_skins()
			ui._style_page = 1
			ui._style_focus = Catalog.find("skins", "drake")
			ui._refresh_style()
		1545: shot("u6_skins")
		1550:
			main.go_menu()
			ui.show_mission()
		1570: shot("u7_missions")
		1575:
			ui.hide_popup()
			main.open_ranking()
			ui._rank_board = "GLOBAL"
			ui.refresh_ranking()
		1600: shot("u8_ranking")
		1605: return true
	if frame > 1200 and frame < 1500:
		main.director.next_coin = minf(main.director.next_coin, main.gt + 1.4)   # lots of coins to pull in
	# candidate frames for the gameplay scenes
	for sc in [[1, 30], [2, 400], [3, 800], [4, 1200]]:
		var f0: int = sc[1]
		if frame > f0 + 120 and (frame - f0) % 40 == 0 and frame < f0 + 380:
			shot("g%d_%d" % [sc[0], (frame - f0) / 40])
	return false
