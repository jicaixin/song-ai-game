extends Node

var enabled := false

func _ready() -> void:
	if OS.has_feature("web"):
		var search = JavaScriptBridge.eval("window.location.search || ''")
		if search is String and ("debug=1" in search):
			enabled = true
	if OS.get_cmdline_user_args().has("--debug-ui"):
		enabled = true


func publish(data: Dictionary) -> void:
	if not enabled or not OS.has_feature("web"):
		return
	var raw := JSON.stringify(data)
	var b64 := Marshalls.raw_to_base64(raw.to_utf8_buffer())
	var js := "window.__song = JSON.parse(new TextDecoder('utf-8').decode(Uint8Array.from(atob('%s'), function(c){return c.charCodeAt(0);})));" % b64
	JavaScriptBridge.eval(js)
