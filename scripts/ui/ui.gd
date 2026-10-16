class_name GameUI
extends CanvasLayer
## All ORBIT POP screens, built in code with the pixel UI kit:
## menu, HUD, game over, style (skins/trails/worlds), shop, pause and popups.

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
signal boost_toggled(id: String)
signal boost_buy(id: String)
signal daily_claim(doubled: bool)
signal free_coins_pressed

const FONT := preload("res://assets/font/pixel.fnt")
const FONT_PLAIN := preload("res://assets/font/pixel_plain.fnt")  # no outline: dark text on light UI
const SPR := "res://assets/sprites/"
const PINK := Color8(255, 128, 178)
const GOLD := Color8(255, 222, 70)
const INK := Color8(38, 28, 66)
const MUTED := Color8(120, 100, 150)
const COIN_INK := Color8(176, 112, 20)
const TABS := ["skins", "trails", "worlds"]

var root: Control
var menu: Control
var hud: Control
var over: Control
var skins: Control
var pause: Control
var shop: Control
var popup: Control
var flash_rect: ColorRect

var _score_lbl: Label
var _hud_best: Label
var _hint: Label
var _menu_best: Label
var _menu_coins: Label
var _gift_badge: Label
var _sound_icon: TextureRect
var _boost_btns := {}
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
var _pause_title: Label
var _pause_sub: Label
# style screen
var _style_tab := "skins"
var _style_page := 0
var _style_focus := 0
var _style_tabs := {}
var _style_cards: Array = []
var _style_preview: TextureRect
var _style_name: Label
var _style_action: Button
var _style_page_lbl: Label
var _style_coins: Label
var _style_arrows: Array = []
# shop
var _shop_tab := "packs"
var _shop_tabs := {}
var _shop_list: Control
var _shop_box: Control
var _popup_box: Control
var _toast: Label
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
	_build_popup()
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
	if _over_record and _over_record.visible:
		_over_record.modulate = Color.WHITE if fmod(_t, 0.5) < 0.3 else Color(1, 0.85, 0.4)
	if _gift_badge and _gift_badge.visible:
		_gift_badge.position.y = -4 + roundf(sin(_t * 6.0))
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


## Places a label horizontally centered (in parent space) at y.
func _center_label(l: Label, parent_w: float, y: float) -> void:
	var w := _text_w(l.text)
	l.size = Vector2(w, 10)
	l.position = Vector2(roundf((parent_w - w * l.scale.x) * 0.5), y)


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
	var tw := 0.0
	if text != "":
		tw = _text_w(text) * text_scale
	var iw := 11.0 if icon != "" else 0.0
	var gap := 2.0 if icon != "" and text != "" else 0.0
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


func _switch(to: Control) -> void:
	for s in [menu, hud, over, skins, pause, shop]:
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
	var best_box := _container(menu)
	_place(best_box, 0.0, logo.texture.get_height() + 16, 120, 10)
	_menu_best = _label(best_box, "", 1, GOLD)
	# coins (top-left) and daily gift (top-right)
	var cb := _container(menu)
	cb.position = Vector2(4, 3)
	_icon(cb, "icon_coin", Vector2.ZERO)
	_menu_coins = _label(cb, "0", 1, GOLD)
	_menu_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_menu_coins.position = Vector2(11, 0)
	var gift := _button(menu, "pink", "", "gift", Vector2(22, 20))
	gift.anchor_left = 1.0; gift.anchor_right = 1.0
	gift.offset_left = -25; gift.offset_right = -3; gift.offset_top = 2; gift.offset_bottom = 22
	gift.pressed.connect(show_daily)
	_gift_badge = _label(gift, "!", 1, GOLD)
	_gift_badge.position = Vector2(17, -4)
	var play := _button(menu, "yellow", "PLAY", "", Vector2(84, 28), 2)
	_place(play, 1.0, -64, 84, 28)
	play.pressed.connect(func(): play_pressed.emit())
	var xs := {"shield": -63, "rush": 63}
	for id in ["shield", "rush"]:
		var b := _button(menu, "white", "", MonetizationConfig.BOOSTS[id]["icon"], Vector2(24, 30))
		_place(b, 1.0, -65, 24, 30)
		b.offset_left += xs[id]; b.offset_right += xs[id]
		var ic: TextureRect = b.get_node("Content/Icon")
		ic.position = Vector2(6, 4)
		var n := _label(b.get_node("Content"), "0", 1, INK)
		n.name = "Count"
		b.pressed.connect(func(): boost_toggled.emit(id))
		_boost_btns[id] = b
	var sk := _button(menu, "white", "", "skins", Vector2(34, 22))
	_place(sk, 1.0, -31, 34, 22)
	sk.offset_left -= 38; sk.offset_right -= 38
	sk.pressed.connect(func(): skins_pressed.emit())
	var sh := _button(menu, "pink", "", "cart", Vector2(34, 22))
	_place(sh, 1.0, -31, 34, 22)
	sh.pressed.connect(func(): shop_pressed.emit())
	var so := _button(menu, "white", "", "sound_on", Vector2(34, 22))
	_place(so, 1.0, -31, 34, 22)
	so.offset_left += 38; so.offset_right += 38
	_sound_icon = so.get_node("Content/Icon")
	so.pressed.connect(_toggle_sound)


