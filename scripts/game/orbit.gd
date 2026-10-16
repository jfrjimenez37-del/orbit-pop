class_name Orbit
## Shared geometry constants and angle helpers.

const R := 60.0            # orbit radius (px, logical)
const PLANET_R := 29.0     # planet visual radius
const PLAYER_R := 4.0      # player hitbox radius (forgiving: sprite body is ~6px)
const NEAR := 0.13         # rad of clearance that still counts as a near miss


static func ang_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


static func on_ring(a: float, r := R) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


## Half-angle (rad) seen from the center of a circle of radius `rr` sitting on the ring.
static func chord_half(rr: float) -> float:
	return 2.0 * asin(clampf(rr / (2.0 * R), 0.0, 1.0))
