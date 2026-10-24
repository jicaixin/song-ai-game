extends Node

const EventSystem = preload("res://scripts/core/event_system.gd")

var busy := false

func request_end() -> void:
	if busy or GameState.input_locked or not GameState.playing:
		return
	if int(GameState.year) == 0:
		return
	_run()


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
		var date := Calendar.format_date(GameState.year, GameState.month)
		ui.call("show_battle_report", "%s\n%s" % [date, GameState.notice])
	elif not told:
		AdvisorSystem.say_turn()
		GameState.notice = "这个月边上很安静。"
	EventSystem.scan()
	SaveManager.save_slot(0, true)
	GameState.input_locked = false
	busy = false
	EventBus.turn_started.emit()
	EventBus.state_changed.emit()
