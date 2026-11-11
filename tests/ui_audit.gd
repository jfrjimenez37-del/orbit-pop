extends SceneTree
## Text layout audit: opens every screen and popup in every language, with big numbers and long
## names, and reports text that leaves its box or the screen, or runs into other text or icons.
##   godot47 --headless --path . --script tests/ui_audit.gd [-- lang ...]
## Exit code = number of problems found (0 = clean).

const LONG_NAME := "Maximiliano Rodriguez"
const DUEL_NAME := "MMMMMMMMMM"     # widest possible duel name (10 letters)

var main: Node
var ui: Node
var sv: Node
var L: Node
var problems: Array = []
var screen := ""
var notch := 0.0   # --notch=N: a camera notch N viewport px tall
var shots := ""    # --shots=DIR: also save a screenshot of every screen (needs a display: xvfb-run)
var only := ""     # --only=TEXT: check (and shoot) only the screens whose name contains TEXT


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	sv = get_root().get_node("Save")
	sv.path = "user://ui_audit.cfg"
	sv.reset_all()
	L = get_root().get_node("L")
	var pg = get_root().get_node("Progress").games
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	ui = main.ui
	var langs: Array = []
	for a in args:
		if a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--notch="):
			notch = float(a.substr(8))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			get_root().size = Vector2i(int(wh[0]), int(wh[1]))
		else:
			langs.append(a)
	if langs.is_empty():
		langs = L.LANGS
	await process_frame
	print("screen %s -> canvas %s" % [get_root().size, main.get_viewport().get_visible_rect().size])
	for lang in langs:
		L.set_lang(lang)
		_big_save()
		pg.signed_in = true
		pg.available = true
		pg.player_name = LONG_NAME
		# screens are built once in the language of the moment: rebuild them for this language
		main.queue_free()
		await process_frame
		main = load("res://scenes/main.tscn").instantiate()
		get_root().add_child(main)
		await process_frame
		ui = main.ui
		ui.safe_top_test = notch
		await _audit_all(lang)
	for p in problems:
		print(p)
	print("UI AUDIT: %d problems" % problems.size())
	quit(problems.size())


func _big_save() -> void:
	sv.reset_all()
	sv.best = 99999; sv.games = 60; sv.total = 999999; sv.coins = 999999; sv.level = 99; sv.sessions = 9
	sv.stats = {"best_world": 16, "near_total": 9999}
	sv.daily_last = sv._day_string()
	sv.starter_seen = true
	sv.tutorial_done = true; sv.jump_tip_done = true   # no tutorial in recordings and bots


# ------------------------------------------------------------------ screens

