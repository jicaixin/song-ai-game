extends Node

const EventSystem = preload("res://scripts/core/event_system.gd")

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
var tech_tutorial_done := false
var tutorial_done := false
var hint_menu_seen := false
var hint_enemy_menu_seen := false
var hint_blocked_seen := false
var site_turns := {}
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
	AdvisorSystem.say("game_start")
	EventSystem.scan()
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
	if tech_done.has("E01"):
		panel *= 1.15
	last_gen = int(round(float(power.get("base", 36)) * s * w * panel))
	var standby := standby_cost()
	var cap := battery_cap()
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
		if u.has("undo"):
			u.erase("undo")
		if u.has("skip_turn"):
			u.erase("skip_turn")


func finish_turn() -> void:
	month += 1
	if month > 12:
		month = 1
		year += 1
	roll_weather()
	apply_power()
	_economy()
	turn += 1
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
	if lines.is_empty() and blueprint == "" and not _should_nag_research():
		return false
	var bits: PackedStringArray = []
	for line in lines:
		bits.append(line)
	if blueprint != "":
		bits.append("图纸已成 · %s" % blueprint)
	if not bits.is_empty():
		notice = "\n".join(bits)
	if not lines.is_empty() and blueprint == "":
		AdvisorSystem.present("城下打起来了。%s明细在上面。" % lines[0], "serious", "battle_brief")
		return true
	if lines.is_empty() and blueprint != "":
		AdvisorSystem.present("图纸画好了：%s。去匠作院试制吧。" % blueprint, "smug", "blueprint_ready")
		return true
	if not lines.is_empty() and blueprint != "":
		AdvisorSystem.present("城下打了 %d 场，%s 的图纸也画好了。明细在上面。" % [lines.size(), blueprint], "serious", "battle_brief")
		return true
	research_idle_warned = true
	AdvisorSystem.present("电库存满了，图纸还空着。按 T 选一份，别让蓄电池干耗着。", "serious", "power_nag")
	notice = "电已满 · 选一份图纸"
	return true


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
	if tech_designing != "":
		var tech: Dictionary = DataDB.tech_by_id.get(tech_designing, {})
		var state := tech_state(tech_designing)
		return {
			"title": "停电" if state == "nopower" else "设计中",
			"body": str(tech.get("name", tech_designing)),
			"alert": false,
		}
	if not tech_trials.is_empty():
		var trial: Dictionary = tech_trials[0]
		var tech_t: Dictionary = DataDB.tech_by_id.get(str(trial.get("id", "")), {})
		return {
			"title": "试制中",
			"body": "%s  %d/%d" % [str(tech_t.get("name", "")), int(trial.get("prog", 0)), int(trial.get("need", 1))],
			"alert": false,
		}
	if not tech_queue.is_empty():
		var tech_q: Dictionary = DataDB.tech_by_id.get(str(tech_queue[0]), {})
		return {"title": "队列", "body": str(tech_q.get("name", "")), "alert": false}
	if not tech_blueprints.is_empty():
		var id := str(tech_blueprints[0])
		var tech_b: Dictionary = DataDB.tech_by_id.get(id, {})
		var extra := ""
		if tech_blueprints.size() > 1:
			extra = " 等%d份" % tech_blueprints.size()
		var title := "电已满 · 图纸待试制" if full else "图纸待试制"
		return {
			"title": title,
			"body": "%s%s · 去匠作院" % [str(tech_b.get("name", id)), extra],
			"alert": true,
		}
	var idle_title := "电已满" if full else "格物"
	return {"title": idle_title, "body": "选一份图纸 · 按 T", "alert": true}


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
		var pay := int(up.get("money", 0))
		if edicts_done.has("jingbing"):
			pay = int(round(float(pay) * 0.8))
		money -= pay
	if edicts_done.has("hegu"):
		money = int(round(float(money) * 0.95))
	money -= subsidies.size() * 40
	money += markets.size() * 6
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
	event_choice[event_id] = choice_id
	pending_events.erase(event_id)
	if not event_log.has(event_id):
		event_log.append(event_id)
	morale += int(choice.get("morale", 0))
	var rel: Dictionary = choice.get("relation", {})
	for key_v in rel.keys():
		var key := str(key_v)
		relations[key] = int(relations.get(key, 0)) + int(rel[key_v])
	EventSystem.apply(ev, choice)
	notice = str(choice.get("result", "已记下"))
	last_event = notice
	AdvisorSystem.say("event_post:%s:%s" % [event_id, choice_id])
	EventBus.state_changed.emit()


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
	tech_tutorial_done = false
	battle_lines = []
	pending_blueprint = ""
	research_idle_warned = false
	site_turns = {}
	firmware_done = []
	edicts_done = []
	notice = ""


