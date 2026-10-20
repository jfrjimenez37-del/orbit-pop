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
## Human tolerance used when committing new patterns: every escape must still work if the
## player taps up to HUMAN_LATE seconds off, and never needs taps closer than HUMAN_GAP.
const HUMAN_LATE := 0.06
const HUMAN_GAP := 0.17
## Nobody reacts to a brand-new hazard instantly: a new pattern is only committed if the
## player can keep doing what they do (no tap) for this long after it appears.
const HUMAN_REACT := 0.25


static func human_margin(omega: float) -> float:
	return MARGIN + omega * HUMAN_LATE


static func _set_range(m: Array, c: float, hw: float) -> void:
	if hw >= PI:
		m[0] = -1; m[1] = -1
		return
	var b0 := ceili((c - hw) / BW)
	var cnt := floori((c + hw) / BW) - b0 + 1
	if cnt <= 0:
		return
	if cnt >= N:
		m[0] = -1; m[1] = -1
		return
	var st := posmod(b0, N)
	var en := st + cnt
	if en <= N:
		_span(m, st, en)
	else:
		_span(m, st, N)
		_span(m, 0, en - N)


## Sets bits [a, b) of a 128-bit mask (0 <= a < b <= 128).
static func _span(m: Array, a: int, b: int) -> void:
	if a < 64:
		var e := mini(b, 64)
		m[0] |= -1 if e - a >= 64 else ((1 << (e - a)) - 1) << a
	if b > 64:
		var a2 := maxi(a, 64) - 64
		var e2 := b - 64
		m[1] |= -1 if e2 - a2 >= 64 else ((1 << (e2 - a2)) - 1) << a2


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


## Danger mask at step s on orbit k: cached part (base hazards) + the rest.
static func _mask(base: Array, rest: Array, cache, t: float, s: int, k: int, margin: float) -> Array:
	var m := danger_mask(rest, t, k, margin)
	if cache == null or base.is_empty():
		return m
	var key := s * 4 + k
	var c = cache.get(key)
	if c == null:
		c = danger_mask(base, t, k, margin)
		cache[key] = c
	return [m[0] | c[0], m[1] | c[1]]


## Per orbit: [no-reverse mask, [[bucket, target orbit, target bucket, dir sign], ...]]
## Buckets surely inside a crossing window switch orbit; buckets that might be inside can
## neither reverse nor switch (the true angle is only known to +-half a bucket).
static var _cm: Array = []
static var _cm_ver := -1


static func cross_maps() -> Array:
	if _cm_ver == Orbit.version:
		return _cm
	_cm_ver = Orbit.version
	_cm = _build_cross_maps()
	return _cm


