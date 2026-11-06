class_name Analytics
extends Node
## Game analytics through the GameAnalytics REST API v2 (no Android plugin needed).
## Keys live in res://scripts/services/analytics_keys.gd (not in the public repository: copy
## analytics_keys.example.gd, fill it in). Without keys, on PC, or when the player turns
## "SHARE STATS" off in Settings, nothing is sent (events are only counted for DIAG).
## Events wait in a queue saved to disk, go out in batches every FLUSH_EVERY s and when the app
## is paused, and are kept for a retry if the network fails.
## Player id: a random UUID made on the first launch (not the advertising id).

const URL := "https://api.gameanalytics.com/v2/%s/%s"
const SDK := "rest api v2"
const KEYS_PATH := "res://scripts/services/analytics_keys.gd"
const QUEUE_PATH := "user://analytics_queue.json"
const FLUSH_EVERY := 20.0
const BATCH := 100
const MAX_QUEUE := 1000
const NEW_SESSION_AFTER := 20.0   # seconds in the background that end a session

var game_key := ""
var secret_key := ""
var user_id := ""
var session_id := ""
var session_num := 0
var session_start := 0.0
var build := ""
var queue: Array = []
var sent := 0
var dropped := 0
var last_status := "-"
var server_offset := 0
var opted_out := false
var force_send := false            # tests: send on PC too
## Tests replace the HTTP call: func(url: String, headers: PackedStringArray, body: String) -> void,
## then call _on_response(code, body).
var sender: Callable
var clock: Callable = func() -> float: return Time.get_unix_time_from_system()

var _save: Node
var _http: HTTPRequest
var _in_flight: Array = []
var _timer := 0.0
var _paused_at := -1.0


func start(save: Node) -> void:
	_save = save
	if ResourceLoader.exists(KEYS_PATH):
		var keys = load(KEYS_PATH)
		game_key = str(keys.GAME_KEY)
		secret_key = str(keys.SECRET_KEY)
	if str(_save.analytics_id) == "":
		_save.analytics_id = uuid()
		_save.save_data()
	user_id = _save.analytics_id
	opted_out = not bool(_save.share_stats)
	build = str(ProjectSettings.get_setting("application/config/version", ""))
	_load_queue()
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(func(_r, code, _h, body): _on_response(code, body.get_string_from_utf8()))
	_close_previous_session()
	_begin_session()
	Diag.log("analytics: %s, %d queued" % [status_text(), queue.size()])


func status_text() -> String:
	if opted_out:
		return "off (player)"
	if game_key == "" or secret_key == "":
		return "no keys"
	if not _can_send():
		return "on (PC: not sent)"
	return "on"


func _can_send() -> bool:
	return not opted_out and game_key != "" and secret_key != "" and (OS.has_feature("android") or force_send)


## The player's choice in Settings.
func set_opt_out(off: bool) -> void:
	opted_out = off
	if off:
		queue.clear()
		_save_queue()


# ------------------------------------------------------------------ events

## A design event: "Part1:Part2:..." (up to 5 parts), optional numeric value.
func design(event_id: String, value = null) -> void:
	var ev := {"category": "design", "event_id": _id(event_id)}
	if value != null:
		ev["value"] = float(value)
	_add(ev)


## status: "Start", "Complete" or "Fail"; p1..p3 the progression levels (mode, world...).
func progression(status: String, p1: String, p2 := "", p3 := "", score := -1) -> void:
	var parts := [status, p1]
	if p2 != "":
		parts.append(p2)
		if p3 != "":
			parts.append(p3)
	var ev := {"category": "progression", "event_id": _id(":".join(parts))}
	if score >= 0 and status != "Start":
		ev["score"] = score
	_add(ev)


## flow: "Source" (earned) or "Sink" (spent); currency "Coins".
func resource(flow: String, currency: String, amount: float, item_type: String, item_id: String) -> void:
	if amount <= 0.0:
		return
	_add({"category": "resource", "event_id": _id("%s:%s:%s:%s" % [flow, currency, item_type, item_id]), "amount": amount})


## A real-money purchase: amount in cents.
func business(item_type: String, item_id: String, cents: int, currency := "USD") -> void:
	var n := int(_save.stats.get("purchases", 0)) + 1
	_save.stats["purchases"] = n
	_add({"category": "business", "event_id": _id(item_type + ":" + item_id), "amount": cents, "currency": currency,
		"transaction_num": n})


func error(severity: String, message: String) -> void:
	_add({"category": "error", "severity": severity, "message": message.left(8000)})


func _add(ev: Dictionary) -> void:
	if opted_out:
		return
	var e := _annotations()
	e.merge(ev, true)
	queue.append(e)
	if queue.size() > MAX_QUEUE:
		queue = queue.slice(queue.size() - MAX_QUEUE)
		dropped += 1


