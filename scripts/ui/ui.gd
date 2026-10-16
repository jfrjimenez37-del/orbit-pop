class_name GameUI
extends CanvasLayer
## All ORBIT POP screens, built in code with the pixel UI kit (menu, HUD, game over, skins, pause).

signal play_pressed
signal retry_pressed
signal menu_pressed
signal skins_pressed
signal skin_selected(index: int)
signal continue_pressed
signal shop_pressed
signal buy_pressed(product_id: String)
signal restore_pressed

const FONT := preload("res://assets/font/pixel.fnt")
const FONT_PLAIN := preload("res://assets/font/pixel_plain.fnt")  # no outline: dark text on light UI
const SPR := "res://assets/sprites/"
const PINK := Color8(255, 128, 178)
const GOLD := Color8(255, 222, 70)
const INK := Color8(38, 28, 66)

var root: Control
var menu: Control
var hud: Control
var over: Control
var skins: Control
var pause: Control
var shop: Control
var flash_rect: ColorRect

var _score_lbl: Label
var _hud_best: Label
var _hint: Label
var _menu_best: Label
var _sound_icon: TextureRect
var _over_score: Label
var _over_best: Label
var _over_best_cap: Label
var _over_record: Control
var _over_unlock: Label
var _over_buttons: Array[Button] = []
var _over_title: Label
var _pause_title: Label
var _pause_sub: Label
var _skin_cards: Array = []
var _skin_preview: TextureRect
var _skin_name: Label
var _skin_stats: Label
var _t := 0.0
var _active: Control
var _over_continue: Button
var _over_panel: NinePatchRect
var _shop_rows := {}
var _shop_status: Label
var _toast: Label


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
	_build_skins()
	_build_pause()
	_build_shop()
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
	if skins.visible:
		var fr: int = [0, 1, 2, 1][int(_t * 10.0) % 4]
		(_skin_preview.texture as AtlasTexture).region = Rect2(fr * 16, 0, 16, 16)


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


## Places a label horizontally centered (in parent space) at y.
func _center_label(l: Label, parent_w: float, y: float) -> void:
	var w := FONT.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	l.size = Vector2(w, 10)
	l.position = Vector2(roundf((parent_w - w * l.scale.x) * 0.5), y)


