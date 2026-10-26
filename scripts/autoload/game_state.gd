extends Node

const GoalSystem = preload("res://scripts/core/goal_system.gd")

const EventSystem = preload("res://scripts/core/event_system.gd")

const Campaign = preload("res://scripts/core/campaign.gd")

const Pathfinder = preload("res://scripts/core/pathfinder.gd")

const CITY_CAP := {"jun": 1, "zhou": 2, "fu": 3, "jing": 3}
const BLUEPRINT_CAP := 3
const BLUEPRINT_CAP_MAX := 5
const QUEUE_CAP := 3

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
var tech_done: Array = []
var tech_queue: Array = []
var tech_designing := ""
var tech_design_prog := 0
var tech_blueprints: Array = []
var tech_trials: Array = []
var tech_paused := {}
var tech_target := ""
var tech_target_skip: Array = []
var target_notice := ""
var target_advisor := ""
var target_advisor_mood := ""
var target_advisor_id := ""
var target_added: Array = []
var target_wait_noted: Array = []
var _sort_spine: Array = []
var _sort_index := {}
var tech_tutorial_done := false
var tutorial_done := false
var hint_menu_seen := false
var hint_enemy_menu_seen := false
var hint_blocked_seen := false
var hint_mp_seen := false
var end_warn_off := false
var design_notice := ""
var research_ping_until := 0
var site_turns := {}
# 试制暂不因实践不足而停工。材料产出接上后把 PRACTICE_GATE 改成 true。
const PRACTICE_GATE := false
const PRACTICE_PER_TURN_CAP := 3
const PRACTICE_SITE := {
	"watermill": "mill",
	"coalpit": "coal",
	"coke": "coke",
	"steel": "steel",
	"steampump": "steam",
}
const PRACTICE_BUILDING := {
	"mill": "watermill",
	"coal": "coalpit",
	"coke": "coke",
	"steel": "steel",
	"steam": "steampump",
}
const PRACTICE_NAME := {
	"mill": "水磨坊",
	"coal": "煤场",
	"coke": "焦炉",
	"steel": "炼钢厂",
	"steam": "蒸汽抽水站",
}
var practice_gate := false
var city_buildings := {}
var practice_said: Array = []
var pending_practice: Array = []
var era3_flash_until := 0
var firmware_done: Array = []
var edicts_done: Array = []
var notice := ""
var battle_lines: Array[String] = []
var pending_blueprint := ""
var research_idle_warned := false
var relations := {}
var subsidies: Array = []
var markets: Array = []
var envoy_turn := {}
var event_choice := {}
var pending_events: Array = []
var event_log: Array = []
var event_flags := {}
var line_history := {}
var line_group_at := {}
var line_recent: Array = []
var meters := {"xia_war": 70, "liao_demand": 20, "unrest": 0}
var report_hold := false
var report_unread := false
var last_report := ""
var month_span := 1
var orders: Array = []
var order_seen := {}
var card_queue: Array = []
var chapter_shown := {}
var chapter_rewarded := {}
var reward_queue: Array = []
var battery_bonus := 0
var blueprint_bonus := 0
var presearch := 0
var supply_left := 0
var grain_sold_turn := -1
var transfer_turn := -1
var feast_turn := -1
var bargain_round := 0
var bargain_used := {}
var bargain_west := false
var order_place := {}
var rest_streak := 0
var campaign := {}
var shelved: Array = []
var power_made := 0
var power_waste := 0
var power_over := 0
var power_sunk := 0
var grain_samples := 0
var grain_le12 := 0
var epilogue_shown := false
var rating_floor := 0
var recovery_until := 0
var recovery_turn := -1
var demo_over := false
var presearch_bonus := 0
var shading := false
var shade_skip := 0
var night_read := false
var night_pay := 0
var design_ease := 0
var jingnei_mod := 0
var city_home := {}
var mold_said := -99
var presearch_full_said := -99
var produce_floor := -1
var food_start := 0

func _ready() -> void:
	rng.seed = seed_value


func new_game() -> void:
	_release_cities()
	var sc: Dictionary = DataDB.scenario
	year = int(sc.get("year", 1040))
	month = int(sc.get("month", 1))
	turn = 1
	seed_value = int(sc.get("seed", 104001))
	rng.seed = seed_value
	resources = (sc.get("resources", {}) as Dictionary).duplicate(true)
	for k in resources.keys():
		resources[k] = int(resources[k])
	food_start = int(resources.get("food", 0))
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
	_reset_research()
	_reset_politics()
	battery = int(DataDB.balance.get("power", {}).get("battery_start", 42))
	_place_scenario_units()
	roll_weather()
	apply_power()
	restore_movement()
	tutorial_done = false
	battle_lines = []
	pending_blueprint = ""
	research_idle_warned = false
	hint_menu_seen = false
	hint_enemy_menu_seen = false
	hint_blocked_seen = false
	hint_mp_seen = false
	end_warn_off = false
	design_notice = ""
	research_ping_until = 0
	AdvisorSystem.say("game_start")
	EventSystem.scan()
	GoalSystem.on_turn()
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


func find_open(q: int, r: int) -> Vector2i:
	return _find_open(q, r)


func unit_by_name(unit_name: String) -> Dictionary:
	for u_v in units:
		var u: Dictionary = u_v
		if str(u.get("name", "")) == unit_name and int(u.hp) > 0:
			return u
	return {}


func add_unit(def_id: String, unit_name: String, q: int, r: int) -> int:
	var ut := DataDB.unit_type(def_id)
	var spot := _find_open(q, r)
	var uid := next_uid
	units.append({
		"uid": uid,
		"def_id": def_id,
		"name": unit_name,
		"faction": str(ut.get("faction", "xia")),
		"q": spot.x,
		"r": spot.y,
		"hp": 100,
		"mp": int(ut.get("move", 2)),
		"max_mp": int(ut.get("move", 2)),
		"general": "",
		"general_bonus": 0,
	})
	next_uid += 1
	return uid


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


func units_at(h: Vector2i) -> Array:
	var out: Array = []
	for u_v in units:
		var u: Dictionary = u_v
		if int(u.q) == h.x and int(u.r) == h.y and int(u.hp) > 0:
			out.append(u)
	return out


func city_cap(city: Dictionary) -> int:
	if city.is_empty():
		return 1
	return int(CITY_CAP.get(str(city.get("level", "")), 1))


func unit_power(unit: Dictionary) -> int:
	var spec := DataDB.unit_type(str(unit.get("def_id", "")))
	var base := maxi(int(spec.get("melee", 0)), int(spec.get("ranged", 0)))
	return int(unit.get("hp", 0)) * maxi(1, base)


