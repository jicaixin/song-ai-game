extends Node

const PAPER := Color("f4efe4")
const PAPER_DEEP := Color("14383f")
const INK := Color("f4efe4")
const WOOD := Color("c6a15a")
const CINNABAR := Color("a33b2b")
const CELADON := Color("1c4c56")
const INK_SOFT := Color("d7cbb6")
const TEAL := Color("10282e")

var theme: Theme
var font: Font
var banner_font: Font

func _ready() -> void:
	font = _load_font(false)
	banner_font = _load_font(true)
	theme = _build_theme()
	get_tree().root.theme = theme
	# Web builds cannot see OS fonts. The engine default only covers Latin,
	# so any control that misses the theme still needs this face.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 18
	DisplayServer.window_set_title("我带着AI穿越大宋")


func _load_font(msdf: bool) -> Font:
	# Raw bytes, not the imported face. The importer stored a font with
	# antialiasing off, and the editor's system fallback hid missing glyphs.
	var ff := FontFile.new()
	ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ff.hinting = TextServer.HINTING_LIGHT
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	ff.oversampling = 0.0
	ff.allow_system_fallback = false
	if msdf:
		ff.multichannel_signed_distance_field = true
		ff.msdf_pixel_range = 8
		ff.msdf_size = 48
	var bytes := FileAccess.get_file_as_bytes("res://art/fonts/ui_zh.bytes")
	ff.data = bytes
	if bytes.is_empty() or not ff.has_char("我".unicode_at(0)):
		push_error("中文字体缺失或没有汉字")
		return ThemeDB.fallback_font
	return ff


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 18
	var normal := _box(CELADON, WOOD, 3)
	var hover := _box(Color("245e6a"), WOOD, 3)
	var pressed := _box(Color("0e3036"), WOOD, 3)
	var disabled := _box(Color("1a3338"), Color("6d5b3e"), 3)
	for kind in ["Button"]:
		t.set_stylebox("normal", kind, normal)
		t.set_stylebox("hover", kind, hover)
		t.set_stylebox("pressed", kind, pressed)
		t.set_stylebox("focus", kind, hover)
		t.set_stylebox("disabled", kind, disabled)
		t.set_color("font_color", kind, INK)
		t.set_color("font_hover_color", kind, INK)
		t.set_color("font_pressed_color", kind, INK)
		t.set_color("font_focus_color", kind, INK)
		t.set_color("font_disabled_color", kind, Color("8d8070"))
		t.set_font("font", kind, font)
		t.set_font_size("font_size", kind, 18)
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", font)
	t.set_font_size("font_size", "Label", 18)
	t.set_stylebox("panel", "Panel", _box(Color("10282ee0"), WOOD, 3))
	t.set_stylebox("panel", "PanelContainer", _box(Color("10282ee0"), WOOD, 3))
	return t


func _box(bg: Color, border: Color, radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func cinnabar_button(text: String, radius: int = 3) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var base := _box(CINNABAR, Color("e6c27a"), radius)
	var hover := _box(Color("b74b3a"), Color("e6c27a"), radius)
	var pressed := _box(Color("8c2e24"), Color("e6c27a"), radius)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", base)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	return b
