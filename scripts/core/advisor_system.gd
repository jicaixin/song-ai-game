class_name AdvisorSystem
extends RefCounted

static var _rng := RandomNumberGenerator.new()
static var _seeded_turn := -99999


static func reset_rng() -> void:
	_seeded_turn = -99999


static func say(trigger: String) -> void:
	_seed()
	var line := _pick(trigger, GameState.power_band())
	if line.is_empty():
		return
	_commit(line)


static func say_turn() -> void:
	_tick()
	_seed()
	var band := GameState.power_band()
	if band == "low":
		var telegraph := _pick("turn_start", band)
		if telegraph.is_empty():
			_fallback("电。少。第%d回合。" % GameState.turn)
		else:
			_commit(telegraph)
		return
	if band == "save":
		var saved := _pick("turn_start", band)
		if saved.is_empty():
			_fallback("省电。第%d回合。延州优先。" % GameState.turn)
		else:
			_commit(saved)
		return
	var order: Array[String] = []
	if str(GameState.weather_id) != "clear" and _rng.randf() < 0.35:
		order.append("weather_%s" % str(GameState.weather_id))
	if _rng.randf() < 0.4:
		order.append("chatter")
	order.append("turn_start")
	order.append("chatter")
	for trigger in order:
		var line := _pick(trigger, band)
		if not line.is_empty():
			_commit(line)
			return
	var date := Calendar.format_date(GameState.year, GameState.month)
	_fallback("第%d回合，%s。城里的事我列在上面，边上的事等您问。" % [GameState.turn, date])


static func say_combat(player_dead: bool, enemy_dead: bool) -> void:
	if player_dead and not enemy_dead:
		say("combat_lose")
	elif enemy_dead and not player_dead:
		say("combat_win")
	else:
		say("combat_trade")


static func present(text: String, mood: String, id: String = "") -> void:
	GameState.advisor_text = text
	GameState.advisor_mood = mood
	if id != "":
		GameState.line_history[id] = GameState.turn
		_remember(id, "spoken", GameState.turn)
	EventBus.advisor_changed.emit()


static func _fallback(text: String) -> void:
	present(text, "normal", "brief_%d" % GameState.turn)


static func _seed() -> void:
	if _seeded_turn == GameState.turn:
		return
	_rng.seed = int(GameState.seed_value) + GameState.turn * 9973
	_seeded_turn = GameState.turn


static func _tick() -> void:
	var next := {}
	for k in GameState.cooldowns.keys():
		var left := int(GameState.cooldowns[k]) - 1
		if left > 0:
			next[k] = left
	GameState.cooldowns = next


static func _pick(trigger: String, band: String) -> Dictionary:
	var cat := _category(trigger)
	if _category_blocked(cat):
		return {}
	var pool: Array = []
	for line_v in DataDB.lines:
		var line: Dictionary = line_v
		if str(line.get("trigger", "")) != trigger:
			continue
		if not _power_ok(line, band):
			continue
		if not _when_ok(line):
			continue
		var id := str(line.get("id", ""))
		if bool(line.get("once", false)) and GameState.line_history.has(id):
			continue
		var last := int(GameState.line_history.get(id, -999))
		if last >= 0 and GameState.turn - last < 30:
			continue
		var group := str(line.get("group", id))
		var group_at := int(GameState.line_group_at.get(group, -999))
		if group_at >= 0 and GameState.turn - group_at < 8:
			continue
		if int(GameState.cooldowns.get(id, 0)) > 0:
			continue
		pool.append(line)
	if pool.is_empty():
		return {}
	return pool[_rng.randi() % pool.size()]


static func _commit(line: Dictionary) -> void:
	var id := str(line.get("id", ""))
	var text := _fill(str(line.get("text", "")))
	GameState.advisor_text = text
	GameState.advisor_mood = str(line.get("mood", "normal"))
	GameState.cooldowns[id] = int(line.get("cooldown", 0))
	GameState.line_history[id] = GameState.turn
	var group := str(line.get("group", id))
	GameState.line_group_at[group] = GameState.turn
	_remember(id, _category(str(line.get("trigger", ""))), GameState.turn)
	EventBus.advisor_changed.emit()


static func _remember(id: String, cat: String, at: int) -> void:
	GameState.line_recent.append({"id": id, "cat": cat, "turn": at})
	while GameState.line_recent.size() > 40:
		GameState.line_recent.pop_front()


static func _fill(text: String) -> String:
	return text.replace("{city}", "延州").replace("{enemy}", "西夏").replace("{n}", str(GameState.turn)).replace("{unit}", "刘平部").replace("{goal}", "延州不失").replace("{turns}", "2")


static func _power_ok(line: Dictionary, band: String) -> bool:
	var pwr := str(line.get("power", "any"))
	if band == "low":
		return pwr == "low"
	if band == "save":
		if pwr == "low":
			return false
		if pwr == "save":
			return true
		return _priority(line) <= 5
	if pwr == "low" or pwr == "save":
		return false
	return pwr == "any" or pwr == band


static func _when_ok(line: Dictionary) -> bool:
	var cond: Dictionary = line.get("when", {})
	if cond.is_empty():
		return true
	if cond.has("season"):
		var season := Calendar.season(GameState.month)
		var ok := false
		for item_v in cond.get("season", []):
			if str(item_v) == season:
				ok = true
		if not ok:
			return false
	if cond.has("month"):
		var month_ok := false
		for month_v in cond.get("month", []):
			if int(month_v) == GameState.month:
				month_ok = true
		if not month_ok:
			return false
	if cond.has("weather") and str(cond.get("weather", "")) != str(GameState.weather_id):
		return false
	var absent := str(cond.get("flag_absent", ""))
	if absent != "" and GameState.event_flags.has(absent):
		return false
	var need := str(cond.get("flag", ""))
	if need != "" and not GameState.event_flags.has(need):
		return false
	if cond.has("year_min") and GameState.year < int(cond.get("year_min", 0)):
		return false
	return true


static func _category(trigger: String) -> String:
	if trigger.begins_with("event"):
		return "event"
	if trigger.begins_with("combat"):
		return "combat"
	if trigger.begins_with("enemy"):
		return "enemy"
	if trigger.begins_with("weather") or trigger.begins_with("season"):
		return "weather"
	if trigger == "chatter":
		return "chatter"
	if trigger == "turn_start":
		return "turn"
	if trigger == "game_start" or trigger.begins_with("menu") or trigger.begins_with("blocked"):
		return "system"
	return trigger


static func _category_blocked(cat: String) -> bool:
	if cat == "event" or cat == "crisis" or cat == "system":
		return false
	var hits := 0
	for item_v in GameState.line_recent:
		var item: Dictionary = item_v
		if int(item.get("turn", -99)) < GameState.turn - 2:
			continue
		if str(item.get("cat", "")) == cat:
			hits += 1
	return hits >= 2


static func _priority(line: Dictionary) -> int:
	if line.has("priority"):
		return int(line.get("priority", 9))
	return _default_priority(str(line.get("trigger", "")))


static func _default_priority(trigger: String) -> int:
	if trigger == "game_start" or trigger.begins_with("menu") or trigger.begins_with("blocked"):
		return 1
	if trigger.begins_with("event"):
		return 2
	if trigger.begins_with("combat"):
		return 6
	if trigger.begins_with("enemy"):
		return 7
	if trigger.begins_with("weather"):
		return 8
	if trigger == "chatter":
		return 9
	if trigger == "turn_start":
		return 10
	return 9