func _toggle_sound() -> void:
	Save.sound = not Save.sound
	Save.save_data()
	Sfx.set_music(Save.sound)
	_sound_icon.texture = _tex("icon_sound_on" if Save.sound else "icon_sound_off")
	Sfx.play("select")


func refresh_menu() -> void:
	_menu_best.text = "BEST %d" % Save.best if Save.best > 0 else "TAP TO FLIP YOUR ORBIT"
	_center_label(_menu_best, 120, 0)
	_menu_coins.text = str(Save.coins)
	_menu_coins.size = Vector2(_text_w(_menu_coins.text), 10)
	_gift_badge.visible = Save.daily_available()
	_sound_icon.texture = _tex("icon_sound_on" if Save.sound else "icon_sound_off")


func refresh_boosts(armed: Dictionary) -> void:
	for id in _boost_btns:
		var b: Button = _boost_btns[id]
		var n: Label = b.get_node("Content/Count")
		var count := int(Save.boosts.get(id, 0))
		n.text = str(count) if count > 0 else "+"
		_center_label(n, 24, 17)
		_style_button(b, "green" if armed.get(id, false) else "white")


func show_menu(armed := {}) -> void:
	refresh_menu()
	refresh_boosts(armed)
	_switch(menu)


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = _screen()
	var top := _container(hud)
	_place(top, 0.0, 0, 180, 60)
	_score_lbl = _label(top, "0", 3)
	_hud_best = _label(top, "", 1, Color(1, 1, 1, 0.85))
	var bottom := _container(hud)
	_place(bottom, 1.0, -52, 180, 20)
	_hint = _label(bottom, "TAP TO FLIP!", 2, Color.WHITE)
	_center_label(_hint, 180, 0)
	_pause_title = _label(hud, "", 4)


func show_hud(best: int, hint: bool) -> void:
	set_score(0)
	_hud_best.text = "BEST %d" % best if best > 0 else ""
	_hud_best.modulate = Color(1, 1, 1, 0.85)
	_center_label(_hud_best, 180, 34)
	_hint.visible = hint
	_pause_title.visible = false
	_switch(hud)


func show_hud_resume() -> void:
	_pause_title.visible = false
	for s in [pause, over, menu, skins, shop]:
		s.visible = false
	hud.visible = true
	hud.modulate.a = 1.0


func show_hud_continue(score: int, best: int) -> void:
	show_hud(best, false)
	set_score(score)


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


func announce_record() -> void:
	_hud_best.text = "NEW BEST!"
	_hud_best.modulate = PINK
	_center_label(_hud_best, 180, 34)


func flash() -> void:
	flash_rect.color = Color(1, 1, 1, 0.85)
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.25)


# ------------------------------------------------------------------ game over

