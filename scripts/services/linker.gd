class_name Linker
extends Node
## Duel links (https://HOST/duel/?c=ORBIT-...) open the game through the "Deeplink" plugin by
## Cengiz (godot-mobile-plugins/godot-deeplink, AssetLib). Its export.cfg (addons/DeeplinkPlugin)
## adds the Android App Link; the site at HOST proves the link belongs to the game
## (.well-known/assetlinks.json) and is the fallback page for people without the game.
## The plugin is looked up dynamically, so the game builds and runs without it.

signal duel_link(code_text: String)

const HOST := "jfrjimenez37-del.github.io"
const PATH := "/duel/"

var _node: Node
var _last := ""


## The link shared in a duel message.
static func duel_url(code: String) -> String:
	return "https://%s%s?c=%s" % [HOST, PATH, code]


## The duel code inside a link (or "" when it is not a duel link of ours).
static func code_in(url: String) -> String:
	if url.find(HOST + "/duel") < 0:
		return ""
	var d := Duel.decode(url)
	return str(d.get("code", ""))


## The link as text, from the plugin's parts (scheme, host, path, query).
static func url_text(data: Dictionary) -> String:
	var q := str(data.get("query", ""))
	return "%s://%s%s%s" % [data.get("scheme", "https"), data.get("host", ""), data.get("path", ""), "?" + q if q != "" else ""]


func start() -> void:
	var scr: Script = null
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "Deeplink":
			scr = load(c["path"])
	Diag.log("links: plugin %s" % ("yes" if scr != null else "NO"))
	if scr == null or not OS.has_feature("android"):
		return
	_node = scr.new()
	_node.set("scheme", "https")
	_node.set("host", HOST)
	_node.set("path_prefix", "/duel")
	add_child(_node)
	_node.connect("deeplink_received", func(url): _got(url_text(url.get_data())))
	_node.call("initialize")
	# opened from a link while the game was closed: the plugin keeps the last link
	_got.call_deferred(str(_node.call("get_link_url")))


func _got(url: String) -> void:
	if url == "" or url == _last:
		return
	_last = url
	var code := code_in(url)
	Diag.log("links: %s -> %s" % [url.left(80), code if code != "" else "not a duel"])
	if code != "":
		duel_link.emit(code)
		_node.call("clear_data")
