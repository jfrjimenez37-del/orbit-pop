class_name TestBot
## Automated player used by tests: taps only when continuing would be unsurvivable.
## A tap reverses, or switches orbit inside a crossing window (same rule as the game).

static func decide(main: Node) -> bool:
	var p = main.player
	if Survival.can_survive(main.hazards, main.gt, p.angle, p.dir, p.omega, false, p.orbit):
		return false
	var r := Orbit.tap_result(p.angle, p.orbit, p.dir)
	return Survival.can_survive(main.hazards, main.gt, r[2], r[1], p.omega, false, r[0])
