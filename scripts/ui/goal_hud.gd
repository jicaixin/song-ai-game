class_name GoalHud
extends Control

const GoalSystem = preload("res://scripts/core/goal_system.gd")
const Omen = preload("res://scripts/core/omen.gd")

## Goal bar, chapter cards, and the reward fly-in. The fly-in ends on 朝堂.

var host
var collapsed := false
var tab := "month"
var _bar: Panel
var _body: Control
var _title: Label
var _count: Label
var _rows: VBoxContainer
var _meters: Control
var _chapter_box: Control
var _card: Control
var _card_id := ""
var _card_left := 0.0
var _sig := ""
var _flights: Array = []
var fly_time := 1.0
var _seal: Label
var _seal_left := 0.0
var _rating: Control
var _rating_hold := false


func setup(owner) -> void:
	host = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_bar()
	_build_card()
	_build_flyers()
	_build_rating()


func blocking() -> bool:
	return _card != null and _card.visible


func tick(delta: float) -> void:
	if _card_id != "" and _card != null and _card.visible:
		_card_left -= delta
		if _card_left <= 0.0:
			dismiss_card()
	if _seal_left > 0.0:
		_seal_left -= delta
		if _seal_left <= 0.0 and _seal:
			_seal.visible = false
	_advance_flights(delta)


func sync() -> void:
	if not GameState.playing:
		_bar.visible = false
		return
	var tutoring := false
	if host != null and host.has_method("tutorial_active"):
		tutoring = bool(host.call("tutorial_active"))
	_bar.visible = GameState.tutorial_done and not tutoring
	if _bar.visible:
		_bar.modulate = Color(1, 1, 1, 0.6) if GameState.input_locked else Color.WHITE
	GoalSystem.touch()
	_drain_rewards()
	_sync_card()
	if blocking():
		z_index = 90
		_bar.visible = false
	else:
		z_index = 50
	if _rating:
		_rating.visible = GameState.demo_over and not blocking() and not _rating_hold
		if _rating.visible:
			_fill_rating()
			z_index = 90
	if _bar.visible:
		_sync_bar()


func dismiss_card() -> void:
	if _card_id.begins_with("end:"):
		var cid := _card_id.trim_prefix("end:")
		var ch: Dictionary = DataDB.chapter_by_id.get(cid, {})
		if not ch.is_empty():
			GoalSystem.grant_chapter(ch, GoalSystem.chapter_state(ch))
			_drain_rewards()
	_card_id = ""
	_card.visible = false
	_sync_card()
	if blocking():
		z_index = 90
	else:
		z_index = 50


func show_tab(which: String) -> void:
	tab = which
	collapsed = false
	_sig = ""
	_sync_bar()


func _sync_bar() -> void:
	var ch := GoalSystem.current_chapter()
	var title := "本月"
	if not ch.is_empty():
		title = "%s · %s  %s" % [str(ch.get("label", "")), str(ch.get("name", "")), GoalSystem.chapter_progress()]
	if collapsed:
		var brief := GoalSystem.collapsed_text()
		if brief == "":
			brief = "本月无急务"
		_title.text = brief
	else:
		_title.text = title
	_count.text = str(GameState.orders.size())
	var sig := "%s|%s|%s|%d" % [tab, str(collapsed), _title.text, GameState.orders.size()]
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		sig += "|%s|%s" % [str(item.get("text", "")), str(item.get("note", ""))]
	sig += "|%d|%d|%d" % [GoalSystem.xiping(), GoalSystem.beiding(), GoalSystem.jingnei()]
	sig += "|" + str(Omen.current().get("title", ""))
	if sig == _sig:
		return
	_sig = sig
	_layout()
	_paint()


func _layout() -> void:
	var height := 44.0
	if not collapsed:
		height = 32.0 + 36.0 + 8.0
		if tab == "month":
			height += float(maxi(GameState.orders.size(), 1)) * 70.0
			if not Omen.current().is_empty():
				height += 68.0
		elif tab == "chapter":
			height += 220.0
		else:
			height += 3.0 * 76.0
	if height > 368.0:
		height = 368.0
	_bar.size = Vector2(304, height)
	_body.visible = not collapsed


