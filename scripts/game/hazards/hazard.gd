class_name Hazard
extends Node2D
## Base for everything that can kill the player. Hazards are fully deterministic
## functions of game time, so the very same `danger()` drives both collisions and
## the fairness checker (Survival). Local origin = planet center.

var t_spawn := 0.0
var t_danger_start := 0.0
var t_danger_end := 0.0
var t_end := 0.0
var scored := false
var min_clear := INF
var t := 0.0  # last game time seen (for drawing)
var home_k := 0              # orbit whose planet this hazard belongs to
var home := Vector2.ZERO     # that planet's center (world space)


func set_home(k: int) -> void:
	home_k = mini(k, Orbit.count() - 1)
	home = Orbit.center(home_k)


## Danger interval on orbit k caused by a round object of radius `rr` at world point p.
static func point_danger(p: Vector2, rr: float, k: int, out: Array) -> void:
	var v := p - Orbit.center(k)
	var d := v.length()
	var kk := mini(k, Orbit.rmax_k.size() - 1)
	if d < 1.0 or d >= Orbit.rmax_k[kk] + rr or d <= Orbit.rmin_k[kk] - rr:
		return
	var phi := v.angle()
	var R := Orbit.radius(k, phi)
	if Orbit.is_round(k):
		if absf(d - R) >= rr:
			return
		var c := (R * R + d * d - rr * rr) / (2.0 * R * d)
		if c >= 1.0:
			return
		out.append(Vector2(phi, acos(clampf(c, -1.0, 1.0))))
		return
	# Non-round orbit (ellipse, offset circle, morph): the radius changes along the way, so a
	# local circle is off by a few px. Use the local slope: with r(phi + x) ~ R + sl * x and
	# cos x ~ 1 - x^2 / 2, |orbit(x) - p| = rr is a quadratic in x.
	var S := Orbit.max_slope(k)
	if absf(d - R) * R / sqrt(R * R + S * S) >= rr:
		return   # the orbit can't get within rr of p anywhere near phi
	var sl := (Orbit.radius(k, phi + 0.02) - Orbit.radius(k, phi - 0.02)) / 0.04
	var qa := sl * sl + R * d
	var qb := 2.0 * sl * (R - d)
	var qc := (R - d) * (R - d) - rr * rr
	var disc := qb * qb - 4.0 * qa * qc
	if disc <= 0.0:
		return
	var sq := sqrt(disc)
	var x1 := (-qb - sq) / (2.0 * qa)
	var x2 := (-qb + sq) / (2.0 * qa)
	# small pad covers the curvature the linear model ignores (keeps it on the player's side)
	var pad := 0.004 + 0.02 * (x2 - x1)
	out.append(Vector2(wrapf(phi + (x1 + x2) * 0.5, -PI, PI), (x2 - x1) * 0.5 + pad))


## Danger on orbit k from a thick segment p0-p1 (half thickness w), tested on the orbit
## samples; each inside sample covers its share of the orbit plus a small pad.
static func segment_danger(p0: Vector2, p1: Vector2, w: float, k: int, out: Array) -> void:
	var smp := Orbit.samples(k)
	var seg := p1 - p0
	var len2 := maxf(seg.length_squared(), 0.001)
	var w2 := w * w
	var half := TAU / Orbit.SAMPLES * 0.5 + 0.01
	for i in range(0, smp.size(), 3):
		var q := Vector2(smp[i + 1], smp[i + 2]) - p0
		var u := clampf(q.dot(seg) / len2, 0.0, 1.0)
		if (q - seg * u).length_squared() < w2:
			out.append(Vector2(smp[i], half))


## Appends Vector2(center_angle, half_width) for every dangerous interval of orbit `k` at `time`.
func danger(_time: float, _out: Array, _k := 0) -> void:
	pass


func tick(time: float) -> void:
	t = time
	queue_redraw()


func is_done(time: float) -> bool:
	return time > t_end


## Clearance between the player and the closest danger edge (rad, <0 = hit, INF = harmless).
func clearance(time: float, angle: float, k := 0) -> float:
	var iv: Array = []
	danger(time, iv, k)
	var best := INF
	for v in iv:
		best = minf(best, absf(Orbit.ang_diff(angle, v.x)) - v.y)
	return best


func ring_pos(a: float, k := 0) -> Vector2:
	return Orbit.pos(k, a)


## Where to show feedback for this hazard (ring angle).
func label_angle(_time: float) -> float:
	return 0.0
