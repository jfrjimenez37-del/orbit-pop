@tool
extends EditorPlugin
## project.godot only stores which plugins are enabled. When it is replaced (for example by
## the copy on GitHub), the Android plugins installed locally (AdMob, Billing, Share) would
## silently turn off and the exported game would have no ads or purchases. This turns every
## plugin found under res://addons (and plugin folders at the project root) back on.
## It also keeps two permissions out of the Android build: the notification plugin declares
## them, the game does not need them, and Play only allows them for some kinds of apps.

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_enable_all.call_deferred()
	_export = PermissionFilter.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	if _export:
		remove_export_plugin(_export)
		_export = null


func _enable_all() -> void:
	var turned_on: Array = []
	for cfg in _plugin_cfgs():
		if cfg.get_base_dir().get_file() == "orbitpop_plugins":
			continue
		if not EditorInterface.is_plugin_enabled(cfg):
			EditorInterface.set_plugin_enabled(cfg, true)
			if EditorInterface.is_plugin_enabled(cfg):
				turned_on.append(cfg.get_base_dir().get_file())
	if not turned_on.is_empty():
		print("ORBIT POP: plugins re-enabled: ", ", ".join(turned_on))


func _plugin_cfgs() -> Array:
	var out: Array = []
	for base in ["res://addons", "res://"]:
		for d in DirAccess.get_directories_at(base):
			var cfg: String = str(base).path_join(d).path_join("plugin.cfg")
			if FileAccess.file_exists(cfg) and not out.has(cfg):
				out.append(cfg)
	return out


## Removes permissions merged in from plugin libraries (Gradle manifest merger, tools:node).
##   REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: Play restricts it to apps that truly need it.
##   SCHEDULE_EXACT_ALARM: reminders do not need exact times (the plugin falls back).
class PermissionFilter extends EditorExportPlugin:
	const REMOVE := ["android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
		"android.permission.SCHEDULE_EXACT_ALARM"]

	func _get_name() -> String:
		return "OrbitPopPermissionFilter"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var out := ""
		for perm in REMOVE:
			out += '<uses-permission android:name="%s" tools:node="remove" />\n' % perm
		return out