func _paint() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.free()
	_clear_goal_buttons()
	_rows.visible = tab == "month" and not collapsed
	_meters.visible = tab == "war" and not collapsed
	_chapter_box.visible = tab == "chapter" and not collapsed
	if collapsed:
		return
	if tab == "month":
		_paint_orders()
	elif tab == "chapter":
		_paint_chapter()
	else:
		_paint_meters()


func _paint_orders() -> void:
	var omen := Omen.current()
	if not omen.is_empty():
		_rows.add_child(_omen_card(omen))
	if GameState.orders.is_empty() and GameState.shelved.is_empty():
		var empty := Label.new()
		empty.text = "本月无急务，可直接结束回合"
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color("6b5b48"))
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(280, 40)
		_rows.add_child(empty)
		return
	var index := 0
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		_rows.add_child(_order_row(item, index))
		index += 1
	for shelved_v in GameState.shelved:
		var shelved: Dictionary = shelved_v
		_rows.add_child(_shelved_row(shelved))


func _order_row(item: Dictionary, index: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(288, 64)
	var plate := Panel.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var main := bool(item.get("main", false))
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f7f1e4")
	box.border_color = Color("c6a15b") if main else Color("d9c7a2")
	box.set_border_width_all(2 if main else 1)
	box.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", box)
	row.add_child(plate)
	var title := Label.new()
	title.text = str(item.get("text", ""))
	title.position = Vector2(10, 8)
	title.size = Vector2(200, 22)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("2a2118"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	var note := Label.new()
	note.text = str(item.get("note", ""))
	note.position = Vector2(10, 34)
	note.size = Vector2(200, 20)
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("6b5b48"))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(note)
	var reward := _reward_label(item)
	reward.position = Vector2(188, 20)
	reward.size = Vector2(90, 24)
	row.add_child(reward)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(_activate_order.bind(str(item.get("id", ""))))
	hit.gui_input.connect(_shelve_click.bind(str(item.get("id", ""))))
	row.add_child(hit)
	if host:
		host.btn_map["goal_%d" % index] = hit
	return row


func _reward_label(item: Dictionary) -> Label:
	var craft := int(item.get("craft", 0))
	if bool(item.get("main", false)):
		craft = int(round(float(craft) * 1.5))
	var lab := Label.new()
	var id := str(item.get("id", ""))
	if id == "G11":
		lab.text = "钱 +120"
	elif id == "G17":
		lab.text = "饷减两成"
	elif id == "G18":
		lab.text = "生命 +20"
	elif craft > 0:
		lab.text = "匠 +%d" % craft
	else:
		lab.text = "皇威"
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lab.add_theme_font_size_override("font_size", 13)
	lab.add_theme_color_override("font_color", Color("8a5a12"))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


func _paint_chapter() -> void:
	for child in _chapter_box.get_children():
		_chapter_box.remove_child(child)
		child.free()
	var ch := GoalSystem.current_chapter()
	if ch.is_empty():
		return
	var head := Label.new()
	head.text = "%s · %s" % [str(ch.get("label", "")), str(ch.get("name", ""))]
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color("8e2a1e"))
	_chapter_box.add_child(head)
	var years := Label.new()
	years.text = str(ch.get("years", ""))
	years.add_theme_font_size_override("font_size", 13)
	years.add_theme_color_override("font_color", Color("6b5b48"))
	_chapter_box.add_child(years)
	var state := GoalSystem.chapter_state(ch)
	var main := Label.new()
	main.text = str(ch.get("main", ""))
	main.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_theme_font_size_override("font_size", 15)
	main.add_theme_color_override("font_color", Color("2a2118"))
	_chapter_box.add_child(main)
	var stamp := Label.new()
	if state == "done":
		stamp.text = "主目标已达成"
	elif state == "partial":
		stamp.text = "主目标完成一半"
	elif state == "fail":
		stamp.text = "主目标未达成"
	else:
		stamp.text = "主目标进行中  %s" % GoalSystem.chapter_progress()
	stamp.add_theme_font_size_override("font_size", 13)
	stamp.add_theme_color_override("font_color", Color("8e2a1e") if state == "done" else Color("6b5b48"))
	_chapter_box.add_child(stamp)
	var sides: Array = ch.get("sides", [])
	for side_v in sides:
		var side := Label.new()
		side.text = "· %s" % str(side_v)
		side.add_theme_font_size_override("font_size", 13)
		side.add_theme_color_override("font_color", Color("2a2118"))
		_chapter_box.add_child(side)


