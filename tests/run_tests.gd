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
	await process_frame   # let autoloads run their _ready() first
	var save = get_root().get_node("Save")
	save.path = "user://test_save.cfg"
	save.reset_all()
	if "--only=obstacles" in OS.get_cmdline_user_args():
		test_new_obstacles()
		print("\n%d checks, %d failed" % [checks, fails])
		quit(1 if fails > 0 else 0)
		return
	print("== geometry: danger() matches real distances")
	test_geometry()
	print("== survival checker")
	test_survival()
	print("== save / load")
	test_save(save)
	print("== difficulty curve")
	test_difficulty()
	print("== monetization")
	await test_monetization(save)
	print("== economy")
	await test_economy(save)
	print("== abilities")
	await test_abilities(save)
	print("== menu banners")
	await test_banners(save)
	print("== orbit shapes")
	test_orbits()
	print("== missions, achievements, cloud, l10n")
	test_progress(save)
	print("== new obstacles (worlds 9-16)")
	test_new_obstacles()
	print("== fairness on every world shape")
	await test_duels(save)
	await test_worlds(save)
	print("== gameplay simulation with fair bot")
	await test_simulation(save)
	await test_analytics(save)
	await test_tutorial(save)
	await test_gestures(save)
	await test_events(save)
	await test_surges(save)
	await test_v120(save)
	await test_v121(save)
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
	# non-round orbits (ellipses, offset circles): collisions follow the real curve, so the
	# player never dies more than a hair away from a hazard (hitbox is already smaller than the art)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst_ghost := 0.0
	var big_miss := 0
	var worst_seg := 0.0
	var seg_miss := 0
	for si in Stages.LIST.size():
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		for k in Orbit.count():
			for i in 60:
				var a0 := rng.randf_range(-PI, PI)
				var rr := rng.randf_range(6.0, 12.0)
				var p := Orbit.pos(k, a0) + Vector2(cos(a0), sin(a0)) * rng.randf_range(-rr, rr)
				var iv: Array = []
				Hazard.point_danger(p, rr, k, iv)
				var q0 := p + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40))
				var siv: Array = []
				Hazard.segment_danger(q0, p, 6.0, k, siv)
				for j in 240:
					var a := a0 + (j - 120) * 0.004
					var pa := Orbit.pos(k, a)
					var gap := pa.distance_to(p) - rr
					if _in_iv(iv, a):
						worst_ghost = maxf(worst_ghost, gap)
					elif gap < -1.0:
						big_miss += 1
					var sd := Geometry2D.get_closest_point_to_segment(pa, q0, p).distance_to(pa) - 6.0
					if _in_iv(siv, a):
						worst_seg = maxf(worst_seg, sd)
					elif sd < -1.0:
						seg_miss += 1
	Orbit.reset()
	ok(worst_ghost < 2.0 and big_miss == 0, "point hazards exact on every orbit shape (ghost %.1f px, misses %d)" % [worst_ghost, big_miss])
	ok(worst_seg < 3.0 and seg_miss == 0, "beams exact on every orbit shape (ghost %.1f px, misses %d)" % [worst_seg, seg_miss])


func _in_iv(iv: Array, a: float) -> bool:
	for v in iv:
		if absf(Orbit.ang_diff(a, v.x)) < v.y:
			return true
	return false


func test_survival() -> void:
	# reaction time: a meteor that can only be dodged by tapping right away is fair for the
	# perfect checker but not for a human, who needs ~0.25 s to see it first
	var th := Meteor.time_to_orbit(0.05, 600.0, Orbit.R)
	var quick := Meteor.new().setup(2.5 * th, 0.0, 0.05, 600.0)
	var instant := Survival.can_survive([quick], 0.0, 0.0, 1, 2.5)
	var human := Survival.can_survive([quick], 0.0, 0.0, 1, 2.5, true, 0, Survival.MARGIN, Survival.TAP_GAP, Survival.HUMAN_REACT)
	ok(instant and not human, "pattern needing an instant tap is rejected for humans (hit at %.2fs)" % th)
	quick.free()
	# a slower meteor (seen in time) stays fair with the reaction window
	var slow := Meteor.new().setup(2.5 * Meteor.time_to_orbit(0.3, 120.0, Orbit.R), 0.0, 0.3, 120.0)
	ok(Survival.can_survive([slow], 0.0, 0.0, 1, 2.5, true, 0, Survival.MARGIN, Survival.TAP_GAP, Survival.HUMAN_REACT), "normal meteor fair with reaction time")
	slow.free()
	# reaction-proof check: a second meteor waits exactly where an early tap would take the
	# player. Escapable if you do not touch, but unfair for someone who tapped before seeing it.
	var w := 2.5
	# the trap lands just after the reaction window, where a tap at 0.06 s would have taken you
	var t_hit := Meteor.time_to_orbit(0.02, 360.0, Orbit.R)
	var safe := Meteor.new().setup(w * Meteor.time_to_orbit(0.3, 120.0, Orbit.R) + 1.6, 0.0, 0.3, 120.0)
	var trap := Meteor.new().setup(w * (2.0 * 0.06 - t_hit), 0.0, 0.02, 360.0)
	var pair: Array = [safe, trap]
	var plain := Survival.can_survive(pair, 0.0, 0.0, 1, w, true, 0, Survival.MARGIN, Survival.HUMAN_GAP, Survival.HUMAN_REACT)
	var rob := Survival.robust(pair, 0, 0.0, 0.0, 1, w, 0, Survival.MARGIN, Survival.HUMAN_GAP, Survival.HUMAN_REACT)
	ok(plain and not rob, "trap for an early tap is rejected by the reaction-proof check (%s %s)" % [plain, rob])
	ok(Survival.robust([safe], 0, 0.0, 0.0, 1, w, 0, Survival.MARGIN, Survival.HUMAN_GAP, Survival.HUMAN_REACT), "a plain far meteor passes the reaction-proof check")
	for h in pair:
		h.free()
	# shared cache gives the same answers as fresh checks
	var field: Array = [Meteor.new().setup(1.0, 0.0, 0.3, 120.0), Spiky.new().setup(-1.2, 0.0, 0.5, 2.0)]
	var cache := {}
	var same := true
	for i in 12:
		var extra := Meteor.new().setup(i * 0.5, 0.2, 0.3, 140.0)
		var all: Array = field.duplicate()
		all.append(extra)
		var fresh := Survival.can_survive(all, 0.0, 0.3, 1, 2.8, true, 0, 0.12, 0.17, 0.25)
		var cached := Survival.can_survive(all, 0.0, 0.3, 1, 2.8, true, 0, 0.12, 0.17, 0.25, 0.0, cache, field.size())
		same = same and fresh == cached
		extra.free()
	ok(same, "cached danger masks give the same answers")
	for h in field:
		h.free()
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
	var minty := Catalog.find("skins", "minty")
	var r1: Dictionary = save.submit_run(12)
	ok(r1["record"], "first run is a record")
	ok(not save.is_unlocked(minty), "MINTY still locked at 12")
	save.best = 0; save.games = 0; save.total = 0
	r1 = save.submit_run(30)
	ok(r1["unlocked"].has(minty), "MINTY unlocked at 30")
	var r2: Dictionary = save.submit_run(5)
	ok(not r2["record"], "lower score is not a record")
	save.skin = minty
	save.save_data()
	save.best = 0; save.games = 0; save.skin = 0
	save.load_data()
	ok(save.best == 30 and save.games == 2 and save.total == 35, "stats persisted (%d,%d,%d)" % [save.best, save.games, save.total])
	ok(save.skin == minty, "skin persisted")
	# rarity catalog
	var last_rank := 0
	var sorted := true
	for sk in Catalog.SKINS:
		var rk: int = Catalog.RARITIES.find(sk["rarity"])
		sorted = sorted and rk >= last_rank
		last_rank = rk
		ok(FileAccess.file_exists("res://assets/sprites/char_%s.png" % sk["id"]), "sprite for skin %s" % sk["id"])
	ok(sorted and Catalog.SKINS.size() >= 26, "skins listed by rarity (%d)" % Catalog.SKINS.size())
	# old saves stored the skin index: index 9 was COOKIE
	ok(Catalog.SKINS[Catalog.skin_index(9)]["id"] == "cookie" and Catalog.skin_index("nova") == Catalog.find("skins", "nova"), "legacy skin index maps to id")
	ok(save._seen_ids([0, 5, "volt"]) == ["poppy", "cosmo", "volt"], "legacy seen list converts to ids")
	# score skins (1.0.21: by score, no longer by world reached)
	var ghosty := Catalog.find("skins", "ghosty")
	save.stats["best_world"] = 16
	ok(not save.is_unlocked(ghosty), "GHOSTY locked below 260 points, whatever the world")
	save.best = 260
	ok(save.is_unlocked(ghosty) and save.submit_run(1)["unlocked"].has(ghosty), "GHOSTY unlocked at 260 points and announced")
	save.stats = {}
	var omega := Catalog.find("skins", "omega")
	save.best = 1499
	ok(not save.is_unlocked(omega), "OMEGA needs 1500")
	save.best = 1500
	ok(save.is_unlocked(omega), "OMEGA unlocked at 1500")
	save.best = 16
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
	ok(absf(d.level(0.0)) < 0.001 and d.level(400.0) <= Director.world_cap(1) + 1e-6, "world 1 never goes past its cap")
	d.world = 15
	ok(d.level(400.0) > 0.999, "level spans 0..1 (from world 15)")
	ok(d.omega(400.0) <= 3.31, "speed capped")
	ok(Director.world_cap(5) <= 0.5 + 1e-6 and Director.world_cap(1) < Director.world_cap(5) and Director.world_cap(20) == 1.0,
		"each world allows a bit more difficulty (world 5: %.2f)" % Director.world_cap(5))
	var w5 := Director.new(); w5.reset(1, 60.0); w5.world = 5
	ok(w5.level(90.0) <= 0.5 + 1e-6, "a strong player reaching world 5 early is not at full speed there")
	var base := Director.new(); base.reset(1, 12.0)
	var easy := Director.new(); easy.reset(1, 2.0)
	var hard := Director.new(); hard.reset(1, 60.0)
	for dd in [base, easy, hard]:
		dd.world = 15
	ok(easy.level(20.0) < base.level(20.0) and hard.level(20.0) > base.level(20.0), "adaptive offset works")


func test_monetization(save) -> void:
	var mon = get_root().get_node("Monetization")
	mon.use_test_providers()
	save.reset_all()
	var now := [1000.0]
	mon.clock = func() -> float: return now[0]
	# interstitials: never for new players, never during a run, paced by runs and time
	save.games = 9
	save.sessions = 3
	save.stats["days_played"] = 5
	for i in 5:
		mon.on_game_over()
	ok(not mon.should_show_interstitial(), "new players: no interstitial in their first 10 runs")
	save.games = 40
	save.stats["days_played"] = 1
	ok(not mon.should_show_interstitial(), "new players: no interstitial on their first day of play")
	save.stats["days_played"] = 2
	save.sessions = 1
	ok(not mon.should_show_interstitial(), "no interstitial in the very first session")
	save.sessions = 3
	ok(mon.should_show_interstitial(), "interstitial allowed after grace + 3 runs")
	mon.on_game_over(true)
	ok(not mon.should_show_interstitial(), "never right after a new record")
	mon.on_game_over()
	mon.run_active = true
	ok(not mon.should_show_interstitial(), "never an interstitial during a run")
	ok(not mon.show_rewarded("continue"), "never a rewarded ad during a run")
	mon.run_active = false
	var called := [0]
	mon.between_runs(func(): called[0] += 1)
	await process_frame
	await process_frame
	ok(called[0] == 1, "between_runs continues after the interstitial")
	mon.on_game_over(); mon.on_game_over()
	ok(not mon.should_show_interstitial(), "only 2 retries since the last ad: no ad yet")
	mon.on_game_over()
	ok(not mon.should_show_interstitial(), "3 retries but less than 2.5 minutes: no ad yet")
	now[0] += MonetizationConfig.INTERSTITIAL_COOLDOWN
	ok(mon.should_show_interstitial(), "ad after 3 retries and 2.5 minutes")
	save.grant("no_ads")
	ok(not mon.should_show_interstitial(), "NO ADS removes interstitials")
	ok(mon.can_continue(10, false), "rewarded continue still offered with NO ADS")
	ok(mon.continue_is_free(), "NO ADS: first continue of the day is free")
	save.free_continue_day = save.day_number()
	ok(not mon.continue_is_free(), "then continues are videos again until tomorrow")
	save.free_continue_day = -1
	# SUPPORTER no longer includes COINS x2; bigger coin bags
	save.purchases = ["supporter"]
	ok(save.owns("star_pack") and save.owns("no_ads") and not save.owns("coins_x2"), "supporter covers the packs, not coins x2")
	save.purchases = []
	var c0: int = save.coins
	mon.buy("coins_12000")
	await process_frame
	ok(save.coins == c0 + 12000, "12000 coin bag")
	ok(not mon.can_continue(10, true), "only one continue per run")
	ok(not mon.can_continue(2, false), "no continue for tiny scores")
	# purchases
	save.reset_all()
	ok(not save.is_unlocked(6), "premium skin locked before purchase")
	var results: Array = []
	var cb := func(id, okk, _m): results.append([id, okk])
	mon.purchase_result.connect(cb)
	mon.store.fail_next = true
	mon.buy("star_pack")
	await process_frame
	ok(not save.owns("star_pack"), "cancelled purchase grants nothing")
	mon.buy("star_pack")
	await process_frame
	ok(save.owns("star_pack") and save.is_unlocked(Catalog.find("skins", "goldie")) and save.is_unlocked(Catalog.find("skins", "panda")), "STAR PACK unlocks premium skins")
	mon.buy("supporter")
	await process_frame
	ok(save.owns("no_ads"), "SUPPORTER includes NO ADS")
	save.load_data()
	ok(save.owns("supporter") and save.owns("star_pack"), "purchases persisted")
	mon.purchase_result.disconnect(cb)
	# continue flow inside the real game loop
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.start_run()
	for f in 120:
		main._process(1.0 / 60.0)
	main.score = 12
	main._die()
	for f in 60:
		main._process(1.0 / 60.0)
	ok(main.state == main.S.OVER and save.games == 1, "game over registered")
	main._on_continue_pressed()
	await process_frame
	await process_frame
	ok(main.state == main.S.PLAYING and main.score == 12 and main.continued, "continue revives with same score")
	ok(save.games == 0, "continued run is not double counted")
	ok(main.hazards.is_empty() and main.shield_until > main.gt, "field cleared + shield after continue")
	main._die()
	for f in 60:
		main._process(1.0 / 60.0)
	ok(save.games == 1 and save.best == 12, "final run counted once")
	ok(not mon.can_continue(main.score, main.continued), "second continue refused")
	main.queue_free()
	await process_frame
	save.reset_all()
	mon.clock = func() -> float: return Time.get_ticks_msec() / 1000.0


