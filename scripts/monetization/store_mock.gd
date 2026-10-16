extends Node
## Test store (PC and debug builds without the billing plugin): every purchase succeeds.
## Owned items live only in the save file, exactly like the real store mirror.

signal prices_updated
signal purchase_done(product_id: String, ok: bool, message: String)
signal restored(owned: Array)

var fail_next := false   # tests: simulate a cancelled / failed purchase


func start(_ids: Array) -> void:
	prices_updated.emit.call_deferred()


func available() -> bool:
	return true


func price(id: String) -> String:
	return MonetizationConfig.FALLBACK_PRICES.get(id, "?")


func buy(id: String) -> void:
	if fail_next:
		fail_next = false
		purchase_done.emit.call_deferred(id, false, "CANCELLED")
		return
	purchase_done.emit.call_deferred(id, true, "TEST PURCHASE")


func restore() -> void:
	restored.emit.call_deferred(Save.purchases.duplicate())