func _paint_meters() -> void:
	for child in _meters.get_children():
		_meters.remove_child(child)
		child.free()
	_meters.add_child(_meter("西平", GoalSystem.xiping(), 85, Color("6B3E8E"), "西夏战意 %d" % int(GameState.meters.get("xia_war", 70)), GoalSystem.xiping_done()))
	var demand := int(GameState.meters.get("liao_demand", 20))
	var bei := GoalSystem.beiding_done()
	var bei_name := "北定"
	if bei == "full":
		bei_name = "北定（达成）"
	elif bei == "reduced":
		bei_name = "北定（减额）"
	_meters.add_child(_meter(bei_name, GoalSystem.beiding(), 100, Color("24467F"), "辽索求 %d 档" % demand, bei != ""))
	_meters.add_child(_meter("靖内", GoalSystem.jingnei(), 100, Color("C23B2A"), "已平定 %d / 3" % GoalSystem.jingnei_count(), GoalSystem.jingnei_done()))


func _meter(title: String, value: int, goal: int, fill: Color, note: String, done: bool) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(288, 72)
	var name := Label.new()
	name.text = title
	name.position = Vector2(0, 0)
	name.size = Vector2(180, 22)
	name.add_theme_font_size_override("font_size", 15)
	name.add_theme_color_override("font_color", Color("2a2118"))
	row.add_child(name)
	var num := Label.new()
	num.text = "%d / %d" % [value, goal]
	num.position = Vector2(160, 0)
	num.size = Vector2(120, 22)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", Color("8e2a1e") if done else Color("6b5b48"))
	row.add_child(num)
	var track := ColorRect.new()
	track.color = Color("e4d7c3")
	track.position = Vector2(0, 26)
	track.size = Vector2(280, 14)
	row.add_child(track)
	var bar := ColorRect.new()
	bar.color = Color("e8cb7c") if done else fill
	bar.position = Vector2(0, 26)
	var width := 280.0 * clampf(float(value) / float(maxi(goal, 1)), 0.0, 1.0)
	bar.size = Vector2(width, 14)
	row.add_child(bar)
	var mark := ColorRect.new()
	mark.color = Color("c6a15b")
	mark.position = Vector2(278, 24)
	mark.size = Vector2(2, 18)
	row.add_child(mark)
	var cap := Label.new()
	cap.text = note
	cap.position = Vector2(0, 46)
	cap.size = Vector2(280, 20)
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", Color("6b5b48"))
	row.add_child(cap)
	return row


func _activate_order(id: String) -> void:
	if GameState.input_locked or host == null:
		return
	if id == "G07":
		host.open_desk("tech")
		return
	if id == "G08":
		host.open_desk("workshop")
		return
	if id == "G15":
		host.open_desk("events")
		return
	if id == "G11":
		GameState.sell_grain()
		return
	if id == "G30":
		GameState.recover_army()
		_show_seal()
		return
	if id == "G12":
		host.open_desk("tech")
		return
	if id == "G17":
		GameState.transfer_grain()
		return
	if id == "G18":
		GameState.feast()
		return
	if id == "G22":
		host.open_desk("court")
		return
	var city := "yanzhou"
	if id == "G06" or id == "G01":
		city = "zhenrong"
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		if str(item.get("id", "")) != id:
			continue
		var place := str(item.get("place", ""))
		if place != "" and DataDB.city_by_id(place).size() > 0:
			city = place
	var map := get_tree().get_first_node_in_group("world_map")
	if map:
		map.call("focus_city", city)


func _sync_card() -> void:
	if _card_id != "":
		return
	if not GameState.tutorial_done:
		return
	if host and host.has_method("tutorial_active") and host.tutorial_active():
		return
	if host and host.pacing and host.pacing.event_open:
		return
	if GameState.input_locked:
		return
	if blocking():
		return
	var next := GoalSystem.pop_card()
	if next == "":
		return
	_show_card(next)


