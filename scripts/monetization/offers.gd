class_name Offers
## Offers at the right moment, never spammy. Decided on game over:
##   after a forced ad -> NO ADS · just short of the record -> STARTER (or a coin bag)
##   a few coins short of an upgrade -> 1500 coins · run milestones -> rotating packs
## Never in the first runs, never after a record (that is the time to celebrate / ask for a
## rating), at most one per session and the same offer not again for 3 days.

const MIN_GAMES := 5
const COOLDOWN_DAYS := 3
const MILESTONES := {25: "star_pack", 60: "trail_pack", 120: "supporter"}
const SHORT_COINS := 200   # "you're this close to an upgrade"


## The offer to show now (product id + reason text key), or {} for none.
## ctx: games, score, best, record, coins, upgrade_cost (-1 none), ad_shown (a forced ad since
## the last offer), session_shown (an offer already this session), today, owned (Callable id -> bool),
## last_shown (Dictionary id -> day).
static func pick(ctx: Dictionary) -> Dictionary:
	if int(ctx["games"]) < MIN_GAMES or bool(ctx["record"]) or bool(ctx["session_shown"]):
		return {}
	var owned: Callable = ctx["owned"]
	var fresh := func(id: String) -> bool:
		return not owned.call(id) and int(ctx["today"]) - int(ctx["last_shown"].get(id, -999)) >= COOLDOWN_DAYS
	if bool(ctx["ad_shown"]) and fresh.call("no_ads"):
		return {"id": "no_ads", "why": "OFFER_ADS"}
	var best := int(ctx["best"])
	var gap := best - int(ctx["score"])
	if best >= 20 and gap >= 1 and gap <= 3:
		if fresh.call("starter"):
			return {"id": "starter", "why": "OFFER_CLOSE"}
		if fresh.call("coins_5000"):
			return {"id": "coins_5000", "why": "OFFER_CLOSE"}
	var cost := int(ctx["upgrade_cost"])
	var short := cost - int(ctx["coins"])
	if cost > 0 and short > 0 and short <= SHORT_COINS and fresh.call("coins_1500"):
		return {"id": "coins_1500", "why": "OFFER_UPGRADE"}
	for m in MILESTONES:
		if int(ctx["games"]) >= int(m) and int(ctx["games"]) < int(m) + 10 and fresh.call(MILESTONES[m]):
			return {"id": MILESTONES[m], "why": "OFFER_MILESTONE"}
	return {}
