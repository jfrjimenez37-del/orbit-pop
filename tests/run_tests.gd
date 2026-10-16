extends SceneTree
## Headless test suite:  godot --headless --path . --script tests/run_tests.gd
## Exits with code 0 when every check passes.

var fails := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FAIL: ", msg)


func _initialize() -> void:
	var save = get_root().get_node("Save")
	save.path = "user://test_save.cfg"
	print("== geometry: danger() matches real distances")
	test_geometry()
	print("== survival checker")
	test_survival()
	print("== save / load")
	test_save(save)
	print("== difficulty curve")
	test_difficulty()
	print("== gameplay simulation with fair bot")
	await test_simulation(save)
	print("\n%d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _player_pos(a: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * Orbit.R


func _inside(h: Hazard, t: float, a: float) -> bool:
	var iv: Array = []
	h.danger(t, iv)
	for v in iv:
		if absf(Orbit.ang_diff(a, v.x)) < v.y:
			return true
	return false


func test_geometry() -> void:
	var bad := 0
	var m := Meteor.new().setup(0.7, 0.0, 0.3, 120.0)
	for i in 400:
		var t := m.t_danger_start - 0.05 + i * (m.t_danger_end - m.t_danger_start + 0.1) / 400.0
		var mp := Vector2(cos(0.7), sin(0.7)) * m.radius_at(t)
		for k in 60:
			var a := 0.7 + (k - 30) * 0.01
			var real := _player_pos(a).distance_to(mp) < Meteor.RADIUS + Orbit.PLAYER_R
			if real != _inside(m, t, a):
				bad += 1
	ok(bad < 6, "meteor interval mismatch count %d" % bad)
	m.free()
	var s := Spiky.new().setup(-1.0, 0.0, 0.5, 2.0)
	bad = 0
	for k in 200:
		var a := -1.0 + (k - 100) * 0.003
		var real := _player_pos(a).distance_to(_player_pos(-1.0)) < Spiky.RADIUS + Orbit.PLAYER_R
		if real != _inside(s, 1.0, a):
			bad += 1
	ok(bad <= 2, "spiky interval mismatch %d" % bad)
	ok(not _inside(s, 0.2, -1.0), "spiky harmless during warning")
	s.free()
	var b := Barrier.new().setup(2.0, 0.0, 0.5, 2.0)
	bad = 0
	for k in 200:
		var a := 2.0 + (k - 100) * 0.003
		var p := _player_pos(a)
		var d := Vector2(cos(2.0), sin(2.0))
		var dist := absf(p.cross(d))
		var real := dist < Orbit.PLAYER_R + Barrier.BEAM_HALF and p.dot(d) > 0
		if real != _inside(b, 1.0, a):
			bad += 1
	ok(bad <= 2, "barrier interval mismatch %d" % bad)
	ok(not _inside(b, 0.3, 2.0), "barrier harmless during warning")
	b.free()


func test_survival() -> void:
	# a full ring of simultaneous mines can not be survived
	var ring: Array = []
	for i in 22:
		ring.append(Spiky.new().setup(i * TAU / 22.0, 0.0, 0.8, 2.0))
	ok(not Survival.can_survive(ring, 0.0, 0.1, 1, 2.5), "full mine ring must be unfair")
	for h in ring:
		h.free()
	# one meteor aimed at the predicted spot is fine (player can flip)
	var m := Meteor.new().setup(-PI * 0.5 + 2.5 * 1.2, 0.0, 0.3, 100.0)
	ok(Survival.can_survive([m], 0.0, -PI * 0.5, 1, 2.5), "single meteor must be fair")
	# two barriers 10 degrees apart around the player, instantly active: unfair
	var b1 := Barrier.new().setup(0.12, 0.0, 0.05, 2.0)
	var b2 := Barrier.new().setup(-0.12, 0.0, 0.05, 2.0)
	ok(not Survival.can_survive([b1, b2], 0.0, 0.0, 1, 2.5), "instant tight cage must be unfair")
	# same cage with long warning but a wide gap: fair
	var b3 := Barrier.new().setup(1.0, 0.0, 0.8, 2.0)
	var b4 := Barrier.new().setup(-1.0, 0.0, 0.8, 2.0)
	ok(Survival.can_survive([b3, b4], 0.0, 0.0, 1, 2.5), "wide cage must be fair")
	for h in [m, b1, b2, b3, b4]:
		h.free()
	var t0 := Time.get_ticks_usec()
	var many: Array = []
	for i in 6:
		many.append(Meteor.new().setup(i * 1.0, 0.0, 0.3, 100.0))
	for i in 20:
		Survival.can_survive(many, 0.0, 0.0, 1, 2.4)
	var per := (Time.get_ticks_usec() - t0) / 20.0 / 1000.0
	print("  survival check with 6 hazards: %.2f ms" % per)
	ok(per < 8.0, "survival check fast enough (%.2f ms)" % per)
	for h in many:
		h.free()


func test_save(save) -> void:
	save.reset_all()
	var r1: Dictionary = save.submit_run(12)
	ok(r1["record"], "first run is a record")
	ok(r1["unlocked"].has(1), "MINTY unlocked at 12")
	var r2: Dictionary = save.submit_run(5)
	ok(not r2["record"], "lower score is not a record")
	save.skin = 1
	save.save_data()
	save.best = 0; save.games = 0; save.skin = 0
	save.load_data()
	ok(save.best == 12 and save.games == 2 and save.total == 17, "stats persisted (%d,%d,%d)" % [save.best, save.games, save.total])
	ok(save.skin == 1, "skin persisted")
	ok(not save.is_unlocked(2), "BERRY still locked")
	save.reset_all()


func test_difficulty() -> void:
	var d := Director.new()
	d.reset(1, 0.0)
	var prev := -1.0
	var mono := true
	for i in 300:
		var w := d.omega(i * 1.0)
		if w < prev - 1e-6:
			mono = false
		prev = w
	ok(mono, "omega never decreases")
	ok(absf(d.level(0.0)) < 0.001 and d.level(400.0) > 0.999, "level spans 0..1")
	ok(d.omega(400.0) <= 3.46, "speed capped")
	var base := Director.new(); base.reset(1, 12.0)
	var easy := Director.new(); easy.reset(1, 2.0)
	var hard := Director.new(); hard.reset(1, 60.0)
	ok(easy.level(20.0) < base.level(20.0) and hard.level(20.0) > base.level(20.0), "adaptive offset works")


func test_simulation(save) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	var dt := 1.0 / 60.0
	var total_hazards := 0
	var deaths := 0
	var counts := {}
	for run in 4:
		main.start_run()
		var frames := 0
		var t_start := Time.get_ticks_msec()
		while main.state == main.S.PLAYING and frames < 60 * 150:
			if frames % 2 == 0 and TestBot.decide(main):
				main._flip()
			main._grace = 0.0
			main._process(dt)
			frames += 1
			for h in main.hazards:
				if not h.has_meta("counted"):
					h.set_meta("counted", true)
					var k: String = h.get_class() if h.get_script() == null else h.get_script().get_global_name()
					counts[k] = counts.get(k, 0) + 1
		var survived: float = main.gt
		total_hazards += main.director.committed
		if main.state != main.S.PLAYING:
			deaths += 1
		print("  run %d: survived %.1fs score %d patterns %d rejected %d omega %.2f (%.1fs real)" % [run, survived, main.score,
			main.director.committed, main.director.rejected, main.player.omega, (Time.get_ticks_msec() - t_start) / 1000.0])
		ok(main.state == main.S.PLAYING, "fair bot survives 150s in run %d (died at %.1fs)" % [run, survived])
		if main.state == main.S.DYING:
			main._game_over()
	print("  hazards by type: ", counts)
	# human-like bot: perceives hazards 0.3s late and decides every 0.1s -> rough run-length estimate
	var lens: Array = []
	for run in 12:
		main.start_run()
		var frames := 0
		while main.state == main.S.PLAYING and frames < 60 * 240:
			if frames % 6 == 0:
				var seen: Array = main.hazards.filter(func(h): return h.t_spawn <= main.gt - 0.35)
				var p = main.player
				if not Survival.can_survive(seen, main.gt, p.angle, p.dir, p.omega, false) \
						and Survival.can_survive(seen, main.gt, p.angle, -p.dir, p.omega, false):
					main._flip()
			main._grace = 0.0
			main._process(dt)
			frames += 1
		lens.append(snappedf(main.gt, 0.1))
		if main.state == main.S.DYING:
			main._game_over()
	lens.sort()
	print("  human-like bot run lengths (s): ", lens)
	ok(counts.size() >= 3, "all hazard types appear")
	# rapid restarts: no leaks of hazards
	for i in 20:
		main.start_run()
		for f in 30:
			main._process(dt)
	ok(main.hazards.size() < 6, "restart clears the field")
	main.queue_free()
	save.reset_all()