func omen_title() -> String:
	var row := Omen.current()
	return str(row.get("title", ""))


func art_size() -> Vector2:
	if _card == null:
		return Vector2.ZERO
	var bg: TextureRect = _card.get_node_or_null("Art")
	if bg == null or bg.texture == null:
		return Vector2.ZERO
	return bg.size


func _show_card(token: String) -> void:
	_card_id = token
	_card_left = 3.0
	_card.position = Vector2.ZERO
	_card.size = Vector2(1280, 720)
	_card.visible = true
	z_index = 90
	_bar.visible = false
	if host and host.has_method("hold_toast"):
		host.hold_toast()
	var ending := token.begins_with("end:")
	var cid := token.trim_prefix("end:") if ending else token.trim_prefix("start:")
	var ch: Dictionary = {}
	if token == "epilogue":
		ch = {
			"label": "尾声",
			"name": "三胜之后",
			"years": "打到第八十六回合",
			"lead": "三件事都有了着落。后面的月份还在，评级不会因此往下掉。",
			"main": "从容打完这一局",
			"sides": ["西平", "北定", "靖内"],
			"art": "chapter_06_beizhou_xingqing",
		}
	else:
		ch = DataDB.chapter_by_id.get(cid, {})
	var art := ""
	if not ch.is_empty():
		art = str(ch.get("art", ""))
	var tex: Texture2D = null
	if art != "":
		tex = Kit.tex("res://ui/art/chapters/%s.png" % art)
	var bg: TextureRect = _card.get_node("Art")
	bg.texture = tex
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.modulate = Color(0.55, 0.52, 0.48) if ending else Color.WHITE
	var state := "open"
	if ending:
		state = GoalSystem.chapter_state(ch)
	var seal := ""
	if ending:
		seal = "章成" if state == "done" else "未竟"
	_card.get_node("LabelLayer/Kicker").text = str(ch.get("label", ""))
	_card.get_node("LabelLayer/Name").text = str(ch.get("name", ""))
	_card.get_node("LabelLayer/Years").text = str(ch.get("years", ""))
	_card.get_node("LabelLayer/Lead").text = str(ch.get("lead", ""))
	var badge: Label = _card.get_node("LabelLayer/Badge")
	badge.text = "主目标"
	var main_lab: Label = _card.get_node("LabelLayer/Main")
	main_lab.text = str(ch.get("main", ""))
	main_lab.position = Vector2(468, 408)
	main_lab.size = Vector2(430, 40)
	var seal_lab: Label = _card.get_node("LabelLayer/Seal")
	seal_lab.text = seal
	_card.get_node("LabelLayer/Hint").text = "点击继续    空格"
	_fill_sides(ch)


func _fill_sides(ch: Dictionary) -> void:
	var box: HBoxContainer = _card.get_node("LabelLayer/Sides")
	for child in box.get_children():
		box.remove_child(child)
		child.free()
	var sides: Array = ch.get("sides", [])
	if sides.is_empty():
		return
	var head := Label.new()
	head.text = "支线"
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", Color("f3ead6"))
	head.add_theme_constant_override("outline_size", 4)
	head.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.9))
	box.add_child(head)
	for side_v in sides:
		var chip := Label.new()
		chip.text = "○  %s" % str(side_v)
		chip.add_theme_font_size_override("font_size", 16)
		chip.add_theme_color_override("font_color", Color("f7f1e4"))
		chip.add_theme_constant_override("outline_size", 4)
		chip.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04, 0.9))
		box.add_child(chip)