func city_top(h: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1
	for u_v in units_at(h):
		var u: Dictionary = u_v
		var score := unit_power(u)
		var better := score > best_score
		if not better and score == best_score and not best.is_empty():
			better = int(u.get("uid", 0)) < int(best.get("uid", 0))
		if better:
			best_score = score
			best = u
	return best


func defender_at(h: Vector2i) -> Dictionary:
	if not DataDB.city_at_hex(h.x, h.y).is_empty():
		var top := city_top(h)
		if not top.is_empty():
			return top
	return unit_at(h)


func unit_by_id(uid: int) -> Dictionary:
	for u_v in units:
		var u: Dictionary = u_v
		if int(u.uid) == uid and int(u.hp) > 0:
			return u
	return {}


func occupied(h: Vector2i, ignore_uid: int) -> bool:
	var mover := unit_by_id(ignore_uid)
	var city := DataDB.city_at_hex(h.x, h.y)
	var faction := str(mover.get("faction", ""))
	var friendly_city := not city.is_empty() and not mover.is_empty() and str(city.get("faction", "")) == faction
	if friendly_city:
		var n := 0
		for u_v in units_at(h):
			var u: Dictionary = u_v
			if int(u.get("uid", -1)) == ignore_uid:
				continue
			if DataDB.hostile(faction, str(u.get("faction", ""))):
				return true
			n += 1
		return n >= city_cap(city)
	for u_v2 in units_at(h):
		var other: Dictionary = u_v2
		if int(other.get("uid", -1)) != ignore_uid:
			return true
	return false


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
	# 人力坊 / 牛转 / 水轮 are not in this sum (tech debt). If they are wired later,
	# that building power must stay full: only the solar term is shaded.
	var power: Dictionary = DataDB.balance.get("power", {})
	var season_name := Calendar.season(month)
	var s := float(DataDB.balance.get("season", {}).get(season_name, 1.0))
	var w := float(DataDB.balance.get("weather", {}).get(weather_id, {}).get("factor", 1.0))
	var panel := float(power.get("panel", 1.0))
	if tech_done.has("E01"):
		panel *= 1.15
	var solar := int(round(float(power.get("base", 36)) * s * w * panel))
	shading = false
	var pool := presearch_cap()
	if battery >= battery_cap() and presearch * 5 >= pool * 4 and shade_skip != turn:
		solar = int(solar / 2)
		shading = true
	last_gen = solar
	var standby := standby_cost()
	var cap := battery_cap()
	var gained := battery - standby + last_gen
	if night_read and gained >= 4:
		gained -= 4
		if rng.randi() % 2 == 0:
			night_pay = 3
		elif tech_designing != "":
			tech_design_prog += 1
		else:
			design_ease += 1
	power_made += last_gen
	if gained > cap:
		var overflow := gained - cap
		battery = cap
		power_over += overflow
		overflow = _pour_design(overflow)
		overflow = _absorb_presearch(overflow)
		power_waste += overflow
		power_sunk += (gained - cap) - overflow
	else:
		battery = maxi(0, gained)


func presearch_cap() -> int:
	return mini(80, 60 + presearch_bonus)


func _absorb_presearch(overflow: int) -> int:
	var left := overflow
	if tech_designing == "":
		_convert_presearch()
	left = _store_presearch(left)
	if left > 0 and tech_designing == "":
		_convert_presearch()
		left = _store_presearch(left)
	var pool := presearch_cap()
	if presearch >= pool and turn - presearch_full_said >= 8:
		presearch_full_said = turn
		AdvisorSystem.present("预研池满了。兑成匠，或兑一点皇威。", "serious", "presearch_full")
	return left


func _store_presearch(left: int) -> int:
	var room := maxi(0, presearch_cap() - presearch)
	var kept := mini(left, room)
	presearch += kept
	return left - kept


func _convert_presearch() -> void:
	var craft_n := 0
	while presearch >= 5 and craft_n < 15:
		presearch -= 5
		craft_n += 1
	if craft_n > 0:
		resources["craft"] = int(resources.get("craft", 0)) + craft_n
	if presearch >= 10:
		presearch -= 10
		morale += 1


func _pour_design(overflow: int) -> int:
	var left := overflow
	var guard := 0
	while left > 0 and guard < 8:
		guard += 1
		if tech_designing == "":
			if not _open_overflow_design():
				return left
		var need := design_need(tech_designing)
		var room := need - tech_design_prog
		if room < 0:
			room = 0
		var use := mini(left, room)
		tech_design_prog += use
		left -= use
		if tech_design_prog >= need:
			if not _gain_blueprint(tech_designing):
				tech_design_prog = need
				return left
			var done: Dictionary = DataDB.tech_by_id.get(tech_designing, {})
			pending_blueprint = str(done.get("name", tech_designing))
			tech_designing = ""
			tech_design_prog = 0
	return left


func _open_overflow_design() -> bool:
	_pull_queue()
	if tech_designing != "":
		return true
	if tech_target != "":
		refill_target_queue("power")
		_pull_queue()
		if tech_designing != "":
			return true
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if tech_target_skip.has(id):
			continue
		if tech_state(id) == "available":
			if start_design(id, false):
				_announce_design("电满了，自动开始设计 %s（可以在格物图改）" % str(tech.get("name", id)))
				return true
			break
	return false


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
		var move := int(ut.get("move", 2))
		if int(u.get("move_mod", 0)) > 0:
			move = int(u.get("move_mod", move))
		if int(u.get("ford_wait", 0)) > 0:
			u["ford_wait"] = int(u.get("ford_wait", 0)) - 1
			u.mp = 0
			u.max_mp = move
		else:
			u.mp = move
			u.max_mp = move
		_garrison_heal(u)
		if u.has("undo"):
			u.erase("undo")
		if u.has("skip_turn"):
			u.erase("skip_turn")


func finish_turn() -> void:
	target_added = []
	target_notice = ""
	target_advisor = ""
	target_advisor_mood = ""
	target_advisor_id = ""
	turn += 1
	var date := Calendar.apply_turn(turn)
	year = date.x
	month = date.y
	month_span = date.z
	roll_weather()
	apply_power()
	_economy()
	_practice_tick()
	_research_tick()
	restore_movement()
	selected_uid = -1
	inspected_uid = -1


func announce_turn() -> bool:
	var lines: PackedStringArray = []
	for item_v in battle_lines:
		lines.append(str(item_v))
	battle_lines.clear()
	var blueprint := pending_blueprint
	pending_blueprint = ""
	var started := design_notice
	design_notice = ""
	var goal := target_notice
	target_notice = ""
	var goal_line := target_advisor
	var goal_mood := target_advisor_mood
	var goal_id := target_advisor_id
	target_advisor = ""
	target_advisor_mood = ""
	target_advisor_id = ""
	target_added = []
	var practice_ids: Array = pending_practice.duplicate()
	pending_practice = []
	var practice_notice := ""
	var practice_say := ""
	if not practice_ids.is_empty():
		practice_notice = "实践够了 · " + _practice_name_list(practice_ids)
		practice_say = _practice_ready_line(practice_ids)
	var era3_fresh: bool = era_unlocked(3) and not event_flags.has("era3_open")
	if era3_fresh:
		event_flags["era3_open"] = true
	var era3_say: bool = era3_fresh or (event_flags.has("era3_open") and not line_history.has("era3_open"))
	var nag: bool = _should_nag_research()
	if lines.is_empty() and blueprint == "" and started == "" and goal == "" and practice_notice == "" and not era3_fresh and not era3_say and not nag:
		return false
	var bits: PackedStringArray = []
	for line in lines:
		bits.append(line)
	if era3_fresh:
		bits.append("时代三 · 火器初兴 开了")
	if blueprint != "":
		bits.append("图纸已成 · %s" % blueprint)
	if started != "":
		bits.append(started)
	if goal != "":
		bits.append(goal)
	if practice_notice != "":
		bits.append(practice_notice)
	var nag_only: bool = nag and lines.is_empty() and blueprint == "" and started == "" and goal == "" and practice_notice == "" and not era3_say
	if nag_only:
		bits.append("电已满 · 选一份图纸")
	if not bits.is_empty():
		notice = "\n".join(bits)
	if not lines.is_empty() and blueprint == "":
		AdvisorSystem.present("城下打起来了。%s明细在上面。" % lines[0], "serious", "battle_brief")
		return true
	if not lines.is_empty() and blueprint != "":
		AdvisorSystem.present("城下打了 %d 场，%s 的图纸也画好了。明细在上面。" % [lines.size(), blueprint], "serious", "battle_brief")
		return true
	if era3_say:
		AdvisorSystem.present(_era3_open_line(), "smug", "era3_open")
		return true
	if blueprint != "":
		var ready := "图纸画好了：%s。去匠作院试制吧。" % blueprint
		if started != "":
			ready += started
		AdvisorSystem.present(ready, "smug", "blueprint_ready")
		return true
	if practice_say != "":
		AdvisorSystem.present(practice_say, "smug", "practice_ready")
		return true
	if started != "":
		AdvisorSystem.present(started, "serious", "design_auto")
		return true
	if goal != "":
		if goal_line != "":
			var mood := goal_mood if goal_mood != "" else "smug"
			AdvisorSystem.present(goal_line, mood, goal_id)
		return true
	if nag_only:
		research_idle_warned = true
		AdvisorSystem.present("电库存满了，图纸还空着。按 T 选一份，别让蓄电池干耗着。", "serious", "power_nag")
		return true
	return not bits.is_empty()


func _should_nag_research() -> bool:
	if research_idle_warned:
		return false
	if battery < battery_cap():
		return false
	if tech_designing != "":
		return false
	if not tech_queue.is_empty() or not tech_trials.is_empty() or not tech_blueprints.is_empty():
		return false
	return true


func research_blurb() -> Dictionary:
	var full := battery >= battery_cap()
	var slots := _research_slots()
	var base := {
		"design": str(slots.get("design", "")),
		"trial": str(slots.get("trial", "")),
		"design_alert": bool(slots.get("design_alert", false)),
		"design_prog": int(slots.get("design_prog", 0)),
		"design_need": int(slots.get("design_need", 1)),
		"trial_prog": int(slots.get("trial_prog", 0)),
		"trial_need": int(slots.get("trial_need", 1)),
		"design_bar": bool(slots.get("design_bar", false)),
		"trial_bar": bool(slots.get("trial_bar", false)),
	}
	if tech_designing != "":
		var state := tech_state(tech_designing)
		base["title"] = "停电" if state == "nopower" else "设计中"
		base["body"] = str(slots.get("design", ""))
		base["alert"] = state == "nopower"
		return base
	if not tech_trials.is_empty():
		base["title"] = "试制中"
		base["body"] = str(slots.get("trial", ""))
		base["alert"] = false
		return base
	if not tech_queue.is_empty():
		var tech_q: Dictionary = DataDB.tech_by_id.get(str(tech_queue[0]), {})
		base["title"] = "队列"
		base["body"] = str(tech_q.get("name", ""))
		base["alert"] = false
		return base
	if not tech_blueprints.is_empty():
		var id := str(tech_blueprints[0])
		var tech_b: Dictionary = DataDB.tech_by_id.get(id, {})
		var extra := ""
		if tech_blueprints.size() > 1:
			extra = " 等%d份" % tech_blueprints.size()
		var title := "电已满 · 图纸待试制" if full else "图纸待试制"
		base["title"] = title
		base["body"] = "%s%s · 去匠作院" % [str(tech_b.get("name", id)), extra]
		base["alert"] = true
		return base
	var idle_title := "电已满" if full else "格物"
	base["title"] = idle_title
	base["body"] = "选一份图纸 · 按 T"
	base["alert"] = true
	return base


func _research_slots() -> Dictionary:
	var design_line := "设计 空槽"
	var design_alert := false
	var dprog := 0
	var dneed := 1
	var design_bar := false
	if tech_designing != "":
		var tech: Dictionary = DataDB.tech_by_id.get(tech_designing, {})
		var need := design_need(tech_designing)
		var left := maxi(0, need - tech_design_prog)
		var eta := int(ceil(float(left) / 10.0))
		var state := tech_state(tech_designing)
		design_alert = state == "nopower"
		if design_alert:
			design_line = "设计 %s %d/%d · 停电" % [str(tech.get("name", tech_designing)), tech_design_prog, need]
		else:
			design_line = "设计 %s %d/%d · 约 %d 回合" % [str(tech.get("name", tech_designing)), tech_design_prog, need, eta]
		dprog = tech_design_prog
		dneed = maxi(1, need)
		design_bar = true
	var empty_slots := maxi(0, trial_slots() - tech_trials.size())
	var trial_line := "试制 空槽 · 空 %d 槽" % trial_slots()
	var tprog := 0
	var tneed := 1
	var trial_bar := false
	if not tech_trials.is_empty():
		var trial: Dictionary = tech_trials[0]
		var tech_t: Dictionary = DataDB.tech_by_id.get(str(trial.get("id", "")), {})
		tprog = int(trial.get("prog", 0))
		tneed = maxi(1, int(trial.get("need", 1)))
		trial_line = "试制 %s %d/%d · 空 %d 槽" % [str(tech_t.get("name", "")), tprog, tneed, empty_slots]
		trial_bar = true
	return {
		"design": design_line,
		"trial": trial_line,
		"design_alert": design_alert,
		"design_prog": dprog,
		"design_need": dneed,
		"trial_prog": tprog,
		"trial_need": tneed,
		"design_bar": design_bar,
		"trial_bar": trial_bar,
	}


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
	var song_pay := 0
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
		var pay := int(up.get("money", 0))
		if edicts_done.has("jingbing"):
			pay = int(round(float(pay) * 0.8))
		song_pay += pay
		money -= pay
	if edicts_done.has("hegu"):
		money = int(round(float(money) * 0.95))
	money -= subsidies.size() * 40
	money += markets.size() * 6
	if supply_left > 0:
		money += int(round(float(song_pay) * 0.2))
		supply_left -= 1
	if event_flags.has("zengbi_signed"):
		money -= int(meters.get("liao_demand", 0)) * 2
	if night_pay > 0:
		craft += night_pay
		night_pay = 0
	var next_food := int(resources.get("food", 0)) + food
	var mold_line := monthly_need() * 18
	if next_food > mold_line:
		var excess := next_food - mold_line
		var rot := int(excess * 3 / 100)
		if rot > 0:
			next_food -= rot
			if turn - mold_said >= 10:
				mold_said = turn
				AdvisorSystem.present("仓里压得太久，超额的陈粮霉了百分之三。", "serious", "mold")
	resources["food"] = max(0, next_food)
	grain_samples += 1
	if int(resources.get("food", 0)) <= monthly_need() * 12:
		grain_le12 += 1
	resources["money"] = max(0, int(resources.get("money", 0)) + money)
	resources["craft"] = max(0, int(resources.get("craft", 0)) + craft)
	last_event = "本月结算 粮%s 钱%s 匠%s 发电 %d" % [_signed(food), _signed(money), _signed(craft), last_gen]


func _signed(n: int) -> String:
	if n > 0:
		return "+%d" % n
	return str(n)


func monthly_food() -> int:
	var use := 0
	for u_v in units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		var up: Dictionary = DataDB.unit_type(str(u.get("def_id", ""))).get("upkeep", {})
		use += int(up.get("food", 0))
	if use < 1:
		use = 1
	return use


func monthly_need() -> int:
	return maxi(monthly_food(), _produce_floor())


func grain_warning() -> bool:
	return int(resources.get("food", 0)) > monthly_need() * 12


func _produce_floor() -> int:
	if produce_floor >= 0:
		return produce_floor
	var food := 0
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var cid := str(city.get("id", ""))
		var fac := str(city.get("faction", ""))
		if city_home.has(cid):
			fac = str(city_home[cid])
		if fac != "song":
			continue
		var output: Dictionary = city.get("output", {})
		food += int(output.get("food", 0))
	var net := food - 5
	if net < 1:
		net = food
	produce_floor = maxi(1, int(round(float(net) * 0.25)))
	return produce_floor


func can_sell_grain() -> bool:
	if grain_sold_turn == turn:
		return false
	if int(resources.get("food", 0)) < 300:
		return false
	return int(resources.get("food", 0)) > monthly_need() * 12


func sell_grain() -> bool:
	if grain_sold_turn == turn:
		notice = "这个月已经出粜过了。"
		EventBus.state_changed.emit()
		return false
	if not can_sell_grain():
		notice = "粮还没超过十二个月的用量。"
		EventBus.state_changed.emit()
		return false
	resources["food"] = int(resources.get("food", 0)) - 300
	resources["money"] = int(resources.get("money", 0)) + 120
	grain_sold_turn = turn
	notice = "常平仓出粜。粮 −300，钱 +120。"
	last_event = notice
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


func transfer_grain() -> bool:
	if int(resources.get("food", 0)) < 200:
		notice = "边粮要二百石，仓里不够。"
		EventBus.state_changed.emit()
		return false
	resources["food"] = int(resources.get("food", 0)) - 200
	supply_left = 3
	transfer_turn = turn
	notice = "边粮已发。前线军饷三个月减两成。"
	last_event = notice
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


func can_feast() -> bool:
	if int(resources.get("food", 0)) < 100:
		return false
	return not _wounded_song().is_empty()


func feast() -> bool:
	var unit := _wounded_song()
	if unit.is_empty() or int(resources.get("food", 0)) < 100:
		notice = "没有该犒的伤兵，或粮不够一百。"
		EventBus.state_changed.emit()
		return false
	resources["food"] = int(resources.get("food", 0)) - 100
	unit["hp"] = mini(100, int(unit.get("hp", 0)) + 20)
	feast_turn = turn
	notice = "%s 加了餐，生命恢复一些。" % str(unit.get("name", "部队"))
	last_event = notice
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


func _wounded_song() -> Dictionary:
	var best: Dictionary = {}
	var best_hp := 100
	for u_v in units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if int(u.get("hp", 100)) < best_hp:
			best_hp = int(u.get("hp", 100))
			best = u
	if best_hp >= 100:
		return {}
	return best


func spend_mp(uid: int, cost: int) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	u.mp = max(0, int(u.mp) - cost)
	if int(u.mp) <= 0:
		_note_mp_done(u)


func move_caption(unit: Dictionary) -> String:
	var mp := int(unit.get("mp", 0))
	var cap := int(unit.get("max_mp", mp))
	var walk := Pathfinder.budget(unit)
	if str(weather_id) == "snow" and mp > walk:
		return "移动 %d/%d · 雪天实走 %d" % [mp, cap, walk]
	if mp > 0:
		return "移动 %d/%d（这支部队本月还能走 %d 步）" % [mp, cap, walk]
	return "移动 %d/%d" % [mp, cap]


func _garrison_heal(unit: Dictionary) -> void:
	var attacked := bool(unit.get("attacked", false))
	if unit.has("attacked"):
		unit.erase("attacked")
	if attacked or int(unit.get("hp", 0)) <= 0:
		return
	var city := DataDB.city_at_hex(int(unit.get("q", 0)), int(unit.get("r", 0)))
	if city.is_empty():
		return
	if str(city.get("faction", "")) != str(unit.get("faction", "")):
		return
	unit.hp = mini(100, int(unit.get("hp", 0)) + 10)


func _note_mp_done(unit: Dictionary) -> void:
	if hint_mp_seen or unit.is_empty():
		return
	if str(unit.get("faction", "")) != "song" or int(unit.get("mp", 0)) > 0:
		return
	var other := ""
	for o_v in units:
		var o: Dictionary = o_v
		if int(o.get("uid", -1)) == int(unit.get("uid", -2)):
			continue
		if str(o.get("faction", "")) != "song" or int(o.get("hp", 0)) <= 0:
			continue
		if int(o.get("mp", 0)) <= 0 or bool(o.get("skip_turn", false)):
			continue
		other = str(o.get("name", ""))
		break
	if other == "":
		return
	hint_mp_seen = true
	AdvisorSystem.present("%s这个月走完了。%s的步数是自己的，还能走——按空格或点左下「可动」。" % [str(unit.get("name", "部队")), other], "serious", "hint_mp")


func set_pos(uid: int, h: Vector2i) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	var before := Vector2i(int(u.q), int(u.r))
	u.q = h.x
	u.r = h.y
	if str(u.get("tag", "")) != "wanglun":
		return
	if Pathfinder.huai(h.x, h.y) and not Pathfinder.huai(before.x, before.y):
		u.mp = 0
		u["ford_wait"] = 1


func fortify(uid: int) -> void:
	var u := unit_by_id(uid)
	if u.is_empty():
		return
	u.mp = 0
	_note_mp_done(u)
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
	atk["attacked"] = true
	_note_mp_done(atk)
	if atk.has("undo"):
		atk.erase("undo")
	var atk_name := str(atk.name)
	var def_name := str(dfd.name)
	var atk_dead := int(atk.hp) <= 0
	var def_dead := int(dfd.hp) <= 0
	_remove_dead()
	var counter := "不受反击" if bool(preview.ranged) else "攻方 -%d" % dmg.x
	var where := ""
	var city := DataDB.city_at_hex(int(dfd.q), int(dfd.r))
	if not city.is_empty():
		where = "%s：" % str(city.get("name", ""))
	var fallen := ""
	if def_dead and atk_dead:
		fallen = "双方阵亡。"
	elif def_dead:
		fallen = "守方阵亡。"
	elif atk_dead:
		fallen = "攻方阵亡。"
	var line := "%s%s 攻击 %s，守方 -%d，%s。%s" % [where, atk_name, def_name, dmg.y, counter, fallen]
	last_event = line
	battle_lines.append(line)
	if not input_locked:
		AdvisorSystem.present("城下交战。" + line, "serious")
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


func _reset_politics() -> void:
	relations = {
		"xia": -55,
		"liao": -15,
		"gusiluo": 15,
		"dali": 0,
		"goryeo": 5,
		"jiaozhi": 0,
		"uyghur": 0,
	}
	subsidies = []
	markets = []
	envoy_turn = {}
	event_choice = {}
	_reset_pacing()


func send_envoy(fid: String) -> bool:
	if int(resources.get("money", 0)) < 80:
		notice = "遣使要 80 钱"
		EventBus.state_changed.emit()
		return false
	if int(envoy_turn.get(fid, -99)) == turn:
		notice = "这个月已经派过使"
		EventBus.state_changed.emit()
		return false
	resources["money"] = int(resources.get("money", 0)) - 80
	relations[fid] = int(relations.get(fid, 0)) + 6
	envoy_turn[fid] = turn
	notice = "使节已出"
	last_event = notice
	EventBus.state_changed.emit()
	return true


func toggle_subsidy(fid: String) -> void:
	if subsidies.has(fid):
		subsidies.erase(fid)
		notice = "岁币停了"
	else:
		subsidies.append(fid)
		relations[fid] = int(relations.get(fid, 0)) + 8
		notice = "岁币记下了"
	last_event = notice
	EventBus.state_changed.emit()


func toggle_market(fid: String) -> void:
	if markets.has(fid):
		markets.erase(fid)
		notice = "榷场关了"
	else:
		markets.append(fid)
		notice = "榷场开了"
	last_event = notice
	EventBus.state_changed.emit()


func choose_event(event_id: String, choice_id: String) -> void:
	if event_choice.has(event_id):
		return
	var ev: Dictionary = DataDB.event_by_id.get(event_id, {})
	if ev.is_empty() or not EventSystem.available(ev):
		return
	var choice := {}
	for choice_v in ev.get("choices", []):
		var item: Dictionary = choice_v
		if str(item.get("id", "")) == choice_id:
			choice = item
	if choice.is_empty() or not EventSystem.choice_enabled(choice):
		return
	if not _afford_choice(event_id, choice_id):
		notice = "粮钱不够，这一条先办不了。"
		EventBus.state_changed.emit()
		return
	var lock := true
	if event_id == "wanglun" and choice_id == "blame" and not event_flags.has("wanglun_blame"):
		lock = false
	if event_id == "wangze" and choice_id == "relief" and not event_flags.has("wangze_relief"):
		lock = false
	if lock:
		event_choice[event_id] = choice_id
		if not event_log.has(event_id):
			event_log.append(event_id)
	pending_events.erase(event_id)
	morale += int(choice.get("morale", 0))
	var rel: Dictionary = choice.get("relation", {})
	for key_v in rel.keys():
		var key := str(key_v)
		relations[key] = int(relations.get(key, 0)) + int(rel[key_v])
	EventSystem.apply(ev, choice)
	Campaign.after_choice(event_id, choice_id)
	if int(choice.get("morale", 0)) <= -4 or _hurts_army(choice):
		recovery_until = maxi(recovery_until, turn + 10)
	notice = str(choice.get("result", "已记下"))
	if event_id == "wanglun" and (choice_id == "fight" or choice_id == "blame"):
		notice += "徐州厢军就近听调。"
	last_event = notice
	AdvisorSystem.say("event_post:%s:%s" % [event_id, choice_id])
	GoalSystem.touch()
	EventBus.state_changed.emit()


func recover_army() -> bool:
	if turn > recovery_until:
		return false
	if recovery_turn == turn:
		return false
	morale += 2
	recovery_turn = turn
	for u_v in units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if int(u.get("hp", 0)) < 100:
			u["hp"] = mini(100, int(u.get("hp", 0)) + 15)
	notice = "整军养伤。皇威 +2，伤兵恢复一些。"
	last_event = notice
	GoalSystem.touch()
	EventBus.state_changed.emit()
	return true


func _hurts_army(choice: Dictionary) -> bool:
	for effect_v in choice.get("effects", []):
		var effect: Dictionary = effect_v
		if str(effect.get("type", "")) == "hurt_named":
			return true
	return false


func _afford_choice(event_id: String, choice_id: String) -> bool:
	if choice_id != "amnesty" and choice_id != "relief":
		return true
	if event_id == "wangze" and choice_id == "relief":
		return int(resources.get("food", 0)) >= 400
	if choice_id == "amnesty" and (event_id == "wanglun" or event_id == "zhanghai"):
		return int(resources.get("food", 0)) >= 200 and int(resources.get("money", 0)) >= 200
	return true


func _release_cities() -> void:
	for id_v in city_home.keys():
		var city := DataDB.city_by_id(str(id_v))
		if city.is_empty():
			continue
		city["faction"] = str(city_home[id_v])
	city_home = {}


func _apply_seized() -> void:
	for id_v in city_home.keys():
		var city := DataDB.city_by_id(str(id_v))
		if city.is_empty():
			continue
		city["faction"] = "rebel"


func _reset_pacing() -> void:
	pending_events = []
	event_log = []
	event_flags = {}
	line_history = {}
	line_group_at = {}
	line_recent = []
	meters = {"xia_war": 70, "liao_demand": 20, "unrest": 0}
	report_hold = false
	report_unread = false
	last_report = ""
	GoalSystem.reset()
	AdvisorSystem.reset_rng()


func _reset_research() -> void:
	tech_done = []
	tech_queue = []
	tech_designing = ""
	tech_design_prog = 0
	tech_blueprints = []
	tech_trials = []
	tech_paused = {}
	tech_target = ""
	tech_target_skip = []
	target_notice = ""
	target_advisor = ""
	target_advisor_mood = ""
	target_advisor_id = ""
	target_added = []
	target_wait_noted = []
	tech_tutorial_done = false
	battle_lines = []
	pending_blueprint = ""
	research_idle_warned = false
	site_turns = {}
	practice_gate = PRACTICE_GATE
	city_buildings = {}
	practice_said = []
	pending_practice = []
	era3_flash_until = 0
	blueprint_bonus = 0
	firmware_done = []
	edicts_done = []
	notice = ""


func blueprint_cap() -> int:
	return mini(BLUEPRINT_CAP + blueprint_bonus, BLUEPRINT_CAP_MAX)


func battery_cap() -> int:
	var cap := int(DataDB.balance.get("power", {}).get("battery_max", 80))
	if tech_done.has("E04"):
		cap += 60
	if tech_done.has("E06"):
		cap += 150
	cap += battery_bonus
	return cap


func standby_cost() -> int:
	var standby := int(DataDB.balance.get("power", {}).get("standby", 4))
	if firmware_done.has("D01"):
		standby = 2
	return standby


func design_need(id: String) -> int:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var cost: Dictionary = tech.get("cost", {})
	var need := maxi(1, int(cost.get("power", 1)))
	if firmware_done.has("D03"):
		need = maxi(1, int(round(float(need) * 0.9)))
	if design_ease > 0:
		need = maxi(1, need - design_ease)
	return need


func era_unlocked(era: int) -> bool:
	if era <= 1:
		return true
	if era == 2:
		return turn > 30
	if era == 3:
		return Calendar.on_or_after(year, month, 1046, 3) or _era_done_count(2) >= 11
	return false


func _era_done_count(era: int) -> int:
	var n := 0
	for id_v in tech_done:
		var tech: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
		if int(tech.get("era", 0)) == era:
			n += 1
	return n


func prereqs_done(id: String) -> bool:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var pre: Array = tech.get("prereq", [])
	for pre_v in pre:
		if not tech_done.has(str(pre_v)):
			return false
	return true


func tech_state(id: String) -> String:
	if tech_done.has(id):
		return "done"
	for trial_v in tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) == id:
			return "trial"
	if tech_blueprints.has(id):
		return "blueprint"
	if tech_designing == id:
		if battery <= 0 and tech_design_prog < design_need(id):
			return "nopower"
		return "designing"
	if tech_queue.has(id):
		return "queued"
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if not era_unlocked(int(tech.get("era", 1))):
		return "locked"
	var pre: Array = tech.get("prereq", [])
	for pre_v in pre:
		if not tech_done.has(str(pre_v)):
			return "noprereq"
	return "available"


