class_name GameUI
extends CanvasLayer
## All ORBIT POP screens, built in code with the pixel UI kit and localized through L.t():
## menu, HUD, game over, style (skins/trails), shop, ranking/achievements, pause and popups
## (daily gift, starter offer, missions, settings) and the abilities screen.

signal play_pressed
signal retry_pressed
signal menu_pressed
signal skins_pressed
signal skin_selected(index: int)
signal continue_pressed
signal double_pressed
signal shop_pressed
signal buy_pressed(product_id: String)
signal restore_pressed
signal style_changed
signal abilities_pressed
signal slowmo_pressed
signal daily_claim(doubled: bool)
signal free_coins_pressed
signal teleport_pressed
signal share_pressed
signal ability_video_pressed
signal ranking_pressed
signal language_changed
signal pause_pressed
signal resume_pressed
signal quit_pressed
signal duel_new_pressed
signal duel_accept_pressed(duel: Dictionary)
signal duel_send_pressed
signal daily_pressed
signal event_pressed
signal daily_video_pressed

const FONT := preload("res://assets/font/pixel.fnt")
const FONT_PLAIN := preload("res://assets/font/pixel_plain.fnt")  # no outline: dark text on light UI
const SPR := "res://assets/sprites/"
const PINK := Color8(255, 128, 178)
const GOLD := Color8(255, 222, 70)
const INK := Color8(38, 28, 66)
const MUTED := Color8(120, 100, 150)
const COIN_INK := Color8(176, 112, 20)
const GREEN_INK := Color8(40, 150, 100)
const TABS := ["skins", "trails"]

var root: Control
var menu: Control
var hud: Control
var over: Control
var skins: Control
var pause: Control
var shop: Control
var ranking: Control
var abilities: Control
var popup: Control
var flash_rect: ColorRect

var _score_lbl: Label
var _hud_best: Label
var _hint: Label
var _tip: Control
var _tip_title: Label
var _tip_sub: Label
var _tip_until := -1.0
var _banner: Control
var _teleport_btn: Button
var _pause_btn: Button
var _rank_box: Control
var _menu_best: Label
var _menu_coins: Label
var _gift_badge: Label
var _mission_badge: Label
var _ab_badge: Label
var _shop_badge: Label
var _duel_badge: Label
var _offer_clock: Label          # countdown in the offer popup / the shop row of the live offer
var _offer_clock_id := ""
var _offer_clock_short := false
var _offer_clock_parent_w := 156.0
var _ab_box: Control
var _ab_list: Control
var _run_coins_box: Control
var _menu_logo: TextureRect
var _menu_top_right: Control
var _mission_card: Control
var _menu_best_box: Control
var _alt_lbl: Label
var _style_box: Control
var _menu_coin_box: Control
var _hud_top: Control
var _style_glow: PremiumGlow
var _over_place: Label
var _over_next: Label
var _over_tip1: Label
var _over_tip2: Label
var _combo_lbl: Label
var _combo_shown := 0
var _over_box: Control
var _run_coins_lbl: Label
var _menu_level: Label
var _menu_xp: ColorRect
var _slowmo_btn: Button
var _teleport_count: Label
var _slowmo_count: Label
var _wp_bg: ColorRect
var _wp_fill: ColorRect
var _wp_best: ColorRect
var _over_xp: Label
var _over_xp_bg: ColorRect
var _over_xp_fill: ColorRect
var _over_score: Label
var _over_best: Label
var _over_best_cap: Label
var _over_record: Control
var _over_unlock: Label
var _over_coins: Label
var _over_double: Button
var _over_buttons: Array[Button] = []
var _over_continue: Button
var _over_continue_free: Button
var _over_panel: NinePatchRect
var _over_duel: Button           # duel game over: CHALLENGE! / SEND RESULT / REMATCH
var _over_duel_mode := ""
var _pause_title: Label
# style screen
var _style_tab := "skins"
var _style_page := 0
var _style_focus := 0
var _style_tabs := {}
var _style_cards: Array = []
var _style_preview: TextureRect
var _style_name: Label
var _menu_name: Label
var _over_rank: Label
var _over_ranks := {}
var _over_was_record := false
var _rank_board := ""   # "" = my best runs, else a leaderboard key
var _board_rows := {}
var _style_need: Label
var _style_rarity: Label
var _style_action: Button
var _style_page_lbl: Label
var _style_coins: Label
var _style_arrows: Array = []
# shop / ranking
var _shop_tab := "packs"
var _shop_tabs := {}
var _shop_list: Control
var _shop_box: Control
var _rank_tab := "ranking"
var _rank_tabs := {}
var _rank_tab_box: Control
var _rank_list: Control
var _rank_page := 0
var _popup_box: Control
var _toast: Label
var _toasts: Array = []
var _toast_busy := false
var _t := 0.0


func _ready() -> void:
	# localized store prices may use symbols the pixel font lacks (₹, ¥, ...)
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["sans-serif"])
	sys.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	for f in [FONT, FONT_PLAIN]:
		if f.fallbacks.is_empty():
			f.fallbacks = [sys]
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 8
	root.theme = th
	add_child(root)
	_build_menu()
	_build_hud()
	_build_over()
	_build_style()
	_build_pause()
	_build_shop()
	_build_ranking()
	_build_abilities()
	_build_popup()
	var pg = Progress.games
	pg.player_loaded.connect(func(_n): refresh_menu())
	pg.rank_loaded.connect(_on_rank_loaded)
	pg.top_loaded.connect(_on_top_loaded)
	_toast = _label(root, "", 1)
	var tb := StyleBoxFlat.new()
	tb.bg_color = Color(0.15, 0.1, 0.26, 0.92)
	tb.set_content_margin_all(3)
	_toast.add_theme_stylebox_override("normal", tb)
	_toast.visible = false
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(flash_rect)


func _process(delta: float) -> void:
	_t += delta
	if _hint and _hint.visible:
		_hint.modulate.a = 1.0 if fmod(_t, 0.9) < 0.6 else 0.25
	if _tip and _tip.visible:
		_tip_title.modulate.a = 1.0 if fmod(_t, 0.8) < 0.55 else 0.55
		if _tip_until >= 0.0 and _t >= _tip_until:
			hide_tip()
	if _over_record and _over_record.visible:
		_over_record.modulate = Color.WHITE if fmod(_t, 0.5) < 0.3 else Color(1, 0.85, 0.4)
	for b in [_gift_badge, _mission_badge, _shop_badge, _duel_badge]:
		if b and b.visible:
			b.position.y = -4 + roundf(sin(_t * 6.0))
	if _offer_clock != null and is_instance_valid(_offer_clock) and _offer_clock.is_visible_in_tree():
		_tick_offer_clock()
	if skins.visible and _style_tab == "skins":
		var fr: int = [0, 1, 2, 1][int(_t * 10.0) % 4]
		(_style_preview.texture as AtlasTexture).region = Rect2(fr * 16, 0, 16, 16)


# ------------------------------------------------------------------ kit

func _tex(name: String) -> Texture2D:
	return load(SPR + name + ".png")


