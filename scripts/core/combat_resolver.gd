class_name CombatResolver
extends RefCounted

static func damage_amount(diff: float, roll: float) -> int:
	var base := float(DataDB.balance.get("combat", {}).get("base", 30))
	var k := float(DataDB.balance.get("combat", {}).get("k", 0.04))
	return int(round(base * exp(k * diff) * roll))


static func assess(atk: Dictionary, dfd: Dictionary) -> Dictionary:
	var atk_spec: Dictionary = DataDB.unit_type(str(atk.get("def_id", "")))
	var dfd_spec: Dictionary = DataDB.unit_type(str(dfd.get("def_id", "")))
	var ahex := Vector2i(int(atk.q), int(atk.r))
	var dhex := Vector2i(int(dfd.q), int(dfd.r))
	var dist := HexGrid.distance(ahex, dhex)
	var ranged := int(atk_spec.get("ranged", 0)) > 0 and dist >= 1 and dist <= int(atk_spec.get("range", 0))
	var atk_parts: Array = []
	var def_parts: Array = []
	var atk_base := int(atk_spec.get("ranged", 0)) if ranged else int(atk_spec.get("melee", 0))
	atk_parts.append({"name": "远程" if ranged else "近战", "value": atk_base})
	def_parts.append({"name": "近战", "value": int(dfd_spec.get("melee", 0))})
	_add_traits(atk, dfd, atk_spec, ranged, true, atk_parts)
	_add_traits(dfd, atk, dfd_spec, false, false, def_parts)
	var gen_a := int(atk.get("general_bonus", 0))
	if gen_a != 0:
		atk_parts.append({"name": "将领", "value": gen_a})
	var gen_d := int(dfd.get("general_bonus", 0))
	if gen_d != 0:
		def_parts.append({"name": "将领", "value": gen_d})
	var hp_a := -int(float(100 - int(atk.get("hp", 100))) / 10.0)
	if hp_a != 0:
		atk_parts.append({"name": "伤势", "value": hp_a})
	var hp_d := -int(float(100 - int(dfd.get("hp", 100))) / 10.0)
	if hp_d != 0:
		def_parts.append({"name": "伤势", "value": hp_d})
	var flank_a := _flank(atk, dfd)
	if flank_a != 0:
		atk_parts.append({"name": "侧翼", "value": flank_a})
	var flank_d := _flank(dfd, atk)
	if flank_d != 0:
		def_parts.append({"name": "侧翼", "value": flank_d})
	_morale(str(atk.get("faction", "")), atk_parts)
	_morale(str(dfd.get("faction", "")), def_parts)
	if not ranged:
		var river := _river_penalty(ahex, dhex)
		if river != 0:
			atk_parts.append({"name": "渡大河" if river <= -6 else "渡河", "value": river})
	var terr := DataDB.terrain(DataDB.terrain_id(dhex.x, dhex.y))
	var tdef := int(terr.get("defense", 0))
	if tdef != 0:
		def_parts.append({"name": str(terr.get("name", "地形")), "value": tdef})
	var city := DataDB.city_at_hex(dhex.x, dhex.y)
	if not city.is_empty():
		var walls := int(city.get("walls", 0))
		if walls != 0:
			def_parts.append({"name": "城墙", "value": walls})
	var atk_power := _sum(atk_parts)
	var def_power := _sum(def_parts)
	if ranged and str(GameState.weather_id) == "rain":
		var cut := int(round(float(atk_power) * 0.25))
		if cut != 0:
			atk_parts.append({"name": "雨天", "value": -cut})
			atk_power -= cut
	atk_power = max(1, atk_power)
	def_power = max(1, def_power)
	var diff := float(atk_power - def_power)
	var def_min := damage_amount(diff, 0.8)
	var def_max := damage_amount(diff, 1.2)
	var atk_min := 0 if ranged else damage_amount(-diff, 0.8)
	var atk_max := 0 if ranged else damage_amount(-diff, 1.2)
	var def_mid := damage_amount(diff, 1.0)
	var atk_mid := 0 if ranged else damage_amount(-diff, 1.0)
	return {
		"ranged": ranged,
		"dist": dist,
		"atk_power": atk_power,
		"def_power": def_power,
		"atk_parts": atk_parts,
		"def_parts": def_parts,
		"def_min": def_min,
		"def_max": def_max,
		"atk_min": atk_min,
		"atk_max": atk_max,
		"def_mid": def_mid,
		"atk_mid": atk_mid,
	}