func trial_slots() -> int:
	if edicts_done.has("gewuyuan"):
		return 2
	return 1


func start_design(id: String, manual: bool = true) -> bool:
	var st := tech_state(id)
	if st != "available" and st != "queued":
		return false
	tech_queue.erase(id)
	if manual:
		tech_target_skip.erase(id)
	research_idle_warned = false
	if tech_designing == "":
		tech_designing = id
		tech_design_prog = int(tech_paused.get(id, 0))
		tech_paused.erase(id)
		if presearch > 0:
			tech_design_prog += presearch
			presearch = 0
		if design_ease > 0:
			tech_design_prog += design_ease
			design_ease = 0
	elif id != tech_designing:
		if not _enqueue(id):
			EventBus.state_changed.emit()
			return false
	EventBus.state_changed.emit()
	return true


func swap_design(id: String) -> bool:
	if tech_designing == "" or id == tech_designing:
		return false
	var st := tech_state(id)
	if st != "available" and st != "queued":
		return false
	var old := tech_designing
	var kept := tech_design_prog
	tech_queue.erase(id)
	tech_paused[old] = kept
	tech_designing = ""
	tech_design_prog = 0
	tech_queue.insert(0, old)
	while tech_queue.size() > QUEUE_CAP:
		tech_queue.pop_back()
	return start_design(id)