func _box(name: String, margin := 4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _tex(name)
	sb.texture_margin_left = margin; sb.texture_margin_right = margin
	sb.texture_margin_top = margin; sb.texture_margin_bottom = margin + 1
	return sb


func _label(parent: Control, text: String, scale := 1, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.scale = Vector2(scale, scale)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if color.get_luminance() < 0.62:
		l.add_theme_font_override("font", FONT_PLAIN)
	parent.add_child(l)
	return l


func _text_w(s: String) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


## Places a label horizontally centered (in parent space) at y; big text shrinks to fit.
func _center_label(l: Label, parent_w: float, y: float) -> void:
	var w := _text_w(l.text)
	while l.scale.x > 1 and w * l.scale.x > parent_w - 4:
		l.scale -= Vector2.ONE
	l.size = Vector2(w, 10)
	l.position = Vector2(roundf((parent_w - w * l.scale.x) * 0.5), y)


func _left_label(parent: Control, text: String, pos: Vector2, color := INK) -> Label:
	var l := _label(parent, text, 1, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.position = pos
	return l


func _icon(parent: Control, name: String, pos: Vector2, scale := 1) -> TextureRect:
	var ir := TextureRect.new()
	ir.texture = _tex(name)
	ir.position = pos
	ir.scale = Vector2(scale, scale)
	ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ir)
	return ir


func _panel(parent: Control, pos: Vector2, size: Vector2) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = _tex("panel")
	p.patch_margin_left = 4; p.patch_margin_right = 4
	p.patch_margin_top = 4; p.patch_margin_bottom = 4
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _button(parent: Control, style: String, text: String, icon: String, size: Vector2, text_scale := 1) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	_style_button(b, style)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = size
	content.name = "Content"
	b.add_child(content)
	var iw := 11.0 if icon != "" else 0.0
	var gap := 2.0 if icon != "" and text != "" else 0.0
	# shrink big text that does not fit (long translations)
	while text != "" and text_scale > 1 and _text_w(text) * text_scale + iw + gap > size.x - 6:
		text_scale -= 1
	var tw := _text_w(text) * text_scale if text != "" else 0.0
	var x := roundf((size.x - tw - iw - gap) * 0.5)
	var cy := roundf((size.y - 2.0) * 0.5)
	if icon != "":
		var ir := _icon(content, "icon_" + icon, Vector2(x, cy - 5))
		ir.name = "Icon"
		x += iw + gap
	if text != "":
		var l := _label(content, text, text_scale, INK if style != "pink" else Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.position = Vector2(x, cy - 4 * text_scale)
		l.name = "Text"
	b.button_down.connect(func(): content.position.y = 1)
	b.button_up.connect(func(): content.position.y = 0)
	b.pressed.connect(func(): Sfx.play("select"))
	return b


func _style_button(b: Button, style: String) -> void:
	b.add_theme_stylebox_override("normal", _box("btn_" + style))
	b.add_theme_stylebox_override("hover", _box("btn_" + style))
	b.add_theme_stylebox_override("disabled", _box("btn_" + style))
	b.add_theme_stylebox_override("pressed", _box("btn_" + style + "_pressed"))


## Re-centers icon + text of a kit button after changing its text.
func _set_button_text(b: Button, text: String) -> void:
	var c: Control = b.get_node("Content")
	var l: Label = c.get_node_or_null("Text")
	var ic: TextureRect = c.get_node_or_null("Icon")
	if l == null:
		return
	l.text = text
	var tw := _text_w(text) * l.scale.x
	var iw := 13.0 if ic and ic.visible else 0.0
	var x := roundf((b.size.x - tw - iw) * 0.5)
	if ic:
		ic.position.x = x
	l.position.x = x + iw


func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	return c


func _dim(parent: Control, a := 0.35) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.2, 0.45, a)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)


## Anchors `c` to the top/bottom center of its parent with a given y offset.
func _place(c: Control, anchor_y: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.5; c.anchor_right = 0.5
	c.anchor_top = anchor_y; c.anchor_bottom = anchor_y
	c.offset_left = -roundf(w * 0.5); c.offset_right = c.offset_left + w
	c.offset_top = y; c.offset_bottom = y + h


func _container(parent: Control) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _clear(c: Control) -> void:
	for ch in c.get_children():
		ch.queue_free()


func _tabs(parent: Control, ids: Array, names: Array, icons: Array, store: Dictionary, cb: Callable) -> void:
	var w := floori(164.0 / ids.size()) - 4
	for i in ids.size():
		var id: String = ids[i]
		var b := _button(parent, "white", names[i], icons[i], Vector2(w, 18))
		b.position = Vector2(i * (w + 4) + 2, 0)
		b.pressed.connect(cb.bind(id))
		store[id] = b


func _switch(to: Control) -> void:
	for s in [menu, hud, over, skins, pause, shop, ranking, abilities]:
		if s != to and s.visible and s != hud:
			s.visible = false
	if to != hud:
		hud.visible = false
	to.visible = true
	to.modulate.a = 0.0
	to.position.y = 6
	var tw := create_tween().set_parallel()
	tw.tween_property(to, "modulate:a", 1.0, 0.16)
	tw.tween_property(to, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ menu

func _build_menu() -> void:
	menu = _screen()
	var logo := TextureRect.new()
	logo.texture = _tex("logo")
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(logo)
	_place(logo, 0.0, 14, logo.texture.get_width(), logo.texture.get_height())
	_menu_logo = logo
	var best_box := _container(menu)
	_place(best_box, 0.0, logo.texture.get_height() + 16, 150, 10)
	_menu_best_box = best_box
	_menu_best = _label(best_box, "", 1, GOLD)
	_menu_level = _label(best_box, "", 1, Color.WHITE)
	var xp_bg := ColorRect.new()
	xp_bg.color = Color(0.1, 0.08, 0.25, 0.55)
	xp_bg.position = Vector2(45, 23)
	xp_bg.size = Vector2(60, 3)
	best_box.add_child(xp_bg)
	_menu_xp = ColorRect.new()
	_menu_xp.color = Color8(120, 230, 255)
	_menu_xp.position = Vector2(45, 23)
	_menu_xp.size = Vector2(0, 3)
	best_box.add_child(_menu_xp)
	_menu_name = _label(best_box, "", 1, Color.WHITE)
	_menu_name.position.y = 30
	var cb := _container(menu)
	cb.position = Vector2(6, 4)
	_menu_coin_box = cb
	_icon(cb, "icon_coin", Vector2.ZERO)
	_menu_coins = _label(cb, "0", 1, GOLD)
	_menu_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_coins.position = Vector2(11, 0)
	var play := _button(menu, "yellow", L.t("PLAY"), "", Vector2(84, 28), 2)
	_place(play, 1.0, -64, 84, 28)
	play.pressed.connect(func(): play_pressed.emit())
	var bb := _button(menu, "white", "", "bolt", Vector2(26, 28))
	_place(bb, 1.0, -64, 26, 28)
	bb.offset_left -= 60; bb.offset_right -= 60
	bb.pressed.connect(func(): abilities_pressed.emit())
	_ab_badge = _label(bb, "!", 1, GOLD)
	_ab_badge.position = Vector2(21, -4)
	var rk := _button(menu, "white", "", "trophy", Vector2(26, 28))
	_place(rk, 1.0, -64, 26, 28)
	rk.offset_left += 60; rk.offset_right += 60
	rk.pressed.connect(func(): ranking_pressed.emit())
	# top right: shop, daily gift and settings (inset from the corner: rounded screens and notches)
	_menu_top_right = _container(menu)
	_menu_top_right.anchor_left = 1.0; _menu_top_right.anchor_right = 1.0
	_menu_top_right.offset_left = -85; _menu_top_right.offset_top = 3
	for k in 3:
		var tb := _button(_menu_top_right, "white" if k == 2 else "pink", "", ["cart", "gift", "gear"][k], Vector2(24, 20))
		tb.position = Vector2(k * 27, 0)
		tb.pressed.connect([func(): shop_pressed.emit(), show_daily, show_settings][k])
		if k == 2:
			continue
		var badge := _label(tb, "!", 1, GOLD)
		badge.position = Vector2(19, -4)
		if k == 0:
			_shop_badge = badge
		else:
			_gift_badge = badge
	# second row, centered under PLAY: styles, the DUELS button (duels, daily challenge, events), missions
	var row := [["skins", "white", func(): skins_pressed.emit(), 26], ["duel", "yellow", show_duel, 62],
		["mission", "white", show_mission, 26]]
	var total := 0.0
	for r in row:
		total += float(r[3]) + 3.0
	var x0 := -(total - 3.0) * 0.5
	for i in row.size():
		var w: float = row[i][3]
		var b := _button(menu, row[i][1], L.t("MENU_DUELS") if row[i][0] == "duel" else "", row[i][0], Vector2(w, 22))
		_place(b, 1.0, -31, w, 22)
		var dx := roundf(x0 + w * 0.5)
		x0 += w + 3.0
		b.offset_left += dx; b.offset_right += dx
		b.pressed.connect(row[i][2])
		if row[i][0] == "mission":
			_mission_badge = _label(b, "!", 1, GOLD)
			_mission_badge.position = Vector2(21, -4)
		elif row[i][0] == "duel":
			_duel_badge = _label(b, "!", 1, GOLD)
			_duel_badge.position = Vector2(w - 5, -4)


func refresh_menu() -> void:
	_menu_best.text = L.t("BEST_N", Save.best) if Save.best > 0 else L.t("TAGLINE")
	_center_label(_menu_best, 150, 0)
	var pg = Progress.games
	_menu_name.visible = pg.player_name != ""
	_menu_name.text = player_label(pg.player_name, pg.ranks.get("GLOBAL", -1))
	_center_label(_menu_name, 150, 30)
	_menu_level.text = L.t("LEVEL_N", Save.level)
	_center_label(_menu_level, 150, 12)
	_menu_xp.size.x = 60.0 if Save.level >= Upgrades.MAX_LEVEL else roundf(60.0 * Save.xp / Upgrades.xp_next(Save.level))
	_ab_badge.visible = upgrade_affordable()
	_menu_coins.text = str(Save.coins)
	_menu_coins.size = Vector2(_text_w(_menu_coins.text), 10)
	_gift_badge.visible = Save.daily_available()
	_mission_badge.visible = Progress.missions_left() > 0
	_shop_badge.visible = Monetization.live_offer_id() != ""
	# today's challenge or this week's event not played yet
	_duel_badge.visible = int(Save.daily_state()["tries"]) == 0 or int(Save.event_state()["tries"]) == 0


## True if some unlocked ability can be upgraded with the coins the player has.
func upgrade_affordable() -> bool:
	for a in Upgrades.ABILITIES:
		var c := Upgrades.price(a["id"], Save.ability(a["id"]))
		if Save.ability_unlocked(a["id"]) and c >= 0 and Save.coins >= c:
			return true
	return false


func show_menu() -> void:
	var st := safe_top()
	_menu_coin_box.position.y = 4 + st
	_menu_top_right.offset_top = 3 + st
	# the logo and the best/level/name lines move down with the notch, so the coins at the top
	# left never run into the logo
	_menu_logo.offset_top = 26 + st   # below the coins (left) and the shop / gift buttons (right)
	_menu_logo.offset_bottom = _menu_logo.offset_top + _menu_logo.texture.get_height()
	_menu_best_box.offset_top = _menu_logo.texture.get_height() + 28 + st
	_menu_best_box.offset_bottom = _menu_best_box.offset_top + 10
	refresh_menu()
	_switch(menu)


## Height (viewport px) hidden at the top by a camera notch / status bar, 0 on PC.
var safe_top_test := -1.0   # tests: pretend a notch of this height (viewport px)


func safe_top() -> float:
	if safe_top_test >= 0.0:
		return safe_top_test
	if not OS.has_feature("mobile"):
		return 0.0
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	return roundf(DisplayServer.get_display_safe_area().position.y * root.size.y / float(win.y))


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = _screen()
	var top := _container(hud)
	_hud_top = top
	_place(top, 0.0, 0, 180, 60)
	_score_lbl = _label(top, "0", 3)
	_hud_best = _label(top, "", 1, Color(1, 1, 1, 0.85))
	var bottom := _container(hud)
	_place(bottom, 1.0, -52, 180, 20)
	_hint = _label(bottom, L.t("TAP_HINT"), 2, Color.WHITE)
	_center_label(_hint, 180, 0)
	# tutorial tips: a dark band across the middle with a big line and a small one
	_tip = _container(hud)
	_place(_tip, 0.78, -16, 180, 34)   # below the orbits: the player and the meteor stay in sight
	var band := ColorRect.new()
	band.color = Color(0.06, 0.04, 0.16, 0.72)
	band.size = Vector2(180, 34)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(band)
	_tip_title = _label(_tip, "", 2, Color8(255, 236, 140))
	_tip_sub = _label(_tip, "", 1, Color.WHITE)
	_tip.visible = false
	_banner = _container(hud)
	_place(_banner, 0.3, -12, 180, 40)
	_banner.visible = false
	_teleport_btn = _button(hud, "pink", "", "teleport", Vector2(28, 28))
	_teleport_btn.anchor_left = 1.0; _teleport_btn.anchor_right = 1.0
	_teleport_btn.anchor_top = 1.0; _teleport_btn.anchor_bottom = 1.0
	_teleport_btn.offset_left = -34; _teleport_btn.offset_right = -6
	_teleport_btn.offset_top = -40; _teleport_btn.offset_bottom = -12
	_teleport_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE   # SWIPE to teleport (see main)
	_teleport_btn.modulate.a = 0.8
	_teleport_btn.visible = false
	_teleport_count = _label(_teleport_btn, "", 1, Color.WHITE)
	_teleport_count.position = Vector2(19, -4)
	_slowmo_btn = _button(hud, "white", "", "slowmo", Vector2(28, 28))
	_slowmo_btn.anchor_top = 1.0; _slowmo_btn.anchor_bottom = 1.0
	_slowmo_btn.offset_left = 6; _slowmo_btn.offset_right = 34
	_slowmo_btn.offset_top = -40; _slowmo_btn.offset_bottom = -12
	_slowmo_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE   # HOLD to slow time (see main)
	_slowmo_btn.modulate.a = 0.8
	_slowmo_btn.visible = false
	_slowmo_count = _label(_slowmo_btn, "", 1, INK)
	_slowmo_count.position = Vector2(19, -4)
	# progress towards the next world, with a tick at the player's record
	_wp_bg = ColorRect.new()
	_wp_bg.color = Color(0.1, 0.08, 0.25, 0.45)
	_wp_bg.position = Vector2(50, 45)
	_wp_bg.size = Vector2(80, 3)
	top.add_child(_wp_bg)
	_wp_fill = ColorRect.new()
	_wp_fill.color = GOLD
	_wp_fill.position = _wp_bg.position
	_wp_fill.size = Vector2(0, 3)
	top.add_child(_wp_fill)
	_wp_best = ColorRect.new()
	_wp_best.color = Color8(255, 128, 178)
	_wp_best.size = Vector2(1, 5)
	top.add_child(_wp_best)
	# combo of near misses in a row, under the world progress bar
	_combo_lbl = _label(top, "", 1, GOLD)
	_combo_lbl.visible = false
	# coins picked up in this run (top right)
	_run_coins_box = _container(hud)
	_run_coins_box.anchor_left = 1.0; _run_coins_box.anchor_right = 1.0
	_run_coins_box.offset_left = -40; _run_coins_box.offset_top = 7
	_icon(_run_coins_box, "icon_coin", Vector2.ZERO)
	_run_coins_lbl = _left_label(_run_coins_box, "0", Vector2(12, 1), GOLD)
	# altitude: the run is a climb (score -> km, miles in English)
	_alt_lbl = _left_label(hud, "", Vector2(4, 25), Color(1, 1, 1, 0.8))
	_pause_btn = _button(hud, "white", "", "pause", Vector2(20, 20))
	_pause_btn.position = Vector2(4, 4)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	_pause_title = _label(hud, "", 4)


## Share card (1080x1920): the moment of the run under a dark veil, the logo, the score, the world
## reached, the best combo and a dare. Drawn in a 180x320 SubViewport with the game's own font and
## scaled x6 without smoothing, like the store pictures. data: score, best, world, world_name, combo.
func share_card(frame: Image, data: Dictionary) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(180, 320)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(vp)
	var c := Control.new()
	c.theme = root.theme
	c.size = Vector2(180, 320)
	vp.add_child(c)
	var bg := ColorRect.new()
	bg.color = Color8(46, 28, 92)
	bg.size = Vector2(180, 320)
	c.add_child(bg)
	if frame != null and not frame.is_empty():
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(frame)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.size = Vector2(180, 320)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.add_child(tr)
	var veil := ColorRect.new()
	veil.color = Color(0.06, 0.03, 0.16, 0.5)
	veil.size = Vector2(180, 320)
	c.add_child(veil)
	var logo := TextureRect.new()
	logo.texture = _tex("logo")
	logo.position = Vector2(roundf((180 - logo.texture.get_width()) * 0.5), 14)
	c.add_child(logo)
	var y := 14 + logo.texture.get_height() + 16
	var sc := _label(c, str(int(data.get("score", 0))), 5)
	_center_label(sc, 180, y)
	y += 48
	if bool(data.get("record", false)):
		var nb := _label(c, L.t("NEW_BEST"), 1, Color8(255, 128, 178))
		_center_label(nb, 180, y)
		y += 12
	var wl := _label(c, L.t("WORLD_N", int(data.get("world", 1))) + " - " + str(data.get("world_name", "")), 1, GOLD)
	_center_label(wl, 180, y)
	y += 12
	if int(data.get("combo", 0)) >= 3:
		var cl := _label(c, L.t("CARD_COMBO", int(data.get("combo", 0))), 1, Color8(150, 230, 255))
		_center_label(cl, 180, y)
	var dare := _label(c, L.t("CARD_DARE"), 2, Color.WHITE)
	_center_label(dare, 180, 262)
	var play := _label(c, L.t("CARD_PLAY"), 1, GOLD)
	_center_label(play, 180, 290)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	img.resize(1080, 1920, Image.INTERPOLATE_NEAREST)
	return img


## Combo counter in the HUD: shown from 2 near misses in a row, pops on every one, x2 / x3 / x5.
func set_combo(n: int, mult: int) -> void:
	if _combo_lbl == null:
		return
	if n < 2:
		_combo_lbl.visible = false
		_combo_shown = 0
		return
	_combo_lbl.text = L.t("COMBO_N", n) + ("  x%d" % mult if mult > 1 else "")
	_combo_lbl.modulate = [GOLD, GOLD, Color8(255, 236, 90), Color8(255, 170, 70), Color8(255, 170, 70), Color8(255, 110, 150)][mini(mult, 5)]
	_center_label(_combo_lbl, 180, 51)
	_combo_lbl.visible = true
	if n != _combo_shown:
		_combo_shown = n
		_combo_lbl.pivot_offset = Vector2(_text_w(_combo_lbl.text) * 0.5, 4)
		_combo_lbl.scale = Vector2(1.35, 1.35)
		create_tween().tween_property(_combo_lbl, "scale", Vector2.ONE, 0.15)


## Altitude shown under the pause button: 25 points = 1 km.
func set_altitude(score: int) -> void:
	_alt_lbl.text = Stages.altitude_text(Stages.altitude_km(score), L.lang == "en", L.t("ALT_UNIT"))


func set_run_coins(n: int) -> void:
	_run_coins_lbl.text = str(n)
	_run_coins_box.offset_left = -roundf(16.0 + _text_w(_run_coins_lbl.text))   # 4+ digits stay on screen
	if n > 0:
		var tw := create_tween()
		_run_coins_box.scale = Vector2(1.25, 1.25)
		tw.tween_property(_run_coins_box, "scale", Vector2.ONE, 0.12)


func show_hud(best: int, hint: bool) -> void:
	var st := safe_top()
	_hud_top.offset_top = st; _hud_top.offset_bottom = st + 60
	_pause_btn.position.y = 4 + st
	_alt_lbl.position.y = 25 + st   # right under the pause button, above the best / target line
	_run_coins_box.offset_top = 7 + st
	set_score(0)
	_hud_best.text = L.t("BEST_N", best) if best > 0 else ""
	_hud_best.modulate = Color(1, 1, 1, 0.85)
	_center_label(_hud_best, 180, 34)
	_hint.visible = hint
	_pause_title.visible = false
	_banner.visible = false
	_pause_btn.visible = true
	_switch(hud)


func show_hud_resume() -> void:
	_pause_title.visible = false
	_pause_btn.visible = true
	for s in [pause, over, menu, skins, shop, ranking, abilities]:
		s.visible = false
	hud.visible = true
	hud.modulate.a = 1.0


func show_hud_continue(score: int, best: int) -> void:
	show_hud(best, false)
	set_score(score)


func set_teleport(charges: int) -> void:
	_teleport_btn.visible = charges > 0
	_teleport_count.text = "x%d" % charges if charges > 1 else ""


func set_slowmo(charges: int) -> void:
	_slowmo_btn.visible = charges > 0
	_slowmo_count.text = "x%d" % charges if charges > 1 else ""


func set_world_progress(score: int, best: int) -> void:
	var b := Stages.bounds(score)
	var span := float(maxi(1, b.y - b.x))
	_wp_fill.size.x = roundf(80.0 * clampf((score - b.x) / span, 0.0, 1.0))
	_wp_best.visible = best > b.x and best < b.y
	_wp_best.position = Vector2(50 + roundf(80.0 * (best - b.x) / span), 44)


## True when a gameplay tap at `pos` actually hit an in-run button.
func blocks_tap(pos: Vector2) -> bool:
	if not hud.visible:
		return false
	if _pause_btn.visible and _pause_btn.get_global_rect().grow(3).has_point(pos):
		return true
	return false


## layer: altitude layer just entered ("" when the world stays in the same layer).
func world_banner(n: int, name: String, tip := "", layer := "") -> void:
	_clear(_banner)
	var a := _label(_banner, L.t("WORLD_N", n), 2, GOLD)
	_center_label(a, 180, 0)
	var b := _label(_banner, name, 1, Color.WHITE)
	_center_label(b, 180, 20)
	var y := 32
	if layer != "":
		var ly := _label(_banner, layer, 1, Color8(150, 220, 255))
		_center_label(ly, 180, y)
		y += 12
	if tip != "":
		var c := _label(_banner, tip, 1, Color8(255, 236, 140))
		_center_label(c, 180, y)
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.2 if tip == "" and layer == "" else 4.2)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _banner.visible = false)


## Tutorial tip: a big title and a small line; secs > 0 hides it by itself.
func show_tip(title: String, sub := "", secs := 0.0) -> void:
	_tip_title.scale = Vector2(2, 2)
	_tip_title.text = title
	_center_label(_tip_title, 180, 3)
	_tip_sub.text = sub
	_center_label(_tip_sub, 180, 23)
	_tip.visible = true
	_tip.modulate.a = 1.0
	_tip_until = _t + secs if secs > 0.0 else -1.0


func hide_tip() -> void:
	_tip.visible = false
	_tip_until = -1.0


func tip_showing() -> bool:
	return _tip.visible


func hide_hint() -> void:
	if _hint.visible:
		var tw := create_tween()
		tw.tween_property(_hint, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func(): _hint.visible = false)


func set_score(v: int) -> void:
	_score_lbl.text = str(v)
	_center_label(_score_lbl, 180, 8)
	if v > 0:
		_score_lbl.position.y = 5
		create_tween().tween_property(_score_lbl, "position:y", 8.0, 0.12)


## Duel HUD: the score to beat instead of my best.
func set_duel_target(name: String, target: int) -> void:
	_hud_best.text = L.t("DUEL_BEAT", [name, target])
	_hud_best.modulate = Color8(255, 170, 200)
	_center_label(_hud_best, 180, 34)


func set_event_target(event_name: String, best: int) -> void:
	_hud_best.text = L.t("EVENT_HUD", best) if best > 0 else event_name
	_hud_best.modulate = Color8(255, 170, 230)
	_center_label(_hud_best, 180, 34)


func set_daily_target(best: int) -> void:
	_hud_best.text = L.t("DAILY_HUD", best) if best > 0 else L.t("DAILY_HUD_0")
	_hud_best.modulate = Color8(150, 220, 255)
	_center_label(_hud_best, 180, 34)


func announce_duel_lead(kind := "duel") -> void:
	_hud_best.text = L.t({"daily": "DAILY_AHEAD", "event": "EVENT_AHEAD"}.get(kind, "DUEL_AHEAD"))
	_hud_best.modulate = GOLD
	_center_label(_hud_best, 180, 34)


func announce_record() -> void:
	_hud_best.text = L.t("NEW_BEST")
	_hud_best.modulate = PINK
	_center_label(_hud_best, 180, 34)


func flash(a := 0.85) -> void:
	flash_rect.color = Color(1, 1, 1, a)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.25)


