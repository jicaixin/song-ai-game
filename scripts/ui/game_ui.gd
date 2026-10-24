class_name GameUI
extends Control

const Kit = preload("res://scripts/ui/kit.gd")
const Desk = preload("res://scripts/ui/desk.gd")
const Onboarding = preload("res://scripts/ui/onboarding.gd")
const TileMenuSc = preload("res://scripts/ui/tile_menu.gd")
const TileTipSc = preload("res://scripts/ui/tile_tip.gd")
const TileMarksSc = preload("res://scripts/ui/tile_marks.gd")
const PacingHudSc = preload("res://scripts/ui/pacing_hud.gd")
const GoalHudSc = preload("res://scripts/ui/goal_hud.gd")

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
var unit_close: Button
var unit_reason: Label
var block_line := ""
var tile_menu
var tile_tip
var tile_marks
var _combat_back: Dictionary = {}
var advisor_root: Control
var advisor_label: Label
var portrait: TextureRect
var dock: Control
var end_button: Button
var home_button: Button
var key_hint: Label
var key_plate: PanelContainer
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
var pacing
var goals
var btn_map := {}
var _enemy_dots := 0
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
	_build_tiles()
	desk = Desk.new()
	desk.name = "Desk"
	desk.z_index = 60
	add_child(desk)
	pacing = PacingHudSc.new()
	pacing.name = "PacingHud"
	pacing.z_index = 70
	add_child(pacing)
	pacing.setup(self)
	goals = GoalHudSc.new()
	goals.name = "GoalHud"
	goals.z_index = 50
	add_child(goals)
	goals.setup(self)
	EventBus.state_changed.connect(_refresh)
	EventBus.advisor_changed.connect(_refresh_advisor)
	EventBus.camera_moved.connect(_on_camera_moved)
	EventBus.turn_started.connect(close_tile_menu)


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
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	unit_card.add_child(holder)
	unit_label = Kit.label("", "HudLabel")
	unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_label.position = Vector2(10, 8)
	unit_label.size = Vector2(248, 96)
	holder.add_child(unit_label)
	unit_close = Kit.button("×", "Button")
	unit_close.position = Vector2(262, 6)
	unit_close.custom_minimum_size = Vector2(28, 28)
	unit_close.pressed.connect(_deselect_unit)
	holder.add_child(unit_close)
	unit_reason = Kit.label("", "MenuReasonLabel")
	unit_reason.position = Vector2(10, 104)
	unit_reason.size = Vector2(270, 36)
	unit_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	unit_reason.visible = false
	holder.add_child(unit_reason)
	btn_map["unit_close"] = unit_close


func _build_hover() -> void:
	key_plate = PanelContainer.new()
	key_plate.position = Vector2(16, 504)
	key_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("14211f")
	plate.border_color = Color("e7c98a")
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(6)
	plate.content_margin_left = 10
	plate.content_margin_top = 6
	plate.content_margin_right = 10
	plate.content_margin_bottom = 6
	key_plate.add_theme_stylebox_override("panel", plate)
	add_child(key_plate)
	key_hint = Kit.label("空格 下一支可动宋军 · Home 回延州 · Shift 看明细", "HudLabel")
	key_hint.add_theme_color_override("font_color", Color("f7f1e4"))
	key_hint.add_theme_color_override("font_outline_color", Color("1a2428"))
	key_hint.add_theme_constant_override("outline_size", 4)
	key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_plate.add_child(key_hint)


