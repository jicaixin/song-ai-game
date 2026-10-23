class_name TileActions
extends RefCounted

## Hover and click share this plan. Numbers come from Pathfinder and CombatResolver.

const NONE := Vector2i(999999, 0)

static func plan(hex: Vector2i, uid: int) -> Dictionary:
	var cost := {}
	var parent := {}
	var unit := GameState.unit_by_id(uid)
	if _can_move(unit):
		var info := Pathfinder.reachable(unit)
		cost = info.get("cost", {})
		parent = info.get("parent", {})
	return plan_reach(hex, uid, cost, parent)


static func plan_reach(hex: Vector2i, uid: int, cost: Dictionary, parent: Dictionary) -> Dictionary:
	var unit := GameState.unit_by_id(uid)
	var moving := _can_move(unit)
	var start := NONE
	if not unit.is_empty():
		start = Vector2i(int(unit.q), int(unit.r))
	var occ := GameState.unit_at(hex)
	var city := DataDB.city_at_hex(hex.x, hex.y)
	var terr := DataDB.terrain(DataDB.terrain_id(hex.x, hex.y))
	var passable := bool(terr.get("passable", false))
	var actions: Array = []
	var style := "empty"
	var cursor := "cur_default"
	var head := _place_head(hex, terr, city)
	var more: Array = []
	var path: Array = []
	var landing := NONE
	var remain := -1
	var hostile := false
	var direct := false
	var reason := ""
	_append_place_more(more, hex, terr, city)

	if not occ.is_empty() and not unit.is_empty() and int(occ.uid) == int(unit.uid):
		style = "own_acted" if int(unit.mp) <= 0 else "own_ready"
		cursor = "cur_select"
		head = _self_head(unit)
		_append_unit_more(more, unit)
		_push_self_actions(actions, unit, city)
	elif not occ.is_empty() and not unit.is_empty() and str(occ.faction) == "song" and str(unit.faction) == "song" and int(occ.uid) != int(unit.uid):
		style = "own_ready" if int(occ.mp) > 0 else "own_acted"
		cursor = "cur_select"
		head = _self_head(occ)
		_append_unit_more(more, occ)
	elif not occ.is_empty() and (unit.is_empty() or not DataDB.hostile(str(unit.get("faction", "")), str(occ.faction))):
		style = "enemy_far" if str(occ.faction) != "song" else ("own_acted" if int(occ.mp) <= 0 else "own_ready")
		cursor = "cur_inspect" if str(occ.faction) != "song" else "cur_select"
		head = _unit_head(occ)
		_append_unit_more(more, occ)
	elif not occ.is_empty() and moving and DataDB.hostile(str(unit.faction), str(occ.faction)):
		var ranged := _is_ranged(unit)
		var in_range := _in_range(unit, occ)
		var atk_id := "ranged" if ranged else "attack"
		var atk_label := "远程攻击" if ranged else "攻击"
		var atk_icon := "act_ranged" if ranged else "act_attack"
		landing = best_landing(unit, hex, cost)
		if in_range:
			style = "attack"
			cursor = "cur_ranged" if ranged else "cur_attack"
			var preview := _assess_at(unit, occ, start)
			head = "%s %s · %s / %s" % [atk_label, str(occ.name), loss_text("敌", int(preview.def_min), int(preview.def_max)), loss_text("我", int(preview.atk_min), int(preview.atk_max))]
			_append_forecast_more(more, preview)
			actions.append(_act(atk_id, atk_label, atk_icon, "", true, "", "cmd", 0, preview))
			hostile = true
		elif landing != NONE:
			style = "move_attack"
			cursor = "cur_attack" if not ranged else "cur_ranged"
			var ghost := unit.duplicate()
			ghost.q = landing.x
			ghost.r = landing.y
			var preview2 := CombatResolver.assess(ghost, occ)
			var step := int(cost.get(landing, 0))
			head = "移动并攻击 · 先走到 (%d,%d)" % [landing.x, landing.y]
			more.append("移动消耗 %d，到达后还剩 %d" % [step, _budget(unit) - step])
			_append_forecast_more(more, preview2)
			actions.append(_act("move_attack", "移动并攻击", "act_move_attack", "", true, "", "cmd", step, preview2))
			actions.append(_act("move_near", "只走到旁边", "act_move_near", "", true, "", "cmd", step, {}))
			path = _path_of(parent, start, landing)
			remain = _budget(unit) - step
			hostile = true
		else:
			style = "enemy_far"
			cursor = "cur_inspect"
			var dist := HexGrid.distance(start, hex)
			var cap := _range_of(unit)
			reason = "移动力已用完" if int(unit.mp) <= 0 else "相距 %d，射程 %d" % [dist, cap]
			if landing == NONE and int(unit.mp) > 0:
				reason = "走不到能出手的位置" if not _closer(start, hex, cost) else "相距 %d，射程 %d" % [dist, cap]
			head = "%s · %s · 生命%d" % [str(occ.name), _faction_name(str(occ.faction)), int(occ.hp)]
			more.append("打不到：" + reason)
			_append_unit_more(more, occ)
			actions.append(_act(atk_id, atk_label, atk_icon, "", false, reason, "cmd", 0, {}))
	elif moving and not passable:
		style = "impassable"
		cursor = "cur_no"
		var tname := str(terr.get("name", "地形"))
		head = "%s · 不可通行" % tname
		reason = "需船只（未开放）" if tname == "湖泊" or tname == "海洋" else "不可通行"
		more.append(reason)
	elif moving and cost.has(hex) and (occ.is_empty() or (not city.is_empty() and str(city.get("faction", "")) == "song")):
		var step2 := int(cost[hex])
		var left := _budget(unit) - step2
		path = _path_of(parent, start, hex)
		remain = left
		var own_city := not city.is_empty() and str(city.get("faction", "")) == "song" and occ.is_empty()
		if own_city:
			style = "reach"
			cursor = "cur_move"
			head = "进城 · 花 %d 步，剩 %d" % [step2, left]
			more.append("进入%s" % str(city.get("name", "城")))
			var blocked_city := false
			actions.append(_act("enter", "进城", "act_enter_city", "", not blocked_city, "", "cmd", step2, {}))
			actions.append(_act("city", "打开城池", "act_city_panel", "C", true, "", "info", 0, {}))
		else:
			style = "reach"
			cursor = "cur_move"
			head = "移动 · 花 %d 步，剩 %d" % [step2, left]
			_append_path_more(more, path)
			if _in_zoc(hex, unit):
				more.append("进入敌军控制区，到达后停下")
			if not city.is_empty():
				more.append("进入%s" % str(city.get("name", "")))
			actions.append(_act("move", "移动", "act_move", "", true, "", "cmd", step2, {}))
			direct = true
	elif moving:
		var near := nearest_step(start, hex, cost)
		if near != NONE and HexGrid.distance(near, hex) < HexGrid.distance(start, hex):
			style = "far"
			cursor = "cur_move_far"
			var step3 := int(cost.get(near, 0))
			head = "走到最近处 · 花 %d 步到 (%d,%d)" % [step3, near.x, near.y]
			more.append("本月走不到。最近可达格：(%d,%d)" % [near.x, near.y])
			path = _path_of(parent, start, near)
			landing = near
			remain = _budget(unit) - step3
			actions.append(_act("move_near", "走到最近处", "act_move_near", "", true, "", "cmd", step3, {}))
			actions.append(_act("deselect", "取消选择", "act_deselect", "", true, "", "info", 0, {}))
		else:
			style = "blocked" if passable else "impassable"
			cursor = "cur_no"
			reason = _block_reason(unit, hex, passable, occ)
			var tname2 := str(terr.get("name", "地形"))
			head = "去不了 · %s" % reason if passable else "%s · 不可通行" % tname2
			more.append(reason)
	elif not city.is_empty():
		var faction := str(city.get("faction", ""))
		if faction == "song":
			style = "city_own"
			cursor = "cur_city"
		elif DataDB.hostile("song", faction):
			style = "city_enemy"
			cursor = "cur_inspect"
		else:
			style = "neutral"
			cursor = "cur_default"
		head = _place_head(hex, terr, city)
	elif not unit.is_empty() and str(unit.faction) == "song" and int(unit.mp) <= 0 and occ.is_empty():
		style = "empty"
		cursor = "cur_default"

	if style == "empty" and not city.is_empty():
		var faction2 := str(city.get("faction", ""))
		if faction2 == "song":
			style = "city_own"
			if not moving:
				cursor = "cur_city"
		elif DataDB.hostile("song", faction2):
			style = "city_enemy"
			if not moving:
				cursor = "cur_inspect"
		elif faction2 != "":
			style = "neutral"

	if moving and style == "empty" and not passable:
		style = "impassable"
		cursor = "cur_no"

	_number_cmds(actions)
	var want_detail := hostile or style == "attack" or style == "move_attack" or style == "enemy_far"
	if want_detail and _find(actions, "info").is_empty():
		actions.append(_act("info", "战斗明细", "act_info", "V", true, "", "info", 0, {}))
	if not direct and not actions.is_empty() and _find(actions, "cancel").is_empty():
		actions.append(_act("cancel", "取消", "act_cancel", "Esc", true, "", "info", 0, {}))
	var card_sub := ""
	if not occ.is_empty() and not unit.is_empty() and DataDB.hostile(str(unit.get("faction", "")), str(occ.get("faction", ""))):
		card_sub = _card_sub(unit, occ)
	var default_id := ""
	for a_v in actions:
		var a: Dictionary = a_v
		if str(a.kind) == "cmd" and bool(a.enabled):
			a.default = true
			default_id = str(a.id)
			break
	return {
		"style": style,
		"cursor": cursor,
		"head": head,
		"more": more,
		"actions": actions,
		"path": path,
		"landing": landing,
		"remain": remain,
		"hostile": hostile,
		"direct": direct,
		"reason": reason,
		"default_id": default_id,
		"badges": _badges(style, hex, city),
		"design_w": _width_of(style),
		"shader": _shader_of(style),
		"color": _color_of(style, city),
		"hatch": 0.35 if style == "attack" else 0.0,
		"card_sub": card_sub,
	}


