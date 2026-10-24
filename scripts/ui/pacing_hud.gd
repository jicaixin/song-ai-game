class_name PacingHud
extends Control

const EventSystem = preload("res://scripts/core/event_system.gd")
const EnemyPace = preload("res://scripts/core/enemy_pace.gd")

## Event modal, enemy-turn banner, and battle report. Drawn in the Song palette.

var host
var event_open := false
var banner_open := false
var report_open := false
var _event_id := ""
var _report_left := 0.0
var _report_hover := false
var _banner: Panel
var _banner_title: Label
var _banner_count: Label
var _speed_1: Button
var _speed_2: Button
var _skip: Button
var _dots: HBoxContainer
var _report: Panel
var _report_label: Label
var _dim: ColorRect
var _card: Panel
var _portrait: TextureRect
var _title: Label
var _date: Label
var _body: Label
var _comment: Label
var _footer: Label
var _options: VBoxContainer
var _comment_head: TextureRect
var _badge: Label
var _badge_bg: ColorRect
var _report_queue := ""


func setup(owner: GameUI) -> void:
	host = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_banner()
	_build_report()
	_build_event()
	_build_badge()


func tick(delta: float) -> void:
	if report_open and not _report_hover:
		_report_left -= delta
		if _report_left <= 0.0:
			_close_report(true)
	if banner_open and _speed_1 and _speed_2:
		_mark_speed()


func sync() -> void:
	_refresh_badge()
	if event_open and _event_id != "" and not GameState.pending_events.has(_event_id):
		_close_event()
	_consider_event()


func show_banner(total: int) -> void:
	banner_open = true
	# The battle report shares this band. Keep it hidden until the phase ends
	# so the banner stays readable for the whole enemy turn.
	if report_open:
		report_open = false
		_report_hover = false
		_report_left = 0.0
		GameState.report_hold = false
		if _report:
			_report.visible = false
	_banner.visible = true
	_banner.z_index = 4
	EnemyPace.total = total
	_apply_faction("西夏")
	set_progress(0, total, "西夏")
	_mark_speed()


func set_progress(done: int, total: int, faction_name: String) -> void:
	EnemyPace.index = done
	EnemyPace.total = total
	_banner_title.text = "敌方行动中 · %s" % faction_name
	_banner_count.text = "%d/%d" % [done, maxi(1, total)]
	_apply_faction(faction_name)
	_paint_dots(done, total)


func hide_banner() -> void:
	banner_open = false
	if _banner:
		_banner.visible = false
	if _report_queue != "":
		var queued := _report_queue
		_report_queue = ""
		_present_report(queued)


func show_report(text: String) -> void:
	if banner_open:
		_report_queue = text
		GameState.last_report = text
		return
	_present_report(text)


func _present_report(text: String) -> void:
	_report_label.text = text
	_report.visible = true
	report_open = true
	_report_left = 3.0
	GameState.report_hold = true
	GameState.last_report = text
	var rows := text.split("\n").size()
	var tall := clampf(96.0 + float(rows) * 22.0, 120.0, 320.0)
	_report.size = Vector2(500, tall)
	_report.position = Vector2(390, 80)
	_report.z_index = 1


func dismiss_report() -> void:
	if report_open:
		_close_report(false)


func event_blocking() -> bool:
	return event_open


func force_event(id: String) -> void:
	if not GameState.pending_events.has(id):
		GameState.pending_events.push_front(id)
	_open_event(id)


func _consider_event() -> void:
	if event_open or report_open or banner_open:
		return
	if GameState.input_locked or not GameState.playing or not GameState.tutorial_done:
		return
	if host and host.has_method("tutorial_active") and host.tutorial_active():
		return
	if host and host.desk and host.desk.is_open():
		return
	if GameState.pending_events.is_empty():
		return
	_open_event(str(GameState.pending_events[0]))


