@tool
extends EditorPlugin
## project.godot only stores which plugins are enabled. When it is replaced (for example by
## the copy on GitHub), the Android plugins installed locally (AdMob, Billing, Share) would
## silently turn off and the exported game would have no ads or purchases. This turns every
## plugin found under res://addons (and plugin folders at the project root) back on.


func _enter_tree() -> void:
	_enable_all.call_deferred()


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
