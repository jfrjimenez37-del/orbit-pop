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
	print("== fairness on every world shape")
	await test_worlds(save)
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
	# non-round orbits (ellipses, offset circles): collisions follow the real curve, so the
	# player never dies more than a hair away from a hazard (hitbox is already smaller than the art)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var worst_ghost := 0.0
	var big_miss := 0
	var worst_seg := 0.0
	var seg_miss := 0
	for si in Stages.LIST.size():
		Orbit.set_shape(Stages.LIST[si]["orbits"], true)
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
	r1 = save.submit_run(12 + 4)
	ok(r1["unlocked"].has(minty), "MINTY unlocked at 16")
	var r2: Dictionary = save.submit_run(5)
	ok(not r2["record"], "lower score is not a record")
	save.skin = minty
	save.save_data()
	save.best = 0; save.games = 0; save.skin = 0
	save.load_data()
	ok(save.best == 16 and save.games == 2 and save.total == 21, "stats persisted (%d,%d,%d)" % [save.best, save.games, save.total])
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
	# world-reached skins
	var ghosty := Catalog.find("skins", "ghosty")
	save.stats["best_world"] = 5
	ok(not save.is_unlocked(ghosty), "GHOSTY locked before world 6")
	save.stats["best_world"] = 6
	ok(save.is_unlocked(ghosty) and save.submit_run(1)["unlocked"].has(ghosty), "GHOSTY unlocked at world 6 and announced")
	save.stats = {}
	var omega := Catalog.find("skins", "omega")
	save.best = 999
	ok(not save.is_unlocked(omega), "OMEGA needs 1000")
	save.best = 1000
	ok(save.is_unlocked(omega), "OMEGA unlocked at 1000")
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
	ok(absf(d.level(0.0)) < 0.001 and d.level(400.0) > 0.999, "level spans 0..1")
	ok(d.omega(400.0) <= 3.46, "speed capped")
	var base := Director.new(); base.reset(1, 12.0)
	var easy := Director.new(); easy.reset(1, 2.0)
	var hard := Director.new(); hard.reset(1, 60.0)
	ok(easy.level(20.0) < base.level(20.0) and hard.level(20.0) > base.level(20.0), "adaptive offset works")


