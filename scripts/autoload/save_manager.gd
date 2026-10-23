extends Node

const SLOT_COUNT := 4

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")


func pack(state: Dictionary) -> String:
	var raw := JSON.stringify(state).to_utf8_buffer()
	var gz := raw.compress(FileAccess.COMPRESSION_GZIP)
	return Marshalls.raw_to_base64(gz)


func unpack(b64: String) -> Dictionary:
	if b64 == "":
		return {}
	var gz := Marshalls.base64_to_raw(b64)
	var raw := gz.decompress_dynamic(4 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var parsed = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func save_slot(slot: int, quiet: bool = false) -> bool:
	var b64 := pack(GameState.to_save())
	var key := "songgame_slot_%d" % slot
	var path := "user://saves/slot_%d.txt" % slot
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(b64)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try{localStorage.setItem('%s','%s');1}catch(e){0}" % [key, b64])
	if not quiet:
		GameState.last_event = "已写入%s。" % slot_name(slot)
		EventBus.state_changed.emit()
	return true


func load_slot(slot: int) -> bool:
	var b64 := _read(slot)
	if b64 == "":
		GameState.last_event = "%s是空的。" % slot_name(slot)
		EventBus.state_changed.emit()
		return false
	var data := unpack(b64)
	if data.is_empty() or not GameState.from_save(data):
		GameState.last_event = "存档损坏。"
		EventBus.state_changed.emit()
		return false
	GameState.last_event = "读入%s。" % slot_name(slot)
	EventBus.state_changed.emit()
	return true


func has_slot(slot: int) -> bool:
	return _read(slot) != ""


func has_any() -> bool:
	for i in SLOT_COUNT:
		if has_slot(i):
			return true
	return false


func newest_slot() -> int:
	if has_slot(0):
		return 0
	for i in range(1, SLOT_COUNT):
		if has_slot(i):
			return i
	return -1


func slot_name(slot: int) -> String:
	if slot == 0:
		return "自动存档"
	return "存档槽%s" % ["一", "二", "三"][clampi(slot, 1, 3) - 1]


func _read(slot: int) -> String:
	var key := "songgame_slot_%d" % slot
	if OS.has_feature("web"):
		var web = JavaScriptBridge.eval("localStorage.getItem('%s') || ''" % key)
		if web is String and web != "":
			return web
	var path := "user://saves/slot_%d.txt" % slot
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()