func _build_over() -> void:
	over = _screen()
	var box := _container(over)
	_place(box, 0.5, -118, 136, 236)
	var title := _label(box, "GAME OVER", 2)
	_center_label(title, 136, 0)
	var panel := _panel(box, Vector2(0, 24), Vector2(136, 200))
	_over_panel = panel
	var cap := _label(panel, "SCORE", 1, MUTED)
	_center_label(cap, 136, 7)
	_over_score = _label(panel, "0", 4, INK)
	_over_best_cap = _label(panel, "BEST", 1, MUTED)
	_center_label(_over_best_cap, 136, 56)
	_over_best = _label(panel, "0", 2, INK)
	_over_record = _container(panel)
	_over_record.position = Vector2(0, 58)
	var rl := _label(_over_record, "NEW BEST!", 2, PINK)
	_center_label(rl, 136, 0)
	for xx in [8, 117]:
		_icon(_over_record, "icon_star", Vector2(xx, 3))
	_icon(panel, "icon_coin", Vector2(30, 89))
	_over_coins = _label(panel, "+0", 1, COIN_INK)
	_over_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_over_coins.position = Vector2(42, 90)
	_over_double = _button(panel, "pink", "X2", "video", Vector2(40, 18))
	_over_double.position = Vector2(80, 85)
	_over_double.pressed.connect(func(): double_pressed.emit())
	_over_unlock = _label(panel, "", 1, Color8(40, 160, 110))
	_over_continue = _button(panel, "pink", "CONTINUE", "video", Vector2(108, 24))
	_over_continue.pressed.connect(func(): continue_pressed.emit())
	_over_continue_free = _button(panel, "green", "CONTINUE", "retry", Vector2(108, 24))
	_over_continue_free.pressed.connect(func(): continue_pressed.emit())
	var retry := _button(panel, "yellow", "RETRY", "retry", Vector2(108, 28), 2)
	retry.pressed.connect(func(): retry_pressed.emit())
	var home := _button(panel, "white", "MENU", "home", Vector2(70, 22))
	home.pressed.connect(func(): menu_pressed.emit())
	_over_buttons = [retry, home, _over_continue, _over_continue_free, _over_double]


func show_game_over(score: int, best: int, record: bool, unlocked: Array, can_continue := false, free_continue := false) -> void:
	_over_continue.visible = can_continue and not free_continue
	_over_continue_free.visible = can_continue and free_continue
	var y := 120
	_over_continue.position = Vector2(14, y)
	_over_continue_free.position = Vector2(14, y)
	if can_continue:
		y += 28
	_over_buttons[0].position = Vector2(14, y)
	_over_buttons[1].position = Vector2(33, y + 34)
	_over_panel.size.y = y + 66
	_over_score.text = str(score)
	_center_label(_over_score, 136, 19)
	_over_best.text = str(best)
	_center_label(_over_best, 136, 66)
	_over_record.visible = record and score > 0
	_over_best_cap.visible = not _over_record.visible
	_over_best.visible = not _over_record.visible
	_over_unlock.text = "" if unlocked.is_empty() else "NEW SKIN: %s!" % Save.SKINS[unlocked[-1]]["name"]
	_center_label(_over_unlock, 136, 106)
	for b in _over_buttons:
		b.disabled = true
	get_tree().create_timer(0.3).timeout.connect(func():
		for b in _over_buttons:
			b.disabled = false)
	_switch(over)


func set_over_coins(n: int, can_double: bool) -> void:
	_over_coins.text = "+%d" % n
	_over_double.visible = can_double


# ------------------------------------------------------------------ style (skins / trails / worlds)

func _build_style() -> void:
	skins = _screen()
	_dim(skins)
	var box := _container(skins)
	_place(box, 0.5, -152, 164, 304)
	var labels := {"skins": "SKINS", "trails": "TRAILS", "worlds": "WORLDS"}
	for i in TABS.size():
		var id: String = TABS[i]
		var b := _button(box, "white", labels[id], "", Vector2(52, 18))
		b.position = Vector2(i * 56, 0)
		b.pressed.connect(func():
			_style_tab = id
			_style_page = 0
			_style_focus = Save.selected(id)
			_refresh_style())
		_style_tabs[id] = b
	var panel := _panel(box, Vector2(0, 21), Vector2(164, 256))
	_style_preview = TextureRect.new()
	_style_preview.texture = AtlasTexture.new()
	_style_preview.scale = Vector2(3, 3)
	_style_preview.position = Vector2(16, 6)
	_style_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_style_preview)
	_style_name = _label(panel, "", 1, INK)
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
		card.pressed.connect(_on_card.bind(i))
		_style_cards.append({"card": card, "pic": pic, "lock": lock, "coin": coin, "cap": cap})
	for k in 2:
		var ar := _button(panel, "white", "", "left" if k == 0 else "right", Vector2(26, 16))
		ar.position = Vector2(8 if k == 0 else 130, 234)
		ar.pressed.connect(func():
			_style_page = (_style_page + (-1 if k == 0 else 1) + _pages()) % _pages()
			_refresh_style())
		_style_arrows.append(ar)
	_style_page_lbl = _label(panel, "", 1, MUTED)
	var back := _button(box, "white", "BACK", "back", Vector2(76, 22))
	back.position = Vector2(44, 282)
	back.pressed.connect(func(): menu_pressed.emit())


