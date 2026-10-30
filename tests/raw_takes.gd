extends SceneTree
## Raw gameplay takes for editors: one continuous run, no captions, no cuts, game audio.
##   (same override.cfg trick as promo_videos.gd for 1080x1920)
##   godot47 --path . --write-movie /tmp/t.avi --fixed-fps 30 --script tests/raw_takes.gd -- jump 7
## Takes: dodge (one planet, taps to dodge), jump (two planets, jumps at the crossings),
## moving (planets in motion). Prints DIED if the bot was hit (then try another seed).

const FPS := 30.0
const TAKES := {
	# world index, seconds, difficulty offset, jump between planets, seconds between jumps
	"dodge": [3, 25.0, 26.0, false, 0.0],
	"jump": [5, 25.0, 6.0, true, 1.2],
	"moving": [13, 28.0, 14.0, true, 1.0],
}
var main: Node
var frame := 0
var take := "jump"
var cfg: Array
var _last_jump := -9.0
var jumps := 0
var dodges := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	take = args[0] if args.size() > 0 else "jump"
	cfg = TAKES[take]
	get_root().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	await process_frame
	var sv = get_root().get_node("Save")
	sv.path = "user://raw_%s.cfg" % take
	sv.reset_all()
	sv.best = 412; sv.games = 60; sv.coins = 2350; sv.level = 18; sv.sessions = 9
	sv.daily_last = sv._day_string()
	sv.starter_seen = true
	sv.skin = Catalog.find("skins", "cosmo")
	sv.trail = "galaxy"
	for a in get_root().get_node("Progress").ACHIEVEMENTS:
		sv.achievements.append(a["id"])
	get_root().get_node("L").set_lang("en")
	seed(int(args[1]) if args.size() > 1 else 7)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)


func _begin() -> void:
	main.ui.hide_popup()
	main.start_run()
	main.ui.hide_hint()
	var si: int = cfg[0]
	main._clear_field()
	main.stage = si
	main.world_no = Stages.number_for_score(int(Stages.LIST[si]["score"]))
	main.score = int(Stages.LIST[si]["score"]) + 2
	Orbit.set_shape(Stages.LIST[si]["orbits"], true, Stages.motion(si))
	main._apply_world(si, false)
	main._layer = Stages.layer(main.score)
	main.director.stage = si
	main.director.offset = float(cfg[2])
	main.ui.set_score(main.score)
	main.ui.set_altitude(main.score)


func _bot(t: float) -> void:
	var p = main.player
	if TestBot.decide(main):
		main._flip()
		dodges += 1
		return
	if not cfg[3] or t - _last_jump < float(cfg[4]) or Orbit.count() < 2:
		return
	if Orbit.crossing_at(p.angle, p.orbit) < 0:
		return
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	if r[0] == p.orbit:
		return
	var rate: float = main.director.omega_rate(main.gt)
	if Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate):
		main._flip()
		_last_jump = t
		jumps += 1


func _process(_dt: float) -> bool:
	if main == null:
		return false
	frame += 1
	var t := frame / FPS
	if frame == 2:
		_begin()
	if frame < 2:
		return false
	main.ui._toast.visible = false
	main.ui._banner.visible = false
	if main.state == main.S.PLAYING:
		main._grace = 0.0
		if frame % 2 == 0:
			_bot(t)
	elif main.state in [main.S.DYING, main.S.OVER]:
		print("DIED at %.1f s" % t)
		return true
	if t >= float(cfg[1]):
		print("TAKE %s ok: %.0f s, %d dodge taps, %d planet jumps, score %d" % [take, t, dodges, jumps, main.score])
		return true
	return false
