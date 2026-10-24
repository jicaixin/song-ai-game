class_name Campaign
extends RefCounted

## Rebel marches and the light bandit spawns in the quiet years.

const MARKS := ["甲", "乙", "丙", "丁", "戊"]


static func alive(tag: String) -> int:
	var n := 0
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("tag", "")) == tag and int(u.get("hp", 0)) > 0:
			n += 1
	return n


static func after_choice(event_id: String, choice_id: String) -> void:
	if event_id == "wanglun":
		if choice_id == "amnesty":
			_pay(200, 200)
			_clear_tag("wanglun")
			GameState.add_unit("song_xiangjun", "收编虎翼", 29, 30)
		elif choice_id == "fight":
			_ensure("wanglun", 2, "rebel_infantry", "沂州叛军", 29, 30, "yangzhou")
		elif choice_id == "blame":
			_ensure("wanglun", 1, "rebel_infantry", "沂州叛军", 29, 30, "yangzhou")
	elif event_id == "zhanghai":
		if choice_id == "amnesty":
			_pay(200, 200)
			_clear_tag("zhanghai")
			GameState.add_unit("song_xiangjun", "收编商山", 16, 28)
		elif choice_id == "fight":
			_ensure("zhanghai", 2, "rebel_bandit", "商山贼", 16, 28, "yanzhou")
	elif event_id == "wangze" and choice_id != "relief":
		_ensure("wangze", 2, "rebel_infantry", "贝州叛军", 27, 25, "beizhou")


static func on_turn() -> void:
	press_liao()
	_hequ_shift()
	if _live("wangze") and not GameState.campaign.has("wangze_spawned"):
		_ensure("wangze", 2, "rebel_infantry", "贝州叛军", 27, 25, "beizhou")
		GameState.campaign["wangze_spawned"] = GameState.turn
	if GameState.campaign.has("wangze_spawned") and not GameState.event_flags.has("wangze_relief"):
		if not GameState.event_flags.has("wangze_storm") and not GameState.event_flags.has("wangze_tunnel"):
			if alive("wangze") > 0 and alive("wangze") < 4:
				_ensure("wangze", alive("wangze") + 1, "rebel_infantry", "贝州叛军", 27, 25, "beizhou")
	if GameState.event_flags.has("zhanghai_fight") and not bool(GameState.campaign.get("zhanghai_grew", false)):
		var born := int(GameState.campaign.get("zhanghai_born", 0))
		if born > 0 and GameState.turn - born >= 6 and alive("zhanghai") > 0:
			_ensure("zhanghai", alive("zhanghai") + 1, "rebel_bandit", "商山贼", 16, 28, "yanzhou")
			GameState.campaign["zhanghai_grew"] = true
	if GameState.turn >= 64 and GameState.turn <= 72 and GameState.morale < 45:
		if GameState.turn == 64 or GameState.turn == 70:
			var key := "bandit_%d" % GameState.turn
			if not GameState.campaign.has(key):
				_ensure(key, 1, "rebel_bandit", "山贼", 15, 28, "yanzhou")
				GameState.campaign[key] = true


static func press_liao() -> void:
	if GameState.campaign.has("liao_spawned"):
		return
	if not GameState.event_flags.has("zengbi_refuse"):
		return
	_spawn_one("liao_south", "liao_pishi", "南皮室", 30, 21)
	_spawn_one("liao_south", "liao_subject", "属国骑", 30, 20)
	_spawn_one("liao_south", "liao_bow", "辽弓骑", 31, 20)
	GameState.campaign["liao_spawned"] = GameState.turn
	GameState.notice = "辽军压到雄州。"


static func muster() -> Vector2i:
	var city := DataDB.city_by_id("xiongzhou")
	if city.is_empty():
		return Vector2i(29, 21)
	return Vector2i(int(city.get("q", 29)), int(city.get("r", 21)))


static func full_push() -> bool:
	var song := 0
	var liao := 0
	var xia_near := false
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if int(u.get("hp", 0)) <= 0:
			continue
		var melee := int(DataDB.unit_type(str(u.get("def_id", ""))).get("melee", 0))
		var fac := str(u.get("faction", ""))
		if fac == "song":
			song += melee
		elif fac == "liao" and str(u.get("tag", "")) == "liao_south":
			liao += melee
		elif fac == "xia":
			var here := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
			if _near_song_city(here, 3):
				xia_near = true
	if liao > 0 and song * 10 < liao * 8:
		return true
	var rebels := alive("wanglun") + alive("zhanghai") + alive("wangze")
	return rebels > 0 and xia_near


static func _hequ_shift() -> void:
	if GameState.turn < 52 or not GameState.campaign.has("liao_spawned"):
		return
	if GameState.campaign.has("hequ_shift") or full_push():
		return
	if alive("liao_south") <= 0:
		return
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("tag", "")) == "liao_south" and int(u.get("hp", 0)) > 0:
			u["hp"] = 0
			break
	GameState._remove_dead()
	GameState.campaign["hequ_shift"] = true
	GameState.notice = "河曲开战，辽军西调了一支。"


static func _near_song_city(h: Vector2i, limit: int) -> bool:
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if str(city.get("faction", "")) != "song":
			continue
		var there := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
		if HexGrid.distance(h, there) <= limit:
			return true
	return false


static func _spawn_one(tag: String, def_id: String, base: String, q: int, r: int) -> void:
	var uid := GameState.add_unit(def_id, base, q, r)
	var unit := GameState.unit_by_id(uid)
	if unit.is_empty():
		return
	unit["tag"] = tag
	unit["march"] = "xiongzhou"
	unit["born"] = GameState.turn


static func _live(event_id: String) -> bool:
	if GameState.pending_events.has(event_id):
		return true
	if GameState.event_log.has(event_id):
		return true
	return GameState.event_choice.has(event_id)


static func _ensure(tag: String, count: int, def_id: String, base: String, q: int, r: int, march: String) -> void:
	var have := alive(tag)
	var i := have
	while i < count:
		var mark := ""
		if i < MARKS.size():
			mark = MARKS[i]
		var uid := GameState.add_unit(def_id, "%s%s" % [base, mark], q + i, r)
		var unit := GameState.unit_by_id(uid)
		if not unit.is_empty():
			unit["tag"] = tag
			unit["march"] = march
			unit["born"] = GameState.turn
		i += 1
	GameState.campaign["%s_born" % tag] = GameState.turn


static func _clear_tag(tag: String) -> void:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("tag", "")) == tag:
			u["hp"] = 0
	GameState._remove_dead()


static func _pay(food: int, money: int) -> void:
	GameState.resources["food"] = maxi(0, int(GameState.resources.get("food", 0)) - food)
	GameState.resources["money"] = maxi(0, int(GameState.resources.get("money", 0)) - money)