func _build_tiles() -> void:
	tile_marks = TileMarksSc.new()
	tile_marks.name = "TileMarks"
	tile_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tile_marks)
	tile_tip = TileTipSc.new()
	tile_tip.name = "TileTip"
	add_child(tile_tip)
	tile_menu = TileMenuSc.new()
	tile_menu.name = "TileMenu"
	tile_menu.closed.connect(_on_tile_menu_closed)
	add_child(tile_menu)


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
	toast_label.add_theme_color_override("font_color", Color("f7f1e4"))
	toast_label.add_theme_color_override("font_outline_color", Color("1a2428"))
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.add_theme_font_size_override("font_size", 16)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(460, 0)
	toast_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toast.add_child(toast_label)
	toast.z_index = 55


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
	combat_panel.z_index = 70
	add_child(combat_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	combat_panel.add_child(box)
	var title := Kit.label("战斗明细", "H2Label")
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
	cancel_button = Kit.button("取消", "Button")
	cancel_button.custom_minimum_size = Vector2(160, 44)
	cancel_button.pressed.connect(_cancel_detail)
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


func tutorial_bubble_rect() -> Array:
	if tutor == null or tutor.bubble == null or not tutor.active:
		return []
	var rect := tutor.bubble.get_global_rect()
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func tutorial_hole() -> Array:
	if tutor == null or not tutor.active:
		return []
	var hole := tutor.hole_global
	return [hole.position.x, hole.position.y, hole.size.x, hole.size.y]


func open_desk(which: String) -> void:
	close_tile_menu()
	hide_combat()
	clear_hover_tip()
	if which == "events":
		GameState.report_unread = false
	if desk.mode == which:
		desk.shut()
		return
	desk.open(which)


func open_save(writing: bool) -> void:
	hide_combat()
	desk.open_save(writing)


func open_city(id: String) -> void:
	close_tile_menu()
	hide_combat()
	desk.open_city(id)


func close_city() -> void:
	if desk.mode == "city":
		desk.shut()


func _process(delta: float) -> void:
	if not visible:
		return
	if toast_left > 0.0 and not GameState.input_locked and not _chapter_blocking():
		toast_left -= delta
		if toast_left <= 0.0:
			toast.visible = false
	if pacing:
		pacing.tick(delta)
	if goals:
		goals.tick(delta)
	_refresh()


func _refresh() -> void:
	if GameState.input_locked:
		close_tile_menu()
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	var over := map != null and map.overview
	_set_play_visible(not over)
	return_chip.visible = over
	if over:
		return
	var era := Calendar.era_name(GameState.year, GameState.month)
	date_label.text = Calendar.format_label(GameState.year, GameState.month, GameState.month_span)
	if era.contains("祐"):
		date_label.theme_type_variation = "H2Label"
		date_label.add_theme_color_override("font_color", Color("8e2a1e"))
	else:
		date_label.theme_type_variation = "BrushLabel"
		date_label.add_theme_font_size_override("font_size", 16 if GameState.month_span >= 2 else 20)
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
	_refresh_advisor()
	_refresh_toast()
	var waiting := _song_waiting()
	end_button.disabled = GameState.input_locked or modal_open() or not GameState.playing
	if GameState.input_locked:
		_enemy_dots = int(Time.get_ticks_msec() / 350) % 4
		var dots := ""
		if _enemy_dots == 1:
			dots = "."
		elif _enemy_dots == 2:
			dots = ".."
		elif _enemy_dots == 3:
			dots = "…"
		end_button.text = "敌方行动中" + dots
		end_button.theme_type_variation = "EndTurnButton"
	else:
		end_button.text = "结束回合"
		end_button.theme_type_variation = "EndTurnAlertButton" if waiting else "EndTurnButton"
	var pace := 20
	if map and (map._pan_active or map.dragging):
		pace = 4
	if map and (minimap.texture == null or Engine.get_process_frames() % pace == 0):
		minimap.texture = ImageTexture.create_from_image(map.minimap_image())
	if pacing:
		pacing.sync()
	if goals:
		goals.sync()


func _set_play_visible(show_hud: bool) -> void:
	top_bar.visible = show_hud
	research_card.visible = show_hud
	advisor_root.visible = show_hud
	dock.visible = show_hud
	if key_plate:
		key_plate.visible = show_hud
	elif key_hint:
		key_hint.visible = show_hud
	if goals:
		goals.visible = show_hud
	if not show_hud:
		unit_card.visible = false
		toast.visible = false
		close_tile_menu()
		clear_hover_tip()


func _refresh_research() -> void:
	var blurb := GameState.research_blurb()
	research_title.text = str(blurb.get("title", "格物"))
	research_body.text = str(blurb.get("body", ""))
	var ink := Color("ff6a4a") if bool(blurb.get("alert", false)) else Color("f3e9d2")
	research_title.add_theme_color_override("font_color", ink)
	research_body.add_theme_color_override("font_color", ink)
	if GameState.tech_designing != "":
		var state := GameState.tech_state(GameState.tech_designing)
		research_bar.visible = true
		research_bar.theme_type_variation = "NodeBarNoPower" if state == "nopower" else "NodeBarDesign"
		research_bar.max_value = float(GameState.design_need(GameState.tech_designing))
		research_bar.value = float(GameState.tech_design_prog)
	elif not GameState.tech_trials.is_empty():
		var trial: Dictionary = GameState.tech_trials[0]
		research_bar.visible = true
		research_bar.theme_type_variation = "NodeBarTrial"
		research_bar.max_value = float(maxi(1, int(trial.get("need", 1))))
		research_bar.value = float(int(trial.get("prog", 0)))
	else:
		research_bar.visible = false


func _panel_uid() -> int:
	if menu_is_open():
		return GameState.selected_uid
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map != null and map.hover_ok:
		var occ: Dictionary = GameState.unit_at(map.hover)
		if not occ.is_empty():
			return int(occ.uid)
	return GameState.selected_uid


func _refresh_unit() -> void:
	var uid := _panel_uid()
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
	var show_reason := block_line != "" and not menu_is_open() and GameState.inspected_uid == int(u.uid)
	unit_reason.visible = show_reason
	unit_reason.text = block_line if show_reason else ""
	var tall := 168 if show_reason else 132
	unit_card.size = Vector2(300, tall)
	unit_card.custom_minimum_size = Vector2(300, tall)


func _refresh_advisor() -> void:
	advisor_label.text = GameState.advisor_text
	portrait.texture = Kit.doushabao_frame(GameState.advisor_mood)


func hold_toast() -> void:
	if toast.visible and _notice_seen == GameState.notice:
		_notice_seen = ""
	toast.visible = false


func _chapter_blocking() -> bool:
	return goals != null and goals.blocking()


func _refresh_toast() -> void:
	if _chapter_blocking():
		if toast.visible and _notice_seen == GameState.notice:
			_notice_seen = ""
		toast.visible = false
		return
	if GameState.report_hold:
		toast.visible = false
		_notice_seen = GameState.notice
		return
	if GameState.notice == "" or GameState.notice == _notice_seen:
		return
	_notice_seen = GameState.notice
	toast_label.text = GameState.notice
	var rows := GameState.notice.split("\n").size()
	var tall := 28.0 + float(rows) * 26.0
	toast.size = Vector2(520, maxf(64.0, tall))
	toast.custom_minimum_size = toast.size
	toast.visible = true
	toast_left = 4.0


func _song_waiting() -> bool:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) == "song" and int(u.get("hp", 0)) > 0 and int(u.get("mp", 0)) > 0 and not bool(u.get("skip_turn", false)):
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
	_combat_back = {}
	combat_panel.visible = false
	set_meta("atk", -1)
	set_meta("def", -1)


