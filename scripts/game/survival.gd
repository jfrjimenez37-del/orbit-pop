class_name Survival
## Fairness checker. Simulates every reachable (orbit, angle, direction) state of the
## player through the future danger timeline of the given hazards, assuming a
## human-limited tap rate and inflated hitboxes. If no state survives, the pattern is unfair.
##
## Each orbit is split into 128 angular buckets stored as two 64-bit words per direction.
## The time step equals the time needed to travel one bucket, so moving is a bit rotation.
## A tap reverses direction, except inside a crossing window, where it switches orbit.

const N := 128
const BW := TAU / N
const TAP_GAP := 0.12          # fastest tapping assumed (s)
const MARGIN := BW * 0.5 + 0.03
const MAXP := 0x7FFFFFFFFFFFFFFF


static func _rotl(v: Array) -> Array:
	var lo: int = v[0]
	var hi: int = v[1]
	return [(lo << 1) | ((hi >> 63) & 1), (hi << 1) | ((lo >> 63) & 1)]


static func _rotr(v: Array) -> Array:
	var lo: int = v[0]
	var hi: int = v[1]
	return [((lo >> 1) & MAXP) | ((hi & 1) << 63), ((hi >> 1) & MAXP) | ((lo & 1) << 63)]


static func _and(a: Array, b: Array) -> Array:
	return [a[0] & b[0], a[1] & b[1]]


static func _andn(a: Array, b: Array) -> Array:
	return [a[0] & ~b[0], a[1] & ~b[1]]


static func _or(a: Array, b: Array) -> Array:
	return [a[0] | b[0], a[1] | b[1]]


static func _any(a: Array) -> bool:
	return (a[0] | a[1]) != 0


static func _set_range(m: Array, c: float, hw: float) -> void:
	if hw >= PI:
		m[0] = -1; m[1] = -1
		return
	for b in range(ceili((c - hw) / BW), floori((c + hw) / BW) + 1):
		var k := posmod(b, N)
		if k < 64:
			m[0] |= 1 << k
		else:
			m[1] |= 1 << (k - 64)


## Returns [lo, hi] mask of dangerous buckets on orbit `k` at time t.
static func danger_mask(hazards: Array, t: float, k := 0, margin := MARGIN) -> Array:
	var m := [0, 0]
	var iv: Array = []
	for h in hazards:
		iv.clear()
		h.danger(t, iv, k)
		for v in iv:
			_set_range(m, v.x, v.y + margin)
	return m


static func cross_mask() -> Array:
	var m := [0, 0]
	if Orbit.count() >= 2 and not Orbit.morphing():
		for c in Orbit.crossings:
			# only buckets fully inside the window count (conservative)
			_set_range(m, c, Orbit.CROSS_WINDOW - BW * 0.5)
	return m


static func bucket(angle: float) -> int:
	return posmod(roundi(angle / BW), N)


## True if some tap sequence lets the player survive every hazard in `hazards`.
## `first_tap`: whether a tap is allowed right now (step 0).
static func can_survive(hazards: Array, t_now: float, angle: float, dir: int, omega: float, first_tap := true, orbit := 0) -> bool:
	var horizon := t_now
	for h in hazards:
		horizon = maxf(horizon, h.t_danger_end)
	if horizon <= t_now:
		return true
	var kc := Orbit.count()
	var dt := BW / omega
	var steps := ceili((horizon - t_now) / dt) + 1
	var gap := maxi(1, roundi(TAP_GAP / dt))
	var b := bucket(angle)
	var bit := [(1 << b) if b < 64 else 0, (1 << (b - 64)) if b >= 64 else 0]
	var P: Array = []   # per orbit, moving +1 (angle increasing)
	var M: Array = []   # per orbit, moving -1
	for k in kc:
		P.append([0, 0]); M.append([0, 0])
	if dir > 0:
		P[mini(orbit, kc - 1)] = bit
	else:
		M[mini(orbit, kc - 1)] = bit
	var X := cross_mask()
	var alive := false
	for k in kc:
		var d0 := danger_mask(hazards, t_now, k)
		P[k] = _andn(P[k], d0); M[k] = _andn(M[k], d0)
		alive = alive or _any(P[k]) or _any(M[k])
	if not alive:
		return false
	for s in steps:
		var t := t_now + (s + 1) * dt
		var NP: Array = []
		var NM: Array = []
		for k in kc:
			NP.append(_rotl(P[k])); NM.append(_rotr(M[k]))
		if s % gap == 0 and (s > 0 or first_tap):
			for k in kc:
				# outside crossings: reverse
				NM[k] = _or(NM[k], _rotr(_andn(P[k], X)))
				NP[k] = _or(NP[k], _rotl(_andn(M[k], X)))
				# at crossings: switch orbit, keep direction
				if kc >= 2:
					var o := 1 - k
					NP[o] = _or(NP[o], _rotl(_and(P[k], X)))
					NM[o] = _or(NM[o], _rotr(_and(M[k], X)))
		alive = false
		for k in kc:
			var d := danger_mask(hazards, t, k)
			P[k] = _andn(NP[k], d); M[k] = _andn(NM[k], d)
			alive = alive or _any(P[k]) or _any(M[k])
		if not alive:
			return false
	return true