func test_economy(save) -> void:
	var mon = get_root().get_node("Monetization")
	mon.use_test_providers()
	save.reset_all()
	# daily gift streak
	var day0 := 1_800_000_000.0
	save.clock_override = day0
	ok(save.daily_available(), "daily gift available on first day")
	var g: Dictionary = save.claim_daily()
	ok(g["day"] == 1 and save.coins == 30, "day 1 gives 30 coins (%d)" % save.coins)
	ok(not save.daily_available() and save.claim_daily().is_empty(), "only once per day")
	save.clock_override = day0 + 86400
	ok(save.daily_preview()["day"] == 2, "next day continues the streak")
	save.claim_daily(2)
	ok(save.coins == 30 + 80, "x2 doubles the gift")
	save.clock_override = day0 + 86400 * 4
	ok(save.daily_preview()["day"] == 1, "missing a day resets the streak")
	save.clock_override = -1.0
	# coin cosmetics
	save.coins = 100
	var robo := Catalog.find("skins", "robo")
	ok(not save.buy_item("skins", robo), "cannot buy without enough coins")
	save.coins = 2300
	ok(save.buy_item("skins", robo) and save.coins == 100 and save.is_unlocked(robo), "coin skin bought")
	ok(not save.buy_item("skins", robo), "cannot buy twice")
	ok(not save.buy_item("skins", Catalog.find("skins", "goldie")), "shop items not buyable with coins")
	# player level & abilities
	save.coins = 5000
	ok(not save.buy_ability("coins"), "locked ability can't be bought")
	var lv_before: int = save.level
	var gained: Array = save.add_xp(Upgrades.xp_next(1))
	ok(gained == [2] and save.level == lv_before + 1 and save.ability("coins") == 1, "level 2 unlocks COINS+ for free")
	ok(save.coins == 5000 + Upgrades.level_coins(2), "level-up pays coins")
	save.coins = Upgrades.PRICES[1]
	ok(Upgrades.PRICES[1] <= 400, "first upgrade is cheap (%d coins)" % Upgrades.PRICES[1])
	ok(save.buy_ability("coins") and save.ability("coins") == 2 and save.coins == 0, "ability upgraded with coins")
	ok(not save.buy_ability("coins"), "upgrade refused without coins")
	save.level = 15
	ok(save.ability("secondlife") == 0 and Upgrades.price("secondlife", 0) == 10000, "SECOND LIFE must be bought")
	save.abilities["shield"] = 3
	ok(Upgrades.price("shield", 3) == -1 and not save.buy_ability("shield"), "maxed ability can't be bought")
	var xp50 := 0
	for L in range(1, Upgrades.MAX_LEVEL):
		xp50 += Upgrades.xp_next(L)
	ok(xp50 > 150000 and xp50 < 260000, "level 50 needs %d XP (tuned curve)" % xp50)
	save.level = 1; save.xp = 0; save.abilities = {}
	# bundles & consumables
	save.coins = 0
	mon.buy("starter")
	await process_frame
	ok(save.owns("no_ads") and save.coins == 1000, "starter: no ads + 1000 coins")
	save.grant("starter")
	ok(save.coins == 1000, "bundle bonus only once (restore safe)")
	mon.buy("coins_1500")
	await process_frame
	mon.buy("coins_1500")
	await process_frame
	ok(save.coins == 4000, "coin bag is consumable (%d)" % save.coins)
	ok(not save.unlocked("trails", Catalog.find("trails", "rainbow")), "trail pack not owned yet")
	mon.buy("supporter")
	await process_frame
	ok(save.unlocked("trails", Catalog.find("trails", "rainbow")) and save.owns("star_pack"), "supporter unlocks all packs")
	# banner never shown to NO ADS owners
	mon.show_banner()
	ok(not mon.ads._banner.visible, "no banner for NO ADS owners")
	save.purchases = []
	mon.show_banner()
	ok(mon.ads._banner.visible, "banner shown in shop otherwise")
	mon.hide_banner()
	ok(not mon.ads._banner.visible, "banner hidden when leaving shop")
	# in-game: coins, XP, free continue, SHIELD ability
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	save.abilities["shield"] = 1
	main.start_run()
	ok(main.shield_hits == 1 and main.player.shield_boost, "SHIELD ability arms a shield every run")
	var m := Meteor.new().setup(main.player.angle, main.gt - 0.5, 0.0, 200.0)
	# force a meteor right on the player now
	m.t_danger_start = main.gt; m.t_danger_end = main.gt + 0.05
	m.t_launch = main.gt - (Meteor.R0 - Orbit.R) / 200.0
	main.hazards.append(m); main.hazards_root.add_child(m)
	main._process(1.0 / 120.0)
	ok(main.state == main.S.PLAYING and main.shield_hits == 0, "shield absorbed the hit")
	main.score = 30
	main.bubbles_popped = 2
	main._die()
	for f in 60:
		main._process(1.0 / 60.0)
	ok(save.coins == 3 + 2 + Upgrades.level_coins(2) and save.level == 2, "coins = score/10 + bubbles, first run reaches level 2 (%d)" % save.coins)
	save.purchases = ["no_ads"]
	ok(mon.can_continue(30, false) and mon.continue_is_free(), "NO ADS gives a free continue")
	main._on_continue_pressed()
	ok(main.state == main.S.PLAYING, "free continue revives without an ad")
	# pause: time freezes, resume counts down, quitting still counts the run
	main._pause()
	var gt0: float = main.gt
	for f in 30:
		main._process(1.0 / 60.0)
	ok(main.state == main.S.PAUSED and main.gt == gt0, "pause freezes the run")
	main._resume()
	for f in 90:
		main._process(1.0 / 60.0)
	ok(main.state == main.S.PLAYING, "resume returns to play after the countdown")
	ok(main.ui.blocks_tap(main.ui._pause_btn.get_global_rect().get_center()), "tapping the pause button does not flip")
	main.score = 60
	main._die()
	for f in 60:
		main._process(1.0 / 60.0)
	# level 2 unlocked COINS+ (x1.1): the whole run is now worth floor((6 + 2) * 1.1) = 8, 5 already paid
	var paid: int = 5 + Upgrades.level_coins(2) + int(floor(8 * Upgrades.coin_mult(1))) - 5
	ok(save.coins == paid, "continued run only pays the new coins (%d)" % save.coins)
	main.queue_free()
	await process_frame
	save.reset_all()


func test_orbits() -> void:
	Orbit.set_shape(Stages.LIST[3]["orbits"], true)
	var top := Orbit.radius(0, -PI * 0.5)
	var bottom := Orbit.radius(0, PI * 0.5)
	ok(bottom > top + 25.0, "candy orbit is off-center (top %.0f, bottom %.0f)" % [top, bottom])
	Orbit.set_shape(Stages.LIST[4]["orbits"], true)
	ok(Orbit.count() == 2 and Orbit.cross_list().size() == 4, "night: 2 orbits, 4 crossings (%d)" % Orbit.cross_list().size())
	var c: float = Orbit.cross_list()[0]["a"][0]
	ok(absf(Orbit.radius(0, c) - Orbit.radius(1, c)) < 1.5, "orbits meet at the crossing")
	var tr := Orbit.tap_result(c, 0, 1)
	ok(tr[0] == 1 and tr[1] == 1, "tap at a crossing switches orbit, keeps direction")
	ok(Orbit.tap_result(c + 0.6, 0, 1).slice(0, 2) == [0, -1], "tap elsewhere reverses")
	# two planets: figure-eight switching keeps the player on the same spot
	for si in [5, 6]:
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		ok(Orbit.planets().size() == 2 and Orbit.cross_list().size() == 2, "%s: 2 planets, 2 crossings" % Stages.LIST[si]["world"])
		var cx: Dictionary = Orbit.cross_list()[0]
		var r2 := Orbit.tap_result(cx["a"][0], 0, 1)
		ok(r2[0] == 1 and Orbit.pos(1, r2[2]).distance_to(Orbit.pos(0, cx["a"][0])) < 1.0, "%s: switch lands on the same point" % Stages.LIST[si]["world"])
		var t0: Vector2 = Orbit._tangent(0, cx["a"][0])
		var t1: Vector2 = Orbit._tangent(1, r2[2]) * r2[1]
		ok(t0.dot(t1) > 0.0, "%s: motion continues forward after switching" % Stages.LIST[si]["world"])
		ok(Orbit.extent() + 8.0 <= 96.0 and absf(Orbit.pos(0, 0).x) + 8.0 <= 90.0, "%s fits the screen" % Stages.LIST[si]["world"])
	# three planets: every orbit reachable, everything on screen, no orbit through a planet
	for si in [7, 8, 9]:
		var nm: String = Stages.LIST[si]["world"]
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		ok(Orbit.planets().size() == 3 and Orbit.cross_list().size() >= 4, "%s: 3 planets, %d crossings" % [nm, Orbit.cross_list().size()])
		var reach := {0: true}
		for it in 3:
			for kk in reach.keys():
				for o in Orbit.neighbors(kk):
					reach[o] = true
		ok(reach.size() == 3, "%s: every orbit reachable by switching" % nm)
		var maxx := 0.0
		var clear := INF
		for k in 3:
			for i in 90:
				var p := Orbit.pos(k, TAU * i / 90.0)
				maxx = maxf(maxx, absf(p.x))
				for pl in Orbit.planets():
					clear = minf(clear, p.distance_to(pl["c"]) - pl["r"])
		ok(maxx + 8.0 <= 90.0 and clear > Orbit.PLAYER_R + 2.0, "%s fits the screen (x %.0f) and clears planets (%.1f)" % [nm, maxx, clear])
		for cx in Orbit.cross_list():
			var kk2: int = cx["k"][0]
			var r3 := Orbit.tap_result(cx["a"][0], kk2, 1)
			ok(r3[0] == cx["k"][1] and Orbit.pos(r3[0], r3[2]).distance_to(Orbit.pos(kk2, cx["a"][0])) < 1.0, "%s: switch %d->%d keeps position" % [nm, kk2, r3[0]])
			break
	# link beam and comet: danger matches real distances
	Orbit.set_shape(Stages.LIST[5]["orbits"], true)
	var ln := Link.new().setup(0, 1, 0.0, 0.5, 2.0)
	var bad := 0
	for k in 2:
		for i in 180:
			var a := TAU * i / 180.0
			var p := Orbit.pos(k, a)
			var q := Geometry2D.get_closest_point_to_segment(p, ln._p0, ln._p1)
			var real := p.distance_to(q) < Orbit.PLAYER_R + Link.BEAM_HALF
			var said := ln.clearance(1.0, a, k) < 0.0
			if real and not said:
				bad += 1
	ok(bad == 0, "link beam never misses a real hit (%d misses)" % bad)
	ok(ln.clearance(0.2, 0.0, 0) == INF, "link harmless during warning")
	ln.free()
	var cm := Comet.new().setup(Orbit.pos(0, 0.5), 2.0, 0.0, 0.4, 160.0)
	bad = 0
	var t2 := cm.t_danger_start
	while t2 <= cm.t_danger_end:
		for k in 2:
			for i in 120:
				var a := TAU * i / 120.0
				var real2 := Orbit.pos(k, a).distance_to(cm.pos_at(t2)) < Comet.RADIUS + Orbit.PLAYER_R - 0.3
				if real2 and cm.clearance(t2, a, k) >= 0.0:
					bad += 1
		t2 += 0.01
	ok(bad == 0, "comet never misses a real hit (%d)" % bad)
	cm.free()
	Orbit.set_shape(Stages.LIST[4]["orbits"], true)
	c = Orbit.cross_list()[0]["a"][0]
	ok(Orbit.max_radius() + 8.0 <= 90.0, "widest orbit fits a 180px screen")
	# a closing cage ("crusher") on orbit 0: the only escape is switching orbit at the crossing
	var a0: float = c
	var m1 := Spiky.new().setup(c - 0.9, 0.0, 0.1, 4.0, 0.45, 0)
	var m2 := Spiky.new().setup(c + 0.9, 0.0, 0.1, 4.0, -0.45, 0)
	ok(Survival.can_survive([m1, m2], 0.0, a0, 1, 2.6, true, 0), "dual orbit crusher is fair (switch escapes)")
	Orbit.set_shape(Stages.LIST[0]["orbits"], true)
	var n1 := Spiky.new().setup(c - 0.9, 0.0, 0.1, 4.0, 0.45, 0)
	var n2 := Spiky.new().setup(c + 0.9, 0.0, 0.1, 4.0, -0.45, 0)
	ok(not Survival.can_survive([n1, n2], 0.0, a0, 1, 2.6, true, 0), "same crusher on a single orbit is unfair")
	for h in [m1, m2, n1, n2]:
		h.free()
	# pulse: only the gap is safe
	var pu := Pulse.new().setup(1.0, 0.0, 0.8, 0.6, 70.0)
	var mid := (pu.t_danger_start + pu.t_danger_end) * 0.5
	ok(pu.clearance(mid, 1.0) > 0.0 and pu.clearance(mid, 1.0 + PI) < 0.0, "pulse: gap safe, rest deadly")
	pu.free()
	Orbit.reset()