func test_monetization(save) -> void:
	var mon = get_root().get_node("Monetization")
	mon.use_test_providers()
	save.reset_all()
	var now := [1000.0]
	mon.clock = func() -> float: return now[0]
	# interstitials: never for new players, never during a run, paced by runs and time
	save.games = 2
	for i in 5:
		mon.on_game_over()
	ok(not mon.should_show_interstitial(), "no interstitial before the 3rd run")
	save.games = 10
	ok(mon.should_show_interstitial(), "interstitial allowed after grace + 3 runs")
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
	ok(mon.should_show_interstitial(), "mandatory ad on the 3rd retry")
	save.grant("no_ads")
	ok(not mon.should_show_interstitial(), "NO ADS removes interstitials")
	ok(mon.can_continue(10, false), "rewarded continue still offered with NO ADS")
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
	save.coins = 1000
	ok(save.buy_ability("coins") and save.ability("coins") == 2 and save.coins == 0, "ability upgraded with coins")
	ok(not save.buy_ability("coins"), "upgrade refused without coins")
	save.level = 15
	ok(save.ability("secondlife") == 0 and Upgrades.price("secondlife", 0) == 15000, "SECOND LIFE must be bought")
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
	ok(Orbit.count() == 2 and Orbit.crossings.size() == 4, "night: 2 orbits, 4 crossings (%d)" % Orbit.crossings.size())
	var c: float = Orbit.crossings[0]["a"][0]
	ok(absf(Orbit.radius(0, c) - Orbit.radius(1, c)) < 1.5, "orbits meet at the crossing")
	var tr := Orbit.tap_result(c, 0, 1)
	ok(tr[0] == 1 and tr[1] == 1, "tap at a crossing switches orbit, keeps direction")
	ok(Orbit.tap_result(c + 0.6, 0, 1).slice(0, 2) == [0, -1], "tap elsewhere reverses")
	# two planets: figure-eight switching keeps the player on the same spot
	for si in [5, 6]:
		Orbit.set_shape(Stages.LIST[si]["orbits"], true)
		ok(Orbit.planets().size() == 2 and Orbit.crossings.size() == 2, "%s: 2 planets, 2 crossings" % Stages.LIST[si]["world"])
		var cx: Dictionary = Orbit.crossings[0]
		var r2 := Orbit.tap_result(cx["a"][0], 0, 1)
		ok(r2[0] == 1 and Orbit.pos(1, r2[2]).distance_to(Orbit.pos(0, cx["a"][0])) < 1.0, "%s: switch lands on the same point" % Stages.LIST[si]["world"])
		var t0: Vector2 = Orbit._tangent(0, cx["a"][0])
		var t1: Vector2 = Orbit._tangent(1, r2[2]) * r2[1]
		ok(t0.dot(t1) > 0.0, "%s: motion continues forward after switching" % Stages.LIST[si]["world"])
		ok(Orbit.extent() + 8.0 <= 96.0 and absf(Orbit.pos(0, 0).x) + 8.0 <= 90.0, "%s fits the screen" % Stages.LIST[si]["world"])
	# three planets: every orbit reachable, everything on screen, no orbit through a planet
	for si in [7, 8, 9]:
		var nm: String = Stages.LIST[si]["world"]
		Orbit.set_shape(Stages.LIST[si]["orbits"], true)
		ok(Orbit.planets().size() == 3 and Orbit.crossings.size() >= 4, "%s: 3 planets, %d crossings" % [nm, Orbit.crossings.size()])
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
		for cx in Orbit.crossings:
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
	c = Orbit.crossings[0]["a"][0]
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
	for d in 15:
		save.clock_override = day0 + d * 86400
		var idx: Array = prog.daily_indices(save.day_number())
		distinct = distinct and idx.size() == 3 and idx[0] != idx[1] and idx[1] != idx[2] and idx[0] != idx[2]
		seen[idx[0]] = true
	ok(distinct and seen.size() == 15, "3 different missions a day, the whole pool of 15 in 15 days")
	save.clock_override = day0
	var first: Array = prog.daily_indices(save.day_number())
	save.clock_override = day0 + 15 * 86400
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
	var all_ids: Array = PlayGamesConfig.ACHIEVEMENTS.values() + PlayGamesConfig.LEADERBOARDS.values()
	var uniq := {}
	for v in all_ids:
		uniq[v] = true
	ok(not all_ids.has("") and uniq.size() == all_ids.size(), "every Play Games id is set and unique")
	for a in prog.ACHIEVEMENTS:
		if a["id"] == "skins_all":
			ok(int(a["goal"]) == Catalog.SKINS.size(), "EVERY SKIN goal matches the catalog")
	ok(Stages.index_for_score(29) == 0 and Stages.index_for_score(30) == 1 and Stages.number_for_score(450) == 10, "wider world spacing")
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
		if key == "SHARE_TEXT":
			continue
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
	l10n.set_lang("en")
	save.reset_all()


func test_abilities(save) -> void:
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
	ok(Stages.bounds(0) == Vector2i(0, 30) and Stages.bounds(70) == Vector2i(65, 105)
		and Stages.bounds(530) == Vector2i(520, 580), "world progress bounds")
	# region override
	save.region = "EUROPE"
	ok(get_root().get_node("Progress").region() == "EUROPE", "region picked in settings wins")
	save.region = ""
	ok(get_root().get_node("Progress").region() == PlayGamesConfig.region(), "AUTO region follows the phone")
	# in-app review: only after a record, after some runs, once a month, 3 times at most
	ok(not Reviewer.should_ask(3, true, 80, 0, -9999, 100), "no review prompt in the first runs")
	ok(not Reviewer.should_ask(20, false, 80, 0, -9999, 100), "no review prompt without a record")
	ok(not Reviewer.should_ask(20, true, 10, 0, -9999, 100), "no review prompt for a tiny record")
	ok(Reviewer.should_ask(20, true, 80, 0, -9999, 100), "review prompt after a good record")
	ok(not Reviewer.should_ask(20, true, 80, 1, 90, 100) and Reviewer.should_ask(20, true, 80, 1, 70, 100), "at most once every 30 days")
	ok(not Reviewer.should_ask(20, true, 80, 3, -9999, 100), "3 prompts at most")
	save.games = 20
	var rv: Reviewer = get_root().get_node("Progress").reviewer
	ok(rv.maybe_ask(save, true, 80) and save.review_asks == 1 and not rv.maybe_ask(save, true, 90), "asking is remembered")
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
func test_worlds(save) -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	main.set_process(false)
	main.ui.hide_popup()
	var dt := 1.0 / 60.0
	for si in Stages.LIST.size():
		main.start_run()
		main.director.offset = 60.0
		Orbit.set_shape(Stages.LIST[si]["orbits"], true)
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
