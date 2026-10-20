class_name TestBot
## Automated player used by tests: taps only when continuing would be unsurvivable.
## A tap reverses, or switches orbit inside a crossing window (same rule as the game).

static func decide(main: Node) -> bool:
	var p = main.player
	var rate: float = main.director.omega_rate(main.gt)
	if Survival.can_survive(main.hazards, main.gt, p.angle, p.dir, p.omega, false, p.orbit, Survival.MARGIN, Survival.TAP_GAP, 0.0, rate):
		return false
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	return Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0], Survival.MARGIN, Survival.TAP_GAP, 0.0, rate)