func test_progress(save) -> void:
	var prog = get_root().get_node("Progress")
	var l10n = get_root().get_node("L")
	save.reset_all()
	var day0 := 1_900_000_000.0
	var seen := {}
	var distinct := true
	var pool: int = prog.MISSIONS.size()
	for d in pool:
		save.clock_override = day0 + d * 86400
		var idx: Array = prog.daily_indices(save.day_number())
		distinct = distinct and idx.size() == 3 and idx[0] != idx[1] and idx[1] != idx[2] and idx[0] != idx[2]
		seen[idx[0]] = true
	ok(distinct and seen.size() == pool, "3 different missions a day, the whole pool of %d in %d days" % [pool, pool])
	save.clock_override = day0
	var first: Array = prog.daily_indices(save.day_number())
	save.clock_override = day0 + pool * 86400
	ok(prog.daily_indices(save.day_number()) == first, "missions repeat cyclically")
	ok(prog.missions().size() == 3 and not prog.weekly().is_empty(), "today has 3 missions + a weekly challenge")
	# complete today's missions whatever they are
	save.clock_override = day0
	var coins0: int = save.coins
	var lv0: int = save.level
	var expect := 0
	for m in prog.missions():
		expect += int(m["reward"])
	for i in 160:
		prog.run_started()
		prog.event("score_now", 60)
		prog.event("world", 6)
		prog.event("near"); prog.event("flip"); prog.event("bubble"); prog.event("coin", 20)
		for b in 3:
			prog.event("bubble")
		prog.run_finished(60, 6, 50.0)
	ok(prog.missions_left() == 0 and save.coins >= coins0 + expect, "all 3 missions complete and pay")
	ok(save.level > lv0, "missions give XP")
	save.clock_override = day0 + 86400
	ok(prog.missions_left() == 3, "new missions the next day")
	save.clock_override = -1.0
	# achievements
	save.submit_run(30)
	prog.run_finished(30, 3, 10.0)
	ok(save.achievements.has("score25") and save.achievements.has("first"), "achievements unlock from stats")
	ok(not save.achievements.has("score50"), "locked achievements stay locked")
	ok(prog.ACHIEVEMENTS.size() >= 30 and PlayGamesConfig.ACHIEVEMENTS.size() == prog.ACHIEVEMENTS.size(), "achievement list and Play Games ids match")
	var boards: Dictionary = PlayGamesConfig.LEADERBOARDS.duplicate()
	for pending in ["DAILY", "EVENT"]:
		if boards.get(pending, "") == "":
			print("  NOTE: %s board id not set yet (create the board in Play Console)" % pending)
			boards.erase(pending)
	var all_ids: Array = PlayGamesConfig.ACHIEVEMENTS.values() + boards.values()
	var uniq := {}
	for v in all_ids:
		uniq[v] = true
	ok(not all_ids.has("") and uniq.size() == all_ids.size(), "every Play Games id is set and unique")
	for a in prog.ACHIEVEMENTS:
		if a["id"] == "skins_all":
			ok(int(a["goal"]) == Catalog.SKINS.size(), "EVERY SKIN goal matches the catalog")
	ok(Stages.index_for_score(14) == 0 and Stages.index_for_score(15) == 1 and Stages.number_for_score(315) == 10
		and Stages.number_for_score(750) == 16 and Stages.number_for_score(830) == 17, "world spacing: closer early, 16 worlds")
	var gaps_grow := true
	for i in range(2, Stages.LIST.size()):
		gaps_grow = gaps_grow and int(Stages.LIST[i]["score"]) - int(Stages.LIST[i - 1]["score"]) >= int(Stages.LIST[i - 1]["score"]) - int(Stages.LIST[i - 2]["score"])
	ok(gaps_grow, "each world is at least as long as the previous one")
	# cloud merge: fresh install restores progress
	var cloud: Dictionary = save.export_data()
	cloud["best"] = 99; cloud["coins"] = 777; cloud["saved_at"] = save.saved_at + 100
	cloud["owned_items"] = ["skins:robo"]
	save.reset_all()
	save.saved_at = 0
	save.merge(cloud)
	ok(save.best == 99 and save.coins == 777 and save.is_unlocked(Catalog.find("skins", "robo")), "cloud save restores after reinstall")
	var older: Dictionary = save.export_data()
	older["coins"] = 5; older["saved_at"] = 1; older["best"] = 10
	save.merge(older)
	ok(save.coins == 777 and save.best == 99, "older cloud copy never lowers progress")
	# best runs from the cloud come back as JSON floats: no duplicates, shown as whole numbers
	save.top_scores = [{"s": 189, "w": 7, "d": "2026-11-05"}, {"s": 116, "w": 5, "d": "2026-11-06"}]
	var js: Dictionary = JSON.parse_string(JSON.stringify(save.export_data()))
	js["top_scores"].append({"s": 120.0, "w": 5.0, "d": "2026-11-04"})
	save.merge(js)
	save.merge(js)
	ok(save.top_scores.size() == 3 and save.top_scores.all(func(e): return e["s"] is int and e["w"] is int)
		and str(save.top_scores[0]["s"]) == "189" and save.top_scores[1]["s"] == 120,
		"cloud merge: best runs stay whole numbers, each run once (no 189 + 189.0)")
	ok(save.clean_tops([{"s": 189}, {"s": 189.0}, {"s": 50, "w": 2, "d": "x"}]).size() == 2, "old saves: duplicated best runs cleaned on load")
	# regions
	ok(PlayGamesConfig.region("es_MX") == "CENTRAL_AMERICA" and PlayGamesConfig.region("es_DO") == "CENTRAL_AMERICA" \
		and PlayGamesConfig.region("pt_BR") == "SOUTH_AMERICA" and PlayGamesConfig.region("es_AR") == "SOUTH_AMERICA" \
		and PlayGamesConfig.region("es_ES") == "EUROPE" and PlayGamesConfig.region("en_US") == "NORTH_AMERICA", "regional boards by locale")
	# localization: 4 languages for every key, every glyph present in the pixel font
	var font: FontFile = load("res://assets/font/pixel.fnt")
	var missing := {}
	var bad_keys := 0
	for key in l10n.T:
		if l10n.T[key].size() != 4:
			bad_keys += 1
		if key == "SHARE_TEXT" or key.begins_with("NOTIF_") or key.begins_with("DUEL_SHARE"):
			continue   # shown by the system (share sheet / notifications), not the pixel font
		for txt in l10n.T[key]:
			for ch in txt:
				if ch != "%" and not font.has_char(ch.unicode_at(0)):
					missing[ch] = true
	ok(bad_keys == 0, "every string has EN/ES/PT/PT-BR")
	ok(missing.is_empty(), "pixel font covers all translated text %s" % str(missing.keys()))
	for code in l10n.LANGS:
		l10n.set_lang(code)
		ok(l10n.t("PLAY") != "" and l10n.t("M_RUNS", 3).contains("3"), "language %s works" % code)
	# abilities screen rows: name and description must fit left of the price button
	var ui_script: Script = load("res://scripts/ui/ui.gd")
	var too_wide: Array = []
	for code in l10n.LANGS:
		l10n.set_lang(code)
		for ab in Upgrades.ABILITIES:
			var texts: Array = [l10n.t("AB_" + ab["id"].to_upper())]
			for lv in range(1, int(ab["max"]) + 1):
				texts.append(ui_script.ability_desc(ab["id"], lv))
			for tx in texts:
				if font.get_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 158 - 46 - 19 - 2:
					too_wide.append(code + ":" + tx)
	ok(too_wide.is_empty(), "ability texts fit their row %s" % str(too_wide))
	# two-tab headers (skins/trails, packs/coins, ranking/awards): label + icon fit the tab
	var tab_wide: Array = []
	for code in l10n.LANGS:
		l10n.set_lang(code)
		for key in ["SKINS", "TRAILS", "PACKS", "COINS", "RANKING", "ACHIEVEMENTS"]:
			if font.get_string_size(l10n.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > floori(164.0 / 2) - 4 - 6 - 13:
				tab_wide.append(code + ":" + l10n.t(key))
	ok(tab_wide.is_empty(), "tab labels fit their tab %s" % str(tab_wide))
	var panel_wide: Array = []
	for code in l10n.LANGS:
		l10n.set_lang(code)
		for key in ["COINS_TIP", "STORE_OFFLINE", "STORE_PLAY", "AB_TIP", "PLAY_GAMES_OFF", "VIDEO_TOMORROW"]:
			if font.get_string_size(l10n.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 158:
				panel_wide.append(code + ":" + l10n.t(key))
	ok(panel_wide.is_empty(), "centered panel texts fit %s" % str(panel_wide))
	var shop_wide: Array = []
	for code in l10n.LANGS:
		l10n.set_lang(code)
		for id in MonetizationConfig.PRODUCT_INFO:
			for key in [MonetizationConfig.PRODUCT_INFO[id]["name"], MonetizationConfig.PRODUCT_INFO[id]["desc"]]:
				if font.get_string_size(l10n.t(key), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > 158 - 54 - 19 - 1:
					shop_wide.append(code + ":" + l10n.t(key))
	ok(shop_wide.is_empty(), "shop product texts fit their row %s" % str(shop_wide))
	l10n.set_lang("en")
	save.reset_all()


func test_abilities(save) -> void:
	save.tutorial_done = true; save.jump_tip_done = true   # bots: no tutorial (see test_tutorial)
	# reminders: one a day at 18:45 local, never at night, rescheduled on every exit
	var day0 := 1_900_000_000 - posmod(1_900_000_000, 86400)   # a UTC midnight
	ok(Notifier.delay_to(1, day0 + 10 * 3600, 0) == 86400 + 8 * 3600 + 45 * 60, "reminder tomorrow at 18:45 (from 10:00)")
	ok(Notifier.delay_to(1, day0 + 23 * 3600, 0) == 19 * 3600 + 45 * 60, "from 23:00: tomorrow 18:45, not at night")
	ok(Notifier.delay_to(1, day0 + 10 * 3600, -5 * 3600) == 86400 + 13 * 3600 + 45 * 60, "local time zone respected (UTC-5)")
	save.reset_all()
	var pl := Notifier.plan(save, day0 + 10 * 3600, 0)
	ok(pl.size() == 3 and pl[1][1] - pl[0][1] == 2 * 86400 and pl[2][1] - pl[0][1] == 6 * 86400, "new player: reminders at day 1, 3 and 7")
	# with a record: day 2 "world N is waiting, X points to go", day 5 "your record is N"
	save.best = 120
	var pl2 := Notifier.plan(save, day0 + 10 * 3600, 0)
	var nw := Stages.next_world(120)
	var l10n2 = get_root().get_node("L")
	var texts: Array = pl2.map(func(n): return str(n[2]))
	ok(pl2.size() == 5 and texts.has(l10n2.t("NOTIF_NEXT_WORLD", [l10n2.t("NOTIF_WORLD_N", int(nw[0])), int(nw[1])]))
		and texts.has(l10n2.t("NOTIF_RECORD", 120)), "with a record: 5 reminders, next world and record ones")
	var ids := {}
	for n in pl2:
		ids[n[0]] = true
	ok(ids.size() == pl2.size(), "every reminder has its own id")
	save.notifications = false
	ok(Notifier.plan(save, day0, 0).is_empty(), "no reminders when turned off in Settings")
	save.reset_all()
	# offers at the right moment
	var base := {"games": 30, "score": 10, "best": 50, "record": false, "coins": 0, "upgrade_cost": -1, "ad_shown": false,
		"session_shown": false, "today": 100, "owned": func(_id): return false, "last_shown": {}}
	var o := func(over: Dictionary) -> String:
		var c := base.duplicate()
		c.merge(over, true)
		return str(Offers.pick(c).get("id", ""))
	ok(o.call({"games": 3, "ad_shown": true}) == "", "no offers in the first runs")
	ok(o.call({"record": true, "ad_shown": true}) == "", "never an offer after a record")
	ok(o.call({"session_shown": true, "ad_shown": true}) == "", "one offer per session at most")
	ok(o.call({"ad_shown": true}) == "no_ads", "after a forced ad: NO ADS")
	ok(o.call({"ad_shown": true, "last_shown": {"no_ads": 99}}) == "star_pack", "same offer not again within 3 days")
	ok(o.call({"score": 48}) == "starter", "2 points short of the record: starter pack")
	ok(o.call({"score": 48, "owned": func(id): return id == "starter"}) == "coins_5000", "starter owned: a coin bag")
	ok(o.call({"games": 70, "coins": 150, "upgrade_cost": 300}) == "coins_1500", "150 coins short of an upgrade: 1500 coins")
	ok(o.call({"games": 65, "coins": 50, "upgrade_cost": 300}) == "trail_pack", "too far from the upgrade: no coin offer (milestone pack instead)")
	ok(o.call({"games": 40}) == "", "nothing special: no offer")
	# offers carry real bonus coins for a limited time (24 h, milestones 48 h); the countdown is honest
	var lv: Dictionary = Offers.make_live({"id": "no_ads", "why": "OFFER_ADS"}, 1000.0)
	ok(lv["until"] == 1000 + 24 * 3600 and lv["bonus"] == Offers.BONUS["no_ads"], "offer bonus lasts 24 h")
	ok(Offers.make_live({"id": "trail_pack", "why": "OFFER_MILESTONE"}, 0.0)["until"] == 48 * 3600, "milestone offers last 48 h")
	ok(Offers.seconds_left(lv, "no_ads", 1000.0 + 3600) == 23 * 3600 and Offers.seconds_left(lv, "star_pack", 1000.0) == 0, "countdown only for the offered product")
	ok(Offers.seconds_left(lv, "no_ads", 1000.0 + 25 * 3600) == 0, "bonus gone after 24 h")
	ok(Offers.clock(23 * 3600 + 59 * 60 + 12) == "23:59:12" and Offers.clock(5 * 3600 + 1, true) == "6H" and Offers.clock(42 * 60, true) == "42M", "countdown text")
	for id in MonetizationConfig.PRODUCTS:
		ok(not Offers.BONUS.has(id) or Offers.BONUS[id] > 0, "bonus defined for %s" % id)
	var mon = get_root().get_node("Monetization")
	mon.use_test_providers()
	save.reset_all()
	var tnow := [100000.0]
	mon.unix = func() -> float: return tnow[0]
	save.games = 30
	mon.offer_this_session = false
	mon.ad_since_offer = true
	var off: Dictionary = mon.offer_for(10, false)
	ok(off.get("id", "") == "no_ads" and mon.offer_secs("no_ads") == 24 * 3600 and mon.live_offer_id() == "no_ads", "shown offer starts its countdown")
	var c1: int = save.coins
	mon.buy("no_ads")
	await process_frame
	await process_frame
	ok(save.owns("no_ads") and save.coins == c1 + Offers.BONUS["no_ads"] and save.offer_live.is_empty(), "bought during the countdown: bonus coins (+%d)" % (save.coins - c1))
	ok(mon.offer_secs("no_ads") == 0 and mon.live_offer_id() == "", "owned: no countdown left")
	save.reset_all()
	save.games = 30
	mon.offer_this_session = false
	mon.ad_since_offer = true
	mon.offer_for(10, false)
	tnow[0] += 24 * 3600 + 1
	c1 = save.coins
	mon.buy("no_ads")
	await process_frame
	await process_frame
	ok(save.owns("no_ads") and save.coins == c1 and mon.last_bonus == 0, "after the countdown: same price, no bonus")
	mon.unix = func() -> float: return Time.get_unix_time_from_system()
	save.reset_all()
	# altitude: from the sky to deep space, always climbing; layers start with a world
	var prev := -1.0
	var climbing := true
	for sc in range(0, 1200, 5):
		var km: float = Stages.altitude_km(sc)
		climbing = climbing and km > prev
		prev = km
	ok(climbing, "altitude always grows with the score")
	ok(absf(Stages.altitude_km(315) - 100.0) < 0.01 and absf(Stages.altitude_km(585) - 384000.0) < 1.0, "edge of space at 100 km, the Moon at 384,000 km")
	var starts := []
	for e in Stages.LIST:
		starts.append(int(e["score"]))
	var layers_ok := true
	for ly in Stages.LAYERS:
		layers_ok = layers_ok and (int(ly[0]) in starts or int(ly[0]) == Stages.LOOP_FROM)
	ok(layers_ok and Stages.layer(0) == 0 and Stages.layer(320) == 4 and Stages.layer(5000) == Stages.LAYERS.size() - 1, "altitude layers begin with a world")
	ok(Stages.altitude_text(7.44, false, "KM") == "7.4 KM" and Stages.altitude_text(230.0, false, "KM") == "230 KM" and Stages.altitude_text(22400.0, false, "KM") == "22,400 KM"
		and Stages.altitude_text(384000.0, false, "KM") == "384K KM" and Stages.altitude_text(1500000.0, false, "KM") == "1.5M KM", "altitude text (%s)" % Stages.altitude_text(22400.0, false, "KM"))
	var widest := 0.0
	for sc in range(0, 6000, 7):
		for mi in [true, false]:
			widest = maxf(widest, load("res://assets/font/pixel.fnt").get_string_size(Stages.altitude_text(Stages.altitude_km(sc), mi, "KM"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	ok(widest <= 56.0, "altitude never runs into the score (widest %d px)" % widest)
	# free ability levels by watching videos: 3 videos for level 2, 5 for level 3, one level a day
	save.reset_all()
	save.level = 5
	save.abilities = {"coins": 1, "shield": 1, "magnet": 2}
	var tgt: String = save.video_target()
	ok(tgt == "coins" and save.video_needed(tgt) == 3, "video upgrade goes to a level-1 ability (%s)" % tgt)
	ok(save.video_ad_watched() == "" and save.video_ad_watched() == "", "2 videos: not yet")
	ok(save.video_ad_watched() == "coins" and save.ability("coins") == 2, "3rd video: +1 level for free")
	ok(not save.video_open_today() and save.video_ad_watched() == "", "only one video level a day")
	save.clock_override = Time.get_unix_time_from_system() + 86400.0
	ok(save.video_open_today() and save.video_target() == "shield", "next day: the next lowest ability")
	save.abilities = {"coins": 3, "shield": 3, "magnet": 3}
	ok(save.video_target() == "", "no video levels above level 3")
	save.clock_override = -1.0
	# COINS x2 FOREVER doubles what a run pays
	save.reset_all()
	var mx = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(mx)
	await process_frame
	mx.set_process(false)
	mx.ui.hide_popup()
	mx.start_run()
	mx.score = 50
	mx.picked_coins = 10
	var plain: int = mx._run_coins()
	save.purchases = ["coins_x2"]
	ok(mx._run_coins() == plain * 2, "COINS x2 doubles run coins (%d -> %d)" % [plain, mx._run_coins()])
	mx.queue_free()
	await process_frame
	Orbit.reset()
	# old saves: consumable boosts become coins, once
	save.reset_all()
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "coins", 10)
	cfg.set_value("shop", "boosts", {"shield": 2, "rush": 1, "teleport": 1})
	cfg.save(save.path)
	save.load_data()
	ok(save.coins == 10 + 300 + 100 + 120, "old boosts refunded in coins (%d)" % save.coins)
	save.save_data()
	save.load_data()
	ok(save.coins == 530, "boost refund only once")
	# HEADSTART: capped by its level and by the best world reached - 1
	save.reset_all()
	save.abilities["headstart"] = 2
	save.stats["best_world"] = 9
	save.start_world = 8
	ok(save.headstart_max() == 5 and save.chosen_start_world() == 5, "headstart level 2 starts at world 5 at most")
	save.stats["best_world"] = 4
	ok(save.chosen_start_world() == 3, "headstart never skips past your best world - 1")
	save.abilities["headstart"] = 0
	ok(save.chosen_start_world() == 1, "no headstart starts at world 1")
	ok(Stages.bounds(0) == Vector2i(0, 15) and Stages.bounds(70) == Vector2i(60, 90)
		and Stages.bounds(850) == Vector2i(830, 890), "world progress bounds")
	# region override
	save.region = "EUROPE"
	ok(get_root().get_node("Progress").region() == "EUROPE", "region picked in settings wins")
	save.region = ""
	ok(get_root().get_node("Progress").region() == PlayGamesConfig.region(), "AUTO region follows the phone")
	# in-app review: after some time (runs, days, minutes), at a happy moment, once a month, 3 at most
	var rc := {"happy": true, "games": 20, "days": 3, "minutes": 40.0, "asks": 0, "last_day": -9999, "today": 100}
	var ask := func(over: Dictionary) -> bool:
		var c := rc.duplicate()
		c.merge(over, true)
		return Reviewer.should_ask(c)
	ok(ask.call({}), "review prompt after a while, at a happy moment")
	ok(not ask.call({"games": 3}) and not ask.call({"days": 1}) and not ask.call({"minutes": 10.0}), "not in the first runs, first day or first minutes")
	ok(not ask.call({"happy": false}), "only at a happy moment")
	ok(not ask.call({"asks": 1, "last_day": 90}) and ask.call({"asks": 1, "last_day": 70}), "at most once every 30 days")
	ok(not ask.call({"asks": 3}), "3 prompts at most")
	ok(Reviewer.happy(true, 80, false, false, false) and not Reviewer.happy(true, 10, false, false, false)
		and Reviewer.happy(false, 0, true, false, false) and Reviewer.happy(false, 0, false, true, false)
		and Reviewer.happy(false, 0, false, false, true) and not Reviewer.happy(false, 90, false, false, false), "happy moments: record, new world, duel win, daily best")
	save.games = 20
	save.stats = {"days_played": 3, "play_seconds": 3000}
	var rv: Reviewer = get_root().get_node("Progress").reviewer
	ok(rv.maybe_ask(save, true) and save.review_asks == 1 and not rv.maybe_ask(save, true), "asking is remembered")
	save.reset_all()
	var pr = get_root().get_node("Progress")
	pr.run_finished(10, 1, 30.0)
	pr.run_finished(10, 1, 50.0)
	ok(int(save.stats.get("play_seconds", 0)) == 80 and int(save.stats.get("days_played", 0)) == 1, "play time and days played are counted")
	# daily challenge: same run for everyone on a day, a new one the next day, a few tries
	ok(Daily.seed_for(20000) == Daily.seed_for(20000) and Daily.seed_for(20000) != Daily.seed_for(20001), "one run per day")
	var jan := Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 1, "day": 15, "hour": 7, "minute": 59, "second": 0})
	ok(Daily.day_key(jan) == Daily.day_key(jan + 59) - 0 and Daily.day_key(jan + 60) == Daily.day_key(jan) + 1, "winter: new day at 08:00 UTC (midnight PST)")
	var jul := Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 7, "day": 15, "hour": 6, "minute": 59, "second": 0})
	ok(Daily.day_key(jul + 60) == Daily.day_key(jul) + 1, "summer: new day at 07:00 UTC (midnight PDT)")
	var mar_before := Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 3, "day": 13, "hour": 12, "minute": 0, "second": 0})
	var mar_after := Time.get_unix_time_from_datetime_dict({"year": 2027, "month": 3, "day": 15, "hour": 12, "minute": 0, "second": 0})
	ok(Daily._is_pdt(Time.get_datetime_dict_from_unix_time(mar_after)) and not Daily._is_pdt(Time.get_datetime_dict_from_unix_time(mar_before)), "daylight time from the 2nd Sunday of March (2027-03-14)")
	save.reset_all()
	ok(save.daily_tries_left() == Daily.FREE_TRIES and save.daily_video_left() == Daily.VIDEO_TRIES, "free tries each day")
	save.daily_started()
	var f1: Dictionary = save.daily_finished(40)
	save.daily_started()
	var f2: Dictionary = save.daily_finished(30)
	ok(f1["best"] and f1["pay"] == Daily.REWARD_FIRST and not f2["best"] and f2["pay"] == 0 and int(save.daily_state()["best"]) == 40, "best try counts, first try of the day pays")
	save.daily_started()
	save.daily_extra_try()
	ok(save.daily_tries_left() == 1 and save.daily_video_left() == Daily.VIDEO_TRIES - 1, "a video gives one more try")
	save.clock_override = Time.get_unix_time_from_system() + 86400.0 * 2
	ok(save.daily_tries_left() == Daily.FREE_TRIES and int(save.daily_state()["best"]) == 0, "a new day, a new challenge")
	save.clock_override = -1.0
	save.reset_all()
	# in-run coins and MAGNET
	var mc = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(mc)
	await process_frame
	mc.set_process(false)
	mc.ui.hide_popup()
	save.abilities = {}
	mc.start_run()
	var seen_coins := 0
	var seen_big := 0
	for f in 60 * 60:
		mc.director.next_t = INF   # no hazards: just watch the pickups appear
		mc._grace = 0.0
		mc._process(1.0 / 60.0)
		for b in mc.bubbles:
			if not b.has_meta("seen"):
				b.set_meta("seen", true)
				seen_coins += 1 if b.kind == "coin" else 0
				seen_big += 1 if b.kind == "big" else 0
	ok(seen_coins >= 18 and seen_coins <= 33 and seen_big >= 1 and seen_big <= 2,
		"coin arcs every ~8 s and a big coin every ~45 s (%d coins, %d big in 60 s)" % [seen_coins, seen_big])
	ok(mc.picked_coins > 0 and mc.ui._run_coins_lbl.text == str(mc.picked_coins), "touching coins collects them, HUD counts them (%d)" % mc.picked_coins)
	# magnet: a coin 25 px away on another spot only comes with magnet level >= 2 (30 px)
	for b in mc.bubbles:
		b.queue_free()
	mc.bubbles.clear()
	var me: Vector2 = Orbit.pos(mc.player.orbit, mc.player.angle)
	var far_a: float = mc.player.angle + 25.0 / Orbit.R
	var lone := Bubble.new().setup(far_a - mc.player.dir * 0.0, mc.gt - 1.0, 99.0, 0, "big")
	mc.bubbles.append(lone); mc.hazards_root.add_child(lone)
	var p0: int = mc.picked_coins
	var hold_a: float = mc.player.angle   # keep the player in place between steps
	mc._sim(1.0 / 60.0)
	mc.player.angle = hold_a
	ok(not lone.flying, "no magnet: a coin 25 px away stays put")
	save.abilities = {"magnet": 2}
	for f in 40:
		mc.director.next_t = INF
		mc._sim(1.0 / 60.0)
		mc.player.angle = hold_a
	ok(mc.picked_coins == p0 + 5, "MAGNET 2 pulls it in from 25 px (+5)")
	ok(mc._run_coins() >= mc.picked_coins, "picked coins count for the run")
	ok(me.distance_to(lone.fpos) < 8.0, "the coin flew to the player")
	mc.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()
	# in-run abilities
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	save.abilities = {"headstart": 1, "slowmo": 2, "secondlife": 1}
	save.stats["best_world"] = 5
	save.start_world = 3
	main.start_run()
	ok(main.world_no == 3 and main.score == Stages.LIST[2]["score"] and main.start_score == main.score,
		"headstart run begins in world 3 with its points (%d)" % main.score)
	ok(main.slowmo_charges == 2 and main.second_life, "slowmo charges and second life armed")
	main._grace = 0.0
	var gt0: float = main.gt
	main.use_slowmo()
	for f in 30:
		main._process(1.0 / 60.0)
	ok(main.slowmo_charges == 1 and absf(main.gt - gt0 - 0.25) < 0.02, "slowmo runs the game at half speed (%.2f)" % (main.gt - gt0))
	main._die()
	ok(main.state == main.S.PLAYING and not main.second_life and main.hazards.is_empty(), "second life revives once")
	main._die()
	ok(main.state == main.S.DYING, "second death ends the run")
	for f in 60:
		main._process(1.0 / 60.0)
	ok(main.run_coins == int(main.bubbles_popped * Upgrades.coin_mult(0)), "headstart points don't pay coins (%d)" % main.run_coins)
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