func _audit_all(lang: String) -> void:
	main.go_menu()
	ui.hide_popup()
	await _check(lang, "menu")
	# missions: every daily mission and every weekly challenge, nearly complete (widest numbers)
	var P = get_root().get_node("Progress")
	for i in range(0, P.MISSIONS.size(), 3):
		var list: Array = []
		for k in 3:
			var mi: int = (i + k) % P.MISSIONS.size()
			list.append({"i": mi, "p": int(P.MISSIONS[mi]["goal"]) - 1, "done": false})
		sv.missions["day"] = sv.day_number()
		sv.missions["list"] = list
		sv.missions["week"] = floori(sv.day_number() / 7.0)
		sv.missions["weekly"] = {"i": (i / 3) % P.WEEKLY.size(), "p": int(P.WEEKLY[(i / 3) % P.WEEKLY.size()]["goal"]) - 1, "done": false}
		ui.show_mission()
		await _check(lang, "missions %d" % i)
	for w in P.WEEKLY.size():
		sv.missions["weekly"] = {"i": w, "p": int(P.WEEKLY[w]["goal"]) - 1, "done": false}
		ui.show_mission()
		await _check(lang, "weekly %d" % w)
	ui.show_settings()
	await _check(lang, "settings")
	for cat in ["skins", "trails"]:
		var longest := 0
		for i in Catalog.items(cat).size():
			if str(Catalog.items(cat)[i]["name"]).length() > str(Catalog.items(cat)[longest]["name"]).length():
				longest = i
		ui.show_reveal(cat, longest)
		await _check(lang, "reveal " + cat)
	ui.hide_popup()
	var before: Array = P.missions() + [P.weekly()]
	var after: Array = []
	for m in before:
		var m2: Dictionary = m.duplicate()
		m2["progress"] = int(m2["goal"]) - 1
		after.append(m2)
	after[1]["done"] = true
	ui.show_mission_progress(before, after)
	await _check(lang, "mission card")
	ui.show_daily()
	await _check(lang, "daily gift")
	ui.show_starter()
	await _check(lang, "starter")
	for o in [["no_ads", "OFFER_ADS"], ["starter", "OFFER_CLOSE"], ["coins_5000", "OFFER_CLOSE"],
			["coins_1500", "OFFER_UPGRADE"], ["star_pack", "OFFER_MILESTONE"], ["trail_pack", "OFFER_MILESTONE"],
			["supporter", "OFFER_MILESTONE"]]:
		ui.show_offer(o[0], o[1])
		await _check(lang, "offer " + o[0])
	sv.daily_run = {"day": sv.daily_today(), "tries": 2, "video": 1, "best": 99999, "paid": true}
	ui.show_duel()
	await _check(lang, "challenges")
	# every weekly event: its window (best 99999, two goals paid) and the challenges row
	for wk in Events.LIST.size():
		var w0: int = sv.event_week()
		var week: int = w0 - posmod(w0, Events.LIST.size()) + wk
		sv.event_run = {"week": week, "tries": 3, "best": 99999, "paid": 2}
		sv.event_week_test = week
		ui.show_event()
		await _check(lang, "event " + str(Events.for_week(week)["id"]))
		ui.show_duel()
		await _check(lang, "challenges " + str(Events.for_week(week)["id"]))
		ui.set_event_target(L.t("EV_" + str(Events.for_week(week)["id"]).to_upper()), 0)
		await _check(lang, "hud event name " + str(Events.for_week(week)["id"]))
	sv.event_week_test = -999999
	ui.show_duel_accept(Duel.decode(Duel.encode(12345, 9999, DUEL_NAME)))
	await _check(lang, "duel accept")
	ui.hide_popup()
	for tab in ["skins", "trails"]:
		main.open_skins()
		ui._style_tab = tab
		ui._style_focus = 0
		for page in ceili(Catalog.items(tab).size() / 9.0):
			ui._style_page = page
			ui._refresh_style()
			await _check(lang, "style %s p%d" % [tab, page])
	main.open_abilities()
	await _check(lang, "abilities")
	for tab in ["packs", "coins"]:
		ui.show_shop(tab)
		await _check(lang, "shop " + tab)
	main.open_ranking()
	for tab in ["ranking", "achievements"]:
		ui._rank_tab = tab
		ui.refresh_ranking()
		await _check(lang, tab)
	# obstacle collection: every kind seen (longest texts), then all locked but the meteor
	ui._rank_tab = "obstacles"
	for half in [["meteor"], Director.KINDS.map(func(kd): return kd[0])]:
		sv.seen_obstacles = half
		for page in 2:
			ui._rank_page = page
			ui.refresh_ranking()
			await _check(lang, "obstacles %d p%d" % [half.size(), page])
	# in a run
	main.duel = {}
	main.start_run()
	main.score = 99999
	ui.set_score(99999)
	ui.set_altitude(99999)
	ui.set_run_coins(9999)
	ui.set_teleport(9)
	ui.set_turbo(9)
	await _check(lang, "hud")
	ui.world_banner(16, _longest_world_name(), L.t("MOVE_TIP"), L.t(Stages.LAYERS[-1][1]))
	await _check(lang, "world banner")
	ui.announce_record()
	await _check(lang, "hud record")
	for tip in [["TAP_HINT", "TUT_TAP_SUB"], ["TUT_NICE", "TUT_NICE_SUB"], ["TUT_JUMP", "TUT_JUMP_SUB"], ["TUT_NICE", "TUT_JUMP_DONE"], ["TIP_HOLD", "TIP_HOLD_SUB"], ["TIP_SWIPE", "TIP_SWIPE_SUB"]]:
		ui.show_tip(L.t(tip[0]), L.t(tip[1]))
		await _check(lang, "tip " + tip[1])
	for kd in Director.KINDS:
		var key: String = "OB_" + str(kd[0]).to_upper()
		ui.show_tip(L.t("NEW_OB_T", L.t(key)), L.t(key + "_D"))
		await _check(lang, "tip new " + str(kd[0]))
	for sk in Director.SURGE_KINDS:
		var skey: String = "SURGE_" + str(sk).to_upper()
		ui.show_tip(L.t(skey), L.t(skey + "_D"))
		await _check(lang, "tip surge " + str(sk))
	ui.hide_tip()
	ui.set_combo(99, 5)
	await _check(lang, "hud combo")
	ui.set_combo(0, 1)
	ui.hide_tip()
	ui.set_duel_target(DUEL_NAME, 9999)
	await _check(lang, "hud duel")
	ui.set_daily_target(99999)
	await _check(lang, "hud daily")
	ui.set_event_target("X", 99999)
	await _check(lang, "hud event")
	ui.show_pause()
	await _check(lang, "pause")
	ui.show_game_over(99999, 99999, true, [Catalog.find("skins", "crystal")], true, false)
	await _check(lang, "game over")
	# a bad run: place among my best, the next world, a tip under the card (no continue offer)
	sv.top_scores = [{"s": 99999, "w": 16}, {"s": 99998, "w": 16}, {"s": 99990, "w": 16}]
	ui.show_game_over(99990, 99999, false, [], false, false)
	ui.show_over_progress(99990, false, true)
	ui.show_over_tip("belt")
	await _check(lang, "game over tip")
	for kd in Director.KINDS:
		ui.show_over_tip(str(kd[0]))
		await _check(lang, "game over tip " + str(kd[0]))
	ui.show_over_progress(5, false, true)
	await _check(lang, "game over far")
	ui.show_welcome()
	await _check(lang, "welcome offer")
	ui.hide_popup()
	ui.show_rank_help()
	await _check(lang, "rank help")
	for kd in Director.KINDS:
		ui.show_obstacle_info(str(kd[0]))
		await _check(lang, "obstacle info " + str(kd[0]))
	ui.hide_popup()
	for dr in [{"mode": "new", "mine": 9999, "theirs": -1, "name": "", "pay": 0, "result": "", "code": "X"},
			{"mode": "reply", "mine": 9999, "theirs": 9998, "name": DUEL_NAME, "pay": 50, "result": "win", "code": "X"},
			{"mode": "reply", "mine": 1, "theirs": 9999, "name": DUEL_NAME, "pay": 10, "result": "loss", "code": "X"},
			{"mode": "reply", "mine": 9999, "theirs": 9999, "name": DUEL_NAME, "pay": 25, "result": "tie", "code": "X"},
			{"mode": "daily", "best": true, "pay": 30, "today": 99999, "mine": 99999, "tries": 2, "video": 1},
			{"mode": "event", "best": true, "pay": 270, "week": 99999, "mine": 99999, "paid": 3},
			{"mode": "event", "best": false, "pay": 0, "week": 99999, "mine": 5, "paid": 3}]:
		ui.show_game_over(dr["mine"], 99999, false, [], false, false)
		ui.show_duel_result(dr)
		await _check(lang, "result " + str(dr["mode"]) + " " + str(dr.get("result", "")))


