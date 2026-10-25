class_name Reviewer
extends Node
## Google Play in-app review ("rate this game" sheet) through the "In-App Review" plugin by
## Cengiz (godot-mobile-plugins/godot-inapp-review). The plugin's `InappReview` node class is
## looked up dynamically, so the game builds and runs without it.
## We only ask after a good moment (a new record), never in the first runs, at most once a
## month and a few times in total. Google decides whether the sheet really shows.

const MIN_GAMES := 8
const MIN_SCORE := 25
const EVERY_DAYS := 30
const MAX_ASKS := 3

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
static func should_ask(games: int, record: bool, score: int, asks: int, last_day: int, today: int) -> bool:
	return record and score >= MIN_SCORE and games >= MIN_GAMES and asks < MAX_ASKS and today - last_day >= EVERY_DAYS


## Call on game over with the Save autoload. Returns true if the review sheet was requested.
func maybe_ask(save: Node, record: bool, score: int) -> bool:
	if not should_ask(save.games, record, score, save.review_asks, save.review_day, save.day_number()):
		return false
	save.review_asks += 1
	save.review_day = save.day_number()
	save.save_data()
	if _node != null:
		_node.call("generate_review_info")
	return true