## A banner on every menu screen (skins, abilities, shop, ranking and the mission / settings /
## daily popups) but never on the main menu, during a run or on game over.
func test_banners(save) -> void:
	save.tutorial_done = true; save.jump_tip_done = true   # bots: no tutorial (see test_tutorial)
	save.reset_all()
	save.daily_last = save._day_string()
	var mon = get_root().get_node("Monetization")
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var tall: bool = main.ui.banner_room(main.ui.STYLE_H)
	var shown := func() -> bool: return mon.ads._banner.visible
	main.go_menu()
	ok(not shown.call(), "no banner on the main menu")
	main.open_skins()
	ok(shown.call() == tall, "skins screen banner (if it fits: %s)" % tall)
	main.go_menu()
	main.open_abilities()
	ok(shown.call() == main.ui.banner_room(main.ui.ABILITIES_H), "abilities screen banner")
	main.go_menu()
	main.open_shop()
	ok(shown.call(), "shop banner")
	main.go_menu()
	main.open_ranking()
	ok(shown.call(), "ranking banner")
	main.go_menu()
	ok(not shown.call(), "back to the menu hides it")
	main.ui.show_mission()
	ok(shown.call(), "missions popup banner")
	main.ui.hide_popup()
	ok(not shown.call(), "closing the popup hides it")
	main.ui.show_settings()
	ok(shown.call(), "settings popup banner")
	main.ui.hide_popup()
	main.ui.show_starter()
	ok(not shown.call(), "no banner next to the starter offer")
	main.ui.hide_popup()
	main.open_shop()
	main.start_run()
	ok(not shown.call(), "no banner during a run")
	main._die()
	for f in 80:
		main._process(1.0 / 60.0)
	ok(main.state == main.S.OVER and not shown.call(), "no banner on game over")
	# screens fit above the banner instead of overlapping it
	main.go_menu()
	main.open_skins()
	var sb: Control = main.ui._style_box
	ok(not tall or sb.offset_top + main.ui.STYLE_H <= main.ui.root.size.y - MonetizationConfig.BANNER_HEIGHT,
		"skins box ends above the banner")
	main.go_menu()
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


