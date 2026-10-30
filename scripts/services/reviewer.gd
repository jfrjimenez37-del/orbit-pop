class_name Reviewer
extends Node
## Google Play in-app review ("rate this game" sheet) through the "In-App Review" plugin by
## Cengiz (godot-mobile-plugins/godot-inapp-review). The plugin's `InappReview` node class is
## looked up dynamically, so the game builds and runs without it.
## We ask after the player has been around a while (some runs, on 2+ days, 20+ minutes) and
## only at a happy moment: a new record, a new world, a won duel or a daily challenge best.
## At most once a month and 3 times in total. Google decides whether the sheet really shows
## (it has its own quota), and Play policy forbids asking "do you like it?" first or
## rewarding a rating, so we just open the official sheet. SETTINGS > RATE is always there.

const MIN_GAMES := 8
const MIN_SCORE := 25           # a "record" below this is not a big moment yet
const MIN_DAYS := 2             # different days with at least one run
const MIN_MINUTES := 20         # total play time
const EVERY_DAYS := 30
const MAX_ASKS := 3
const STORE_PAGE := "market://details?id=com.barriogames.orbitpop"
const STORE_WEB := "https://play.google.com/store/apps/details?id=com.barriogames.orbitpop"

var _node: Node


static func plugin_script() -> Script:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "InappReview":
			return load(c["path"])
	return null


func start() -> void:
	var scr := plugin_script()
	Diag.log("review: plugin %s" % ("yes" if scr != null else "NO"))
	if scr == null or not OS.has_feature("android"):
		return
	_node = scr.new()
	add_child(_node)
	_node.connect("review_info_generated", func(): _node.call("launch_review_flow"))


## True when it is a good moment to ask (pure rule, also used by tests).
## ctx: games, days, minutes, happy (a good moment just happened), asks, last_day, today.
static func should_ask(ctx: Dictionary) -> bool:
	return bool(ctx["happy"]) and int(ctx["games"]) >= MIN_GAMES and int(ctx["days"]) >= MIN_DAYS \
		and float(ctx["minutes"]) >= MIN_MINUTES and int(ctx["asks"]) < MAX_ASKS \
		and int(ctx["today"]) - int(ctx["last_day"]) >= EVERY_DAYS


## A happy moment on this game over: a real record, a new world, a won duel, a daily best.
static func happy(record: bool, score: int, new_world: bool, duel_won: bool, daily_best: bool) -> bool:
	return (record and score >= MIN_SCORE) or new_world or duel_won or daily_best


## Call on game over with the Save autoload. Returns true if the review sheet was requested.
func maybe_ask(save: Node, is_happy: bool) -> bool:
	var ctx := {"happy": is_happy, "games": save.games, "days": int(save.stats.get("days_played", 0)),
		"minutes": float(save.stats.get("play_seconds", 0)) / 60.0, "asks": save.review_asks,
		"last_day": save.review_day, "today": save.day_number()}
	if not should_ask(ctx):
		return false
	save.review_asks += 1
	save.review_day = save.day_number()
	save.save_data()
	Diag.log("review: asking (%d of %d)" % [save.review_asks, MAX_ASKS])
	if _node != null:
		_node.call("generate_review_info")
	return true


## SETTINGS > RATE: the Play Store page (works on any device, with or without the plugin).
static func open_store_page() -> void:
	if OS.has_feature("android"):
		OS.shell_open(STORE_PAGE)
	else:
		OS.shell_open(STORE_WEB)
