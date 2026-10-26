class_name FactionAI
extends RefCounted

const EnemyPace = preload("res://scripts/core/enemy_pace.gd")
const Campaign = preload("res://scripts/core/campaign.gd")

static func acting_count() -> int:
	return _actors().size()


static func run() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	EnemyPace.begin()
	var actors := _actors()
	EnemyPace.total = actors.size()
	var step := 0
	for actor_v in actors:
		var actor: Dictionary = actor_v
		step += 1
		EnemyPace.enforce_cap(actors.size() >= 6)
		var ui := _ui()
		if ui and ui.has_method("set_enemy_progress"):
			ui.call("set_enemy_progress", step, actors.size(), str(actor.get("name", "西夏")))
		var uid := int(actor.get("uid", -1))
		var unit := GameState.unit_by_id(uid)
		if unit.is_empty():
			continue
		if str(unit.get("faction", "")) == "rebel":
			await _rebel_act(unit)
			continue
		if str(unit.get("faction", "")) == "liao":
			await _liao_act(unit)
			continue
		if int(unit.hp) < 35:
			await _step_toward(unit, _capital("xingqing"))
			continue
		var prey := _best_attack(unit)
		if not prey.is_empty() and _score(unit, prey) >= -8:
			await _present_attack(unit, prey)
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
			await _present_attack(unit, prey)
			GameState.resolve_attack(int(unit.uid), int(prey.uid))
			await tree.process_frame
	EnemyPace.finish()
	var map := _map()
	if map:
		map.clear_pings()


static func _actors() -> Array:
	var rows: Array = []
	var factions: Array[String] = ["xia", "rebel", "liao"]
	var names: Dictionary = {"xia": "西夏", "rebel": "叛军", "liao": "辽"}
	for fac in factions:
		for u_v in GameState.units:
			var u: Dictionary = u_v
			if str(u.get("faction", "")) != fac or int(u.get("hp", 0)) <= 0:
				continue
			if fac == "liao" and str(u.get("tag", "")) != "liao_south":
				continue
			rows.append({"uid": int(u.get("uid", -1)), "name": str(names.get(fac, "西夏"))})
	return rows


static func _liao_act(unit: Dictionary) -> void:
	var prey := _best_attack(unit)
	if not prey.is_empty() and _score(unit, prey) >= -8:
		await _present_attack(unit, prey)
		GameState.resolve_attack(int(unit.uid), int(prey.uid))
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			await tree.process_frame
		return
	var press: bool = Campaign.full_push()
	var home := Campaign.muster()
	var here := Vector2i(int(unit.q), int(unit.r))
	if not press and HexGrid.distance(here, home) <= 2:
		return
	var dest := home
	if press:
		var nearest := _nearest_song(unit)
		if nearest.is_empty():
			return
		dest = Vector2i(int(nearest.q), int(nearest.r))
	await _step_toward(unit, dest)


static func _rebel_act(unit: Dictionary) -> void:
	var prey := _best_attack(unit)
	if not prey.is_empty() and _score(unit, prey) >= -8:
		await _present_attack(unit, prey)
		GameState.resolve_attack(int(unit.uid), int(prey.uid))
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			await tree.process_frame
		return
	var march := str(unit.get("march", "yanzhou"))
	var dest := _capital(march)
	if dest == Vector2i.ZERO:
		dest = _capital("yanzhou")
	await _step_toward(unit, dest)
	unit = GameState.unit_by_id(int(unit.get("uid", -1)))
	if unit.is_empty():
		return
	if Vector2i(int(unit.q), int(unit.r)) == dest and str(unit.get("tag", "")) == "wanglun":
		Campaign.seize_yangzhou()


static func _present_attack(unit: Dictionary, prey: Dictionary) -> void:
	if EnemyPace.skip:
		return
	var map := _map()
	if map == null:
		return
	var world := HexGrid.axial_to_pixel(int(prey.q), int(prey.r))
	map.focus_smooth(world, EnemyPace.scale(0.45))
	await _wait(EnemyPace.scale(0.28))
	await map.animate_strike(int(unit.uid), Vector2i(int(prey.q), int(prey.r)))


static func _wait(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if seconds <= 0.02:
		await tree.process_frame
		return
	await tree.create_timer(seconds).timeout


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
	if map and _near_song_city(best, 3) and not EnemyPace.skip_moves():
		map.focus_smooth(HexGrid.axial_to_pixel(best.x, best.y), EnemyPace.scale(0.35))
		await _wait(EnemyPace.scale(0.22))
	elif map:
		map.ping(best)
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
		var there := Vector2i(int(other.q), int(other.r))
		if not DataDB.city_at_hex(there.x, there.y).is_empty():
			var top := GameState.city_top(there)
			if int(top.get("uid", -1)) != int(other.get("uid", -2)):
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
	if tree == null:
		return null
	return tree.get_first_node_in_group("world_map") as WorldMap


static func _ui() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("game_ui")


static func _near_song_city(h: Vector2i, limit: int) -> bool:
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if str(city.get("faction", "")) != "song":
			continue
		var there := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
		if HexGrid.distance(h, there) <= limit:
			return true
	return false