func bump_queue(id: String) -> void:
	var at := tech_queue.find(id)
	if int(at) <= 0:
		return
	var prev = tech_queue[at - 1]
	tech_queue[at - 1] = tech_queue[at]
	tech_queue[at] = prev
	EventBus.state_changed.emit()


func _enqueue(id: String) -> bool:
	if id == "" or id == tech_designing or tech_queue.has(id):
		return false
	if tech_queue.size() >= QUEUE_CAP:
		notice = "队列已满 3/3"
		return false
	tech_queue.append(id)
	return true


func refill_target_queue(reason: String) -> Array:
	var added: Array = []
	if tech_target == "":
		return added
	if not DataDB.tech_by_id.has(tech_target):
		tech_target = ""
		tech_target_skip = []
		return added
	if tech_done.has(tech_target):
		tech_target = ""
		tech_target_skip = []
		return added
	var ready: Array = []
	_collect_target_ready(tech_target, ready, {})
	_prepare_target_sort()
	ready.sort_custom(Callable(self, "_target_before"))
	var waiting: Array = []
	for id_v in ready:
		var nid := str(id_v)
		if nid == tech_designing or tech_queue.has(nid):
			continue
		if tech_queue.size() >= QUEUE_CAP:
			waiting.append(nid)
			continue
		tech_queue.append(nid)
		added.append(nid)
		target_wait_noted.erase(nid)
		if not target_added.has(nid):
			target_added.append(nid)
	if not added.is_empty():
		research_ping_until = Time.get_ticks_msec() + 1600
	_write_target_notice(reason, waiting, added)
	return added


