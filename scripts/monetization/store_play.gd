extends Node
## Google Play Billing through the official plugin (godot-sdk-integrations/godot-google-play-billing,
## master branch for Godot 4.2+). `BillingClient` is looked up dynamically so the project compiles
## without the plugin. All products are one-time, non-consumable and get acknowledged.

signal prices_updated
signal purchase_done(product_id: String, ok: bool, message: String)
signal restored(owned: Array)

const OK_CODE := 0          # BillingResponseCode.OK
const CANCELED := 1         # BillingResponseCode.USER_CANCELED
const ALREADY_OWNED := 7    # BillingResponseCode.ITEM_ALREADY_OWNED
const INAPP := 0            # ProductType.INAPP
const PURCHASED := 1        # PurchaseState.PURCHASED
const PENDING := 2          # PurchaseState.PENDING

var _client: Object
var _ids: Array = []
var _prices := {}
var _connected := false
var _pending_buy := ""
var _consuming := {}   # purchase token -> product id


static func plugin_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "BillingClient":
			return load(c["path"])
	return null


func start(ids: Array) -> void:
	_ids = ids
	var scr := plugin_script()
	if scr == null:
		return
	_client = scr.new()
	_client.connect("connected", _on_connected)
	_client.connect("disconnected", func(): _connected = false)
	_client.connect("connect_error", func(_c, _m): _connected = false)
	_client.connect("query_product_details_response", _on_details)
	_client.connect("query_purchases_response", _on_purchases.bind(true))
	_client.connect("on_purchase_updated", _on_purchases.bind(false))
	_client.connect("acknowledge_purchase_response", func(_r): pass)
	_client.connect("consume_purchase_response", _on_consumed)
	_client.call("start_connection")


func available() -> bool:
	return _connected


func price(id: String) -> String:
	return _prices.get(id, MonetizationConfig.FALLBACK_PRICES.get(id, "?"))


func buy(id: String) -> void:
	if not _connected:
		purchase_done.emit(id, false, "STORE OFFLINE")
		return
	_pending_buy = id
	var res: Dictionary = _client.call("purchase", id)
	if int(res.get("response_code", -1)) != OK_CODE:
		_pending_buy = ""
		purchase_done.emit(id, false, "STORE ERROR")


func restore() -> void:
	if _connected:
		_client.call("query_purchases", INAPP)
	else:
		restored.emit([])


func _on_connected() -> void:
	_connected = true
	_client.call("query_product_details", PackedStringArray(_ids), INAPP)
	_client.call("query_purchases", INAPP)


func _on_details(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != OK_CODE:
		return
	for d in res.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if offers is Array and not offers.is_empty():
			_prices[d.get("product_id", "")] = str(offers[0].get("formatted_price", ""))
	prices_updated.emit()


func _on_purchases(res: Dictionary, is_restore: bool) -> void:
	var code := int(res.get("response_code", -1))
	if code != OK_CODE:
		if not is_restore and _pending_buy != "":
			var msg := "CANCELLED" if code == CANCELED else ("OWNED" if code == ALREADY_OWNED else "FAILED")
			purchase_done.emit(_pending_buy, code == ALREADY_OWNED, msg)
			if code == ALREADY_OWNED:
				restore()
		_pending_buy = ""
		return
	var owned: Array = []
	for p in res.get("purchases", []):
		var state := int(p.get("purchase_state", 0))
		var token := str(p.get("purchase_token", ""))
		var consumable := false
		for id in p.get("product_ids", []):
			if MonetizationConfig.CONSUMABLES.has(String(id)):
				consumable = true
				if state == PURCHASED and not _consuming.has(token):
					_consuming[token] = String(id)
					_client.call("consume_purchase", token)
				elif state == PENDING and not is_restore:
					purchase_done.emit(String(id), false, "PENDING")
				continue
			if state == PURCHASED:
				owned.append(String(id))
				if not is_restore:
					purchase_done.emit(String(id), true, "THANK YOU!")
			elif state == PENDING and not is_restore:
				purchase_done.emit(String(id), false, "PENDING")
		if state == PURCHASED and not consumable and not bool(p.get("is_acknowledged", false)):
			_client.call("acknowledge_purchase", p.get("purchase_token", ""))
	_pending_buy = ""
	if is_restore:
		restored.emit(owned)


## Consumables are granted only once Google confirms the consumption.
func _on_consumed(res: Dictionary) -> void:
	var token := str(res.get("token", ""))
	var id: String = _consuming.get(token, "")
	_consuming.erase(token)
	if id != "" and int(res.get("response_code", -1)) == OK_CODE:
		purchase_done.emit(id, true, "+%d COINS" % MonetizationConfig.CONSUMABLES[id])