func _omen_card(row: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(288, 60)
	var plate := Panel.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("f7f1e4")
	var urgent: bool = Omen.urgent(row)
	box.border_color = Color("8e2a1e") if urgent else Color("d99a2b")
	box.set_border_width_all(1)
	box.border_width_left = 3
	box.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", box)
	card.add_child(plate)
	var icon := TextureRect.new()
	icon.texture = Kit.icon("omen_beacon")
	icon.position = Vector2(8, 16)
	icon.size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	var left := Omen.turns_left(row)
	var when := "下回合" if left <= 1 else "约 %d 回合" % left
	var title := Label.new()
	title.text = "%s · %s" % [str(row.get("title", "")), when]
	title.position = Vector2(40, 6)
	title.size = Vector2(180, 24)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("2a2118"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(title)
	var sub := Label.new()
	sub.text = str(row.get("sub", ""))
	sub.position = Vector2(40, 32)
	sub.size = Vector2(180, 22)
	sub.clip_text = true
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color("6b5b48"))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sub)
	var look := Label.new()
	look.text = "查看"
	look.position = Vector2(228, 18)
	look.size = Vector2(52, 24)
	look.add_theme_font_size_override("font_size", 14)
	look.add_theme_color_override("font_color", Color("8e2a1e"))
	look.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(look)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	var city := str(row.get("city", "yanzhou"))
	hit.pressed.connect(_focus_city.bind(city))
	card.add_child(hit)
	if host:
		host.btn_map["goal_omen"] = hit
	return card


func _focus_city(city: String) -> void:
	var map := get_tree().get_first_node_in_group("world_map")
	if map:
		map.call("focus_city", city)


func _shelve_click(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	GoalSystem.shelve(id)
	mouse.button_index = MOUSE_BUTTON_NONE


func _shelved_row(item: Dictionary) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(288, 36)
	var plate := Panel.new()
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color("e7dcc6")
	box.border_color = Color("b3a894")
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	plate.add_theme_stylebox_override("panel", box)
	row.add_child(plate)
	var title := Label.new()
	title.text = "搁置 · %s" % str(item.get("text", ""))
	title.position = Vector2(10, 6)
	title.size = Vector2(260, 22)
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("6b5b48"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(title)
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(GoalSystem.restore.bind(str(item.get("id", ""))))
	row.add_child(hit)
	return row


func _reward_icon(text: String) -> String:
	if text.find("粮") >= 0:
		return "res_food"
	if text.find("钱") >= 0:
		return "res_gold"
	if text.find("匠") >= 0:
		return "res_craft"
	if text.find("电") >= 0:
		return "res_power"
	if text.find("皇威") >= 0:
		return "res_prestige"
	if text.find("生命") >= 0:
		return "res_strength"
	return ""


func _build_rating() -> void:
	_rating = Control.new()
	_rating.visible = false
	_rating.mouse_filter = Control.MOUSE_FILTER_STOP
	_rating.position = Vector2.ZERO
	_rating.size = Vector2(1280, 720)
	add_child(_rating)
	var back := ColorRect.new()
	back.color = Color("1a140e")
	back.position = Vector2.ZERO
	back.size = Vector2(1280, 720)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rating.add_child(back)
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2.ZERO
	art.size = Vector2(1280, 720)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.45, 0.42, 0.38)
	art.texture = Kit.tex("res://ui/art/chapters/chapter_06_beizhou_xingqing.png")
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rating.add_child(art)
	_rate_label(_rating, "Kicker", Vector2(0, 150), 22, Color("e8cb7c"), "第八十六回合 · 史官")
	_rate_label(_rating, "Rank", Vector2(0, 200), 48, Color("f3ead6"), "")
	_rate_label(_rating, "Line", Vector2(200, 280), 18, Color("f7f1e4"), "")
	var line: Label = _rating.get_node("Line")
	line.size = Vector2(880, 64)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var paper := ColorRect.new()
	paper.color = Color("f3ead6")
	paper.position = Vector2(340, 380)
	paper.size = Vector2(600, 120)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rating.add_child(paper)
	_rate_label(_rating, "Stats", Vector2(360, 396), 16, Color("2a2118"), "")
	var stats: Label = _rating.get_node("Stats")
	stats.size = Vector2(560, 90)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats.add_theme_constant_override("outline_size", 0)
	var close := Button.new()
	close.text = "合上史册"
	close.position = Vector2(540, 540)
	close.size = Vector2(200, 40)
	close.add_theme_font_size_override("font_size", 16)
	close.pressed.connect(_close_rating)
	_rating.add_child(close)


func _rate_label(parent: Control, node_name: String, pos: Vector2, size: int, color: Color, text: String) -> void:
	var lab := Label.new()
	lab.name = node_name
	lab.text = text
	lab.position = pos
	lab.size = Vector2(1280 if pos.x == 0 else 560, size + 16)
	if pos.x == 0:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_constant_override("outline_size", 6)
	lab.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.85))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lab)