func target_waiting() -> Array:
	var out: Array = []
	if tech_target == "" or tech_queue.size() < QUEUE_CAP:
		return out
	var ready: Array = []
	_collect_target_ready(tech_target, ready, {})
	for id_v in ready:
		var nid := str(id_v)
		if nid == tech_designing or tech_queue.has(nid):
			continue
		out.append(nid)
	return out


func _collect_target_ready(id: String, into: Array, seen: Dictionary) -> void:
	if id == "" or seen.has(id):
		return
	seen[id] = true
	if tech_done.has(id) or tech_blueprints.has(id):
		return
	if _is_trialing(id) or tech_designing == id:
		return
	if TechPlan.view_state(id) == "available":
		if not tech_target_skip.has(id) and not tech_queue.has(id):
			into.append(id)
		return
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		_collect_target_ready(str(pre_v), into, seen)


func _prepare_target_sort() -> void:
	_sort_spine = TechPlan.spine(tech_target)
	_sort_index = {}
	var index := 0
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		_sort_index[str(tech.get("id", ""))] = index
		index += 1


func _target_before(a: String, b: String) -> bool:
	var power_a := design_need(a)
	var power_b := design_need(b)
	if power_a != power_b:
		return power_a < power_b
	var spine_a := _spine_pos(a)
	var spine_b := _spine_pos(b)
	if spine_a != spine_b:
		return spine_a < spine_b
	return _data_pos(a) < _data_pos(b)


func _spine_pos(id: String) -> int:
	var at := _sort_spine.find(id)
	if int(at) < 0:
		return 999
	return int(at)


func _data_pos(id: String) -> int:
	return int(_sort_index.get(id, 9999))


func _write_target_notice(reason: String, waiting: Array, added_now: Array) -> void:
	if not added_now.is_empty():
		var names := _tech_list(target_added)
		var line := "目标路线 · %s 进队列（%d/%d）" % [names, tech_queue.size(), QUEUE_CAP]
		notice = line
		if reason == "set":
			target_notice = ""
			target_advisor = ""
			target_added = []
			return
		target_notice = line
		var target_tech: Dictionary = DataDB.tech_by_id.get(tech_target, {})
		var target_name := str(target_tech.get("name", tech_target))
		if target_added.size() == 1:
			target_advisor = "%s的前置齐了，我顺手排进了设计队列。离%s又近一步。" % [names, target_name]
		else:
			target_advisor = "前置一下子齐了两份，我都排上了。电够的话，下个月就开画。"
		target_advisor_mood = "smug"
		target_advisor_id = "target_queue"
		return
	if not target_added.is_empty():
		return
	var fresh: Array = []
	for id_v in waiting:
		var wid := str(id_v)
		if not target_wait_noted.has(wid):
			fresh.append(wid)
	if fresh.is_empty():
		return
	for id_v in fresh:
		target_wait_noted.append(str(id_v))
	var wait_names := _tech_list(fresh)
	var wait_line := "目标路线 · %s 等队列空位（%d/%d）" % [wait_names, QUEUE_CAP, QUEUE_CAP]
	notice = wait_line
	if reason == "set":
		target_notice = ""
		target_advisor = ""
		return
	target_notice = wait_line
	target_advisor = "队列塞满了，%s先在门口排着。哪份画完，我就把它塞进去。" % wait_names
	target_advisor_mood = "serious"
	target_advisor_id = "target_wait"


