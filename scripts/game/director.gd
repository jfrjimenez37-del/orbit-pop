class_name Director
extends RefCounted
## Picks hazard patterns, scales them with difficulty and only commits a pattern
## when Survival confirms the player can still escape everything on screen.

var rng := RandomNumberGenerator.new()
var next_t := 0.0
var next_bubble := 0.0
var offset := 0.0          # adaptive difficulty shift (s), from recent performance
var rejected := 0          # stats for tests / tuning
var committed := 0
var spawned_first := false
var bubble_rate := 1.0     # BUBBLE RUSH boost: 2.0 = twice as many bubbles
var hold := false          # world change in progress: no new spawns
var stage := 0             # current Stages index (unlocks obstacles)
var human_check := true    # require human timing slack when committing (off only for A/B audits)

# name, unlock time (effective seconds), base weight
const PATTERNS := [
	["lead", 0.0, 3.0],
	["here", 2.0, 1.5],
	["pinch", 5.0, 2.0],
	["mine", 8.0, 2.5],
	["spoke", 12.0, 2.5],
	["gate", 18.0, 2.0],
	["rain", 24.0, 2.0],
	["sweep", 32.0, 1.6],
	["cage", 40.0, 1.6],
	["drift", 48.0, 1.6],
]
## Obstacles unlocked by reaching a world (stage index, base weight).
const STAGE_PATTERNS := [["pulse", 1, 2.2], ["saw", 2, 2.0], ["swap", 4, 2.6], ["cross_rain", 4, 1.6],
	["link", 5, 2.4], ["comet", 5, 2.4], ["comet_rain", 7, 1.8], ["link_cage", 7, 1.6]]
const MULTI_PLANET := ["link", "comet_rain", "link_cage"]


func reset(seed_value: int, recent_avg: float) -> void:
	rng.seed = seed_value
	offset = clampf((recent_avg - 12.0) * 0.5, -6.0, 12.0)
	next_t = 1.1
	next_bubble = rng.randf_range(4.0, 6.0)
	rejected = 0
	committed = 0
	spawned_first = false
	hold = false
	stage = 0


func eff_time(t: float) -> float:
	return maxf(0.0, t + offset)


## 0..1 difficulty curve; reaches max at ~2 minutes effective.
func level(t: float) -> float:
	var x := clampf(eff_time(t) / 95.0, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 1.6)


func omega(t: float) -> float:
	return lerpf(2.45, 3.45, level(t))


## Returns {"hazards": [...], "bubbles": [...]} to add this frame (possibly empty).
func update(t: float, angle: float, dir: int, active: Array, k := 0) -> Dictionary:
	var out := {"hazards": [], "bubbles": []}
	if hold:
		return out
	if t >= next_bubble:
		next_bubble = t + rng.randf_range(5.0, 8.5) / bubble_rate
		var bo := rng.randi_range(0, Orbit.count() - 1)
		var b := Bubble.new().setup(angle + PI + rng.randf_range(-0.7, 0.7), t, 5.0, bo)
		out["bubbles"].append(b)
	if t < next_t:
		return out
	var w := omega(t)
	for attempt in 5:
		var name: String = "lead" if not spawned_first else _pick(t)
		var res := _build(name, t, angle, dir, w, level(t), attempt, k)
		var hs: Array = res["hazards"]
		var all := active.duplicate()
		all.append_array(hs)
		var fair := Survival.can_survive(all, t, angle, dir, w, true, k, Survival.human_margin(w), Survival.HUMAN_GAP) \
			if human_check else Survival.can_survive(all, t, angle, dir, w, true, k)
		if fair:
			spawned_first = true
			committed += 1
			next_t = t + float(res["length"]) + lerpf(0.55, 0.08, level(t))
			out["hazards"] = hs
			return out
		rejected += 1
		for h in hs:
			h.free()
	next_t = t + 0.25
	return out


func _pick(t: float) -> String:
	var te := eff_time(t)
	var total := 0.0
	var pool := []
	for p in PATTERNS:
		if te >= p[1]:
			# fresh patterns get a short spotlight, old basics fade a bit
			var w: float = p[2]
			if te - p[1] < 10.0:
				w *= 1.8
			if p[0] == "here" or p[0] == "lead":
				w *= lerpf(1.0, 0.5, level(t))
			pool.append([p[0], w])
			total += w
	for sp in STAGE_PATTERNS:
		var needs_two: bool = sp[0] in ["swap", "cross_rain"]
		var needs_planets: bool = sp[0] in MULTI_PLANET
		if stage >= sp[1] and (not needs_two or Orbit.count() >= 2) and (not needs_planets or Orbit.planets().size() >= 2):
			pool.append([sp[0], sp[2]])
			total += sp[2]
	var r := rng.randf() * total
	for p in pool:
		r -= p[1]
		if r <= 0.0:
			return p[0]
	return pool[-1][0]


