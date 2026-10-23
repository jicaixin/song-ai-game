extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Actions = preload("res://scripts/core/tile_actions.gd")

signal chosen(id: String)
signal closed

var plan: Dictionary = {}
var target := Vector2i(999999, 0)
var anchor := Vector2.ZERO
var radius := 40.0
var focus_i := 0
var rows: Array = []
var card: PanelContainer
var leader: Line2D
var _flash := 0.0
var _built := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 55
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func is_open() -> bool:
	return visible


func open_at(next: Dictionary, hex: Vector2i, screen_anchor: Vector2, hex_radius: float) -> void:
	plan = next
	target = hex
	anchor = screen_anchor
	radius = hex_radius
	focus_i = _first_enabled()
	_rebuild()
	visible = true
	modulate.a = 1.0
	scale = Vector2.ONE
	if card:
		card.modulate.a = 0.0
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.96, 0.96)
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.08)
		tw.parallel().tween_property(card, "scale", Vector2.ONE, 0.08)


func move_anchor(screen_anchor: Vector2, hex_radius: float) -> void:
	anchor = screen_anchor
	radius = hex_radius
	if card == null:
		return
	var placed: Dictionary = Actions.place_card(anchor, radius, card.size)
	card.position = placed.pos
	_place_leader()


func shut() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func confirm_default() -> void:
	for row_v in rows:
		var row: Dictionary = row_v
		if bool(row.get("default", false)) and bool(row.get("enabled", false)):
			_pick(str(row.id))
			return
	shut()


func handle_key(event: InputEventKey) -> bool:
	if not visible:
		return false
	var code := event.keycode
	if code == KEY_ESCAPE:
		shut()
		return true
	if code == KEY_ENTER or code == KEY_KP_ENTER:
		confirm_default()
		return true
	if code == KEY_UP:
		_move_focus(-1)
		return true
	if code == KEY_DOWN:
		_move_focus(1)
		return true
	if code == KEY_V:
		_pick("info")
		return true
	if code == KEY_C and _has("city"):
		_pick("city")
		return true
	if code == KEY_F and _has("fortify"):
		_pick("fortify")
		return true
	if code == KEY_Q and _has("standby"):
		_pick("standby")
		return true
	if code == KEY_Z and event.ctrl_pressed and _has("undo"):
		_pick("undo")
		return true
	if code >= KEY_1 and code <= KEY_9:
		var n := code - KEY_1 + 1
		for row_v in rows:
			var row: Dictionary = row_v
			if str(row.kind) == "cmd" and str(row.key) == str(n):
				_pick(str(row.id))
				return true
		return true
	return false


func debug_buttons() -> Dictionary:
	var out := {}
	if not visible:
		return out
	for row_v in rows:
		var row: Dictionary = row_v
		var btn: Button = row.get("button")
		if btn == null:
			continue
		var r := btn.get_global_rect()
		out["menu_" + str(row.id)] = {
			"x": r.position.x,
			"y": r.position.y,
			"w": r.size.x,
			"h": r.size.y,
			"visible": true,
			"enabled": bool(row.enabled),
		}
	return out


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_paint_focus()


func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	rows.clear()
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.gui_input.connect(_on_blocker)
	add_child(blocker)
	leader = Line2D.new()
	leader.width = 3.0
	leader.default_color = Color("e3b341")
	leader.texture = Kit.piece("menu_leader")
	leader.texture_mode = Line2D.LINE_TEXTURE_TILE
	leader.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(leader)
	card = PanelContainer.new()
	card.theme_type_variation = "MenuCard"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(232, 0)
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := Kit.label(_title(), "MenuTitleLabel")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(head)
	var sub := Kit.label(_subtitle(), "MenuSubLabel")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	var preview := _forecast()
	if not preview.is_empty():
		box.add_child(_forecast_panel(preview))
	var list: Array = plan.get("actions", [])
	var i := 0
	for a_v in list:
		var action: Dictionary = a_v
		var row := _row(action, i)
		box.add_child(row.panel)
		rows.append(row)
		i += 1
	_fit_width(box)
	var tall := 88.0
	var preview_now := _forecast()
	if not preview_now.is_empty():
		tall += 72.0
	for row_v in rows:
		var row: Dictionary = row_v
		tall += 56.0 if row.reason != null else 42.0
	card.custom_minimum_size.y = tall
	var placed: Dictionary = Actions.place_card(anchor, radius, card.custom_minimum_size, Rect2())
	if bool(placed.nudge):
		pass
	card.position = placed.pos
	card.size = card.custom_minimum_size
	_place_leader()
	_paint_focus()


func _fit_width(box: VBoxContainer) -> void:
	var width := 232.0
	for child in box.get_children():
		if child is Control:
			width = maxf(width, (child as Control).get_combined_minimum_size().x + 8.0)
	width = minf(width, 420.0)
	card.custom_minimum_size = Vector2(width, 0)
	for child in box.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = width - 16.0


