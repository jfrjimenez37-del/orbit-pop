class_name Notifier
extends Node
## Local reminders through the "Notification Scheduler" plugin by Cengiz
## (godot-mobile-plugins/godot-notification-scheduler); looked up dynamically, so the game
## builds and runs without it. At most one a day, never at night (REMIND_AT local time):
##   tomorrow  -> daily gift / missions / streak · 3 days -> we miss you · 7 days -> coins to spend
## Rescheduled every time the player leaves the game, so active players never get them.
## Permission is asked after the 3rd run, not on launch. Off in Settings.

const CHANNEL := "orbit_pop_reminders"
const IDS := [101, 102, 103]
const REMIND_AT := [18, 45]   # local hour, minute
const ASK_AFTER_GAMES := 3
const TEST_ID := 199

var _node: Node
var _ready_plugin := false


static func plugin_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "NotificationScheduler":
			return load(c["path"])
	return null


func start() -> void:
	var scr := plugin_script()
	Diag.log("notify: plugin %s" % ("yes" if scr != null else "NO"))
	if scr == null or not OS.has_feature("android"):
		return
	_node = scr.new()
	add_child(_node)
	_node.connect("initialization_completed", _on_init)
	_node.call("initialize")


func _on_init() -> void:
	var ch_scr := _class("NotificationChannel")
	if ch_scr != null:
		var ch = ch_scr.new()
		ch.set_id(CHANNEL).set_name("ORBIT POP").set_description("Daily gift and missions").set_importance(3)
		_node.call("create_notification_channel", ch)
	_ready_plugin = true
	Diag.log("notify: ready, permission %s" % str(_node.call("has_post_notifications_permission")))


static func _class(name: String) -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == name:
			return load(c["path"])
	return null


## After a few runs: ask Android for permission once (a good moment, not on launch).
func maybe_ask_permission(save: Node) -> void:
	if not _ready_plugin or save.notif_asked or save.games < ASK_AFTER_GAMES or not save.notifications:
		return
	save.notif_asked = true
	save.save_data()
	if not bool(_node.call("has_post_notifications_permission")):
		_node.call("request_post_notifications_permission")


## Seconds from `now` (unix, local time zone bias in s) to REMIND_AT, `days` days later.
static func delay_to(days: int, now: float, bias: int) -> int:
	var local := int(now) + bias
	var midnight := local - posmod(local, 86400)
	var target := midnight + days * 86400 + REMIND_AT[0] * 3600 + REMIND_AT[1] * 60
	return maxi(60, target - local)


## The reminders to schedule (pure, tested): [[id, delay s, title key, text], ...]
static func plan(save: Node, now: float, bias: int) -> Array:
	if not save.notifications:
		return []
	var l: Node = save.get_node("/root/L")   # translations (autoload)
	var out: Array = []
	var gift: String = l.t("NOTIF_STREAK", save.daily_day + 1) if save.daily_day >= 2 else l.t("NOTIF_GIFT")
	out.append([IDS[0], delay_to(1, now, bias), gift])
	out.append([IDS[1], delay_to(3, now, bias), l.t("NOTIF_MISS")])
	var cost := -1
	var name := ""
	for a in Upgrades.ABILITIES:
		var c := Upgrades.price(a["id"], save.ability(a["id"]))
		if save.ability_unlocked(a["id"]) and c > 0 and save.coins >= c and (cost < 0 or c < cost):
			cost = c
			name = l.t("AB_" + str(a["id"]).to_upper())
	out.append([IDS[2], delay_to(7, now, bias), l.t("NOTIF_COINS", name) if name != "" else l.t("NOTIF_WORLDS")])
	return out


## Diagnostics: one reminder in 10 seconds. Returns what happened (shown to the tester).
func test_now() -> String:
	if not _ready_plugin:
		return "NO PLUGIN"
	if not bool(_node.call("has_post_notifications_permission")):
		_node.call("request_post_notifications_permission")
		return "ASKING PERMISSION"
	var data_scr := _class("NotificationData")
	if data_scr == null:
		return "NO DATA CLASS"
	var d = data_scr.new()
	d.set_id(TEST_ID).set_channel_id(CHANNEL).set_title("ORBIT POP").set_content("Test reminder: it works!").set_delay(10)
	var err = _node.call("schedule", d)
	Diag.log("notify: test scheduled (err %s)" % str(err))
	return "IN 10 S" if int(err) == OK else "ERROR %s" % str(err)


## Call when the player leaves the game: cancel the old reminders, schedule new ones.
func reschedule(save: Node) -> void:
	if not _ready_plugin:
		return
	for id in IDS:
		_node.call("cancel", id)
	var data_scr := _class("NotificationData")
	if data_scr == null:
		return
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	for n in plan(save, Time.get_unix_time_from_system(), bias):
		var d = data_scr.new()
		d.set_id(n[0]).set_channel_id(CHANNEL).set_title("ORBIT POP").set_content(n[2]).set_delay(n[1])
		_node.call("schedule", d)