func _fill_rating() -> void:
	if _rating == null:
		return
	var page := GoalSystem.verdict()
	var rank: Label = _rating.get_node("Rank")
	rank.text = str(page.get("rank", ""))
	var line: Label = _rating.get_node("Line")
	line.text = str(page.get("line", ""))
	var stats: Label = _rating.get_node("Stats")
	stats.text = "西平 %d    北定 %d    靖内 %d\n皇威 %d    粮 %d    钱 %d\n%s" % [
		GoalSystem.xiping(),
		GoalSystem.beiding(),
		GoalSystem.jingnei(),
		GameState.morale,
		int(GameState.resources.get("food", 0)),
		int(GameState.resources.get("money", 0)),
		Calendar.format_label(GameState.year, GameState.month, GameState.month_span),
	]


func _close_rating() -> void:
	_rating_hold = true
	if _rating:
		_rating.visible = false


func _show_seal() -> void:
	_seal_left = 0.35
	if _seal:
		_seal.visible = true


func _drain_rewards() -> void:
	if GameState.reward_queue.is_empty():
		return
	var batch: Array = GameState.reward_queue.duplicate()
	GameState.reward_queue.clear()
	var origin := _bar.position + Vector2(120, minf(_bar.size.y * 0.45, 180.0))
	var delay := 0.0
	for item_v in batch:
		var item: Dictionary = item_v
		var bad: bool = bool(item.get("bad", false))
		_fly(str(item.get("text", "")), origin, delay, bad)
		if not bad:
			_show_seal()
		delay += 0.08


func fly_debug() -> Array:
	var marks: Array = []
	for child in get_children():
		if str(child.name) != "FlyReward" or not (child is Control):
			continue
		var node: Control = child as Control
		if not node.visible:
			continue
		var center := node.position + node.size * 0.5
		var shown := ""
		if node.get_child_count() > 0 and node.get_child(0) is Label:
			var inner: Label = node.get_child(0) as Label
			shown = inner.text
		var icon_on := false
		var icon_node := node.get_node_or_null("Icon")
		if icon_node != null and icon_node.visible:
			icon_on = true
		marks.append({"t": shown, "x": center.x, "y": center.y, "w": node.size.x, "h": node.size.y, "icon": icon_on})
	return marks


func _build_flyers() -> void:
	# Reused chips, built with the hud. A ColorRect always paints its fill, and
	# z 40 keeps the chip above the goal bar on the way to 朝堂.
	for _i in 4:
		var chip := ColorRect.new()
		chip.name = "FlyReward"
		chip.visible = false
		chip.z_index = 40
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.color = Color("2a2118")
		chip.size = Vector2(112, 32)
		chip.position = Vector2(-200, -200)
		var lab := Label.new()
		lab.name = "Caption"
		lab.position = Vector2.ZERO
		lab.size = chip.size
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_size_override("font_size", 16)
		lab.add_theme_color_override("font_color", Color("e8cb7c"))
		chip.add_child(lab)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(4, 4)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		chip.add_child(icon)
		add_child(chip)


func _take_flyer() -> Control:
	for child in get_children():
		if str(child.name) == "FlyReward" and child is Control:
			var node: Control = child as Control
			if not node.visible:
				return node
	return null


func _fly(text: String, origin: Vector2, delay: float, bad: bool) -> void:
	var chip := _take_flyer()
	if chip == null:
		return
	if chip is ColorRect:
		var fill: ColorRect = chip as ColorRect
		fill.color = Color("8e2a1e") if bad else Color("2a2118")
	var lab: Label = chip.get_node("Caption") as Label
	lab.text = text
	var icon: TextureRect = chip.get_node_or_null("Icon") as TextureRect
	if icon:
		var key := _reward_icon(text)
		if key == "":
			icon.texture = null
			icon.visible = false
			lab.position = Vector2.ZERO
			lab.size = chip.size
		else:
			icon.texture = Kit.icon(key)
			icon.visible = true
			lab.position = Vector2(28, 0)
			lab.size = Vector2(80, 32)
	var ink := Color("f7f1e4") if bad else Color("e8cb7c")
	lab.add_theme_color_override("font_color", ink)
	var dest := Vector2(1100, 26)
	if host and host.btn_map.has("court"):
		var court: Button = host.btn_map["court"]
		if is_instance_valid(court):
			dest = court.get_global_rect().get_center() - global_position
	var mid := (origin + dest) * 0.5 + Vector2(-60, 36)
	chip.position = origin - chip.size * 0.5
	chip.visible = delay <= 0.0
	chip.z_index = 40
	move_child(chip, get_child_count() - 1)
	chip.move_to_front()
	_flights.append({
		"node": chip,
		"origin": origin,
		"mid": mid,
		"dest": dest,
		"delay": delay,
		"elapsed": 0.0,
	})


