extends CanvasLayer
## Test ad provider (PC and debug builds without the AdMob plugin).
## Shows a clearly labelled fake full-screen ad so the whole flow can be tested.

signal rewarded_done(granted: bool)
signal interstitial_done

const FONT := preload("res://assets/font/pixel.fnt")
const REWARDED_TIME := 3.0
const INTERSTITIAL_TIME := 1.5

var instant := false   # tests: resolve immediately without UI
var fill_rate := 1.0   # tests: probability an ad is "loaded"

var _box: Control
var _title: Label
var _timer_lbl: Label
var _close: Button
var _kind := ""
var _left := 0.0


func start() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_box = Control.new()
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.visible = false
	var th := Theme.new()
	th.default_font = FONT
	th.default_font_size = 8
	_box.theme = th
	add_child(_box)
	var bg := ColorRect.new()
	bg.color = Color8(24, 18, 44)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.add_child(bg)
	_title = Label.new()
	_title.scale = Vector2(2, 2)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.position = Vector2(-60, -40)
	_box.add_child(_title)
	_timer_lbl = Label.new()
	_timer_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_timer_lbl.position = Vector2(-40, 0)
	_box.add_child(_timer_lbl)
	_close = Button.new()
	_close.text = " X CLOSE "
	_close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_close.position = Vector2(-60, 6)
	_close.pressed.connect(_finish)
	_box.add_child(_close)


func rewarded_ready() -> bool:
	return fill_rate >= 1.0 or randf() < fill_rate


func interstitial_ready() -> bool:
	return rewarded_ready()


func show_rewarded() -> void:
	_open("rewarded", REWARDED_TIME)


func show_interstitial() -> void:
	_open("interstitial", INTERSTITIAL_TIME)


func _open(kind: String, time: float) -> void:
	_kind = kind
	_left = time
	if instant:
		_left = 0.0
		_finish()
		return
	_title.text = "TEST AD"
	_box.visible = true
	_refresh()


func _process(delta: float) -> void:
	if _box == null or not _box.visible:
		return
	_left -= delta
	_refresh()


func _refresh() -> void:
	if _kind == "rewarded":
		_timer_lbl.text = "REWARD IN %d" % ceili(maxf(_left, 0.0)) if _left > 0.0 else "REWARD READY!"
		_close.text = " X SKIP " if _left > 0.0 else " X CLOSE "
		_close.disabled = false
	else:
		_timer_lbl.text = "INTERSTITIAL %d" % ceili(maxf(_left, 0.0)) if _left > 0.0 else "INTERSTITIAL"
		_close.disabled = _left > 0.0


func _finish() -> void:
	if _box:
		_box.visible = false
	if _kind == "rewarded":
		rewarded_done.emit(_left <= 0.0)
	else:
		interstitial_done.emit()
	_kind = ""