static func best_landing(unit: Dictionary, target: Vector2i, cost: Dictionary) -> Vector2i:
	if unit.is_empty():
		return NONE
	var cap := _range_of(unit)
	var best := NONE
	var best_cost := 9999
	for h_v in cost.keys():
		var h: Vector2i = h_v
		var step := int(cost[h])
		if step >= int(unit.mp):
			continue
		var dist := HexGrid.distance(h, target)
		if dist < 1 or dist > cap:
			continue
		if step < best_cost:
			best_cost = step
			best = h
	return best


static func nearest_step(start: Vector2i, target: Vector2i, cost: Dictionary) -> Vector2i:
	var best := NONE
	var best_d := HexGrid.distance(start, target)
	var best_c := 9999
	if best_d <= 0:
		return NONE
	for h_v in cost.keys():
		var h: Vector2i = h_v
		var dist := HexGrid.distance(h, target)
		var step := int(cost[h])
		if dist < best_d or (dist == best_d and step < best_c and dist < HexGrid.distance(start, target)):
			best = h
			best_d = dist
			best_c = step
	if best == NONE or HexGrid.distance(best, target) >= HexGrid.distance(start, target):
		return NONE
	return best


static func place_card(anchor: Vector2, radius: float, card: Vector2, extra: Rect2 = Rect2()) -> Dictionary:
	var spots: Array[Vector2] = [
		Vector2(anchor.x + radius + 12.0, anchor.y - 24.0),
		Vector2(anchor.x - radius - 12.0 - card.x, anchor.y - 24.0),
		Vector2(anchor.x - card.x * 0.5, anchor.y + radius + 12.0),
		Vector2(anchor.x - card.x * 0.5, anchor.y - radius - 12.0 - card.y),
	]
	for avoid in [true, false]:
		for spot in spots:
			if _place_ok(spot, card, anchor, radius, extra, avoid):
				return {"pos": spot, "nudge": false}
	var fallback := _clamp_card(spots[0], card)
	return {"pos": fallback, "nudge": true}


