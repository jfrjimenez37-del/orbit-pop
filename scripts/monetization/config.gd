class_name MonetizationConfig
## Every business knob in one place. Product ids must match Google Play Console.

const PRODUCTS := ["no_ads", "star_pack", "supporter"]
const PRODUCT_INFO := {
	"no_ads": {"name": "NO ADS", "desc": "NO BREAKS"},
	"star_pack": {"name": "STAR PACK", "desc": "+3 SKINS"},
	"supporter": {"name": "SUPPORTER", "desc": "ALL ITEMS"},
}
## Shown until the store returns localized prices.
const FALLBACK_PRICES := {"no_ads": "$1.99", "star_pack": "$1.99", "supporter": "$2.99"}

## Interstitial pacing (only ever between runs, never during one).
const INTERSTITIAL_GRACE_GAMES := 5     # new players see no interstitials at first
const INTERSTITIAL_EVERY_RUNS := 3      # at most one every N finished runs
const INTERSTITIAL_COOLDOWN := 150.0    # seconds between any two ads
## Rewarded "continue": one per run, only when it is worth it.
const CONTINUE_MIN_SCORE := 5
const CONTINUE_SHIELD := 1.8            # seconds of invulnerability after reviving

## Fill these with the real ids from the AdMob console before the release build.
## Debug builds always use Google's demo ad units (configured inside the plugin).
const ADMOB_APP_ID := ""
const ADMOB_INTERSTITIAL_ID := ""
const ADMOB_REWARDED_ID := ""
