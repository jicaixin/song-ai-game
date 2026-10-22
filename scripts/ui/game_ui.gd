class_name GameUI
extends Control

const MAT_NAME := {
	"wood": "木",
	"iron": "铁",
	"money": "钱",
	"copper": "铜",
	"saltpeter": "硝",
	"sulfur": "硫",
	"coal": "煤",
	"lead": "铅",
	"steel": "钢",
	"craft": "匠",
}

var top_label: Label
var tile_label: Label
var unit_label: Label
var event_label: Label
var advisor_label: Label
var portrait: TextureRect
var minimap: TextureRect
var mini_frame: Panel
var mini_caption: Label
var end_button: Button
var save_button: Button
var load_button: Button
var tech_button: Button
var combat_panel: Panel
var combat_label: Label
var fight_button: Button
var cancel_button: Button
var tech_panel: Panel
var save_panel: Panel
var pending_atk := -1
var pending_def := -1
var btn_map := {}

func _ready() -> void:
	add_to_group("game_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_side()
	_build_advisor()
	_build_event()
	_build_combat()
	_build_tech()
	_build_save()
	EventBus.state_changed.connect(_refresh)
	EventBus.advisor_changed.connect(_refresh_advisor)


func _build_top() -> void:
	var panel := Panel.new()
	panel.position = Vector2(0, 0)
	panel.size = Vector2(1280, 52)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	top_label = Label.new()
	top_label.position = Vector2(16, 8)
	top_label.size = Vector2(900, 36)
	top_label.clip_text = true
	top_label.add_theme_font_size_override("font_size", 20)
	top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(top_label)
	tech_button = _small_button(panel, "科技", Vector2(960, 6), Vector2(96, 40))
	tech_button.pressed.connect(func() -> void: tech_panel.visible = true)
	save_button = _small_button(panel, "存档", Vector2(1064, 6), Vector2(96, 40))
	save_button.pressed.connect(func() -> void: _open_save(true))
	load_button = _small_button(panel, "读档", Vector2(1168, 6), Vector2(96, 40))
	load_button.pressed.connect(func() -> void: _open_save(false))


func _build_side() -> void:
	var panel := Panel.new()
	panel.position = Vector2(16, 64)
	panel.size = Vector2(400, 176)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	tile_label = _wrap_label(panel, Vector2(12, 8), Vector2(376, 52))
	unit_label = _wrap_label(panel, Vector2(12, 62), Vector2(376, 48))
	event_label = _wrap_label(panel, Vector2(12, 114), Vector2(376, 52))
	event_label.add_theme_color_override("font_color", Color("f4ead2"))
	event_label.add_theme_font_size_override("font_size", 16)
	minimap = TextureRect.new()
	minimap.position = Vector2(1064, 522)
	minimap.size = Vector2(204, 186)
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(_on_mini)
	add_child(minimap)
	mini_frame = Panel.new()
	mini_frame.position = Vector2(1058, 516)
	mini_frame.size = Vector2(216, 198)
	mini_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mini_frame)
	mini_caption = Label.new()
	mini_caption.text = "全图"
	mini_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_caption.add_theme_font_size_override("font_size", 15)
	mini_caption.add_theme_color_override("font_color", Color("f4efe4"))
	mini_caption.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.9))
	mini_caption.add_theme_constant_override("outline_size", 6)
	add_child(mini_caption)
	move_child(minimap, get_child_count() - 1)
	move_child(mini_caption, get_child_count() - 1)
	end_button = Settings.cinnabar_button("结束回合", 8)
	end_button.position = Vector2(1090, 468)
	end_button.size = Vector2(180, 52)
	end_button.pressed.connect(func() -> void: TurnManager.request_end())
	add_child(end_button)
	btn_map = {
		"end_turn": end_button,
		"save": save_button,
		"load": load_button,
		"tech": tech_button,
	}


