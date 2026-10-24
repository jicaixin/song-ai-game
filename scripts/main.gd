extends Node

const TechPlan = preload("res://scripts/ui/tech_plan.gd")

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
		"era": Calendar.era_name(GameState.year, GameState.month),
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
		"notice": GameState.notice,
		"research_title": ui.research_title.text if ui.research_title else "",
		"research_body": ui.research_body.text if ui.research_body else "",
		"toast": ui.toast_label.text if ui.toast and ui.toast.visible else "",
		"tutorial_bubble": ui.tutorial_bubble_rect() if ui.has_method("tutorial_bubble_rect") else [],
	})


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
