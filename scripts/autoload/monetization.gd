extends Node
## Monetization seam. Phase 1 ships with NO ad / billing SDK: every call is a no-op.
## Later, plug an AdMob / Play Billing Android plugin in here without touching gameplay.
## Rule: never call anything here while a run is active (only from menus / game over).

signal rewarded_finished(placement: String, granted: bool)

var ads_removed := false


## Called by the game over screen. Hook point for an occasional interstitial.
func on_game_over(_games_played: int) -> void:
	pass


func rewarded_available(_placement: String) -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit(placement, false)


func purchase_remove_ads() -> void:
	pass
