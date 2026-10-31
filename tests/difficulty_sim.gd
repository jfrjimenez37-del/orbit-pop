extends SceneTree
## How a run feels for players of different skill, from a real start (world 1, natural world
## changes, adaptive difficulty from the player's recent runs). Slow, not part of run_tests:
##   godot47 --headless --path . --script tests/difficulty_sim.gd -- [runs]
## Bots see a hazard `react` s after it appears, tap 0..`late` s late, never faster than `gap`,
## and plan with the exact hitbox (no safety margin), so they make human-like mistakes.

const DT := 1.0 / 60.0
const MAX_T := 150.0
const PROFILES := {
	# react, late, gap, recent average score (adaptive difficulty)
	"new player": [0.42, 0.14, 0.24, 0.0],
	"casual": [0.34, 0.10, 0.20, 25.0],
	"good": [0.27, 0.07, 0.17, 80.0],
}


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 30
	var save = get_root().get_node("Save")
	save.path = "user://difficulty_sim.cfg"
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	for name in PROFILES:
		var pr: Array = PROFILES[name]
		var times: Array = []
		var scores: Array = []
		var deaths := {}
		for r in runs:
			var out := _play(main, save, pr, 777 + r * 31)
			times.append(out["t"])
			scores.append(out["score"])
			for b in [10, 20, 30, 60]:
				if out["t"] < b:
					deaths[b] = deaths.get(b, 0) + 1
		times.sort()
		scores.sort()
		print("%-10s median run %5.1f s  score %3d  | died before 10s %2d%%  20s %2d%%  30s %2d%%  60s %2d%%  | best %3d" % [name,
			times[runs / 2], scores[runs / 2], 100 * deaths.get(10, 0) / runs, 100 * deaths.get(20, 0) / runs,
			100 * deaths.get(30, 0) / runs, 100 * deaths.get(60, 0) / runs, scores[-1]])
	quit(0)


func _play(main, save, pr: Array, seed_value: int) -> Dictionary:
	save.reset_all()
	for i in 5:
		save.recent.append(int(pr[3]))   # the adaptive difficulty reads the last runs
	seed(seed_value)
	main.duel = {}
	main.start_run()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var react: float = pr[0]
	var pending := -1.0
	var last_tap := -9.0
	while main.state == main.S.PLAYING and main.gt < MAX_T:
		var seen: Array = main.hazards.filter(func(h): return h.t_spawn <= main.gt - react)
		if pending < 0.0 and main.gt - last_tap >= float(pr[2]) and _decide(main, seen):
			pending = main.gt + rng.randf_range(0.0, float(pr[1]))
		if pending >= 0.0 and main.gt >= pending:
			main._flip()
			last_tap = main.gt
			pending = -1.0
		main._grace = 0.0
		main._process(DT)
	var out := {"t": main.gt, "score": main.score}
	if main.state == main.S.DYING:
		main._game_over()
	main.go_menu()
	return out


func _decide(main, seen: Array) -> bool:
	var p = main.player
	var rate: float = main.director.omega_rate(main.gt)
	var stay := Survival.can_survive(seen, main.gt, p.angle, p.dir, p.omega, false, p.orbit, Survival.MARGIN, Survival.TAP_GAP, 0.0, rate)
	if stay:
		return false
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	return Survival.can_survive(seen, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate)