var _home := 0   # orbit (planet) the pattern being built belongs to


func _meteor(theta: float, t_spawn: float, x: float) -> Meteor:
	var pre := lerpf(0.34, 0.16, x)
	var v := lerpf(105.0, 170.0, x)
	return Meteor.new().setup(theta, t_spawn, pre, v, _home)


## Orbits whose planet is not the planet of orbit k.
func _other_planets(k: int) -> Array:
	var out: Array = []
	for p in Orbit.planets():
		if p["c"].distance_to(Orbit.center(k)) > 1.0:
			out.append(p["k"])
	return out


func _hit_time(x: float) -> float:
	return Meteor.time_to_orbit(lerpf(0.34, 0.16, x), lerpf(105.0, 170.0, x), Orbit.R)


func _build(name: String, t: float, a: float, d: int, w: float, x: float, attempt: int, k := 0) -> Dictionary:
	var hs: Array = []
	_home = k
	var warn := lerpf(0.9, 0.58, x)
	var th := _hit_time(x)
	var j := rng.randf_range(-0.12, 0.12)
	var length := 1.0
	match name:
		"lead":
			if not spawned_first:
				# tutorial meteor: slow, aimed exactly where the player will be
				var m := Meteor.new().setup(a + d * w * Meteor.time_to_orbit(0.5, 80.0, Orbit.R), t, 0.5, 80.0, k)
				hs.append(m)
				length = 1.6
			else:
				hs.append(_meteor(a + d * w * th + j, t, x))
				length = th * 0.75
		"here":
			hs.append(_meteor(a + j * 0.5, t, x))
			length = th * 0.6
		"pinch":
			var off := w * th * rng.randf_range(0.75, 0.95)
			hs.append(_meteor(a + off, t, x))
			hs.append(_meteor(a - off, t, x))
			length = th * 0.9
		"mine":
			var sp := Spiky.new().setup(a + d * rng.randf_range(0.8, 1.5), t, warn, rng.randf_range(2.2, 3.4), 0.0, k)
			hs.append(sp)
			length = warn + 0.6
		"spoke":
			var b := Barrier.new().setup(a + d * rng.randf_range(0.9, 1.7), t, warn, rng.randf_range(1.6, 2.4), 0.0, k)
			hs.append(b)
			length = warn + 0.6
		"gate":
			var g := rng.randf_range(0.85, 1.25)
			var act := rng.randf_range(3.0, 3.8)
			hs.append(Spiky.new().setup(a + g, t, warn, act, 0.0, k))
			hs.append(Spiky.new().setup(a - g, t, warn, act, 0.0, k))
			hs.append(_meteor(a + rng.randf_range(-0.3, 0.3), t + warn + 0.4, x))
			length = warn + 1.8
		"rain":
			var n := 3 + rng.randi_range(0, 1 + int(x * 2.0))
			var gap := lerpf(0.6, 0.42, x)
			var dd := d
			for i in n:
				var ti := t + i * gap
				var target := a + dd * w * (th + i * gap) * 0.55 + rng.randf_range(-0.5, 0.5)
				hs.append(_meteor(target, ti, x))
				if rng.randf() < 0.4:
					dd = -dd
			length = n * gap + th * 0.4
		"sweep":
			var sb := Barrier.new().setup(a - d * rng.randf_range(1.4, 2.0), t, warn, rng.randf_range(2.6, 3.6), d * w * rng.randf_range(0.42, 0.58), k)
			hs.append(sb)
			length = warn + 2.0
		"cage":
			var g2 := rng.randf_range(0.8, 1.1)
			var act2 := rng.randf_range(2.6, 3.2)
			hs.append(Barrier.new().setup(a + g2, t, warn, act2, 0.0, k))
			hs.append(Barrier.new().setup(a - g2, t, warn, act2, 0.0, k))
			hs.append(_meteor(a + rng.randf_range(-0.25, 0.25), t + warn + 0.3, x))
			if x > 0.6:
				hs.append(_meteor(a + rng.randf_range(-0.4, 0.4), t + warn + 1.1, x))
			length = warn + 2.0
		"drift":
			var dr := Spiky.new().setup(a + d * rng.randf_range(2.0, 2.6), t, warn, rng.randf_range(2.4, 3.2), -d * rng.randf_range(0.6, 0.95), k)
			hs.append(dr)
			if rng.randf() < 0.5 + x * 0.3:
				hs.append(_meteor(a - d * rng.randf_range(0.6, 1.2), t + warn * 0.5, x))
			length = warn + 1.4
		"pulse":
			var spd := lerpf(62.0, 90.0, x)
			var cross_t := warn + (Orbit.R - Orbit.planet_r(k)) / spd
			var gh := lerpf(0.8, 0.5, x)
			hs.append(Pulse.new().setup(a + d * w * cross_t * rng.randf_range(0.3, 1.0), t, warn, gh, spd, k))
			length = cross_t + 0.4
		"saw":
			var act3 := lerpf(1.0, 0.8, x)
			var span := rng.randf_range(2.0, 2.8)
			hs.append(Spiky.new().setup(a + d * rng.randf_range(1.8, 2.6), t, warn + 0.15, act3, -d * span / act3, k, "saw"))
			length = warn + act3 * 0.8
		"swap":
			# the player's orbit gets caged: escape by switching orbit at a crossing
			var g3 := rng.randf_range(1.0, 1.4)
			var act4 := rng.randf_range(2.6, 3.4)
			hs.append(Spiky.new().setup(a + g3, t, warn, act4, 0.0, k))
			hs.append(Spiky.new().setup(a - g3, t, warn, act4, 0.0, k))
			hs.append(_meteor(a + rng.randf_range(-0.2, 0.2), t + warn + 0.5, x))
			length = warn + 1.8
		"cross_rain":
			# mines on the other orbit + meteors on this one: pick the right orbit
			var nb := Orbit.neighbors(k)
			var o: int = nb[rng.randi() % nb.size()] if not nb.is_empty() else (k + 1) % Orbit.count()
			var ao := Orbit.angle_of(o, Orbit.pos(k, a)) + rng.randf_range(1.2, 1.8) * (1 if rng.randf() < 0.5 else -1)
			hs.append(Spiky.new().setup(ao, t, warn, 2.6, 0.0, o))
			for i in 3:
				hs.append(_meteor(a + d * w * (_hit_time(x) + i * 0.5) * 0.6 + rng.randf_range(-0.3, 0.3), t + i * 0.5, x))
			length = warn + 1.6
		"link":
			# electric bond between this planet and a neighbour (blocks the junction for a while)
			var nb2 := _other_planets(k)
			if not nb2.is_empty():
				hs.append(Link.new().setup(k, nb2[rng.randi() % nb2.size()], t, warn + 0.1, rng.randf_range(1.6, 2.4)))
				if rng.randf() < 0.5 + x * 0.3:
					hs.append(_meteor(a + d * w * _hit_time(x) + rng.randf_range(-0.2, 0.2), t + 0.3, x))
			length = warn + 1.4
		"link_cage":
			var others := _other_planets(k)
			for o2 in others:
				hs.append(Link.new().setup(k, o2, t, warn + 0.1, rng.randf_range(2.0, 2.6)))
			hs.append(Spiky.new().setup(a + d * rng.randf_range(1.0, 1.6), t, warn, 2.4, 0.0, k))
			length = warn + 1.8
		"comet":
			var n2 := 1 + (1 if rng.randf() < x else 0)
			for i in n2:
				var tt := lerpf(0.55, 0.32, x) + Comet.LEN * 0.5 / lerpf(130.0, 190.0, x)
				var target := Orbit.pos(k, a + d * w * tt + rng.randf_range(-0.35, 0.35))
				hs.append(Comet.new().setup(target, rng.randf_range(-PI, PI), t + i * 0.7, lerpf(0.55, 0.32, x), lerpf(130.0, 190.0, x)))
			length = n2 * 0.7 + 0.6
		"comet_rain":
			for i in 3:
				var ti := t + i * 0.55
				var tt2 := lerpf(0.5, 0.3, x) + Comet.LEN * 0.5 / lerpf(140.0, 190.0, x)
				var kk := rng.randi_range(0, Orbit.count() - 1)
				var target2 := Orbit.pos(kk, rng.randf_range(-PI, PI)) if kk != k else Orbit.pos(k, a + d * w * (tt2 + i * 0.55))
				hs.append(Comet.new().setup(target2, rng.randf_range(-PI, PI), ti, lerpf(0.5, 0.3, x), lerpf(140.0, 190.0, x)))
			length = 1.9
	# later attempts: simplify (drop extras) to make acceptance easier
	if attempt >= 3 and hs.size() > 1:
		for q in range(1, hs.size()):
			hs[q].free()
		hs = [hs[0]]
	return {"hazards": hs, "length": length}