# ------------------------------------------------------------------ game over

func _build_over() -> void:
	over = _screen()
	var box := _container(over)
	_place(box, 0.5, -124, 136, 258)
	_over_box = box
	var title := _label(box, L.t("GAME_OVER"), 2)
	_center_label(title, 136, 0)
	var panel := _panel(box, Vector2(0, 24), Vector2(136, 222))
	_over_panel = panel
	# where this run stands among my best ones, and the next world (show_over_progress)
	_over_place = _label(panel, "", 1, Color8(150, 110, 200))
	_over_next = _label(panel, "", 1, Color8(214, 140, 30))
	# a tip after a bad run, under the panel (show_over_tip)
	_over_tip1 = _label(box, "", 1, Color8(255, 236, 140))
	_over_tip2 = _label(box, "", 1, Color.WHITE)
	var cap := _label(panel, L.t("SCORE"), 1, MUTED)
	_center_label(cap, 136, 7)
	_over_score = _label(panel, "0", 4, INK)
	_over_best_cap = _label(panel, L.t("BEST"), 1, MUTED)
	_center_label(_over_best_cap, 136, 56)
	_over_best = _label(panel, "0", 2, INK)
	_over_record = _container(panel)
	_over_record.position = Vector2(0, 58)
	var rl := _label(_over_record, L.t("NEW_BEST"), 2, PINK)
	_center_label(rl, 136, 0)
	for xx in [6, 119]:
		_icon(_over_record, "icon_star", Vector2(xx, 3))
	_icon(panel, "icon_coin", Vector2(30, 89))
	_over_coins = _label(panel, "+0", 1, COIN_INK)
	_over_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_over_coins.position = Vector2(42, 90)
	_over_double = _button(panel, "pink", "X2", "video", Vector2(40, 18))
	_over_double.position = Vector2(80, 82)
	_over_double.pressed.connect(func(): double_pressed.emit())
	_over_unlock = _label(panel, "", 1, GREEN_INK)
	_over_rank = _label(panel, "", 1, Color8(70, 120, 220))
	_over_xp = _label(panel, "", 1, Color8(60, 150, 200))
	_over_xp_bg = ColorRect.new()
	_over_xp_bg.color = Color8(220, 226, 240)
	_over_xp_bg.position = Vector2(28, 110)
	_over_xp_bg.size = Vector2(80, 3)
	panel.add_child(_over_xp_bg)
	_over_xp_fill = ColorRect.new()
	_over_xp_fill.color = Color8(90, 190, 240)
	_over_xp_fill.position = _over_xp_bg.position
	_over_xp_fill.size = Vector2(0, 3)
	panel.add_child(_over_xp_fill)
	_over_continue = _button(panel, "pink", L.t("CONTINUE"), "video", Vector2(108, 24))
	_over_continue.pressed.connect(func(): continue_pressed.emit())
	_over_continue_free = _button(panel, "green", L.t("CONTINUE"), "retry", Vector2(108, 24))
	_over_continue_free.pressed.connect(func(): continue_pressed.emit())
	var retry := _button(panel, "yellow", L.t("RETRY"), "retry", Vector2(108, 28), 2)
	retry.pressed.connect(func(): retry_pressed.emit())
	var home := _button(panel, "white", L.t("MENU"), "home", Vector2(58, 22))
	home.pressed.connect(func(): menu_pressed.emit())
	var share := _button(panel, "green", "", "share", Vector2(46, 22))
	share.pressed.connect(func(): share_pressed.emit())
	_over_duel = _button(panel, "pink", "DUEL", "share", Vector2(108, 28))
	_over_duel.pressed.connect(_on_over_duel)
	_over_buttons = [retry, home, share, _over_continue, _over_continue_free, _over_double, _over_duel]


func show_game_over(score: int, best: int, record: bool, unlocked: Array, can_continue := false, free_continue := false) -> void:
	_over_continue.visible = can_continue and not free_continue
	_over_continue_free.visible = can_continue and free_continue
	var y := 160
	_over_continue.position = Vector2(14, y)
	_over_continue_free.position = Vector2(14, y)
	if can_continue:
		y += 28
	_over_buttons[0].position = Vector2(14, y)
	_over_buttons[0].visible = true
	_over_duel.visible = false
	_over_duel.position = Vector2(14, y)
	# share only when the native share sheet exists (otherwise the button seemed to do nothing)
	var can_share: bool = Progress.sharer.available()
	_over_buttons[2].visible = can_share
	_over_buttons[1].position = Vector2(14 if can_share else 39, y + 34)
	_over_buttons[2].position = Vector2(76, y + 34)
	_over_panel.size.y = y + 66
	_over_score.text = str(score)
	_over_score.scale = Vector2(4, 4)
	_center_label(_over_score, 136, 19)
	_over_best.text = str(best)
	_center_label(_over_best, 136, 66)
	_over_record.visible = record and score > 0
	_over_best_cap.visible = not _over_record.visible
	_over_best.visible = not _over_record.visible
	_over_unlock.text = "" if unlocked.is_empty() else L.t("NEW_SKIN", Save.SKINS[unlocked[-1]]["name"])
	_over_unlock.modulate = Color.WHITE
	if unlocked.is_empty():
		# always a goal in sight: the closest skin / trail earned by playing
		_over_unlock.text = next_goal()
		_over_unlock.modulate = Color(0.55, 0.5, 0.7)
	_center_label(_over_unlock, 136, 116)
	_over_ranks = {}
	_over_was_record = record and score > 0
	_over_rank.text = ""
	_over_place.text = ""
	_over_next.text = ""
	_over_tip1.text = ""
	_over_tip2.text = ""
	for b in _over_buttons:
		b.disabled = true
	get_tree().create_timer(0.3).timeout.connect(func():
		for b in _over_buttons:
			b.disabled = false)
	_switch(over)


## Game over: this run among my best ones (#2..#10, or how far from the record) and the points
## that were missing for the next world.
func show_over_progress(score: int, record: bool, worlds: bool) -> void:
	var place := -1
	for i in Save.top_scores.size():
		if int(Save.top_scores[i]["s"]) == score:
			place = i + 1
			break
	if record or score <= 0:
		_over_place.text = ""
	elif place >= 2:
		_over_place.text = L.t("OVER_PLACE", place)
	else:
		_over_place.text = L.t("OVER_FROM_BEST", maxi(0, Save.best - score))
	_center_label(_over_place, 136, 126)
	if worlds:
		var nw := Stages.next_world(score)
		_over_next.text = L.t("OVER_NEXT_WORLD", [int(nw[0]), int(nw[1])])
	else:
		_over_next.text = ""
	_center_label(_over_next, 136, 137)


## A tip about the obstacle kind that ended the run ("" = a general one), two lines under the panel.
func show_over_tip(kind: String) -> void:
	if _over_continue.visible or _over_continue_free.visible:
		return   # the continue offer takes that room on short screens
	var key := "TIP_" + (kind.to_upper() if kind != "" and L.has("TIP_" + kind.to_upper() + "_1") else "ANY")
	_over_tip1.text = L.t(key + "_1")
	_over_tip2.text = L.t(key + "_2")
	var y := 24.0 + _over_panel.size.y + 6.0
	_center_label(_over_tip1, 136, y)
	_center_label(_over_tip2, 136, y + 11)


func _on_over_duel() -> void:
	match _over_duel_mode:
		"rematch":
			duel_new_pressed.emit()
		"daily":
			daily_pressed.emit()
		"daily_video":
			daily_video_pressed.emit()
		"event":
			event_pressed.emit()
		_:
			duel_send_pressed.emit()


## Duel game over: the result replaces the next goal, one button to send it (or a rematch).
## dr: see main._finish_duel().
func show_duel_result(dr: Dictionary) -> void:
	_over_buttons[0].visible = false   # one try per duel: no RETRY
	_over_buttons[2].visible = false
	_over_duel.visible = true
	var col := GREEN_INK
	if dr["mode"] == "event":
		if dr["pay"] > 0:
			_over_unlock.text = L.t("EVENT_PAY", dr["pay"])
		elif dr["best"]:
			_over_unlock.text = L.t("EVENT_NEW_BEST")
		else:
			_over_unlock.text = L.t("EVENT_RESULT_BEST", dr["week"])
			col = Color(0.55, 0.5, 0.7)
		_over_duel_mode = "event"
		(_over_duel.get_node("Content/Icon") as TextureRect).texture = _tex("icon_retry")
		_set_button_text(_over_duel, L.t("EVENT_AGAIN"))
	elif dr["mode"] == "daily":
		if dr["best"]:
			_over_unlock.text = L.t("DAILY_NEW_BEST", dr["pay"]) if dr["pay"] > 0 else L.t("DAILY_NEW_BEST_0")
		else:
			_over_unlock.text = L.t("DAILY_TODAY", dr["today"])
			col = Color(0.55, 0.5, 0.7)
		var icon := "icon_retry"
		if dr["tries"] > 0:
			_over_duel_mode = "daily"
			_set_button_text(_over_duel, L.t("DAILY_AGAIN", dr["tries"]))
		elif dr["video"] > 0:
			_over_duel_mode = "daily_video"
			icon = "icon_video"
			_set_button_text(_over_duel, L.t("DAILY_PLUS_TRY"))
		else:
			_over_duel.visible = false
			_over_unlock.text = L.t("DAILY_TOMORROW", dr["today"])
		(_over_duel.get_node("Content/Icon") as TextureRect).texture = _tex(icon)
	elif dr["mode"] == "new":
		_over_unlock.text = L.t("DUEL_SEND_IT")
		_over_duel_mode = "send"
		(_over_duel.get_node("Content/Icon") as TextureRect).texture = _tex("icon_share")
		_set_button_text(_over_duel, L.t("DUEL_CHALLENGE"))
	else:
		match dr["result"]:
			"win":
				_over_unlock.text = L.t("DUEL_WIN", dr["pay"]) if dr["pay"] > 0 else L.t("DUEL_WIN_0")
			"tie":
				_over_unlock.text = L.t("DUEL_TIE", dr["pay"]) if dr["pay"] > 0 else L.t("DUEL_TIE_0")
			_:
				_over_unlock.text = L.t("DUEL_LOSE", [dr["name"], dr["theirs"]])
				col = Color8(214, 66, 128)
		_over_duel_mode = "rematch" if dr["result"] == "lose" else "send"
		(_over_duel.get_node("Content/Icon") as TextureRect).texture = _tex("icon_duel" if _over_duel_mode == "rematch" else "icon_share")
		_set_button_text(_over_duel, L.t("DUEL_REMATCH") if _over_duel_mode == "rematch" else L.t("DUEL_SEND_RESULT"))
		if dr["result"] == "lose" and dr["pay"] > 0:
			toast(L.t("PLUS_COINS", dr["pay"]), Color8(255, 222, 70))
	_over_unlock.modulate = col
	_center_label(_over_unlock, 136, 116)