## Forces every world shape with all obstacles unlocked and checks the fair bot survives.
func test_duels(save) -> void:
	save.tutorial_done = true; save.jump_tip_done = true   # bots: no tutorial (see test_tutorial)
	print("== duels")
	save.reset_all()
	# codes: round trip, inside a pasted message, lower case, edited score rejected
	var all_ok := true
	for i in 50:
		var sd := (i * 7919 + 13) & ((1 << Duel.SEED_BITS) - 1)
		var c := Duel.encode(sd, i * 37, "Ana %d" % i)
		var d := Duel.decode("hey! " + c + " https://play.google.com")
		all_ok = all_ok and d.get("seed", -1) == sd and d.get("score", -1) == i * 37 and d.get("name", "") == Duel.clean_name("Ana %d" % i)
	ok(all_ok, "duel codes round-trip (50 codes)")
	var code := Duel.encode(123456, 142, "José María")
	ok(code.begins_with("ORBIT-") and code.ends_with("-JOSEMARIA") and code.length() <= 6 + Duel.CODE_LEN + 1 + Duel.NAME_MAX, "code format %s" % code)
	ok(Duel.decode(code.to_lower()).get("score", -1) == 142, "pasted in lower case still works")
	var body := code.substr(6, Duel.CODE_LEN)
	var swapped := body.substr(0, 9) + ("Z" if body[9] != "Z" else "Y") + body.substr(10)
	ok(Duel.decode("ORBIT-" + swapped + "-JOSEMARIA").is_empty(), "edited score: code rejected")
	ok(Duel.decode(code.replace("JOSEMARIA", "JOSE")).is_empty(), "edited name: code rejected")
	ok(Duel.decode("no code here").is_empty() and Duel.clean_name("") == "PLAYER", "no code / empty name")
	ok(Duel.outcome(10, 9) == "win" and Duel.outcome(9, 9) == "tie" and Duel.outcome(8, 9) == "lose", "duel outcome")
	# duel links: the shared message carries a link that opens the game (or the web page)
	var link := Linker.duel_url(code)
	ok(link.begins_with("https://" + Linker.HOST + "/duel/?c=ORBIT-") and Linker.code_in(link) == code, "duel link carries the code (%s)" % link)
	ok(Linker.code_in("https://example.com/duel/?c=" + code) == "" and Linker.code_in(Linker.HOST + "/duel/?c=nothing") == "", "only our duel links count")
	ok(Linker.url_text({"scheme": "https", "host": Linker.HOST, "path": "/duel/", "query": "c=" + code}) == link, "link rebuilt from the plugin's parts")
	ok(Linker.code_in("https://jfrjimenez37-del.github.io/duel/?c=" + code) == code, "links of the first site (1.0.12) still open")
	var l10 = get_root().get_node("L")
	ok(l10.t("DUEL_SHARE", [142, link]).contains(link) and l10.t("DUEL_SHARE_BACK", [150, link]).contains(link), "the duel message has the link")
	# rewards: nobody loses coins; a few paid duels a day
	var c0: int = save.coins
	ok(save.duel_finished("win") == Duel.REWARD_WIN and save.duel_finished("lose") == Duel.REWARD_LOSS and save.duel_finished("tie") == Duel.REWARD_TIE, "win / lose / tie pay")
	ok(save.duel_finished("win") == 0 and save.coins == c0 + Duel.REWARD_WIN + Duel.REWARD_LOSS + Duel.REWARD_TIE, "only %d paid duels a day, never coins lost" % Duel.REWARDS_PER_DAY)
	ok(int(save.duels["wins"]) == 2 and int(save.duels["losses"]) == 1 and save.duel_rewards_left() == 0, "duel stats")
	save.duel_created(code)
	ok(save.duel_mine(Duel.decode(code)) and not save.duel_mine(Duel.decode(Duel.encode(123456, 150, "KAI"))), "own code recognised, a reply on the same run is not mine")
	save.duel_started(code)
	ok(save.duel_played(code), "a duel can only be played once")
	# a duel run: same run for everyone, no abilities, no continue
	save.reset_all()
	save.level = 20
	save.abilities = {"coins": 5, "shield": 3, "magnet": 5, "slowmo": 3, "teleport": 3, "headstart": 3, "secondlife": 1}
	save.stats = {"best_world": 12}
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var d2 := Duel.decode(Duel.encode(4242, 30, "KAI"))
	main.start_duel(d2)
	ok(main.shield_hits == 0 and main.teleports == 0 and main.slowmo_charges == 0 and not main.second_life and main.stage == 0 and main.score == 0,
		"duel: no shield, teleport, slow-mo, second life or headstart")
	var runs := []
	for k in 2:
		if k == 1:
			main.start_duel(d2)
		var frames := 0
		while main.state == main.S.PLAYING and frames < 60 * 25:
			if frames % 2 == 0 and TestBot.decide(main):
				main._flip()
			main._grace = 0.0
			main._process(1.0 / 60.0)
			frames += 1
		runs.append([main.score, frames, main.director.committed])
		if main.state == main.S.DYING:
			main._game_over()
	print("  duel runs (score, frames, patterns): ", runs)
	ok(runs[0] == runs[1], "same code, same play: identical run %s / %s" % [str(runs[0]), str(runs[1])])
	# the result: win against a low score, paid and counted
	save.reset_all()
	main.start_duel(Duel.decode(Duel.encode(77, 0, "LU")))
	main.score = 5
	main._game_over()
	ok(int(save.duels.get("wins", 0)) == 1 and main.duel["last"]["result"] == "win" and main.duel["last"]["pay"] == Duel.REWARD_WIN, "beating a friend's score: win + coins")
	ok(not main.ui._over_buttons[0].visible and main.ui._over_duel.visible and main.ui._over_duel_mode == "send", "duel game over: no retry, send the result")
	ok(Duel.decode(main.duel["last"]["code"]).get("score", -1) == 5 and Duel.decode(main.duel["last"]["code"]).get("seed", -1) == 77, "reply code: my score, same run")
	main.start_duel(Duel.decode(Duel.encode(78, 900, "LU")))
	main.score = 5
	main._game_over()
	ok(main.duel["last"]["result"] == "lose" and main.ui._over_duel_mode == "rematch", "losing offers a rematch (new run)")
	main.go_menu()
	main.start_duel({})
	main.score = 12
	main._game_over()
	ok(main.duel["last"]["mode"] == "new" and save.duel_mine(Duel.decode(main.duel["last"]["code"])), "new duel: code to send, marked as mine")
	main.queue_free()
	await process_frame
	Orbit.reset()
	# every duel text fits where it is drawn
	var l10n = get_root().get_node("L")
	var font: FontFile = load("res://assets/font/pixel.fnt")
	var w := func(t: String) -> float: return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var wide: Array = []
	for lang in l10n.LANGS:
		l10n.set_lang(lang)
		for k in ["DUEL_I1", "DUEL_I2", "DUEL_I3", "DUEL_HINT", "DUEL_DARES", "DUEL_RULES", "DUEL_LEFT", "DUEL_STATS", "DUEL_PAY"]:
			var t: String = l10n.t(k, [99, 99]) if k in ["DUEL_STATS", "DUEL_PAY"] else (l10n.t(k, 3) if k == "DUEL_LEFT" else l10n.t(k))
			if w.call(t) > 152: wide.append("%s %s" % [lang, k])
		for k in ["DUEL_SEND_IT", "DUEL_WIN", "DUEL_TIE"]:
			if w.call(l10n.t(k, 50) if k != "DUEL_SEND_IT" else l10n.t(k)) > 132: wide.append("%s %s" % [lang, k])
		if w.call(l10n.t("DUEL_LOSE", ["ABCDEFGHIJ", 9999])) > 132: wide.append("%s DUEL_LOSE" % lang)
		if w.call(l10n.t("DUEL_BEAT", ["ABCDEFGHIJ", 9999])) > 176: wide.append("%s DUEL_BEAT" % lang)
		if w.call(l10n.t("DUEL_BEAT_N", 9999)) * 2 > 152: wide.append("%s DUEL_BEAT_N" % lang)
		for k in ["DUEL_CHALLENGE", "DUEL_SEND_RESULT", "DUEL_REMATCH", "DUEL_NEW", "DUEL_PASTE"]:
			if w.call(l10n.t(k)) > 108 - 6 - 13: wide.append("%s %s" % [lang, k])
	l10n.set_lang("en")
	ok(wide.is_empty(), "duel texts fit %s" % str(wide))
	save.reset_all()


