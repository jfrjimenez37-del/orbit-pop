class_name Duel
## Turn-based duels without servers. A duel is a code that carries the run seed, the score to
## beat and the challenger's name: ORBIT-XXXXXXXXXXXX-NAME. Both players play the SAME run
## (same seed for every obstacle, coin and bubble) with NO abilities; the higher score wins.
## Shared by WhatsApp etc.; the friend copies the message and pastes it in DUEL. The checksum
## stops casual edits of the score (a friendly game, not an anti-cheat system).
## Nobody loses coins: playing a friend's duel pays a little, winning pays more (a few a day).

const PREFIX := "ORBIT-"
const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"   # Crockford base32 (no I, L, O, U)
const VERSION := 1
const SEED_BITS := 22
const SCORE_BITS := 14
const CHECK_BITS := 22
const CODE_LEN := 12            # 2 + 22 + 14 + 22 = 60 bits = 12 base32 characters
const NAME_MAX := 10
const SALT := "orbitpop-duel-v1"
const RECENT_AVG := 12.0        # fixed difficulty for duels (no adaptive shift)
const REWARD_WIN := 50
const REWARD_TIE := 25
const REWARD_LOSS := 10
const REWARDS_PER_DAY := 3
const KEEP := 40                # codes remembered (played / created)


## A-Z 0-9 only, no accents, at most NAME_MAX characters ("PLAYER" when empty).
static func clean_name(n: String) -> String:
	var map := {"Á": "A", "À": "A", "Â": "A", "Ã": "A", "Ä": "A", "É": "E", "È": "E", "Ê": "E", "Ë": "E",
		"Í": "I", "Ì": "I", "Î": "I", "Ï": "I", "Ó": "O", "Ò": "O", "Ô": "O", "Õ": "O", "Ö": "O",
		"Ú": "U", "Ù": "U", "Û": "U", "Ü": "U", "Ñ": "N", "Ç": "C"}
	var out := ""
	for ch in n.strip_edges().to_upper():
		var c: String = map.get(ch, ch)
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			out += c
		if out.length() >= NAME_MAX:
			break
	return out if out != "" else "PLAYER"


## FNV-1a (32 bit): our own hash, so codes stay valid across engine versions.
static func _check(seed_value: int, score: int, name: String) -> int:
	var h := 2166136261
	for b in ("%s|%d|%d|%s" % [SALT, seed_value, score, name]).to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h & ((1 << CHECK_BITS) - 1)


static func encode(seed_value: int, score: int, name: String) -> String:
	var s := seed_value & ((1 << SEED_BITS) - 1)
	var sc := clampi(score, 0, (1 << SCORE_BITS) - 1)
	var nm := clean_name(name)
	var v := VERSION
	v = (v << SEED_BITS) | s
	v = (v << SCORE_BITS) | sc
	v = (v << CHECK_BITS) | _check(s, sc, nm)
	var code := ""
	for i in CODE_LEN:
		code = ALPHABET[v & 31] + code
		v >>= 5
	return PREFIX + code + "-" + nm


## Finds a duel code anywhere in `text` (a whole pasted message is fine).
## Returns {seed, score, name, code} or {} when there is none / it was edited.
static func decode(text: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("ORBIT-([0-9A-Z]{%d})-([0-9A-Z]{1,%d})" % [CODE_LEN, NAME_MAX])
	var m := re.search(text.to_upper())
	if m == null:
		return {}
	var v := 0
	for ch in m.get_string(1):
		var d := ALPHABET.find(ch)
		if d < 0:
			return {}
		v = (v << 5) | d
	var check := v & ((1 << CHECK_BITS) - 1)
	v >>= CHECK_BITS
	var score := v & ((1 << SCORE_BITS) - 1)
	v >>= SCORE_BITS
	var s := v & ((1 << SEED_BITS) - 1)
	v >>= SEED_BITS
	var nm := m.get_string(2)
	if v != VERSION or check != _check(s, score, nm):
		return {}
	return {"seed": s, "score": score, "name": nm, "code": m.get_string(0)}


## "win" / "tie" / "lose" for my score against the code's score.
static func outcome(mine: int, theirs: int) -> String:
	return "win" if mine > theirs else ("tie" if mine == theirs else "lose")


static func reward(result: String) -> int:
	return {"win": REWARD_WIN, "tie": REWARD_TIE, "lose": REWARD_LOSS}[result]


static func new_seed(rng_value: int) -> int:
	return rng_value & ((1 << SEED_BITS) - 1)
