class_name AdvisorSystem
extends RefCounted

static func say(trigger: String) -> void:
	var line := _pick(trigger, GameState.power_band(), false)
	if line.is_empty():
		return
	GameState.advisor_text = str(line.get("text", ""))
	GameState.advisor_mood = str(line.get("mood", "normal"))
	GameState.cooldowns[str(line.get("id", ""))] = int(line.get("cooldown", 0))
	EventBus.advisor_changed.emit()


static func say_turn() -> void:
	_tick()
	var band := GameState.power_band()
	if band == "normal" and GameState.rng.randf() < 0.4:
		say("chatter")
		return
	if str(GameState.weather_id) != "clear" and GameState.rng.randf() < 0.35:
		say("weather_%s" % str(GameState.weather_id))
		return
	say("turn_start")


static func say_combat(player_dead: bool, enemy_dead: bool) -> void:
	if player_dead and not enemy_dead:
		say("combat_lose")
	elif enemy_dead and not player_dead:
		say("combat_win")
	else:
		say("combat_trade")


static func _tick() -> void:
	var next := {}
	for k in GameState.cooldowns.keys():
		var left := int(GameState.cooldowns[k]) - 1
		if left > 0:
			next[k] = left
	GameState.cooldowns = next


static func _pick(trigger: String, band: String, ignore_cd: bool) -> Dictionary:
	var pool: Array = []
	for line_v in DataDB.lines:
		var line: Dictionary = line_v
		if str(line.get("trigger", "")) != trigger:
			continue
		var pwr := str(line.get("power", "any"))
		if pwr != "any" and pwr != band:
			continue
		if not ignore_cd and int(GameState.cooldowns.get(str(line.get("id", "")), 0)) > 0:
			continue
		pool.append(line)
	if pool.is_empty():
		if not ignore_cd:
			return _pick(trigger, band, true)
		return {}
	return pool[GameState.rng.randi() % pool.size()]
