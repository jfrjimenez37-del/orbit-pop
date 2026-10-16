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


static func _has(v: Array, b: int) -> bool:
	return (v[0] >> b) & 1 == 1 if b < 64 else (v[1] >> (b - 64)) & 1 == 1


static func _setbit(v: Array, b: int) -> void:
	b = posmod(b, N)
	if b < 64:
		v[0] |= 1 << b
	else:
		v[1] |= 1 << (b - 64)


## Per orbit: [no-reverse mask, [[bucket, target orbit, target bucket, dir sign], ...]]
## Buckets surely inside a crossing window switch orbit; buckets that might be inside can
## neither reverse nor switch (the true angle is only known to +-half a bucket).
static func cross_maps() -> Array:
	var out: Array = []
	var W := Orbit.CROSS_WINDOW
	for k in Orbit.count():
		var m := [0, 0]
		var maps: Array = []
		if Orbit.count() >= 2 and not Orbit.morphing():
			for c in Orbit.crossings:
				var side: int = c["k"].find(k)
				if side < 0:
					continue
				var o: int = c["k"][1 - side]
				var ak: float = c["a"][side]
				_set_range(m, ak, W + BW * 0.5)
				for b in range(ceili((ak - W + BW * 0.5) / BW), floori((ak + W - BW * 0.5) / BW) + 1):
					var bb := posmod(b, N)
					var a2 := Orbit.angle_of(o, Orbit.pos(k, bb * BW))
					maps.append([bb, o, bucket(a2), int(c["sign"])])
		out.append([m, maps])
	return out


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
	var CM := cross_maps()
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
				var X: Array = CM[k][0]
				# outside crossings: reverse
				NM[k] = _or(NM[k], _rotr(_andn(P[k], X)))
				NP[k] = _or(NP[k], _rotl(_andn(M[k], X)))
				# at crossings: jump to the other orbit (angle + direction remapped)
				for mp in CM[k][1]:
					var b0: int = mp[0]
					var o: int = mp[1]
					for dd in [1, -1]:
						if _has(P[k] if dd > 0 else M[k], b0):
							var nd: int = dd * int(mp[3])
							if nd > 0:
								_setbit(NP[o], int(mp[2]) + 1)
							else:
								_setbit(NM[o], int(mp[2]) - 1)
		alive = false
		for k in kc:
			var d := danger_mask(hazards, t, k)
			P[k] = _andn(NP[k], d); M[k] = _andn(NM[k], d)
			alive = alive or _any(P[k]) or _any(M[k])
		if not alive:
			return false
	return true