static func _build_cross_maps() -> Array:
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
## `margin` / `tap_gap`: hitbox inflation and fastest tap assumed (Director uses the human values).
## `tap_from`: no tap is possible before t_now + tap_from (reaction time).
## `omega_rate`: angular acceleration (rad/s^2); the game speeds up slowly as time goes by.
## `cache` + `n_cached`: the first n_cached hazards are the same on every call that shares
## `cache` (same t_now, omega and margin), so their danger masks are computed only once.
static func can_survive(hazards: Array, t_now: float, angle: float, dir: int, omega: float, first_tap := true, orbit := 0,
		margin := MARGIN, tap_gap := TAP_GAP, tap_from := 0.0, omega_rate := 0.0, cache = null, n_cached := 0) -> bool:
	var horizon := t_now
	for h in hazards:
		horizon = maxf(horizon, h.t_danger_end)
	if horizon <= t_now:
		return true
	var kc := Orbit.count()
	var dt := BW / omega
	var gap := maxi(1, roundi(tap_gap / dt))
	var tap0 := ceili(tap_from / dt - 0.001)
	var b := bucket(angle)
	# per orbit 128-bit sets of reachable buckets, split in two 64-bit words:
	# P = moving +1 (angle increasing), M = moving -1
	var plo := PackedInt64Array(); plo.resize(kc)
	var phi := PackedInt64Array(); phi.resize(kc)
	var mlo := PackedInt64Array(); mlo.resize(kc)
	var mhi := PackedInt64Array(); mhi.resize(kc)
	var ko := mini(orbit, kc - 1)
	var b_lo := (1 << b) if b < 64 else 0
	var b_hi := (1 << (b - 64)) if b >= 64 else 0
	if dir > 0:
		plo[ko] = b_lo; phi[ko] = b_hi
	else:
		mlo[ko] = b_lo; mhi[ko] = b_hi
	var CM := cross_maps()
	var base: Array = hazards.slice(0, n_cached) if cache != null else []
	var rest: Array = hazards.slice(n_cached) if cache != null else hazards
	var alive := false
	for k in kc:
		var d0 := _mask(base, rest, cache, t_now, -1, k, margin)
		plo[k] &= ~d0[0]; phi[k] &= ~d0[1]; mlo[k] &= ~d0[0]; mhi[k] &= ~d0[1]
		alive = alive or (plo[k] | phi[k] | mlo[k] | mhi[k]) != 0
	if not alive:
		return false
	var nplo := PackedInt64Array(); nplo.resize(kc)
	var nphi := PackedInt64Array(); nphi.resize(kc)
	var nmlo := PackedInt64Array(); nmlo.resize(kc)
	var nmhi := PackedInt64Array(); nmhi.resize(kc)
	var t := t_now
	var s := -1
	while t < horizon + dt:
		s += 1
		# one step = the time needed to travel one bucket at the current speed
		t += BW / (omega + omega_rate * (t - t_now))
		var tap := s >= tap0 and (s - tap0) % gap == 0 and (s > 0 or first_tap)
		for k in kc:
			var a0 := plo[k]
			var a1 := phi[k]
			var c0 := mlo[k]
			var c1 := mhi[k]
			# move one bucket: P rotates left, M rotates right
			var np0 := (a0 << 1) | ((a1 >> 63) & 1)
			var np1 := (a1 << 1) | ((a0 >> 63) & 1)
			var nm0 := ((c0 >> 1) & MAXP) | ((c1 & 1) << 63)
			var nm1 := ((c1 >> 1) & MAXP) | ((c0 & 1) << 63)
			if tap:
				# outside crossings a tap reverses: P -> M (moves -1), M -> P (moves +1)
				var X: Array = CM[k][0]
				var r0: int = a0 & ~X[0]
				var r1: int = a1 & ~X[1]
				nm0 |= ((r0 >> 1) & MAXP) | ((r1 & 1) << 63)
				nm1 |= ((r1 >> 1) & MAXP) | ((r0 & 1) << 63)
				var q0: int = c0 & ~X[0]
				var q1: int = c1 & ~X[1]
				np0 |= (q0 << 1) | ((q1 >> 63) & 1)
				np1 |= (q1 << 1) | ((q0 >> 63) & 1)
			nplo[k] = np0; nphi[k] = np1; nmlo[k] = nm0; nmhi[k] = nm1
		if tap:
			# at crossings: jump to the other orbit (angle + direction remapped)
			for k in kc:
				for mp in CM[k][1]:
					var b0: int = mp[0]
					var o: int = mp[1]
					for dd in [1, -1]:
						var w := (plo[k] if b0 < 64 else phi[k]) if dd > 0 else (mlo[k] if b0 < 64 else mhi[k])
						if (w >> (b0 & 63)) & 1 == 1:
							var nd: int = dd * int(mp[3])
							var tb := posmod(int(mp[2]) + (1 if nd > 0 else -1), N)
							if nd > 0:
								if tb < 64: nplo[o] |= 1 << tb
								else: nphi[o] |= 1 << (tb - 64)
							else:
								if tb < 64: nmlo[o] |= 1 << tb
								else: nmhi[o] |= 1 << (tb - 64)
		alive = false
		for k in kc:
			var d := _mask(base, rest, cache, t, s, k, margin)
			plo[k] = nplo[k] & ~d[0]; phi[k] = nphi[k] & ~d[1]
			mlo[k] = nmlo[k] & ~d[0]; mhi[k] = nmhi[k] & ~d[1]
			alive = alive or (plo[k] | phi[k] | mlo[k] | mhi[k]) != 0
		if not alive:
			return false
	return true
