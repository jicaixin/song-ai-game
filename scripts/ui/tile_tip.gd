extends PanelContainer

const Kit = preload("res://scripts/ui/kit.gd")

var head: Label
var detail: Label
var _hex := Vector2i(999999, 0)
var _shown_at := -10.0
var _hidden_at := -10.0
var _hover_at := 0.0
var _head_text := ""
var _more_text := ""
var _shake := 0.0
var _ready_ui := false


func _ready() -> void:
	theme_type_variation = "TooltipMap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	visible = false
	custom_minimum_size = Vector2(120, 0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	head = Kit.label("", "TooltipHeadLabel")
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.custom_minimum_size = Vector2(200, 0)
	box.add_child(head)
	detail = Kit.label("", "TooltipDetailLabel")
	detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.visible = false
	box.add_child(detail)
	_ready_ui = true


func present(hex: Vector2i, plan: Dictionary) -> void:
	if not _ready_ui:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var head_text := str(plan.get("head", ""))
	var more: Array = plan.get("more", [])
	var lines: PackedStringArray = []
	for line_v in more:
		lines.append(str(line_v))
	var more_text := "\n".join(lines)
	var hot := visible and (now - _shown_at) < 0.3 and _neighbor(_hex, hex)
	if head_text == _head_text and more_text == _more_text and hex == _hex:
		return
	_hex = hex
	_hover_at = now
	_head_text = head_text
	_more_text = more_text
	head.text = head_text
	detail.text = more_text
	if hot:
		visible = true
		_shown_at = now
	else:
		visible = false
	_fit()


func clear_tip() -> void:
	visible = false
	_hidden_at = Time.get_ticks_msec() / 1000.0
	_head_text = ""
	_more_text = ""


func shake() -> void:
	_shake = 0.12
	visible = true
	_shown_at = Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if _head_text == "":
		return
	var now := Time.get_ticks_msec() / 1000.0
	var wait := 0.0 if (now - _hidden_at) < 0.3 and _hidden_at > 0.0 else 0.15
	if not visible and now - _hover_at >= wait:
		visible = true
		_shown_at = now
	var shift := Input.is_key_pressed(KEY_SHIFT)
	var expand := shift or (visible and now - _hover_at >= 0.6)
	if detail.visible != expand:
		detail.visible = expand and _more_text != ""
		_fit()
	_follow()
	if _shake > 0.0:
		_shake -= _delta
		position.x += sin(now * 40.0) * 2.0


func _follow() -> void:
	var mouse := get_viewport().get_mouse_position()
	var sz := size
	if sz.x < 8.0:
		sz = custom_minimum_size
	var pos := mouse + Vector2(18, 22)
	var bounds := get_viewport_rect().size
	if bounds.x < 2.0:
		bounds = Vector2(1280, 720)
	if pos.x + sz.x > bounds.x - 16.0:
		pos.x = mouse.x - 18.0 - sz.x
	if pos.y + sz.y > bounds.y - 16.0:
		pos.y = mouse.y - 22.0 - sz.y
	if pos.y < 52.0:
		pos.y = 52.0
	var dock := Rect2(1020, 450, 260, 270)
	var rect := Rect2(pos, sz)
	if rect.intersects(dock):
		pos.x = minf(pos.x, dock.position.x - sz.x - 8.0)
	pos.x = clampf(pos.x, 16.0, bounds.x - sz.x - 16.0)
	pos.y = clampf(pos.y, 52.0, bounds.y - sz.y - 16.0)
	position = pos


func _fit() -> void:
	var w := 220.0
	w = maxf(w, head.get_minimum_size().x + 28.0)
	if detail.visible:
		w = maxf(w, detail.get_minimum_size().x + 28.0)
	w = minf(w, 420.0)
	custom_minimum_size = Vector2(w, 0)
	head.custom_minimum_size.x = maxf(head.get_minimum_size().x, w - 28.0)
	detail.custom_minimum_size.x = w - 28.0
	reset_size()


func _neighbor(a: Vector2i, b: Vector2i) -> bool:
	return HexGrid.distance(a, b) <= 1