func _longest_world_name() -> String:
	var best := ""
	for i in Stages.LIST.size():
		var n: String = L.t("WORLD_" + str(Stages.world(i)["id"]).to_upper())
		if n.length() > best.length():
			best = n
	return best


# ------------------------------------------------------------------ checks

func _check(lang: String, name: String) -> void:
	screen = "[%s] %s" % [lang, name]
	if only != "" and name.find(only) < 0:
		return
	await create_timer(0.3).timeout   # layout and the short pop-in tweens (scale) settle
	if shots != "":
		get_root().get_texture().get_image().save_png("%s/%s_%s.png" % [shots, lang, name.replace(" ", "_")])
	var vp: Rect2 = Rect2(Vector2.ZERO, ui.root.size if "root" in ui else main.get_viewport().get_visible_rect().size)
	var items: Array = []   # [kind, rect, frame, node]
	_collect(ui, items)
	if ui.menu.visible and ui._menu_logo.is_visible_in_tree() and not ui.popup.visible:
		items.append(["icon", ui._menu_logo.get_global_rect(), null, ui._menu_logo])
		# the logo must not sit under a menu button either
		var lr: Rect2 = ui._menu_logo.get_global_rect()
		for b in ui.menu.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree():
				var ir: Rect2 = lr.intersection((b as Button).get_global_rect())
				if ir.size.x > 0.5 and ir.size.y > 0.5:
					var key := "%s | a menu button covers the logo  (x %.0f-%.0f, y %.0f-%.0f)" % [screen, ir.position.x, ir.end.x, ir.position.y, ir.end.y]
					if not problems.has(key):
						problems.append(key)
	var popup_open: bool = ui.popup.visible
	for it in items:
		if it[0] != "label" or (popup_open and not ui.popup.is_ancestor_of(it[3])):
			continue
		var r: Rect2 = it[1]
		var l: Label = it[3]
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > vp.size.x + 0.5 or r.end.y > vp.size.y + 0.5:
			_report(l, "off screen", r)
		var fr: Control = it[2]
		if fr != null:
			var fb: Rect2 = fr.get_global_rect().grow(0.5)
			if not fb.encloses(r):
				_report(l, "outside its %s" % fr.get_class(), r)
	# text running into text or icons of the same box
	for a in items.size():
		var A: Array = items[a]
		if A[0] != "label" or (popup_open and not ui.popup.is_ancestor_of(A[3])):
			continue
		for b in items.size():
			if b == a:
				continue
			var B: Array = items[b]
			if B[2] != A[2] or (B[0] == "label" and b < a):
				continue
			var inter: Rect2 = (A[1] as Rect2).intersection(B[1])
			if inter.size.x > 0.5 and inter.size.y > 0.5:
				_report(A[3], "runs into %s" % ("'" + (B[3] as Label).text + "'" if B[0] == "label" else "an icon"), A[1])
	# a popup's title over the screen behind it
	if popup_open:
		for it in items:
			if it[0] != "label" or not ui.popup.is_ancestor_of(it[3]) or it[2] != null:
				continue
			for other in items:
				if other[0] == "label" and not ui.popup.is_ancestor_of(other[3]):
					var i2: Rect2 = (it[1] as Rect2).intersection(other[1])
					if i2.size.x > 0.5 and i2.size.y > 0.5:
						_report(it[3], "covers '%s' behind the popup" % (other[3] as Label).text, it[1])


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is Control and ui.popup.visible and not (ui.popup == c or ui.popup.is_ancestor_of(c)) and not _behind_popup_ok(c):
			pass
		# with a popup open only the popup counts (plus what its title covers, checked apart)
		var behind: bool = ui.popup.visible and c is CanvasItem and not (ui.popup == c or ui.popup.is_ancestor_of(c) or c.is_ancestor_of(ui.popup))
		if c is Label:
			var l := c as Label
			# "!" badges sit on a button's corner on purpose
			if l.text.strip_edges() != "" and l.text != "!" and not (l.text.begins_with("x") and l.text.substr(1).is_valid_int()) and l.modulate.a > 0.05 and l.self_modulate.a > 0.05 and (not behind or _is_menu_text(l)):
				out.append(["label", _text_rect(l), _frame_of(l), l])
		elif c is TextureRect and not behind and (c as TextureRect).texture != null and _frame_of(c) != null:
			var t := c as TextureRect
			if t.texture.get_width() <= 24 and t.modulate.a > 0.05:   # icons, not artwork
				out.append(["icon", t.get_global_rect(), _frame_of(t), t])
		_collect(c, out)