func _row(action: Dictionary, index: int) -> Dictionary:
	var enabled := bool(action.get("enabled", false))
	var reason := str(action.get("reason", ""))
	var tall := (not enabled) and reason != ""
	var panel := PanelContainer.new()
	if tall:
		panel.theme_type_variation = "MenuRowReason"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_row.bind(str(action.get("id", ""))))
	var wrap := VBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(wrap)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	var num := Kit.label(_num_text(action, index), "MenuReasonLabel")
	num.custom_minimum_size = Vector2(16, 0)
	line.add_child(num)
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.theme_type_variation = "MenuRowDefault" if bool(action.get("default", false)) else "MenuRow"
	btn.text = str(action.get("label", ""))
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = not enabled
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_name := str(action.get("icon", ""))
	if not enabled and icon_name != "":
		icon_name += "_disabled"
	if icon_name != "":
		btn.icon = Kit.icon(icon_name)
	btn.custom_minimum_size = Vector2(0, 36 if not tall else 28)
	line.add_child(btn)
	var key := str(action.get("key", ""))
	if bool(action.get("default", false)):
		key = "Enter"
	if key != "":
		var cap := PanelContainer.new()
		cap.theme_type_variation = "KeycapActive" if bool(action.get("default", false)) else "Keycap"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var kl := Kit.label(key, "KeycapLabel")
		cap.add_child(kl)
		line.add_child(cap)
	var reason_label: Label = null
	if tall:
		reason_label = Kit.label(reason, "MenuReasonLabel")
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		wrap.add_child(reason_label)
	return {
		"id": str(action.get("id", "")),
		"kind": str(action.get("kind", "")),
		"key": str(action.get("key", "")),
		"enabled": enabled,
		"default": bool(action.get("default", false)),
		"button": btn,
		"panel": panel,
		"reason": reason_label,
	}


func _forecast() -> Dictionary:
	for a_v in plan.get("actions", []):
		var action: Dictionary = a_v
		var preview: Dictionary = action.get("preview", {})
		if not preview.is_empty() and bool(action.get("enabled", false)):
			return preview
	return {}


func _forecast_panel(preview: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "MenuForecast"
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_bar_line("敌 -%d~%d" % [int(preview.def_min), int(preview.def_max)], int(preview.def_mid), false))
	box.add_child(_bar_line("我 -%d~%d" % [int(preview.atk_min), int(preview.atk_max)], int(preview.atk_mid), true))
	if int(preview.atk_mid) > int(preview.def_mid):
		var warn := Kit.label("预计不利", "ForecastBadLabel")
		box.add_child(warn)
	return panel


func _bar_line(text: String, mid: int, mine: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lab := Kit.label(text, "ForecastBadLabel" if mine else "ForecastGoodLabel")
	lab.custom_minimum_size = Vector2(110, 0)
	row.add_child(lab)
	var bar := ProgressBar.new()
	bar.max_value = 60
	bar.value = mini(mid, 60)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(64, 8)
	bar.theme_type_variation = "HPBarLow" if mine else "HPBar"
	row.add_child(bar)
	return row


func _title() -> String:
	var head := str(plan.get("head", ""))
	var bits := head.split(" · ")
	if bits.size() > 0:
		return bits[0]
	return head


func _subtitle() -> String:
	var head := str(plan.get("head", ""))
	var bits := head.split(" · ")
	if bits.size() > 1:
		return " · ".join(bits.slice(1))
	return ""


func _num_text(action: Dictionary, _index: int) -> String:
	if str(action.get("kind", "")) != "cmd":
		return ""
	return str(action.get("key", ""))


func _first_enabled() -> int:
	var i := 0
	for a_v in plan.get("actions", []):
		var action: Dictionary = a_v
		if str(action.kind) == "cmd" and bool(action.enabled):
			return i
		i += 1
	return 0


func _move_focus(dir: int) -> void:
	if rows.is_empty():
		return
	var i := focus_i
	for _n in rows.size():
		i = (i + dir + rows.size()) % rows.size()
		var row: Dictionary = rows[i]
		if bool(row.enabled):
			focus_i = i
			for r_v in rows:
				var other: Dictionary = r_v
				other.default = false
			row.default = true
			_paint_focus()
			return


func _paint_focus() -> void:
	var i := 0
	for row_v in rows:
		var row: Dictionary = row_v
		var btn: Button = row.button
		var on := i == focus_i and bool(row.enabled)
		btn.theme_type_variation = "MenuRowDefault" if on else "MenuRow"
		i += 1


func _pick(id: String) -> void:
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.id) != id:
			continue
		if not bool(row.enabled):
			_flash = 0.25
			var reason: Label = row.reason
			if reason:
				reason.add_theme_color_override("font_color", Color("f2a08f"))
			return
		chosen.emit(id)
		shut()
		return


func _has(id: String) -> bool:
	for row_v in rows:
		var row: Dictionary = row_v
		if str(row.id) == id:
			return true
	return false


func _on_row(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_pick(id)
	accept_event()


func _on_blocker(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	var pad := radius + 8.0
	var hex := Rect2(anchor - Vector2(pad, pad), Vector2(pad, pad) * 2.0)
	if mb.button_index == MOUSE_BUTTON_LEFT and hex.has_point(mb.position):
		confirm_default()
	elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
		shut()
	accept_event()


func _place_leader() -> void:
	if leader == null or card == null:
		return
	var side := card.position + Vector2(0, 24)
	if anchor.x < card.position.x:
		side = card.position + Vector2(0, 24)
	else:
		side = card.position + Vector2(card.size.x, 24)
	leader.points = PackedVector2Array([anchor, side])
	leader.visible = card.visible
