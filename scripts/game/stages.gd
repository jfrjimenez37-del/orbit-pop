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

## Altitude layers (sky -> space): from this score, text key. They start with a world.
const LAYERS := [[0, "ALT_SKY"], [90, "ALT_HIGH"], [125, "ALT_STRATO"], [210, "ALT_MESO"], [315, "ALT_EDGE"],
	[375, "ALT_LOW_ORBIT"], [510, "ALT_HIGH_ORBIT"], [585, "ALT_MOON"], [750, "ALT_DEEP"], [830, "ALT_STELLAR"]]
## Altitude in km at these scores (log-interpolated between them, a bit like the real thing:
## clouds, ozone, the Karman line at 100 km, the space station, geostationary, the Moon).
const ALT_KM := [[0, 0.0], [35, 2.0], [90, 12.0], [125, 25.0], [210, 60.0], [315, 100.0], [375, 400.0],
	[510, 36000.0], [585, 384000.0], [750, 1500000.0]]
const ALT_GROWTH := 1.25  # x per LOOP_EVERY points after the last anchor


## Short altitude for the HUD (it sits next to the score): 7.4 KM, 230 KM, 22,400 KM, 384K KM, 1.5M KM, 2.3B KM.
static func altitude_text(km: float, miles: bool, unit: String) -> String:
	var v := km * 0.621 if miles else km
	var n: String
	if v < 10.0:
		n = "%.1f" % v
	elif v < 1000.0:
		n = str(int(v))
	elif v < 100000.0:
		var i := int(v)
		n = "%d,%03d" % [i / 1000, i % 1000]
	elif v < 1000000.0:
		n = "%dK" % int(v / 1000.0)
	elif v < 1000000000.0:
		n = "%.1fM" % (v / 1000000.0) if v < 100000000.0 else "%dM" % int(v / 1000000.0)
	else:
		n = "%.1fB" % minf(v / 1000000000.0, 99.9) if v < 100000000000.0 else "%dB" % mini(int(v / 1000000000.0), 999)
	return "%s %s" % [n, unit]


static func layer(score: int) -> int:
	var idx := 0
	for i in LAYERS.size():
		if score >= int(LAYERS[i][0]):
			idx = i
	return idx


static func altitude_km(score: float) -> float:
	var last: Array = ALT_KM[-1]
	if score >= float(last[0]):
		return float(last[1]) * pow(ALT_GROWTH, (score - float(last[0])) / LOOP_EVERY)
	for i in range(1, ALT_KM.size()):
		var a: Array = ALT_KM[i - 1]
		var b: Array = ALT_KM[i]
		if score < float(b[0]):
			var k := (score - float(a[0])) / (float(b[0]) - float(a[0]))
			return exp(lerpf(log(1.0 + float(a[1])), log(1.0 + float(b[1])), k)) - 1.0
	return 0.0


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