func test_worlds(save) -> void:
	save.tutorial_done = true; save.jump_tip_done = true   # bots: no tutorial (see test_tutorial)
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var dt := 1.0 / 60.0
	for si in Stages.LIST.size():
		seed(7000 + si)   # reproducible: the bot is greedy, not perfect (tests/audit*.gd measure fairness)
		main.start_run()
		main.director.offset = 60.0
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		main.stage = si
		main.director.stage = si
		main.world_no = 99  # no further world changes during this test
		var frames := 0
		var switches := 0
		while main.state == main.S.PLAYING and frames < 60 * 45:
			if frames % 2 == 0 and TestBot.decide(main):
				var k0: int = main.player.orbit
				main._flip()
				if main.player.orbit != k0:
					switches += 1
			main._grace = 0.0
			main._process(dt)
			frames += 1
		ok(main.state == main.S.PLAYING, "fair bot survives world %s (died at %.1fs)" % [Stages.LIST[si]["world"], main.gt])
		print("  world %s: %d patterns, %d rejected, %d orbit switches" % [Stages.LIST[si]["world"], main.director.committed, main.director.rejected, switches])
		if main.state == main.S.DYING:
			main._game_over()
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


func test_simulation(save) -> void:
	save.tutorial_done = true; save.jump_tip_done = true   # bots: no tutorial (see test_tutorial)
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
		print("  run %d: survived %.1fs score %d world %d patterns %d rejected %d omega %.2f (%.1fs real)" % [run, survived, main.score,
			main.world_no, main.director.committed, main.director.rejected, main.player.omega, (Time.get_ticks_msec() - t_start) / 1000.0])
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
				var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
				if not Survival.can_survive(seen, main.gt, p.angle, p.dir, p.omega, false, p.orbit) \
						and Survival.can_survive(seen, main.gt, r[2], r[1], p.omega, false, r[0]):
					main._flip()
			main._grace = 0.0
			main._process(dt)
			frames += 1
		lens.append(snappedf(main.gt, 0.1))
		if main.state == main.S.DYING:
			main._game_over()
	lens.sort()
	print("  human-like bot run lengths (s): ", lens)
	ok(counts.size() >= 4, "hazard types appear: %s" % str(counts.keys()))
	print("  (worlds reached in long runs exercise the newer hazards too)")
	# rapid restarts: no leaks of hazards
	for i in 20:
		main.start_run()
		for f in 30:
			main._process(dt)
	ok(main.hazards.size() < 6, "restart clears the field")
	main.queue_free()
	save.reset_all()


## Statistics (GameAnalytics REST): signing, event format, batching, retries, opt-out, sessions.
func test_analytics(save) -> void:
	ok(Analytics.hmac_sign('[{"category":"user"}]', "test-secret") == "ojOp1Jfyh8S9et+JYxOOhFPxLXfrlr3dyaqzfIWmnGE=",
		"analytics: HMAC-SHA256 signature matches openssl")
	var u := Analytics.uuid()
	ok(RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$").search(u) != null and Analytics.uuid() != u,
		"analytics: random v4 player ids (%s)" % u)
	save.reset_all()
	save.sessions = 4
	save.share_stats = true
	save.analytics_session = {}
	if FileAccess.file_exists(Analytics.QUEUE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Analytics.QUEUE_PATH))
	var now := [5000.0]
	var calls: Array = []
	var a := Analytics.new()
	a.clock = func() -> float: return now[0]
	a.sender = func(url: String, headers: PackedStringArray, body: String) -> void: calls.append([url, headers, body])
	get_root().add_child(a)
	a.start(save)
	a.game_key = "gk"
	a.secret_key = "sk"
	a.force_send = true
	ok(save.analytics_id != "" and a.user_id == save.analytics_id, "analytics: a player id is made once and saved")
	ok(a.queue.size() == 1 and a.queue[0]["category"] == "user" and a.queue[0]["session_num"] == 4, "analytics: a session starts with a user event")
	a.design("Run:Start", 1)
	a.progression("Fail", "Normal", "World03", "", 120)
	a.progression("Start", "Normal", "World03", "", 99)
	a.resource("Source", "Coins", 50, "Mission", "near-run")
	a.resource("Sink", "Coins", 0, "Style", "x")
	a.business("Product", "coins_1500", 99)
	a.design("Shop:Purchase:coins-x2:Bad Text!")
	ok(a.queue.size() == 7, "analytics: events queued (a 0-coin resource is skipped)")
	ok(a.queue[2]["event_id"] == "Fail:Normal:World03" and a.queue[2]["score"] == 120 and not a.queue[3].has("score"),
		"analytics: progression ids and scores (none on Start)")
	ok(a.queue[4]["event_id"] == "Source:Coins:Mission:near_run" and a.queue[6]["event_id"] == "Shop:Purchase:coins_x2:Bad_Text_",
		"analytics: ids keep only letters, digits and _")
	ok(a.queue[5]["category"] == "business" and a.queue[5]["amount"] == 99 and a.queue[5]["currency"] == "USD" and a.queue[5]["transaction_num"] == 1,
		"analytics: business event in cents")
	var e: Dictionary = a.queue[1]
	ok(e["v"] == 2 and e["sdk_version"] == "rest api v2" and e["platform"] == "android" and e["client_ts"] == 5000
		and e["session_id"] == a.session_id and str(e["os_version"]).begins_with("android "), "analytics: default annotations on every event")
	a.flush()
	ok(calls.size() == 1 and calls[0][0] == "https://api.gameanalytics.com/v2/gk/events", "analytics: one batch to the events endpoint")
	var body: String = calls[0][2]
	ok(Array(calls[0][1]).has("Authorization: " + Analytics.hmac_sign(body, "sk")) and Array(calls[0][1]).has("Content-Type: application/json"),
		"analytics: signed JSON request")
	ok((JSON.parse_string(body) as Array).size() == 7, "analytics: the batch carries the queued events")
	a.flush()
	ok(calls.size() == 1, "analytics: no second request while one is in flight")
	a._on_response(0, "")
	ok(a.queue.size() == 7 and a.sent == 0, "analytics: no network: events kept for a retry")
	a.flush()
	a._on_response(200, "")
	ok(a.queue.is_empty() and a.sent == 7, "analytics: 200: batch removed from the queue")
	a.design("Bad")
	a.flush()
	a._on_response(400, "{}")
	ok(a.queue.is_empty() and a.dropped == 1, "analytics: 400: refused batch dropped, never retried forever")
	# sessions: a short trip to the background keeps the session, a long one starts a new one
	var sid := a.session_id
	a._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	now[0] += 5.0
	a._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	ok(a.session_id == sid, "analytics: 5 s in the background: same session")
	a._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	now[0] += 60.0
	a._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var ends := a.queue.filter(func(q): return q["category"] == "session_end")
	ok(a.session_id != sid and ends.size() == 1 and ends[0]["length"] == 5 and a.queue[-1]["category"] == "user",
		"analytics: 60 s in the background: session_end (length 5 s) and a new session")
	# a session left open (app killed) is closed on the next start; the queue saved on disk is sent then
	a._save_queue()
	var b := Analytics.new()
	b.clock = func() -> float: return now[0] + 1000.0
	b.sender = func(_u, _h, _b) -> void: pass
	get_root().add_child(b)
	b.start(save)
	var closing := b.queue.filter(func(q): return q["category"] == "session_end")
	ok(closing.size() >= 1 and closing[-1]["session_id"] == a.session_id, "analytics: a session left open is closed on the next launch")
	var b_body := [""]
	b.sender = func(_u, _h, body: String) -> void: b_body[0] = body
	b.game_key = "gk"; b.secret_key = "sk"; b.force_send = true
	b.flush()
	ok(b.queue.size() > 2 and b.queue.all(func(q): return q["client_ts"] is int and q["session_num"] is int)
		and b_body[0] != "" and not ".0," in b_body[0] and not ".0}" in b_body[0],
		"analytics: events saved before a restart are sent with whole numbers (not 21.0: GameAnalytics 400)")
	b._on_response(200, "")
	b.set_opt_out(true)
	b.design("Nope")
	ok(b.queue.is_empty(), "analytics: SHARE STATS off: nothing is queued or kept")
	a.queue_free()
	b.queue_free()
	if FileAccess.file_exists(Analytics.QUEUE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Analytics.QUEUE_PATH))
	save.reset_all()


## First-run tutorial: the game stops before the first meteor until the first tap, never kills
## meanwhile, then NICE!; players who already played never see it; the planet-jump tip slows the
## game at the first crossing and ends with a jump.
func test_tutorial(save) -> void:
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	var dt := 1.0 / 60.0
	main.duel = {}
	main.start_run()
	ok(main._tut_step == 1, "tutorial: on in the very first run")
	var frames := 0
	while main.state == main.S.PLAYING and frames < 60 * 20 and not (main._tut_scale == 0.0):
		main._grace = 0.0
		main._process(dt)
		frames += 1
	ok(main._tut_meteor != null and main._tut_scale == 0.0 and main.ui.tip_showing(), "tutorial: time stops before the first meteor, tip shown")
	var gt0: float = main.gt
	for i in 120:
		main._process(dt)
	ok(main.state == main.S.PLAYING and absf(main.gt - gt0) < 0.001, "tutorial: frozen and alive while waiting for the tap")
	main._flip()
	ok(main._tut_step == 0 and save.tutorial_done, "tutorial: the first tap ends it (saved)")
	for i in 30:
		main._process(dt)
	ok(main._tut_scale > 0.99 and main.gt > gt0, "tutorial: back to normal speed after the tap")
	main._game_over()
	main.start_run()
	ok(main._tut_step == 0, "tutorial: not shown again")
	save.reset_all()
	save.games = 3
	save.tutorial_done = false
	main.start_run()
	ok(main._tut_step == 0, "tutorial: never for players who already played")
	# planet-jump tip: at a crossing of two planets
	save.jump_tip_done = false
	main._clear_field()
	Orbit.set_shape(Stages.LIST[5]["orbits"], true)
	var cl: Array = Orbit.cross_list()
	ok(not cl.is_empty(), "tutorial: two-planet world has crossings")
	var found := false
	for i in 720:
		var a := -PI + TAU * i / 720.0
		if Orbit.crossing_at(a, 0) >= 0:
			main.player.angle = a
			main.player.orbit = 0
			found = true
			break
	main._tutorial(dt)
	ok(found and main._jump_tip and main.ui.tip_showing(), "tutorial: TAP NOW! at the first crossing")
	for i in 20:
		main._tutorial(dt)
	ok(absf(main._tut_scale - main.JUMP_TIP_SCALE) < 0.01, "tutorial: slow motion while the jump tip is up")
	var sw: bool = main.player.tap()
	main._jump_tip = main._jump_tip and sw
	if sw:
		save.jump_tip_done = true
	ok(sw and save.jump_tip_done, "tutorial: a jump at the crossing ends the tip")
	main.queue_free()
	save.reset_all()


