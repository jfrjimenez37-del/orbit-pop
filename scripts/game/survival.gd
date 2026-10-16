class_name Survival
## Fairness checker. Simulates every reachable (angle, direction) state of the player
## through the future danger timeline of the given hazards, assuming a human-limited
## tap rate and inflated hitboxes. If no state survives, the pattern is unfair.
##
## The ring is split into 128 buckets stored as two 64-bit bitsets per direction.
## The time step equals the time needed to travel one bucket, so moving is a bit rotation.

const N := 128
const BW := TAU / N
const TAP_GAP := 0.12          # fastest tapping assumed (s)
const MARGIN := BW * 0.5 + 0.03
const MAXP := 0x7FFFFFFFFFFFFFFF


static func _rotl(lo: int, hi: int) -> Array:
	return [(lo << 1) | ((hi >> 63) & 1), (hi << 1) | ((lo >> 63) & 1)]


static func _rotr(lo: int, hi: int) -> Array:
	return [((lo >> 1) & MAXP) | ((hi & 1) << 63), ((hi >> 1) & MAXP) | ((lo & 1) << 63)]


## Returns [lo, hi] mask of dangerous buckets at time t.
static func danger_mask(hazards: Array, t: float, margin := MARGIN) -> Array:
	var lo := 0
	var hi := 0
	var iv: Array = []
	for h in hazards:
		iv.clear()
		h.danger(t, iv)
		for v in iv:
			var hw: float = v.y + margin
			if hw >= PI:
				return [-1, -1]
			var b0 := ceili((v.x - hw) / BW)
			var b1 := floori((v.x + hw) / BW)
			for b in range(b0, b1 + 1):
				var k := posmod(b, N)
				if k < 64:
					lo |= 1 << k
				else:
					hi |= 1 << (k - 64)
	return [lo, hi]


static func bucket(angle: float) -> int:
	return posmod(roundi(angle / BW), N)


## True if some tap sequence lets the player survive every hazard in `hazards`.
## `first_tap`: whether a reversal is allowed right now (step 0).
static func can_survive(hazards: Array, t_now: float, angle: float, dir: int, omega: float, first_tap := true) -> bool:
	var horizon := t_now
	for h in hazards:
		horizon = maxf(horizon, h.t_danger_end)
	if horizon <= t_now:
		return true
	var dt := BW / omega
	var steps := ceili((horizon - t_now) / dt) + 1
	var k := maxi(1, roundi(TAP_GAP / dt))
	var b := bucket(angle)
	var p_lo := 0; var p_hi := 0  # moving +1 (angle increasing)
	var m_lo := 0; var m_hi := 0  # moving -1
	var bit_lo := (1 << b) if b < 64 else 0
	var bit_hi := (1 << (b - 64)) if b >= 64 else 0
	if dir > 0:
		p_lo = bit_lo; p_hi = bit_hi
	else:
		m_lo = bit_lo; m_hi = bit_hi
	var d0 := danger_mask(hazards, t_now)
	p_lo &= ~d0[0]; p_hi &= ~d0[1]; m_lo &= ~d0[0]; m_hi &= ~d0[1]
	if (p_lo | p_hi | m_lo | m_hi) == 0:
		return false
	for s in steps:
		var t := t_now + (s + 1) * dt
		var a := _rotl(p_lo, p_hi)
		var c := _rotr(m_lo, m_hi)
		var np_lo: int = a[0]; var np_hi: int = a[1]
		var nm_lo: int = c[0]; var nm_hi: int = c[1]
		if s % k == 0 and (s > 0 or first_tap):
			var a2 := _rotl(m_lo, m_hi)   # was moving -1, taps, now moves +1
			var c2 := _rotr(p_lo, p_hi)
			np_lo |= a2[0]; np_hi |= a2[1]
			nm_lo |= c2[0]; nm_hi |= c2[1]
		var d := danger_mask(hazards, t)
		p_lo = np_lo & ~d[0]; p_hi = np_hi & ~d[1]
		m_lo = nm_lo & ~d[0]; m_hi = nm_hi & ~d[1]
		if (p_lo | p_hi | m_lo | m_hi) == 0:
			return false
	return true