func _tech_list(ids: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for id_v in ids:
		var tech: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
		parts.append(str(tech.get("name", str(id_v))))
	return "、".join(parts)


func _skip_target(id: String) -> void:
	if id == "" or tech_target_skip.has(id):
		return
	if not _on_target_route(id):
		return
	tech_target_skip.append(id)


func _on_target_route(id: String) -> bool:
	if tech_target == "" or id == "":
		return false
	if id == tech_target:
		return true
	return _route_has(tech_target, id, {})


func _route_has(cur: String, want: String, seen: Dictionary) -> bool:
	if seen.has(cur):
		return false
	seen[cur] = true
	var tech: Dictionary = DataDB.tech_by_id.get(cur, {})
	for pre_v in tech.get("prereq", []):
		var pre := str(pre_v)
		if pre == want or _route_has(pre, want, seen):
			return true
	return false


func _gain_blueprint(id: String) -> bool:
	if id == "" or tech_blueprints.has(id):
		return id != ""
	if tech_blueprints.size() >= blueprint_cap():
		notice = "图纸库已满 %d/%d，先去试制" % [blueprint_cap(), blueprint_cap()]
		EventBus.state_changed.emit()
		return false
	tech_blueprints.append(id)
	return true


func _announce_design(text: String) -> void:
	design_notice = text
	notice = text
	research_ping_until = Time.get_ticks_msec() + 1600
	EventBus.state_changed.emit()


func cancel_design() -> void:
	pause_design()


func pause_design() -> void:
	if tech_designing == "":
		return
	_skip_target(tech_designing)
	tech_paused[tech_designing] = tech_design_prog
	tech_designing = ""
	tech_design_prog = 0
	_pull_queue()
	EventBus.state_changed.emit()


func remove_queued(id: String) -> void:
	if tech_queue.has(id):
		_skip_target(id)
	tech_queue.erase(id)
	EventBus.state_changed.emit()


func start_trial(id: String) -> bool:
	if tech_state(id) != "blueprint":
		return false
	if tech_trials.size() >= trial_slots():
		notice = "试制槽已满"
		EventBus.state_changed.emit()
		return false
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var practice_short: bool = not practice_ok(id)
	if practice_short and practice_gate:
		var blocked_have := practice_have(id)
		var blocked_need := practice_need(id)
		var blocked_name := str(PRACTICE_NAME.get(practice_site(id), "实践"))
		_remind_practice_short(id, blocked_name, maxi(0, blocked_need - blocked_have))
		notice = "实践不够 · %s %d/%d" % [blocked_name, blocked_have, blocked_need]
		EventBus.state_changed.emit()
		return false
	if not _pay_trial(tech):
		notice = "匠或材料不够"
		EventBus.state_changed.emit()
		return false
	if practice_short:
		var short_have := practice_have(id)
		var short_need := practice_need(id)
		var short_name := str(PRACTICE_NAME.get(practice_site(id), "实践"))
		_remind_practice_short(id, short_name, maxi(0, short_need - short_have))
	tech_blueprints.erase(id)
	var cost: Dictionary = tech.get("cost", {})
	var craft := int(cost.get("craft", 8))
	var need := maxi(2, int(ceil(float(craft) / 12.0)))
	tech_trials.append({"id": id, "prog": 0, "need": need})
	notice = "开试制 · %s" % str(tech.get("name", id))
	EventBus.state_changed.emit()
	return true


func _pay_trial(tech: Dictionary) -> bool:
	var cost: Dictionary = tech.get("cost", {})
	var craft := int(cost.get("craft", 0))
	if int(resources.get("craft", 0)) < craft:
		return false
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		var key := str(key_v)
		if int(resources.get(key, 0)) < int(mats[key_v]):
			return false
	resources["craft"] = int(resources.get("craft", 0)) - craft
	for key_v in mats.keys():
		var key := str(key_v)
		resources[key] = int(resources.get(key, 0)) - int(mats[key_v])
	return true


func write_firmware(id: String) -> bool:
	if firmware_done.has(id):
		return false
	var fw: Dictionary = DataDB.firmware_by_id.get(id, {})
	if fw.is_empty():
		return false
	var pre := str(fw.get("prereq", ""))
	if pre != "" and not firmware_done.has(pre):
		return false
	var cost := int(fw.get("power", 0))
	if battery < cost:
		notice = "电不够，写不进固件"
		EventBus.state_changed.emit()
		return false
	battery -= cost
	firmware_done.append(id)
	notice = "固件已写入 · %s" % str(fw.get("name", id))
	last_event = notice
	EventBus.state_changed.emit()
	return true


func edict_block(edict: Dictionary) -> String:
	var id := str(edict.get("id", ""))
	if edicts_done.has(id):
		return "已颁布"
	if id == "jingbing" and morale < 50:
		return "需要皇威 50"
	if id == "huangcheng" and not firmware_done.has("D02"):
		return "需要固件「敌情推演」"
	if id == "fangtian" and not tech_done.has("C01"):
		return "需要算学"
	if id == "baojia" and (not tech_done.has("C01") or not edicts_done.has("jingbing")):
		return "需要算学，并先颁布精兵简政"
	if id == "hegu" and not tech_done.has("C01"):
		return "需要算学"
	if id == "jiangyi" and not tech_done.has("K04"):
		return "需要标准件与量规"
	if id == "gewuyuan" and not tech_done.has("C03"):
		return "需要活字与交子"
	if id == "huoqi" and not (tech_done.has("M06") or tech_done.has("M07") or tech_done.has("M08")):
		return "需要一件火器"
	var cost: Dictionary = edict.get("cost", {})
	if morale < int(cost.get("morale", 0)):
		return "皇威不足"
	if int(resources.get("money", 0)) < int(cost.get("money", 0)):
		return "钱不足"
	return ""


func enact_edict(id: String) -> bool:
	var edict: Dictionary = DataDB.edict_by_id.get(id, {})
	if edict.is_empty():
		return false
	if edict_block(edict) != "":
		return false
	var cost: Dictionary = edict.get("cost", {})
	morale -= int(cost.get("morale", 0))
	resources["money"] = int(resources.get("money", 0)) - int(cost.get("money", 0))
	edicts_done.append(id)
	notice = "颁布 · %s" % str(edict.get("name", id))
	last_event = notice
	EventBus.state_changed.emit()
	return true


func _research_tick() -> void:
	if tech_designing != "":
		var id := tech_designing
		var need := design_need(id)
		var room := need - tech_design_prog
		var spend := mini(mini(10, room), battery)
		if spend > 0:
			battery -= spend
			tech_design_prog += spend
		if tech_design_prog >= need:
			if not _gain_blueprint(id):
				tech_design_prog = need
			else:
				var tech: Dictionary = DataDB.tech_by_id.get(id, {})
				pending_blueprint = str(tech.get("name", id))
				notice = "图纸已成 · %s" % pending_blueprint
				last_event = notice
				tech_designing = ""
				tech_design_prog = 0
				_pull_queue()
	var finished: Array[String] = []
	for trial_v in tech_trials:
		var trial: Dictionary = trial_v
		trial["prog"] = int(trial.get("prog", 0)) + 1
		if int(trial["prog"]) >= int(trial.get("need", 1)):
			finished.append(str(trial.get("id", "")))
	for fid in finished:
		_complete_tech(fid)
		_erase_trial(fid)
	refill_target_queue("turn")
	if tech_designing == "":
		_pull_queue()


func _pull_queue() -> void:
	if tech_designing != "":
		return
	var i := 0
	while i < tech_queue.size():
		var nxt := str(tech_queue[i])
		if tech_done.has(nxt) or tech_blueprints.has(nxt) or _is_trialing(nxt):
			tech_queue.remove_at(i)
			continue
		if prereqs_done(nxt):
			tech_queue.remove_at(i)
			tech_designing = nxt
			tech_design_prog = int(tech_paused.get(nxt, 0))
			tech_paused.erase(nxt)
			var tech: Dictionary = DataDB.tech_by_id.get(nxt, {})
			_announce_design("开始设计 %s" % str(tech.get("name", nxt)))
			return
		i += 1


func _is_trialing(id: String) -> bool:
	for trial_v in tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) == id:
			return true
	return false


func _complete_tech(id: String) -> void:
	if tech_done.has(id):
		return
	tech_done.append(id)
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var name := str(tech.get("name", id))
	notice = "已经推广 · %s" % name
	last_event = "%s %s" % [notice, str(tech.get("effect", ""))]
	if id != tech_target:
		return
	tech_target = ""
	tech_target_skip = []
	target_added = []
	target_wait_noted = []
	target_notice = "目标达成 · %s" % name
	target_advisor = "%s推广了。目标我先撤了，下一个想冲哪个？" % name
	target_advisor_mood = "smug"
	target_advisor_id = "target_done"
	notice = target_notice


func _erase_trial(id: String) -> void:
	var keep: Array = []
	for trial_v in tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) != id:
			keep.append(trial)
	tech_trials = keep