func _annotations() -> Dictionary:
	var model := OS.get_model_name()
	return {"v": 2, "user_id": user_id, "client_ts": int(clock.call()) + server_offset, "sdk_version": SDK,
		"os_version": "android " + _os_version(), "manufacturer": model.split(" ")[0].to_lower() if model != "" else "unknown",
		"device": model.to_lower() if model != "" else "unknown", "platform": "android", "session_id": session_id,
		"session_num": session_num, "build": build}


func _os_version() -> String:
	var v := OS.get_version()
	var m := RegEx.create_from_string("^[0-9]+(\\.[0-9]+){0,2}").search(v)
	return m.get_string() if m else "0"


## GameAnalytics ids: up to 5 parts of letters, digits and _ (other characters become _).
func _id(s: String) -> String:
	var parts := s.split(":")
	var out: Array = []
	var re := RegEx.create_from_string("[^A-Za-z0-9_]")
	for p in parts.slice(0, 5):
		var c := re.sub(str(p), "_", true).left(32)
		out.append(c if c != "" else "_")
	return ":".join(out)


# ------------------------------------------------------------------ sessions

func _begin_session() -> void:
	session_id = uuid()
	session_num = int(_save.sessions)
	session_start = clock.call()
	_save.analytics_session = {"id": session_id, "start": session_start, "last": session_start, "num": session_num}
	_add({"category": "user"})


func _end_session(at: float) -> void:
	var length := maxi(0, int(at - session_start))
	_add({"category": "session_end", "length": length})


## The app was killed in the background last time: close that session now.
func _close_previous_session() -> void:
	var s: Dictionary = _save.analytics_session
	if s.is_empty():
		return
	var keep := [session_id, session_start, session_num]
	session_id = str(s.get("id", ""))
	session_start = float(s.get("start", 0.0))
	session_num = int(s.get("num", 0))
	if session_id != "":
		_end_session(float(s.get("last", session_start)))
	session_id = keep[0]; session_start = keep[1]; session_num = keep[2]
	_save.analytics_session = {}


func _notification(what: int) -> void:
	if _save == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if _paused_at < 0.0:
				_paused_at = clock.call()
				_save.analytics_session["last"] = _paused_at
				_save.save_data()
				_save_queue()
				flush()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if _paused_at >= 0.0:
				if clock.call() - _paused_at > NEW_SESSION_AFTER:
					_end_session(_paused_at)
					_begin_session()
				_paused_at = -1.0
		NOTIFICATION_WM_CLOSE_REQUEST:
			_end_session(clock.call())
			_save.analytics_session = {}
			_save_queue()


# ------------------------------------------------------------------ sending

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_EVERY:
		_timer = 0.0
		if _save != null:
			_save.analytics_session["last"] = clock.call()
		flush()


func flush() -> void:
	if not _can_send() or queue.is_empty() or not _in_flight.is_empty():
		return
	_in_flight = queue.slice(0, BATCH)
	var body := JSON.stringify(_in_flight)
	var headers := PackedStringArray(["Content-Type: application/json", "Authorization: " + hmac_sign(body, secret_key)])
	var url := URL % [game_key, "events"]
	if sender.is_valid():
		sender.call(url, headers, body)
	else:
		var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
		if err != OK:
			_in_flight = []
			last_status = "request error %d" % err


func _on_response(code: int, body: String) -> void:
	var n := _in_flight.size()
	last_status = str(code)
	if code == 200:
		queue = queue.slice(n)
		sent += n
	elif code == 400 or code == 413:
		# GameAnalytics refused this batch (bad data): drop it, do not retry it forever
		queue = queue.slice(n)
		dropped += n
		Diag.log("analytics: batch refused %d %s" % [code, body.left(200)])
	# other codes (0 = no network, 5xx): keep the events for the next try
	_in_flight = []
	_save_queue()


## HMAC-SHA256 of the body with the secret key, base64 (GameAnalytics "Authorization" header).
static func hmac_sign(body: String, secret: String) -> String:
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, secret.to_utf8_buffer())
	ctx.update(body.to_utf8_buffer())
	return Marshalls.raw_to_base64(ctx.finish())


static func uuid() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(queue))


func _load_queue() -> void:
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var f := FileAccess.open(QUEUE_PATH, FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data is Array:
			queue = data.map(_ints)


## JSON reads every number back as a float (21 -> 21.0), and GameAnalytics refuses a batch
## with "client_ts": 1793926084.0 or "length": 21.0 (400). Whole numbers go back to int.
static func _ints(ev) -> Variant:
	if not ev is Dictionary:
		return ev
	var out := {}
	for k in ev:
		var v = ev[k]
		out[k] = int(v) if v is float and v == floorf(v) and absf(v) < 1e15 else v
	return out
