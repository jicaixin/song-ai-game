extends Node

var title_layer: CanvasLayer
var title: TitleScreen
var game_root: Node2D
var world: WorldMap
var ui: GameUI
var ready_flag := false

func _ready() -> void:
	title_layer = CanvasLayer.new()
	title_layer.name = "TitleScreen"
	title_layer.layer = 20
	add_child(title_layer)
	title = TitleScreen.new()
	title_layer.add_child(title)
	title.new_button.pressed.connect(_on_new)
	title.continue_button.pressed.connect(_on_continue)
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


func _on_new() -> void:
	GameState.new_game()
	SaveManager.save_slot(0, true)
	_enter_game()
	world.focus_city(str(DataDB.scenario.get("focus_city", "yanzhou")))


func _on_continue() -> void:
	var slot := SaveManager.newest_slot()
	if slot < 0:
		return
	if not SaveManager.load_slot(slot):
		return
	_enter_game()
	world.focus_after_load()


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
	})