## 1.0.16 abilities: HOLD = slow-mo (after HOLD_TIME, lasts by level), SWIPE = teleport (along the
## orbit or onto the planet it points at, undoing the swipe's own flip), BUBBLES ability, and
## near misses in a row (x2, x3).
func test_gestures(save) -> void:
	save.reset_all()
	save.tutorial_done = true; save.jump_tip_done = true
	save.ability_tips = ["hold", "swipe"]
	save.abilities = {"slowmo": 2, "teleport": 2, "bubbles": 2}
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.duel = {}
	main.start_run()
	main._clear_field()
	ok(main.slowmo_charges == 2 and main.teleports == 2, "gestures: charges from the ability levels")
	var now := Time.get_ticks_msec() / 1000.0
	# a short press: no slow-mo
	main._touch = {"pos": Vector2(90, 200), "t": now - 0.2, "dir": main.player.dir, "orbit": 0, "done": false, "pointer": true}
	main._hold_update()
	ok(main.slowmo_left <= 0.0 and main.player.hold > 0.0, "gestures: 0.2 s held: ring charging, no slow-mo yet")
	main._touch["t"] = now - 0.6
	main._hold_update()
	ok(main.slowmo_left == Upgrades.SLOWMO_TIMES[2] and main.slowmo_charges == 1 and main.player.hold == 0.0,
		"gestures: held 0.5 s: slow-mo for %.1f s (level 2)" % Upgrades.SLOWMO_TIMES[2])
	main._touch = {}
	main.slowmo_left = 0.0
	main.player.slowmo = false
	# swipe: the tap's flip is undone and the TELEPORT aim starts (slow game, nothing spent yet)
	var d0: int = main.player.dir
	main._flip()   # the swipe's own tap
	var org := Vector2(90, 200)
	main._touch = {"pos": org, "t": Time.get_ticks_msec() / 1000.0, "dir": d0, "orbit": 0, "done": false, "pointer": true}
	var a0: float = main.player.angle
	var tangent: Vector2 = (Orbit.pos(0, a0 + 0.02) - Orbit.pos(0, a0 - 0.02)).normalized()
	var ev := InputEventScreenDrag.new()
	ev.position = org + tangent * 20.0
	main._gesture(ev)
	ok(not main._aim.is_empty() and main.teleports == 2 and main.player.dir == d0 and main.aim_view.visible,
		"teleport aim: a swipe starts aiming (flip undone, no charge spent yet)")
	var gt0: float = main.gt
	main._process(0.1)
	ok(main.gt - gt0 < 0.1 * main.AIM_SCALE + 0.01, "teleport aim: the game runs at %.2fx while aiming" % main.AIM_SCALE)
	# drag the aim along the orbit, let go: warp there
	var goal: Vector2 = Orbit.pos(0, a0 + 1.0)
	ev.position = org + (goal - main.player.position) / main.AIM_GAIN
	main._gesture(ev)
	ok(main._aim["k"] == 0 and absf(Orbit.ang_diff(main._aim["a"], a0 + 1.0)) < 0.2, "teleport aim: the aim snaps to the orbit under the drag")
	var up := InputEventScreenTouch.new()
	up.pressed = false
	main._gesture(up)
	var moved := Orbit.ang_diff(main.player.angle, a0 + 1.0)
	ok(main._aim.is_empty() and main.teleports == 1 and absf(moved) < 0.55 and not main.aim_view.visible,
		"teleport aim: letting go warps to the aim (%.2f rad off, safe spot)" % moved)
	# back on the player: cancel, no charge spent
	main._touch = {"pos": org, "t": Time.get_ticks_msec() / 1000.0, "dir": main.player.dir, "orbit": main.player.orbit, "done": false, "pointer": true}
	var a1: float = main.player.angle
	ev.position = org + Vector2(20, 0)
	main._gesture(ev)
	ev.position = org + Vector2(2, 1)
	main._gesture(ev)
	main._gesture(up)
	ok(main.teleports == 1 and absf(Orbit.ang_diff(main.player.angle, a1)) < 0.1, "teleport aim: dragged back onto the player = cancelled, charge kept")
	# aim at the other planet's orbit
	main._touch = {}
	Orbit.set_shape(Stages.LIST[5]["orbits"], true)
	main.player.teleport_to(0, 0.0)
	var aim_far := Vector2.ZERO
	var dfar := -1.0
	for st in 72:
		var q: Vector2 = Orbit.pos(1, -PI + TAU * st / 72.0)
		var dd: float = Orbit.pos(0, Orbit.nearest_angle(0, q)).distance_to(q)
		if dd > dfar:
			dfar = dd
			aim_far = q
	main._touch = {"pos": org, "t": Time.get_ticks_msec() / 1000.0, "dir": main.player.dir, "orbit": 0, "done": false, "pointer": true}
	ev.position = org + Vector2(0, 20)
	main._gesture(ev)
	ev.position = org + (aim_far - main.player.position) / main.AIM_GAIN
	main._gesture(ev)
	main._gesture(up)
	ok(main.player.orbit == 1 and main.teleports == 0, "teleport aim: aiming at another planet's orbit warps onto it")
	# no charges left: a swipe does not aim
	main._touch = {"pos": org, "t": Time.get_ticks_msec() / 1000.0, "dir": main.player.dir, "orbit": main.player.orbit, "done": false, "pointer": true}
	ev.position = org + Vector2(20, 0)
	main._gesture(ev)
	ok(main._aim.is_empty(), "teleport aim: no charges, no aim")
	# AIM_MAX: the aim warps on its own
	main.teleports = 1
	main._touch = {"pos": org, "t": Time.get_ticks_msec() / 1000.0, "dir": main.player.dir, "orbit": main.player.orbit, "done": false, "pointer": true}
	main._gesture(ev)
	main._aim["t"] = Time.get_ticks_msec() / 1000.0 - main.AIM_MAX - 0.1
	main._process(0.016)
	ok(main._aim.is_empty() and main.teleports == 0, "teleport aim: after %.1f s it warps by itself" % main.AIM_MAX)
	# NEW OBSTACLE intro: first boomerang -> tip + seen; the second one says nothing
	save.seen_obstacles = ["meteor"]
	main.ui.hide_tip()
	var bm := Boomerang.new().setup(Orbit.pos(0, main.player.angle + 2.0), 0.0, main.gt + 5.0, 0.5, 2.0, 0)
	main._new_obstacle(bm)
	ok(save.seen_obstacles.has("boomerang") and main.ui.tip_showing(), "obstacles: first boomerang shows NEW: BOOMERANG")
	main.ui.hide_tip()
	main._new_obstacle(bm)
	ok(not main.ui.tip_showing(), "obstacles: only the first time")
	bm.free()
	var saw := Spiky.new().setup(0.0, 0.0, 0.5, 1.0, 1.0, 0, "saw")
	ok(Director.kind_of(saw) == "saw" and Director.kind_of(Beam.new()) == "beams" and Director.kind_of(Barrier.new()) == "spoke",
		"obstacles: saw / beams / spoke kinds")
	saw.free()
	# BUBBLES ability: +1 per level on every bubble
	var s0: int = main.score
	var b := Bubble.new().setup(main.player.angle, main.gt, 5.0, main.player.orbit)
	main.hazards_root.add_child(b)
	main._collect(b)
	ok(main.score - s0 == 2 + 2 * Upgrades.BUBBLE_BONUS, "gestures: BUBBLES level 2: a bubble gives %d" % (main.score - s0))
	ok(main.ui.ability_desc("bubbles", 2) != "" and Upgrades.find("bubbles")["max"] == 4, "gestures: BUBBLES ability listed")
	# combo: near misses in a row give 2, 2, then x2 from the 3rd (4), x3 from the 6th (6), x5 from
	# the 10th (10); a PERFECT (very close) adds 2 and freezes the game for a moment
	var near := Meteor.new().setup(0.0, main.gt, 0.5, 80.0, 0)
	near.min_clear = 0.08
	var s1: int = main.score
	var c0: int = main.picked_coins
	var got: Array = []
	for i in 10:
		var b4: int = main.score
		main._award(near)
		got.append(main.score - b4)
	ok(got == [2, 2, 4, 4, 4, 6, 6, 6, 6, 10], "gestures: combo points %s" % str(got))
	ok(main.best_combo == 10 and main.picked_coins - c0 == 5 + 15, "gestures: combo 5 and 10 pay 5 + 15 coins")
	ok(main.ui._combo_lbl.visible and main.ui._combo_lbl.text.contains("10"), "gestures: the HUD shows the combo")
	var far := Meteor.new().setup(0.0, main.gt, 0.5, 80.0, 0)
	far.min_clear = 1.0
	main._award(far)
	ok(main._near_streak == 0 and not main.ui._combo_lbl.visible, "gestures: a normal pass ends the combo")
	var s2: int = main.score
	var perfect := Meteor.new().setup(0.0, main.gt, 0.5, 80.0, 0)
	perfect.min_clear = 0.01
	save.reduce_motion = false
	main._award(perfect)
	ok(main.score - s2 == 4 and main._freeze > 0.0, "gestures: PERFECT gives +2 more and a hit-stop")
	var g0: float = main.gt
	main.set_process(false)
	main._process(1.0 / 60.0)
	ok(main.gt == g0, "gestures: nothing moves during the hit-stop")
	main._freeze = 0.0
	perfect.free()
	ok(int(save.stats.get("best_combo", 0)) >= 10, "gestures: best combo kept in the statistics")
	near.free(); far.free()
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


## 1.0.17 obstacles: each one is dangerous, only inside its danger window, and the fairness
## check accepts it often enough to be seen in its world.
func test_new_obstacles() -> void:
	var list: Array = Director.STAGE_PATTERNS.duplicate()
	if "--compare" in OS.get_cmdline_user_args():
		# reference: older patterns in the same worlds (cost only)
		list = [["sweep", 14], ["sweep", 9], ["cage", 12], ["comet_rain", 8], ["link_cage", 10], ["drift", 15], ["rain", 13]]
	for sp in list:
		var si: int = sp[1]
		if si < 8:
			continue
		var name: String = sp[0]
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		var dr := Director.new()
		dr.reset(900 + si, 20.0)
		dr.stage = si
		dr.world = si + 1
		dr.spawned_first = true
		var rng := RandomNumberGenerator.new()
		rng.seed = 31 + si
		var trials := 30
		var accepted := 0
		var dangerous := 0
		var leaks := 0
		var kinds := {}
		var worst_ms := 0.0
		for i in trials:
			var t := 100.0 + i * 7.3
			Orbit.set_time(t)
			var k := rng.randi_range(0, Orbit.count() - 1)
			var a := rng.randf_range(-PI, PI)
			var d := 1 if rng.randf() < 0.5 else -1
			var w := dr.omega(t)
			var res: Dictionary = dr._build(name, t, a, d, w, dr.level(t), 0, k)
			var hs: Array = res["hazards"]
			var hit := false
			for h in hs:
				kinds[h.get_script().get_global_name()] = true
				ok(Director.kind_of(h) != "", "%s: %s has an obstacle kind" % [name, h.get_script().get_global_name()])
				var ts: float = h.t_spawn
				while ts <= h.t_end + 0.5:
					Orbit.set_time(ts)
					for kk in Orbit.count():
						var iv: Array = []
						h.danger(ts, iv, kk)
						if not iv.is_empty():
							if ts < h.t_danger_start - 0.001 or ts > h.t_danger_end + 0.001:
								leaks += 1
							else:
								hit = true
					ts += 0.02
				ok(h.t_end >= h.t_danger_end and h.t_danger_start >= h.t_spawn - 0.001, "%s: time window in order" % name)
			Orbit.set_time(t)
			if hit:
				dangerous += 1
			var us0 := Time.get_ticks_usec()
			if Survival.can_survive(hs, t, a, d, w, true, k, Survival.human_margin(w), Survival.HUMAN_GAP,
					Survival.HUMAN_REACT, dr.omega_rate(t), {}, 0):
				accepted += 1
			worst_ms = maxf(worst_ms, (Time.get_ticks_usec() - us0) / 1000.0)
			for h in hs:
				h.free()
		print("  %s (world %d): %d/%d fair, %d/%d dangerous, check %.1f ms worst, %s" % [name, si + 1, accepted, trials, dangerous, trials, worst_ms, ",".join(kinds.keys())])
		ok(leaks == 0, "%s: no danger outside its window (%d)" % [name, leaks])
		ok(dangerous >= trials * 0.8, "%s: really dangerous (%d/%d)" % [name, dangerous, trials])
		ok(accepted >= trials * 0.3, "%s: accepted by the fairness check often enough (%d/%d)" % [name, accepted, trials])
	Orbit.reset()


## 1.0.18 weekly events: weeks start on Monday (Pacific), goals pay once, the run only has the
## event's obstacles, LAND OF GIANTS stays on world 9, SPEED WEEK is faster.
func test_events(save) -> void:
	# 2026-11-09 is a Monday: 12:00 Pacific (20:00 UTC) on Sunday 8th and Monday 9th are different weeks
	var sun := Time.get_unix_time_from_datetime_string("2026-11-08T20:00:00")
	var mon := Time.get_unix_time_from_datetime_string("2026-11-09T20:00:00")
	var tue := Time.get_unix_time_from_datetime_string("2026-11-10T20:00:00")
	ok(Events.week_key(mon) == Events.week_key(sun) + 1 and Events.week_key(tue) == Events.week_key(mon), "events: the week starts on Monday")
	var left := Events.seconds_left(mon)
	ok(left > 5 * 86400 and left <= 7 * 86400, "events: time left on Monday noon ~6.5 days (%d h)" % (left / 3600))
	ok(Events.for_week(0) != Events.for_week(1) and Events.seed_for(5) == Events.seed_for(5) and Events.seed_for(5) != Events.seed_for(6),
		"events: a different event and run every week, the same run for everyone")
	ok(Events.pay_for(30, 0) == [40, 1] and Events.pay_for(130, 1) == [230, 3] and Events.pay_for(500, 3) == [0, 3],
		"events: goals pay in order and once")
	save.reset_all()
	save.tutorial_done = true; save.jump_tip_done = true
	save.event_week_test = 0
	save.coins = 0
	save.event_started()
	var r1: Dictionary = save.event_finished(70)
	var r2: Dictionary = save.event_finished(70)
	ok(r1["pay"] == 120 and r2["pay"] == 0 and save.coins == 120 and int(save.event_state()["best"]) == 70,
		"events: 70 points pay 40 + 80 once (%d, %d)" % [r1["pay"], r2["pay"]])
	save.event_week_test = 1
	ok(int(save.event_state()["paid"]) == 0 and int(save.event_state()["best"]) == 0, "events: a new week starts fresh")
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var dt := 1.0 / 60.0
	for i in Events.LIST.size():
		var ev: Dictionary = Events.LIST[i]
		var w0: int = 0
		save.event_week_test = w0 - posmod(w0, Events.LIST.size()) + i
		main.start_event()
		ok(main.duel.get("kind", "") == "event" and main.teleports == 0 and main.slowmo_charges == 0, "events: %s run has no abilities" % ev["id"])
		var bad := {}
		var seen := {}
		var frames := 0
		while main.state == main.S.PLAYING and frames < 60 * 40:
			if frames % 2 == 0 and TestBot.decide(main):
				main._flip()
			main._grace = 0.0
			main.shield_until = INF   # keep going: this checks the content, not the bot
			main._process(dt)
			for h in main.hazards:
				var k := Director.kind_of(h)
				seen[k] = true
			if ev.has("stage") and frames == 600:
				main._add_score(400)   # far past world 10's score
			frames += 1
		if ev.has("only"):
			for k in seen:
				if not k in ev["kinds"]:
					bad[k] = true   # nothing else, not even the first slow meteor
			ok(bad.is_empty() and seen.size() >= 1, "events: %s only has its obstacles %s (bad %s)" % [ev["id"], str(seen.keys()), str(bad.keys())])
		if ev.has("stage"):
			ok(main.stage == int(ev["stage"]) and main._stage_pending < 0, "events: %s stays on its world (stage %d)" % [ev["id"], main.stage])
		if ev.has("omega"):
			ok(absf(main.director.omega(30.0) - lerpf(2.3, 3.3, main.director.level(30.0)) * float(ev["omega"])) < 0.001,
				"events: %s is faster" % ev["id"])
		main.state = main.S.DYING
		main._game_over()
		ok(main.duel.get("last", {}).get("mode", "") == "event", "events: %s result shown" % ev["id"])
	# overtaking the week's best in an event / today's best in the daily: the right HUD message
	var l10n = get_root().get_node("L")
	for kind in ["event", "daily", "duel"]:
		save.event_run = {"week": save.event_week(), "tries": 1, "best": 10, "paid": 0}
		if kind == "event":
			main.start_event()
		elif kind == "daily":
			main.start_daily()
		else:
			main.start_duel({"seed": 77, "score": 10, "name": "MAYA", "code": "X"})
		main.duel["target"] = 10
		main._add_score(11)
		var want: String = {"event": "EVENT_AHEAD", "daily": "DAILY_AHEAD", "duel": "DUEL_AHEAD"}[kind]
		ok(main.duel_lead and main.ui._hud_best.text == l10n.t(want), "events: overtaking in a %s run says %s" % [kind, want])
		main.state = main.S.DYING
		main._game_over()
	main.duel = {}
	main.start_run()
	ok(main.director.only.is_empty() and main.director.omega_mul == 1.0 and main._event_stage == -1, "events: a normal run after an event is normal")
	var sfx = get_root().get_node("Sfx")
	var changes := 0
	for si in range(1, 16):
		if sfx.group_for_stage(si) != sfx.group_for_stage(si - 1):
			changes += 1
	ok(sfx.group_for_stage(0) == "sky" and sfx.group_for_stage(2) == "planets" and sfx.group_for_stage(15) == "moving"
		and changes >= 7 and sfx.current_group() == "sky", "music: a new song every two worlds (%d changes)" % changes)
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.event_week_test = -999999
	save.reset_all()