func _advance_flights(delta: float) -> void:
	if _flights.is_empty():
		return
	var keep: Array = []
	for flight_v in _flights:
		var flight: Dictionary = flight_v
		var node: Control = flight["node"] as Control
		if not is_instance_valid(node):
			continue
		var elapsed := float(flight["elapsed"]) + delta
		flight["elapsed"] = elapsed
		var local := elapsed - float(flight["delay"])
		var duration := fly_time
		if duration < 0.2:
			duration = 0.2
		if local >= duration:
			node.visible = false
			continue
		if local < 0.0:
			keep.append(flight)
			continue
		var tn := local / duration
		var u := 1.0 - tn
		var origin: Vector2 = flight["origin"]
		var mid: Vector2 = flight["mid"]
		var dest: Vector2 = flight["dest"]
		var point := u * u * origin + 2.0 * u * tn * mid + tn * tn * dest
		node.position = point - node.size * 0.5
		node.visible = true
		keep.append(flight)
	_flights = keep


func _build_bar() -> void:
	_bar = Panel.new()
	_bar.position = Vector2(968, 68)
	_bar.size = Vector2(304, 280)
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.add_theme_stylebox_override("panel", _plate(Color("f3ead6"), Color("c6a15b")))
	add_child(_bar)
	var fold := Button.new()
	fold.flat = true
	fold.focus_mode = Control.FOCUS_NONE
	fold.position = Vector2(8, 4)
	fold.size = Vector2(250, 28)
	fold.pressed.connect(_toggle)
	_bar.add_child(fold)
	if host:
		host.btn_map["goal_toggle"] = fold
	_title = Label.new()
	_title.position = Vector2(12, 6)
	_title.size = Vector2(230, 24)
	_title.clip_text = true
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color("2a2118"))
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_title)
	_count = Label.new()
	_count.position = Vector2(262, 6)
	_count.size = Vector2(28, 22)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", Color("f7f1e4"))
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := ColorRect.new()
	pill.color = Color("8e2a1e")
	pill.position = Vector2(262, 8)
	pill.size = Vector2(28, 18)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(pill)
	_bar.add_child(_count)
	_seal = Label.new()
	_seal.text = "已办"
	_seal.visible = false
	_seal.position = Vector2(90, 108)
	_seal.size = Vector2(120, 48)
	_seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seal.add_theme_font_size_override("font_size", 28)
	_seal.add_theme_color_override("font_color", Color("8e2a1e"))
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.z_index = 5
	_bar.add_child(_seal)
	_body = Control.new()
	_body.position = Vector2(8, 36)
	_body.size = Vector2(288, 320)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_body)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(0, 0)
	tabs.add_theme_constant_override("separation", 4)
	_body.add_child(tabs)
	_tab_button(tabs, "本月", "month")
	_tab_button(tabs, "本章", "chapter")
	_tab_button(tabs, "大局", "war")
	_rows = VBoxContainer.new()
	_rows.position = Vector2(0, 36)
	_rows.size = Vector2(288, 220)
	_rows.add_theme_constant_override("separation", 6)
	_body.add_child(_rows)
	_chapter_box = VBoxContainer.new()
	_chapter_box.position = Vector2(0, 36)
	_chapter_box.size = Vector2(288, 240)
	_chapter_box.add_theme_constant_override("separation", 4)
	_chapter_box.visible = false
	_body.add_child(_chapter_box)
	_meters = VBoxContainer.new()
	_meters.position = Vector2(0, 36)
	_meters.size = Vector2(288, 240)
	_meters.add_theme_constant_override("separation", 4)
	_meters.visible = false
	_body.add_child(_meters)


