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
const WOLD_KEY := -5000         # cache slot of robust()'s backward pass over the old hazards
const ALL_KEY := -5001          # cache slot: can_survive's per-step masks of all hazards, for robust()
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
		# every hazard is only dangerous inside [t_danger_start, t_danger_end] (skip the call)
		if t < h.t_danger_start or t > h.t_danger_end:
			continue
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
	var key := s * 8 + k
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


## Crossing maps at step s of a check in a moving world. Every check and attempt of one spawn
## steps through the same times, so they share them (rebuilding them was the slowest part).
static func _cm_at(cache, s: int) -> Array:
	if cache == null:
		return cross_maps()
	var key := -100 - s
	var c = cache.get(key)
	if c == null:
		c = cross_maps()
		cache[key] = c
	return c


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
			for c in Orbit.cross_list():
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
	if not Orbit.moving():
		return _survive(hazards, t_now, angle, dir, omega, first_tap, orbit, margin, tap_gap, tap_from, omega_rate, cache, n_cached, false)
	# moving world: the geometry follows each step's time; put the clock back afterwards
	var keep := Orbit.time
	Orbit.set_time(t_now)
	var res := _survive(hazards, t_now, angle, dir, omega, first_tap, orbit, margin, tap_gap, tap_from, omega_rate, cache, n_cached, true)
	Orbit.set_time(keep)
	return res


static func _survive(hazards: Array, t_now: float, angle: float, dir: int, omega: float, first_tap: bool, orbit: int,
		margin: float, tap_gap: float, tap_from: float, omega_rate: float, cache, n_cached: int, moving: bool) -> bool:
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
	# the masks of every step are kept for robust(), which needs exactly the same ones
	var keep := cache != null
	var d_all: Array = []
	if keep:
		cache.erase(ALL_KEY)
	var s_lo := PackedInt64Array(); s_lo.resize(kc)
	var s_hi := PackedInt64Array(); s_hi.resize(kc)
	for k in kc:
		var d0 := _mask(base, rest, cache, t_now, -1, k, margin)
		s_lo[k] = d0[0]; s_hi[k] = d0[1]
		plo[k] &= ~d0[0]; phi[k] &= ~d0[1]; mlo[k] &= ~d0[0]; mhi[k] &= ~d0[1]
		alive = alive or (plo[k] | phi[k] | mlo[k] | mhi[k]) != 0
	if keep:
		d_all.append([s_lo, s_hi])
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
		if moving:
			# transitions start from the geometry of the current step (already set: it is where
			# the previous step's masks were taken, or t_now)
			CM = _cm_at(cache, s)
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
		if moving:
			Orbit.set_time(t)
		var a_lo := PackedInt64Array(); a_lo.resize(kc)
		var a_hi := PackedInt64Array(); a_hi.resize(kc)
		for k in kc:
			var d := _mask(base, rest, cache, t, s, k, margin)
			a_lo[k] = d[0]; a_hi[k] = d[1]
			plo[k] = nplo[k] & ~d[0]; phi[k] = nphi[k] & ~d[1]
			mlo[k] = nmlo[k] & ~d[0]; mhi[k] = nmhi[k] & ~d[1]
			alive = alive or (plo[k] | phi[k] | mlo[k] | mhi[k]) != 0
		if keep:
			d_all.append([a_lo, a_hi])
		if not alive:
			return false
	if keep:
		cache[ALL_KEY] = [t_now, hazards.size(), n_cached, d_all]
	return true


# ------------------------------------------------------------------ reaction-proof check

static func _rotl0(lo: int, hi: int) -> int:
	return (lo << 1) | ((hi >> 63) & 1)


static func _rotl1(lo: int, hi: int) -> int:
	return (hi << 1) | ((lo >> 63) & 1)


static func _rotr0(lo: int, hi: int) -> int:
	return ((lo >> 1) & MAXP) | ((hi & 1) << 63)


static func _rotr1(lo: int, hi: int) -> int:
	return ((hi >> 1) & MAXP) | ((lo & 1) << 63)