static func roll_damage(preview: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var c: Dictionary = DataDB.balance.get("combat", {})
	var lo := float(c.get("rand_min", 0.8))
	var hi := float(c.get("rand_max", 1.2))
	var diff := float(int(preview.atk_power) - int(preview.def_power))
	var def_dmg := damage_amount(diff, rng.randf_range(lo, hi))
	var atk_dmg := 0
	if not bool(preview.ranged):
		atk_dmg = damage_amount(-diff, rng.randf_range(lo, hi))
	return Vector2i(atk_dmg, def_dmg)


static func _sum(parts: Array) -> int:
	var n := 0
	for p in parts:
		n += int(p.get("value", 0))
	return n


static func _add_traits(unit: Dictionary, enemy: Dictionary, spec: Dictionary, ranged: bool, is_attacker: bool, parts: Array) -> void:
	var enemy_spec: Dictionary = DataDB.unit_type(str(enemy.get("def_id", "")))
	var enemy_class := str(enemy_spec.get("unit_class", ""))
	var stood := DataDB.terrain_id(int(unit.q), int(unit.r))
	for trait_v in spec.get("traits", []):
		var row: Dictionary = trait_v
		var kind := str(row.get("type", ""))
		if kind == "vs_class" and str(row.get("class", "")) == enemy_class:
			parts.append({"name": "兵种克制", "value": int(row.get("bonus", 0))})
		elif kind == "charge" and is_attacker and not ranged:
			parts.append({"name": "冲锋", "value": int(row.get("bonus", 0))})
		elif kind == "terrain_power":
			var terrains: Array = row.get("terrains", [])
			if stood in terrains:
				parts.append({"name": "地形熟练", "value": int(row.get("bonus", 0))})


static func _flank(unit: Dictionary, enemy: Dictionary) -> int:
	var n := 0
	var around := Vector2i(int(enemy.q), int(enemy.r))
	for nb in HexGrid.neighbors_of(around):
		var other := GameState.unit_at(nb)
		if other.is_empty():
			continue
		if int(other.get("uid", -1)) == int(unit.get("uid", -2)):
			continue
		if str(other.get("faction", "")) == str(unit.get("faction", "")):
			n += 1
	return n * 2


static func _morale(faction: String, parts: Array) -> void:
	if faction != "song":
		return
	var morale := int(GameState.morale)
	if morale >= 80:
		parts.append({"name": "士气", "value": 2})
	elif morale <= 40:
		parts.append({"name": "士气", "value": -3})


static func _river_penalty(a: Vector2i, b: Vector2i) -> int:
	var dir := HexGrid.dir_between(a, b)
	if dir < 0:
		return 0
	var bit := 1 << dir
	var masks: Array = DataDB.river_masks.get(a, [0, 0])
	if (int(masks[1]) & bit) != 0:
		return -6
	if (int(masks[0]) & bit) != 0:
		return -3
	var back := HexGrid.dir_between(b, a)
	if back < 0:
		return 0
	var bit2 := 1 << back
	var masks_b: Array = DataDB.river_masks.get(b, [0, 0])
	if (int(masks_b[1]) & bit2) != 0:
		return -6
	if (int(masks_b[0]) & bit2) != 0:
		return -3
	return 0


static func format_parts(parts: Array) -> String:
	var bits: PackedStringArray = []
	for p in parts:
		var v := int(p.get("value", 0))
		var sign := "+" if v > 0 else ""
		bits.append("%s%s%d" % [str(p.get("name", "")), sign, v])
	return "，".join(bits)
