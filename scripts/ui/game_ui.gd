class_name GameUI
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Desk = preload("res://scripts/ui/desk.gd")
const Onboarding = preload("res://scripts/ui/onboarding.gd")

const RES_BAR := [
	["food", "res_food", "HudNumberLabel", Color("6db394")],
	["money", "res_gold", "GoldLabel", Color("e8cb7c")],
	["craft", "res_craft", "HudNumberLabel", Color("d9a35e")],
	["iron", "res_iron", "HudNumberLabel", Color("f3e9d2")],
	["coal", "res_coal", "HudNumberLabel", Color("f3e9d2")],
	["wood", "res_wood", "HudNumberLabel", Color("f3e9d2")],
	["copper", "res_copper", "HudNumberLabel", Color("f3e9d2")],
	["sulfur", "res_sulfur", "HudNumberLabel", Color("f3e9d2")],
	["saltpeter", "res_saltpeter", "HudNumberLabel", Color("f3e9d2")],
]
const WX_ICON := {
	"clear": "wx_sunny",
	"cloudy": "wx_partly",
	"overcast": "wx_overcast",
	"rain": "wx_rain",
	"snow": "wx_snow",
	"dust": "wx_dust",
}

var top_bar: PanelContainer
var date_label: Label
var year_label: Label
var res_labels := {}
var power_label: Label
var weather_icon: TextureRect
var weather_label: Label
var research_card: PanelContainer
var research_title: Label
var research_body: Label
var research_bar: ProgressBar
var unit_card: PanelContainer
var unit_label: Label
var hover_chip: Label
var advisor_root: Control
var advisor_label: Label
var portrait: TextureRect
var dock: Control
var end_button: Button
var home_button: Button
var key_hint: Label
var minimap: TextureRect
var toast: PanelContainer
var toast_label: Label
var toast_left := 0.0
var return_chip: Button
var combat_panel: PanelContainer
var combat_label: Label
var fight_button: Button
var cancel_button: Button
var desk: Desk
var tutor: Onboarding
var btn_map := {}
var _notice_seen := ""


func _ready() -> void:
	add_to_group("game_ui")
	theme = Settings.theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_research()
	_build_unit()
	_build_hover()
	_build_advisor()
	_build_dock()
	_build_toast()
	_build_return()
	_build_combat()
	desk = Desk.new()
	desk.name = "Desk"
	add_child(desk)
	EventBus.state_changed.connect(_refresh)
	EventBus.advisor_changed.connect(_refresh_advisor)