## 1.0.19 orbital surges: each kind starts with its banner and ends, the gravity pulse only speeds
## the player up with an empty field (both ramps), the bot gets through them, none in weekly events.
func test_surges(save) -> void:
	save.reset_all()
	save.tutorial_done = true; save.jump_tip_done = true
	save.ability_tips = ["hold", "swipe"]
	save.seen_obstacles = Director.KINDS.map(func(kd): return kd[0])
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var dt := 1.0 / 60.0
	for case in [["shower", 2], ["comets", 5], ["nova", 4], ["gravity", 2], ["gravity", 9], ["nova", 13]]:
		var kind: String = case[0]
		var si: int = case[1]
		seed(8100 + si)
		main.duel = {}
		main.start_run()
		main.director.offset = 40.0
		Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
		main.stage = si
		main.director.stage = si
		main.world_no = 99
		main.director.next_surge = 4.0
		main.director.surge_test = kind
		var started := ""
		var ended := false
		var grav_ok := true
		var max_mul := 1.0
		var was_up := false
		var nova_seen := false
		var frames := 0
		while main.state == main.S.PLAYING and frames < 60 * 30:
			if frames % 2 == 0 and TestBot.decide(main):
				main._flip()
			main._grace = 0.0
			var phase: String = main.director.surge_phase
			main._process(dt)
			if main.director.surge != "" and started == "":
				started = main.director.surge
			if started != "" and main.director.surge == "" and frames > 0:
				ended = true
			var m: float = main.director._grav_mul(main.gt)
			max_mul = maxf(max_mul, m)
			# the speed only moves (ramps) while the field is empty
			if m > 1.0001 and m < 1.0 + Director.GRAVITY_X - 0.0001 and not main.hazards.is_empty():
				grav_ok = false
			for h in main.hazards:
				if h is Pulse and h.nova:
					nova_seen = true
			frames += 1
		var want := kind if not (kind == "nova" and Orbit.moving()) else "comets"
		ok(main.state == main.S.PLAYING, "surges: the bot gets through a %s in world %d (died at %.1f s)" % [kind, si + 1, main.gt])
		ok(started == want and ended, "surges: %s in world %d starts and ends (%s, %s)" % [kind, si + 1, started, ended])
		if want == "gravity":
			ok(grav_ok and absf(max_mul - 1.0 - Director.GRAVITY_X) < 0.001, "surges: gravity pulse x%.2f, ramps only on an empty field" % max_mul)
		if want == "nova":
			ok(nova_seen, "surges: the supernova wave showed up")
		if main.state == main.S.DYING:
			main._game_over()
	# no surges in weekly events
	save.event_week_test = 0
	main.start_event()
	main.director.next_surge = 0.0
	for i in 600:
		main._grace = 0.0
		main.shield_until = INF
		main._process(dt)
	ok(main.director.surge_count == 0, "surges: none in a weekly event")
	save.event_week_test = -999999
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


## 1.0.20: weekly events escalate on one world, the game over says where the run stands and what
## was missing for the next world, a tip after a bad run, the welcome offer (-50 %) after 3 runs.
func test_v120(save) -> void:
	save.reset_all()
	save.tutorial_done = true; save.jump_tip_done = true
	save.ability_tips = ["hold", "swipe"]
	save.seen_obstacles = Director.KINDS.map(func(kd): return kd[0])
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var dt := 1.0 / 60.0
	# COMET STORM: one world, only comets, more and more of them at once
	save.event_week_test = 0
	main.start_event()
	var d = main.director
	ok(d.escalate and main.stage == 0 and absf(d.level(80.0) - 1.0) < 0.001 and d._overlap(80.0) < 0.4,
		"v120: events escalate (full speed at 80 s, patterns overlap)")
	var most := 0
	var kinds := {}
	var frames := 0
	while main.state == main.S.PLAYING and frames < 60 * 90:
		if frames % 2 == 0 and TestBot.decide(main):
			main._flip()
		main._grace = 0.0
		main.shield_until = INF
		main._process(dt)
		if main.gt > 60.0:
			most = maxi(most, main.hazards.size())
		for h in main.hazards:
			kinds[Director.kind_of(h)] = true
		frames += 1
	ok(most >= 3 and main.stage == 0, "v120: after a minute the comet storm has %d comets at once, still world 1" % most)
	ok(kinds.keys() == ["comet"], "v120: only comets, not even the first meteor %s" % str(kinds.keys()))
	main.state = main.S.DYING
	main._game_over()
	save.event_week_test = -999999
	# game over: place among my best runs and the next world
	ok(Stages.next_world(10) == [2, 5] and Stages.next_world(0) == [2, 15], "v120: next world and points missing")
	save.top_scores = []
	for sc in [200, 150, 120]:
		save.add_top_score(sc, 5)
	save.best = 200
	main.duel = {}
	main.start_run()
	main.score = 120
	main.state = main.S.DYING
	main._killer_kind = "saw"
	main._game_over()
	var l10n = get_root().get_node("L")
	ok(main.ui._over_place.text == l10n.t("OVER_PLACE", 3) or main.ui._over_place.text == l10n.t("OVER_PLACE", 4),
		"v120: game over says it was my #3/#4 best run (%s)" % main.ui._over_place.text)
	var nw := Stages.next_world(120)
	ok(main.ui._over_next.text == l10n.t("OVER_NEXT_WORLD", [int(nw[0]), int(nw[1])]), "v120: and how much was missing for world %d" % nw[0])
	# a bad run: a tip about what hit me (unless the continue offer is showing)
	main.ui._over_continue.visible = false
	main.ui._over_continue_free.visible = false
	main.ui.show_over_tip("saw")
	ok(main.ui._over_tip1.text == l10n.t("TIP_SAW_1") and main.ui._over_tip2.text == l10n.t("TIP_SAW_2"), "v120: tip about the saw")
	main.ui.show_over_tip("")
	ok(main.ui._over_tip1.text == l10n.t("TIP_ANY_1"), "v120: a general tip when the killer is unknown")
	for kd in Director.KINDS:
		ok(l10n.has("TIP_" + str(kd[0]).to_upper() + "_1"), "v120: a tip for %s" % kd[0])
	# welcome offer: after the 5th run (and the 20th), 48 h, the starter at half price in the shop
	save.games = 4
	save.welcome_count = 0
	save.daily_last = save._day_string()
	main.go_menu()
	ok(not (main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome"), "v120: no welcome offer before the 5th run")
	save.games = 5
	save.daily_last = save._day_string()
	main.go_menu()
	ok(main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome", "v120: the welcome offer shows after 5 runs")
	var secs: int = get_root().get_node("Monetization").welcome_secs()
	ok(secs > 47 * 3600 and secs <= 48 * 3600, "v120: for 48 hours (%d h)" % (secs / 3600))
	main.ui.hide_popup()
	main.go_menu()
	ok(not (main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome"), "v120: not again while it runs")
	main.ui._shop_tab = "packs"
	main.ui.refresh_shop()
	var shop_txt := ""
	for c in main.ui._shop_list.get_children():
		if c is Label:
			shop_txt += c.text + "|"
	ok(shop_txt.contains(l10n.t("WELCOME_LEFT", 48)), "v120: the shop shows the -50 % starter with its hours")
	# expired: again at the 20th run, then never
	save.welcome_until = 0
	save.games = 19
	main.go_menu()
	ok(not (main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome"), "v120: not at run 19")
	save.games = 20
	main.go_menu()
	ok(main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome" and save.welcome_count == 2, "v120: again after the 20th run")
	main.ui.hide_popup()
	save.welcome_until = 0
	save.games = 60
	main.go_menu()
	ok(not (main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "welcome"), "v120: two times at most")
	save.welcome_until = int(Time.get_unix_time_from_system()) + 3600
	save.grant("starter_50")
	ok(save.owns("starter") and save.owns("no_ads") and get_root().get_node("Monetization").welcome_secs() == 0,
		"v120: the half-price pack counts as the starter pack (no ads)")
	main.queue_free()
	await process_frame
	Orbit.reset()
	save.reset_all()


## 1.0.21: skins and trails by score (worth more), old unlocks kept, premium aura, obstacle info,
## ranking help.
func test_v121(save) -> void:
	# a first run to world 5 (90 points) no longer hands out a pile of skins
	save.reset_all()
	save.best = 90
	save.stats = {"best_world": 5}
	var got: Array = []
	for i in Catalog.SKINS.size():
		if save.unlocked("skins", i):
			got.append(Catalog.SKINS[i]["id"])
	var trails: Array = []
	for i in Catalog.TRAILS.size():
		if save.unlocked("trails", i):
			trails.append(Catalog.TRAILS[i]["id"])
	ok(got == ["poppy", "minty", "berry"] and trails == ["classic"], "v121: 90 points unlock 2 skins, no trail (%s / %s)" % [str(got), str(trails)])
	var by_world := 0
	for cat in ["skins", "trails"]:
		for it in Catalog.items(cat):
			if it["need"][0] == "world":
				by_world += 1
	ok(by_world == 0, "v121: nothing unlocks by world reached any more")
	# an old save keeps what it had: a player with world 9 under the old rules keeps MAGMA etc.
	var cfg := ConfigFile.new()
	cfg.set_value("stats", "best", 300)
	cfg.set_value("stats", "games", 40)
	cfg.set_value("player", "level", 12)
	cfg.set_value("progress", "stats", {"best_world": 9})
	cfg.save(save.path)
	save.load_data()
	var keep := ["frosty", "ember", "volt", "ghosty", "alien", "crystal", "cosmo", "magma"]
	var kept := true
	for id in keep:
		kept = kept and save.unlocked("skins", Catalog.find("skins", id))
	ok(kept and save.unlocked("trails", Catalog.find("trails", "galaxy")) and save.unlocked("trails", Catalog.find("trails", "smoke")),
		"v121: an old save keeps its skins and trails")
	ok(not save.unlocked("skins", Catalog.find("skins", "royal")) and save.unlock_rules == 2, "v121: but nothing more than it had")
	save.save_data()
	save.load_data()
	ok(save.unlocked("skins", Catalog.find("skins", "magma")), "v121: kept after saving and loading again")
	# premium look
	ok(Catalog.premium(Catalog.SKINS[Catalog.find("skins", "magma")]) and Catalog.premium(Catalog.SKINS[Catalog.find("skins", "ninja")])
		and not Catalog.premium(Catalog.SKINS[Catalog.find("skins", "minty")]), "v121: legendary / expensive skins are premium")
	save.reset_all()
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	main.ui.show_obstacle_info("boomerang")
	ok(main.ui.popup.visible and main.ui.popup.get_meta("kind", "") == "obstacle", "v121: an obstacle's info window")
	main.ui.show_rank_help()
	ok(main.ui.popup.get_meta("kind", "") == "rank_help", "v121: how to appear in the ranking")
	main.queue_free()
	await process_frame
	save.reset_all()
