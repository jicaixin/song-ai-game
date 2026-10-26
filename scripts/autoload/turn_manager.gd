extends Node

const EventSystem = preload("res://scripts/core/event_system.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")

var busy := false
var confirm_open := false

func movable_names() -> Array:
	var names: Array = []
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if int(u.get("mp", 0)) <= 0 or bool(u.get("skip_turn", false)):
			continue
		names.append(str(u.get("name", "部队")))
	return names


func needs_end_confirm() -> bool:
	return not GameState.end_warn_off and not movable_names().is_empty()


func request_end() -> void:
	if busy or GameState.input_locked or not GameState.playing:
		return
	if int(GameState.year) == 0:
		return
	if confirm_open:
		confirm_look()
		return
	if needs_end_confirm():
		confirm_open = true
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui and ui.has_method("open_end_confirm"):
			ui.call("open_end_confirm", movable_names())
		return
	_run()


func confirm_look() -> void:
	_take_mute()
	confirm_open = false
	var map := get_tree().get_first_node_in_group("world_map")
	if map and map.has_method("focus_movable"):
		map.call("focus_movable")


func confirm_standby_end() -> void:
	_take_mute()
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if int(u.get("mp", 0)) > 0 and not bool(u.get("skip_turn", false)):
			u["skip_turn"] = true
	confirm_open = false
	_run()


func confirm_force_end() -> void:
	_take_mute()
	confirm_open = false
	_run()


func dismiss_confirm() -> void:
	confirm_open = false
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("close_end_confirm"):
		ui.call("close_end_confirm")


func _take_mute() -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("end_confirm_muted") and bool(ui.call("end_confirm_muted")):
		GameState.end_warn_off = true
	if ui and ui.has_method("close_end_confirm"):
		ui.call("close_end_confirm")


func _run() -> void:
	busy = true
	GameState.input_locked = true
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.call("hide_combat")
		if ui.has_method("begin_enemy_phase"):
			ui.call("begin_enemy_phase", FactionAI.acting_count())
	EventBus.state_changed.emit()
	AdvisorSystem.say("enemy_turn")
	await FactionAI.run()
	if ui and ui.has_method("end_enemy_phase"):
		ui.call("end_enemy_phase")
	var had_battle := not GameState.battle_lines.is_empty()
	GameState.finish_turn()
	var told := GameState.announce_turn()
	if had_battle and ui and ui.has_method("show_battle_report"):
		var date := "%s · %d" % [Calendar.format_label(GameState.year, GameState.month, GameState.month_span), GameState.year]
		ui.call("show_battle_report", "%s\n%s" % [date, GameState.notice])
	elif not told:
		AdvisorSystem.say_turn()
		GameState.notice = "这个月边上很安静。"
	EventSystem.scan()
	GoalSystem.on_turn()
	SaveManager.save_slot(0, true)
	GameState.input_locked = false
	busy = false
	EventBus.turn_started.emit()
	EventBus.state_changed.emit()