## Empty set of states: [P lo, P hi, M lo, M hi], one int per orbit each.
static func _states(kc: int, fill := 0) -> Array:
	var s: Array = []
	for i in 4:
		var a := PackedInt64Array()
		a.resize(kc)
		a.fill(fill)
		s.append(a)
	return s


static func _bit(v: int, b: int) -> bool:
	return (v >> (b & 63)) & 1 == 1


## Reaction-proof fairness, used when committing a new pattern. The player cannot have seen
## the new hazards during the first `react` seconds, so whatever they do in that time (any taps
## that make sense for the hazards already on screen) must still leave a way out of everything.
## hazards[0..n_old) are already on screen, the rest is the new pattern. Same step grid and
## mask cache keys as can_survive (call can_survive first: this only adds the robustness part).
static func robust(hazards: Array, n_old: int, t_now: float, angle: float, dir: int, omega: float, orbit := 0,
		margin := MARGIN, tap_gap := HUMAN_GAP, react := HUMAN_REACT, omega_rate := 0.0, cache = null) -> bool:
	var old: Array = hazards.slice(0, n_old)
	var new: Array = hazards.slice(n_old)
	if new.is_empty():
		return true
	var horizon := t_now
	for h in hazards:
		horizon = maxf(horizon, h.t_danger_end)
	if horizon <= t_now:
		return true
	var kc := Orbit.count()
	var dt0 := BW / omega
	var gap := maxi(1, roundi(tap_gap / dt0))
	var tap0 := ceili(react / dt0 - 0.001)
	var ts := PackedFloat64Array([t_now])
	var t := t_now
	while t < horizon + dt0:
		t += BW / (omega + omega_rate * (t - t_now))
		ts.append(t)
	var n := ts.size()
	if tap0 >= n - 1:
		return true
	var moving := Orbit.moving()
	var t_keep := Orbit.time
	# danger masks per step: old (cached like can_survive's base part) and new
	var d_old: Array = []
	var cms: Array = []
	var no_cache := cache == null
	if no_cache:
		cache = {}
	# masks of all hazards per step: from can_survive when it just ran on the same hazards
	var shared = cache.get(ALL_KEY)
	var d_all: Array = []
	if shared != null and shared[0] == t_now and shared[1] == hazards.size() and shared[2] == n_old and shared[3].size() == n:
		d_all = shared[3]
	var have_all := not d_all.is_empty()
	for i in n:
		if moving:
			# move the geometry only for what is not cached yet (usually nothing after can_survive)
			var need_geo: bool = not have_all or not cache.has(-100 - i)
			if not need_geo and n_old > 0:
				for k in kc:
					if not cache.has((i - 1) * 8 + k):
						need_geo = true
						break
			if need_geo:
				Orbit.set_time(ts[i])
			cms.append(_cm_at(cache, i))
		else:
			cms.append(cross_maps())
		var o_lo := PackedInt64Array(); o_lo.resize(kc)
		var o_hi := PackedInt64Array(); o_hi.resize(kc)
		var a_lo := PackedInt64Array(); a_lo.resize(kc)
		var a_hi := PackedInt64Array(); a_hi.resize(kc)
		for k in kc:
			var key := (i - 1) * 8 + k
			var c = cache.get(key) if n_old > 0 else [0, 0]
			if c == null:
				c = danger_mask(old, ts[i], k, margin)
				cache[key] = c
			o_lo[k] = c[0]; o_hi[k] = c[1]
			if not have_all:
				var m := danger_mask(new, ts[i], k, margin)
				a_lo[k] = m[0] | c[0]; a_hi[k] = m[1] | c[1]
		d_old.append([o_lo, o_hi])
		if not have_all:
			d_all.append([a_lo, a_hi])
	if moving:
		Orbit.set_time(t_keep)
	# backward: states from which the player can still escape (old only / everything)
	var w_old := _states(kc, -1)
	var w_all := _states(kc, -1)
	for k in kc:
		for q in 2:
			w_old[q * 2][k] &= ~d_old[n - 1][0][k]; w_old[q * 2 + 1][k] &= ~d_old[n - 1][1][k]
			w_all[q * 2][k] &= ~d_all[n - 1][0][k]
			w_all[q * 2 + 1][k] &= ~d_all[n - 1][1][k]
	# W_old only depends on the hazards already on screen: every attempt of a spawn shares it
	# (the backward pass starts after their last danger, where everything is safe)
	var w_old_at = cache.get(WOLD_KEY)
	var have_old := w_old_at != null
	if not have_old:
		w_old_at = []   # W_old for steps 0..tap0
		w_old_at.resize(tap0 + 1)
	var w_all_tap0: Array = []
	for i in range(n - 2, -1, -1):
		var tap := i < tap0 or (i - tap0) % gap == 0
		if not have_old:
			w_old = _back(w_old, cms[i], tap, d_old[i][0], d_old[i][1], null, null)
			if i <= tap0:
				w_old_at[i] = w_old
		w_all = _back(w_all, cms[i], tap, d_all[i][0], d_all[i][1], null, null)
		if i == tap0:
			w_all_tap0 = w_all
			if have_old:
				break   # nothing below tap0 is needed any more
	if not have_old:
		cache[WOLD_KEY] = w_old_at
	# forward through the reaction window with any taps, avoiding the old hazards only
	var r := _states(kc)
	var b := bucket(angle)
	var ko := mini(orbit, kc - 1)
	var q0 := 0 if dir > 0 else 2
	if b < 64:
		r[q0][ko] = 1 << b
	else:
		r[q0 + 1][ko] = 1 << (b - 64)
	for q in 4:
		r[q][ko] &= ~d_old[0][q % 2][ko]
	for i in tap0:
		var wo: Array = w_old_at[i]
		for k in kc:
			for q in 4:
				# r avoids the old hazards already, so hitting anything here means hitting the new ones
				if r[q][k] & wo[q][k] & d_all[i][q % 2][k] != 0:
					return false   # a sensible move gets hit by something not seen yet
		r = _fwd(r, cms[i], true)
		for k in kc:
			for q in 4:
				r[q][k] &= ~d_old[i + 1][q % 2][k]
	var wo2: Array = w_old_at[tap0]
	for k in kc:
		for q in 4:
			if r[q][k] & wo2[q][k] & ~w_all_tap0[q][k] != 0:
				return false   # reachable and fine before, but doomed by the new pattern
	return true