func set_over_xp(gain: int) -> void:
	_over_xp.text = "+%d XP  %s" % [gain, L.t("LEVEL_N", Save.level)]
	_center_label(_over_xp, 136, 101)
	var full := Save.level >= Upgrades.MAX_LEVEL
	_over_xp_fill.size.x = 80.0 if full else roundf(80.0 * Save.xp / Upgrades.xp_next(Save.level))


func set_over_coins(n: int, can_double: bool) -> void:
	_over_coins.text = "+%d" % n
	_over_double.visible = can_double


## Player name as shown in the pixel font (upper case, short).
static func safe_name(n: String) -> String:
	var u := n.strip_edges().to_upper()
	return u.substr(0, 12) + ("." if u.length() > 12 else "")


static func player_label(n: String, rank: int) -> String:
	return safe_name(n) + ("  #%d" % rank if rank > 0 else "")


func _on_rank_loaded(board: String, rank: int, _score: int) -> void:
	if menu.visible:
		refresh_menu()
	if ranking.visible and _rank_board == board:
		refresh_ranking()
	if not over.visible or rank <= 0:
		return
	_over_ranks[board] = rank
	var parts: Array = []
	if _over_ranks.has("GLOBAL"):
		parts.append("%s #%d" % [L.t("GLOBAL"), _over_ranks["GLOBAL"]])
	for k in _over_ranks:
		if k != "GLOBAL":
			parts.append("%s #%d" % [PlayGamesConfig.REGION_NAMES[k], _over_ranks[k]])
	_over_rank.text = "  ".join(parts)
	if _text_w(_over_rank.text) > 132:
		_over_rank.text = parts[0]
	_center_label(_over_rank, 136, 148)
	if board == "GLOBAL" and _over_was_record:
		toast(L.t("RANK_ENTER", rank), Color8(255, 226, 90))


func _on_top_loaded(board: String, rows: Array) -> void:
	_board_rows[board] = rows
	if ranking.visible and _rank_board == board:
		refresh_ranking()


# ------------------------------------------------------------------ style (skins / trails)

func _build_style() -> void:
	skins = _screen()
	_dim(skins)
	var box := _container(skins)
	_style_box = box
	_place(box, 0.5, -152, 164, STYLE_H)
	_tabs(box, TABS, [L.t("SKINS"), L.t("TRAILS")], ["skins", "trail"], _style_tabs, func(id):
		_style_tab = id
		_style_page = 0
		_style_focus = Save.selected(id)
		_refresh_style())
	var panel := _panel(box, Vector2(0, 21), Vector2(164, 256))
	_style_glow = PremiumGlow.new()
	_style_glow.position = Vector2(6, -4)
	_style_glow.size = Vector2(68, 68)
	panel.add_child(_style_glow)
	_style_preview = TextureRect.new()
	_style_preview.texture = AtlasTexture.new()
	_style_preview.scale = Vector2(3, 3)
	_style_preview.position = Vector2(16, 6)
	_style_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_style_preview)
	_style_name = _label(panel, "", 1, INK)
	_style_need = _label(panel, "", 1, MUTED)
	_style_need.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_need.position = Vector2(84, 40)
	_style_rarity = _label(panel, "", 1, INK)
	_style_action = _button(panel, "yellow", "0000", "coin", Vector2(64, 20))
	_style_action.position = Vector2(84, 36)
	_style_action.pressed.connect(_on_style_action)
	var cb := _container(panel)
	cb.position = Vector2(84, 10)
	_icon(cb, "icon_coin", Vector2.ZERO)
	_style_coins = _label(cb, "0", 1, COIN_INK)
	_style_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_coins.position = Vector2(12, 1)
	for i in 9:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.size = Vector2(48, 52)
		card.position = Vector2(8 + (i % 3) * 50, 66 + (i / 3) * 56)
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		panel.add_child(card)
		var pic := TextureRect.new()
		pic.texture = AtlasTexture.new()
		pic.scale = Vector2(2, 2)
		pic.position = Vector2(8, 4)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		var lock := _icon(card, "icon_lock", Vector2(19, 15))
		var coin := _icon(card, "icon_coin", Vector2(6, 39))
		var cap := _label(card, "", 1, INK)
		var bar := ColorRect.new()
		bar.size = Vector2(36, 2)
		bar.position = Vector2(6, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bar)
		card.pressed.connect(_on_card.bind(i))
		_style_cards.append({"card": card, "pic": pic, "lock": lock, "coin": coin, "cap": cap, "bar": bar})
	for k in 2:
		var ar := _button(panel, "white", "", "left" if k == 0 else "right", Vector2(26, 16))
		ar.position = Vector2(8 if k == 0 else 130, 234)
		ar.pressed.connect(func():
			_style_page = (_style_page + (-1 if k == 0 else 1) + _pages()) % _pages()
			_refresh_style())
		_style_arrows.append(ar)
	_style_page_lbl = _label(panel, "", 1, MUTED)
	var back := _button(box, "white", L.t("BACK"), "back", Vector2(76, 22))
	back.position = Vector2(44, 282)
	back.pressed.connect(func(): menu_pressed.emit())


func _pages() -> int:
	return ceili(Catalog.items(_style_tab).size() / 9.0)


func _item_tex(cat: String, i: int, anim_frame := 1) -> Dictionary:
	var it: Dictionary = Catalog.items(cat)[i]
	if cat == "skins":
		return {"atlas": _tex("char_" + it["id"]), "region": Rect2(anim_frame * 16, 0, 16, 16)}
	return {"atlas": _tex("trail_" + it["id"]), "region": Rect2(0, 0, 16, 16)}


## "> NAME: WORLD 8" for the locked skin or trail (earned by playing) closest to unlocking.
func next_goal() -> String:
	var best_ratio := -1.0
	var text := ""
	for cat in ["skins", "trails"]:
		var list := Catalog.items(cat)
		for i in list.size():
			if Save.unlocked(cat, i):
				continue
			var need: Array = list[i]["need"]
			var cur := 0.0
			match need[0]:
				"best": cur = Save.best
				"world": cur = int(Save.stats.get("best_world", 1))
				"level": cur = Save.level
				"total": cur = Save.total
				_: continue
			var ratio := cur / maxf(1.0, float(need[1]))
			if ratio > best_ratio:
				best_ratio = ratio
				text = "> %s: %s" % [list[i]["name"], _need_text(cat, i)]
	return text


func _need_text(cat: String, i: int) -> String:
	var need: Array = Catalog.items(cat)[i]["need"]
	match need[0]:
		"shop":
			return L.t("SHOP")
		"coins":
			return str(need[1])
		"total":
			return "TOTAL %d" % need[1]
		"world":
			return L.t("WORLD_N", need[1])
		"level":
			return L.t("LEVEL_N", need[1])
	return L.t("BEST_N", need[1])


func _on_card(slot: int) -> void:
	var i := _style_page * 9 + slot
	if i >= Catalog.items(_style_tab).size():
		return
	_style_focus = i
	if Save.unlocked(_style_tab, i):
		Save.select(_style_tab, i)
		if _style_tab == "skins":
			skin_selected.emit(i)
		style_changed.emit()
		Sfx.play("select")
	else:
		Sfx.play("tick")
	_refresh_style()


func _on_style_action() -> void:
	var i := _style_focus
	var need: Array = Catalog.items(_style_tab)[i]["need"]
	if need[0] == "shop":
		shop_pressed.emit()
	elif need[0] == "coins":
		if Save.buy_item(_style_tab, i):
			Progress.ga.resource("Sink", "Coins", int(need[1]), "Style", str(Catalog.items(_style_tab)[i]["id"]))
			Save.select(_style_tab, i)
			style_changed.emit()
			show_reveal(_style_tab, i)
		else:
			Sfx.play("deny")
			toast(L.t("NOT_ENOUGH"), Color8(255, 150, 160))
	_refresh_style()


func _refresh_style() -> void:
	var list: Array = Catalog.items(_style_tab)
	var cur := Save.selected(_style_tab)
	for id in _style_tabs:
		_style_button(_style_tabs[id], "yellow" if id == _style_tab else "white")
	_style_coins.text = str(Save.coins)
	var f := mini(_style_focus, list.size() - 1)
	var tx := _item_tex(_style_tab, f)
	var at: AtlasTexture = _style_preview.texture
	at.atlas = tx["atlas"]
	at.region = tx["region"]
	var it: Dictionary = list[f]
	var un := Save.unlocked(_style_tab, f)
	var need: Array = it["need"]
	var buyable: bool = not un and need[0] in ["coins", "shop"]
	_style_name.text = it["name"]
	_style_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_name.size = Vector2(_text_w(_style_name.text), 10)
	_style_name.position = Vector2(84, 24)
	_style_need.visible = not un and not buyable
	_style_need.text = _need_text(_style_tab, f)
	_style_need.size = Vector2(_text_w(_style_need.text), 10)
	var rar: String = it.get("rarity", "")
	_style_glow.on = _style_tab == "skins" and Catalog.premium(it)
	_style_glow.color = Catalog.RARITY_COLORS.get(rar, Color.WHITE)
	_style_glow.queue_redraw()
	_style_rarity.visible = rar != ""
	if rar != "":
		_style_rarity.text = L.t("R_" + rar.to_upper())
		_style_rarity.modulate = Catalog.RARITY_COLORS[rar]
		_center_label(_style_rarity, 80, 55)
	_style_action.visible = buyable
	if buyable:
		var coin_item: bool = need[0] == "coins"
		(_style_action.get_node("Content/Icon") as TextureRect).visible = coin_item
		_style_button(_style_action, "yellow" if coin_item else "pink")
		_set_button_text(_style_action, str(need[1]) if coin_item else L.t("SHOP"))
		(_style_action.get_node("Content/Text") as Label).modulate = (SHORT if Save.coins < int(need[1]) else INK) if coin_item else Color.WHITE
	for s in 9:
		var d: Dictionary = _style_cards[s]
		var i := _style_page * 9 + s
		var card: Button = d["card"]
		card.visible = i < list.size()
		if not card.visible:
			continue
		var unl := Save.unlocked(_style_tab, i)
		var n: Array = list[i]["need"]
		var style := _box("card_sel" if i == cur else "card", 3)
		for st in ["normal", "hover", "pressed"]:
			card.add_theme_stylebox_override(st, style)
		var t2 := _item_tex(_style_tab, i)
		var a2: AtlasTexture = d["pic"].texture
		a2.atlas = t2["atlas"]
		a2.region = t2["region"]
		d["pic"].modulate = Color.WHITE if unl else Color(0.2, 0.16, 0.35, 0.55)
		if i == f and not unl:
			d["pic"].modulate = Color(1, 1, 1, 0.8)
		d["lock"].visible = not unl
		var need_icon: String = {"coins": "icon_coin", "best": "icon_star", "world": "icon_world", "total": "icon_trophy", "level": "icon_level"}.get(n[0], "")
		d["coin"].visible = not unl and need_icon != ""
		if d["coin"].visible:
			d["coin"].texture = _tex(need_icon)
		var r2: String = list[i].get("rarity", "")
		d["bar"].visible = r2 != ""
		if r2 != "":
			d["bar"].color = Catalog.RARITY_COLORS[r2]
		var cap: Label = d["cap"]
		cap.text = list[i]["name"] if unl else (str(n[1]) if need_icon != "" else _need_text(_style_tab, i))
		cap.modulate = INK if unl else (Color8(214, 66, 128) if n[0] == "shop" else ((SHORT if Save.coins < int(n[1]) else COIN_INK) if n[0] == "coins" else MUTED))
		_center_label(cap, 48, 40)
		if d["coin"].visible:
			var iw: float = d["coin"].texture.get_width()
			cap.position.x += roundf(iw * 0.5) + 1
			d["coin"].position.x = cap.position.x - iw - 2
			d["coin"].position.y = 39 - roundf((d["coin"].texture.get_height() - 9) * 0.5)
	var pages := _pages()
	for ar in _style_arrows:
		ar.visible = pages > 1
	_style_page_lbl.text = "%d/%d" % [_style_page + 1, pages] if pages > 1 else "%s %d" % [L.t("BEST"), Save.best]
	_center_label(_style_page_lbl, 164, 238)


func show_skins() -> void:
	_fit_above_banner(_style_box, STYLE_H)
	_style_focus = Save.selected(_style_tab)
	_style_page = _style_focus / 9
	_refresh_style()
	_switch(skins)


# ------------------------------------------------------------------ abilities

func _build_abilities() -> void:
	abilities = _screen()
	_dim(abilities)
	_ab_box = _container(abilities)
	_place(_ab_box, 0.5, -152, 164, ABILITIES_H)
	var t := _label(_ab_box, L.t("ABILITIES"), 2)
	_center_label(t, 164, 0)
	var panel := _panel(_ab_box, Vector2(0, 21), Vector2(164, 266))
	_ab_list = _container(panel)
	var back := _button(_ab_box, "white", L.t("BACK"), "back", Vector2(76, 22))
	back.position = Vector2(44, 291)
	back.pressed.connect(func(): menu_pressed.emit())


## Short description of what an ability does at a given level.
static func ability_desc(id: String, lv: int) -> String:
	lv = maxi(1, lv)
	match id:
		"coins":
			return L.t("AB_COINS_D", lv * 10)
		"shield":
			return L.t(["AB_SHIELD_D1", "AB_SHIELD_D2", "AB_SHIELD_D3"][mini(lv, 3) - 1])
		"magnet":
			return L.t("AB_MAGNET_D")
		"slowmo":
			return L.t("AB_SLOWMO_D", [lv, Upgrades.SLOWMO_TIMES[mini(lv, 3)]])
		"teleport":
			return L.t("AB_CHARGES_D", lv)
		"bubbles":
			return L.t("AB_BUBBLES_D", 2 + lv * Upgrades.BUBBLE_BONUS)
		"headstart":
			return L.t("AB_HEADSTART_D", Upgrades.HEADSTART_WORLD[mini(lv, 3)])
	return L.t("AB_SECONDLIFE_D")


