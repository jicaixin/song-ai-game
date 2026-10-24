class_name EventSystem
extends RefCounted

const Bargain = preload("res://scripts/core/bargain.gd")

## Queues events whose window has opened and applies the choice effects.

static func scan() -> void:
	for ev_v in DataDB.events:
		var ev: Dictionary = ev_v
		var id := str(ev.get("id", ""))
		if id == "":
			continue
		if id == "zengbi":
			if Bargain.should_queue():
				GameState.pending_events.append(id)
			continue
		if GameState.event_choice.has(id):
			continue
		if GameState.event_log.has(id):
			continue
		if GameState.pending_events.has(id):
			continue
		if not _due(ev):
			continue
		GameState.pending_events.append(id)


static func revealed(ev: Dictionary) -> bool:
	var id := str(ev.get("id", ""))
	if GameState.event_choice.has(id) or GameState.event_log.has(id) or GameState.pending_events.has(id):
		return true
	return GameState.turn >= _start(ev)


static func available(ev: Dictionary) -> bool:
	if ev.is_empty():
		return false
	var id := str(ev.get("id", ""))
	if GameState.event_choice.has(id):
		return false
	return GameState.turn >= _start(ev) or GameState.pending_events.has(id)


static func choice_enabled(choice: Dictionary) -> bool:
	return str(choice.get("requires", "")) != "feature_simulate"


static func apply(ev: Dictionary, choice: Dictionary) -> void:
	var effects: Array = choice.get("effects", [])
	for effect_v in effects:
		if typeof(effect_v) != TYPE_DICTIONARY:
			continue
		var effect: Dictionary = effect_v
		var kind := str(effect.get("type", ""))
		if kind == "flag":
			GameState.event_flags[str(effect.get("id", ""))] = true
		elif kind == "meter":
			var mid := str(effect.get("id", ""))
			var cur := int(GameState.meters.get(mid, 0))
			GameState.meters[mid] = clampi(cur + int(effect.get("delta", 0)), 0, 100)
		elif kind == "hurt_named":
			_hurt(effect.get("names", []), int(effect.get("hp", 0)))
		elif kind == "move_named":
			_move(effect.get("names", []), int(effect.get("q", 0)), int(effect.get("r", 0)))
		elif kind == "spawn":
			_spawn(effect)
	if str(choice.get("id", "")) != "" and str(ev.get("id", "")) != "":
		GameState.event_flags["%s_%s" % [str(ev.get("id", "")), str(choice.get("id", ""))]] = true


static func _due(ev: Dictionary) -> bool:
	if GameState.turn < _start(ev):
		return false
	if GameState.turn >= _guarantee(ev):
		return true
	return _conditions(ev)


static func _start(ev: Dictionary) -> int:
	var window: Array = ev.get("window", [])
	if window.size() >= 1:
		return int(window[0])
	return int(ev.get("turn", 1))


static func _guarantee(ev: Dictionary) -> int:
	if ev.has("guarantee"):
		return int(ev.get("guarantee", 1))
	var window: Array = ev.get("window", [])
	if window.size() >= 2:
		return int(window[1])
	return int(ev.get("turn", 1))


static func _conditions(ev: Dictionary) -> bool:
	var cond: Dictionary = ev.get("conditions", {})
	if cond.is_empty():
		return true
	var mins: Dictionary = cond.get("meter_min", {})
	for key_v in mins.keys():
		if int(GameState.meters.get(str(key_v), 0)) < int(mins[key_v]):
			return false
	var maxs: Dictionary = cond.get("meter_max", {})
	for key_v2 in maxs.keys():
		if int(GameState.meters.get(str(key_v2), 0)) > int(maxs[key_v2]):
			return false
	if cond.has("morale_max") and GameState.morale > int(cond.get("morale_max", 100)):
		return false
	var need := str(cond.get("flag", ""))
	if need != "" and not GameState.event_flags.has(need):
		return false
	var rel: Dictionary = cond.get("relation_min", {})
	for fid_v in rel.keys():
		if int(GameState.relations.get(str(fid_v), 0)) < int(rel[fid_v]):
			return false
	return true


static func _hurt(names: Array, delta: int) -> void:
	for name_v in names:
		var unit := GameState.unit_by_name(str(name_v))
		if unit.is_empty():
			continue
		unit.hp = maxi(1, int(unit.hp) + delta)


static func _move(names: Array, q: int, r: int) -> void:
	var step := 0
	for name_v in names:
		var unit := GameState.unit_by_name(str(name_v))
		if unit.is_empty():
			continue
		var spot := GameState.find_open(q + (step % 3) - 1, r)
		GameState.set_pos(int(unit.uid), spot)
		step += 1


static func _spawn(effect: Dictionary) -> void:
	var count := maxi(1, int(effect.get("count", 1)))
	var base := str(effect.get("name", "伏兵"))
	var q := int(effect.get("q", 14))
	var r := int(effect.get("r", 26))
	var def_id := str(effect.get("def", "xia_buba"))
	var marks := ["甲", "乙", "丙", "丁"]
	for i in count:
		var label := base
		if count > 1 and i < marks.size():
			label = "%s%s" % [base, marks[i]]
		GameState.add_unit(def_id, label, q + i, r - i)