func _int_dict(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw
	for key_v in src.keys():
		out[str(key_v)] = int(src[key_v])
	return out


func _str_dict(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw
	for key_v in src.keys():
		out[str(key_v)] = str(src[key_v])
	return out


func _str_list(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item_v in raw:
		out.append(str(item_v))
	return out


func _flag_dict(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw
	for key_v in src.keys():
		out[str(key_v)] = true
	return out


func _recent_list(raw) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for item_v in raw:
		if typeof(item_v) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = item_v
		out.append({
			"id": str(item.get("id", "")),
			"cat": str(item.get("cat", "")),
			"turn": int(item.get("turn", 0)),
		})
	return out


func arm_era3_flash() -> bool:
	if not era_unlocked(3) or event_flags.has("era3_tree_seen"):
		return false
	event_flags["era3_tree_seen"] = true
	era3_flash_until = Time.get_ticks_msec() + 1600
	return true


func _era3_open_line() -> String:
	var early: bool = _era_done_count(2) >= 11 and not Calendar.on_or_after(year, month, 1046, 3)
	if early:
		return "时代二做满十一项，格物图提前翻到第三卷「火器初兴」。坩埚炼钢、燧发机构都能画了。陛下，工匠们的眉毛，这回怕是真保不住了。"
	return "庆历六年春，格物图翻到第三卷「火器初兴」。坩埚炼钢、燧发机构都能画了。陛下，工匠们的眉毛，这回怕是真保不住了。"


func _quiet_era3() -> void:
	if not era_unlocked(3) or event_flags.has("era3_open"):
		return
	event_flags["era3_open"] = true
	event_flags["era3_tree_seen"] = true
	line_history["era3_open"] = turn


func practice_building(bid: String) -> bool:
	return PRACTICE_SITE.has(bid) or bid == "ironworks"


func practice_key_of(city_id: String, bid: String) -> String:
	if PRACTICE_SITE.has(bid):
		return str(PRACTICE_SITE[bid])
	if bid == "ironworks" and tech_done.has("K02") and _city_has_river(city_id):
		return "mill"
	return ""


func practice_site(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var site := str(tech.get("practice_site", ""))
	if site != "":
		return site
	var label := str(tech.get("practice", ""))
	if label == "":
		return ""
	return TechPlan._site_key(label)


func practice_talent_scale(_id: String) -> float:
	return 1.0


func practice_need(id: String) -> int:
	var base := _practice_base(id)
	if base <= 0:
		return 0
	var scale := 1.0
	if edicts_done.has("jiangyi"):
		scale *= 0.75
	scale *= practice_talent_scale(id)
	return maxi(1, int(ceil(float(base) * scale)))


func practice_have(id: String) -> int:
	var site := practice_site(id)
	if site == "":
		return 0
	return int(site_turns.get(site, 0))


func practice_ok(id: String) -> bool:
	if practice_site(id) == "":
		return true
	return practice_have(id) >= practice_need(id)


func practice_city(id: String) -> String:
	var bid := str(PRACTICE_BUILDING.get(practice_site(id), ""))
	if bid == "":
		return "kaifeng"
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		var cid := str(city.get("id", ""))
		if can_build(cid, bid) == "":
			return cid
	return "kaifeng"


func practice_tech_line(key: String) -> String:
	var parts := PackedStringArray()
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if practice_site(id) != key:
			continue
		parts.append("%s %d/%d" % [str(tech.get("name", id)), practice_have(id), practice_need(id)])
	return "、".join(parts)


func practice_count_text(city_id: String, bid: String) -> String:
	var key := practice_key_of(city_id, bid)
	if key == "" and bid == "ironworks":
		if not tech_done.has("K02"):
			return "推广水力鼓风后计入水磨"
		return "需河畔才计入水磨"
	if key == "":
		return ""
	var have := int(site_turns.get(key, 0))
	return "计入：%s %d · %s" % [str(PRACTICE_NAME.get(key, key)), have, practice_tech_line(key)]


func can_build(city_id: String, bid: String) -> String:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty() or str(city.get("faction", "")) != "song":
		return "非宋城"
	var spec := _building_spec(bid)
	if spec.is_empty():
		return "未开放"
	if not building_unlocked(spec):
		return building_lock_text(spec)
	if _city_has_building(city_id, bid):
		return "已建"
	if bid == "watermill" and not _city_has_river(city_id):
		return "需河畔"
	if bid == "coalpit" and not _near_feature(city, "coal"):
		return "需煤矿"
	if bid == "ironworks" and not _near_feature(city, "iron"):
		return "需铁矿"
	if bid == "steampump" and not _near_feature(city, "coal") and not _near_feature(city, "iron"):
		return "需煤矿"
	var cost: Dictionary = spec.get("cost", {})
	if int(resources.get("money", 0)) < int(cost.get("money", 0)):
		return "缺钱"
	if int(resources.get("craft", 0)) < int(cost.get("craft", 0)):
		return "缺匠"
	return ""


func build_label(city_id: String, bid: String) -> String:
	var why := can_build(city_id, bid)
	if why != "":
		return why
	var spec := _building_spec(bid)
	var cost: Dictionary = spec.get("cost", {})
	return "建造（钱 %d · 匠 %d）" % [int(cost.get("money", 0)), int(cost.get("craft", 0))]


func build(city_id: String, bid: String) -> bool:
	if can_build(city_id, bid) != "":
		return false
	var spec := _building_spec(bid)
	var cost: Dictionary = spec.get("cost", {})
	resources["money"] = int(resources.get("money", 0)) - int(cost.get("money", 0))
	resources["craft"] = int(resources.get("craft", 0)) - int(cost.get("craft", 0))
	if not city_buildings.has(city_id):
		city_buildings[city_id] = []
	var built: Array = city_buildings[city_id]
	built.append(bid)
	city_buildings[city_id] = built
	var city := DataDB.city_by_id(city_id)
	var place := str(city.get("short", city.get("name", city_id)))
	notice = "已建 · %s（%s）" % [str(spec.get("name", bid)), place]
	EventBus.state_changed.emit()
	return true


func building_lock_text(spec: Dictionary) -> String:
	var unlock := str(spec.get("unlock", ""))
	if unlock.begins_with("edict_"):
		return "待政令"
	var tech: Dictionary = DataDB.tech_by_id.get(unlock, {})
	if tech.is_empty():
		return "未开放"
	return "待 " + str(tech.get("name", unlock))


func _practice_tick() -> void:
	var before := _practice_ok_set()
	var gain := {}
	for city_id_v in city_buildings.keys():
		var city_id := str(city_id_v)
		var city := DataDB.city_by_id(city_id)
		if str(city.get("faction", "")) != "song":
			continue
		var built: Array = city_buildings[city_id_v]
		for bid_v in built:
			var key := practice_key_of(city_id, str(bid_v))
			if key == "":
				continue
			gain[key] = int(gain.get(key, 0)) + 1
	for key_v in gain.keys():
		var key := str(key_v)
		var add := mini(int(gain[key_v]), PRACTICE_PER_TURN_CAP)
		site_turns[key] = int(site_turns.get(key, 0)) + add
	for id_v in _practice_ok_set().keys():
		var id := str(id_v)
		if before.has(id) or practice_said.has(id):
			continue
		practice_said.append(id)
		pending_practice.append(id)


func _practice_ok_set() -> Dictionary:
	var out := {}
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if practice_site(id) == "":
			continue
		if tech_done.has(id):
			continue
		if practice_ok(id):
			out[id] = true
	return out


func _practice_base(id: String) -> int:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if tech.has("practice_need"):
		return int(tech.get("practice_need", 0))
	var label := str(tech.get("practice", ""))
	var digits := ""
	for i in label.length():
		var ch := label.substr(i, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	if digits == "":
		return 0
	return int(digits)


func _practice_name_list(ids: Array) -> String:
	var parts := PackedStringArray()
	for id_v in ids:
		var id := str(id_v)
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		parts.append(str(tech.get("name", id)))
	return "、".join(parts)


func _practice_ready_line(ids: Array) -> String:
	if ids.size() >= 2:
		return "两份门槛同时过了：%s。匠作院今天会很热闹。" % _practice_name_list(ids)
	var id := str(ids[0])
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var site_name := str(PRACTICE_NAME.get(practice_site(id), "门槛"))
	return "%s跑够了，师傅们手上有了数。「%s」的实践这关过了，图纸一到就能开槽。" % [site_name, str(tech.get("name", id))]


func _remind_practice_short(id: String, site_name: String, left: int) -> void:
	var key := "practice_short_%s" % id
	if line_history.has(key) and turn - int(line_history[key]) < 5:
		return
	AdvisorSystem.present("图纸是我画的，炉子得他们自己烧。%s还差 %d 回合。" % [site_name, left], "serious", key)


func _city_has_building(city_id: String, bid: String) -> bool:
	if not city_buildings.has(city_id):
		return false
	var built: Array = city_buildings[city_id]
	return built.has(bid)


func _building_spec(bid: String) -> Dictionary:
	for spec_v in DataDB.buildings:
		var spec: Dictionary = spec_v
		if str(spec.get("id", "")) == bid:
			return spec
	return {}


func _city_has_river(city_id: String) -> bool:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		return false
	var masks: Array = DataDB.river_masks.get(Vector2i(int(city.get("q", 0)), int(city.get("r", 0))), [])
	if masks.size() < 2:
		return false
	return int(masks[0]) != 0 or int(masks[1]) != 0


func _near_feature(city: Dictionary, feat_id: String) -> bool:
	var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
	for hex_v in DataDB.feature_hexes.keys():
		var feat: Dictionary = DataDB.feature_hexes[hex_v]
		if str(feat.get("id", "")) != feat_id:
			continue
		if HexGrid.distance(origin, hex_v) <= 2:
			return true
	return false


func _building_map(raw) -> Dictionary:
	var out := {}
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var src: Dictionary = raw
	for key_v in src.keys():
		var ids: Array = []
		var list = src[key_v]
		if typeof(list) == TYPE_ARRAY:
			for item_v in list:
				ids.append(str(item_v))
		out[str(key_v)] = ids
	return out


func building_unlocked(spec: Dictionary) -> bool:
	var unlock := str(spec.get("unlock", "start"))
	if unlock == "" or unlock == "start":
		return true
	if unlock.begins_with("edict_"):
		return edicts_done.has(unlock.trim_prefix("edict_"))
	return tech_done.has(unlock)


func to_save() -> Dictionary:
	return {
		"save_version": 1,
		"year": year,
		"month": month,
		"month_span": month_span,
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
		"tech_done": tech_done.duplicate(),
		"tech_queue": tech_queue.duplicate(),
		"tech_designing": tech_designing,
		"tech_design_prog": tech_design_prog,
		"tech_blueprints": tech_blueprints.duplicate(),
		"tech_trials": tech_trials.duplicate(true),
		"tech_paused": tech_paused.duplicate(),
		"tech_target": tech_target,
		"tech_target_skip": tech_target_skip.duplicate(),
		"tech_tutorial_done": tech_tutorial_done,
		"tutorial_done": tutorial_done,
		"hint_menu_seen": hint_menu_seen,
		"hint_enemy_menu_seen": hint_enemy_menu_seen,
		"hint_blocked_seen": hint_blocked_seen,
		"hint_mp_seen": hint_mp_seen,
		"end_warn_off": end_warn_off,
		"research_idle_warned": research_idle_warned,
		"site_turns": site_turns.duplicate(),
		"city_buildings": city_buildings.duplicate(true),
		"practice_said": practice_said.duplicate(),
		"firmware_done": firmware_done.duplicate(),
		"edicts_done": edicts_done.duplicate(),
		"relations": relations.duplicate(),
		"subsidies": subsidies.duplicate(),
		"markets": markets.duplicate(),
		"envoy_turn": envoy_turn.duplicate(),
		"event_choice": event_choice.duplicate(),
		"pending_events": pending_events.duplicate(),
		"event_log": event_log.duplicate(),
		"event_flags": event_flags.duplicate(),
		"line_history": line_history.duplicate(),
		"line_group_at": line_group_at.duplicate(),
		"line_recent": line_recent.duplicate(true),
		"meters": meters.duplicate(),
		"report_unread": report_unread,
		"last_report": last_report,
		"orders": orders.duplicate(true),
		"order_seen": order_seen.duplicate(),
		"card_queue": card_queue.duplicate(),
		"chapter_shown": chapter_shown.duplicate(),
		"chapter_rewarded": chapter_rewarded.duplicate(),
		"battery_bonus": battery_bonus,
		"blueprint_bonus": blueprint_bonus,
		"presearch": presearch,
		"supply_left": supply_left,
		"grain_sold_turn": grain_sold_turn,
		"transfer_turn": transfer_turn,
		"feast_turn": feast_turn,
		"bargain_round": bargain_round,
		"bargain_used": bargain_used.duplicate(),
		"bargain_west": bargain_west,
		"order_place": order_place.duplicate(),
		"rest_streak": rest_streak,
		"campaign": campaign.duplicate(true),
		"shelved": shelved.duplicate(true),
		"power_made": power_made,
		"power_waste": power_waste,
		"power_over": power_over,
		"power_sunk": power_sunk,
		"grain_samples": grain_samples,
		"grain_le12": grain_le12,
		"epilogue_shown": epilogue_shown,
		"rating_floor": rating_floor,
		"recovery_until": recovery_until,
		"recovery_turn": recovery_turn,
		"demo_over": demo_over,
		"presearch_bonus": presearch_bonus,
		"shading": shading,
		"shade_skip": shade_skip,
		"night_read": night_read,
		"night_pay": night_pay,
		"design_ease": design_ease,
		"jingnei_mod": jingnei_mod,
		"city_home": city_home.duplicate(),
		"mold_said": mold_said,
		"presearch_full_said": presearch_full_said,
		"food_start": food_start,
	}


func from_save(data: Dictionary) -> bool:
	if int(data.get("save_version", 0)) != 1:
		return false
	_reset_research()
	_reset_politics()
	turn = int(data.get("turn", 1))
	var date := Calendar.apply_turn(turn)
	year = date.x
	month = date.y
	month_span = date.z
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
		var row := {
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
		}
		var snap: Dictionary = src.get("undo", {})
		if not snap.is_empty():
			row["undo"] = {"q": int(snap.get("q", 0)), "r": int(snap.get("r", 0)), "mp": int(snap.get("mp", 0))}
		if bool(src.get("skip_turn", false)):
			row["skip_turn"] = true
		if str(src.get("tag", "")) != "":
			row["tag"] = str(src.get("tag", ""))
		if str(src.get("march", "")) != "":
			row["march"] = str(src.get("march", ""))
		if int(src.get("born", 0)) > 0:
			row["born"] = int(src.get("born", 0))
		if int(src.get("move_mod", 0)) > 0:
			row["move_mod"] = int(src.get("move_mod", 0))
		if int(src.get("ford_wait", 0)) > 0:
			row["ford_wait"] = int(src.get("ford_wait", 0))
		if bool(src.get("attacked", false)):
			row["attacked"] = true
		units.append(row)
	rng.state = int(str(data.get("rng_state", "0")))
	tech_done = _str_list(data.get("tech_done", []))
	tech_queue = _str_list(data.get("tech_queue", []))
	tech_designing = str(data.get("tech_designing", ""))
	tech_design_prog = int(data.get("tech_design_prog", 0))
	tech_blueprints = _str_list(data.get("tech_blueprints", []))
	firmware_done = _str_list(data.get("firmware_done", []))
	edicts_done = _str_list(data.get("edicts_done", []))
	relations = _int_dict(data.get("relations", relations))
	subsidies = _str_list(data.get("subsidies", []))
	markets = _str_list(data.get("markets", []))
	envoy_turn = _int_dict(data.get("envoy_turn", {}))
	event_choice = _str_dict(data.get("event_choice", {}))
	pending_events = _str_list(data.get("pending_events", []))
	event_log = _str_list(data.get("event_log", []))
	event_flags = _flag_dict(data.get("event_flags", {}))
	line_history = _int_dict(data.get("line_history", {}))
	line_group_at = _int_dict(data.get("line_group_at", {}))
	line_recent = _recent_list(data.get("line_recent", []))
	meters = {"xia_war": 70, "liao_demand": 20, "unrest": 0}
	var raw_meters: Dictionary = data.get("meters", {})
	for mid_v in meters.keys():
		var mid := str(mid_v)
		if raw_meters.has(mid):
			meters[mid] = int(raw_meters[mid])
	report_unread = bool(data.get("report_unread", false))
	last_report = str(data.get("last_report", ""))
	report_hold = false
	tech_paused = _int_dict(data.get("tech_paused", {}))
	tech_target = str(data.get("tech_target", ""))
	tech_target_skip = _str_list(data.get("tech_target_skip", []))
	target_notice = ""
	target_advisor = ""
	target_advisor_mood = ""
	target_advisor_id = ""
	target_added = []
	target_wait_noted = []
	if tech_target != "" and not DataDB.tech_by_id.has(tech_target):
		tech_target = ""
		tech_target_skip = []
	tech_tutorial_done = bool(data.get("tech_tutorial_done", false))
	tutorial_done = bool(data.get("tutorial_done", false))
	hint_menu_seen = bool(data.get("hint_menu_seen", false))
	hint_enemy_menu_seen = bool(data.get("hint_enemy_menu_seen", false))
	hint_blocked_seen = bool(data.get("hint_blocked_seen", false))
	hint_mp_seen = bool(data.get("hint_mp_seen", false))
	end_warn_off = bool(data.get("end_warn_off", false))
	design_notice = ""
	research_ping_until = 0
	research_idle_warned = bool(data.get("research_idle_warned", false))
	battle_lines = []
	pending_blueprint = ""
	site_turns = _int_dict(data.get("site_turns", {}))
	city_buildings = _building_map(data.get("city_buildings", {}))
	practice_said = _str_list(data.get("practice_said", []))
	pending_practice = []
	tech_trials = []
	for trial_v in data.get("tech_trials", []):
		if typeof(trial_v) != TYPE_DICTIONARY:
			continue
		var trial: Dictionary = trial_v
		tech_trials.append({
			"id": str(trial.get("id", "")),
			"prog": int(trial.get("prog", 0)),
			"need": int(trial.get("need", 1)),
		})
	selected_uid = -1
	inspected_uid = -1
	input_locked = false
	playing = true
	orders = data.get("orders", [])
	if typeof(orders) != TYPE_ARRAY:
		orders = []
	order_seen = _int_dict(data.get("order_seen", {}))
	card_queue = _str_list(data.get("card_queue", []))
	chapter_shown = _flag_dict(data.get("chapter_shown", {}))
	chapter_rewarded = _str_dict(data.get("chapter_rewarded", {}))
	battery_bonus = int(data.get("battery_bonus", 0))
	if data.has("blueprint_bonus"):
		blueprint_bonus = clampi(int(data.get("blueprint_bonus", 0)), 0, 2)
	else:
		blueprint_bonus = 0
		if str(chapter_rewarded.get("liao", "")) == "done":
			blueprint_bonus += 1
		if str(chapter_rewarded.get("heyi", "")) == "done":
			blueprint_bonus += 1
	presearch = int(data.get("presearch", 0))
	supply_left = int(data.get("supply_left", 0))
	grain_sold_turn = int(data.get("grain_sold_turn", -1))
	transfer_turn = int(data.get("transfer_turn", -1))
	feast_turn = int(data.get("feast_turn", -1))
	bargain_round = int(data.get("bargain_round", 0))
	bargain_west = bool(data.get("bargain_west", false))
	bargain_used = _flag_dict(data.get("bargain_used", {}))
	order_place = _int_dict(data.get("order_place", {}))
	rest_streak = int(data.get("rest_streak", 0))
	campaign = {}
	var raw_campaign: Dictionary = data.get("campaign", {})
	for camp_key_v in raw_campaign.keys():
		campaign[str(camp_key_v)] = raw_campaign[camp_key_v]
	shelved = data.get("shelved", [])
	if typeof(shelved) != TYPE_ARRAY:
		shelved = []
	power_made = int(data.get("power_made", 0))
	power_waste = int(data.get("power_waste", 0))
	power_over = int(data.get("power_over", 0))
	power_sunk = int(data.get("power_sunk", 0))
	grain_samples = int(data.get("grain_samples", 0))
	grain_le12 = int(data.get("grain_le12", 0))
	epilogue_shown = bool(data.get("epilogue_shown", false))
	rating_floor = int(data.get("rating_floor", 0))
	recovery_until = int(data.get("recovery_until", 0))
	recovery_turn = int(data.get("recovery_turn", -1))
	demo_over = bool(data.get("demo_over", false))
	presearch_bonus = int(data.get("presearch_bonus", 0))
	shading = bool(data.get("shading", false))
	shade_skip = int(data.get("shade_skip", 0))
	night_read = bool(data.get("night_read", false))
	night_pay = int(data.get("night_pay", 0))
	design_ease = int(data.get("design_ease", 0))
	jingnei_mod = int(data.get("jingnei_mod", 0))
	city_home = _str_dict(data.get("city_home", {}))
	mold_said = int(data.get("mold_said", -99))
	presearch_full_said = int(data.get("presearch_full_said", -99))
	food_start = int(data.get("food_start", int(resources.get("food", 0))))
	produce_floor = -1
	_quiet_era3()
	_apply_seized()
	if orders.is_empty():
		GoalSystem.on_turn()
	EventSystem.scan()
	EventBus.state_changed.emit()
	return true


func load_tech_sample() -> void:
	# 第 52 回合示例：设计 K03 22/40，队列空，试制槽 1（K02 已试制 2/4 回合），图纸 I05、K04，格物院未颁布，实践 煤场 4、焦炉 6、水磨 6，电池 46，铜 14，已完成 21 项。
	turn = 52
	year = 1044
	month = 4
	month_span = 1
	tech_done = []
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		var era := int(tech.get("era", 1))
		if era == 1 or id == "I04" or id == "M05" or id == "E02" or id == "E03":
			tech_done.append(id)
	tech_designing = "K03"
	tech_design_prog = 22
	tech_queue = []
	tech_blueprints = ["I05", "K04"]
	tech_trials = [{"id": "K02", "prog": 2, "need": 4}]
	tech_paused = {}
	tech_target = ""
	tech_target_skip = []
	target_notice = ""
	target_advisor = ""
	target_added = []
	target_wait_noted = []
	tech_tutorial_done = true
	edicts_done.erase("gewuyuan")
	resources["copper"] = 14
	resources["iron"] = 46
	site_turns = {"mill": 6, "coal": 4, "coke": 6}
	city_buildings = {"kaifeng": ["watermill"], "daming": ["coalpit"]}
	practice_said = []
	pending_practice = []
	blueprint_bonus = 0
	battery_bonus = 0
	battery = 46
	EventBus.state_changed.emit()
