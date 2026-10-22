class_name TitleScreen
extends Control

var new_button: Button
var continue_button: Button

func _ready() -> void:
	add_to_group("title_screen")
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	custom_minimum_size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0c1e24")
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var band := ColorRect.new()
	band.color = Color("c6a15a")
	band.position = Vector2(0, 0)
	band.size = Vector2(1280, 6)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var title := _label("我带着AI穿越大宋", Vector2(0, 168), Vector2(1280, 64))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("f0d48a"))
	var sub := _label("宝元三年正月 · 你在延州醒来", Vector2(0, 248), Vector2(1280, 36))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	var sub2 := _label("随身只有一台会说话的终端，和一块太阳能板。", Vector2(0, 292), Vector2(1280, 36))
	sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub2.add_theme_font_size_override("font_size", 22)
	new_button = Button.new()
	new_button.text = "新游戏"
	new_button.position = Vector2(500, 360)
	new_button.size = Vector2(280, 52)
	new_button.focus_mode = Control.FOCUS_NONE
	new_button.add_theme_font_size_override("font_size", 22)
	add_child(new_button)
	continue_button = Button.new()
	continue_button.text = "继续"
	continue_button.position = Vector2(500, 432)
	continue_button.size = Vector2(280, 52)
	continue_button.focus_mode = Control.FOCUS_NONE
	continue_button.add_theme_font_size_override("font_size", 22)
	add_child(continue_button)
	var hint := _label("地图、行军、战斗、豆沙包", Vector2(0, 640), Vector2(1280, 36))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 20)
	refresh_continue()


func _label(text: String, pos: Vector2, sz: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = sz
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func refresh_continue() -> void:
	var has := SaveManager.has_any()
	continue_button.disabled = not has
	continue_button.text = "继续" if has else "继续（无存档）"
