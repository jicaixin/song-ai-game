extends Node

var year := 1040
var month := 1
var turn := 1
var weather_id := "clear"
var battery := 42
var last_gen := 0
var resources := {}
var morale := 62
var prestige := 55
var secrecy := 70
var units: Array = []
var next_uid := 1
var rng := RandomNumberGenerator.new()
var seed_value := 104001
var cooldowns := {}
var advisor_text := ""
var advisor_mood := "serious"
var selected_uid := -1
var inspected_uid := -1
var input_locked := false
var last_event := ""
var playing := false

func _ready() -> void:
	rng.seed = seed_value


func new_game() -> void:
	var sc: Dictionary = DataDB.scenario
	year = int(sc.get("year", 1040))
	month = int(sc.get("month", 1))
	turn = 1
	seed_value = int(sc.get("seed", 104001))
	rng.seed = seed_value
	resources = (sc.get("resources", {}) as Dictionary).duplicate(true)
	for k in resources.keys():
		resources[k] = int(resources[k])
	morale = int(sc.get("morale", 62))
	prestige = int(sc.get("prestige", 55))
	secrecy = int(sc.get("secrecy", 70))
	units = []
	next_uid = 1
	cooldowns = {}
	selected_uid = -1
	inspected_uid = -1
	input_locked = false
	last_event = "三川口前夜。先看延州。"
	battery = int(DataDB.balance.get("power", {}).get("battery_start", 42))
	_place_scenario_units()
	roll_weather()
	apply_power()
	restore_movement()
	AdvisorSystem.say("game_start")
	playing = true
	EventBus.state_changed.emit()


func _place_scenario_units() -> void:
	for spec_v in DataDB.scenario.get("units", []):
		var spec: Dictionary = spec_v
		var city := DataDB.city_by_id(str(spec.get("city", "")))
		if city.is_empty():
			push_error("剧本城市缺失 %s" % str(spec.get("city", "")))
			continue
		var q := int(city.q) + int(spec.get("dq", 0))
		var r := int(city.r) + int(spec.get("dr", 0))
		var spot := _find_open(q, r)
		var utype := str(spec.get("def", ""))
		var ut := DataDB.unit_type(utype)
		units.append({
			"uid": next_uid,
			"def_id": utype,
			"name": str(spec.get("name", ut.get("name", utype))),
			"faction": str(ut.get("faction", "song")),
			"q": spot.x,
			"r": spot.y,
			"hp": 100,
			"mp": int(ut.get("move", 2)),
			"max_mp": int(ut.get("move", 2)),
			"general": str(spec.get("general", "")),
			"general_bonus": int(spec.get("general_bonus", 0)),
		})
		next_uid += 1


func _find_open(q: int, r: int) -> Vector2i:
	var start := Vector2i(q, r)
	if _free(start):
		return start
	for radius in range(1, 8):
		var cur := start + HexGrid.DIRS[4] * radius
		for dir in HexGrid.DIRS:
			for _step in radius:
				if _free(cur):
					return cur
				cur += dir
	return start


func _free(h: Vector2i) -> bool:
	if not DataDB.in_bounds(h.x, h.y):
		return false
	if not bool(DataDB.terrain(DataDB.terrain_id(h.x, h.y)).get("passable", false)):
		return false
	return unit_at(h).is_empty()


func unit_at(h: Vector2i) -> Dictionary:
	for u_v in units:
		var u: Dictionary = u_v
		if int(u.q) == h.x and int(u.r) == h.y and int(u.hp) > 0:
			return u
	return {}


func unit_by_id(uid: int) -> Dictionary:
	for u_v in units:
		var u: Dictionary = u_v
		if int(u.uid) == uid and int(u.hp) > 0:
			return u
	return {}


func occupied(h: Vector2i, ignore_uid: int) -> bool:
	var u := unit_at(h)
	return not u.is_empty() and int(u.uid) != ignore_uid


func selected_unit() -> Dictionary:
	return unit_by_id(selected_uid)