func _pages() -> int:
	return ceili(Catalog.items(_style_tab).size() / 9.0)


func _item_tex(cat: String, i: int, anim_frame := 1) -> Dictionary:
	var it: Dictionary = Catalog.items(cat)[i]
	match cat:
		"skins":
			return {"atlas": _tex("char_" + it["id"]), "region": Rect2(anim_frame * 16, 0, 16, 16)}
		"trails":
			return {"atlas": _tex("trail_" + it["id"]), "region": Rect2(0, 0, 16, 16)}
	return {"atlas": _tex("world_" + it["id"]), "region": Rect2(0, 0, 16, 16)}


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
			Save.select(_style_tab, i)
			style_changed.emit()
			Sfx.play("unlock")
			toast("UNLOCKED " + Catalog.items(_style_tab)[i]["name"] + "!", Color8(120, 255, 200))
		else:
			Sfx.play("deny")
			toast("NOT ENOUGH COINS", Color8(255, 150, 160))
	_refresh_style()


func _refresh_style() -> void:
	var list: Array = Catalog.items(_style_tab)
	var cur := Save.selected(_style_tab)
	for id in _style_tabs:
		_style_button(_style_tabs[id], "yellow" if id == _style_tab else "white")
	_style_coins.text = str(Save.coins)
	# preview (always in full color so players see what they would get)
	var f := _style_focus
	var tx := _item_tex(_style_tab, f)
	var at: AtlasTexture = _style_preview.texture
	at.atlas = tx["atlas"]
	at.region = tx["region"]
	var it: Dictionary = list[f]
	var un := Save.unlocked(_style_tab, f)
	var need: Array = it["need"]
	_style_name.text = it["name"] if un or need[0] != "best" and need[0] != "total" else "%s - %s" % [it["name"], Save.need_text(_style_tab, f)]
	_style_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_name.size = Vector2(_text_w(_style_name.text), 10)
	_style_name.position = Vector2(84 if not un and need[0] in ["coins", "shop"] else roundf((164 - _style_name.size.x) * 0.5), 24 if not un and need[0] in ["coins", "shop"] else 56)
	if un:
		_style_name.position = Vector2(84, 26)
	_style_action.visible = not un and need[0] in ["coins", "shop"]
	if _style_action.visible:
		var coin_item: bool = need[0] == "coins"
		(_style_action.get_node("Content/Icon") as TextureRect).visible = coin_item
		_style_button(_style_action, "yellow" if coin_item else "pink")
		_set_button_text(_style_action, str(need[1]) if coin_item else "SHOP")
		(_style_action.get_node("Content/Text") as Label).modulate = INK if coin_item else Color.WHITE
	# grid
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
		if i == _style_focus and not unl:
			d["pic"].modulate = Color(1, 1, 1, 0.8)
		d["lock"].visible = not unl
		d["coin"].visible = not unl and n[0] == "coins"
		var cap: Label = d["cap"]
		cap.text = list[i]["name"] if unl else Save.need_text(_style_tab, i)
		cap.modulate = INK if unl else (Color8(214, 66, 128) if n[0] == "shop" else (COIN_INK if n[0] == "coins" else MUTED))
		_center_label(cap, 48, 40)
		if d["coin"].visible:
			cap.position.x += 6
			d["coin"].position.x = cap.position.x - 11
	var pages := _pages()
	for ar in _style_arrows:
		ar.visible = pages > 1
	_style_page_lbl.text = "%d/%d" % [_style_page + 1, pages] if pages > 1 else ("GAMES %d  TOTAL %d" % [Save.games, Save.total])
	_center_label(_style_page_lbl, 164, 238)


func show_skins() -> void:
	_style_focus = Save.selected(_style_tab)
	_style_page = _style_focus / 9
	_refresh_style()
	_switch(skins)


# ------------------------------------------------------------------ shop

