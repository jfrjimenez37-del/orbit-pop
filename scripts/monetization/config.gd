class_name MonetizationConfig
## Every business knob in one place. Product ids must match Google Play Console.

const PRODUCTS := ["starter", "no_ads", "star_pack", "trail_pack", "supporter", "coins_1500"]
## Consumables: product id -> coins granted every purchase.
const CONSUMABLES := {"coins_1500": 1500}
## name/desc are localization keys (see l10n.gd)
const PRODUCT_INFO := {
	"starter": {"name": "P_STARTER", "desc": "P_STARTER_D", "icon": "gift"},
	"no_ads": {"name": "P_NOADS", "desc": "P_NOADS_D", "icon": "noads"},
	"star_pack": {"name": "P_STAR", "desc": "P_STAR_D", "icon": "star"},
	"trail_pack": {"name": "P_TRAILS", "desc": "P_TRAILS_D", "icon": "trail"},
	"supporter": {"name": "P_SUPPORTER", "desc": "P_SUPPORTER_D", "icon": "crown"},
	"coins_1500": {"name": "P_COINS", "desc": "P_COINS_D", "icon": "coin"},
}
## Shown until the store returns localized prices.
const FALLBACK_PRICES := {"starter": "$1.99", "no_ads": "$2.99", "star_pack": "$1.99", "trail_pack": "$0.99",
	"supporter": "$3.99", "coins_1500": "$0.99"}
## Extra goodies granted once when a bundle is first bought.
const BUNDLE_BONUS := {"starter": {"coins": 500, "boosts": {"shield": 2}}, "supporter": {"coins": 1000}}
## Starter offer pops up once after this many runs (then stays in the shop until bought).
const STARTER_AFTER_GAMES := 8

## Coins: earned every run, doubled with a rewarded ad.
const COINS_PER_SCORE := 1.0 / 3.0
const COINS_PER_BUBBLE := 1
const FREE_COIN_ADS_PER_DAY := 3
const FREE_COIN_AD_REWARD := 60
## Daily gift streak (resets if a day is missed). Day 7 is the big one.
const DAILY_REWARDS := [
	{"coins": 30}, {"coins": 40}, {"coins": 50, "boost": "rush"}, {"coins": 60},
	{"coins": 80}, {"coins": 100, "boost": "shield"}, {"coins": 250, "boost": "shield"},
]
## Boosts: bought with coins, max one of each per run.
const BOOSTS := {
	"shield": {"name": "B_SHIELD", "desc": "B_SHIELD_D", "price": 150, "icon": "shield"},
	"rush": {"name": "B_RUSH", "desc": "B_RUSH_D", "price": 100, "icon": "rush"},
	"teleport": {"name": "B_TELEPORT", "desc": "B_TELEPORT_D", "price": 120, "icon": "teleport"},
}

## Interstitial pacing (only ever between runs, never during one).
const INTERSTITIAL_GRACE_GAMES := 3     # first interstitial after the 3rd run at the earliest
const INTERSTITIAL_EVERY_RUNS := 3      # mandatory interstitial every 3 retries
const INTERSTITIAL_COOLDOWN := 0.0      # extra minimum seconds between two ads (0 = off)
## Rewarded "continue": one per run, only when it is worth it.
const CONTINUE_MIN_SCORE := 5
const CONTINUE_SHIELD := 1.8            # seconds of invulnerability after reviving

## Fill these with the real ids from the AdMob console before the release build.
## Debug builds always use Google's demo ad units (configured inside the plugin).
const ADMOB_APP_ID := ""
const ADMOB_INTERSTITIAL_ID := ""
const ADMOB_REWARDED_ID := ""
const ADMOB_BANNER_ID := ""          # small banner on the shop and ranking/achievements screens
const BANNER_HEIGHT := 28            # logical px kept free at the bottom of those screens