func roll_weather() -> void:
	var season := Calendar.season(month)
	var bag: Array[String] = []
	var clear_w := 45 if season == "autumn" or season == "winter" else 40
	var rain_w := 15 if season == "summer" else 10
	var dust_w := 5 if season == "spring" else 0
	_fill(bag, "clear", clear_w)
	_fill(bag, "cloudy", 30)
	_fill(bag, "overcast", 15)
	if season == "winter":
		_fill(bag, "snow", rain_w)
	else:
		_fill(bag, "rain", rain_w)
	_fill(bag, "dust", dust_w)
	weather_id = bag[rng.randi() % bag.size()]


func _fill(bag: Array[String], id: String, n: int) -> void:
	for _i in n:
		bag.append(id)


func apply_power() -> void:
	var power: Dictionary = DataDB.balance.get("power", {})
	var season_name := Calendar.season(month)
	var s := float(DataDB.balance.get("season", {}).get(season_name, 1.0))
	var w := float(DataDB.balance.get("weather", {}).get(weather_id, {}).get("factor", 1.0))
	var panel := float(power.get("panel", 1.0))
	last_gen = int(round(float(power.get("base", 36)) * s * w * panel))
	var standby := int(power.get("standby", 4))
	var cap := int(power.get("battery_max", 80))
	battery = clampi(battery - standby + last_gen, 0, cap)


func power_band() -> String:
	var cap := float(DataDB.balance.get("power", {}).get("battery_max", 80))
	if cap <= 0.0:
		return "normal"
	var ratio := float(battery) / cap
	if ratio < 0.15:
		return "low"
	if ratio < 0.35:
		return "save"
	return "normal"


func restore_movement() -> void:
	for u_v in units:
		var u: Dictionary = u_v
		var ut := DataDB.unit_type(str(u.def_id))
		u.mp = int(ut.get("move", 2))
		u.max_mp = int(ut.get("move", 2))


func finish_turn() -> void:
	month += 1
	if month > 12:
		month = 1
		year += 1
	roll_weather()
	apply_power()
	_economy()
	restore_movement()
	turn += 1
	selected_uid = -1
	inspected_uid = -1


func _economy() -> void:
	var factor := 1.0
	var eco: Dictionary = DataDB.balance.get("economy", {})
	if morale <= 40:
		factor = float(eco.get("morale_low", 0.75))
	elif morale >= 80:
		factor = float(eco.get("morale_high", 1.1))
	var food := 0
	var money := 0
	var craft := 0
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		if str(city.get("faction", "")) != "song":
			continue
		var output: Dictionary = city.get("output", {})
		food += int(output.get("food", 0))
		money += int(output.get("money", 0))
		craft += int(output.get("craft", 0))
	food = int(round(float(food) * factor))
	money = int(round(float(money) * factor))
	craft = int(round(float(craft) * factor))
	for u_v in units:
		var u: Dictionary = u_v
		if str(u.faction) != "song" or int(u.hp) <= 0:
			continue
		var up: Dictionary = DataDB.unit_type(str(u.def_id)).get("upkeep", {})
		food -= int(up.get("food", 0))
		money -= int(up.get("money", 0))
	resources["food"] = max(0, int(resources.get("food", 0)) + food)
	resources["money"] = max(0, int(resources.get("money", 0)) + money)
	resources["craft"] = max(0, int(resources.get("craft", 0)) + craft)
	last_event = "本月结算 粮%s 钱%s 匠%s 发电 %d" % [_signed(food), _signed(money), _signed(craft), last_gen]


func _signed(n: int) -> String:
	if n > 0:
		return "+%d" % n
	return str(n)


func spend_mp(uid: int, cost: int) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	u.mp = max(0, int(u.mp) - cost)


func set_pos(uid: int, h: Vector2i) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	u.q = h.x
	u.r = h.y


func fortify(uid: int) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	u.mp = 0
	last_event = "%s 驻扎。" % str(u.name)
	EventBus.state_changed.emit()


