extends Node

const TechPlan = preload("res://scripts/ui/tech_plan.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")
const EnemyPace = preload("res://scripts/core/enemy_pace.gd")

const Kit = preload("res://scripts/ui/kit.gd")

var title_layer: CanvasLayer
var title: TitleScreen
var game_root: Node2D
var world: WorldMap
var ui: GameUI
var ready_flag := false
var _tech_cmd := ""
var boot_layer: CanvasLayer
var boot_title: Label
var boot_step: Label
var boot_fill: ColorRect

func _ready() -> void:
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleScreen"
	title_layer.layer = 20
	add_child(title_layer)
	title = TitleScreen.new()
	title_layer.add_child(title)
	title.new_button.pressed.connect(_on_new)
	title.continue_button.pressed.connect(_on_continue)
	title.new_button.disabled = true
	title.continue_button.disabled = true
	_build_boot()
	EventBus.map_boot.connect(_on_map_boot)
	EventBus.map_ready.connect(_on_map_ready)
	game_root = Node2D.new()
	game_root.name = "Game"
	add_child(game_root)
	world = WorldMap.new()
	world.name = "WorldMap"
	world.add_to_group("world_map")
	game_root.add_child(world)
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	game_root.add_child(layer)
	ui = GameUI.new()
	ui.name = "UI"
	layer.add_child(ui)
	# Node3D and CanvasLayer do not follow a Node2D parent's visible flag.
	game_root.visible = false
	world.visible = false
	layer.visible = false
	ready_flag = true
	if OS.get_cmdline_user_args().has("--test"):
		var runner = load("res://tests/test_core.gd").new()
		var failed: int = runner.run_tests()
		get_tree().quit(failed)
	if OS.get_cmdline_user_args().has("--sweep") or OS.get_cmdline_user_args().has("--wang"):
		var sweep = load("res://scripts/core/sweep.gd").new()
		var sweep_failed: int = sweep.run() if OS.get_cmdline_user_args().has("--sweep") else sweep.wang_only()
		get_tree().quit(sweep_failed)


