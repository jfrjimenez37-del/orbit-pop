class_name Diag
## In-game diagnostics: the last events of ads, Play Games, store and review plugins, with
## their error codes. Shown by tapping the version 5 times in Settings (and copied to the
## clipboard) so problems on a real phone can be read without a computer.

const MAX_LINES := 60
static var lines: Array = []
static var _t0 := Time.get_ticks_msec()


static func log(msg: String) -> void:
	lines.append("%5.1f %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, msg])
	if lines.size() > MAX_LINES:
		lines.pop_front()
	print("[diag] ", msg)


## "code message" of an AdMob / UMP error object (or whatever came in).
static func err(e) -> String:
	if e is Object and e.has_method("get_code"):
		return "%s %s" % [str(e.call("get_code")), str(e.call("get_message")) if e.has_method("get_message") else ""]
	return str(e)


static func text() -> String:
	return "ORBIT POP V%s %s\n%s" % [ProjectSettings.get_setting("application/config/version", ""), OS.get_name(), "\n".join(lines)]
