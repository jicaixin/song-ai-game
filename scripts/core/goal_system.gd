class_name GoalSystem
extends RefCounted

## Chapters, monthly orders, and the three victory meters.
## Orders are at most three, and each label is at most 14 characters.

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


static func on_turn() -> void:
	_apply_span()
	_queue_cards()
	_resolve_orders(true)
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
		if _flag_any("wanglun_fight", "wanglun_amnesty") and _flag_any("zhanghai_fight", "zhanghai_amnesty"):
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
		if xiping_done() and _flag_any("wangze_storm", "wangze_tunnel"):
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
	if _flag_any("wanglun_fight", "wanglun_amnesty"):
		n += 1
	if _flag_any("zhanghai_fight", "zhanghai_amnesty"):
		n += 1
	if _flag_any("wangze_storm", "wangze_tunnel"):
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
	var want: Array[String] = []
	if _hostile_near("yanzhou", 3) and _cooled("G02"):
		want.append("G02")
	if _wounded_xia() and _cooled("G04"):
		want.append("G04")
	if _can_trial() and _cooled("G08"):
		want.append("G08")
	elif _can_design() and _cooled("G07"):
		want.append("G07")
	var ch := current_chapter()
	if str(ch.get("id", "")) == "forts" and not GameState.event_flags.has("qingjian_build") and _cooled("G15"):
		want.append("G15")
	if GameState.turn >= 11 and GameState.turn <= 14 and _cooled("G06"):
		want.append("G06")
	if want.size() < MAX_ORDERS and _can_design() and not want.has("G07"):
		want.append("G07")
	if want.size() < MAX_ORDERS and _cooled("G16") and not want.has("G16"):
		want.append("G16")
	for id in want:
		if GameState.orders.size() >= MAX_ORDERS:
			break
		if have.has(id):
			continue
		var row := _make(id)
		if row.is_empty():
			continue
		GameState.orders.append(row)
		have[id] = true
	_mark_main()
	_refresh_notes()


static func _make(id: String) -> Dictionary:
	var spec := {}
	for item_v in DataDB.goal_orders:
		var item: Dictionary = item_v
		if str(item.get("id", "")) == id:
			spec = item
	if spec.is_empty():
		return {}
	var text := str(spec.get("text", ""))
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
		var place := "延州"
		var id := str(item.get("id", ""))
		if id == "G06":
			place = "镇戎军"
		elif id == "G07" or id == "G08":
			place = "开封"
		elif id == "G15":
			place = "青涧"
		item["note"] = "剩 %d 回合 · %s" % [left, place]


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
