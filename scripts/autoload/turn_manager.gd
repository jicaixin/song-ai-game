extends Node

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
	EventBus.state_changed.emit()
	AdvisorSystem.say("enemy_turn")
	await FactionAI.run()
	GameState.finish_turn()
	AdvisorSystem.say_turn()
	SaveManager.save_slot(0, true)
	GameState.input_locked = false
	busy = false
	EventBus.turn_started.emit()
	EventBus.state_changed.emit()
