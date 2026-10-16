extends Node
## Real ads through the official "godot-admob" Android plugin (godot-sdk-integrations/godot-admob).
## The plugin's `Admob` node class is looked up dynamically, so the game still compiles and runs
## when the plugin is not installed. Ad unit / app IDs are configured on the Admob node
## (see MonetizationConfig) — debug builds automatically use Google's demo units.

signal rewarded_done(granted: bool)
signal interstitial_done

var _admob: Node
var _rewarded_loaded := false
var _interstitial_loaded := false
var _earned := false
var _ready_init := false


static func plugin_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "Admob":
			return load(c["path"])
	return null


func start() -> void:
	var scr := plugin_script()
	if scr == null:
		return
	_admob = scr.new()
	_admob.set("is_real", not OS.is_debug_build())
	_admob.set("android_real_application_id", MonetizationConfig.ADMOB_APP_ID)
	_admob.set("android_real_interstitial_id", MonetizationConfig.ADMOB_INTERSTITIAL_ID)
	_admob.set("android_real_rewarded_id", MonetizationConfig.ADMOB_REWARDED_ID)
	add_child(_admob)
	_admob.connect("initialization_completed", func(_s): _on_init())
	_admob.connect("consent_info_updated", _on_consent_info)
	_admob.connect("consent_form_loaded", func(): _admob.call("show_consent_form"))
	_admob.connect("rewarded_ad_loaded", func(_a, _r): _rewarded_loaded = true)
	_admob.connect("rewarded_ad_failed_to_load", func(_a, _e): _retry_load("rewarded"))
	_admob.connect("rewarded_ad_user_earned_reward", func(_a, _r): _earned = true)
	_admob.connect("rewarded_ad_dismissed_full_screen_content", func(_a): _rewarded_closed())
	_admob.connect("rewarded_ad_failed_to_show_full_screen_content", func(_a, _e): _rewarded_closed())
	_admob.connect("interstitial_ad_loaded", func(_a, _r): _interstitial_loaded = true)
	_admob.connect("interstitial_ad_failed_to_load", func(_a, _e): _retry_load("interstitial"))
	_admob.connect("interstitial_ad_dismissed_full_screen_content", func(_a): _interstitial_closed())
	_admob.connect("interstitial_ad_failed_to_show_full_screen_content", func(_a, _e): _interstitial_closed())
	# GDPR / UMP consent first, then initialize the SDK.
	_admob.call("update_consent_info")


func _on_consent_info() -> void:
	var st = _admob.call("get_consent_status")
	# UserConsent.Status: 0 UNKNOWN, 1 NOT_REQUIRED, 2 REQUIRED, 3 OBTAINED
	if st != null and int(st.get("status")) == 2 and bool(_admob.call("is_consent_form_available")):
		_admob.call("load_consent_form")
	if not _ready_init:
		_ready_init = true
		_admob.call("initialize")


func _on_init() -> void:
	_admob.call("load_rewarded_ad")
	if not Save.owns("no_ads"):
		_admob.call("load_interstitial_ad")


func _retry_load(kind: String) -> void:
	await get_tree().create_timer(20.0).timeout
	if kind == "rewarded":
		_admob.call("load_rewarded_ad")
	elif not Save.owns("no_ads"):
		_admob.call("load_interstitial_ad")


func rewarded_ready() -> bool:
	return _admob != null and _rewarded_loaded


func interstitial_ready() -> bool:
	return _admob != null and _interstitial_loaded


func show_rewarded() -> void:
	_earned = false
	_rewarded_loaded = false
	_admob.call("show_rewarded_ad")


func show_interstitial() -> void:
	_interstitial_loaded = false
	_admob.call("show_interstitial_ad")


func _rewarded_closed() -> void:
	rewarded_done.emit(_earned)
	_admob.call("load_rewarded_ad")


func _interstitial_closed() -> void:
	interstitial_done.emit()
	if not Save.owns("no_ads"):
		_admob.call("load_interstitial_ad")
