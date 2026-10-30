class_name Stages
## In-run world progression (free, unlocked by playing). Each stage changes the sky,
## the planet and the SHAPE of the orbit. Score thresholds trigger the change.

const LIST := [
	{"world": "sky", "score": 0, "orbits": [{"kind": "circle", "r": 60.0}]},
	{"world": "lagoon", "score": 15, "orbits": [{"kind": "circle", "r": 72.0}]},
	{"world": "sunset", "score": 35, "orbits": [{"kind": "circle", "r": 48.0}]},
	{"world": "candy", "score": 60, "orbits": [{"kind": "offset", "r": 60.0, "c": 17.0, "phi": PI * 0.5}]},
	{"world": "night", "score": 90, "orbits": [
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": 0.0},
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": PI * 0.5}]},
	# two planets: orbits touch between them; switching there jumps to the other planet (figure eight)
	{"world": "twin", "score": 125, "orbits": [
		{"kind": "circle", "r": 46.0, "center": Vector2(0, -40)},
		{"kind": "circle", "r": 46.0, "center": Vector2(0, 40)}]},
	{"world": "binary", "score": 165, "orbits": [
		{"kind": "circle", "r": 44.0, "center": Vector2(-15, -37)},
		{"kind": "ellipse", "a": 40.0, "b": 47.0, "rot": 0.0, "center": Vector2(14, 37)}]},
	# three planets
	{"world": "trio", "score": 210, "orbits": [
		{"kind": "circle", "r": 38.0, "center": Vector2(0, -44), "pr": 21.0},
		{"kind": "circle", "r": 38.0, "center": Vector2(-34, 22), "pr": 21.0},
		{"kind": "circle", "r": 38.0, "center": Vector2(34, 22), "pr": 21.0}]},
	# one big orbit and two small ones
	{"world": "giants", "score": 260, "orbits": [
		{"kind": "circle", "r": 52.0, "center": Vector2(0, -34), "pr": 21.0},
		{"kind": "circle", "r": 32.0, "center": Vector2(-34, 40), "pr": 15.0},
		{"kind": "circle", "r": 32.0, "center": Vector2(34, 40), "pr": 15.0}]},
	# lopsided orbits: wide on the side facing the next planet, tight on the other
	{"world": "warped", "score": 315, "orbits": [
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": 2.0465, "center": Vector2(0, -44), "pr": 15.0},
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": 0.0000, "center": Vector2(-34, 22), "pr": 15.0},
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": -2.0465, "center": Vector2(34, 22), "pr": 15.0}]},
	# four planets in a diamond: every orbit crosses its two neighbours
	{"world": "moons", "score": 375, "orbits": [
		{"kind": "circle", "r": 34.0, "center": Vector2(0, -46), "pr": 15.0},
		{"kind": "circle", "r": 34.0, "center": Vector2(40, 0), "pr": 15.0},
		{"kind": "circle", "r": 34.0, "center": Vector2(0, 46), "pr": 15.0},
		{"kind": "circle", "r": 34.0, "center": Vector2(-40, 0), "pr": 15.0}]},
	# a big planet and three moons whose small orbits cut through the big one
	{"world": "giant", "score": 440, "orbits": [
		{"kind": "circle", "r": 46.0, "center": Vector2(0, 6), "pr": 22.0},
		{"kind": "circle", "r": 23.0, "center": Vector2(0, -60), "pr": 13.0},
		{"kind": "circle", "r": 23.0, "center": Vector2(57, 39), "pr": 13.0},
		{"kind": "circle", "r": 23.0, "center": Vector2(-57, 39), "pr": 13.0}]},
	# three planets in a zigzag chain
	{"world": "chain", "score": 510, "orbits": [
		{"kind": "circle", "r": 36.0, "center": Vector2(-20, -48), "pr": 17.0},
		{"kind": "circle", "r": 36.0, "center": Vector2(20, 0), "pr": 17.0},
		{"kind": "circle", "r": 36.0, "center": Vector2(-20, 48), "pr": 17.0}]},
	# moving worlds (circles only): the geometry is a function of time, see Orbit.motion
	{"world": "dance", "score": 585, "motion": {"kind": "spin", "period": 16.0}, "orbits": [
		{"kind": "circle", "r": 42.0, "center": Vector2(0, -38), "pr": 22.0},
		{"kind": "circle", "r": 42.0, "center": Vector2(0, 38), "pr": 22.0}]},
	{"world": "pendulum", "score": 665, "motion": {"kind": "swing", "period": 5.0, "amp": 12.0}, "orbits": [
		{"kind": "circle", "r": 43.0, "center": Vector2(-37, 0), "pr": 22.0},
		{"kind": "circle", "r": 43.0, "center": Vector2(37, 0), "pr": 22.0}]},
	{"world": "pulsar", "score": 750, "motion": {"kind": "breathe", "period": 4.0, "amp": 7.0}, "orbits": [
		{"kind": "circle", "r": 46.0, "center": Vector2(0, -40)},
		{"kind": "circle", "r": 46.0, "center": Vector2(0, 40)}]},
]
const LOOP_FROM := 830   # after this score, stages 1.. repeat every LOOP_EVERY points
const LOOP_EVERY := 60


static func index_for_score(score: int) -> int:
	if score >= LOOP_FROM:
		return 1 + ((score - LOOP_FROM) / LOOP_EVERY) % (LIST.size() - 1)
	var idx := 0
	for i in LIST.size():
		if score >= int(LIST[i]["score"]):
			idx = i
	return idx


## Absolute "world number" shown to the player (keeps growing while looping).
static func number_for_score(score: int) -> int:
	if score >= LOOP_FROM:
		return LIST.size() + 1 + (score - LOOP_FROM) / LOOP_EVERY
	return index_for_score(score) + 1


static func world(i: int) -> Dictionary:
	return Catalog.WORLDS[Catalog.find("worlds", LIST[i]["world"])]


static func motion(i: int) -> Dictionary:
	return LIST[i].get("motion", {})


## Score range [start, next world) of the world the score is in (for the HUD progress bar).
static func bounds(score: int) -> Vector2i:
	if score >= LOOP_FROM:
		var lo := LOOP_FROM + ((score - LOOP_FROM) / LOOP_EVERY) * LOOP_EVERY
		return Vector2i(lo, lo + LOOP_EVERY)
	var lo := 0
	for e in LIST:
		var s := int(e["score"])
		if score < s:
			return Vector2i(lo, s)
		lo = s
	return Vector2i(lo, LOOP_FROM)
