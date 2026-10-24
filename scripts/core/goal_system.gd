class_name GoalSystem
extends RefCounted

## Chapters, monthly orders, and the three victory meters.
## Orders are at most three, and each label is at most 14 characters.

const Omen = preload("res://scripts/core/omen.gd")
const Campaign = preload("res://scripts/core/campaign.gd")

const MAX_ORDERS := 3
const LABEL_MAX := 14


static func reset() -> void:
	GameState.orders = []
	GameState.order_seen = {}
	GameState.card_queue = []
	GameState.chapter_shown = {}
	GameState.chapter_rewarded = {}
	GameState.reward_queue = []
	GameState.month_span = 1
	GameState.battery_bonus = 0
	GameState.presearch = 0
	GameState.supply_left = 0
	GameState.grain_sold_turn = -1
	GameState.transfer_turn = -1
	GameState.feast_turn = -1
	GameState.bargain_round = 0
	GameState.bargain_used = {}
	GameState.bargain_west = false
	GameState.order_place = {}
	GameState.rest_streak = 0
	GameState.campaign = {}


static func on_turn() -> void:
	_apply_span()
	_queue_cards()
	_resolve_orders(true)
	Campaign.on_turn()
	_fill_orders()


static func touch() -> void:
	_resolve_orders(false)
	if GameState.orders.size() < MAX_ORDERS:
		_fill_orders()


static func main_text() -> String:
	if GameState.orders.is_empty():
		return ""
	var first: Dictionary = GameState.orders[0]
	return str(first.get("text", ""))


static func collapsed_text() -> String:
	var text := main_text()
	if text.length() > 13:
		return text.substr(0, 13)
	return text


static func chapter_for_turn(turn: int) -> Dictionary:
	for ch_v in DataDB.chapters:
		var ch: Dictionary = ch_v
		var window: Array = ch.get("turn", [])
		if window.size() < 2:
			continue
		if turn >= int(window[0]) and turn <= int(window[1]):
			return ch
	return {}


static func current_chapter() -> Dictionary:
	return chapter_for_turn(GameState.turn)


static func chapter_progress() -> String:
	var ch := current_chapter()
	if ch.is_empty():
		return ""
	var window: Array = ch.get("turn", [1, 1])
	var start := int(window[0])
	var last := int(window[1])
	var at := GameState.turn - start + 1
	var total := last - start + 1
	return "%d/%d" % [at, total]


static func chapter_state(ch: Dictionary) -> String:
	var check := str(ch.get("check", ""))
	if check == "yan":
		if not _city_song("yanzhou"):
			return "fail"
		if GameState.event_flags.has("sanchuan_hold"):
			return "done"
		if GameState.event_flags.has("sanchuan_march"):
			return "partial"
		return "open"
	if check == "haoshui":
		if GameState.event_flags.has("haoshui_hold"):
			return "done"
		if GameState.event_flags.has("haoshui_advance"):
			return "fail"
		return "open"
	if check == "liao":
		if int(GameState.meters.get("liao_demand", 20)) <= 10:
			return "done"
		return "open"
	if check == "rebels":
		if _pacified("wanglun") and _pacified("zhanghai"):
			return "done"
		return "open"
	if check == "heyi":
		if xiping() >= 70 and _flag_any("heyi_accept", "heyi_cut", "heyi_refuse"):
			return "done"
		return "open"
	if check == "era3":
		if GameState._era_done_count(3) >= 1:
			return "done"
		return "open"
	if check == "finale":
		if xiping_done() and _pacified("wangze"):
			return "done"
		return "open"
	return "open"


static func xiping() -> int:
	return clampi(100 - int(GameState.meters.get("xia_war", 70)), 0, 100)


static func xiping_done() -> bool:
	if xiping() >= 85:
		return true
	if _flag_any("heyi_accept", "heyi_cut"):
		return true
	return _city_song("xingqing")


static func beiding() -> int:
	var demand := int(GameState.meters.get("liao_demand", 20))
	return clampi((20 - demand) * 5, 0, 100)


static func beiding_done() -> String:
	var demand := int(GameState.meters.get("liao_demand", 20))
	if demand <= 0:
		return "full"
	if demand <= 10:
		return "reduced"
	return ""


static func jingnei_count() -> int:
	var n := 0
	if _pacified("wanglun"):
		n += 1
	if _pacified("zhanghai"):
		n += 1
	if _pacified("wangze"):
		n += 1
	return n