func _open_event(id: String) -> void:
	var ev: Dictionary = DataDB.event_by_id.get(id, {})
	if ev.is_empty():
		GameState.pending_events.erase(id)
		return
	_event_id = id
	event_open = true
	_dim.visible = true
	_card.visible = true
	_title.text = str(ev.get("title", ""))
	var dated := str(ev.get("date_label", ""))
	if dated == "":
		dated = Calendar.format_date(GameState.year, GameState.month)
	_date.text = dated
	_body.text = str(ev.get("body", ""))
	var comment := str(ev.get("comment", ""))
	if comment.begins_with("豆沙包："):
		comment = comment.substr(4)
	_comment.text = comment
	_footer.text = str(ev.get("footer", ""))
	var who := str(ev.get("who", ""))
	var expr := str(ev.get("expr", "normal"))
	var portrait_key := str(ev.get("portrait", ""))
	var face: Texture2D = null
	if portrait_key != "":
		face = Kit.tex("res://ui/art/portraits/full/%s.png" % portrait_key)
	if face == null:
		face = _full_or_bust(who, expr)
	if face == null:
		face = Kit.portrait_full("doushabao", "serious")
	_portrait.texture = face
	_comment_head.texture = Kit.doushabao_frame("serious")
	_clear_choice_buttons()
	for child in _options.get_children():
		_options.remove_child(child)
		child.free()
	var choices: Array = ev.get("choices", [])
	for choice_v in choices:
		var choice: Dictionary = choice_v
		_options.add_child(_choice_row(id, choice))


func _full_or_bust(pid: String, expr: String) -> Texture2D:
	var face := Kit.portrait_full(pid, expr)
	if face == null:
		face = Kit.portrait_bust(pid, expr)
	return face


func _close_event() -> void:
	event_open = false
	_event_id = ""
	_dim.visible = false
	_card.visible = false
	_clear_choice_buttons()


func _choice_row(event_id: String, choice: Dictionary) -> Control:
	var enabled := EventSystem.choice_enabled(choice)
	var row := Control.new()
	row.custom_minimum_size = Vector2(560, 64)
	row.size = Vector2(560, 64)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plate := Panel.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f7f1e4") if enabled else Color("e4dccb")
	box.border_color = Color("c6a15b") if enabled else Color("b3a894")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.content_margin_left = 12
	box.content_margin_right = 12
	plate.add_theme_stylebox_override("panel", box)
	row.add_child(plate)
	var title := Label.new()
	title.text = str(choice.get("label", ""))
	title.position = Vector2(14, 10)
	title.size = Vector2(420, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("2a2118") if enabled else Color("8a8175"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	var note := Label.new()
	note.text = str(choice.get("note", ""))
	note.position = Vector2(14, 36)
	note.size = Vector2(420, 22)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("6b5b48") if enabled else Color("8a8175"))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(note)
	var odds := str(choice.get("odds", ""))
	if odds != "":
		var chip := Label.new()
		chip.text = odds
		chip.position = Vector2(470, 22)
		chip.size = Vector2(72, 24)
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		chip.add_theme_font_size_override("font_size", 14)
		var ink := Color("8e2a1e")
		if odds == "稳":
			ink = Color("2f6b45")
		elif odds == "五五":
			ink = Color("8a5a12")
		chip.add_theme_color_override("font_color", ink if enabled else Color("8a8175"))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	var hit := Button.new()
	hit.text = ""
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.disabled = not enabled
	var cid := str(choice.get("id", ""))
	if enabled:
		hit.pressed.connect(_choose.bind(event_id, cid))
	row.add_child(hit)
	if host:
		host.btn_map["event_%s" % cid] = hit
	return row


func _choose(event_id: String, choice_id: String) -> void:
	GameState.choose_event(event_id, choice_id)
	if not GameState.pending_events.has(event_id):
		_close_event()


func _clear_choice_buttons() -> void:
	if host == null:
		return
	var drop: Array[String] = []
	for key_v in host.btn_map.keys():
		var key := str(key_v)
		if key.begins_with("event_"):
			drop.append(key)
	for key2 in drop:
		host.btn_map.erase(key2)


func _build_banner() -> void:
	_banner = Panel.new()
	_banner.position = Vector2(400, 60)
	_banner.size = Vector2(480, 44)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.add_theme_stylebox_override("panel", _plate(Color("6B3E8E"), 6))
	add_child(_banner)
	_banner_title = _cream(16)
	_banner_title.position = Vector2(12, 10)
	_banner_title.size = Vector2(188, 26)
	_banner.add_child(_banner_title)
	_banner_count = _cream(15)
	_banner_count.position = Vector2(200, 11)
	_banner_count.size = Vector2(40, 24)
	_banner.add_child(_banner_count)
	_dots = HBoxContainer.new()
	_dots.position = Vector2(242, 18)
	_dots.add_theme_constant_override("separation", 3)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_dots)
	_speed_1 = _tiny("1×")
	_speed_1.position = Vector2(318, 8)
	_speed_1.pressed.connect(_set_speed.bind(1.0))
	_banner.add_child(_speed_1)
	_speed_2 = _tiny("2×")
	_speed_2.position = Vector2(364, 8)
	_speed_2.pressed.connect(_set_speed.bind(2.0))
	_banner.add_child(_speed_2)
	_skip = _tiny("跳过")
	_skip.position = Vector2(410, 8)
	_skip.custom_minimum_size = Vector2(58, 28)
	_skip.size = Vector2(58, 28)
	_skip.pressed.connect(func() -> void: EnemyPace.request_skip())
	_banner.add_child(_skip)
	if host:
		host.btn_map["enemy_skip"] = _skip
		host.btn_map["enemy_speed_1"] = _speed_1
		host.btn_map["enemy_speed_2"] = _speed_2


