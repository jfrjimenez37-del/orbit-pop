class_name TestBot
## Automated player used by tests: flips only when continuing would be unsurvivable.

static func decide(main: Node) -> bool:
	var p = main.player
	var keep := Survival.can_survive(main.hazards, main.gt, p.angle, p.dir, p.omega, false)
	if keep:
		return false
	return Survival.can_survive(main.hazards, main.gt, p.angle, -p.dir, p.omega, false)