static func jingnei() -> int:
	return int(round(float(jingnei_count()) * 100.0 / 3.0))


static func jingnei_done() -> bool:
	return jingnei_count() >= 3


static func pop_card() -> String:
	if GameState.card_queue.is_empty():
		return ""
	var card := str(GameState.card_queue[0])
	GameState.card_queue.remove_at(0)
	return card


static func grant_chapter(ch: Dictionary, state: String) -> void:
	var cid := str(ch.get("id", ""))
	if cid == "" or GameState.chapter_rewarded.has(cid):
		return
	if state != "done" and state != "partial":
		GameState.chapter_rewarded[cid] = state
		return
	GameState.chapter_rewarded[cid] = state
	var scale := 1.0 if state == "done" else 0.5
	var craft := int(round(float(int(ch.get("craft", 0))) * scale))
	var morale := int(round(float(int(ch.get("morale", 0))) * scale))
	var battery := int(ch.get("battery", 0)) if state == "done" else 0
	_pay(craft, morale, battery)


static func _apply_span() -> void:
	var date := Calendar.apply_turn(GameState.turn)
	GameState.year = date.x
	GameState.month = date.y
	GameState.month_span = date.z


static func _queue_cards() -> void:
	var ch := current_chapter()
	if ch.is_empty():
		return
	var cid := str(ch.get("id", ""))
	if GameState.chapter_shown.has(cid):
		return
	var prev := _previous_chapter(ch)
	if not prev.is_empty():
		var pid := str(prev.get("id", ""))
		if not GameState.chapter_rewarded.has(pid):
			GameState.card_queue.append("end:%s" % pid)
	GameState.card_queue.append("start:%s" % cid)
	GameState.chapter_shown[cid] = true


static func _previous_chapter(ch: Dictionary) -> Dictionary:
	var window: Array = ch.get("turn", [])
	if window.is_empty():
		return {}
	return chapter_for_turn(int(window[0]) - 1)


static func _fill_orders() -> void:
	var have := {}
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		have[str(item.get("id", ""))] = true
	var started_empty: bool = GameState.orders.is_empty()
	var want: Array = []
	var omen := Omen.current()
	if not omen.is_empty():
		_push(want, have, "G01", str(omen.get("order", "")), str(omen.get("place", "")), "", int(omen.get("need", 1)))
	var threat := _threat_place()
	if threat == "yanzhou":
		_push(want, have, "G02", "守住延州", "yanzhou", "", 1)
	elif threat != "":
		var city := DataDB.city_by_id(threat)
		var label := "守住%s" % str(city.get("short", "边城"))
		_push(want, have, "G24", label, threat, "", 1)
	if _wounded_xia():
		_push(want, have, "G04", "击退城下西夏", "yanzhou", "", 1)
	_chapter_steps(want, have)
	if _can_trial():
		_push(want, have, "G08", "试制一份图纸", "", "", 1)
	elif _can_design() and not _battery_full():
		_push(want, have, "G07", "开始一项设计", "", "", 1)
	if GameState.can_sell_grain():
		_push(want, have, "G11", "常平仓出粜", "", "", 1)
	if _battery_full() and _can_design():
		_push(want, have, "G12", "把溢电送去设计", "", "", 1)
	elif int(GameState.resources.get("food", 0)) >= 200 and int(GameState.resources.get("food", 0)) > GameState.monthly_food() * 12:
		_push(want, have, "G17", "转输陕西边粮", "yanzhou", "", 1)
	if GameState.can_feast():
		_push(want, have, "G18", "犒赏一支伤兵", "yanzhou", "", 1)
	if int(GameState.resources.get("money", 0)) >= 80 and int(GameState.envoy_turn.get("gusiluo", -99)) != GameState.turn:
		_push(want, have, "G22", "遣使唃厮啰", "", "gusiluo", 1)
	var added_real := false
	for spec_v in want:
		if GameState.orders.size() >= MAX_ORDERS:
			break
		var spec: Dictionary = spec_v
		var id := str(spec.get("id", ""))
		if have.has(id):
			continue
		var row := _make(id, str(spec.get("text", "")), str(spec.get("place", "")), str(spec.get("envoy", "")), int(spec.get("need", 1)))
		if row.is_empty():
			continue
		GameState.orders.append(row)
		have[id] = true
		added_real = true
		var place := str(spec.get("place", ""))
		if place != "":
			GameState.order_place[place] = GameState.turn
	if GameState.orders.is_empty():
		_force_fallback()
		added_real = false
	if started_empty:
		if added_real:
			GameState.rest_streak = 0
		else:
			GameState.rest_streak += 1
	_mark_main()
	_refresh_notes()


