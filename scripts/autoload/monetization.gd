extends Node
## Monetization facade: rewarded "continue", paced interstitials and one-time purchases.
## Providers are swappable: real plugins on Android (AdMob / Google Play Billing) when they are
## installed, clearly-labelled test providers on PC and debug builds, nothing otherwise.
## Hard rule: no ad is ever shown while a run is active.

signal rewarded_finished(placement: String, granted: bool)
signal purchase_result(product_id: String, ok: bool, message: String)
signal store_changed

const AdsMock := preload("res://scripts/monetization/ads_mock.gd")
const AdsAdmob := preload("res://scripts/monetization/ads_admob.gd")
const StoreMock := preload("res://scripts/monetization/store_mock.gd")
const StorePlay := preload("res://scripts/monetization/store_play.gd")

var ads: Node        # null = ads disabled
var store: Node      # null = store unavailable
var run_active := false
var ads_mode := "none"
var store_mode := "none"
var clock := func() -> float: return Time.get_ticks_msec() / 1000.0

var _runs_since_ad := 0
var _last_ad_time := -1e9
var _placement := ""
var _after_interstitial: Callable


func _ready() -> void:
	var android := OS.has_feature("android")
	var force_mock := OS.get_cmdline_user_args().has("--mock-monetization")
	if android and AdsAdmob.plugin_script() != null and not force_mock:
		_set_ads(AdsAdmob.new(), "admob")
	elif OS.is_debug_build() or force_mock:
		_set_ads(AdsMock.new(), "test")
	if android and StorePlay.plugin_script() != null and not force_mock:
		_set_store(StorePlay.new(), "play")
	elif OS.is_debug_build() or force_mock:
		_set_store(StoreMock.new(), "test")


func _set_ads(node: Node, mode: String) -> void:
	if ads:
		ads.queue_free()
	ads = node
	ads_mode = mode
	add_child(ads)
	ads.rewarded_done.connect(_on_rewarded_done)
	ads.interstitial_done.connect(_on_interstitial_done)
	ads.start()


func _set_store(node: Node, mode: String) -> void:
	if store:
		store.queue_free()
	store = node
	store_mode = mode
	add_child(store)
	store.prices_updated.connect(func(): store_changed.emit())
	store.purchase_done.connect(_on_purchase_done)
	store.restored.connect(_on_restored)
	store.start(MonetizationConfig.PRODUCTS)


## For tests: plug instant test providers.
func use_test_providers() -> void:
	_set_ads(AdsMock.new(), "test")
	ads.instant = true
	_set_store(StoreMock.new(), "test")


# ------------------------------------------------------------------ ads

func ads_removed() -> bool:
	return Save.owns("no_ads")


func can_continue(score: int, already_used: bool) -> bool:
	return not run_active and not already_used and ads != null \
		and score >= MonetizationConfig.CONTINUE_MIN_SCORE and ads.rewarded_ready()


func show_rewarded(placement: String) -> bool:
	if run_active or ads == null or not ads.rewarded_ready() or _placement != "":
		return false
	_placement = placement
	ads.show_rewarded()
	return true


func _on_rewarded_done(granted: bool) -> void:
	var p := _placement
	_placement = ""
	# a watched rewarded ad counts as the player's ad break
	_runs_since_ad = 0
	_last_ad_time = clock.call()
	rewarded_finished.emit(p, granted)


## Called once per finished run (game over).
func on_game_over() -> void:
	_runs_since_ad += 1


func should_show_interstitial() -> bool:
	return not run_active and ads != null and not ads_removed() \
		and Save.games >= MonetizationConfig.INTERSTITIAL_GRACE_GAMES \
		and _runs_since_ad >= MonetizationConfig.INTERSTITIAL_EVERY_RUNS \
		and clock.call() - _last_ad_time >= MonetizationConfig.INTERSTITIAL_COOLDOWN \
		and ads.interstitial_ready()


## Use between runs (retry / menu). Runs `then` right away, or after a paced interstitial.
func between_runs(then: Callable) -> void:
	if should_show_interstitial():
		_after_interstitial = then
		_runs_since_ad = 0
		_last_ad_time = clock.call()
		ads.show_interstitial()
	else:
		then.call()


func _on_interstitial_done() -> void:
	var cb := _after_interstitial
	_after_interstitial = Callable()
	if cb.is_valid():
		cb.call()


# ------------------------------------------------------------------ store

func store_available() -> bool:
	return store != null and store.available()


func price(id: String) -> String:
	return store.price(id) if store else MonetizationConfig.FALLBACK_PRICES.get(id, "?")


func buy(id: String) -> void:
	if Save.owns(id):
		purchase_result.emit(id, true, "OWNED")
		return
	if not store_available():
		purchase_result.emit(id, false, "STORE OFFLINE")
		return
	store.buy(id)


func restore() -> void:
	if store_available():
		store.restore()


func _on_purchase_done(id: String, ok: bool, message: String) -> void:
	if ok:
		Save.grant(id)
	purchase_result.emit(id, ok, message)
	store_changed.emit()


func _on_restored(owned: Array) -> void:
	for id in owned:
		Save.grant(id)
	purchase_result.emit("restore", true, "RESTORED")
	store_changed.emit()