func _cancel_detail() -> void:
	var back := _combat_back
	_combat_back = {}
	combat_panel.visible = false
	set_meta("atk", -1)
	set_meta("def", -1)
	if back.is_empty():
		return
	var hex: Vector2i = back.get("hex", Vector2i(999999, 0))
	var anchor: Vector2 = back.get("anchor", Vector2.ZERO)
	open_tile_menu(back.get("plan", {}), hex, anchor, float(back.get("radius", 40.0)))


func hide_modals() -> void:
	if pacing and pacing.event_open:
		return
	if goals and goals.blocking():
		goals.dismiss_card()
		return
	if pacing and pacing.report_open:
		pacing.dismiss_report()
		return
	if combat_panel.visible:
		_cancel_detail()
		return
	if desk:
		desk.shut()


func modal_open() -> bool:
	if pacing and pacing.event_blocking():
		return true
	if goals and goals.blocking():
		return true
	return combat_panel.visible or (desk != null and desk.is_open())


func begin_enemy_phase(total: int) -> void:
	if pacing:
		pacing.show_banner(total)


func set_enemy_progress(done: int, total: int, faction_name: String) -> void:
	if pacing:
		pacing.set_progress(done, total, faction_name)


func end_enemy_phase() -> void:
	if pacing:
		pacing.hide_banner()


