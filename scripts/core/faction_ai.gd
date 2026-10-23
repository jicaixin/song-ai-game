class_name FactionAI
extends RefCounted

static func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ids: Array[int] = []
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) == "xia" and int(u.hp) > 0:
			ids.append(int(u.uid))
	for uid in ids:
		var unit := GameState.unit_by_id(uid)
		if unit.is_empty():
			continue
		if int(unit.hp) < 35:
			await _step_toward(unit, _capital("xingqing"))
			continue
		var prey := _best_attack(unit)
		if not prey.is_empty() and _score(unit, prey) >= -8:
			GameState.resolve_attack(int(unit.uid), int(prey.uid))
			await tree.process_frame
			continue
		var nearest := _nearest_song(unit)
		if nearest.is_empty():
			continue
		await _step_toward(unit, Vector2i(int(nearest.q), int(nearest.r)))
		unit = GameState.unit_by_id(uid)
		if unit.is_empty() or int(unit.mp) <= 0:
			continue
		prey = _best_attack(unit)
		if not prey.is_empty() and _score(unit, prey) >= -8:
			GameState.resolve_attack(int(unit.uid), int(prey.uid))
			await tree.process_frame


static func _step_toward(unit: Dictionary, target: Vector2i) -> void:
	var info := Pathfinder.reachable(unit)
	var cost: Dictionary = info.get("cost", {})
	var parent: Dictionary = info.get("parent", {})
	var start := Vector2i(int(unit.q), int(unit.r))
	var best := start
	var best_d := HexGrid.distance(start, target)
	var best_c := 0
	for h_v in cost.keys():
		var h: Vector2i = h_v
		var d := HexGrid.distance(h, target)
		var c := int(cost[h])
		if d < best_d or (d == best_d and c < best_c):
			best = h
			best_d = d
			best_c = c
	if best == start:
		return
	var path := Pathfinder.reconstruct(parent, start, best)
	if path.is_empty():
		return
	GameState.spend_mp(int(unit.uid), int(cost[best]))
	GameState.set_pos(int(unit.uid), best)
	var map := _map()
	if map:
		await map.animate_move(int(unit.uid), path)
	else:
		EventBus.state_changed.emit()


static func _best_attack(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -9999
	for other_v in GameState.units:
		var other: Dictionary = other_v
		if int(other.hp) <= 0:
			continue
		if not DataDB.hostile(str(unit.faction), str(other.faction)):
			continue
		if not _in_range(unit, other):
			continue
		var score := _score(unit, other)
		if score > best_score:
			best_score = score
			best = other
	return best


static func _score(unit: Dictionary, other: Dictionary) -> int:
	var preview := CombatResolver.assess(unit, other)
	return int(preview.def_mid) - int(preview.atk_mid)


static func _in_range(unit: Dictionary, other: Dictionary) -> bool:
	if int(unit.mp) <= 0:
		return false
	var spec := DataDB.unit_type(str(unit.def_id))
	var dist := HexGrid.distance(Vector2i(int(unit.q), int(unit.r)), Vector2i(int(other.q), int(other.r)))
	if int(spec.get("ranged", 0)) > 0:
		return dist >= 1 and dist <= int(spec.get("range", 0))
	return dist == 1


static func _nearest_song(unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 9999
	var here := Vector2i(int(unit.q), int(unit.r))
	for other_v in GameState.units:
		var other: Dictionary = other_v
		if str(other.faction) != "song" or int(other.hp) <= 0:
			continue
		var d := HexGrid.distance(here, Vector2i(int(other.q), int(other.r)))
		if d < best_d:
			best_d = d
			best = other
	return best


static func _capital(id: String) -> Vector2i:
	var city := DataDB.city_by_id(id)
	if city.is_empty():
		return Vector2i.ZERO
	return Vector2i(int(city.q), int(city.r))


static func _map() -> WorldMap:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("world_map") as WorldMap
