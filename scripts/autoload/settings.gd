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
	theme = load("res://ui/theme.tres")
	_chain_fallbacks()
	# Window.theme does not cross a CanvasLayer. gui/theme/custom does.
	get_tree().root.theme = theme
	# Web builds cannot see OS fonts. The engine default only covers Latin,
	# so any control that misses the theme still needs this face.
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 15
	DisplayServer.window_set_title("我带着AI穿越大宋")


func _chain_fallbacks() -> void:
	var noto := load("res://ui/fonts/NotoSerifSC-Regular.subset.ttf") as FontFile
	var bold := load("res://ui/fonts/NotoSerifSC-Bold.subset.ttf") as FontFile
	var lxgw := load("res://ui/fonts/LXGWWenKai-Medium.subset.ttf") as FontFile
	var ma := load("res://ui/fonts/MaShanZheng-Regular.subset.ttf") as FontFile
	var zero := load("res://ui/fonts/ideo-zero.ttf") as FontFile
	for face in [noto, bold, lxgw, ma, zero]:
		if face != null:
			face.allow_system_fallback = false
	if zero != null:
		if noto != null:
			noto.fallbacks = [zero]
		if bold != null:
			bold.fallbacks = [zero]
		if lxgw != null:
			lxgw.fallbacks = [zero]
	# 马善政只有标题和年号。缺的字（包括「祐」）改用思源宋体，不再画成方框。
	if ma != null and noto != null:
		ma.fallbacks = [noto]


func _load_font(msdf: bool) -> Font:
	# Duplicate the imported face so the banner can turn on MSDF without
	# touching the theme's copy, and so tests can see fallback stay off.
	var src := load("res://ui/fonts/NotoSerifSC-Regular.subset.ttf") as FontFile
	if src == null:
		push_error("中文字体缺失")
		return ThemeDB.fallback_font
	var ff := src.duplicate() as FontFile
	ff.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	ff.hinting = TextServer.HINTING_LIGHT
	ff.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	ff.oversampling = 0.0
	ff.allow_system_fallback = false
	if msdf:
		ff.multichannel_signed_distance_field = true
		ff.msdf_pixel_range = 8
		ff.msdf_size = 48
	if not ff.has_char("我".unicode_at(0)):
		var bytes := FileAccess.get_file_as_bytes("res://ui/fonts/NotoSerifSC-Regular.subset.ttf")
		var raw := FontFile.new()
		raw.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		raw.hinting = TextServer.HINTING_LIGHT
		raw.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		raw.oversampling = 0.0
		raw.allow_system_fallback = false
		if msdf:
			raw.multichannel_signed_distance_field = true
			raw.msdf_pixel_range = 8
			raw.msdf_size = 48
		raw.data = bytes
		if bytes.is_empty() or not raw.has_char("我".unicode_at(0)):
			push_error("中文字体缺失或没有汉字")
			return ThemeDB.fallback_font
		return raw
	return ff


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