static func cmd_actions(plan: Dictionary) -> Array:
	var out: Array = []
	for a_v in plan.get("actions", []):
		var a: Dictionary = a_v
		if str(a.get("kind", "")) == "cmd":
			out.append(a)
	return out


static func enabled_cmds(plan: Dictionary) -> Array:
	var out: Array = []
	for a_v in cmd_actions(plan):
		var a: Dictionary = a_v
		if bool(a.get("enabled", false)):
			out.append(a)
	return out


static func _place_ok(pos: Vector2, card: Vector2, anchor: Vector2, radius: float, extra: Rect2, avoid_dock: bool) -> bool:
	var rect := Rect2(pos, card)
	var safe := Rect2(16, 60, 1248, 644)
	if not safe.encloses(rect):
		return false
	var pad := radius + 8.0
	var hex := Rect2(anchor - Vector2(pad, pad), Vector2(pad, pad) * 2.0)
	if rect.intersects(hex):
		return false
	if extra.size.x > 1.0 and rect.intersects(extra):
		return false
	if rect.intersects(Rect2(0, 576, 1016, 160)):
		return false
	if avoid_dock and rect.intersects(Rect2(1008, 440, 272, 280)):
		return false
	return true


static func _can_move(unit: Dictionary) -> bool:
	return not unit.is_empty() and str(unit.get("faction", "")) == "song" and int(unit.get("mp", 0)) > 0


