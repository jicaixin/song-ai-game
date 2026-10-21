class_name Pathfinder
extends RefCounted

static func budget(unit: Dictionary) -> int:
	var mp := int(unit.get("mp", 0))
	if str(GameState.weather_id) == "snow":
		mp = max(0, mp - 1)
	return mp


static func enter_cost(unit: Dictionary, q: int, r: int) -> int:
	var tid := DataDB.terrain_id(q, r)
	if tid == "":
		return -1
	var terr := DataDB.terrain(tid)
	if not bool(terr.get("passable", false)):
		return -1
	var cost := int(terr.get("move", 1))
	var spec: Dictionary = DataDB.unit_type(str(unit.get("def_id", "")))
	for trait_v in spec.get("traits", []):
		var row: Dictionary = trait_v
		if str(row.get("type", "")) == "terrain_move":
			var terrains: Array = row.get("terrains", [])
			if tid in terrains:
				cost = int(row.get("cost", cost))
	return cost


static func reachable(unit: Dictionary) -> Dictionary:
	var start := Vector2i(int(unit.q), int(unit.r))
	var mp := budget(unit)
	var best := {start: 0}
	var parent := {start: start}
	var open: Array = [{"p": start, "c": 0}]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if int(open[i]["c"]) < int(open[bi]["c"]):
				bi = i
		var item: Dictionary = open[bi]
		open.remove_at(bi)
		var cur: Vector2i = item["p"]
		if int(item["c"]) != int(best[cur]):
			continue
		var cur_zoc := _zoc(cur, unit)
		for nb in HexGrid.neighbors_of(cur):
			if not DataDB.in_bounds(nb.x, nb.y):
				continue
			if GameState.occupied(nb, int(unit.get("uid", -1))):
				continue
			var step := enter_cost(unit, nb.x, nb.y)
			if step < 0:
				continue
			var nc: int = int(best[cur]) + step
			if nc > mp:
				continue
			if cur_zoc and _zoc(nb, unit):
				continue
			if best.has(nb) and nc >= int(best[nb]):
				continue
			best[nb] = nc
			parent[nb] = cur
			if not _zoc(nb, unit):
				open.append({"p": nb, "c": nc})
	best.erase(start)
	return {"cost": best, "parent": parent}


static func reconstruct(parent: Dictionary, start: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var rev: Array[Vector2i] = []
	var cur := dest
	var guard := 0
	while cur != start and guard < 256:
		rev.append(cur)
		if not parent.has(cur):
			return []
		cur = parent[cur]
		guard += 1
	if cur != start:
		return []
	rev.reverse()
	return rev


static func _zoc(hex: Vector2i, unit: Dictionary) -> bool:
	var faction := str(unit.get("faction", ""))
	var uid := int(unit.get("uid", -1))
	for nb in HexGrid.neighbors_of(hex):
		var other := GameState.unit_at(nb)
		if other.is_empty():
			continue
		if int(other.get("uid", -1)) == uid:
			continue
		if DataDB.hostile(faction, str(other.get("faction", ""))):
			return true
	return false