const AB_BTN_W := 46


func refresh_abilities() -> void:
	_clear(_ab_list)
	var cb := _container(_ab_list)
	_icon(cb, "icon_coin", Vector2.ZERO)
	_left_label(cb, str(Save.coins), Vector2(12, 1), COIN_INK)
	cb.position = Vector2(8, 6)
	var lv := L.t("LEVEL_N", Save.level)
	_left_label(_ab_list, lv, Vector2(156 - _text_w(lv), 7), INK)
	var y := 20
	for a in Upgrades.ABILITIES:
		var id: String = a["id"]
		var cur := Save.ability(id)
		var open := Save.ability_unlocked(id)
		var name := L.t("AB_" + id.to_upper())
		var desc := ability_desc(id, cur)
		if id == "headstart" and cur > 0:
			desc = L.t("AB_START", Save.chosen_start_world())
		var cost := Upgrades.price(id, cur)
		var style := "yellow"
		var text := str(cost)
		var icon := "coin"
		var enabled := open and cost >= 0 and Save.coins >= cost
		if not open:
			style = "white"; text = L.t("LEVEL_N", a["unlock"]); icon = ""
		elif cost < 0:
			style = "green"; text = "MAX"; icon = ""
		var b := _shop_row(_ab_list, y, a["icon"], name, desc, style, text, icon, enabled or (open and cost >= 0), func():
			if Save.buy_ability(id):
				Progress.ga.resource("Sink", "Coins", cost, "Ability", "%s_L%d" % [id, Save.ability(id)])
				Sfx.play("unlock")
				toast(L.t("UPGRADED", L.t("AB_" + id.to_upper())), Color8(120, 255, 200))
			else:
				Sfx.play("deny")
				toast(L.t("NOT_ENOUGH"), Color8(255, 150, 160))
			refresh_abilities(), AB_BTN_W)
		if open and cost >= 0 and Save.coins < cost:
			(b.get_node("Content/Text") as Label).modulate = SHORT
		if open:  # level pips under the button
			var mx := int(a["max"])
			var px := 158 - AB_BTN_W + roundi((AB_BTN_W - (mx * 5 - 2)) * 0.5)
			for k in mx:
				var pip := ColorRect.new()
				pip.size = Vector2(3, 3)
				pip.position = Vector2(px + k * 5, y + 23)
				pip.color = Color8(255, 200, 60) if k < cur else Color8(90, 90, 120)
				pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_ab_list.add_child(pip)
		if not open:
			b.modulate = Color(1, 1, 1, 0.6)
			_icon(_ab_list, "icon_lock", Vector2(5, y + 3)).modulate = Color(1, 1, 1, 0.9)
		if id == "headstart" and cur > 0 and Save.headstart_max() > 1:
			var sw := _button(_ab_list, "white", "", "right", Vector2(14, 14))
			sw.position = Vector2(mini(21 + roundi(_text_w(desc)), 156 - AB_BTN_W - 14), y + 7)
			sw.pressed.connect(func():
				Save.start_world = Save.chosen_start_world() % Save.headstart_max() + 1
				Save.save_data()
				Sfx.play("select")
				refresh_abilities())
		y += AB_ROW
	# free level by watching videos (levels 1 -> 2 and 2 -> 3, one a day)
	var vid := Save.video_target()
	if vid != "" and Save.video_open_today():
		var n := int(Save.video_up.get("n", 0)) if Save.video_up.get("id", "") == vid else 0
		var vb := _button(_ab_list, "pink", "%s +1  %d/%d" % [L.t("AB_" + vid.to_upper()), n, Save.video_needed(vid)], "video", Vector2(140, 16))
		vb.position = Vector2(12, 246)
		vb.disabled = not Monetization.rewarded_ready()
		vb.pressed.connect(func(): ability_video_pressed.emit())
	else:
		var tip := _label(_ab_list, L.t("AB_TIP") if vid == "" else L.t("VIDEO_TOMORROW"), 1, MUTED)
		_center_label(tip, 164, 250)


func show_abilities() -> void:
	_fit_above_banner(_ab_box, ABILITIES_H)
	refresh_abilities()
	_switch(abilities)


# ------------------------------------------------------------------ shop

func _build_shop() -> void:
	shop = _screen()
	_dim(shop)
	_shop_box = _container(shop)
	_place(_shop_box, 0.5, -152, 164, 280)
	_tabs(_shop_box, ["packs", "coins"], [L.t("PACKS"), L.t("COINS")], ["cart", "coin"], _shop_tabs, func(id):
		_shop_tab = id
		refresh_shop())
	var panel := _panel(_shop_box, Vector2(0, 21), Vector2(164, 232))
	_shop_list = _container(panel)
	var back := _button(_shop_box, "white", L.t("BACK"), "back", Vector2(76, 22))
	back.position = Vector2(44, 257)
	back.pressed.connect(func(): menu_pressed.emit())


func _shop_row(parent: Control, y: int, icon: String, name: String, desc: String, btn_style: String, btn_text: String, btn_icon: String, enabled: bool, cb: Callable, btn_w := 54) -> Button:
	_icon(parent, "icon_" + icon, Vector2(5, y + 3))
	_left_label(parent, name, Vector2(19, y))
	_left_label(parent, desc, Vector2(19, y + 10), MUTED)
	var b := _button(parent, btn_style, btn_text, btn_icon, Vector2(btn_w, 20))
	b.position = Vector2(158 - btn_w, y)
	b.disabled = not enabled
	b.pressed.connect(cb)
	return b


func refresh_shop() -> void:
	_clear(_shop_list)
	for id in _shop_tabs:
		_style_button(_shop_tabs[id], "yellow" if id == _shop_tab else "white")
	var online := Monetization.store_available()
	var y := 6
	if _shop_tab == "packs":
		var ids: Array = MonetizationConfig.PRODUCTS.filter(func(p): return not MonetizationConfig.CONSUMABLES.has(p))
		if not Monetization.starter_listed():
			ids.erase("starter")
		# the welcome offer (-50 %) takes the starter pack's place while it lasts
		var welcome_left := Monetization.welcome_secs()
		ids.erase("starter" if welcome_left > 0 else "starter_50")
		for id in ids:
			var info: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
			var owned := Save.owns(id)
			var live := not owned and Monetization.offer_secs(id) > 0
			var desc: String = "" if live else L.t(info["desc"])
			if id == "starter_50":
				desc = L.t("WELCOME_LEFT", ceili(welcome_left / 3600.0))
			_shop_row(_shop_list, y, info["icon"], L.t(info["name"]), desc,
				"green" if owned else ("pink" if id in ["starter", "starter_50"] or live else "yellow"),
				L.t("OWNED") if owned else Monetization.price(id), "", online and not owned, func(): buy_pressed.emit(id))
			if live:
				_offer_row_clock(id, y)
			if id == MonetizationConfig.BEST_VALUE and not owned:
				var bv := _label(_shop_list, L.t("BEST_VALUE"), 1, COIN_INK)
				bv.position = Vector2(roundf(minf(131 - _text_w(bv.text) * 0.5, 160 - _text_w(bv.text))), y + 22)
				y += 8   # room for the tag, so it reads as this row's
			y += 30
		var rs := _button(_shop_list, "white", L.t("RESTORE"), "", Vector2(80, 18))
		rs.position = Vector2(42, 208)
		rs.pressed.connect(func(): restore_pressed.emit())
	else:
		var cb := _container(_shop_list)
		_icon(cb, "icon_coin", Vector2(0, 0), 2)
		var cl := _label(cb, str(Save.coins), 2, COIN_INK)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cl.position = Vector2(22, 2)
		cb.position = Vector2(roundf((164 - 22 - _text_w(cl.text) * 2) * 0.5), 4)
		y = 30
		var left := Save.free_ads_left()
		_shop_row(_shop_list, y, "video", L.t("FREE_COINS"), L.t("LEFT_TODAY", left), "pink", "+%d" % MonetizationConfig.FREE_COIN_AD_REWARD, "video",
			left > 0 and Monetization.rewarded_ready(), func(): free_coins_pressed.emit())
		y += 28
		for id in MonetizationConfig.CONSUMABLES:
			var info2: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
			var live2 := Monetization.offer_secs(id) > 0
			_shop_row(_shop_list, y, info2["icon"], L.t(info2["name"]), "" if live2 else L.t(info2["desc"]), "pink" if live2 else "yellow",
				Monetization.price(id), "", online, func(): buy_pressed.emit(id))
			if live2:
				_offer_row_clock(id, y)
			y += 28
		var tip := _label(_shop_list, L.t("COINS_TIP"), 1, MUTED)
		_center_label(tip, 164, y + 4)
	var mode := Monetization.store_mode
	var st := _label(_shop_list, L.t("STORE_OFFLINE") if not online else (L.t("STORE_TEST") if mode == "test" else L.t("STORE_PLAY")), 1, MUTED)
	_center_label(st, 164, 194)


func show_shop(tab := "packs") -> void:
	_shop_tab = tab
	# keep the shop clear of the banner ad at the bottom of the screen
	_fit_above_banner(_shop_box)
	refresh_shop()
	_switch(shop)


# ------------------------------------------------------------------ ranking / achievements

func _build_ranking() -> void:
	ranking = _screen()
	_dim(ranking)
	var box := _container(ranking)
	_rank_box = box
	_place(box, 0.5, -140, 164, 280)
	_rank_tab_box = _container(box)
	var panel := _panel(box, Vector2(0, 21), Vector2(164, 232))
	_rank_list = _container(panel)
	var back := _button(box, "white", L.t("BACK"), "back", Vector2(76, 22))
	back.position = Vector2(44, 257)
	back.pressed.connect(func(): menu_pressed.emit())


const RANK_TABS := [["ranking", "RANKING", "trophy"], ["achievements", "ACHIEVEMENTS", "star"], ["obstacles", "OBSTACLES", "meteor"]]


## Three tabs: the open one is wide with its name, the others only show their icon.
func _layout_rank_tabs() -> void:
	_clear(_rank_tab_box)
	_rank_tabs.clear()
	var narrow := 30
	var wide := 164 - 2 * narrow - 8
	var x := 0
	for tb in RANK_TABS:
		var id: String = tb[0]
		var sel := id == _rank_tab
		var w := wide if sel else narrow
		var b := _button(_rank_tab_box, "yellow" if sel else "white", L.t(tb[1]) if sel else "", tb[2], Vector2(w, 18))
		b.position = Vector2(x, 0)
		x += w + 4
		b.pressed.connect(func():
			_rank_tab = id
			_rank_page = 0
			refresh_ranking())
		_rank_tabs[id] = b


func refresh_ranking() -> void:
	_clear(_rank_list)
	_layout_rank_tabs()
	var pg = Progress.games
	if _rank_tab == "obstacles":
		_obstacle_list()
		return
	if _rank_tab == "ranking":
		var qb := _button(_rank_list, "white", "?", "", Vector2(14, 13))
		qb.position = Vector2(146, 2)
		qb.pressed.connect(show_rank_help)
		var region := Progress.region()
		if _rank_board == "":
			_my_runs()
		else:
			_board_view(pg)
		var boards := [["GLOBAL", "globe"], [region, ""], ["FRIENDS", ""], ["TODAY", ""]]
		for k in boards.size():
			var bd: String = boards[k][0]
			var bt := _button(_rank_list, "yellow" if _rank_board == bd else "white", board_name(bd), boards[k][1], Vector2(72, 18))
			bt.position = Vector2(8 + (k % 2) * 76, 144 + (k / 2) * 20)
			bt.pressed.connect(_select_board.bind(bd))
		if _rank_board == "":
			var rl := _label(_rank_list, L.t("REGION") + ": " + PlayGamesConfig.REGION_NAMES[region], 1, MUTED)
			_center_label(rl, 164, 190)
		else:
			var all := _button(_rank_list, "green", L.t("SEE_ALL"), "trophy", Vector2(100, 16))
			all.position = Vector2(32, 186)
			all.pressed.connect(func(): _open_board(_rank_board))
		_play_games_footer(pg, 194)
	else:
		var per := 8
		var list: Array = Progress.ACHIEVEMENTS
		var pages := ceili(list.size() / float(per))
		var count := 0
		for a in list:
			if Save.achievements.has(a["id"]):
				count += 1
		var hdr := _label(_rank_list, "%d / %d" % [count, list.size()], 1, MUTED)
		_center_label(hdr, 164, 6)
		for i in per:
			var idx := _rank_page * per + i
			if idx >= list.size():
				break
			var a: Dictionary = list[idx]
			var got: bool = Save.achievements.has(a["id"])
			var y := 20 + i * 20
			_icon(_rank_list, "icon_trophy" if got else "icon_lock", Vector2(8, y))
			_left_label(_rank_list, Progress.achievement_name(a), Vector2(24, y + 1), INK if got else MUTED)
			if not got:
				var prog := "%d/%d" % [mini(Progress.stat(a["stat"]), int(a["goal"])), int(a["goal"])]
				_left_label(_rank_list, prog, Vector2(156 - _text_w(prog), y + 1), Color8(190, 180, 210))
		for k in 2:
			var ar := _button(_rank_list, "white", "", "left" if k == 0 else "right", Vector2(26, 16))
			ar.position = Vector2(8 if k == 0 else 130, 184)
			ar.pressed.connect(func():
				_rank_page = (_rank_page + (-1 if k == 0 else 1) + pages) % pages
				refresh_ranking())
		var pl := _label(_rank_list, "%d/%d" % [_rank_page + 1, pages], 1, MUTED)
		_center_label(pl, 164, 188)
		var open := _button(_rank_list, "white", L.t("OPEN_PLAY"), "", Vector2(130, 18))
		open.position = Vector2(17, 206)
		open.disabled = not pg.signed_in
		open.pressed.connect(func(): pg.show_achievements())


