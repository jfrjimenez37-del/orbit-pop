class_name Orbit
## Orbit geometry shared by gameplay, hazards, fairness checker and drawing.
## An orbit is a star-shaped closed curve around the planet: radius(k, angle).
## There can be 1 or 2 orbits; where 2 orbits cross, a tap switches orbit
## instead of reversing. The player always moves at the same angular speed.
## Shapes morph smoothly when the world changes (blend 0 -> 1).

const PLANET_R := 29.0     # planet visual radius
const PLAYER_R := 4.0      # player hitbox radius (forgiving: sprite body is ~6px)
const NEAR := 0.13         # rad of clearance that still counts as a near miss
const CROSS_WINDOW := 0.16 # rad around a crossing where a tap switches orbit
const BASE := [{"kind": "circle", "r": 60.0}]

## Legacy mean radius (visual helpers). Kept in sync with the current shape.
static var R := 60.0
static var defs: Array = BASE.duplicate(true)
static var prev_defs: Array = BASE.duplicate(true)
static var blend := 1.0
static var crossings: Array = []   # angles where orbit 0 and 1 meet


static func reset() -> void:
	set_shape(BASE, true)


## Starts (or instantly applies) a new shape.
static func set_shape(new_defs: Array, instant := false) -> void:
	prev_defs = defs.duplicate(true) if not instant else new_defs.duplicate(true)
	defs = new_defs.duplicate(true)
	blend = 1.0 if instant else 0.0
	_refresh()


static func set_blend(b: float) -> void:
	blend = clampf(b, 0.0, 1.0)
	if blend >= 1.0:
		prev_defs = defs.duplicate(true)
	_refresh()


static func morphing() -> bool:
	return blend < 1.0


static func count() -> int:
	return defs.size() if blend >= 1.0 else maxi(defs.size(), prev_defs.size())


static func _eval(d: Dictionary, a: float) -> float:
	match d["kind"]:
		"offset":
			# circle of radius r whose center sits c px away from the planet, toward phi
			var x := a - float(d["phi"])
			var c: float = d["c"]
			var rr: float = d["r"]
			return c * cos(x) + sqrt(maxf(0.0, rr * rr - c * c * sin(x) * sin(x)))
		"ellipse":
			var x2 := a - float(d.get("rot", 0.0))
			var ea: float = d["a"]
			var eb: float = d["b"]
			return ea * eb / sqrt(pow(eb * cos(x2), 2.0) + pow(ea * sin(x2), 2.0))
	return float(d["r"])


static func radius(k: int, a: float) -> float:
	var new_r := _eval(defs[mini(k, defs.size() - 1)], a)
	if blend >= 1.0:
		return new_r
	var old_r := _eval(prev_defs[mini(k, prev_defs.size() - 1)], a)
	return lerpf(old_r, new_r, blend)


static func pos(k: int, a: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * radius(k, a)


static func on_ring(a: float, r := -1.0) -> Vector2:
	return Vector2(cos(a), sin(a)) * (radius(0, a) if r < 0.0 else r)


static func max_radius() -> float:
	var m := 0.0
	for k in count():
		for i in 32:
			m = maxf(m, radius(k, TAU * i / 32.0))
	return m


static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


## Half-angle (rad) covered by a circle of radius `rr` sitting on an orbit of radius `r`.
static func chord_half(rr: float, r := -1.0) -> float:
	var rad := R if r < 0.0 else r
	return 2.0 * asin(clampf(rr / (2.0 * rad), 0.0, 1.0))


## True when a tap at this angle switches orbit (two orbits, close to a crossing).
static func at_crossing(a: float) -> bool:
	if count() < 2 or morphing():
		return false
	for c in crossings:
		if absf(ang_diff(a, c)) <= CROSS_WINDOW:
			return true
	return false


## Result of a tap: [orbit, dir].
static func tap_result(a: float, k: int, dir: int) -> Array:
	if at_crossing(a):
		return [1 - k, dir]
	return [k, -dir]


static func _refresh() -> void:
	var s := 0.0
	for i in 16:
		s += radius(0, TAU * i / 16.0)
	R = s / 16.0
	crossings.clear()
	if defs.size() < 2:
		return
	# sample between grid points (never exactly on a crossing), then refine by bisection
	var n := 256
	var a0 := TAU * 0.5 / n
	var prev := _eval(defs[0], a0) - _eval(defs[1], a0)
	for i in range(1, n + 1):
		var a1 := TAU * (i + 0.5) / n
		var d := _eval(defs[0], a1) - _eval(defs[1], a1)
		if (d > 0.0) != (prev > 0.0):
			var lo := a1 - TAU / n
			var hi := a1
			for it in 20:
				var m := (lo + hi) * 0.5
				var dm := _eval(defs[0], m) - _eval(defs[1], m)
				if (dm > 0.0) == (prev > 0.0):
					lo = m
				else:
					hi = m
			crossings.append(wrapf((lo + hi) * 0.5, -PI, PI))
		prev = d