func _set_speed(rate: float) -> void:
	EnemyPace.speed = rate
	_mark_speed()


func _mark_speed() -> void:
	var on := Color("e8cb7c")
	var off := Color("f7f1e4")
	if _speed_1:
		_speed_1.add_theme_color_override("font_color", on if is_equal_approx(EnemyPace.speed, 1.0) else off)
	if _speed_2:
		_speed_2.add_theme_color_override("font_color", on if is_equal_approx(EnemyPace.speed, 2.0) else off)


func _paint_dots(done: int, total: int) -> void:
	for child in _dots.get_children():
		child.queue_free()
	var n := mini(total, 6)
	for i in n:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = Color("f7f1e4") if i < done else Color("f7f1e4", 0.35)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(dot)


func _apply_faction(faction_name: String) -> void:
	var bg := Color("6B3E8E")
	if faction_name.find("辽") >= 0:
		bg = Color("24467F")
	elif faction_name.find("叛") >= 0:
		bg = Color("4D4540")
	_banner.add_theme_stylebox_override("panel", _plate(bg, 6))


func _build_report() -> void:
	_report = Panel.new()
	_report.position = Vector2(390, 80)
	_report.size = Vector2(500, 160)
	_report.visible = false
	_report.mouse_filter = Control.MOUSE_FILTER_STOP
	_report.add_theme_stylebox_override("panel", _plate(Color("f7f1e4"), 8, Color("8e2a1e")))
	_report.mouse_entered.connect(func() -> void: _report_hover = true)
	_report.mouse_exited.connect(func() -> void: _report_hover = false)
	add_child(_report)
	var head := Label.new()
	head.text = "敌方回合"
	head.position = Vector2(16, 10)
	head.size = Vector2(200, 22)
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color("8e2a1e"))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.add_child(head)
	_report_label = Label.new()
	_report_label.position = Vector2(16, 36)
	_report_label.size = Vector2(360, 220)
	_report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_report_label.add_theme_font_size_override("font_size", 14)
	_report_label.add_theme_color_override("font_color", Color("2a2118"))
	_report_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_report.add_child(_report_label)
	var locate := Button.new()
	locate.text = "定位"
	locate.focus_mode = Control.FOCUS_NONE
	locate.position = Vector2(400, 12)
	locate.size = Vector2(80, 32)
	locate.add_theme_font_size_override("font_size", 14)
	locate.pressed.connect(_locate)
	_report.add_child(locate)
	var closer := Button.new()
	closer.text = ""
	closer.flat = true
	closer.focus_mode = Control.FOCUS_NONE
	closer.position = Vector2(0, 48)
	closer.size = Vector2(390, 260)
	closer.pressed.connect(func() -> void: _close_report(false))
	_report.add_child(closer)
	if host:
		host.btn_map["report_locate"] = locate
		host.btn_map["report_close"] = closer