func _button(parent: Control, style: String, text: String, icon: String, size: Vector2, text_scale := 1) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_stylebox_override("normal", _box("btn_" + style))
	b.add_theme_stylebox_override("hover", _box("btn_" + style))
	b.add_theme_stylebox_override("pressed", _box("btn_" + style + "_pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size = size
	b.add_child(content)
	var tw := 0.0
	if text != "":
		tw = FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * text_scale
	var iw := 11.0 if icon != "" else 0.0
	var gap := 3.0 if icon != "" and text != "" else 0.0
	var x := roundf((size.x - tw - iw - gap) * 0.5)
	var cy := roundf((size.y - 2.0) * 0.5)
	if icon != "":
		var ir := TextureRect.new()
		ir.texture = _tex("icon_" + icon)
		ir.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ir.position = Vector2(x, cy - 5)
		ir.name = "Icon"
		content.add_child(ir)
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


func _screen() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	root.add_child(c)
	return c


## Anchors `c` to the top/bottom center of its parent with a given y offset.
func _place(c: Control, anchor_y: float, y: float, w: float, h: float) -> void:
	c.anchor_left = 0.5; c.anchor_right = 0.5
	c.anchor_top = anchor_y; c.anchor_bottom = anchor_y
	c.offset_left = -roundf(w * 0.5); c.offset_right = c.offset_left + w
	c.offset_top = y; c.offset_bottom = y + h


func _switch(to: Control) -> void:
	for s in [menu, hud, over, skins, pause, shop]:
		if s != to and s.visible and s != hud:
			s.visible = false
	if to != hud:
		hud.visible = false
	_active = to
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
	var lw := logo.texture.get_width()
	_place(logo, 0.0, 8, lw, logo.texture.get_height())
	logo.set_meta("bob", true)
	var best_box := Control.new()
	best_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(best_box)
	_place(best_box, 0.0, logo.texture.get_height() + 10, 120, 10)
	_menu_best = _label(best_box, "", 1, GOLD)
	var play := _button(menu, "yellow", "PLAY", "", Vector2(84, 28), 2)
	_place(play, 1.0, -64, 84, 28)
	play.pressed.connect(func(): play_pressed.emit())
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
	_sound_icon = so.get_child(0).get_node("Icon")
	so.pressed.connect(_toggle_sound)


func _toggle_sound() -> void:
	Save.sound = not Save.sound
	Save.save_data()
	Sfx.set_music(Save.sound)
	_refresh_sound()
	Sfx.play("select")


func _refresh_sound() -> void:
	_sound_icon.texture = _tex("icon_sound_on" if Save.sound else "icon_sound_off")


func show_menu() -> void:
	_menu_best.text = "BEST %d" % Save.best if Save.best > 0 else "TAP TO FLIP YOUR ORBIT"
	_center_label(_menu_best, 120, 0)
	_refresh_sound()
	_switch(menu)


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = _screen()
	var top := Control.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	_place(top, 0.0, 0, 180, 60)
	_score_lbl = _label(top, "0", 3)
	_hud_best = _label(top, "", 1, Color(1, 1, 1, 0.85))
	var bottom := Control.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(bottom)
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
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(box)
	_place(box, 0.5, -104, 136, 208)
	box.anchor_top = 0.5; box.anchor_bottom = 0.5
	_over_title = _label(box, "GAME OVER", 2)
	_center_label(_over_title, 136, 0)
	var panel := NinePatchRect.new()
	_over_panel = panel
	panel.texture = _tex("panel")
	panel.patch_margin_left = 4; panel.patch_margin_right = 4
	panel.patch_margin_top = 4; panel.patch_margin_bottom = 4
	panel.position = Vector2(0, 24)
	panel.size = Vector2(136, 182)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	var cap := _label(panel, "SCORE", 1, Color8(120, 110, 160))
	_center_label(cap, 136, 7)
	_over_score = _label(panel, "0", 4, INK)
	_over_best_cap = _label(panel, "BEST", 1, Color8(120, 110, 160))
	_center_label(_over_best_cap, 136, 58)
	_over_best = _label(panel, "0", 2, INK)
	_over_record = Control.new()
	_over_record.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_over_record)
	_over_record.position = Vector2(0, 60)
	var rl := _label(_over_record, "NEW BEST!", 2, PINK)
	_center_label(rl, 136, 0)
	for xx in [8, 117]:
		var st := TextureRect.new()
		st.texture = _tex("icon_star")
		st.position = Vector2(xx, 3)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_over_record.add_child(st)
	_over_unlock = _label(panel, "", 1, Color8(40, 160, 110))
	var retry := _button(panel, "yellow", "RETRY", "retry", Vector2(108, 28), 2)
	retry.position = Vector2(14, 114)
	retry.pressed.connect(func(): retry_pressed.emit())
	var home := _button(panel, "white", "MENU", "home", Vector2(70, 22))
	home.position = Vector2(33, 150)
	home.pressed.connect(func(): menu_pressed.emit())
	_over_continue = _button(panel, "pink", "CONTINUE", "video", Vector2(108, 24))
	_over_continue.position = Vector2(14, 112)
	_over_continue.pressed.connect(func(): continue_pressed.emit())
	_over_buttons = [retry, home, _over_continue]


func show_game_over(score: int, best: int, record: bool, unlocked: Array, can_continue := false) -> void:
	_over_continue.visible = can_continue
	var y0 := 140 if can_continue else 114
	_over_buttons[0].position.y = y0
	_over_buttons[1].position.y = y0 + 36
	_over_panel.size.y = y0 + 68
	_over_score.text = str(score)
	_center_label(_over_score, 136, 20)
	_over_best.text = str(best)
	_center_label(_over_best, 136, 70)
	_over_record.visible = record and score > 0
	_over_best_cap.visible = not _over_record.visible
	_over_best.visible = true
	if _over_record.visible:
		_over_best.visible = false
	if unlocked.is_empty():
		_over_unlock.text = ""
	else:
		_over_unlock.text = "NEW SKIN: %s!" % Save.SKINS[unlocked[-1]]["name"]
	_center_label(_over_unlock, 136, 98)
	for b in _over_buttons:
		b.disabled = true
	get_tree().create_timer(0.3).timeout.connect(func():
		for b in _over_buttons:
			b.disabled = false)
	_switch(over)


# ------------------------------------------------------------------ skins

func _build_skins() -> void:
	skins = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.2, 0.45, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	skins.add_child(dim)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skins.add_child(box)
	_place(box, 0.5, -153, 164, 306)
	var title := _label(box, "SKINS", 2)
	_center_label(title, 164, 0)
	var panel := NinePatchRect.new()
	panel.texture = _tex("panel")
	panel.patch_margin_left = 4; panel.patch_margin_right = 4
	panel.patch_margin_top = 4; panel.patch_margin_bottom = 4
	panel.position = Vector2(0, 22)
	panel.size = Vector2(164, 256)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	_skin_preview = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = _tex("char_poppy")
	at.region = Rect2(0, 0, 16, 16)
	_skin_preview.texture = at
	_skin_preview.scale = Vector2(3, 3)
	_skin_preview.position = Vector2(58, 6)
	_skin_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_skin_preview)
	_skin_name = _label(panel, "", 1, INK)
	_skin_stats = _label(panel, "", 1, Color8(120, 110, 160))
	for i in Save.SKINS.size():
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.size = Vector2(48, 52)
		card.position = Vector2(8 + (i % 3) * 50, 76 + (i / 3) * 56)
		card.add_theme_stylebox_override("normal", _box("card", 3))
		card.add_theme_stylebox_override("hover", _box("card", 3))
		card.add_theme_stylebox_override("pressed", _box("card", 3))
		card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		panel.add_child(card)
		var pic := TextureRect.new()
		var a2 := AtlasTexture.new()
		a2.atlas = _tex("char_" + Save.SKINS[i]["id"])
		a2.region = Rect2(16, 0, 16, 16)
		pic.texture = a2
		pic.scale = Vector2(2, 2)
		pic.position = Vector2(8, 4)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
		var lock := TextureRect.new()
		lock.texture = _tex("icon_lock")
		lock.position = Vector2(19, 15)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lock)
		var cap := _label(card, "", 1, INK)
		card.pressed.connect(_on_card.bind(i))
		_skin_cards.append({"card": card, "pic": pic, "lock": lock, "cap": cap})
	var back := _button(box, "white", "BACK", "back", Vector2(76, 22))
	back.position = Vector2(44, 282)
	back.pressed.connect(func(): menu_pressed.emit())