static func _chapter_steps(want: Array, have: Dictionary) -> void:
	var ch := current_chapter()
	var cid := str(ch.get("id", ""))
	if cid == "forts" and not GameState.event_flags.has("qingjian_build"):
		_push(want, have, "G15", "修筑青涧城", "qingjian", "", 1)
	if cid == "forts" and GameState.turn >= 11 and GameState.turn <= 14:
		_push(want, have, "G06", "侦察镇戎军北", "zhenrong", "", 1)
	if cid == "liao" and not GameState.event_choice.has("zengbi"):
		_push(want, have, "G25", "雄州定州驻军", "xiongzhou", "", 1)
	if cid == "qingli" and Campaign.alive("wanglun") > 0:
		_push(want, have, "G26", "追击沂州叛军", "yizhou", "", 1)
	elif cid == "qingli" and Campaign.alive("zhanghai") > 0:
		_push(want, have, "G26", "清剿商山贼", "shang", "", 1)


static func _force_fallback() -> void:
	var id := "G16"
	var text := "巡视延州边"
	var place := "yanzhou"
	if not _place_ok("yanzhou"):
		id = "G28"
		text = "巡视开封外围"
		place = "kaifeng"
	var row := _make(id, text, place, "", 1)
	if row.is_empty():
		return
	GameState.orders.append(row)
	GameState.order_place[place] = GameState.turn


static func _push(want: Array, have: Dictionary, id: String, text: String, place: String, envoy: String, need: int) -> void:
	if want.size() >= MAX_ORDERS:
		return
	if have.has(id):
		return
	if not _cooled(id):
		return
	if not _place_ok(place):
		return
	if not _startable(id):
		return
	for prev_v in want:
		var prev: Dictionary = prev_v
		if str(prev.get("id", "")) == id:
			return
		if place != "" and str(prev.get("place", "")) == place:
			return
	if text.length() > LABEL_MAX:
		text = text.substr(0, LABEL_MAX)
	want.append({"id": id, "text": text, "place": place, "envoy": envoy, "need": need})


static func _startable(id: String) -> bool:
	if id == "G07" or id == "G12":
		return _can_design()
	if id == "G08":
		return _can_trial()
	if id == "G11":
		return GameState.can_sell_grain()
	if id == "G17":
		return int(GameState.resources.get("food", 0)) >= 200
	if id == "G18":
		return GameState.can_feast()
	if id == "G22":
		return int(GameState.resources.get("money", 0)) >= 80
	if id == "G04":
		return _wounded_xia()
	return true


static func _make(id: String, text: String, place: String, envoy: String, need: int) -> Dictionary:
	var spec := {}
	for item_v in DataDB.goal_orders:
		var item: Dictionary = item_v
		if str(item.get("id", "")) == id:
			spec = item
	if spec.is_empty():
		return {}
	if text == "":
		text = str(spec.get("text", ""))
	if text.length() > LABEL_MAX:
		text = text.substr(0, LABEL_MAX)
	return {
		"id": id,
		"text": text,
		"note": "",
		"kind": str(spec.get("kind", "military")),
		"born": GameState.turn,
		"limit": int(spec.get("limit", 2)),
		"craft": int(spec.get("craft", 6)),
		"morale": int(spec.get("morale", 0)),
		"place": place,
		"envoy": envoy,
		"need": need,
		"main": false,
	}


static func _resolve_orders(by_turn: bool) -> void:
	var keep: Array = []
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		var id := str(item.get("id", ""))
		var state := _order_state(item, by_turn)
		if state == "open":
			keep.append(item)
			continue
		GameState.order_seen[id] = GameState.turn
		if state == "done":
			var craft := int(item.get("craft", 0))
			var morale := int(item.get("morale", 0))
			if bool(item.get("main", false)):
				craft = int(round(float(craft) * 1.5))
			_pay(craft, morale, 0)
		else:
			GameState.reward_queue.append({"text": "逾期", "bad": true})
	GameState.orders = keep
	_mark_main()
	_refresh_notes()
	if GameState.orders.is_empty():
		_fill_orders()