func _build_advisor() -> void:
	var panel := Panel.new()
	panel.position = Vector2(16, 624)
	panel.size = Vector2(860, 84)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	portrait = TextureRect.new()
	portrait.position = Vector2(8, 10)
	portrait.size = Vector2(64, 64)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = ArtBank.face_tex("serious")
	panel.add_child(portrait)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(84, 8)
	scroll.size = Vector2(760, 68)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)
	advisor_label = Label.new()
	advisor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advisor_label.custom_minimum_size = Vector2(760, 0)
	advisor_label.size = Vector2(760, 68)
	advisor_label.add_theme_font_size_override("font_size", 18)
	advisor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(advisor_label)


func _build_event() -> void:
	pass


func _build_combat() -> void:
	combat_panel = Panel.new()
	combat_panel.position = Vector2(360, 160)
	combat_panel.size = Vector2(560, 280)
	combat_panel.visible = false
	combat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(combat_panel)
	combat_label = _wrap_label(combat_panel, Vector2(16, 12), Vector2(528, 196))
	fight_button = Settings.cinnabar_button("开战")
	fight_button.position = Vector2(16, 220)
	fight_button.size = Vector2(160, 44)
	fight_button.pressed.connect(_confirm_fight)
	combat_panel.add_child(fight_button)
	cancel_button = Button.new()
	cancel_button.text = "罢手"
	cancel_button.position = Vector2(192, 220)
	cancel_button.size = Vector2(160, 44)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(hide_combat)
	combat_panel.add_child(cancel_button)
	btn_map["fight"] = fight_button
	btn_map["cancel"] = cancel_button


func _build_tech() -> void:
	tech_panel = Panel.new()
	tech_panel.position = Vector2(80, 80)
	tech_panel.size = Vector2(760, 520)
	tech_panel.visible = false
	tech_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tech_panel)
	var title := Label.new()
	title.text = "科技树 · 下回可研究"
	title.position = Vector2(16, 10)
	title.size = Vector2(560, 28)
	title.add_theme_font_size_override("font_size", 20)
	tech_panel.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(640, 8)
	close.size = Vector2(100, 36)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: tech_panel.visible = false)
	tech_panel.add_child(close)
	btn_map["tech_close"] = close
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 52)
	scroll.size = Vector2(728, 452)
	tech_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(700, 0)
	scroll.add_child(box)
	var era_names := {}
	for era_v in DataDB.eras:
		era_names[int(era_v.get("id", 0))] = str(era_v.get("name", ""))
	var branch_names := {}
	for b_v in DataDB.branches:
		branch_names[str(b_v.get("id", ""))] = str(b_v.get("name", ""))
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var line := Label.new()
		line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		line.custom_minimum_size = Vector2(700, 0)
		line.text = _tech_line(tech, era_names, branch_names)
		box.add_child(line)


func _tech_line(tech: Dictionary, era_names: Dictionary, branch_names: Dictionary) -> String:
	var pre: Array = tech.get("prereq", [])
	var any: Array = tech.get("prereq_any", [])
	var pre_s := "无"
	if not pre.is_empty():
		pre_s = "、".join(pre)
	if not any.is_empty():
		pre_s = "或 ".join(any) if pre.is_empty() else pre_s + "，另需 " + "或".join(any)
	var cost: Dictionary = tech.get("cost", {})
	var mats := ""
	var mat_dict: Dictionary = tech.get("materials", {})
	if not mat_dict.is_empty():
		var bits: PackedStringArray = []
		for k in mat_dict.keys():
			bits.append("%s%d" % [MAT_NAME.get(str(k), str(k)), int(mat_dict[k])])
		mats = " 材料" + "、".join(bits)
	return "[%s·%s] %s %s 前置%s 电%d 匠%d%s。%s %s" % [
		str(era_names.get(int(tech.get("era", 0)), "")),
		str(branch_names.get(str(tech.get("branch", "")), "")),
		str(tech.get("id", "")),
		str(tech.get("name", "")),
		pre_s,
		int(cost.get("power", 0)),
		int(cost.get("craft", 0)),
		mats,
		str(tech.get("effect", "")),
		str(tech.get("advisor_line", "")),
	]


