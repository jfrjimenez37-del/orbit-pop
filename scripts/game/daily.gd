class_name Daily
## Daily challenge: the same run for every player on a given day (seed from the date), no
## abilities, like a duel. A few free tries a day, one or two more with a video. The best try
## goes to the "DAILY" Play Games board, whose TODAY view resets every day.
## The day follows US Pacific time (where Play Games daily boards reset), so the whole US gets
## a new challenge in the evening and everyone in the world shares the same run.

const FREE_TRIES := 3
const VIDEO_TRIES := 2
const REWARD_FIRST := 30        # coins for the first finished try of the day
const SALT := "orbitpop-daily-v1"


## Day number in US Pacific time (PST UTC-8, PDT UTC-7 from the 2nd Sunday of March 2:00
## to the 1st Sunday of November 2:00).
static func day_key(unix: float) -> int:
	var off := -8 * 3600
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + off)
	if _is_pdt(d):
		off = -7 * 3600
	return int(floor((unix + off) / 86400.0))


static func _is_pdt(d: Dictionary) -> bool:
	var m: int = d["month"]
	if m < 3 or m > 11:
		return false
	if m > 3 and m < 11:
		return true
	# weekday of day 1 of the month (0 = Sunday)
	var first := Time.get_unix_time_from_datetime_dict({"year": d["year"], "month": m, "day": 1, "hour": 12, "minute": 0, "second": 0})
	var wd1: int = Time.get_datetime_dict_from_unix_time(first)["weekday"]
	var first_sunday := 1 + (7 - wd1) % 7
	var change := first_sunday + 7 if m == 3 else first_sunday   # 2nd Sunday of March / 1st of November
	var after: bool = d["day"] > change or (d["day"] == change and d["hour"] >= 2)
	return after if m == 3 else not after


## The run of that day (same for everyone).
static func seed_for(day: int) -> int:
	var h := 2166136261
	for b in ("%s|%d" % [SALT, day]).to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return Duel.new_seed(h)