static func _order_state(item: Dictionary, by_turn: bool) -> String:
	var id := str(item.get("id", ""))
	var age := GameState.turn - int(item.get("born", GameState.turn))
	var limit := int(item.get("limit", 1))
	if id == "G02":
		if not _city_song("yanzhou"):
			return "overdue"
		if by_turn and age >= limit:
			return "done"
		return "open"
	if id == "G04":
		if not _wounded_xia():
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G06":
		if _song_moved_near("zhenrong", 2):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G07":
		if str(GameState.tech_designing) != "":
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G08":
		if not GameState.tech_trials.is_empty():
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G15":
		if GameState.event_flags.has("qingjian_build"):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G16":
		if _song_moved_near("yanzhou", 2):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G28":
		if _song_moved_near("kaifeng", 2):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G01":
		var need := int(item.get("need", 1))
		if _song_count_near(str(item.get("place", "")), 2) >= need:
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G11":
		if GameState.grain_sold_turn >= int(item.get("born", GameState.turn)):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G12":
		if str(GameState.tech_designing) != "":
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G17":
		if GameState.transfer_turn >= int(item.get("born", GameState.turn)):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G18":
		if GameState.feast_turn >= int(item.get("born", GameState.turn)):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G22":
		var envoy := str(item.get("envoy", "gusiluo"))
		if int(GameState.envoy_turn.get(envoy, -99)) >= int(item.get("born", GameState.turn)):
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G24":
		var held := str(item.get("place", ""))
		if held != "" and not _city_song(held):
			return "overdue"
		if by_turn and age >= limit:
			return "done"
		return "open"
	if id == "G25":
		if _garrison_count() >= 2:
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	if id == "G26":
		var rebels_gone: bool = Campaign.alive("wanglun") == 0 and Campaign.alive("zhanghai") == 0
		var dealt: bool = _flag_any("wanglun_fight", "wanglun_amnesty") or _flag_any("zhanghai_fight", "zhanghai_amnesty")
		if rebels_gone and dealt:
			return "done"
		if _rebel_contact():
			return "done"
		if by_turn and age >= limit:
			return "overdue"
		return "open"
	return "open"


static func _pay(craft: int, morale: int, battery: int) -> void:
	if craft > 0:
		GameState.resources["craft"] = int(GameState.resources.get("craft", 0)) + craft
		GameState.reward_queue.append({"text": "匠 +%d" % craft})
	if morale > 0:
		GameState.morale += morale
		GameState.reward_queue.append({"text": "皇威 +%d" % morale})
	if battery > 0:
		GameState.battery_bonus += battery
		GameState.reward_queue.append({"text": "电上限 +%d" % battery})


static func _mark_main() -> void:
	var first := true
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		item["main"] = first
		first = false


static func _refresh_notes() -> void:
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		var left := int(item.get("limit", 1)) - (GameState.turn - int(item.get("born", GameState.turn)))
		if left < 1:
			left = 1
		var place := _place_name(str(item.get("place", "")), str(item.get("id", "")))
		item["note"] = "剩 %d 回合 · %s" % [left, place]


static func completable(item: Dictionary) -> bool:
	if int(item.get("limit", 9)) > 3:
		return false
	return _startable(str(item.get("id", "")))


static func _pacified(tag: String) -> bool:
	if tag == "wanglun":
		if not _flag_any("wanglun_fight", "wanglun_amnesty"):
			return false
	elif tag == "zhanghai":
		if not _flag_any("zhanghai_fight", "zhanghai_amnesty"):
			return false
	elif tag == "wangze":
		if not _flag_any("wangze_storm", "wangze_tunnel"):
			return false
	else:
		return false
	return Campaign.alive(tag) == 0


static func _place_ok(place: String) -> bool:
	if place == "":
		return true
	if not GameState.order_place.has(place):
		return true
	return GameState.turn - int(GameState.order_place[place]) >= 3


static func _battery_full() -> bool:
	return GameState.battery >= GameState.battery_cap()


