extends SceneTree
## Fairness audit with a realistic human (slow, not part of run_tests):
##   godot --headless --path . --script tests/audit_react.gd -- [runs_per_world] [seconds] [react]
## The bot only sees a hazard `react` seconds after it appears, plans with the human margin,
## taps 0-70 ms late and never faster than every 0.17 s. Every death is classified:
##   blind: the run was already lost before the bot could even see the newest hazard (unfair)
##   late:  an escape existed after it could react (needed better play / tighter timing)

const DT := 1.0 / 60.0


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 4
	var secs := float(args[1]) if args.size() > 1 else 40.0
	var react := float(args[2]) if args.size() > 2 else 0.25
	var save = get_root().get_node("Save")
	save.path = "user://audit_save.cfg"
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var tot := {"blind": 0, "late": 0, "time": 0.0, "patterns": 0}
	for si in Stages.LIST.size():
		var w := {"blind": 0, "late": 0, "time": 0.0, "patterns": 0}
		var causes := {}
		for r in runs:
			var out := _play(main, si, secs, 1000 * si + r, react)
			w["time"] += out["t"]
			w["patterns"] += out["patterns"]
			if out["died"]:
				w[out["kind"]] += 1
				causes[out["cause"]] = causes.get(out["cause"], 0) + 1
		for key in tot:
			tot[key] += w[key]
		print("%-8s blind %d  late %d  in %4.0fs  (%.1f patterns/s) %s" % [Stages.LIST[si]["world"], w["blind"], w["late"], w["time"],
			w["patterns"] / maxf(w["time"], 1.0), str(causes) if not causes.is_empty() else ""])
	print("TOTAL blind=%d late=%d in %.0fs, %.2f patterns/s, deaths/min %.2f" % [tot["blind"], tot["late"], tot["time"],
		tot["patterns"] / tot["time"], (tot["blind"] + tot["late"]) * 60.0 / tot["time"]])
	quit(0)


func _can(hs: Array, main, angle: float, dir: int, orbit: int, human: bool) -> bool:
	var p = main.player
	if human:
		return Survival.can_survive(hs, main.gt, angle, dir, p.omega, false, orbit, Survival.human_margin(p.omega), Survival.HUMAN_GAP)
	return Survival.can_survive(hs, main.gt, angle, dir, p.omega, false, orbit)


## True if some move (stay or tap now) still survives `hs`.
func _alive(hs: Array, main, human: bool) -> bool:
	var p = main.player
	if _can(hs, main, p.angle, p.dir, p.orbit, human):
		return true
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	return _can(hs, main, r[2], r[1], r[0], human)


func _decide(main, seen: Array) -> bool:
	var p = main.player
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	for human in [true, false]:
		var stay := _can(seen, main, p.angle, p.dir, p.orbit, human)
		var tap := _can(seen, main, r[2], r[1], r[0], human)
		if stay or tap:
			return not stay
	return false


func _play(main, si: int, secs: float, seed_value: int, react: float) -> Dictionary:
	main.start_run()
	main.director.rng.seed = seed_value
	main.director.offset = 60.0
	Orbit.set_shape(Stages.LIST[si]["orbits"], true)
	main.stage = si
	main.director.stage = si
	main.world_no = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pending := -1.0
	var last_tap := -9.0
	var doom_at := -1.0     # first time no move survives everything (true state, exact margin)
	var names: Array = []
	var newest := -9.0
	while main.state == main.S.PLAYING and main.gt < secs:
		var seen: Array = main.hazards.filter(func(h): return h.t_spawn <= main.gt - react)
		if pending < 0.0 and main.gt - last_tap >= Survival.HUMAN_GAP and _decide(main, seen):
			pending = main.gt + rng.randf_range(0.0, 0.07)
		if pending >= 0.0 and main.gt >= pending:
			main._flip()
			last_tap = main.gt
			pending = -1.0
		if doom_at < 0.0 and not _alive(main.hazards, main, false):
			doom_at = main.gt
			names = main.hazards.map(func(h): return h.get_script().get_global_name())
			newest = -9.0
			for h in main.hazards:
				newest = maxf(newest, h.t_spawn)
		main._grace = 0.0
		main._process(DT)
	var died: bool = main.state != main.S.PLAYING
	var out := {"died": died, "t": main.gt, "patterns": main.director.committed, "kind": "", "cause": ""}
	if died:
		# lost before the newest hazard was even visible to the player -> unfair
		out["kind"] = "blind" if doom_at >= 0.0 and doom_at < newest + react else "late"
		out["cause"] = ",".join(names)
	if main.state == main.S.DYING:
		main._game_over()
	return out
