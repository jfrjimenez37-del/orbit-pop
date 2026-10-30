class_name Offers
## Offers at the right moment, never spammy. Decided on game over:
##   after a forced ad -> NO ADS · just short of the record -> STARTER (or a coin bag)
##   a few coins short of an upgrade -> 1500 coins · run milestones -> rotating packs
## Never in the first runs, never after a record (that is the time to celebrate / ask for a
## rating), at most one per session and the same offer not again for 3 days.
## Each offer carries real BONUS coins for a limited time (the countdown is honest: when it ends,
## the bonus is gone; the price never changes). It stays in the shop until then.

const MIN_GAMES := 5
const COOLDOWN_DAYS := 3
const MILESTONES := {25: "star_pack", 60: "trail_pack", 120: "supporter"}
const SHORT_COINS := 200   # "you're this close to an upgrade"
const BONUS := {"no_ads": 500, "starter": 500, "star_pack": 500, "trail_pack": 500, "supporter": 1000,
	"coins_x2": 500, "coins_1500": 750, "coins_5000": 1500}
const HOURS := 24
const MILESTONE_HOURS := 48


## What to remember of a shown offer: {id, until (unix s), bonus}.
static func make_live(o: Dictionary, now: float) -> Dictionary:
	var h := MILESTONE_HOURS if o.get("why", "") == "OFFER_MILESTONE" else HOURS
	return {"id": o["id"], "until": int(now) + h * 3600, "bonus": int(BONUS.get(o["id"], 0))}


## Seconds left on `id`'s bonus (0 = no live bonus for it).
static func seconds_left(live: Dictionary, id: String, now: float) -> int:
	if live.get("id", "") != id or int(live.get("bonus", 0)) <= 0:
		return 0
	return maxi(0, int(live.get("until", 0)) - int(now))


## 23:59:12 (popup) or 23H / 42M (shop row).
static func clock(secs: int, short := false) -> String:
	if short:
		return "%dH" % ceili(secs / 3600.0) if secs >= 3600 else "%dM" % maxi(1, ceili(secs / 60.0))
	return "%d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]


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