## Collection of obstacle kinds: the ones met with their tip, the others locked until their world.
func _obstacle_list() -> void:
	var kinds: Array = Director.KINDS
	var per := 7
	var pages := ceili(kinds.size() / float(per))
	_rank_page = clampi(_rank_page, 0, pages - 1)
	var seen := 0
	for kd in kinds:
		if Save.seen_obstacles.has(kd[0]):
			seen += 1
	var hdr := _label(_rank_list, L.t("OB_SEEN", [seen, kinds.size()]), 1, MUTED)
	_center_label(hdr, 164, 6)
	for i in per:
		var idx := _rank_page * per + i
		if idx >= kinds.size():
			break
		var kd: Array = kinds[idx]
		var got: bool = Save.seen_obstacles.has(kd[0])
		var y := 19 + i * 23
		var ic := ObstacleIcon.new(kd[0], not got)
		ic.position = Vector2(8, y)
		_rank_list.add_child(ic)
		if got:   # tap a met obstacle: what it does and how to dodge it
			var hit := Button.new()
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.position = Vector2(4, y - 2)
			hit.size = Vector2(156, 22)
			var kind: String = kd[0]
			hit.pressed.connect(func():
				Sfx.play("select")
				show_obstacle_info(kind))
			_rank_list.add_child(hit)
		var key := "OB_" + str(kd[0]).to_upper()
		_left_label(_rank_list, L.t(key) if got else "???", Vector2(32, y + 1), INK if got else MUTED)
		_left_label(_rank_list, L.t(key + "_D") if got else L.t("OB_LOCKED", int(kd[2])), Vector2(32, y + 10), MUTED)
	for k in 2:
		var ar := _button(_rank_list, "white", "", "left" if k == 0 else "right", Vector2(26, 16))
		ar.position = Vector2(8 if k == 0 else 130, 184)
		ar.pressed.connect(func():
			_rank_page = (_rank_page + (-1 if k == 0 else 1) + pages) % pages
			refresh_ranking())
	var pl := _label(_rank_list, "%d/%d" % [_rank_page + 1, pages], 1, MUTED)
	_center_label(pl, 164, 188)
	if seen > 1:
		var hint := _label(_rank_list, L.t("OB_TAP"), 1, Color8(190, 180, 210))
		_center_label(hint, 164, 206)


## An obstacle of the collection: big picture, name, what it does, how to dodge it, first world.
func show_obstacle_info(kind: String) -> void:
	var key := "OB_" + kind.to_upper()
	var p := _open_popup(L.t(key), "obstacle", 168)
	var ic := ObstacleIcon.new(kind, false)
	ic.scale = Vector2(2, 2)
	ic.position = Vector2(58, 2)
	p.add_child(ic)
	var y := 46
	for j in 2:
		var l := _label(p, L.t("%s_INFO_%d" % [key, j + 1]), 1, INK)
		_center_label(l, 156, y + j * 10)
	y += 26
	var how := _label(p, L.t("OB_HOW"), 1, COIN_INK)
	_center_label(how, 156, y)
	y += 11
	for j in 2:
		var tip: String = L.t("TIP_%s_%d" % [kind.to_upper(), j + 1])
		if j == 0 and tip.find(": ") >= 0:
			tip = tip.substr(tip.find(": ") + 2)   # without the "TIP:" word of the game over tips
		var tl := _label(p, tip, 1, MUTED)
		_center_label(tl, 156, y + j * 10)
	y += 26
	for kd in Director.KINDS:
		if kd[0] == kind:
			var fw := _label(p, L.t("OB_FIRST", int(kd[2])), 1, Color8(150, 110, 200))
			_center_label(fw, 156, y)
	_close_button(p, y + 16)


func _my_runs() -> void:
	var t := _label(_rank_list, L.t("MY_BEST"), 1, MUTED)
	_center_label(t, 164, 6)
	var tops: Array = Save.top_scores
	for i in 10:
		var y := 20 + i * 12
		var col := INK if i < tops.size() else Color8(190, 180, 210)
		_left_label(_rank_list, "%d." % (i + 1), Vector2(14, y), col)
		if i < tops.size():
			var e: Dictionary = tops[i]
			_left_label(_rank_list, str(e["s"]), Vector2(40, y), Color8(214, 66, 128) if i == 0 else INK)
			_left_label(_rank_list, L.t("WORLD_N", int(e.get("w", 1))), Vector2(84, y), MUTED)
		else:
			_left_label(_rank_list, "-", Vector2(40, y), col)


## Top of a Play Games leaderboard with names, plus the player's own position.
func _board_view(pg) -> void:
	var me: int = pg.ranks.get(_rank_board, -1)
	var head := board_name(_rank_board)
	if me > 0:
		head += "  " + L.t("YOU_RANK", me)
	var t := _label(_rank_list, head, 1, MUTED)
	_center_label(t, 164, 6)
	if not pg.signed_in:
		var off := _label(_rank_list, L.t("PLAY_GAMES_OFF"), 1, Color8(190, 120, 150))
		_center_label(off, 164, 60)
		return
	if not _board_rows.has(_rank_board):
		var ld := _label(_rank_list, L.t("LOADING"), 1, MUTED)
		_center_label(ld, 164, 60)
		return
	var rows: Array = _board_rows[_rank_board]
	if rows.is_empty():
		var em := _label(_rank_list, L.t("NO_SCORES"), 1, MUTED)
		_center_label(em, 164, 60)
		if _rank_board == "FRIENDS":
			for j in 2:
				var fl := _label(_rank_list, L.t("FRIENDS_EMPTY_%d" % (j + 1)), 1, Color8(190, 120, 150))
				_center_label(fl, 164, 80 + j * 10)
		elif Save.best > 0:   # played but not listed: usually a hidden Play Games profile
			for j in 2:
				var hl := _label(_rank_list, L.t("RANK_HIDDEN_%d" % (j + 1)), 1, Color8(190, 120, 150))
				_center_label(hl, 164, 80 + j * 10)
			var hb := _button(_rank_list, "pink", L.t("RANK_HOW"), "", Vector2(100, 18))
			hb.position = Vector2(32, 104)
			hb.pressed.connect(show_rank_help)
	for i in mini(rows.size(), 10):
		var r: Dictionary = rows[i]
		var y := 20 + i * 12
		var col := Color8(214, 66, 128) if r["me"] else INK
		_left_label(_rank_list, "%d." % int(r["rank"]), Vector2(8, y), MUTED if not r["me"] else col)
		_left_label(_rank_list, safe_name(r["name"]), Vector2(32, y), col)
		var sc := str(r["score"])
		_left_label(_rank_list, sc, Vector2(156 - _text_w(sc), y), col)


func board_name(board: String) -> String:
	match board:
		"GLOBAL": return L.t("GLOBAL")
		"FRIENDS": return L.t("FRIENDS")
		"TODAY": return L.t("DAILY_RANK")
		"WEEK": return L.t("EVENT_RANK")
	return PlayGamesConfig.REGION_NAMES.get(board, board)


func _select_board(board: String) -> void:
	if _rank_board == board:
		_rank_board = ""
	else:
		_rank_board = board
		if Progress.games.load_top(board):
			Progress.games.load_rank(board)
	refresh_ranking()


func _play_games_footer(pg, y: int) -> void:
	if pg.signed_in:
		return
	if pg.available:
		var si := _button(_rank_list, "green", L.t("SIGN_IN"), "", Vector2(100, 20))
		si.position = Vector2(32, y + 16)
		si.pressed.connect(func(): pg.sign_in())
	else:
		var off := _label(_rank_list, L.t("PLAY_GAMES_OFF"), 1, Color8(190, 120, 150))
		_center_label(off, 164, y + 20)


## How to show up in the Play Games rankings (a private profile hides your scores).
func show_rank_help() -> void:
	Progress.ga.design("UI:Open:RankHelp")
	var p := _open_popup(L.t("RANK_HELP_T"), "rank_help", 150)
	for i in 4:
		var l := _label(p, L.t("RANK_HELP_%d" % (i + 1)), 1, INK if i < 3 else GREEN_INK)
		_center_label(l, 156, 6 + i * 13)
	var why := _label(p, L.t("RANK_HELP_WHY"), 1, MUTED)
	_center_label(why, 156, 60)
	var pg = Progress.games
	var ob := _button(p, "green", L.t("RANK_OPEN_PG") if pg.signed_in else L.t("SIGN_IN"), "trophy", Vector2(120, 22))
	ob.position = Vector2(18, 78)
	ob.pressed.connect(func():
		if pg.signed_in:
			_open_board("GLOBAL")
		elif pg.available:
			pg.sign_in()
		else:
			toast(L.t("PLAY_GAMES_OFF"), Color8(255, 150, 160)))
	_close_button(p, 108)


func _open_board(board: String) -> void:
	if not Progress.games.show_board(board):
		toast(L.t("PLAY_GAMES_OFF"), Color8(255, 150, 160))


## Banner ads sit at the bottom of every menu screen (not the main menu, runs or game over).
const STYLE_H := 304
const ABILITIES_H := 314
const AB_ROW := 28   # 8 abilities: button 20 + level pips, fits a 320 px tall screen
const POPUP_BANNER_KINDS := ["mission", "settings", "daily", "duel", "event"]


## True if a box `h` px tall fits above the banner on this screen (short 16:9 phones: not
## for the tallest screens, which then go without a banner rather than overlap it).
func banner_room(h: int) -> bool:
	return root.size.y - MonetizationConfig.BANNER_HEIGHT - h - 4 >= 0


func _fit_above_banner(box: Control, h := 280) -> void:
	var banner := MonetizationConfig.BANNER_HEIGHT if not Monetization.ads_removed() and banner_room(h) else 0
	var top := maxf(4.0, roundf((root.size.y - banner - h) * 0.5))
	box.anchor_top = 0.0; box.anchor_bottom = 0.0
	box.offset_top = top
	box.offset_bottom = top + h


func show_ranking() -> void:
	_fit_above_banner(_rank_box)
	_rank_board = ""
	refresh_ranking()
	_switch(ranking)


# ------------------------------------------------------------------ popups

func _build_popup() -> void:
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.visible = false
	root.add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.3, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	_popup_box = _container(popup)
	_place(_popup_box, 0.5, -90, 156, 180)


func _open_popup(title: String, kind := "", h := 136) -> NinePatchRect:
	_clear(_popup_box)
	popup.set_meta("kind", kind)
	_popup_box.offset_top = -roundf((h + 22) * 0.5)
	var t := _label(_popup_box, title, 2)
	_center_label(t, 156, 0)
	var p := _panel(_popup_box, Vector2(0, 22), Vector2(156, h))
	# over every screen (it can open from the ranking / style screens), under toasts and the flash
	popup.move_to_front()
	_toast.move_to_front()
	flash_rect.move_to_front()
	if not popup.visible:
		popup.visible = true
		popup.modulate.a = 0.0
		create_tween().tween_property(popup, "modulate:a", 1.0, 0.15)
	if kind in POPUP_BANNER_KINDS and menu.visible:
		Monetization.show_banner()
	_menu_best_box.visible = false
	_menu_coin_box.visible = false
	return p


func _close_button(p: Control, y: int) -> void:
	var c := _button(p, "white", L.t("BACK"), "back", Vector2(72, 20))
	c.position = Vector2(42, y)
	c.pressed.connect(hide_popup)


func hide_popup() -> void:
	popup.visible = false
	_menu_best_box.visible = _mission_card == null
	_menu_coin_box.visible = true
	if menu.visible:
		Monetization.hide_banner()
		refresh_menu()


func show_daily() -> void:
	if not Save.daily_available():
		_show_daily_taken()
		return
	var g := Save.daily_preview()
	var p := _open_popup(L.t("DAILY_GIFT"), "daily")
	var day: int = g["day"]
	_gift_calendar(p, day, false)
	var big := _container(p)
	_icon(big, "icon_coin", Vector2(0, 2), 2)
	var amount := _label(big, "+%d" % g["coins"], 3, COIN_INK)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.position = Vector2(24, 0)
	big.position = Vector2(roundf((156 - 24 - _text_w(amount.text) * 3) * 0.5), 42)
	var extra := _label(p, L.t("DAY_N", day), 1, MUTED)
	_center_label(extra, 156, 72)
	var claim := _button(p, "yellow", L.t("CLAIM"), "", Vector2(64, 24))
	claim.position = Vector2(10, 92)
	claim.pressed.connect(func(): daily_claim.emit(false))
	var dbl := _button(p, "pink", "X2", "video", Vector2(64, 24))
	dbl.position = Vector2(82, 92)
	dbl.disabled = not Monetization.rewarded_ready()
	dbl.pressed.connect(func(): daily_claim.emit(true))


## The 7 days of the streak: past days dimmed with a green bar, `day` highlighted.
func _gift_calendar(p: Control, day: int, taken: bool) -> void:
	for i in 7:
		var r: Dictionary = MonetizationConfig.DAILY_REWARDS[i]
		var cell := NinePatchRect.new()
		cell.texture = _tex("card_sel" if i + 1 == day else "card")
		cell.patch_margin_left = 3; cell.patch_margin_right = 3; cell.patch_margin_top = 3; cell.patch_margin_bottom = 3
		cell.position = Vector2(6 + i * 21, 8)
		cell.size = Vector2(20, 26)
		var done := i + 1 < day or (taken and i + 1 == day)
		cell.modulate = Color(1, 1, 1, 0.55) if done and i + 1 != day else Color.WHITE
		p.add_child(cell)
		var dl := _label(cell, "D%d" % (i + 1), 1, MUTED)
		_center_label(dl, 20, 3)
		var cl := _label(cell, str(r["coins"]), 1, COIN_INK)
		_center_label(cl, 20, 14)
		if done:
			var ok := ColorRect.new()
			ok.color = Color8(124, 226, 104)
			ok.position = Vector2(3, 22)
			ok.size = Vector2(14, 2)
			cell.add_child(ok)


