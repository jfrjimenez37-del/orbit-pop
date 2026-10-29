extends Node
## Share the score card through the "godot-share" plugin (godot-sdk-integrations) when present.
## Fallback (PC / no plugin): copy the text to the clipboard. Returns true if the native sheet opened.

var _share: Node


func start() -> void:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == "Share":
			_share = load(c["path"]).new()
			add_child(_share)
			return


func available() -> bool:
	return _share != null


func share_score(text: String, img: Image) -> bool:
	var path := "user://orbitpop_score.png"
	if img:
		img.save_png(path)
	if _share:
		if img:
			_share.call("share_image", ProjectSettings.globalize_path(path), "ORBIT POP", "ORBIT POP", text)
		else:
			_share.call("share_text", "ORBIT POP", "ORBIT POP", text)
		return true
	DisplayServer.clipboard_set(text)
	return false
