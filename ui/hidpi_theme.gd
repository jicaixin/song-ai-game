## HiDPI helper for the 《我带着AI穿越大宋》 UI kit (Godot 4.x, Compatibility/Web).
##
## Usage: add as an Autoload (Project Settings > Globals) named "HiDPITheme".
## On screens whose effective UI scale is >= 1.5 (Retina, 2560x1440 browser canvas, ...)
## every StyleBoxTexture / icon in the project theme is swapped for its @2x PNG.
## The @2x texture gets set_size_override(@1x size), so texture_margin_* values and
## all layout stay identical; only the pixel density doubles.
## Alternative for Godot 4.5+/4.6: use theme_hidpi.tres with SVGs imported as DPITexture.
extends Node

@export var theme: Theme
@export var threshold := 1.5

func _ready() -> void:
	if theme == null:
		theme = ThemeDB.get_project_theme()
	if theme == null:
		theme = load("res://ui/theme.tres")
	if effective_scale() >= threshold:
		apply_2x(theme)

func effective_scale() -> float:
	var win := get_window()
	var base := Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width", 1280),
		ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	var stretch: float = min(win.size.x / base.x, win.size.y / base.y)
	return max(stretch, DisplayServer.screen_get_scale())

static var _cache := {}

static func hi(tex: Texture2D) -> Texture2D:
	if tex == null or not tex.resource_path.ends_with(".png"):
		return tex
	var p := tex.resource_path.trim_suffix(".png") + "@2x.png"
	if _cache.has(p):
		return _cache[p]
	if not ResourceLoader.exists(p):
		return tex
	var img: Image = (load(p) as Texture2D).get_image()
	var it := ImageTexture.create_from_image(img)
	it.set_size_override(Vector2i(tex.get_size()))
	_cache[p] = it
	return it

static func apply_2x(t: Theme) -> void:
	for type in t.get_type_list():
		for sb_name in t.get_stylebox_list(type):
			var sb := t.get_stylebox(sb_name, type)
			if sb is StyleBoxTexture:
				sb.texture = hi(sb.texture)
		for icon_name in t.get_icon_list(type):
			t.set_icon(icon_name, type, hi(t.get_icon(icon_name, type)))