static func _budget(unit: Dictionary) -> int:
	return Pathfinder.budget(unit)


static func _is_ranged(unit: Dictionary) -> bool:
	var spec := DataDB.unit_type(str(unit.get("def_id", "")))
	return int(spec.get("ranged", 0)) > 0


static func _range_of(unit: Dictionary) -> int:
	var spec := DataDB.unit_type(str(unit.get("def_id", "")))
	if int(spec.get("ranged", 0)) > 0:
		return int(spec.get("range", 1))
	return 1


static func _in_range(unit: Dictionary, enemy: Dictionary) -> bool:
	if int(unit.get("mp", 0)) <= 0:
		return false
	var dist := HexGrid.distance(Vector2i(int(unit.q), int(unit.r)), Vector2i(int(enemy.q), int(enemy.r)))
	if _is_ranged(unit):
		return dist >= 1 and dist <= _range_of(unit)
	return dist == 1


static func _assess_at(unit: Dictionary, enemy: Dictionary, at: Vector2i) -> Dictionary:
	var ghost := unit.duplicate()
	ghost.q = at.x
	ghost.r = at.y
	return CombatResolver.assess(ghost, enemy)


static func _act(id: String, label: String, icon: String, key: String, enabled: bool, reason: String, kind: String, cost: int, preview: Dictionary) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"icon": icon,
		"key": key,
		"enabled": enabled,
		"reason": reason,
		"kind": kind,
		"default": false,
		"cost": cost,
		"preview": preview,
	}


static func _push_self_actions(actions: Array, unit: Dictionary, city: Dictionary) -> void:
	var ready := int(unit.mp) > 0
	actions.append(_act("fortify", "驻扎", "act_fortify", "F", ready, "" if ready else "本月已行动", "cmd", 0, {}))
	actions.append(_act("standby", "待命", "act_standby", "Q", ready, "" if ready else "本月已行动", "cmd", 0, {}))
	var undo: Dictionary = unit.get("undo", {})
	if not undo.is_empty():
		actions.append(_act("undo", "撤回移动", "act_undo", "Ctrl+Z", true, "", "cmd", 0, {}))
	if not city.is_empty() and str(city.get("faction", "")) == str(unit.faction):
		actions.append(_act("city", "打开城池", "act_city_panel", "C", true, "", "info", 0, {}))
	actions.append(_act("deselect", "取消选择", "act_deselect", "", true, "", "info", 0, {}))