static func _threat_place() -> String:
	var best := ""
	var best_d := 99
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if str(city.get("faction", "")) != "song":
			continue
		var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
		for u_v in GameState.units:
			var u: Dictionary = u_v
			if int(u.get("hp", 0)) <= 0:
				continue
			if not DataDB.hostile("song", str(u.get("faction", ""))):
				continue
			var d := HexGrid.distance(origin, Vector2i(int(u.get("q", 0)), int(u.get("r", 0))))
			if d <= 3 and d < best_d:
				best_d = d
				best = str(city.get("id", ""))
	return best


static func _song_count_near(place: String, dist: int) -> int:
	var origin := _place_hex(place)
	if origin.x > 9000:
		return 0
	var n := 0
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if HexGrid.distance(origin, Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))) <= dist:
			n += 1
	return n


static func _place_hex(place: String) -> Vector2i:
	if place == "qingjian":
		return Vector2i(19, 24)
	if place == "dingchuan" or place == "shang":
		return Vector2i(16, 28)
	if place == "qinghai":
		return Vector2i(8, 30)
	var city := DataDB.city_by_id(place)
	if city.is_empty():
		return Vector2i(99999, 0)
	return Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))


static func _place_name(place: String, id: String) -> String:
	if place == "qingjian" or id == "G15":
		return "青涧"
	if place == "dingchuan" or place == "shang":
		return "陕西"
	if place == "qinghai":
		return "青唐"
	if place == "":
		if id == "G07" or id == "G08" or id == "G11" or id == "G12" or id == "G22":
			return "开封"
		return "延州"
	var city := DataDB.city_by_id(place)
	if city.is_empty():
		return "延州"
	var short := str(city.get("short", ""))
	if short == "":
		short = str(city.get("name", "延州"))
	return short


static func _garrison_count() -> int:
	var n := 0
	if _song_count_near("xiongzhou", 1) > 0:
		n += 1
	if _song_count_near("dingzhou", 1) > 0:
		n += 1
	if _song_count_near("zhending", 1) > 0:
		n += 1
	return n


static func _rebel_contact() -> bool:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		var tag := str(u.get("tag", ""))
		if tag != "wanglun" and tag != "zhanghai":
			continue
		if int(u.get("hp", 0)) <= 0:
			continue
		var at := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
		if _song_count_near_hex(at, 2) > 0:
			return true
	return false


static func _song_count_near_hex(origin: Vector2i, dist: int) -> int:
	var n := 0
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if HexGrid.distance(origin, Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))) <= dist:
			n += 1
	return n


static func _cooled(id: String) -> bool:
	if not GameState.order_seen.has(id):
		return true
	return GameState.turn - int(GameState.order_seen[id]) >= 6


static func _can_design() -> bool:
	if str(GameState.tech_designing) != "":
		return false
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if GameState.tech_state(str(tech.get("id", ""))) == "available":
			return true
	return false


static func _can_trial() -> bool:
	return not GameState.tech_blueprints.is_empty() and GameState.tech_trials.size() < GameState.trial_slots()


static func _city_song(city_id: String) -> bool:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		return false
	return DataDB.owner_id(int(city.get("q", 0)), int(city.get("r", 0))) == "song"


static func _hostile_near(city_id: String, dist: int) -> bool:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		return false
	var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) == "song" or int(u.get("hp", 0)) <= 0:
			continue
		var at := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
		if HexGrid.distance(origin, at) <= dist:
			return true
	return false


static func _wounded_xia() -> bool:
	var city := DataDB.city_by_id("yanzhou")
	if city.is_empty():
		return false
	var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "xia" or int(u.get("hp", 0)) <= 0 or int(u.get("hp", 0)) >= 40:
			continue
		var at := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
		if HexGrid.distance(origin, at) <= 4:
			return true
	return false


static func _song_moved_near(city_id: String, dist: int) -> bool:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		return false
	var origin := Vector2i(int(city.get("q", 0)), int(city.get("r", 0)))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) != "song" or int(u.get("hp", 0)) <= 0:
			continue
		if int(u.get("mp", 0)) >= int(u.get("max_mp", 0)):
			continue
		var at := Vector2i(int(u.get("q", 0)), int(u.get("r", 0)))
		if HexGrid.distance(origin, at) <= dist:
			return true
	return false


static func _flag_any(a: String, b: String, c: String = "") -> bool:
	if GameState.event_flags.has(a) or GameState.event_flags.has(b):
		return true
	return c != "" and GameState.event_flags.has(c)