## One backward step: states at step i that reach `w` at step i+1 and are safe now.
static func _back(w: Array, cm: Array, tap: bool, dlo: PackedInt64Array, dhi: PackedInt64Array, d2lo, d2hi) -> Array:
	# (rotations written out inline: this runs for every step of every check, on phones)
	var w0: PackedInt64Array = w[0]
	var w1: PackedInt64Array = w[1]
	var w2: PackedInt64Array = w[2]
	var w3: PackedInt64Array = w[3]
	var kc := w0.size()
	var o0 := PackedInt64Array(); o0.resize(kc)
	var o1 := PackedInt64Array(); o1.resize(kc)
	var o2 := PackedInt64Array(); o2.resize(kc)
	var o3 := PackedInt64Array(); o3.resize(kc)
	for k in kc:
		var p0 := w0[k]
		var p1 := w1[k]
		var m0 := w2[k]
		var m1 := w3[k]
		# moving +1 stays winning if the next bucket is (rotate right); moving -1 likewise (left)
		var ra0 := ((p0 >> 1) & MAXP) | ((p1 & 1) << 63)
		var ra1 := ((p1 >> 1) & MAXP) | ((p0 & 1) << 63)
		var lc0 := (m0 << 1) | ((m1 >> 63) & 1)
		var lc1 := (m1 << 1) | ((m0 >> 63) & 1)
		if tap:
			# P reverses to M (moves -1), M reverses to P (moves +1), outside crossing windows
			var X: Array = cm[k][0]
			var x0: int = X[0]
			var x1: int = X[1]
			o0[k] = ra0 | (lc0 & ~x0); o1[k] = ra1 | (lc1 & ~x1)
			o2[k] = lc0 | (ra0 & ~x0); o3[k] = lc1 | (ra1 & ~x1)
		else:
			o0[k] = ra0; o1[k] = ra1; o2[k] = lc0; o3[k] = lc1
	if tap:
		for k in kc:
			for mp in cm[k][1]:
				var b0: int = mp[0]
				var o: int = mp[1]
				var tb0: int = mp[2]
				var sg: int = mp[3]
				# moving +1 here continues with direction sg on the other orbit, -1 with -sg
				for dd in 2:
					var nd := sg if dd == 0 else -sg
					var tb := posmod(tb0 + (1 if nd > 0 else -1), N)
					var src: int
					if nd > 0:
						src = w0[o] if tb < 64 else w1[o]
					else:
						src = w2[o] if tb < 64 else w3[o]
					if (src >> (tb & 63)) & 1 == 1:
						if dd == 0:
							if b0 < 64: o0[k] |= 1 << b0
							else: o1[k] |= 1 << (b0 - 64)
						else:
							if b0 < 64: o2[k] |= 1 << b0
							else: o3[k] |= 1 << (b0 - 64)
	var two := d2lo != null
	for k in kc:
		var lo: int = dlo[k] | (d2lo[k] if two else 0)
		var hi: int = dhi[k] | (d2hi[k] if two else 0)
		o0[k] &= ~lo; o1[k] &= ~hi; o2[k] &= ~lo; o3[k] &= ~hi
	return [o0, o1, o2, o3]