func resolve_attack(atk_uid: int, def_uid: int) -> void:
	var atk := unit_by_id(atk_uid)
	var dfd := unit_by_id(def_uid)
	if atk.is_empty() or dfd.is_empty():
		return
	if int(atk.mp) <= 0:
		return
	var preview := CombatResolver.assess(atk, dfd)
	if int(preview.dist) <= 0:
		return
	var spec := DataDB.unit_type(str(atk.def_id))
	var max_range := int(spec.get("range", 0)) if int(spec.get("ranged", 0)) > 0 else 1
	if int(preview.dist) > max_range:
		return
	var dmg := CombatResolver.roll_damage(preview, rng)
	dfd.hp = int(dfd.hp) - dmg.y
	if not bool(preview.ranged):
		atk.hp = int(atk.hp) - dmg.x
	atk.mp = 0
	var atk_name := str(atk.name)
	var def_name := str(dfd.name)
	var atk_dead := int(atk.hp) <= 0
	var def_dead := int(dfd.hp) <= 0
	var player_dead := (str(atk.faction) == "song" and atk_dead) or (str(dfd.faction) == "song" and def_dead)
	var enemy_dead := (str(atk.faction) != "song" and atk_dead) or (str(dfd.faction) != "song" and def_dead)
	_remove_dead()
	var counter := "不受反击" if bool(preview.ranged) else "攻方 -%d" % dmg.x
	last_event = "%s 攻击 %s，守方 -%d，%s。" % [atk_name, def_name, dmg.y, counter]
	AdvisorSystem.say_combat(player_dead, enemy_dead)
	EventBus.combat_finished.emit()
	EventBus.state_changed.emit()


func _remove_dead() -> void:
	var keep: Array = []
	for u_v in units:
		var u: Dictionary = u_v
		if int(u.hp) > 0:
			keep.append(u)
			continue
		if int(u.uid) == selected_uid:
			selected_uid = -1
		if int(u.uid) == inspected_uid:
			inspected_uid = -1
	units = keep


func to_save() -> Dictionary:
	return {
		"save_version": 1,
		"year": year,
		"month": month,
		"turn": turn,
		"weather_id": weather_id,
		"battery": battery,
		"last_gen": last_gen,
		"resources": resources.duplicate(true),
		"morale": morale,
		"prestige": prestige,
		"secrecy": secrecy,
		"units": units.duplicate(true),
		"next_uid": next_uid,
		"rng_state": str(rng.state),
		"cooldowns": cooldowns.duplicate(true),
		"advisor_text": advisor_text,
		"advisor_mood": advisor_mood,
		"seed": seed_value,
		"last_event": last_event,
	}


func from_save(data: Dictionary) -> bool:
	if int(data.get("save_version", 0)) != 1:
		return false
	year = int(data.get("year", 1040))
	month = int(data.get("month", 1))
	turn = int(data.get("turn", 1))
	weather_id = str(data.get("weather_id", "clear"))
	battery = int(data.get("battery", 0))
	last_gen = int(data.get("last_gen", 0))
	morale = int(data.get("morale", 60))
	prestige = int(data.get("prestige", 50))
	secrecy = int(data.get("secrecy", 70))
	next_uid = int(data.get("next_uid", 1))
	seed_value = int(data.get("seed", 104001))
	advisor_text = str(data.get("advisor_text", ""))
	advisor_mood = str(data.get("advisor_mood", "normal"))
	last_event = str(data.get("last_event", ""))
	resources = {}
	var raw_res: Dictionary = data.get("resources", {})
	for k in raw_res.keys():
		resources[str(k)] = int(raw_res[k])
	cooldowns = {}
	var raw_cd: Dictionary = data.get("cooldowns", {})
	for k in raw_cd.keys():
		cooldowns[str(k)] = int(raw_cd[k])
	units = []
	for u_v in data.get("units", []):
		var src: Dictionary = u_v
		units.append({
			"uid": int(src.get("uid", 0)),
			"def_id": str(src.get("def_id", "")),
			"name": str(src.get("name", "")),
			"faction": str(src.get("faction", "")),
			"q": int(src.get("q", 0)),
			"r": int(src.get("r", 0)),
			"hp": int(src.get("hp", 100)),
			"mp": int(src.get("mp", 0)),
			"max_mp": int(src.get("max_mp", 2)),
			"general": str(src.get("general", "")),
			"general_bonus": int(src.get("general_bonus", 0)),
		})
	rng.state = int(str(data.get("rng_state", "0")))
	selected_uid = -1
	inspected_uid = -1
	input_locked = false
	playing = true
	EventBus.state_changed.emit()
	return true