func _tab_button(parent: Node, text: String, which: String) -> void:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(90, 28)
	btn.add_theme_font_size_override("font_size", 14)
	btn.pressed.connect(show_tab.bind(which))
	parent.add_child(btn)
	if host:
		host.btn_map["goal_tab_%s" % which] = btn


func _toggle() -> void:
	collapsed = not collapsed
	_sig = ""
	_sync_bar()


func _build_card() -> void:
	_card = Control.new()
	_card.visible = false
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.position = Vector2.ZERO
	_card.size = Vector2(1280, 720)
	add_child(_card)
	var back := ColorRect.new()
	back.name = "Back"
	back.color = Color("1a140e")
	back.position = Vector2.ZERO
	back.size = Vector2(1280, 720)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(back)
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2.ZERO
	art.size = Vector2(1280, 720)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(art)
	var layer := Control.new()
	layer.name = "LabelLayer"
	layer.position = Vector2.ZERO
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(layer)
	_card_label(layer, "Kicker", Vector2(0, 132), 28, Color("f7f1e4"))
	_card_label(layer, "Name", Vector2(0, 176), 56, Color("f3ead6"))
	_card_label(layer, "Years", Vector2(0, 258), 20, Color("e8cb7c"))
	_card_label(layer, "Lead", Vector2(200, 304), 18, Color("f7f1e4"))
	var lead: Label = layer.get_node("Lead")
	lead.size = Vector2(880, 52)
	lead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var paper := ColorRect.new()
	paper.name = "Paper"
	paper.color = Color("f3ead6")
	paper.position = Vector2(360, 392)
	paper.size = Vector2(560, 72)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(paper)
	var edge := ColorRect.new()
	edge.color = Color("c6a15b")
	edge.position = Vector2(360, 392)
	edge.size = Vector2(560, 3)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(edge)
	_card_label(layer, "Badge", Vector2(376, 412), 14, Color("8e2a1e"))
	var badge: Label = layer.get_node("Badge")
	badge.size = Vector2(88, 32)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge.add_theme_constant_override("outline_size", 0)
	_card_label(layer, "Main", Vector2(468, 408), 18, Color("2a2118"))
	var main: Label = layer.get_node("Main")
	main.size = Vector2(430, 40)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main.add_theme_constant_override("outline_size", 0)
	var sides := HBoxContainer.new()
	sides.name = "Sides"
	sides.position = Vector2(160, 480)
	sides.size = Vector2(960, 36)
	sides.alignment = BoxContainer.ALIGNMENT_CENTER
	sides.add_theme_constant_override("separation", 18)
	sides.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sides)
	_card_label(layer, "Seal", Vector2(0, 560), 42, Color("8e2a1e"))
	var seal: Label = layer.get_node("Seal")
	seal.add_theme_constant_override("outline_size", 0)
	_card_label(layer, "Hint", Vector2(820, 656), 16, Color("f3ead6"))
	var hint: Label = layer.get_node("Hint")
	hint.size = Vector2(420, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hit := Button.new()
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.position = Vector2.ZERO
	hit.size = Vector2(1280, 720)
	hit.pressed.connect(dismiss_card)
	_card.add_child(hit)
	if host:
		host.btn_map["chapter_continue"] = hit


func _card_label(parent: Control, node_name: String, pos: Vector2, size: int, color: Color) -> void:
	var lab := Label.new()
	lab.name = node_name
	lab.position = pos
	lab.size = Vector2(1280 if pos.x == 0 else 920, size + 16)
	if pos.x == 0:
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", color)
	lab.add_theme_constant_override("outline_size", 6)
	lab.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05, 0.85))
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lab)


func _clear_goal_buttons() -> void:
	if host == null:
		return
	var drop: Array[String] = []
	for key_v in host.btn_map.keys():
		var key := str(key_v)
		if key.begins_with("goal_"):
			if key != "goal_toggle" and not key.begins_with("goal_tab_"):
				drop.append(key)
	for key2 in drop:
		host.btn_map.erase(key2)


func _plate(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	return box