func show_battle_report(text: String) -> void:
	if pacing:
		pacing.show_report(text)


func force_event(id: String) -> void:
	if tutor and tutor.active:
		tutor._finish()
	GameState.tutorial_done = true
	if pacing:
		pacing.force_event(id)


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
	if tile_menu and tile_menu.has_method("debug_buttons"):
		var menu_btns: Dictionary = tile_menu.debug_buttons()
		for key_v3 in menu_btns.keys():
			out[str(key_v3)] = menu_btns[key_v3]
	return out


func open_tile_menu(plan: Dictionary, hex: Vector2i, anchor: Vector2, radius: float) -> void:
	clear_hover_tip()
	if tile_menu == null:
		return
	tile_menu.open_at(plan, hex, anchor, radius)
	EventBus.tile_menu.emit(true)
	_refresh_unit()


func close_tile_menu() -> void:
	if tile_menu and tile_menu.is_open():
		tile_menu.shut()
		_refresh_unit()


func menu_is_open() -> bool:
	return tile_menu != null and tile_menu.is_open()


func tile_menu_key(event: InputEventKey) -> bool:
	if tile_menu == null:
		return false
	return tile_menu.handle_key(event)


func move_tile_menu(anchor: Vector2, radius: float) -> void:
	if tile_menu and tile_menu.has_method("move_anchor"):
		tile_menu.move_anchor(anchor, radius)


func present_hover(hex: Vector2i, plan: Dictionary) -> void:
	if not menu_is_open():
		_refresh_unit()
	if tile_tip == null:
		return
	if tutorial_active() or menu_is_open() or modal_open() or GameState.input_locked:
		tile_tip.clear_tip()
		return
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map and (map.dragging or map.animating or map.suspend > 0):
		tile_tip.clear_tip()
		return
	tile_tip.present(hex, plan)


func clear_hover_tip() -> void:
	if tile_tip and tile_tip.has_method("clear_tip"):
		tile_tip.clear_tip()
	if not menu_is_open():
		_refresh_unit()


func shake_tip() -> void:
	if tile_tip and tile_tip.has_method("shake"):
		tile_tip.shake()


func set_block_line(text: String) -> void:
	block_line = text
	_refresh_unit()


func clear_block_line() -> void:
	set_block_line("")


func arm_combat_return(plan: Dictionary, hex: Vector2i, anchor: Vector2, radius: float) -> void:
	_combat_back = {"plan": plan, "hex": hex, "anchor": anchor, "radius": radius}


func tile_menu_debug() -> Dictionary:
	if not menu_is_open():
		return {"open": false}
	var labels: Array = []
	for row_v in tile_menu.rows:
		var row: Dictionary = row_v
		var lab: Label = row.get("button")
		var key := str(row.get("key", ""))
		labels.append("%s|%s" % [lab.text if lab else "", key])
	var rect := Rect2()
	if tile_menu.card:
		rect = tile_menu.card.get_global_rect()
	return {
		"open": true,
		"q": tile_menu.target.x,
		"r": tile_menu.target.y,
		"sub": tile_menu.subtitle,
		"rows": labels,
		"x": rect.position.x,
		"y": rect.position.y,
		"w": rect.size.x,
		"h": rect.size.y,
		"panel": unit_label.text if unit_label else "",
	}


func _deselect_unit() -> void:
	block_line = ""
	GameState.selected_uid = -1
	GameState.inspected_uid = -1
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map:
		map.full_refresh()
	EventBus.state_changed.emit()


func _on_camera_moved() -> void:
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map and map._menu_hold:
		return
	close_tile_menu()
	clear_hover_tip()


func _on_tile_menu_closed() -> void:
	EventBus.tile_menu.emit(false)


func _put_button(out: Dictionary, key: String, b: Button) -> void:
	var r := b.get_global_rect()
	out[key] = {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "visible": b.is_visible_in_tree()}
