extends RefCounted

const Campaign = preload("res://scripts/core/campaign.gd")


static func step_rebels() -> void:
	if Campaign.alive("wanglun") <= 0:
		return
	if GameState.event_flags.has("wanglun_at_yangzhou"):
		return
	_rebels()
	if Campaign.alive("wanglun") <= 0 and not GameState.event_flags.has("wanglun_at_yangzhou"):
		GameState.event_flags["wanglun_caught"] = true


static func step() -> void:
	if GameState.pending_events.has("wanglun") and not GameState.event_choice.has("wanglun"):
		GameState.choose_event("wanglun", "fight")
	if Campaign.alive("wanglun") <= 0:
		return
	if GameState.event_flags.has("wanglun_at_yangzhou"):
		return
	_songs()
	_rebels()
	if Campaign.alive("wanglun") <= 0 and not GameState.event_flags.has("wanglun_at_yangzhou"):
		GameState.event_flags["wanglun_caught"] = true


static func _songs() -> void:
	var guard := 0
	while guard < 8:
		guard += 1
		var song := _nearest_song()
		if song.is_empty() or int(song.get("mp", 0)) <= 0:
			return
		var rebel := _nearest_rebel(Vector2i(int(song.q), int(song.r)))
		if rebel.is_empty():
			return
		if _adjacent(song, rebel):
			GameState.resolve_attack(int(song.uid), int(rebel.uid))
			continue
		if not _step(song, Vector2i(int(rebel.q), int(rebel.r))):
			song["mp"] = 0


static func _rebels() -> void:
	var city := DataDB.city_by_id("yangzhou")
	var dest := Vector2i(int(city.get("q", 28)), int(city.get("r", 35)))
	for u_v in GameState.units.duplicate():
		var unit: Dictionary = u_v
		if str(unit.get("tag", "")) != "wanglun" or int(unit.get("hp", 0)) <= 0:
			continue
		var live := GameState.unit_by_id(int(unit.get("uid", -1)))
		if live.is_empty():
			continue
		var foe := _adjacent_song(live)
		if not foe.is_empty():
			GameState.resolve_attack(int(live.uid), int(foe.uid))
			continue
		var left := int(live.get("mp", 0))
		while left > 0 and int(live.get("hp", 0)) > 0:
			left -= 1
			if not _step(live, dest):
				break
			live = GameState.unit_by_id(int(unit.get("uid", -1)))
			if live.is_empty():
				break
			if Vector2i(int(live.q), int(live.r)) == dest:
				Campaign.seize_yangzhou()
				break
			if int(live.get("mp", 0)) <= 0:
				break


static func _nearest_song() -> Dictionary:
	var best: Dictionary = {}
	var best_d := 9999
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0 or int(u.get("mp", 0)) <= 0:
			continue
		var rebel := _nearest_rebel(Vector2i(int(u.q), int(u.r)))
		if rebel.is_empty():
			continue
		var dist := HexGrid.distance(Vector2i(int(u.q), int(u.r)), Vector2i(int(rebel.q), int(rebel.r)))
		if dist < best_d:
			best_d = dist
			best = u
	return best


static func _nearest_rebel(here: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_d := 9999
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("tag", "")) != "wanglun" or int(u.get("hp", 0)) <= 0:
			continue
		var dist := HexGrid.distance(here, Vector2i(int(u.q), int(u.r)))
		if dist < best_d:
			best_d = dist
			best = u
	return best


static func _adjacent_song(unit: Dictionary) -> Dictionary:
	var here := Vector2i(int(unit.q), int(unit.r))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if HexGrid.distance(here, Vector2i(int(u.q), int(u.r))) == 1:
			return u
	return {}


static func _adjacent(a: Dictionary, b: Dictionary) -> bool:
	return HexGrid.distance(Vector2i(int(a.q), int(a.r)), Vector2i(int(b.q), int(b.r))) == 1


static func _step(unit: Dictionary, dest: Vector2i) -> bool:
	if int(unit.get("mp", 0)) <= 0 or int(unit.get("hp", 0)) <= 0:
		return false
	var here := Vector2i(int(unit.q), int(unit.r))
	var best := here
	var best_d := HexGrid.distance(here, dest)
	for nxt in HexGrid.neighbors_of(here):
		if not _open(nxt):
			continue
		var dist := HexGrid.distance(nxt, dest)
		if dist < best_d:
			best = nxt
			best_d = dist
	if best == here:
		return false
	GameState.spend_mp(int(unit.uid), 1)
	GameState.set_pos(int(unit.uid), best)
	return true


static func _open(h: Vector2i) -> bool:
	if not DataDB.in_bounds(h.x, h.y):
		return false
	if not bool(DataDB.terrain(DataDB.terrain_id(h.x, h.y)).get("passable", false)):
		return false
	if not GameState.unit_at(h).is_empty():
		return false
	var city := DataDB.city_at_hex(h.x, h.y)
	if city.is_empty():
		return true
	return str(city.get("faction", "")) == "song"
