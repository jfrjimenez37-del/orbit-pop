class_name Events
## Weekly event: a different kind of run every week (Monday to Sunday, US Pacific time, like the
## daily challenge), the same run for everyone that week and no abilities. Free tries; coins
## for reaching each score goal once a week; the best try goes to the "EVENT" Play Games board
## (its weekly view). Opened from the DUELS / challenges screen.

const SALT := "orbitpop-event-v1"
## only: the patterns allowed (Director names); omega: player speed factor; stage: play the
## whole run on that world (Stages index), no world changes.
const LIST := [
	{"id": "comets", "only": ["comet", "comet_rain"]},
	{"id": "mines", "only": ["mine", "gate", "drift", "saw", "ufo"]},
	{"id": "lasers", "only": ["spoke", "sweep", "cage", "beams"]},
	{"id": "speed", "omega": 1.22},
	{"id": "giants", "stage": 8},
]
## [score to reach in one try, coins] (each paid once a week, in order)
const GOALS := [[25, 40], [60, 80], [120, 150]]


## Week number (weeks start on Monday 00:00 Pacific; day 0 of the epoch was a Thursday).
static func week_key(unix: float) -> int:
	return int(floor((Daily.day_key(unix) + 3) / 7.0))


static func for_week(week: int) -> Dictionary:
	return LIST[posmod(week, LIST.size())]


static func current(unix: float) -> Dictionary:
	return for_week(week_key(unix))


## Seconds until this week's event ends.
static func seconds_left(unix: float) -> int:
	var end_day := (week_key(unix) + 1) * 7 - 3
	return maxi(0, int(end_day * 86400 - (unix + Daily.pacific_offset(unix))))


## The run of that week (same for everyone).
static func seed_for(week: int) -> int:
	var h := 2166136261
	for b in ("%s|%d" % [SALT, week]).to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return Duel.new_seed(h)


## Coins for a try that scored `score`, given how many goals were already paid this week.
## Returns [coins, goals paid after this try].
static func pay_for(score: int, paid: int) -> Array:
	var coins := 0
	var n := paid
	while n < GOALS.size() and score >= int(GOALS[n][0]):
		coins += int(GOALS[n][1])
		n += 1
	return [coins, n]