func _build_shop() -> void:
	shop = _screen()
	_dim(shop)
	_shop_box = _container(shop)
	_place(_shop_box, 0.5, -152, 164, 280)
	for i in 2:
		var id: String = ["packs", "boosts"][i]
		var b := _button(_shop_box, "white", "PACKS" if i == 0 else "COINS", "cart" if i == 0 else "coin", Vector2(78, 18))
		b.position = Vector2(i * 86, 0)
		b.pressed.connect(func():
			_shop_tab = id
			refresh_shop())
		_shop_tabs[id] = b
	var panel := _panel(_shop_box, Vector2(0, 21), Vector2(164, 232))
	_shop_list = _container(panel)
	var back := _button(_shop_box, "white", "BACK", "back", Vector2(76, 22))
	back.position = Vector2(44, 257)
	back.pressed.connect(func(): menu_pressed.emit())


func _shop_row(y: int, icon: String, name: String, desc: String, btn_style: String, btn_text: String, btn_icon: String, enabled: bool, cb: Callable) -> Button:
	_icon(_shop_list, "icon_" + icon, Vector2(5, y + 3))
	var nm := _label(_shop_list, name, 1, INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nm.position = Vector2(19, y)
	var ds := _label(_shop_list, desc, 1, MUTED)
	ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ds.position = Vector2(19, y + 10)
	var b := _button(_shop_list, btn_style, btn_text, btn_icon, Vector2(54, 20))
	b.position = Vector2(104, y)
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
		for id in ids:
			var info: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
			var owned := Save.owns(id)
			_shop_row(y, info["icon"], info["name"], info["desc"], "green" if owned else ("pink" if id == "starter" else "yellow"),
				"OWNED" if owned else Monetization.price(id), "", online and not owned, func(): buy_pressed.emit(id))
			y += 30
		var rs := _button(_shop_list, "white", "RESTORE", "", Vector2(70, 18))
		rs.position = Vector2(47, 208)
		rs.pressed.connect(func(): restore_pressed.emit())
	else:
		var cb := _container(_shop_list)
		_icon(cb, "icon_coin", Vector2(0, 0), 2)
		var cl := _label(cb, str(Save.coins), 2, COIN_INK)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cl.position = Vector2(22, 2)
		cb.position = Vector2(roundf((164 - 22 - _text_w(cl.text) * 2) * 0.5), 6)
		y = 32
		for id in MonetizationConfig.BOOSTS:
			var bi: Dictionary = MonetizationConfig.BOOSTS[id]
			_shop_row(y, bi["icon"], "%s x%d" % [bi["name"], int(Save.boosts.get(id, 0))] if id == "shield" else "RUSH x%d" % int(Save.boosts.get(id, 0)),
				bi["desc"], "yellow", str(bi["price"]), "coin", true, func(): boost_buy.emit(id))
			y += 30
		var left := Save.free_ads_left()
		_shop_row(y, "video", "FREE COINS", "%d LEFT TODAY" % left, "pink", "+%d" % MonetizationConfig.FREE_COIN_AD_REWARD, "video",
			left > 0 and Monetization.rewarded_ready(), func(): free_coins_pressed.emit())
		y += 30
		for id in MonetizationConfig.CONSUMABLES:
			var info2: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
			_shop_row(y, info2["icon"], info2["name"], info2["desc"], "yellow", Monetization.price(id), "", online, func(): buy_pressed.emit(id))
			y += 30
		var tip := _label(_shop_list, "1 BOOST OF EACH PER RUN", 1, MUTED)
		_center_label(tip, 164, 166)
	var mode := Monetization.store_mode
	var st := _label(_shop_list, "STORE OFFLINE" if not online else ("TEST STORE (NO CHARGES)" if mode == "test" else "PAID VIA GOOGLE PLAY"), 1, MUTED)
	_center_label(st, 164, 194)


func show_shop(tab := "packs") -> void:
	_shop_tab = tab
	# keep the shop clear of the banner ad at the bottom of the screen
	var banner := 0 if Monetization.ads_removed() else MonetizationConfig.BANNER_HEIGHT
	var top := maxf(4.0, roundf((root.size.y - banner - 280.0) * 0.5))
	_shop_box.anchor_top = 0.0; _shop_box.anchor_bottom = 0.0
	_shop_box.offset_top = top
	_shop_box.offset_bottom = top + 280
	refresh_shop()
	_switch(shop)


# ------------------------------------------------------------------ popups (daily gift / starter offer)

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
	_place(_popup_box, 0.5, -80, 156, 160)


func _open_popup(title: String) -> NinePatchRect:
	_clear(_popup_box)
	var t := _label(_popup_box, title, 2)
	_center_label(t, 156, 0)
	var p := _panel(_popup_box, Vector2(0, 22), Vector2(156, 136))
	popup.visible = true
	popup.modulate.a = 0.0
	create_tween().tween_property(popup, "modulate:a", 1.0, 0.15)
	return p


func hide_popup() -> void:
	popup.visible = false


func show_daily() -> void:
	if not Save.daily_available():
		toast("COME BACK TOMORROW!", GOLD)
		return
	var g := Save.daily_preview()
	var p := _open_popup("DAILY GIFT")
	var day: int = g["day"]
	for i in 7:
		var r: Dictionary = MonetizationConfig.DAILY_REWARDS[i]
		var cell := NinePatchRect.new()
		cell.texture = _tex("card_sel" if i + 1 == day else "card")
		cell.patch_margin_left = 3; cell.patch_margin_right = 3; cell.patch_margin_top = 3; cell.patch_margin_bottom = 3
		cell.position = Vector2(6 + i * 21, 8)
		cell.size = Vector2(20, 26)
		cell.modulate = Color(1, 1, 1, 0.5) if i + 1 < day else Color.WHITE
		p.add_child(cell)
		var dl := _label(cell, "D%d" % (i + 1), 1, MUTED)
		_center_label(dl, 20, 3)
		var cl := _label(cell, str(r["coins"]), 1, COIN_INK)
		_center_label(cl, 20, 14)
	var big := _container(p)
	_icon(big, "icon_coin", Vector2(0, 2), 2)
	var amount := _label(big, "+%d" % g["coins"], 3, COIN_INK)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.position = Vector2(24, 0)
	big.position = Vector2(roundf((156 - 24 - _text_w(amount.text) * 3) * 0.5), 42)
	var extra := _label(p, "+1 " + MonetizationConfig.BOOSTS[g["boost"]]["name"] if g["boost"] != "" else "DAY %d OF 7" % day, 1, MUTED)
	_center_label(extra, 156, 72)
	var claim := _button(p, "yellow", "CLAIM", "", Vector2(64, 24))
	claim.position = Vector2(10, 92)
	claim.pressed.connect(func(): daily_claim.emit(false))
	var dbl := _button(p, "pink", "X2", "video", Vector2(64, 24))
	dbl.position = Vector2(82, 92)
	dbl.disabled = not Monetization.rewarded_ready()
	dbl.pressed.connect(func(): daily_claim.emit(true))


func show_starter() -> void:
	var p := _open_popup("STARTER PACK")
	var lines := ["NO ADS + FREE CONTINUE", "+%d COINS" % MonetizationConfig.BUNDLE_BONUS["starter"]["coins"],
		"+%d SHIELDS" % MonetizationConfig.BUNDLE_BONUS["starter"]["boosts"]["shield"], "ONE-TIME OFFER!"]
	for i in lines.size():
		var l := _label(p, lines[i], 1, INK if i < 3 else Color8(214, 66, 128))
		_center_label(l, 156, 10 + i * 14)
	var buy := _button(p, "pink", Monetization.price("starter"), "gift", Vector2(80, 24))
	buy.position = Vector2(38, 70)
	buy.pressed.connect(func():
		hide_popup()
		buy_pressed.emit("starter"))
	var later := _button(p, "white", "LATER", "", Vector2(60, 20))
	later.position = Vector2(48, 102)
	later.pressed.connect(hide_popup)


func toast(text: String, color := Color.WHITE) -> void:
	_toast.text = text
	_toast.modulate = color
	var sz := root.size
	var w := _text_w(text)
	_toast.size = Vector2(w + 6, 16)
	_toast.position = Vector2(roundf((sz.x - w - 6) * 0.5), roundf(sz.y * 0.5) - 8)
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _toast.visible = false)


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.3, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause.add_child(dim)
	var box := _container(pause)
	_place(box, 0.5, -30, 180, 60)
	var l := _label(box, "PAUSED", 3)
	_center_label(l, 180, 0)
	_pause_sub = _label(box, "TAP TO CONTINUE", 1)
	_center_label(_pause_sub, 180, 34)


func show_pause() -> void:
	pause.visible = true
	pause.modulate.a = 1.0
	hud.visible = true


func show_countdown(n: int) -> void:
	pause.visible = false
	_pause_title.visible = true
	_pause_title.text = str(maxi(1, n))
	var sz := root.size
	var w := _text_w(_pause_title.text) * 4
	_pause_title.position = Vector2(roundf((sz.x - w) * 0.5), roundf(sz.y * 0.5) - 16)
