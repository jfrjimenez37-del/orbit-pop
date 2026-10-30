class_name MonetizationConfig
## Every business knob in one place. Product ids must match Google Play Console.

const PRODUCTS := ["starter", "no_ads", "star_pack", "trail_pack", "supporter", "coins_x2",
	"coins_1500", "coins_5000", "coins_12000", "coins_30000"]
## Consumables: product id -> coins granted every purchase (bigger bags give more per dollar).
const CONSUMABLES := {"coins_1500": 1500, "coins_5000": 5000, "coins_12000": 12000, "coins_30000": 30000}
## What the SUPPORTER bundle includes (coins x2 is sold apart).
const SUPPORTER_INCLUDES := ["no_ads", "star_pack", "trail_pack"]
## name/desc are localization keys (see l10n.gd)
const PRODUCT_INFO := {
	"starter": {"name": "P_STARTER", "desc": "P_STARTER_D", "icon": "gift"},
	"no_ads": {"name": "P_NOADS", "desc": "P_NOADS_D", "icon": "noads"},
	"star_pack": {"name": "P_STAR", "desc": "P_STAR_D", "icon": "star"},
	"trail_pack": {"name": "P_TRAILS", "desc": "P_TRAILS_D", "icon": "trail"},
	"supporter": {"name": "P_SUPPORTER", "desc": "P_SUPPORTER_D", "icon": "crown"},
	"coins_x2": {"name": "P_X2", "desc": "P_X2_D", "icon": "coin"},
	"coins_1500": {"name": "P_COINS", "desc": "P_COINS_D", "icon": "coin"},
	"coins_5000": {"name": "P_COINS5", "desc": "P_COINS5_D", "icon": "coin"},
	"coins_12000": {"name": "P_COINS12", "desc": "P_COINS12_D", "icon": "coin"},
	"coins_30000": {"name": "P_COINS30", "desc": "P_COINS30_D", "icon": "coin"},
}
## Shown until the store returns localized prices.
const FALLBACK_PRICES := {"starter": "$1.99", "no_ads": "$2.99", "star_pack": "$1.99", "trail_pack": "$0.99",
	"supporter": "$3.99", "coins_x2": "$2.99", "coins_1500": "$0.99", "coins_5000": "$2.99", "coins_12000": "$4.99",
	"coins_30000": "$9.99"}
## Extra goodies granted once when a bundle is first bought.
const BUNDLE_BONUS := {"starter": {"coins": 1000}, "supporter": {"coins": 1500}}
## Starter offer pops up once after this many runs (then stays in the shop until bought).
const STARTER_AFTER_GAMES := 8

## Coins: earned every run, doubled with a rewarded ad.
const COINS_PER_SCORE := 1.0 / 10.0   # most coins now come from picking them up in the run
const COINS_PER_BUBBLE := 1
const FREE_COIN_ADS_PER_DAY := 3
const FREE_COIN_AD_REWARD := 60
## Daily gift streak (resets if a day is missed). Day 7 is the big one.
const DAILY_REWARDS := [
	{"coins": 30}, {"coins": 40}, {"coins": 70}, {"coins": 60},
	{"coins": 80}, {"coins": 140}, {"coins": 300},
]

## Interstitial pacing (only ever between runs, never during one).
const INTERSTITIAL_GRACE_GAMES := 3     # first interstitial after the 3rd run at the earliest
const INTERSTITIAL_EVERY_RUNS := 3      # and at least 3 retries since the last ad
const INTERSTITIAL_COOLDOWN := 150.0    # and at least 2.5 minutes since the last ad (any kind)
## Abilities: watch videos for a free level (levels 1 -> 2 and 2 -> 3 only, one level a day).
const VIDEO_UPGRADE_ADS := [0, 3, 5]    # videos needed to go from level i to i + 1
## Rewarded "continue": one per run, only when it is worth it.
const CONTINUE_MIN_SCORE := 5
const CONTINUE_SHIELD := 1.8            # seconds of invulnerability after reviving

## Fill these with the real ids from the AdMob console before the release build.
## Debug builds always use Google's demo ad units (configured inside the plugin).
const ADMOB_APP_ID := "ca-app-pub-3155364507895952~6157313760"
const ADMOB_INTERSTITIAL_ID := "ca-app-pub-3155364507895952/5388594360"
const ADMOB_REWARDED_ID := "ca-app-pub-3155364507895952/7575774000"
const ADMOB_BANNER_ID := "ca-app-pub-3155364507895952/3636528998"          # small banner on every menu screen (skins, abilities, shop, ranking, missions, settings, daily gift)
const BANNER_HEIGHT := 28            # logical px kept free at the bottom of those screens