func _build_boot() -> void:
	boot_layer = CanvasLayer.new()
	boot_layer.name = "MapBoot"
	boot_layer.layer = 40
	add_child(boot_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	boot_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("1a140c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var face := TextureRect.new()
	face.texture = Kit.doushabao_frame("thinking")
	face.position = Vector2(560, 150)
	face.size = Vector2(160, 160)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face)
	boot_title = Kit.label("豆沙包正在铺延州…", "H2Label")
	boot_title.position = Vector2(240, 330)
	boot_title.size = Vector2(800, 48)
	boot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_title.add_theme_color_override("font_color", Color("f3e9d2"))
	root.add_child(boot_title)
	boot_step = Kit.label("正在展开卷宗", "BodyLabel")
	boot_step.position = Vector2(240, 386)
	boot_step.size = Vector2(800, 32)
	boot_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_step.add_theme_color_override("font_color", Color("e7c98a"))
	root.add_child(boot_step)
	var track := ColorRect.new()
	track.color = Color("2a241c")
	track.position = Vector2(390, 440)
	track.size = Vector2(500, 10)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(track)
	boot_fill = ColorRect.new()
	boot_fill.color = Color("e7c98a")
	boot_fill.position = Vector2.ZERO
	boot_fill.size = Vector2(8, 10)
	boot_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(boot_fill)


func _on_map_boot(step: int, total: int, text: String) -> void:
	if boot_step:
		boot_step.text = text
	if boot_fill and total > 0:
		var width := 500.0 * clampf(float(step) / float(total), 0.08, 1.0)
		boot_fill.size = Vector2(width, 10)


func _on_map_ready() -> void:
	if boot_layer:
		boot_layer.visible = false
	if title:
		title.new_button.disabled = false
		title.refresh_continue()


func _on_new() -> void:
	GameState.new_game()
	SaveManager.save_slot(0, true)
	_enter_game()
	world.focus_city(str(DataDB.scenario.get("focus_city", "yanzhou")))
	if not GameState.tutorial_done:
		ui.start_tutorial()


func _on_continue() -> void:
	var slot := SaveManager.newest_slot()
	if slot < 0:
		return
	if not SaveManager.load_slot(slot):
		return
	_enter_game()
	world.focus_after_load()
	if not GameState.tutorial_done:
		ui.start_tutorial()


func _enter_game() -> void:
	title_layer.visible = false
	game_root.visible = true
	world.visible = true
	var layer := game_root.get_node("UI") as CanvasLayer
	if layer:
		layer.visible = true
	world.full_refresh()
	title.refresh_continue()


func _process(_delta: float) -> void:
	if not DebugBridge.enabled:
		return
	_poll_tech_cmd()
	if Engine.get_process_frames() % 8 != 0:
		return
	var screen := "title"
	if world.visible and not title_layer.visible:
		screen = "game"
	var reachable: Array = []
	var reach_px: Array = []
	for h_v in world.reach_cost.keys():
		var h: Vector2i = h_v
		reachable.append([h.x, h.y])
		var sp := world.world_to_screen(HexGrid.axial_to_pixel(h.x, h.y))
		reach_px.append({"q": h.x, "r": h.y, "sx": sp.x, "sy": sp.y})
	var attacks: Array = []
	var selected := GameState.selected_unit()
	if not selected.is_empty():
		var spec := DataDB.unit_type(str(selected.def_id))
		var max_range := 1
		if int(spec.get("ranged", 0)) > 0:
			max_range = int(spec.get("range", 1))
		for u_v in GameState.units:
			var u: Dictionary = u_v
			if not DataDB.hostile(str(selected.faction), str(u.faction)):
				continue
			var dist := HexGrid.distance(Vector2i(int(selected.q), int(selected.r)), Vector2i(int(u.q), int(u.r)))
			if dist >= 1 and dist <= max_range and int(selected.mp) > 0:
				attacks.append(int(u.uid))
	var buttons: Dictionary = ui.debug_buttons()
	if title:
		var nr := title.new_button.get_global_rect()
		var cr := title.continue_button.get_global_rect()
		buttons["new_game"] = {"x": nr.position.x, "y": nr.position.y, "w": nr.size.x, "h": nr.size.y, "visible": title_layer.visible}
		buttons["continue"] = {"x": cr.position.x, "y": cr.position.y, "w": cr.size.x, "h": cr.size.y, "visible": title_layer.visible and not title.continue_button.disabled}
	var hover := {}
	if world.hover_ok:
		hover = {"q": world.hover.x, "r": world.hover.y}
	DebugBridge.publish({
		"ready": ready_flag and DataDB.cities.size() > 0,
		"screen": screen,
		"turn": GameState.turn,
		"year": GameState.year,
		"month": GameState.month,
		"month_span": GameState.month_span,
		"era": Calendar.era_name(GameState.year, GameState.month),
		"date_label": ui.date_label.text if ui.date_label else "",
		"orders": _order_rows(),
		"food": int(GameState.resources.get("food", 0)),
		"food_start": GameState.food_start,
		"money": int(GameState.resources.get("money", 0)),
		"presearch": GameState.presearch,
		"presearch_cap": GameState.presearch_cap(),
		"shading": GameState.shading,
		"shade_button": ui.shade_button.visible if ui.shade_button else false,
		"notice": GameState.notice,
		"jingnei_mod": GameState.jingnei_mod,
		"order_menu": ui.goals.menu_debug() if ui.goals else {},
		"chapter": str(GoalSystem.current_chapter().get("name", "")),
		"chapter_label": str(GoalSystem.current_chapter().get("label", "")),
		"chapter_open": ui.goals.blocking() if ui.goals else false,
		"chapter_art": [ui.goals.art_size().x, ui.goals.art_size().y] if ui.goals else [0, 0],
		"omen": ui.goals.omen_title() if ui.goals else "",
		"banner_buttons": [ui.pacing._speed_1.text, ui.pacing._speed_2.text, ui.pacing._skip.text] if ui.pacing and ui.pacing._speed_1 else [],
		"goal_tab": ui.goals.tab if ui.goals else "",
		"xiping": GoalSystem.xiping(),
		"beiding": GoalSystem.beiding(),
		"jingnei": GoalSystem.jingnei(),
		"flies": ui.goals.fly_debug() if ui.goals else [],
		"weather": GameState.weather_id,
		"battery": GameState.battery,
		"advisor": GameState.advisor_text,
		"advisor_mood": GameState.advisor_mood,
		"selected": GameState.selected_uid,
		"locked": GameState.input_locked,
		"units": world.debug_units(),
		"hover": hover,
		"reachable": reachable,
		"reach_px": reach_px,
		"attacks": attacks,
		"buttons": buttons,
		"preview": ui.combat_panel.visible,
		"last_event": GameState.last_event,
		"clicks": world.debug_clicks,
		"zoom": world.zoom_index,
		"overview": world.overview,
		"span": world.visible_hex_span(),
		"draw_calls": world.get_meta("draw_calls", -1),
		"prims": world.get_meta("prims", -1),
		"tris": world.get_meta("tris", world._tris),
		"mesh_draws": world.get_meta("mesh_draws", -1),
		"shadow_draws": world.get_meta("shadow_draws", -1),
		"tech_view": ui.desk.tech_view,
		"tech_target": GameState.tech_target,
		"tech_tutorial": ui.desk.tech_tutorial,
		"tech_mode": ui.desk.mode,
		"tech_picked": ui.desk.picked,
		"tech_legend": ui.desk.tech_show_legend,
		"tech_parts": ui.desk.tech_show_parts,
		"tech_bar": ui.desk.tech_legend_bar,
		"tutorial_active": ui.tutorial_active(),
		"tutorial_step": ui.tutorial_step(),
		"tutorial_dim": [ui.tutorial_dim().x, ui.tutorial_dim().y],
		"tutorial_hole": ui.tutorial_hole() if ui.has_method("tutorial_hole") else [],
		"tutorial_done": GameState.tutorial_done,
		"tile_menu": ui.tile_menu_debug() if ui.has_method("tile_menu_debug") else {},
		"hover_head": str(world.hover_plan.get("head", "")),
		"hover_more": world.hover_plan.get("more", []),
		"research_title": ui.research_title.text if ui.research_title else "",
		"research_body": ui.research_body.text if ui.research_body else "",
		"toast": ui.toast_label.text if ui.toast and ui.toast.visible else "",
		"toast_y": ui.toast.position.y if ui.toast else -1,
		"rating_open": ui.goals._rating.visible if ui.goals and ui.goals._rating else false,
		"rating_rank": ui.goals._rating.get_node("Rank").text if ui.goals and ui.goals._rating and ui.goals._rating.visible else "",
		"event_open": ui.pacing.event_open if ui.pacing else false,
		"event_title": ui.pacing._title.text if ui.pacing and ui.pacing.event_open else "",
		"banner": ui.pacing.banner_open if ui.pacing else false,
		"banner_text": ui.pacing._banner_title.text if ui.pacing and ui.pacing.banner_open else "",
		"report": ui.pacing.report_open if ui.pacing else false,
		"report_text": ui.pacing._report_label.text if ui.pacing and ui.pacing.report_open else "",
		"unread": GameState.pending_events.size(),
		"tutorial_bubble": ui.tutorial_bubble_rect() if ui.has_method("tutorial_bubble_rect") else [],
	})


func _frame_yanzhou(map: Node) -> void:
	map.set("overview", false)
	map.set("zoom_index", 2)
	map.set("_debug_dist", 0.0)
	if map.has_method("_sync_grade"):
		map.call("_sync_grade")
	var yan: Dictionary = DataDB.city_by_id("yanzhou")
	var world := HexGrid.axial_to_pixel(int(yan.q), int(yan.r))
	map.set("look_xz", world)
	if map.has_method("_place_camera"):
		map.call("_place_camera")
	if map.has_method("_seat_toward"):
		map.call("_seat_toward", world, Vector2(640, 280))


func _arm_shot() -> void:
	GameState.tutorial_done = true
	GameState.playing = true
	GameState.input_locked = false
	ui.end_enemy_phase()
	if ui.pacing and ui.pacing.event_open:
		ui.pacing._close_event()
	GameState.pending_events.clear()
	GameState.card_queue.clear()
	GameState.reward_queue.clear()
	if ui.goals and ui.goals.blocking():
		ui.goals.dismiss_card()
	if ui.goals:
		ui.goals.sync()
	ui._order_layers()


func _debug_turn(at: int) -> void:
	GameState.turn = at
	var date := Calendar.apply_turn(at)
	GameState.year = date.x
	GameState.month = date.y
	GameState.month_span = date.z


func _order_rows() -> Array:
	var out: Array = []
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		out.append({
			"id": str(item.get("id", "")),
			"text": str(item.get("text", "")),
			"main": bool(item.get("main", false)),
			"note": str(item.get("note", "")),
		})
	return out


func _poll_tech_cmd() -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.__techCmd || ''")
	if not (raw is String):
		return
	var text := str(raw)
	if text == "" or text == _tech_cmd:
		return
	_tech_cmd = text
	var cmd := text.split("|")[0]
	var desk := ui.desk
	if cmd == "sample":
		GameState.load_tech_sample()
		return
	if cmd == "shot_blueprint":
		GameState.tech_designing = ""
		GameState.tech_queue = []
		GameState.tech_trials = []
		GameState.tech_blueprints = ["M02"]
		GameState.pending_blueprint = ""
		GameState.notice = "图纸已成 · 堡寨筑城法"
		GameState.advisor_text = "图纸画好了：堡寨筑城法。去匠作院试制吧。"
		GameState.advisor_mood = "smug"
		EventBus.state_changed.emit()
		return
	if cmd == "shot_event":
		ui.force_event("sanchuan")
		return
	if cmd == "shot_banner":
		GameState.input_locked = true
		ui.begin_enemy_phase(5)
		ui.set_enemy_progress(2, 5, "西夏")
		return
	if cmd == "shot_goals":
		ui.force_event("sanchuan")
		GameState.choose_event("sanchuan", "hold")
		if ui.goals:
			ui.goals.collapsed = false
			ui.goals.show_tab("month")
		return
	if cmd == "shot_chapter":
		GameState.tutorial_done = true
		GameState.card_queue.push_front("start:forts")
		if ui.goals:
			ui.goals.dismiss_card()
		return
	if cmd == "shot_meters":
		GameState.tutorial_done = true
		if ui.goals:
			ui.goals.show_tab("war")
		return
	if cmd == "shot_fly":
		GameState.reward_queue.append({"text": "匠 +12"})
		if ui.goals:
			ui.goals.fly_time = 2.4
			ui.goals.sync()
		return
	if cmd == "pace_slow":
		EnemyPace.pinned = true
		EnemyPace.speed = 0.35
		return
	if cmd == "shot_omen":
		GameState.tutorial_done = true
		GameState.input_locked = false
		_debug_turn(12)
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		if ui.goals:
			if ui.goals.blocking():
				ui.goals.dismiss_card()
			ui.goals.collapsed = false
			ui.goals.show_tab("month")
			ui.goals.sync()
		return
	if cmd == "shot_wanglun":
		GameState.tutorial_done = true
		GameState.input_locked = false
		_debug_turn(38)
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		GoalSystem.on_turn()
		GameState.card_queue.clear()
		GameState.reward_queue.clear()
		if ui.goals:
			if ui.goals.blocking():
				ui.goals.dismiss_card()
			ui.goals._clear_flights()
			ui.goals.collapsed = false
			ui.goals.show_tab("month")
			ui.goals.sync()
		var map := get_tree().get_first_node_in_group("world_map")
		if map:
			map.call("focus_city", "yizhou")
		EventBus.state_changed.emit()
		return
	if cmd == "shot_shelve":
		GameState.tutorial_done = true
		GameState.input_locked = false
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		if ui.goals:
			ui.goals.debug_open_shelve()
		return
	if cmd == "shot_city":
		GameState.tutorial_done = true
		GameState.playing = true
		GameState.input_locked = false
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		GameState.pending_events.clear()
		GameState.card_queue.clear()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		if ui.goals:
			ui.goals.sync()
		ui.open_city("yanzhou")
		ui._order_layers()
		return
	if cmd == "shot_grain":
		GameState.tutorial_done = true
		GameState.input_locked = false
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		var before := int(GameState.resources.get("food", 0))
		GameState.finish_turn()
		GoalSystem.on_turn()
		GameState.notice = "开局粮 %d，结算后 %d，没有强卖。" % [before, int(GameState.resources.get("food", 0))]
		EventBus.state_changed.emit()
		return
	if cmd == "shot_shade":
		GameState.tutorial_done = true
		GameState.input_locked = false
		ui.end_enemy_phase()
		GameState.battery = GameState.battery_cap()
		GameState.presearch = GameState.presearch_cap()
		GameState.shade_skip = 0
		GameState.apply_power()
		EventBus.state_changed.emit()
		return
	if cmd == "shot_rating":
		GameState.tutorial_done = true
		GameState.input_locked = false
		_debug_turn(87)
		ui.end_enemy_phase()
		if ui.pacing and ui.pacing.event_open:
			ui.pacing._close_event()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		GameState.demo_over = true
		GameState.reward_queue.append({"text": "匠 +15"})
		if ui.goals:
			ui.goals._clear_flights()
			ui.goals._rating_hold = false
			ui.goals.sync()
		return
	if cmd == "shot_bargain":
		GameState.tutorial_done = true
		GameState.input_locked = false
		_debug_turn(27)
		GameState.meters["liao_demand"] = 20
		ui.end_enemy_phase()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		ui.force_event("zengbi")
		return
	if cmd == "shot_report":
		GameState.notice = "延州：步跋子 攻击 延州守军，守方 -40，攻方 -23。"
		ui.show_battle_report("庆历元年九月\n延州：步跋子 攻击 延州守军，守方 -40，攻方 -23。\n延州：铁鹞子 攻击 延州守军，守方 -28，攻方 -16。")
		return
	if cmd == "shot_idle":
		GameState.tech_designing = ""
		GameState.tech_queue = []
		GameState.tech_trials = []
		GameState.tech_blueprints = []
		GameState.battery = GameState.battery_cap()
		GameState.research_idle_warned = false
		GameState.battle_lines.clear()
		GameState.pending_blueprint = ""
		GameState.announce_turn()
		EventBus.state_changed.emit()
		return
	if cmd == "demo_garrison":
		_arm_shot()
		GameState.weather_id = "clear"
		var shi_demo := GameState.unit_by_name("石元孙部")
		var yan_demo: Dictionary = DataDB.city_by_id("yanzhou")
		if not shi_demo.is_empty() and not yan_demo.is_empty():
			GameState.spend_mp(int(shi_demo.uid), int(shi_demo.mp))
			GameState.set_pos(int(shi_demo.uid), Vector2i(int(yan_demo.q), int(yan_demo.r)))
		GameState.selected_uid = -1
		GameState.inspected_uid = -1
		ui.close_tile_menu()
		var demo_map := get_tree().get_first_node_in_group("world_map")
		if demo_map:
			demo_map.call("full_refresh")
		EventBus.state_changed.emit()
		return
	if cmd == "frame_wide" or cmd == "frame_near":
		GameState.selected_uid = -1
		GameState.inspected_uid = -1
		ui.close_tile_menu()
		if ui.desk:
			ui.desk.shut()
		var framed := get_tree().get_first_node_in_group("world_map")
		if framed:
			framed.set("overview", false)
			framed.set("_debug_dist", 0.0)
			if cmd == "frame_wide":
				framed.set("zoom_index", 1)
				if framed.has_method("_sync_grade"):
					framed.call("_sync_grade")
				framed.call("focus_city", "yanzhou")
			else:
				_frame_yanzhou(framed)
			framed.call("full_refresh")
		EventBus.state_changed.emit()
		return
	if cmd == "shot_garrison":
		_arm_shot()
		GameState.weather_id = "clear"
		var shi := GameState.unit_by_name("石元孙部")
		var yan: Dictionary = DataDB.city_by_id("yanzhou")
		var city := Vector2i(int(yan.q), int(yan.r))
		GameState.set_pos(int(shi.uid), city)
		GameState.selected_uid = -1
		if ui.desk:
			ui.desk.shut()
		ui.close_tile_menu()
		var map := get_tree().get_first_node_in_group("world_map")
		if map:
			map.call("full_refresh")
			_frame_yanzhou(map)
		EventBus.state_changed.emit()
		return
	if cmd == "shot_pips":
		_arm_shot()
		GameState.weather_id = "clear"
		GameState.selected_uid = -1
		if ui.desk:
			ui.desk.shut()
		ui.close_tile_menu()
		var map2 := get_tree().get_first_node_in_group("world_map")
		if map2:
			map2.call("full_refresh")
			_frame_yanzhou(map2)
		EventBus.state_changed.emit()
		return
	if cmd == "shot_endwarn":
		_arm_shot()
		GameState.weather_id = "clear"
		GameState.end_warn_off = false
		for u_v in GameState.units:
			var u: Dictionary = u_v
			if str(u.get("faction", "")) == "song":
				u.mp = int(u.get("max_mp", 2))
				u.erase("skip_turn")
		TurnManager.confirm_open = false
		TurnManager.request_end()
		return
	if cmd == "shot_autoqueue":
		_arm_shot()
		GameState.load_tech_sample()
		TechPlan.set_target("E05")
		for trial_v in GameState.tech_trials:
			var trial: Dictionary = trial_v
			if str(trial.get("id", "")) == "K02":
				trial["prog"] = int(trial.get("need", 1)) - 1
		GameState.battery = 40
		GameState.finish_turn()
		GameState.announce_turn()
		if ui.desk.mode == "tech":
			ui.desk.shut()
		EventBus.state_changed.emit()
		ui.toast_left = 30.0
		return
	if cmd == "shot_queuewait":
		GameState.new_game()
		_arm_shot()
		_debug_turn(40)
		for tech_v in DataDB.techs:
			var tech: Dictionary = tech_v
			var tid := str(tech.get("id", ""))
			if int(tech.get("era", 1)) == 1 and not GameState.tech_done.has(tid):
				GameState.tech_done.append(tid)
		GameState.tech_designing = "X01"
		GameState.tech_design_prog = 0
		GameState.tech_queue = ["A05", "E02", "K04"]
		GameState.tech_target = ""
		TechPlan.set_target("C07")
		if ui.desk.mode == "tech":
			ui.desk.shut()
		EventBus.state_changed.emit()
		ui.toast_left = 30.0
		return
	if cmd == "shot_bpfly":
		_arm_shot()
		GameState.meters["liao_demand"] = 8
		GameState.card_queue = ["end:liao"]
		if ui.goals:
			ui.goals.fly_time = 8.0
			ui.goals.sync()
		return
	if cmd == "shot_t68" or cmd == "shot_sample":
		_arm_shot()
		GameState.load_tech_sample()
		if cmd == "shot_t68":
			_debug_turn(52)
		desk.tech_view = "focus"
		desk.tech_tutorial = -1
		desk.tech_show_legend = false
		desk.open("tech")
		return
	if cmd == "shot_workshop":
		_arm_shot()
		GameState.load_tech_sample()
		desk.tech_tutorial = -1
		desk.open("workshop")
		return
	if cmd == "shot_era3":
		GameState.new_game()
		_arm_shot()
		_debug_turn(67)
		GameState.battle_lines = []
		GameState.finish_turn()
		GameState.announce_turn()
		if ui.desk:
			ui.desk.shut()
		if ui.goals:
			ui.goals.collapsed = false
			ui.goals.sync()
		EventBus.state_changed.emit()
		ui.toast_left = 30.0
		return
	if cmd == "shot_era3flash":
		GameState.new_game()
		_arm_shot()
		_debug_turn(68)
		GameState.event_flags.erase("era3_open")
		GameState.event_flags.erase("era3_tree_seen")
		GameState.line_history.erase("era3_open")
		GameState.tech_tutorial_done = true
		desk.tech_tutorial = -1
		desk.tech_view = "focus"
		desk.tech_show_legend = false
		desk.open("tech")
		return
	if cmd == "shot_city":
		GameState.new_game()
		_arm_shot()
		GameState.load_tech_sample()
		desk.open_city("daming")
		return
	if cmd == "shot_ch5":
		GameState.new_game()
		_arm_shot()
		_debug_turn(65)
		if ui.goals:
			ui.goals.collapsed = false
			ui.goals.show_tab("chapter")
			ui.goals.sync()
		if ui.desk:
			ui.desk.shut()
		return
	if cmd == "shot_ch5full":
		GameState.new_game()
		_arm_shot()
		_debug_turn(68)
		GameState.tech_blueprints = ["A01", "M01", "C01"]
		if ui.goals:
			ui.goals.collapsed = false
			ui.goals.show_tab("chapter")
			ui.goals.sync()
		if ui.desk:
			ui.desk.shut()
		return
	if cmd == "shot_tech" or cmd == "shot_swap" or cmd == "shot_hud":
		_arm_shot()
		GameState.load_tech_sample()
		GameState.tech_design_prog = 12
		GameState.tech_queue = ["A05"]
		GameState.tech_tutorial_done = true
		desk.tech_tutorial = -1
		desk.tech_view = "focus"
		if cmd == "shot_hud":
			desk.shut()
			EventBus.state_changed.emit()
			return
		desk.open("tech")
		if cmd == "shot_swap":
			var other := ""
			for tech_v in DataDB.techs:
				var tech: Dictionary = tech_v
				var id := str(tech.get("id", ""))
				if id != "A05" and GameState.tech_state(id) == "available":
					other = id
					break
			var board := desk.host.get_child(0)
			if other != "" and board and board.has_method("_open_design_confirm"):
				board.call("_open_design_confirm", other)
		return
	if cmd == "open":
		desk.open("tech")
		return
	if cmd == "focus":
		desk.tech_view = "focus"
		desk.tech_show_legend = false
		desk.tech_show_parts = false
		desk.tech_tutorial = -1
		_show_tech(desk)
		return
	if cmd == "overview":
		desk.tech_view = "overview"
		desk.tech_show_legend = false
		desk.tech_show_parts = false
		desk.tech_tutorial = -1
		_show_tech(desk)
		return
	if cmd == "target":
		desk.tech_view = "focus"
		desk.tech_show_legend = false
		desk.tech_show_parts = false
		desk.tech_tutorial = -1
		desk.tech_legend_bar = 1
		desk.picked = "E05"
		_show_tech(desk)
		TechPlan.set_target("E05")
		return
	if cmd == "tutorial":
		TechPlan.clear_target()
		desk.picked = ""
		desk.tech_view = "focus"
		desk.tech_show_legend = false
		desk.tech_show_parts = false
		desk.tech_legend_bar = 0
		desk.tech_tutorial = 0
		_show_tech(desk)
		return
	if cmd == "legend":
		desk.tech_view = "focus"
		desk.tech_show_parts = false
		desk.tech_tutorial = -1
		desk.tech_show_legend = true
		_show_tech(desk)
		return
	if cmd == "parts":
		desk.tech_view = "focus"
		desk.tech_show_legend = false
		desk.tech_tutorial = -1
		desk.tech_show_parts = true
		_show_tech(desk)
		return
	if cmd == "bar":
		desk.tech_legend_bar = 1
		if desk.mode == "tech":
			desk._fill()
		return
	if cmd.begins_with("pick:"):
		desk.picked = cmd.substr(5)
		if desk.mode == "tech":
			desk._fill()
		return
	if cmd.begins_with("hover:"):
		desk.tech_hover = cmd.substr(6)
		if desk.mode == "tech":
			desk._fill()


func _show_tech(desk: Desk) -> void:
	if desk.mode == "tech":
		desk._fill()
	else:
		desk.open("tech")