func _on_card(i: int) -> void:
	if Save.is_unlocked(i):
		skin_selected.emit(i)
		Sfx.play("select")
		_refresh_skins()
	elif Save.is_premium(i):
		shop_pressed.emit()
	else:
		Sfx.play("deny")
		var c: Button = _skin_cards[i]["card"]
		var x0 := c.position.x
		var tw := create_tween()
		for k in [3, -3, 2, 0]:
			tw.tween_property(c, "position:x", x0 + k, 0.04)


func _refresh_skins() -> void:
	var cur := Save.skin
	(_skin_preview.texture as AtlasTexture).atlas = _tex("char_" + Save.SKINS[cur]["id"])
	_skin_name.text = Save.SKINS[cur]["name"]
	_center_label(_skin_name, 164, 56)
	_skin_stats.text = "GAMES %d  TOTAL %d" % [Save.games, Save.total]
	_center_label(_skin_stats, 164, 242)
	for i in _skin_cards.size():
		var d: Dictionary = _skin_cards[i]
		var un := Save.is_unlocked(i)
		var card: Button = d["card"]
		var sel := i == cur
		var style := _box("card_sel" if sel else "card", 3)
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		d["pic"].modulate = Color.WHITE if un else Color(0.2, 0.16, 0.35, 0.55)
		d["lock"].visible = not un
		d["cap"].text = Save.SKINS[i]["name"] if un else Save.unlock_text(i)
		d["cap"].modulate = INK if un else (Color8(214, 66, 128) if Save.is_premium(i) else Color8(120, 100, 150))
		_center_label(d["cap"], 48, 40)