func _build_top() -> void:
	top_bar = Kit.panel("TopBar")
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(1280, 52)
	top_bar.custom_minimum_size = Vector2(1280, 52)
	add_child(top_bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_bar.add_child(row)
	var cartouche := Kit.panel("DateCartouche")
	row.add_child(cartouche)
	var date_box := VBoxContainer.new()
	cartouche.add_child(date_box)
	date_label = Kit.label("", "BrushLabel")
	date_label.add_theme_font_size_override("font_size", 20)
	date_box.add_child(date_label)
	year_label = Kit.label("", "SmallLabel")
	date_box.add_child(year_label)
	for spec_v in RES_BAR:
		var spec: Array = spec_v
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 2)
		row.add_child(pair)
		pair.add_child(Kit.icon_rect(str(spec[1]), 18))
		var num := Kit.label("0", str(spec[2]))
		num.add_theme_color_override("font_color", spec[3])
		pair.add_child(num)
		res_labels[str(spec[0])] = num
	var power := HBoxContainer.new()
	power.add_theme_constant_override("separation", 2)
	row.add_child(power)
	power.add_child(Kit.icon_rect("res_power", 18))
	power_label = Kit.label("0", "PowerLabel")
	power.add_child(power_label)
	weather_icon = Kit.icon_rect("wx_sunny", 18)
	row.add_child(weather_icon)
	weather_label = Kit.label("", "HudMutedLabel")
	row.add_child(weather_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_icon_button(row, "tech", "ui_tech", "格物图", "tech")
	_icon_button(row, "console", "ui_console", "控制台", "console")
	_icon_button(row, "workshop", "bld_workshop", "匠作院", "workshop")
	_icon_button(row, "industry", "bld_watermill", "百工图", "industry")
	_icon_button(row, "talent", "ui_info", "贤才录", "talent")
	_icon_button(row, "court", "ui_court", "朝堂", "court")
	_icon_button(row, "codex", "ui_book", "史册", "codex")
	_icon_button(row, "diplomacy", "ui_diplomacy", "外交", "diplomacy")
	_icon_button(row, "events", "ui_report", "时事", "events")
	_icon_button(row, "save", "ui_save", "存档", "save")
	_icon_button(row, "load", "ui_load", "读档", "load")
	var help := Kit.button("？", "RoundButton")
	help.tooltip_text = "再看开局引导"
	help.custom_minimum_size = Vector2(36, 36)
	help.pressed.connect(replay_tutorial)
	row.add_child(help)
	btn_map["help"] = help


func _icon_button(parent: Node, key: String, icon_name: String, tip: String, screen: String) -> void:
	var b := Kit.button("", "RoundButton")
	b.icon = Kit.icon(icon_name)
	b.expand_icon = true
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(36, 36)
	if screen == "save":
		b.pressed.connect(open_save.bind(true))
	elif screen == "load":
		b.pressed.connect(open_save.bind(false))
	else:
		b.pressed.connect(open_desk.bind(screen))
	parent.add_child(b)
	btn_map[key] = b


func _build_research() -> void:
	research_card = Kit.panel("InkPanel")
	research_card.position = Vector2(16, 68)
	research_card.size = Vector2(300, 112)
	research_card.custom_minimum_size = Vector2(300, 112)
	add_child(research_card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	research_card.add_child(box)
	research_title = Kit.label("格物", "HudLabel")
	box.add_child(research_title)
	research_body = Kit.label("", "HudMutedLabel")
	research_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(research_body)
	research_bar = ProgressBar.new()
	research_bar.theme_type_variation = "NodeBarDesign"
	research_bar.show_percentage = false
	research_bar.custom_minimum_size = Vector2(0, 8)
	box.add_child(research_bar)


func _build_unit() -> void:
	unit_card = Kit.panel("InkPanel")
	unit_card.position = Vector2(16, 188)
	unit_card.size = Vector2(300, 132)
	unit_card.custom_minimum_size = Vector2(300, 132)
	unit_card.visible = false
	add_child(unit_card)
	unit_label = Kit.label("", "HudLabel")
	unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_card.add_child(unit_label)


func _build_hover() -> void:
	key_hint = Kit.label("空格 下一支可动宋军 · Home 回延州", "HudMutedLabel")
	key_hint.position = Vector2(16, 520)
	key_hint.size = Vector2(640, 24)
	key_hint.clip_text = true
	add_child(key_hint)
	hover_chip = Kit.label("", "HudMutedLabel")
	hover_chip.position = Vector2(16, 548)
	hover_chip.size = Vector2(520, 28)
	hover_chip.clip_text = true
	add_child(hover_chip)


func _build_advisor() -> void:
	advisor_root = Control.new()
	advisor_root.position = Vector2(8, 584)
	advisor_root.size = Vector2(900, 132)
	advisor_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(advisor_root)
	portrait = TextureRect.new()
	portrait.position = Vector2(0, 0)
	portrait.size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = Kit.doushabao_frame("serious")
	advisor_root.add_child(portrait)
	var scroll := Kit.panel("ScrollPanel")
	scroll.position = Vector2(108, 16)
	scroll.size = Vector2(760, 104)
	scroll.custom_minimum_size = Vector2(760, 104)
	advisor_root.add_child(scroll)
	advisor_label = Kit.label("", "BodyLabel")
	advisor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advisor_label.custom_minimum_size = Vector2(680, 0)
	advisor_label.add_theme_color_override("font_color", Color("2b2620"))
	scroll.add_child(advisor_label)


func _build_dock() -> void:
	dock = Control.new()
	dock.position = Vector2(1016, 448)
	dock.size = Vector2(256, 268)
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dock)
	var backing := ColorRect.new()
	backing.color = Color("14211ff2")
	backing.position = Vector2.ZERO
	backing.size = dock.size
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.add_child(backing)
	end_button = Kit.button("结束回合", "EndTurnButton")
	end_button.position = Vector2(8, 14)
	end_button.size = Vector2(240, 72)
	end_button.custom_minimum_size = Vector2(240, 72)
	end_button.pressed.connect(func() -> void: TurnManager.request_end())
	dock.add_child(end_button)
	btn_map["end_turn"] = end_button
	var frame := Kit.panel("MinimapFrame")
	frame.position = Vector2(12, 90)
	frame.size = Vector2(232, 128)
	frame.custom_minimum_size = Vector2(232, 128)
	dock.add_child(frame)
	minimap = TextureRect.new()
	minimap.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	minimap.gui_input.connect(_on_mini)
	frame.add_child(minimap)
	home_button = Kit.button("回延州", "Button")
	home_button.position = Vector2(12, 224)
	home_button.size = Vector2(232, 36)
	home_button.custom_minimum_size = Vector2(232, 36)
	home_button.tooltip_text = "回到选中的部队；没有选中时回到延州。快捷键 Home。空格换下一支可动宋军。"
	home_button.pressed.connect(_on_home)
	dock.add_child(home_button)
	btn_map["home"] = home_button


func _build_toast() -> void:
	toast = Kit.panel("ToastBlueprint")
	toast.position = Vector2(390, 80)
	toast.size = Vector2(500, 64)
	toast.custom_minimum_size = Vector2(500, 64)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast_label = Kit.label("", "H3Label")
	toast.add_child(toast_label)


func _build_return() -> void:
	return_chip = Kit.button("按 M 返回", "Button")
	return_chip.position = Vector2(16, 16)
	return_chip.size = Vector2(160, 40)
	return_chip.visible = false
	return_chip.pressed.connect(func() -> void:
		var map := get_tree().get_first_node_in_group("world_map")
		if map:
			map.call("_leave_overview", true)
	)
	add_child(return_chip)


func _build_combat() -> void:
	combat_panel = Kit.panel("InkPanel")
	combat_panel.position = Vector2(280, 160)
	combat_panel.size = Vector2(720, 340)
	combat_panel.custom_minimum_size = Vector2(720, 340)
	combat_panel.visible = false
	add_child(combat_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	combat_panel.add_child(box)
	var title := Kit.label("接战", "H2Label")
	title.add_theme_color_override("font_color", Color("f3e9d2"))
	box.add_child(title)
	combat_label = Kit.label("", "HudLabel")
	combat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(combat_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	fight_button = Kit.button("开战", "PrimaryButton")
	fight_button.custom_minimum_size = Vector2(160, 44)
	fight_button.pressed.connect(_confirm_fight)
	row.add_child(fight_button)
	cancel_button = Kit.button("罢手", "Button")
	cancel_button.custom_minimum_size = Vector2(160, 44)
	cancel_button.pressed.connect(hide_combat)
	row.add_child(cancel_button)
	btn_map["fight"] = fight_button
	btn_map["cancel"] = cancel_button


func start_tutorial() -> void:
	if tutor != null and tutor.active:
		return
	hide_modals()
	if tutor == null:
		tutor = Onboarding.new()
		tutor.name = "Onboarding"
		add_child(tutor)
	tutor.begin(self)


func replay_tutorial() -> void:
	if not GameState.playing:
		return
	start_tutorial()


func tutorial_active() -> bool:
	return tutor != null and tutor.active


func tutorial_step() -> int:
	if tutor == null or not tutor.active:
		return -1
	return tutor.step


func tutorial_dim() -> Vector2:
	if tutor == null or tutor.shade == null:
		return Vector2.ZERO
	return tutor.shade.size


func open_desk(which: String) -> void:
	hide_combat()
	if desk.mode == which:
		desk.shut()
		return
	desk.open(which)


func open_save(writing: bool) -> void:
	hide_combat()
	desk.open_save(writing)


func open_city(id: String) -> void:
	hide_combat()
	desk.open_city(id)


func close_city() -> void:
	if desk.mode == "city":
		desk.shut()


func _process(delta: float) -> void:
	if not visible:
		return
	if toast_left > 0.0:
		toast_left -= delta
		if toast_left <= 0.0:
			toast.visible = false
	_refresh()


func _refresh() -> void:
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	var over := map != null and map.overview
	_set_play_visible(not over)
	return_chip.visible = over
	if over:
		return
	var era := Calendar.era_name(GameState.year, GameState.month)
	var month := Calendar.month_name(GameState.month)
	date_label.text = "%s %s" % [era, month]
	if era.contains("祐"):
		date_label.theme_type_variation = "H2Label"
		date_label.add_theme_color_override("font_color", Color("8e2a1e"))
	else:
		date_label.theme_type_variation = "BrushLabel"
		date_label.add_theme_font_size_override("font_size", 20)
	year_label.text = str(GameState.year)
	for key_v in res_labels.keys():
		var key := str(key_v)
		var num: Label = res_labels[key]
		num.text = str(int(GameState.resources.get(key, 0)))
	var cap := GameState.battery_cap()
	power_label.text = "%d/%d" % [GameState.battery, cap]
	var wx := str(WX_ICON.get(GameState.weather_id, "wx_sunny"))
	weather_icon.texture = Kit.icon(wx)
	weather_label.text = str(DataDB.balance.get("weather", {}).get(GameState.weather_id, {}).get("name", ""))
	_refresh_research()
	_refresh_unit()
	_refresh_hover(map)
	_refresh_advisor()
	_refresh_toast()
	var waiting := _song_waiting()
	end_button.disabled = GameState.input_locked or modal_open() or not GameState.playing
	if GameState.input_locked:
		end_button.text = "西夏行动中"
		end_button.theme_type_variation = "EndTurnButton"
	else:
		end_button.text = "结束回合"
		end_button.theme_type_variation = "EndTurnAlertButton" if waiting else "EndTurnButton"
	var pace := 20
	if map and (map._pan_active or map.dragging):
		pace = 4
	if map and (minimap.texture == null or Engine.get_process_frames() % pace == 0):
		minimap.texture = ImageTexture.create_from_image(map.minimap_image())


func _set_play_visible(show_hud: bool) -> void:
	top_bar.visible = show_hud
	research_card.visible = show_hud
	advisor_root.visible = show_hud
	dock.visible = show_hud
	if key_hint:
		key_hint.visible = show_hud
	if not show_hud:
		unit_card.visible = false
		hover_chip.visible = false
		toast.visible = false


func _refresh_research() -> void:
	if GameState.tech_designing != "":
		var tech: Dictionary = DataDB.tech_by_id.get(GameState.tech_designing, {})
		var state := GameState.tech_state(GameState.tech_designing)
		research_title.text = "停电" if state == "nopower" else "设计中"
		research_body.text = str(tech.get("name", GameState.tech_designing))
		research_bar.visible = true
		research_bar.theme_type_variation = "NodeBarNoPower" if state == "nopower" else "NodeBarDesign"
		research_bar.max_value = float(GameState.design_need(GameState.tech_designing))
		research_bar.value = float(GameState.tech_design_prog)
	elif not GameState.tech_trials.is_empty():
		var trial: Dictionary = GameState.tech_trials[0]
		var tech: Dictionary = DataDB.tech_by_id.get(str(trial.get("id", "")), {})
		research_title.text = "试制中"
		research_body.text = "%s  %d/%d" % [str(tech.get("name", "")), int(trial.get("prog", 0)), int(trial.get("need", 1))]
		research_bar.visible = true
		research_bar.theme_type_variation = "NodeBarTrial"
		research_bar.max_value = float(maxi(1, int(trial.get("need", 1))))
		research_bar.value = float(int(trial.get("prog", 0)))
	elif not GameState.tech_queue.is_empty():
		var tech: Dictionary = DataDB.tech_by_id.get(str(GameState.tech_queue[0]), {})
		research_title.text = "队列"
		research_body.text = str(tech.get("name", ""))
		research_bar.visible = false
	else:
		research_title.text = "格物"
		research_body.text = "还没开题。按 T。"
		research_bar.visible = false


func _refresh_unit() -> void:
	var uid := GameState.inspected_uid if GameState.inspected_uid != -1 else GameState.selected_uid
	var u := GameState.unit_by_id(uid)
	unit_card.visible = not u.is_empty()
	if u.is_empty():
		return
	var spec := DataDB.unit_type(str(u.def_id))
	var faction := str(DataDB.faction(str(u.faction)).get("name", ""))
	var text := "%s\n%s · %s\n生命 %d    移动 %d/%d" % [
		str(u.name), str(spec.get("name", "")), faction, int(u.hp), int(u.mp), int(u.max_mp),
	]
	if str(u.general) != "":
		text += "\n将领 %s" % str(u.general)
	unit_label.text = text


func _refresh_hover(map: WorldMap) -> void:
	if map == null or not map.hover_ok:
		hover_chip.visible = false
		return
	hover_chip.visible = true
	var h := map.hover
	var tid := DataDB.terrain_id(h.x, h.y)
	var terr := DataDB.terrain(tid)
	var owner := DataDB.owner_id(h.x, h.y)
	var owner_name := "无主"
	if owner != "":
		owner_name = str(DataDB.faction(owner).get("name", owner))
	var line := "%s · %s" % [str(terr.get("name", tid)), owner_name]
	var city := DataDB.city_at_hex(h.x, h.y)
	if not city.is_empty():
		line += " · %s" % str(city.get("name", ""))
	hover_chip.text = line


func _refresh_advisor() -> void:
	advisor_label.text = GameState.advisor_text
	portrait.texture = Kit.doushabao_frame(GameState.advisor_mood)


func _refresh_toast() -> void:
	if GameState.notice == "" or GameState.notice == _notice_seen:
		return
	_notice_seen = GameState.notice
	toast_label.text = GameState.notice
	toast.visible = true
	toast_left = 4.0


func _song_waiting() -> bool:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) == "song" and int(u.get("hp", 0)) > 0 and int(u.get("mp", 0)) > 0:
			return true
	return false


func show_combat(preview: Dictionary, atk_uid: int, def_uid: int) -> void:
	set_meta("atk", atk_uid)
	set_meta("def", def_uid)
	var atk := GameState.unit_by_id(atk_uid)
	var dfd := GameState.unit_by_id(def_uid)
	var counter := "攻方不受反击" if bool(preview.ranged) else "攻方受伤 %d–%d" % [int(preview.atk_min), int(preview.atk_max)]
	combat_label.text = "攻 %s  战力 %d\n%s\n守 %s  战力 %d\n%s\n守方受伤 %d–%d\n%s" % [
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
	if desk.is_open():
		desk.shut()
	combat_panel.visible = true


func _confirm_fight() -> void:
	var a := int(get_meta("atk", -1))
	var d := int(get_meta("def", -1))
	var dfd := GameState.unit_by_id(d)
	hide_combat()
	var map := get_tree().get_first_node_in_group("world_map")
	if map and not dfd.is_empty():
		map.call("animate_strike", a, Vector2i(int(dfd.q), int(dfd.r)))
	GameState.resolve_attack(a, d)


func hide_combat() -> void:
	combat_panel.visible = false
	set_meta("atk", -1)
	set_meta("def", -1)


func hide_modals() -> void:
	hide_combat()
	if desk:
		desk.shut()


func modal_open() -> bool:
	return combat_panel.visible or (desk != null and desk.is_open())


func blocks_pointer(screen: Vector2) -> bool:
	if modal_open():
		return true
	if return_chip.visible and return_chip.get_global_rect().has_point(screen):
		return true
	if not top_bar.visible:
		return false
	if top_bar.get_global_rect().has_point(screen):
		return true
	if advisor_root.get_global_rect().has_point(screen):
		return true
	if dock.get_global_rect().has_point(screen):
		return true
	if research_card.visible and research_card.get_global_rect().has_point(screen):
		return true
	if unit_card.visible and unit_card.get_global_rect().has_point(screen):
		return true
	if hover_chip.visible and hover_chip.get_global_rect().has_point(screen):
		return true
	return false


func _on_home() -> void:
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map:
		map.return_home()


func _on_mini(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var map := get_tree().get_first_node_in_group("world_map") as WorldMap
		if map == null or minimap.size.x < 2.0 or minimap.size.y < 2.0:
			return
		var ax := map.minimap_axial(mb.position.x / minimap.size.x, mb.position.y / minimap.size.y)
		map.focus_from_minimap(ax)


func debug_buttons() -> Dictionary:
	var out := {}
	for key_v in btn_map.keys():
		var key := str(key_v)
		var b: Button = btn_map[key]
		if not is_instance_valid(b):
			continue
		_put_button(out, key, b)
	if desk:
		for key_v2 in desk.debug_btns.keys():
			var key2 := str(key_v2)
			var extra: Button = desk.debug_btns[key2]
			if is_instance_valid(extra):
				_put_button(out, key2, extra)
	return out


func _put_button(out: Dictionary, key: String, b: Button) -> void:
	var r := b.get_global_rect()
	out[key] = {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "visible": b.is_visible_in_tree()}