## One forward step (no danger applied), same transitions as can_survive.
static func _fwd(r: Array, cm: Array, tap: bool) -> Array:
	var r0: PackedInt64Array = r[0]
	var r1: PackedInt64Array = r[1]
	var r2: PackedInt64Array = r[2]
	var r3: PackedInt64Array = r[3]
	var kc := r0.size()
	var o0 := PackedInt64Array(); o0.resize(kc)
	var o1 := PackedInt64Array(); o1.resize(kc)
	var o2 := PackedInt64Array(); o2.resize(kc)
	var o3 := PackedInt64Array(); o3.resize(kc)
	for k in kc:
		var a0 := r0[k]
		var a1 := r1[k]
		var c0 := r2[k]
		var c1 := r3[k]
		var np0 := (a0 << 1) | ((a1 >> 63) & 1)
		var np1 := (a1 << 1) | ((a0 >> 63) & 1)
		var nm0 := ((c0 >> 1) & MAXP) | ((c1 & 1) << 63)
		var nm1 := ((c1 >> 1) & MAXP) | ((c0 & 1) << 63)
		if tap:
			var X: Array = cm[k][0]
			var x0: int = X[0]
			var x1: int = X[1]
			var q0 := a0 & ~x0
			var q1 := a1 & ~x1
			nm0 |= ((q0 >> 1) & MAXP) | ((q1 & 1) << 63)
			nm1 |= ((q1 >> 1) & MAXP) | ((q0 & 1) << 63)
			var u0 := c0 & ~x0
			var u1 := c1 & ~x1
			np0 |= (u0 << 1) | ((u1 >> 63) & 1)
			np1 |= (u1 << 1) | ((u0 >> 63) & 1)
		o0[k] |= np0; o1[k] |= np1; o2[k] |= nm0; o3[k] |= nm1
	if tap:
		for k in kc:
			for mp in cm[k][1]:
				var b0: int = mp[0]
				var o: int = mp[1]
				var tb0: int = mp[2]
				var sg: int = mp[3]
				for dd in 2:
					var src: int
					if dd == 0:
						src = r0[k] if b0 < 64 else r1[k]
					else:
						src = r2[k] if b0 < 64 else r3[k]
					if (src >> (b0 & 63)) & 1 == 1:
						var nd := sg if dd == 0 else -sg
						var tb := posmod(tb0 + (1 if nd > 0 else -1), N)
						if nd > 0:
							if tb < 64: o0[o] |= 1 << tb
							else: o1[o] |= 1 << (tb - 64)
						else:
							if tb < 64: o2[o] |= 1 << tb
							else: o3[o] |= 1 << (tb - 64)
	return [o0, o1, o2, o3]