static func _number_cmds(actions: Array) -> void:
	var n := 1
	for a_v in actions:
		var a: Dictionary = a_v
		if str(a.kind) != "cmd":
			continue
		if str(a.key) == "":
			a.key = str(n)
		n += 1


static func _find(actions: Array, id: String) -> Dictionary:
	for a_v in actions:
		var a: Dictionary = a_v
		if str(a.id) == id:
			return a
	return {}


static func _closer(start: Vector2i, target: Vector2i, cost: Dictionary) -> bool:
	return nearest_step(start, target, cost) != NONE


static func _block_reason(unit: Dictionary, hex: Vector2i, passable: bool, occ: Dictionary) -> String:
	if not passable:
		return "不可通行"
	if not occ.is_empty():
		return "格上已有部队"
	if _in_zoc(hex, unit):
		return "被敌军控制区挡住"
	if int(unit.mp) <= 0:
		return "移动力已用完"
	return "移动力不够"


static func _in_zoc(hex: Vector2i, unit: Dictionary) -> bool:
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


static func _path_of(parent: Dictionary, start: Vector2i, dest: Vector2i) -> Array:
	if dest == NONE or start == NONE or parent.is_empty():
		return []
	var rev: Array[Vector2i] = []
	var cur := dest
	var guard := 0
	while cur != start and guard < 64:
		rev.append(cur)
		if not parent.has(cur):
			return []
		cur = parent[cur]
		guard += 1
	rev.reverse()
	return rev


static func _place_head(hex: Vector2i, terr: Dictionary, city: Dictionary) -> String:
	var owner := DataDB.owner_id(hex.x, hex.y)
	var owner_name := "无主"
	if owner != "":
		owner_name = _faction_name(owner)
	if not city.is_empty():
		var level := str(city.get("level", ""))
		var level_name := {"jing": "京", "fu": "府", "zhou": "州", "xian": "县"}.get(level, "")
		var bits := str(city.get("name", ""))
		if level_name != "":
			bits += " · " + level_name
		bits += " · " + _faction_name(str(city.get("faction", owner)))
		return bits
	var head := "%s · %s" % [str(terr.get("name", "土地")), owner_name]
	var feat := DataDB.feature_at(hex.x, hex.y)
	if not feat.is_empty() and str(feat.get("id", "")) != "pass":
		head += " · " + str(feat.get("name", ""))
	if _has_river(hex):
		head += " · 临河"
	return head


static func _append_place_more(more: Array, hex: Vector2i, terr: Dictionary, city: Dictionary) -> void:
	var move := int(terr.get("move", 1))
	var defense := int(terr.get("defense", 0))
	if bool(terr.get("passable", false)):
		var sign := "+" if defense > 0 else ""
		more.append("移动消耗 %d，防御 %s%d" % [move, sign, defense])
	if not city.is_empty():
		more.append("人口 %s，城墙 +%d" % [str(city.get("pop", "")), int(city.get("walls", 0))])
		var output: Dictionary = city.get("output", {})
		if not output.is_empty():
			more.append("本月产出 粮%d 钱%d" % [int(output.get("food", 0)), int(output.get("money", 0))])
	if _has_river(hex):
		more.append("渡河攻击 -3")
		more.append("渡大河 -6")
		more.append("大河暂不挡路")
	var feat := DataDB.feature_at(hex.x, hex.y)
	if str(feat.get("id", "")) == "pass":
		more.append("%s · 关隘" % str(feat.get("name", "关")))


static func _append_path_more(more: Array, path: Array) -> void:
	var names: PackedStringArray = []
	var limit := mini(path.size(), 6)
	for i in limit:
		var h: Vector2i = path[i]
		var terr := DataDB.terrain(DataDB.terrain_id(h.x, h.y))
		names.append(str(terr.get("name", "")))
	if names.size() > 0:
		more.append("沿途 " + "、".join(names))