func battery_cap() -> int:
	var cap := int(DataDB.balance.get("power", {}).get("battery_max", 80))
	if tech_done.has("E04"):
		cap += 60
	if tech_done.has("E06"):
		cap += 150
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
	return need


func era_unlocked(era: int) -> bool:
	if era <= 1:
		return true
	if era == 2:
		return turn > 30
	if era == 3:
		return turn > 75 or _era_done_count(2) >= 11
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


func start_design(id: String) -> bool:
	var st := tech_state(id)
	if st != "available" and st != "queued":
		return false
	tech_queue.erase(id)
	research_idle_warned = false
	if tech_designing == "":
		tech_designing = id
		tech_design_prog = int(tech_paused.get(id, 0))
		tech_paused.erase(id)
	elif id != tech_designing and not tech_queue.has(id):
		tech_queue.append(id)
	EventBus.state_changed.emit()
	return true


func cancel_design() -> void:
	pause_design()


func pause_design() -> void:
	if tech_designing == "":
		return
	tech_paused[tech_designing] = tech_design_prog
	tech_designing = ""
	tech_design_prog = 0
	_pull_queue()
	EventBus.state_changed.emit()


func remove_queued(id: String) -> void:
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
	if not _pay_trial(tech):
		notice = "匠或材料不够"
		EventBus.state_changed.emit()
		return false
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
			tech_blueprints.append(id)
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
	notice = "已经推广 · %s" % str(tech.get("name", id))
	last_event = "%s %s" % [notice, str(tech.get("effect", ""))]


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
		"tech_tutorial_done": tech_tutorial_done,
		"tutorial_done": tutorial_done,
		"hint_menu_seen": hint_menu_seen,
		"hint_enemy_menu_seen": hint_enemy_menu_seen,
		"hint_blocked_seen": hint_blocked_seen,
		"research_idle_warned": research_idle_warned,
		"site_turns": site_turns.duplicate(),
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
	}


func from_save(data: Dictionary) -> bool:
	if int(data.get("save_version", 0)) != 1:
		return false
	_reset_research()
	_reset_politics()
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
	tech_tutorial_done = bool(data.get("tech_tutorial_done", false))
	tutorial_done = bool(data.get("tutorial_done", false))
	hint_menu_seen = bool(data.get("hint_menu_seen", false))
	hint_enemy_menu_seen = bool(data.get("hint_enemy_menu_seen", false))
	hint_blocked_seen = bool(data.get("hint_blocked_seen", false))
	research_idle_warned = bool(data.get("research_idle_warned", false))
	battle_lines = []
	pending_blueprint = ""
	site_turns = _int_dict(data.get("site_turns", {}))
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
	EventSystem.scan()
	EventBus.state_changed.emit()
	return true


func load_tech_sample() -> void:
	# 第 52 回合示例：设计 K03 22/40，队列 K05→E05，试制 K02 与 K04，图纸 I05，铜 14，已完成 21 项。
	turn = 52
	year = 1044
	month = 4
	tech_done = []
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		var era := int(tech.get("era", 1))
		if era == 1 or id == "I04" or id == "M05" or id == "E02" or id == "E03":
			tech_done.append(id)
	tech_designing = "K03"
	tech_design_prog = 22
	tech_queue = ["K05", "E05"]
	tech_blueprints = ["I05"]
	tech_trials = [
		{"id": "K02", "prog": 22, "need": 28},
		{"id": "K04", "prog": 12, "need": 30},
	]
	tech_paused = {}
	tech_target = ""
	tech_tutorial_done = true
	if not edicts_done.has("gewuyuan"):
		edicts_done.append("gewuyuan")
	resources["copper"] = 14
	resources["iron"] = 46
	site_turns = {"mill": 6}
	battery = 48
	EventBus.state_changed.emit()