func _close_report(into_badge: bool) -> void:
	report_open = false
	_report.visible = false
	_report_hover = false
	GameState.report_hold = false
	if into_badge:
		GameState.report_unread = true
	if host:
		host.toast.visible = false


func _locate() -> void:
	var text := _report_label.text
	var first := text.split("\n")[0]
	var city_name := ""
	if first.find("：") >= 0:
		city_name = first.split("：")[0]
		if city_name.find("·") >= 0:
			city_name = ""
	var map: Node = null
	if host:
		map = host.get_tree().get_first_node_in_group("world_map")
	if map == null or city_name == "":
		return
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if str(city.get("name", "")) == city_name or str(city.get("short", "")) == city_name:
			map.call("focus_city", str(city.get("id", "")))
			return


func _build_event() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.04, 0.03, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_dim.z_index = 5
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_card = Panel.new()
	_card.position = Vector2(200, 100)
	_card.size = Vector2(880, 520)
	_card.visible = false
	_card.z_index = 6
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", _plate(Color("f3ead6"), 10, Color("8e2a1e")))
	add_child(_card)
	var ribbon := ColorRect.new()
	ribbon.color = Color("8e2a1e")
	ribbon.position = Vector2(280, -16)
	ribbon.size = Vector2(320, 40)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(ribbon)
	_title = Label.new()
	_title.position = Vector2(280, -12)
	_title.size = Vector2(320, 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", Color("f7f1e4"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_title)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(24, 40)
	_portrait.size = Vector2(240, 360)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_portrait)
	_date = Label.new()
	_date.position = Vector2(284, 36)
	_date.size = Vector2(560, 22)
	_date.add_theme_font_size_override("font_size", 14)
	_date.add_theme_color_override("font_color", Color("8e2a1e"))
	_date.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_date)
	_body = Label.new()
	_body.position = Vector2(284, 64)
	_body.size = Vector2(560, 120)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color("2a2118"))
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_body)
	_comment_head = TextureRect.new()
	_comment_head.position = Vector2(284, 188)
	_comment_head.size = Vector2(48, 48)
	_comment_head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_comment_head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_comment_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_comment_head)
	_comment = Label.new()
	_comment.position = Vector2(340, 190)
	_comment.size = Vector2(504, 48)
	_comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_comment.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_comment.add_theme_font_size_override("font_size", 14)
	_comment.add_theme_color_override("font_color", Color("3a2a22"))
	_comment.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_comment)
	_options = VBoxContainer.new()
	_options.position = Vector2(284, 248)
	_options.size = Vector2(572, 220)
	_options.add_theme_constant_override("separation", 8)
	_card.add_child(_options)
	_footer = Label.new()
	_footer.position = Vector2(284, 478)
	_footer.size = Vector2(560, 24)
	_footer.add_theme_font_size_override("font_size", 13)
	_footer.add_theme_color_override("font_color", Color("6b5b48"))
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_footer)


func _build_badge() -> void:
	if host == null:
		return
	var btn: Button = host.btn_map.get("events", null)
	if btn == null:
		return
	_badge_bg = ColorRect.new()
	_badge_bg.color = Color("c23b2a")
	_badge_bg.position = Vector2(20, -2)
	_badge_bg.size = Vector2(16, 16)
	_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_bg.visible = false
	btn.add_child(_badge_bg)
	_badge = Label.new()
	_badge.position = Vector2(20, -4)
	_badge.size = Vector2(16, 16)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 13)
	_badge.add_theme_color_override("font_color", Color("fff6ea"))
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.visible = false
	btn.add_child(_badge)


func _refresh_badge() -> void:
	if _badge == null:
		return
	var n := GameState.pending_events.size()
	if n == 0 and GameState.report_unread:
		n = 1
	_badge.visible = n > 0
	_badge_bg.visible = n > 0
	_badge.text = str(n)


func _cream(size: int) -> Label:
	var lab := Label.new()
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", Color("f7f1e4"))
	lab.add_theme_constant_override("outline_size", 4)
	lab.add_theme_color_override("font_outline_color", Color("1a1020"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _tiny(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(44, 28)
	btn.size = Vector2(44, 28)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color("f7f1e4"))
	return btn


func _plate(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box