static func _append_unit_more(more: Array, unit: Dictionary) -> void:
	var spec := DataDB.unit_type(str(unit.def_id))
	more.append("生命%d，移动%d/%d" % [int(unit.hp), int(unit.mp), int(unit.max_mp)])
	if str(unit.general) != "":
		more.append("将领 %s" % str(unit.general))
	for trait_v in spec.get("traits", []):
		var row: Dictionary = trait_v
		var line := _trait_line(row)
		if line != "":
			more.append(line)


static func _append_forecast_more(more: Array, preview: Dictionary) -> void:
	more.append("攻 " + CombatResolver.format_parts(preview.atk_parts))
	more.append("守 " + CombatResolver.format_parts(preview.def_parts))
	if bool(preview.ranged):
		more.append("攻方不受反击")


static func _self_head(unit: Dictionary) -> String:
	var spec := DataDB.unit_type(str(unit.def_id))
	if int(unit.mp) <= 0:
		return "%s · 本月已行动" % str(unit.name)
	return "%s · %s · 移动%d/%d" % [str(unit.name), str(spec.get("name", "")), int(unit.mp), int(unit.max_mp)]


static func _unit_head(unit: Dictionary) -> String:
	return "%s · %s · 生命%d" % [str(unit.name), _faction_name(str(unit.faction)), int(unit.hp)]


static func _faction_name(id: String) -> String:
	if id == "":
		return "无主"
	return str(DataDB.faction(id).get("name", id))


static func _clamp_card(pos: Vector2, card: Vector2) -> Vector2:
	var safe := Rect2(16, 60, 1248, 644)
	var advisor := Rect2(0, 576, 1016, 160)
	var dock := Rect2(1008, 440, 272, 280)
	var x := clampf(pos.x, safe.position.x, maxf(safe.position.x, safe.end.x - card.x))
	var y := clampf(pos.y, safe.position.y, maxf(safe.position.y, safe.end.y - card.y))
	if Rect2(Vector2(x, y), card).intersects(advisor):
		y = advisor.position.y - card.y - 6.0
	if Rect2(Vector2(x, y), card).intersects(dock):
		var left := dock.position.x - card.x - 8.0
		if left >= safe.position.x:
			x = left
		else:
			y = dock.position.y - card.y - 6.0
	x = clampf(x, safe.position.x, maxf(safe.position.x, safe.end.x - card.x))
	y = clampf(y, safe.position.y, maxf(safe.position.y, safe.end.y - card.y))
	return Vector2(x, y)


static func loss_text(who: String, lo: int, hi: int) -> String:
	if lo == 0 and hi == 0:
		return "%s 0" % who
	return "%s -%d~%d" % [who, lo, hi]


static func _card_sub(unit: Dictionary, occ: Dictionary) -> String:
	var terr := DataDB.terrain(DataDB.terrain_id(int(occ.q), int(occ.r)))
	var spec := DataDB.unit_type(str(occ.get("def_id", "")))
	var dist := HexGrid.distance(Vector2i(int(unit.q), int(unit.r)), Vector2i(int(occ.q), int(occ.r)))
	return "%s · %s / %s%s · 生命%d · 相距%d" % [
		str(occ.get("name", "")),
		str(terr.get("name", "土地")),
		_faction_name(str(occ.get("faction", ""))),
		_class_label(spec),
		int(occ.get("hp", 0)),
		dist,
	]


static func _class_label(spec: Dictionary) -> String:
	var kind := str(spec.get("unit_class", ""))
	var base := "步兵"
	match kind:
		"ranged":
			base = "弓兵"
		"cavalry":
			base = "骑兵"
		"siege":
			base = "攻城"
		"infantry":
			base = "步兵"
		_:
			base = str(spec.get("name", "部队"))
	for trait_v in spec.get("traits", []):
		var row: Dictionary = trait_v
		if str(row.get("type", "")) != "terrain_power":
			continue
		var terrains: Array = row.get("terrains", [])
		if kind == "infantry" and (terrains.has("mountain") or terrains.has("loess")):
			return "山地步兵"
	return base


