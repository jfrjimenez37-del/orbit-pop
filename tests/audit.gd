extends SceneTree
## Fairness audit (slow, not part of run_tests):
##   godot --headless --path . --script tests/audit.gd -- [runs_per_world] [seconds]
## For every world it plays with two bots at max difficulty:
##   perfect: taps exactly when needed (any death = a truly impossible situation)
##   human:   plans with slack (human margin), then taps 0-70 ms late, never faster than every 0.17 s
## and reports deaths per minute, so unfair-for-humans worlds stand out.
## Pass "old" as third argument to commit patterns without the human check (A/B comparison).

const DT := 1.0 / 60.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 4
	var secs := float(args[1]) if args.size() > 1 else 40.0
	var human_check := not (args.size() > 2 and args[2] == "old")
	var save = get_root().get_node("Save")
	save.path = "user://audit_save.cfg"
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var total := {"perfect": 0, "human": 0}
	for si in Stages.LIST.size():
		var res := {}
		for kind in ["perfect", "human"]:
			var deaths := 0
			var time := 0.0
			var causes := {}
			for r in runs:
				var out := _play(main, si, kind, secs, 1000 * si + r, human_check)
				time += out["t"]
				if out["died"]:
					deaths += 1
					causes[out["cause"]] = causes.get(out["cause"], 0) + 1
			res[kind] = "%d deaths in %.0fs %s" % [deaths, time, str(causes) if deaths > 0 else ""]
			total[kind] += deaths
		print("%-8s perfect: %s | human: %s" % [Stages.LIST[si]["world"], res["perfect"], res["human"]])
	print("TOTAL deaths perfect=%d human=%d" % [total["perfect"], total["human"]])
	quit(0)


## Human-like decision: keep a timing cushion when possible, otherwise act like the perfect bot.
func _human_decide(main) -> bool:
	var p = main.player
	var hm := Survival.human_margin(p.omega)
	var stay_ok := Survival.can_survive(main.hazards, main.gt, p.angle, p.dir, p.omega, false, p.orbit, hm, Survival.HUMAN_GAP)
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	var tap_ok := Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], hm, Survival.HUMAN_GAP)
	if stay_ok or tap_ok:
		return not stay_ok
	return TestBot.decide(main)


func _play(main, si: int, kind: String, secs: float, seed_value: int, human_check := true) -> Dictionary:
	main.start_run()
	main.director.rng.seed = seed_value
	main.director.offset = 60.0
	main.director.human_check = human_check
	Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
	main.stage = si
	main.director.stage = si
	main.world_no = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pending := -1.0
	var last_tap := -9.0
	var frames := 0
	var last_names: Array = []
	while main.state == main.S.PLAYING and main.gt < secs:
		if kind == "perfect":
			if TestBot.decide(main):
				main._flip()
		else:
			if pending < 0.0 and main.gt - last_tap >= Survival.HUMAN_GAP and _human_decide(main):
				pending = main.gt + rng.randf_range(0.0, 0.07)
			if pending >= 0.0 and main.gt >= pending:
				main._flip()
				last_tap = main.gt
				pending = -1.0
		last_names = main.hazards.map(func(h): return h.get_script().get_global_name())
		main._grace = 0.0
		main._process(DT)
		frames += 1
	var died: bool = main.state != main.S.PLAYING
	var cause := ""
	if died:
		cause = ",".join(last_names)
	var t: float = main.gt
	if main.state == main.S.DYING:
		main._game_over()
	return {"died": died, "t": t, "cause": cause}
