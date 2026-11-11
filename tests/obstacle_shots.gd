extends SceneTree
## Screenshots of every obstacle of worlds 9-16 in its world (warning, then active):
##   xvfb-run -a -s "-screen 0 600x1300x24" godot47 --path . --script tests/obstacle_shots.gd -- DIR [name]
## Writes DIR/<pattern>_<n>.png (180x320 canvas, x3).

const TIMES := [0.35, 0.9, 1.4, 2.0]


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "user://obstacle_shots"
	var only: String = args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(dir)
	var save = get_root().get_node("Save")
	save.path = "user://test_shots_save.cfg"
	save.reset_all()
	save.tutorial_done = true
	save.jump_tip_done = true
	save.ability_tips = ["turbo", "swipe"]
	get_root().size = Vector2i(540, 960)
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	for sp in Director.STAGE_PATTERNS:
		var si: int = sp[1]
		var name: String = sp[0]
		if si < 8 or (only != "" and name != only):
			continue
		seed(4000 + si)
		main.duel = {}
		main.start_run()
		main._clear_field()
		main.director.reset(77 + si, 20.0)
		main.director.offset = 60.0
		main.director.spawned_first = true
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		main.stage = si
		main.director.stage = si
		main.director.world = si + 1
		main.world_no = 99
		main._apply_world(si, false)
		main.ui.hide_tip()
		main.shield_until = INF
		var dt := 1.0 / 60.0
		for i in 30:
			main._process(dt)
		main.director.hold = true
		main._clear_field()
		var p = main.player
		var res: Dictionary = main.director._build(name, main.gt, p.angle, p.dir, main.director.omega(main.gt),
			main.director.level(main.gt), 0, p.orbit)
		for h in res["hazards"]:
			main.hazards.append(h)
			main.hazards_root.add_child(h)
		var t0: float = main.gt
		for n in TIMES.size():
			while main.gt - t0 < TIMES[n]:
				main._process(dt)
			await process_frame
			await process_frame
			get_root().get_texture().get_image().save_png("%s/%s_%d.png" % [dir, name, n])
		print("shots: %s" % name)
	quit()