func _build_save() -> void:
	save_panel = Panel.new()
	save_panel.position = Vector2(420, 160)
	save_panel.size = Vector2(420, 320)
	save_panel.visible = false
	save_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(save_panel)
	var title := Label.new()
	title.name = "SaveTitle"
	title.position = Vector2(16, 10)
	title.size = Vector2(240, 28)
	title.text = "存档"
	save_panel.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.position = Vector2(300, 8)
	close.size = Vector2(100, 36)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func() -> void: save_panel.visible = false)
	save_panel.add_child(close)
	btn_map["save_close"] = close


func _open_save(writing: bool) -> void:
	for c in save_panel.get_children():
		if str(c.name).begins_with("Slot"):
			c.queue_free()
	var title := save_panel.get_node("SaveTitle") as Label
	title.text = "存档" if writing else "读档"
	var labels := ["自动", "槽一", "槽二", "槽三"]
	for i in 4:
		var b := Button.new()
		b.name = "Slot%d" % i
		var has := SaveManager.has_slot(i)
		if writing and i == 0:
			b.text = "自动（回合结束写入）"
			b.disabled = true
		elif writing:
			b.text = "写入%s" % labels[i]
		else:
			b.text = "读取%s%s" % [labels[i], "" if has else "（空）"]
			b.disabled = not has
		b.position = Vector2(20, 64 + i * 56)
		b.size = Vector2(380, 44)
		b.focus_mode = Control.FOCUS_NONE
		var slot := i
		if writing:
			b.pressed.connect(func() -> void:
				SaveManager.save_slot(slot)
				save_panel.visible = false
			)
		else:
			b.pressed.connect(func() -> void:
				if SaveManager.load_slot(slot):
					save_panel.visible = false
					var map := get_tree().get_first_node_in_group("world_map")
					if map:
						map.call("focus_after_load")
			)
		save_panel.add_child(b)
	save_panel.visible = true


