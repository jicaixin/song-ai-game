class_name TitleScreen
extends Control

const Kit = preload("res://scripts/ui/kit.gd")

var new_button: Button
var continue_button: Button


func _ready() -> void:
	add_to_group("title_screen")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var art := TextureRect.new()
	art.texture = Kit.tex("res://ui/art/title_keyart.png")
	art.position = Vector2.ZERO
	art.size = Vector2(1280, 720)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.03, 0.28)
	shade.position = Vector2(720, 0)
	shade.size = Vector2(560, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := Kit.label("我带着AI穿越大宋", "DisplayLabel")
	title.position = Vector2(48, 36)
	title.size = Vector2(760, 84)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("fbf5e6"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 2)
	add_child(title)
	var sub := Kit.label("宝元三年正月，你在延州醒来。", "BodyLabel")
	sub.position = Vector2(56, 128)
	sub.size = Vector2(640, 32)
	sub.add_theme_color_override("font_color", Color("f3e9d2"))
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	sub.add_theme_constant_override("shadow_offset_y", 1)
	add_child(sub)
	var sub2 := Kit.label("随身只有一台会说话的终端，和一块太阳能板。", "BodyLabel")
	sub2.position = Vector2(56, 164)
	sub2.size = Vector2(700, 32)
	sub2.add_theme_color_override("font_color", Color("f3e9d2"))
	sub2.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	sub2.add_theme_constant_override("shadow_offset_y", 1)
	add_child(sub2)
	new_button = Kit.button("新游戏", "PrimaryButton")
	new_button.position = Vector2(860, 470)
	new_button.size = Vector2(280, 56)
	new_button.add_theme_font_size_override("font_size", 22)
	add_child(new_button)
	continue_button = Kit.button("继续", "Button")
	continue_button.position = Vector2(860, 542)
	continue_button.size = Vector2(280, 56)
	continue_button.add_theme_font_size_override("font_size", 22)
	add_child(continue_button)
	var hint := Kit.label("格物、行军、朝堂，都从这一局走起。", "CaptionLabel")
	hint.position = Vector2(860, 620)
	hint.size = Vector2(360, 28)
	hint.add_theme_color_override("font_color", Color("f3e9d2"))
	add_child(hint)
	refresh_continue()


func refresh_continue() -> void:
	var has := SaveManager.has_any()
	continue_button.disabled = not has
	continue_button.text = "继续" if has else "继续（无存档）"
