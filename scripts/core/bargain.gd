class_name Bargain
extends RefCounted

## Three rounds of 庆历增币, then a signing at the remaining tier.

const GoalSystem = preload("res://scripts/core/goal_system.gd")


static func should_queue() -> bool:
	if GameState.event_choice.has("zengbi"):
		return false
	if GameState.pending_events.has("zengbi"):
		return false
	var at := GameState.turn
	if at < 27:
		return false
	if at >= 33:
		return true
	if at == 27:
		return GameState.bargain_round < 1
	if at == 29:
		return GameState.bargain_round < 2
	if at == 31:
		return GameState.bargain_round < 3
	return false


static func settling() -> bool:
	return GameState.turn >= 33


static func round_no() -> int:
	return clampi(GameState.bargain_round + 1, 1, 3)


static func prepare() -> void:
	if GameState.bargain_west:
		return
	if GoalSystem.xiping() < 40:
		return
	GameState.bargain_west = true
	_add_demand(-2)


static func garrisons() -> int:
	var n := 0
	var cities: Array[String] = ["xiongzhou", "dingzhou", "zhending"]
	for cid in cities:
		if _near(cid, 1):
			n += 1
	return n


static func chips() -> Array:
	var rows: Array = []
	var gar := garrisons()
	rows.append(_chip("show", "强兵示威", -3, "雄州定州真定 %d/3" % gar, gar >= 3, false))
	var money := int(GameState.resources.get("money", 0))
	rows.append(_chip("beijing", "建北京", -2, "钱 300", money >= 300, false))
	var rich: bool = GameState.morale >= 60
	var cut := -2
	var note := "皇威不足六十，减两档"
	if rich:
		cut = -3
		note = "皇威够，减三档"
	rows.append(_chip("fubi", "富弼出使", cut, note, true, false))
	rows.append(_chip("alien", "推演离间", -3, "推演功能尚未开放", false, false))
	rows.append(_chip("refuse", "强硬拒绝", 4, "辽军南压提前", true, true))
	return rows


static func commit(ids: Array) -> bool:
	if GameState.event_choice.has("zengbi"):
		return false
	if settling():
		return settle()
	if ids.is_empty() or ids.size() > 2:
		GameState.notice = "这一轮请选一到两张筹码。"
		EventBus.state_changed.emit()
		return false
	prepare()
	var spec := {}
	for row_v in chips():
		var row: Dictionary = row_v
		spec[str(row.get("id", ""))] = row
	var applied := 0
	for id_v in ids:
		var id := str(id_v)
		if not spec.has(id):
			continue
		var chip: Dictionary = spec[id]
		if not bool(chip.get("enabled", false)):
			continue
		if id == "beijing":
			if int(GameState.resources.get("money", 0)) < 300:
				continue
			GameState.resources["money"] = int(GameState.resources.get("money", 0)) - 300
		_add_demand(int(chip.get("delta", 0)))
		GameState.bargain_used[id] = true
		if id == "refuse":
			GameState.event_flags["zengbi_refuse"] = true
		applied += 1
	if applied == 0:
		GameState.notice = "这张筹码眼下用不了。"
		EventBus.state_changed.emit()
		return false
	GameState.bargain_round += 1
	GameState.pending_events.erase("zengbi")
	var demand := int(GameState.meters.get("liao_demand", 0))
	GameState.notice = "这一轮谈完了。辽索求 %d 档。" % demand
	GameState.last_event = GameState.notice
	AdvisorSystem.present("谈了一轮。辽还咬着 %d 档不放。" % demand, "serious", "bargain_%d" % GameState.bargain_round)
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


static func settle() -> bool:
	if GameState.event_choice.has("zengbi"):
		return false
	prepare()
	GameState.event_choice["zengbi"] = "sign"
	GameState.pending_events.erase("zengbi")
	if not GameState.event_log.has("zengbi"):
		GameState.event_log.append("zengbi")
	GameState.event_flags["zengbi_signed"] = true
	var demand := int(GameState.meters.get("liao_demand", 0))
	GameState.notice = "增币定议，按 %d 档签约。" % demand
	GameState.last_event = GameState.notice
	AdvisorSystem.present("谈下来了。富弼大人回来的时候头发又白了一截。眼下按 %d 档给岁币。" % demand, "serious", "bargain_sign")
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


static func _chip(id: String, label: String, delta: int, note: String, enabled: bool, risk: bool) -> Dictionary:
	if GameState.bargain_used.has(id):
		enabled = false
		note = "本局已用"
	return {
		"id": id,
		"label": label,
		"delta": delta,
		"note": note,
		"enabled": enabled,
		"risk": risk,
	}


static func _add_demand(delta: int) -> void:
	var cur := int(GameState.meters.get("liao_demand", 20))
	GameState.meters["liao_demand"] = clampi(cur + delta, 0, 40)


static func _near(city_id: String, dist: int) -> bool:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		return false
	var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		var at := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
		if HexGrid.distance(origin, at) <= dist:
			return true
	return false