func _behind_popup_ok(_c: Node) -> bool:
	return true


## Menu texts behind a popup are only used for the "popup title covers them" check.
func _is_menu_text(l: Label) -> bool:
	return ui.menu.is_ancestor_of(l)


## The box a node lives in: its nearest panel or button (null = the screen itself).
func _frame_of(n: Node) -> Control:
	var p := n.get_parent()
	while p != null and p != ui:
		if p is Button or p is NinePatchRect:
			return p
		p = p.get_parent()
	return null


## Where the glyphs really are (not the Label's box): text width x scale, aligned in the box.
func _text_rect(l: Label) -> Rect2:
	var font: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	var lines := l.text.split("\n")
	var tw := 0.0
	for line in lines:
		tw = maxf(tw, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var th := font.get_height(fs) * lines.size()
	var x0 := 0.0
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x0 = (l.size.x - tw) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x0 = l.size.x - tw
	var xf := l.get_global_transform()
	var s := xf.get_scale()
	# the pixel font draws in the top 8 px of its 10 px line: trim the empty bottom
	return Rect2(xf.origin + Vector2(x0, 0) * s, Vector2(tw, th - 2.0) * s)


func _report(l: Label, what: String, r: Rect2) -> void:
	var key := "%s | '%s' %s" % [screen, l.text.replace("\n", " / "), what]
	if not problems.has(key):
		problems.append(key + "  (x %.0f-%.0f, y %.0f-%.0f)" % [r.position.x, r.end.x, r.position.y, r.end.y])
