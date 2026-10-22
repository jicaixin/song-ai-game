class_name Kit
extends RefCounted

const MOOD := {
	"think": "thinking",
	"sleepy": "lowpower",
	"disgust": "deadpan",
	"shock": "shocked",
	"happy": "happy",
	"smug": "smug",
	"deadpan": "deadpan",
	"shocked": "shocked",
	"lowpower": "lowpower",
	"serious": "serious",
	"thinking": "thinking",
	"awkward": "awkward",
	"moved": "moved",
	"off": "off",
	"normal": "normal",
}

static var _cache := {}


static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		var cached = _cache[path]
		if cached == null:
			return null
		return cached as Texture2D
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var loaded = load(path)
	_cache[path] = loaded
	return loaded as Texture2D


static func icon(name: String) -> Texture2D:
	return tex("res://ui/icons/png/%s.png" % name)


static func piece(name: String) -> Texture2D:
	return tex("res://ui/components/png/%s.png" % name)


static func label(text: String, variation: String) -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func button(text: String, variation: String) -> Button:
	var node := Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.focus_mode = Control.FOCUS_NONE
	return node


static func panel(variation: String) -> PanelContainer:
	var node := PanelContainer.new()
	node.theme_type_variation = variation
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node


static func state_variation(prefix: String, state: String) -> String:
	if state.is_empty():
		return prefix
	return prefix + state.substr(0, 1).to_upper() + state.substr(1)


static func mood_key(mood: String) -> String:
	return str(MOOD.get(mood, "normal"))


static func portrait_frame(pid: String, expr: String = "normal") -> Texture2D:
	var frame := tex("res://ui/art/portraits/frame/%s_%s_frame_256.png" % [pid, expr])
	if frame == null:
		frame = tex("res://ui/art/portraits/frame/%s_normal_frame_256.png" % pid)
	if frame == null:
		frame = portrait_head(pid, expr)
	return frame


static func portrait_head(pid: String, expr: String = "normal") -> Texture2D:
	var head := tex("res://ui/art/portraits/head/%s_%s_128.png" % [pid, expr])
	if head == null:
		head = tex("res://ui/art/portraits/head/%s_normal_128.png" % pid)
	return head


static func portrait_bust(pid: String, expr: String = "normal") -> Texture2D:
	var bust := tex("res://ui/art/portraits/bust/%s_%s_512.png" % [pid, expr])
	if bust == null:
		bust = tex("res://ui/art/portraits/bust/%s_normal_512.png" % pid)
	return bust


static func portrait_full(pid: String, expr: String = "normal") -> Texture2D:
	var full := tex("res://ui/art/portraits/full/%s_%s.png" % [pid, expr])
	if full == null and expr != "normal":
		full = tex("res://ui/art/portraits/full/%s_normal.png" % pid)
	return full


static func doushabao_frame(mood: String) -> Texture2D:
	return portrait_frame("doushabao", mood_key(mood))


static func emperor_tex(expr: String) -> Texture2D:
	var full := portrait_full("emperor_zhaozhen", expr)
	if full != null:
		return full
	return portrait_bust("emperor_zhaozhen", expr)


static func icon_rect(name: String, px: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = icon(name)
	rect.custom_minimum_size = Vector2(px, px)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return rect
