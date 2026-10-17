class_name Stages
## In-run world progression (free, unlocked by playing). Each stage changes the sky,
## the planet and the SHAPE of the orbit. Score thresholds trigger the change.

const LIST := [
	{"world": "sky", "score": 0, "orbits": [{"kind": "circle", "r": 60.0}]},
	{"world": "lagoon", "score": 30, "orbits": [{"kind": "circle", "r": 72.0}]},
	{"world": "sunset", "score": 65, "orbits": [{"kind": "circle", "r": 48.0}]},
	{"world": "candy", "score": 105, "orbits": [{"kind": "offset", "r": 60.0, "c": 17.0, "phi": PI * 0.5}]},
	{"world": "night", "score": 150, "orbits": [
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": 0.0},
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": PI * 0.5}]},
	# two planets: orbits touch between them; switching there jumps to the other planet (figure eight)
	{"world": "twin", "score": 200, "orbits": [
		{"kind": "circle", "r": 46.0, "center": Vector2(0, -40)},
		{"kind": "circle", "r": 46.0, "center": Vector2(0, 40)}]},
	{"world": "binary", "score": 255, "orbits": [
		{"kind": "circle", "r": 44.0, "center": Vector2(-15, -37)},
		{"kind": "ellipse", "a": 40.0, "b": 47.0, "rot": 0.0, "center": Vector2(14, 37)}]},
	# three planets
	{"world": "trio", "score": 315, "orbits": [
		{"kind": "circle", "r": 38.0, "center": Vector2(0, -44), "pr": 21.0},
		{"kind": "circle", "r": 38.0, "center": Vector2(-34, 22), "pr": 21.0},
		{"kind": "circle", "r": 38.0, "center": Vector2(34, 22), "pr": 21.0}]},
	# one big orbit and two small ones
	{"world": "giants", "score": 380, "orbits": [
		{"kind": "circle", "r": 52.0, "center": Vector2(0, -34), "pr": 21.0},
		{"kind": "circle", "r": 32.0, "center": Vector2(-34, 40), "pr": 15.0},
		{"kind": "circle", "r": 32.0, "center": Vector2(34, 40), "pr": 15.0}]},
	# lopsided orbits: wide on the side facing the next planet, tight on the other
	{"world": "warped", "score": 450, "orbits": [
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": 2.0465, "center": Vector2(0, -44), "pr": 15.0},
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": 0.0000, "center": Vector2(-34, 22), "pr": 15.0},
		{"kind": "offset", "r": 36.0, "c": 8.0, "phi": -2.0465, "center": Vector2(34, 22), "pr": 15.0}]},
]
const LOOP_FROM := 520   # after this score, stages 1..9 repeat every LOOP_EVERY points
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
