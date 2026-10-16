class_name Orbit
## Orbit geometry shared by gameplay, hazards, fairness checker and drawing.
## Each orbit k is a star-shaped closed curve around its own center (a planet):
##   pos(k, a) = center(k) + dir(a) * radius(k, a)      (a = angle around that center)
## There can be 1 or 2 orbits. Where 2 orbits cross, a tap switches orbit instead of
## reversing; when the orbits belong to different planets the angle and direction are
## remapped so the motion continues smoothly (figure-eight). The player always moves at
## the same angular speed. Shapes morph smoothly when the world changes (blend 0 -> 1).

const PLANET_R := 29.0     # planet visual radius
const PLAYER_R := 4.0      # player hitbox radius (forgiving: sprite body is ~6px)
const NEAR := 0.13         # rad of clearance that still counts as a near miss
const CROSS_WINDOW := 0.16 # rad around a crossing where a tap switches orbit
const BASE := [{"kind": "circle", "r": 60.0}]

## Mean radius of orbit 0 (visual helpers). Kept in sync with the current shape.
static var R := 60.0
static var defs: Array = BASE.duplicate(true)
static var prev_defs: Array = BASE.duplicate(true)
static var blend := 1.0
## Each crossing: {"a": [angle on orbit 0, angle on orbit 1], "sign": dir multiplier when switching}
static var crossings: Array = []


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


static func _def(list: Array, k: int) -> Dictionary:
	return list[mini(k, list.size() - 1)]


static func radius(k: int, a: float) -> float:
	var new_r := _eval(_def(defs, k), a)
	if blend >= 1.0:
		return new_r
	return lerpf(_eval(_def(prev_defs, k), a), new_r, blend)


## Planet / orbit center of orbit k (world space, relative to the playfield origin).
static func center(k: int) -> Vector2:
	var c_new: Vector2 = _def(defs, k).get("center", Vector2.ZERO)
	if blend >= 1.0:
		return c_new
	var c_old: Vector2 = _def(prev_defs, k).get("center", Vector2.ZERO)
	return c_old.lerp(c_new, blend)


static func pos(k: int, a: float) -> Vector2:
	return center(k) + Vector2(cos(a), sin(a)) * radius(k, a)


## Angle of a world point as seen from orbit k's center.
static func angle_of(k: int, p: Vector2) -> float:
	return (p - center(k)).angle()


## Distinct planet centers (one planet per center).
static func planets() -> Array:
	var out: Array = []
	for k in count():
		var c := center(k)
		var dup := false
		for o in out:
			if o.distance_to(c) < 1.0:
				dup = true
		if not dup:
			out.append(c)
	return out


static func on_ring(a: float, r := -1.0) -> Vector2:
	return center(0) + Vector2(cos(a), sin(a)) * (radius(0, a) if r < 0.0 else r)


## Largest distance of orbit k from its own center (default: any orbit, from its center).
static func max_radius(k := -1) -> float:
	var m := 0.0
	for o in count():
		if k >= 0 and o != k:
			continue
		for i in 32:
			m = maxf(m, radius(o, TAU * i / 32.0))
	return m


## Farthest point of any orbit from the playfield origin (screen fitting).
static func extent() -> float:
	var m := 0.0
	for k in count():
		for i in 32:
			m = maxf(m, pos(k, TAU * i / 32.0).length())
	return m


static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


## Half-angle (rad) covered by a circle of radius `rr` sitting on an orbit of radius `r`.
static func chord_half(rr: float, r := -1.0) -> float:
	var rad := R if r < 0.0 else r
	return 2.0 * asin(clampf(rr / (2.0 * rad), 0.0, 1.0))


## Index of the crossing whose window contains angle `a` on orbit `k`, or -1.
static func crossing_at(a: float, k: int) -> int:
	if count() < 2 or morphing():
		return -1
	for i in crossings.size():
		if absf(ang_diff(a, crossings[i]["a"][k])) <= CROSS_WINDOW:
			return i
	return -1


static func at_crossing(a: float, k := 0) -> bool:
	return crossing_at(a, k) >= 0


## Result of a tap: [orbit, dir, angle]. Inside a crossing window the player moves to the
## other orbit at the same world point; otherwise the direction reverses.
static func tap_result(a: float, k: int, dir: int) -> Array:
	var i := crossing_at(a, k)
	if i < 0:
		return [k, -dir, a]
	var o := 1 - k
	return [o, dir * int(crossings[i]["sign"]), wrapf(angle_of(o, pos(k, a)), -PI, PI)]


static func _tangent(k: int, a: float) -> Vector2:
	return (pos(k, a + 0.01) - pos(k, a - 0.01)).normalized()


static func _refresh() -> void:
	var s := 0.0
	for i in 16:
		s += radius(0, TAU * i / 16.0)
	R = s / 16.0
	crossings.clear()
	if count() < 2:
		return
	# walk orbit 0 and find where it enters/leaves orbit 1 (sign of "outside orbit 1")
	var n := 256
	var a0 := TAU * 0.5 / n
	var prev := _outside(1, pos(0, a0))
	for i in range(1, n + 1):
		var a1 := TAU * (i + 0.5) / n
		var d := _outside(1, pos(0, a1))
		if (d > 0.0) != (prev > 0.0):
			var lo := a1 - TAU / n
			var hi := a1
			for it in 22:
				var m := (lo + hi) * 0.5
				if (_outside(1, pos(0, m)) > 0.0) == (prev > 0.0):
					lo = m
				else:
					hi = m
			var ac := wrapf((lo + hi) * 0.5, -PI, PI)
			var ao := wrapf(angle_of(1, pos(0, ac)), -PI, PI)
			var sign := 1 if _tangent(0, ac).dot(_tangent(1, ao)) >= 0.0 else -1
			crossings.append({"a": [ac, ao], "sign": sign})
		prev = d


## >0 when point p lies outside orbit k.
static func _outside(k: int, p: Vector2) -> float:
	var v := p - center(k)
	return v.length() - radius(k, v.angle())