## Today's gift already taken: what it was, what tomorrow brings, and the streak rule.
## Something new unlocked: the skin or trail big, its name and rarity, USE or LATER.
func show_reveal(cat: String, i: int) -> void:
	var it: Dictionary = Catalog.items(cat)[i]
	var p := _open_popup(L.t("NEW_SKIN_T" if cat == "skins" else "NEW_TRAIL_T"), "reveal", 150)
	var glow := ColorRect.new()
	var rar: String = it.get("rarity", "common")
	glow.color = Catalog.RARITY_COLORS.get(rar, Color.WHITE) * Color(1, 1, 1, 0.25)
	glow.position = Vector2(46, 8)
	glow.size = Vector2(64, 64)
	p.add_child(glow)
	var t := _item_tex(cat, i)
	var at := AtlasTexture.new()
	at.atlas = t["atlas"]
	at.region = t["region"]
	var pic := TextureRect.new()
	pic.texture = at
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.scale = Vector2(4, 4)
	pic.position = Vector2(46, 8)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pic)
	var tw := pic.create_tween().set_loops()
	tw.tween_property(pic, "position:y", 4.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(pic, "position:y", 10.0, 0.5).set_trans(Tween.TRANS_SINE)
	var nm := _label(p, str(it["name"]), 2, INK)
	_center_label(nm, 156, 78)
	var rl := _label(p, L.t("R_" + rar.to_upper()), 1, Catalog.RARITY_COLORS.get(rar, MUTED))
	_center_label(rl, 156, 98)
	var use := _button(p, "yellow", L.t("USE"), "", Vector2(64, 24))
	use.position = Vector2(10, 116)
	use.pressed.connect(func():
		Save.select(cat, i)
		Save.save_data()
		style_changed.emit()
		hide_popup())
	var later := _button(p, "white", L.t("LATER"), "", Vector2(64, 24))
	later.position = Vector2(82, 116)
	later.pressed.connect(hide_popup)
	Sfx.play("unlock")


## After a run, in the menu: the 3 missions and the weekly challenge, bars filling from where they
## were to where they are now; completed ones in green with their coins. Hides by itself.
func show_mission_progress(before: Array, after: Array) -> void:
	if _mission_card != null:
		_mission_card.queue_free()
	var card := _container(menu)
	_mission_card = card
	_menu_best_box.visible = false   # short screens: the card would run into the name / best lines
	var rows := after.size()
	var h := 12 + rows * 17
	_place(card, 1.0, -72 - h, 160, h)
	var bgp := _panel(card, Vector2.ZERO, Vector2(160, h))
	bgp.modulate = Color(1, 1, 1, 0.95)
	var tl := _label(card, L.t("MISSIONS"), 1, MUTED)
	_center_label(tl, 160, 2)
	for k in rows:
		var a: Dictionary = after[k]
		var b: Dictionary = before[k] if k < before.size() else a
		var y := 12 + k * 17
		var txt := _left_label(card, str(a["text"]), Vector2(6, y), GREEN_INK if a["done"] else INK)
		while txt.text.length() > 4 and _text_w(txt.text) > 148:
			txt.text = txt.text.substr(0, txt.text.length() - 2) + "."
		var pr := "+%d" % a["reward"] if a["done"] else "%d/%d" % [a["progress"], a["goal"]]
		var pl := _left_label(card, pr, Vector2(154 - _text_w(pr), y + 8), COIN_INK if a["done"] else MUTED)
		var bw := pl.position.x - 10
		var bar := ColorRect.new()
		bar.color = Color8(220, 226, 240)
		bar.position = Vector2(6, y + 10)
		bar.size = Vector2(bw, 4)
		card.add_child(bar)
		var fill := ColorRect.new()
		fill.color = Color8(124, 226, 104) if a["done"] else GOLD
		fill.position = bar.position
		var f0 := float(b["progress"]) / float(b["goal"])
		var f1 := float(a["progress"]) / float(a["goal"])
		fill.size = Vector2(roundf(bw * f0), 4)
		card.add_child(fill)
		card.create_tween().tween_property(fill, "size:x", roundf(bw * f1), 0.7).set_delay(0.3).set_trans(Tween.TRANS_QUAD)
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		card.queue_free()
		if _mission_card == card:
			_mission_card = null
			_menu_best_box.visible = not popup.visible)


func _show_daily_taken() -> void:
	var p := _open_popup(L.t("DAILY_GIFT"), "daily")
	var day := Save.daily_day
	_gift_calendar(p, day, true)
	var got := _label(p, L.t("GIFT_GOT"), 1, MUTED)
	_center_label(got, 156, 40)
	var big := _container(p)
	_icon(big, "icon_coin", Vector2(0, 2), 2)
	var amount := _label(big, "+%d" % int(Save.stats.get("gift_last", MonetizationConfig.DAILY_REWARDS[maxi(0, day - 1)]["coins"])), 3, COIN_INK)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.position = Vector2(24, 0)
	big.position = Vector2(roundf((156 - 24 - _text_w(amount.text) * 3) * 0.5), 52)
	var nxt: int = MonetizationConfig.DAILY_REWARDS[day % 7]["coins"]
	var tm := _label(p, L.t("GIFT_TOMORROW", nxt), 1, COIN_INK)
	_center_label(tm, 156, 84)
	var rule := _label(p, L.t("GIFT_RULE"), 1, MUTED)
	_center_label(rule, 156, 96)
	_close_button(p, 110)


func show_starter() -> void:
	Progress.ga.design("Offer:Shown:starter:Starter")
	var p := _open_popup(L.t("STARTER_PACK"), "starter")
	var lines := [L.t("STARTER_L1"), L.t("PLUS_COINS", MonetizationConfig.BUNDLE_BONUS["starter"]["coins"]), "", L.t("STARTER_L4")]
	for i in lines.size():
		var l := _label(p, lines[i], 1, INK if i < 3 else Color8(214, 66, 128))
		_center_label(l, 156, 10 + i * 14)
	var buy := _button(p, "pink", Monetization.price("starter"), "gift", Vector2(80, 24))
	buy.position = Vector2(38, 70)
	buy.pressed.connect(func():
		hide_popup()
		buy_pressed.emit("starter"))
	var later := _button(p, "white", L.t("LATER"), "", Vector2(60, 20))
	later.position = Vector2(48, 102)
	later.pressed.connect(hide_popup)


## Welcome offer: the starter pack at half price for 48 h (once, after the 3rd run).
func show_welcome() -> void:
	Progress.ga.design("Offer:Shown:starter_50:Welcome")
	var p := _open_popup(L.t("WELCOME_T"), "welcome", 150)
	var off := _label(p, "-50%", 3, Color8(214, 66, 128))
	_center_label(off, 156, 4)
	var nm := _label(p, L.t("STARTER_PACK"), 1, INK)
	_center_label(nm, 156, 32)
	var l1 := _label(p, L.t("STARTER_L1"), 1, MUTED)
	_center_label(l1, 156, 43)
	var l2 := _label(p, L.t("PLUS_COINS", MonetizationConfig.BUNDLE_BONUS["starter_50"]["coins"]), 1, COIN_INK)
	_center_label(l2, 156, 54)
	# the normal price, struck through, then the button with the offer price
	var old := _label(p, Monetization.price("starter"), 1, MUTED)
	_center_label(old, 156, 68)
	var strike := ColorRect.new()
	strike.color = Color8(214, 66, 128)
	strike.position = Vector2(old.position.x - 2, 72)
	strike.size = Vector2(_text_w(old.text) + 4, 1)
	strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(strike)
	var buy := _button(p, "pink", Monetization.price("starter_50"), "gift", Vector2(80, 24))
	buy.position = Vector2(38, 80)
	buy.pressed.connect(func():
		hide_popup()
		buy_pressed.emit("starter_50"))
	var hrs := _label(p, L.t("WELCOME_HOURS", MonetizationConfig.WELCOME_HOURS), 1, MUTED)
	_center_label(hrs, 156, 108)
	var later := _button(p, "white", L.t("LATER"), "", Vector2(60, 20))
	later.position = Vector2(48, 122)
	later.pressed.connect(hide_popup)


## Offer at the right moment (see Offers): why, what, price, later.
func show_offer(id: String, why: String) -> void:
	Progress.ga.design("Offer:Shown:%s:%s" % [id, why])
	var info: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
	var secs := Monetization.offer_secs(id)
	var bonus := int(Save.offer_live.get("bonus", 0)) if secs > 0 else 0
	var p := _open_popup(L.t("OFFER"), "offer")
	var w := _label(p, L.t(why), 1, Color8(214, 66, 128))
	_center_label(w, 156, 8)
	_icon(p, "icon_" + info["icon"], Vector2(70, 21), 2)
	var n := _label(p, L.t(info["name"]), 1, INK)
	_center_label(n, 156, 44)
	var d := _label(p, L.t(info["desc"]), 1, MUTED)
	_center_label(d, 156, 54)
	if bonus > 0:
		var bl := _label(p, L.t("OFFER_BONUS", bonus), 1, COIN_INK)
		_center_label(bl, 156, 66)
		_offer_clock = _label(p, "", 1, Color8(214, 66, 128))
		_offer_clock_id = id
		_offer_clock_short = false
		_offer_clock_parent_w = 156.0
		_offer_clock.set_meta("y", 76)
		_tick_offer_clock()
	var buy := _button(p, "pink", Monetization.price(id), "", Vector2(80, 24))
	buy.position = Vector2(38, 88 if bonus > 0 else 78)
	buy.pressed.connect(func():
		hide_popup()
		buy_pressed.emit(id))
	var later := _button(p, "white", L.t("LATER"), "", Vector2(60, 20))
	later.position = Vector2(48, 114 if bonus > 0 else 108)
	later.pressed.connect(hide_popup)


## Pink "+bonus (23H)" in place of the description of the shop row with the live offer.
func _offer_row_clock(id: String, y: int) -> void:
	_offer_clock = _left_label(_shop_list, "", Vector2(19, y + 10), Color8(214, 66, 128))
	_offer_clock_id = id
	_offer_clock_short = true
	_tick_offer_clock()


func _tick_offer_clock() -> void:
	var secs := Monetization.offer_secs(_offer_clock_id)
	if secs <= 0:
		_offer_clock.visible = false
		if shop.visible:
			refresh_shop.call_deferred()
		return
	var txt: String
	if _offer_clock_short:
		txt = L.t("OFFER_ROW", [int(Save.offer_live.get("bonus", 0)), Offers.clock(secs, true)])
	else:
		txt = L.t("OFFER_ENDS", Offers.clock(secs))
	if txt != _offer_clock.text:
		_offer_clock.text = txt
		if not _offer_clock_short:
			_center_label(_offer_clock, _offer_clock_parent_w, float(_offer_clock.get_meta("y", 76)))


## CHALLENGES (swords button): today's challenge for everyone, and duels with friends.
func show_duel() -> void:
	var p := _open_popup(L.t("CHALLENGES"), "duel", 228)
	# this week's event: one big button that opens its own window
	var ev := Save.event_info()
	var etag := _label(p, L.t("EVENT_WEEK"), 1, COIN_INK)
	_center_label(etag, 156, 5)
	var eb := _button(p, "pink", L.t("EV_" + str(ev["id"]).to_upper()), "star", Vector2(148, 22))
	eb.position = Vector2(4, 15)
	eb.pressed.connect(show_event)
	if int(Save.event_state()["tries"]) == 0:
		var eg := _label(eb, "!", 1, GOLD)
		eg.position = Vector2(143, -4)
	var y0 := 42
	var st := Save.daily_state()
	var dt := _label(p, L.t("DAILY_TITLE"), 1, COIN_INK)
	_center_label(dt, 156, 6 + y0)
	var di := _label(p, L.t("DAILY_INFO"), 1, MUTED)
	_center_label(di, 156, 16 + y0)
	var left := Save.daily_tries_left()
	var ds := _label(p, L.t("DAILY_STATE", [int(st["best"]), left]), 1, INK)
	_center_label(ds, 156, 26 + y0)
	var play: Button
	if left > 0:
		play = _button(p, "pink", L.t("PLAY"), "retry", Vector2(72, 22))
		play.pressed.connect(func(): daily_pressed.emit())
	elif Save.daily_video_left() > 0 and Monetization.rewarded_ready():
		play = _button(p, "pink", "+1", "video", Vector2(72, 22))
		play.pressed.connect(func(): daily_video_pressed.emit())
	else:
		play = _button(p, "white", L.t("DAILY_DONE"), "", Vector2(72, 22))
		play.disabled = true
	play.position = Vector2(4, 38 + y0)
	var rk := _button(p, "white", L.t("DAILY_RANK"), "trophy", Vector2(72, 22))
	rk.position = Vector2(80, 38 + y0)
	rk.pressed.connect(func(): _open_board("TODAY"))
	var sep := ColorRect.new()
	sep.color = Color8(220, 214, 236)
	sep.position = Vector2(8, 68 + y0)
	sep.size = Vector2(140, 1)
	p.add_child(sep)
	var tt := _label(p, L.t("DUEL_TITLE"), 1, COIN_INK)
	_center_label(tt, 156, 74 + y0)
	var r1 := _label(p, L.t("DUEL_I1"), 1, MUTED)
	_center_label(r1, 156, 84 + y0)
	var r2 := _label(p, L.t("DUEL_RULES"), 1, MUTED)
	_center_label(r2, 156, 94 + y0)
	var pay := _label(p, L.t("DUEL_PAY", [Duel.REWARD_WIN, Duel.REWARD_LOSS]), 1, COIN_INK)
	_center_label(pay, 156, 104 + y0)
	var nb := _button(p, "yellow", L.t("DUEL_NEW"), "duel", Vector2(72, 22))
	nb.position = Vector2(4, 116 + y0)
	nb.pressed.connect(func(): duel_new_pressed.emit())
	var pb := _button(p, "white", L.t("DUEL_PASTE_SHORT"), "", Vector2(72, 22))
	pb.position = Vector2(80, 116 + y0)
	pb.pressed.connect(_paste_duel)
	var sts := _label(p, L.t("DUEL_STATS", [int(Save.duels.get("wins", 0)), int(Save.duels.get("losses", 0))]), 1, MUTED)
	_center_label(sts, 156, 144 + y0)
	_close_button(p, 160 + y0)