func _small_button(parent: Node, text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b


func _wrap_label(parent: Node, pos: Vector2, sz: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = sz
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_constant_override("line_spacing", 0)
	parent.add_child(label)
	return label


func _process(_delta: float) -> void:
	if not visible:
		return
	_refresh()


func _refresh() -> void:
	var weather_name := str(DataDB.balance.get("weather", {}).get(GameState.weather_id, {}).get("name", ""))
	var cap := int(DataDB.balance.get("power", {}).get("battery_max", 80))
	top_label.text = "%s  粮%d 钱%d 匠%d  %s 电%d/%d  第%d回合" % [
		Calendar.format_date(GameState.year, GameState.month),
		int(GameState.resources.get("food", 0)),
		int(GameState.resources.get("money", 0)),
		int(GameState.resources.get("craft", 0)),
		weather_name,
		GameState.battery,
		cap,
		GameState.turn,
	]
	tile_label.text = _tile_text()
	unit_label.text = _unit_text()
	event_label.text = GameState.last_event
	_refresh_advisor()
	end_button.disabled = GameState.input_locked or combat_panel.visible or not GameState.playing
	end_button.text = "西夏行动中" if GameState.input_locked else "结束回合"
	if minimap.texture == null or Engine.get_process_frames() % 20 == 0:
		var map := get_tree().get_first_node_in_group("world_map") as WorldMap
		if map:
			_fit_minimap(map)
			minimap.texture = ImageTexture.create_from_image(map.minimap_image())


func _refresh_advisor() -> void:
	advisor_label.text = GameState.advisor_text
	portrait.texture = ArtBank.face_tex(GameState.advisor_mood)


func _tile_text() -> String:
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map == null or not map.hover_ok:
		return "把指针移到格子上。\n左键选人，右键移动或攻击。"
	var h := map.hover
	var tid := DataDB.terrain_id(h.x, h.y)
	var terr := DataDB.terrain(tid)
	var owner := DataDB.owner_id(h.x, h.y)
	var owner_name := "无主"
	if owner != "":
		owner_name = str(DataDB.faction(owner).get("name", owner))
	var ll := Geo.lonlat(h.x, h.y)
	var lines := "%s · %s\n东经 %.1f 北纬 %.1f" % [str(terr.get("name", tid)), owner_name, ll.x, ll.y]
	var city := DataDB.city_at_hex(h.x, h.y)
	if not city.is_empty():
		lines += "\n%s 城墙%d" % [str(city.get("name", "")), int(city.get("walls", 0))]
	var feat := DataDB.feature_at(h.x, h.y)
	if not feat.is_empty():
		lines += "\n%s" % str(feat.get("name", ""))
	var masks: Array = DataDB.river_masks.get(h, [0, 0])
	if int(masks[1]) != 0:
		lines += "\n大河"
	elif int(masks[0]) != 0:
		lines += "\n河流"
	return lines


func _unit_text() -> String:
	var uid := GameState.inspected_uid if GameState.inspected_uid != -1 else GameState.selected_uid
	var u := GameState.unit_by_id(uid)
	if u.is_empty():
		return "未选择单位"
	var spec := DataDB.unit_type(str(u.def_id))
	var faction := str(DataDB.faction(str(u.faction)).get("name", ""))
	var text := "%s\n%s · %s\n生命 %d  移动 %d/%d" % [
		str(u.name), str(spec.get("name", "")), faction, int(u.hp), int(u.mp), int(u.max_mp),
	]
	if str(u.general) != "":
		text += "\n将领 %s" % str(u.general)
	return text


func show_combat(preview: Dictionary, atk_uid: int, def_uid: int) -> void:
	pending_atk = atk_uid
	pending_def = def_uid
	var atk := GameState.unit_by_id(atk_uid)
	var dfd := GameState.unit_by_id(def_uid)
	var counter := "攻方不受反击" if bool(preview.ranged) else "攻方受伤 %d–%d" % [int(preview.atk_min), int(preview.atk_max)]
	combat_label.text = "攻 %s 战力 %d\n%s\n守 %s 战力 %d\n%s\n守方受伤 %d–%d\n%s" % [
		str(atk.get("name", "")),
		int(preview.atk_power),
		CombatResolver.format_parts(preview.atk_parts),
		str(dfd.get("name", "")),
		int(preview.def_power),
		CombatResolver.format_parts(preview.def_parts),
		int(preview.def_min),
		int(preview.def_max),
		counter,
	]
	combat_panel.visible = true


func _confirm_fight() -> void:
	var a := pending_atk
	var d := pending_def
	var dfd := GameState.unit_by_id(d)
	hide_combat()
	var map := get_tree().get_first_node_in_group("world_map")
	if map and not dfd.is_empty():
		map.call("animate_strike", a, Vector2i(int(dfd.q), int(dfd.r)))
	GameState.resolve_attack(a, d)


func hide_combat() -> void:
	combat_panel.visible = false
	pending_atk = -1
	pending_def = -1


func hide_modals() -> void:
	hide_combat()
	tech_panel.visible = false
	save_panel.visible = false


func modal_open() -> bool:
	return combat_panel.visible or tech_panel.visible or save_panel.visible


func _fit_minimap(map: WorldMap) -> void:
	var src := map.minimap_pixel_size()
	if src.x < 2.0 or src.y < 2.0:
		return
	var fit := Vector2(220, 186)
	var s := minf(fit.x / src.x, fit.y / src.y)
	minimap.size = src * s
	minimap.position = Vector2(1268.0 - minimap.size.x, 708.0 - minimap.size.y)
	if mini_frame:
		mini_frame.position = minimap.position - Vector2(6, 6)
		mini_frame.size = minimap.size + Vector2(12, 12)
	if mini_caption:
		mini_caption.position = minimap.position + Vector2(8, 4)


func _on_mini(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var map := get_tree().get_first_node_in_group("world_map") as WorldMap
		if map == null:
			return
		if not map.overview:
			map.enter_overview()
			return
		var ax := map.minimap_axial(mb.position.x / minimap.size.x, mb.position.y / minimap.size.y)
		map.focus_from_minimap(ax)


func debug_buttons() -> Dictionary:
	var out := {}
	for k in btn_map.keys():
		var b: Button = btn_map[k]
		if not is_instance_valid(b):
			continue
		var r := b.get_global_rect()
		out[str(k)] = {
			"x": r.position.x,
			"y": r.position.y,
			"w": r.size.x,
			"h": r.size.y,
			"visible": b.visible and b.get_parent().visible,
		}
	return out