func show_skins() -> void:
	_refresh_skins()
	_switch(skins)


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.12, 0.3, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause.add_child(dim)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause.add_child(box)
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
	var w := FONT.get_string_size(_pause_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 4
	_pause_title.position = Vector2(roundf((sz.x - w) * 0.5), roundf(sz.y * 0.5) - 16)


# ------------------------------------------------------------------ shop

func _build_shop() -> void:
	shop = _screen()
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.2, 0.45, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop.add_child(dim)
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop.add_child(box)
	_place(box, 0.5, -124, 164, 248)
	var title := _label(box, "SHOP", 2)
	_center_label(title, 164, 0)
	var panel := NinePatchRect.new()
	panel.texture = _tex("panel")
	panel.patch_margin_left = 4; panel.patch_margin_right = 4
	panel.patch_margin_top = 4; panel.patch_margin_bottom = 4
	panel.position = Vector2(0, 22)
	panel.size = Vector2(164, 196)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	var icons := {"no_ads": "noads", "star_pack": "star", "supporter": "crown"}
	var y := 8
	for id in MonetizationConfig.PRODUCTS:
		var info: Dictionary = MonetizationConfig.PRODUCT_INFO[id]
		var ic := TextureRect.new()
		ic.texture = _tex("icon_" + icons[id])
		ic.position = Vector2(6, y + 3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ic)
		var nm := _label(panel, info["name"], 1, INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		nm.position = Vector2(20, y + 1)
		var ds := _label(panel, info["desc"], 1, Color8(120, 100, 150))
		ds.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ds.position = Vector2(20, y + 12)
		if id == "star_pack":
			for k in 3:
				var pic := TextureRect.new()
				var at := AtlasTexture.new()
				at.atlas = _tex("char_" + Save.SKINS[6 + k]["id"])
				at.region = Rect2(16, 0, 16, 16)
				pic.texture = at
				pic.position = Vector2(20 + k * 17, y + 22)
				pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				panel.add_child(pic)
		var buy := _button(panel, "yellow", "$0.00", "", Vector2(52, 22))
		buy.position = Vector2(106, y + 2)
		buy.pressed.connect(func(): buy_pressed.emit(id))
		_shop_rows[id] = buy
		y += 46 if id == "star_pack" else 34
	_shop_status = _label(panel, "", 1, Color8(120, 100, 150))
	var rs := _button(panel, "white", "RESTORE", "", Vector2(76, 20))
	rs.position = Vector2(44, 160)
	rs.pressed.connect(func(): restore_pressed.emit())
	var back := _button(box, "white", "BACK", "back", Vector2(76, 22))
	back.position = Vector2(44, 224)
	back.pressed.connect(func(): menu_pressed.emit())


func refresh_shop() -> void:
	var online := Monetization.store_available()
	for id in _shop_rows:
		var b: Button = _shop_rows[id]
		var owned := Save.owns(id)
		var txt: Label = b.get_child(0).get_node("Text")
		txt.text = "OWNED" if owned else Monetization.price(id)
		var w := FONT.get_string_size(txt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		txt.position.x = roundf((b.size.x - w) * 0.5)
		b.disabled = owned or not online
		var st := _box("btn_green" if owned else "btn_yellow")
		b.add_theme_stylebox_override("disabled", st)
	var mode := Monetization.store_mode
	_shop_status.text = "STORE OFFLINE" if not online else ("TEST STORE (NO CHARGES)" if mode == "test" else "PAID VIA GOOGLE PLAY")
	_center_label(_shop_status, 164, 146)


func show_shop() -> void:
	refresh_shop()
	_switch(shop)


func toast(text: String, color := Color.WHITE) -> void:
	_toast.text = text
	_toast.modulate = color
	var sz := root.size
	var w := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_toast.size = Vector2(w + 6, 16)
	_toast.position = Vector2(roundf((sz.x - w - 6) * 0.5), roundf(sz.y * 0.5) - 8)
	_toast.visible = true
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _toast.visible = false)


func show_hud_continue(score: int, best: int) -> void:
	show_hud(best, false)
	set_score(score)
