extends Node

const PAPER := Color("f4ead2")
const PAPER_DEEP := Color("f3e6c8")
const INK := Color("1c1612")
const WOOD := Color("6b3a24")
const CINNABAR := Color("a33b2b")
const CELADON := Color("2f6d5a")
const INK_SOFT := Color("3a3128")

var theme: Theme
var font: Font

func _ready() -> void:
	font = _load_font()
	theme = _build_theme()
	get_tree().root.theme = theme
	# Web builds cannot see OS fonts. The engine default only covers Latin,
	# so any control that misses the theme still needs this face.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 12
	DisplayServer.window_set_title("我带着AI穿越大宋")


func _load_font() -> Font:
	# Raw bytes, not the imported CFF face. The importer's .fontdata loaded in
	# the editor (where system fallback hides missing glyphs) and still drew
	# hex boxes in the browser.
	var ff := FontFile.new()
	ff.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ff.hinting = TextServer.HINTING_NONE
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	ff.oversampling = 1.0
	ff.allow_system_fallback = false
	var bytes := FileAccess.get_file_as_bytes("res://art/fonts/ui_zh.bytes")
	ff.data = bytes
	if bytes.is_empty() or not ff.has_char("我".unicode_at(0)):
		push_error("中文字体缺失或没有汉字")
		return ThemeDB.fallback_font
	return ff


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 12
	var normal := _box(PAPER_DEEP, WOOD)
	var hover := _box(PAPER, WOOD)
	var pressed := _box(Color("e4d3b0"), WOOD)
	var disabled := _box(Color("d9d0c0"), Color("8a7b6a"))
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
		t.set_color("font_disabled_color", kind, Color("6d6256"))
		t.set_font("font", kind, font)
		t.set_font_size("font_size", kind, 12)
	t.set_color("font_color", "Label", INK)
	t.set_font("font", "Label", font)
	t.set_font_size("font_size", "Label", 12)
	t.set_stylebox("panel", "Panel", _box(PAPER, WOOD))
	t.set_stylebox("panel", "PanelContainer", _box(PAPER, WOOD))
	return t


func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


func cinnabar_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	var base := _box(CINNABAR, Color("6e241c"))
	var hover := _box(Color("b74b3a"), Color("6e241c"))
	var pressed := _box(Color("8c2e24"), Color("6e241c"))
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", base)
	b.add_theme_color_override("font_color", PAPER)
	b.add_theme_color_override("font_hover_color", PAPER)
	b.add_theme_color_override("font_pressed_color", PAPER)
	b.add_theme_color_override("font_focus_color", PAPER)
	return b
