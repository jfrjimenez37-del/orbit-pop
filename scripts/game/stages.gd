class_name Stages
## In-run world progression (free, unlocked by playing). Each stage changes the sky,
## the planet and the SHAPE of the orbit. Score thresholds trigger the change.

const LIST := [
	{"world": "sky", "score": 0, "orbits": [{"kind": "circle", "r": 60.0}]},
	{"world": "lagoon", "score": 20, "orbits": [{"kind": "circle", "r": 72.0}]},
	{"world": "sunset", "score": 45, "orbits": [{"kind": "circle", "r": 48.0}]},
	{"world": "candy", "score": 75, "orbits": [{"kind": "offset", "r": 60.0, "c": 17.0, "phi": PI * 0.5}]},
	{"world": "night", "score": 110, "orbits": [
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": 0.0},
		{"kind": "ellipse", "a": 72.0, "b": 46.0, "rot": PI * 0.5}]},
	# two planets: orbits touch between them; switching there jumps to the other planet (figure eight)
	{"world": "twin", "score": 150, "orbits": [
		{"kind": "circle", "r": 46.0, "center": Vector2(0, -40)},
		{"kind": "circle", "r": 46.0, "center": Vector2(0, 40)}]},
	{"world": "binary", "score": 195, "orbits": [
		{"kind": "circle", "r": 44.0, "center": Vector2(-15, -37)},
		{"kind": "ellipse", "a": 40.0, "b": 47.0, "rot": 0.0, "center": Vector2(14, 37)}]},
]
const LOOP_FROM := 240   # after this score, stages 1..6 repeat every LOOP_EVERY points
const LOOP_EVERY := 40


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