static func _trait_line(row: Dictionary) -> String:
	var kind := str(row.get("type", ""))
	var bonus := int(row.get("bonus", 0))
	var named := str(row.get("name", ""))
	if named != "":
		return named
	match kind:
		"vs_class":
			return "克制%s +%d" % [_class_word(str(row.get("class", ""))), bonus]
		"charge":
			return "冲锋 +%d" % bonus
		"terrain_power":
			return "山地战力 +%d" % bonus
		_:
			return ""


static func _class_word(kind: String) -> String:
	match kind:
		"cavalry":
			return "骑兵"
		"ranged":
			return "弓兵"
		"siege":
			return "攻城"
		"infantry":
			return "步兵"
		_:
			return "兵"


static func _has_river(hex: Vector2i) -> bool:
	var masks: Array = DataDB.river_masks.get(hex, [])
	if masks.size() < 2:
		return false
	return int(masks[0]) != 0 or int(masks[1]) != 0


static func _badges(style: String, hex: Vector2i, city: Dictionary) -> Array:
	var badges: Array = []
	match style:
		"reach":
			badges.append("hb_move")
		"far":
			badges.append("hb_move_near")
		"blocked", "impassable":
			badges.append("hb_blocked")
		"attack":
			badges.append("hb_attack")
		"move_attack":
			badges.append("hb_move_attack")
		"enemy_far":
			badges.append("hb_eye")
		"own_acted":
			badges.append("hb_acted")
		"city_own":
			badges.append("hb_city_own")
		"city_enemy":
			badges.append("hb_city_enemy")
		"neutral":
			badges.append("hb_neutral")
	if _has_river(hex):
		badges.append("hb_river")
	var feat := DataDB.feature_at(hex.x, hex.y)
	var fid := str(feat.get("id", ""))
	if fid == "pass":
		badges.append("hb_pass")
	elif fid != "" and fid != "pass":
		badges.append("hb_resource")
	if not city.is_empty() and style != "city_own" and style != "city_enemy":
		if str(city.get("faction", "")) == "song":
			badges.append("hb_city_own")
		elif DataDB.hostile("song", str(city.get("faction", ""))):
			badges.append("hb_city_enemy")
	return badges


static func _width_of(style: String) -> float:
	match style:
		"reach":
			return 0.24
		"far":
			return 0.20
		"attack":
			return 0.32
		"move_attack":
			return 0.24
		"own_ready":
			return 0.12
		"own_acted":
			return 0.10
		"city_own", "city_enemy":
			return 0.22
		_:
			return 0.16


static func _shader_of(style: String) -> int:
	match style:
		"reach", "move_attack", "attack":
			return 1
		"empty":
			return 0
		"far":
			return 2
		"blocked", "impassable":
			return 3
		"neutral":
			return 4
		"city_own":
			return 5
		"city_enemy":
			return 6
		"own_ready":
			return 7
		"enemy_far":
			return 8
		_:
			return 0


static func _color_of(style: String, city: Dictionary) -> Color:
	match style:
		"reach":
			return Color(1, 1, 1, 1)
		"far":
			return Color("f4efe4b2")
		"blocked", "impassable":
			return Color("a39482")
		"attack", "move_attack":
			return Color("c44a3a")
		"enemy_far":
			return Color("c44a3ab2")
		"own_ready":
			return Color("e8cb7c")
		"own_acted":
			return Color("e8cb7c80")
		"city_own":
			return Color("c23b2a")
		"city_enemy":
			var faction := str(city.get("faction", ""))
			if faction == "liao":
				return Color("24467f")
			return Color("6b3e8e")
		"neutral":
			return Color("c4b08a")
		_:
			return Color(1, 1, 1, 0.85)