## This week's event: what it is, time left, the week's best, the coin goals, PLAY and its board.
func show_event() -> void:
	var ev := Save.event_info()
	var st := Save.event_state()
	var key := "EV_" + str(ev["id"]).to_upper()
	var p := _open_popup(L.t("EVENT_WEEK"), "event", 184)
	var nm := _label(p, L.t(key), 1, Color8(214, 66, 128))
	_center_label(nm, 156, 5)
	var ds := _label(p, L.t(key + "_D"), 1, MUTED)
	_center_label(ds, 156, 15)
	var secs := Events.seconds_left(Save._now())
	var ends := _label(p, L.t("EVENT_ENDS", [secs / 86400, (secs % 86400) / 3600]), 1, MUTED)
	_center_label(ends, 156, 25)
	var best := _label(p, L.t("EVENT_HUD", int(st["best"])), 1, INK)
	_center_label(best, 156, 38)
	for i in Events.GOALS.size():
		var g: Array = Events.GOALS[i]
		var done := int(st["paid"]) > i
		var y := 52 + i * 16
		_icon(p, "icon_star" if done else "icon_lock", Vector2(10, y - 1))
		_left_label(p, L.t("EVENT_GOAL", int(g[0])), Vector2(24, y), GREEN_INK if done else INK)
		var rw := "+%d" % int(g[1])
		var rx := 146.0 - _text_w(rw)
		_left_label(p, rw, Vector2(roundf(rx), y), GREEN_INK if done else COIN_INK)
		_icon(p, "icon_coin", Vector2(roundf(rx) - 11, y))
	var how := _label(p, L.t("EVENT_HOW"), 1, Color8(214, 66, 128))
	_center_label(how, 156, 100)
	var rule := _label(p, L.t("EVENT_RULE"), 1, MUTED)
	_center_label(rule, 156, 110)
	var play := _button(p, "pink", L.t("PLAY"), "retry", Vector2(72, 22))
	play.position = Vector2(4, 124)
	play.pressed.connect(func(): event_pressed.emit())
	var rk := _button(p, "white", L.t("EVENT_RANK"), "trophy", Vector2(72, 22))
	rk.position = Vector2(80, 124)
	rk.pressed.connect(func(): _open_board("WEEK"))
	var back := _button(p, "white", L.t("BACK"), "back", Vector2(76, 20))
	back.position = Vector2(40, 152)
	back.pressed.connect(show_duel)


func _paste_duel() -> void:
	offer_duel_text(DisplayServer.clipboard_get())


## A duel from pasted text or a duel link: checks it and shows the challenge.
func offer_duel_text(text: String) -> void:
	var d := Duel.decode(text)
	if d.is_empty():
		toast(L.t("DUEL_NONE"), Color8(255, 150, 160))
	elif Save.duel_mine(d):
		toast(L.t("DUEL_OWN"), Color8(255, 150, 160))
	elif Save.duel_played(str(d["code"])):
		toast(L.t("DUEL_DONE"), Color8(255, 150, 160))
	else:
		show_duel_accept(d)


func show_duel_accept(d: Dictionary) -> void:
	var p := _open_popup(L.t("DUEL") + "!", "duel_accept", 128)
	var n := _label(p, str(d["name"]), 2, Color8(214, 66, 128))
	_center_label(n, 156, 8)
	var c := _label(p, L.t("DUEL_DARES"), 1, INK)
	_center_label(c, 156, 28)
	var b := _label(p, L.t("DUEL_BEAT_N", int(d["score"])), 2, INK)
	_center_label(b, 156, 42)
	var r := _label(p, L.t("DUEL_RULES"), 1, MUTED)
	_center_label(r, 156, 64)
	var go := _button(p, "pink", L.t("PLAY"), "duel", Vector2(88, 24))
	go.position = Vector2(34, 78)
	go.pressed.connect(func(): duel_accept_pressed.emit(d))
	var later := _button(p, "white", L.t("LATER"), "", Vector2(60, 20))
	later.position = Vector2(48, 106)
	later.pressed.connect(hide_popup)


## Today's 3 missions and the weekly challenge (rewards are paid automatically).
func show_mission() -> void:
	var p := _open_popup(L.t("MISSIONS"), "mission", 188)
	var t := _label(p, L.t("DAILY"), 1, MUTED)
	_center_label(t, 156, 5)
	var y := 18
	for m in Progress.missions():
		_mission_row(p, m, y)
		y += 32
	var w := _label(p, L.t("WEEKLY"), 1, Color8(214, 140, 30))
	_center_label(w, 156, y + 2)
	_mission_row(p, Progress.weekly(), y + 14)
	_close_button(p, y + 48)


func _mission_row(p: Control, m: Dictionary, y: int) -> void:
	var tl := _left_label(p, m["text"], Vector2(8, y), GREEN_INK if m["done"] else INK)
	while tl.text.length() > 4 and _text_w(tl.text) > 140:   # a long translation: cut, never overflow
		tl.text = tl.text.substr(0, tl.text.length() - 2) + "."
	# from the right: +reward, its coin, the progress text, then the bar fills what is left
	var rw := "+%d" % m["reward"]
	var rx := 149.0 - _text_w(rw)
	_left_label(p, rw, Vector2(roundf(rx), y + 10), COIN_INK)
	_icon(p, "icon_coin", Vector2(roundf(rx) - 11, y + 10))
	var pr := "%d/%d" % [m["progress"], m["goal"]] if not m["done"] else L.t("DONE")
	var px := roundf(rx - 14 - _text_w(pr))
	_left_label(p, pr, Vector2(px, y + 10), MUTED)
	var bar_w := maxf(24.0, px - 12.0)
	var bg := ColorRect.new()
	bg.color = Color8(220, 226, 240)
	bg.position = Vector2(8, y + 12)
	bg.size = Vector2(bar_w, 5)
	p.add_child(bg)
	var fill := ColorRect.new()
	fill.color = Color8(124, 226, 104) if m["done"] else GOLD
	fill.position = bg.position
	fill.size = Vector2(roundf(bar_w * float(m["progress"]) / float(m["goal"])), 5)
	p.add_child(fill)


const ROW := 20   # settings row spacing
const SHORT := Color8(220, 40, 60)   # a coin price the player cannot pay yet


func show_settings() -> void:
	var p := _open_popup(L.t("SETTINGS"), "settings", 248)
	var rows := [
		["SOUND", L.t("ON") if Save.sound else L.t("OFF"), func():
			Save.sound = not Save.sound
			Save.save_data()
			Sfx.set_music(Save.sound)],
		["MUSIC", L.t("ON") if Save.music else L.t("OFF"), func():
			Save.music = not Save.music
			Save.save_data()
			Sfx.set_music(true)],
		["VIBRATION", L.t("ON") if Save.vibration else L.t("OFF"), func():
			Save.vibration = not Save.vibration
			Save.save_data()
			Save.vibrate(40)],
		["MOTION", L.t("MOTION_REDUCED") if Save.reduce_motion else L.t("MOTION_FULL"), func():
			Save.reduce_motion = not Save.reduce_motion
			Save.save_data()],
		["LANGUAGE", L.LANG_NAMES[L.lang], func():
			var i := (L.LANGS.find(L.lang) + 1) % L.LANGS.size()
			Save.lang = L.LANGS[i]
			Save.save_data()
			L.set_lang(Save.lang)
			language_changed.emit()],
		["CLOUD", L.t("ON") if Progress.games.signed_in else L.t("SIGN_IN"), func():
			if Progress.games.available:
				Progress.games.sign_in()
			else:
				toast(L.t("PLAY_GAMES_OFF"), Color8(255, 150, 160))],
		["REGION", PlayGamesConfig.REGION_NAMES[Progress.region()], func():
			var keys: Array = PlayGamesConfig.REGION_NAMES.keys()
			Save.region = keys[(keys.find(Progress.region()) + 1) % keys.size()]
			Save.save_data()],
		["NOTIFY", L.t("ON") if Save.notifications else L.t("OFF"), func():
			Save.notifications = not Save.notifications
			Save.save_data()
			Progress.notifier.reschedule(Save)],
		["STATS", L.t("ON") if Save.share_stats else L.t("OFF"), func():
			Save.share_stats = not Save.share_stats
			Save.save_data()
			Progress.ga.set_opt_out(not Save.share_stats)],
		["PRIVACY", ">", func():
			if not Monetization.show_privacy_options():
				toast(L.t("PRIVACY") + " (TEST)", Color8(255, 236, 140))],
	]
	for i in rows.size():
		var y := 8 + i * ROW
		_left_label(p, L.t(rows[i][0]), Vector2(10, y + 5))
		var b := _button(p, "white", rows[i][1], "", Vector2(70, 18))
		b.position = Vector2(78, y)
		var cb: Callable = rows[i][2]
		b.pressed.connect(func():
			cb.call()
			if popup.visible and popup.get_meta("kind", "") == "settings":
				show_settings())
	var back := _button(p, "white", L.t("BACK"), "back", Vector2(70, 20))
	back.position = Vector2(6, 8 + rows.size() * ROW + 2)
	back.pressed.connect(hide_popup)
	var rate := _button(p, "green", L.t("RATE"), "star", Vector2(70, 20))
	rate.position = Vector2(80, 8 + rows.size() * ROW + 2)
	rate.pressed.connect(func(): Reviewer.open_store_page())
	var ver := _label(p, "V" + str(ProjectSettings.get_setting("application/config/version", "")), 1, MUTED)
	_center_label(ver, 156, 8 + rows.size() * ROW + 26)
	# hidden: tap the version 5 times to see what the ads / Play Games / store plugins reported
	var vb := Button.new()
	vb.flat = true
	vb.focus_mode = Control.FOCUS_NONE
	vb.position = Vector2(48, 8 + rows.size() * ROW + 22)
	vb.size = Vector2(60, 14)
	p.add_child(vb)
	vb.pressed.connect(func():
		_diag_taps += 1
		if _diag_taps >= 5:
			_diag_taps = 0
			show_diag())


var _diag_taps := 0


## Diagnostics popup (also copies the text so it can be pasted in a message).
func show_diag() -> void:
	var p := _open_popup("DIAG", "diag", 236)
	var ga: Analytics = Progress.ga
	Diag.log("analytics: %s, queued %d, sent %d, dropped %d, last http %s" % [ga.status_text(), ga.queue.size(), ga.sent, ga.dropped, ga.last_status])
	Diag.log("player id: " + ga.user_id)   # for data deletion requests (orbitpopgame.github.io/delete-data/)
	var txt := Diag.text()
	DisplayServer.clipboard_set(txt)
	var lab := Label.new()
	lab.add_theme_font_override("font", FONT_PLAIN)
	lab.add_theme_font_size_override("font_size", 8)
	lab.add_theme_color_override("font_color", INK)
	lab.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	lab.position = Vector2(4, 4)
	lab.size = Vector2(148, 200)
	lab.clip_text = true
	var shown: Array = txt.split("\n")
	# the pixel font only has capitals and a few symbols
	var newest := shown.slice(maxi(1, shown.size() - 18))
	newest.reverse()
	lab.text = (shown[0] + "\n" + "\n".join(newest)).to_upper().replace("=", ":").replace("_", "-")
	p.add_child(lab)
	var c := _left_label(p, L.t("COPIED"), Vector2(4, 206), GREEN_INK)
	c.scale = Vector2.ONE
	var back := _button(p, "white", L.t("BACK"), "back", Vector2(70, 20))
	back.position = Vector2(6, 214)
	back.pressed.connect(hide_popup)
	# testers: a reminder in 10 s (close the game to see it), to check the plugin + permission
	var nt := _button(p, "green", "NOTIF 10S", "", Vector2(70, 20))
	nt.position = Vector2(80, 214)
	nt.pressed.connect(func():
		toast("NOTIF: " + Progress.notifier.test_now(), Color8(120, 255, 200)))


## Queues short messages; they show one after another.
func toast(text: String, color := Color.WHITE) -> void:
	_toasts.append([text, color])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var item: Array = _toasts.pop_front()
	_toast.text = item[0]
	_toast.modulate = item[1]
	var sz := root.size
	var w := _text_w(_toast.text)
	_toast.size = Vector2(w + 6, 16)
	var ty := roundf(sz.y * 0.5) - 8
	var hide_tip := false
	if over.visible:
		# above the game over card, not on top of its coins / XP lines; on short screens there is
		# no room above it: then over the tip under the card (hidden while the message shows)
		ty = _over_box.global_position.y - 28.0
		if ty < 4.0 + safe_top():
			ty = minf(sz.y - 20.0, _over_box.global_position.y + 24.0 + _over_panel.size.y + 6.0)
			hide_tip = true
	_toast.position = Vector2(roundf((sz.x - w - 6) * 0.5), ty)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_over_tip1.visible = not hide_tip
	_over_tip2.visible = not hide_tip
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		_toast.visible = false
		_over_tip1.visible = true
		_over_tip2.visible = true
		_next_toast())


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.3, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause.add_child(dim)
	var box := _container(pause)
	_place(box, 0.5, -50, 180, 100)
	var l := _label(box, L.t("PAUSED"), 3)
	_center_label(l, 180, 0)
	var go := _button(box, "yellow", L.t("CONTINUE"), "", Vector2(100, 26), 2)
	go.position = Vector2(40, 36)
	go.pressed.connect(func(): resume_pressed.emit())
	var quit := _button(box, "white", L.t("MENU"), "home", Vector2(70, 22))
	quit.position = Vector2(55, 70)
	quit.pressed.connect(func(): quit_pressed.emit())


func show_pause() -> void:
	_banner.visible = false
	pause.visible = true
	pause.modulate.a = 1.0
	hud.visible = true
	_pause_btn.visible = false


func show_countdown_start() -> void:
	_pause_btn.visible = false


func show_countdown(n: int) -> void:
	pause.visible = false
	_pause_title.visible = true
	_pause_title.text = str(maxi(1, n))
	var sz := root.size
	var w := _text_w(_pause_title.text) * 4
	_pause_title.position = Vector2(roundf((sz.x - w) * 0.5), roundf(sz.y * 0.5) - 16)
