class_name TechPlan
extends RefCounted

const MAT_NAME := {
	"wood": "木",
	"iron": "铁",
	"money": "钱",
	"copper": "铜",
	"saltpeter": "硝",
	"sulfur": "硫",
	"coal": "煤",
	"steel": "钢",
}


static func view_state(id: String) -> String:
	var raw := GameState.tech_state(id)
	if raw == "queued":
		if not GameState.prereqs_done(id):
			return "noprereq"
		return "queued"
	if raw == "nopower":
		return "blocked"
	if raw == "blueprint" and GameState.practice_gate_on and not GameState.practice_ok(id):
		return "blocked"
	if raw == "blueprint" and not can_afford(id):
		return "blocked"
	return raw


static func queue_index(id: String) -> int:
	var at := GameState.tech_queue.find(id)
	if at < 0:
		return 0
	return int(at) + 1


static func status_text(id: String) -> String:
	var state := view_state(id)
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if state == "done":
		return "已完成"
	if state == "designing":
		return "设计 %d/%d 电" % [GameState.tech_design_prog, GameState.design_need(id)]
	if state == "queued" or state == "available":
		return "可设计 · %d 电" % GameState.design_need(id)
	if state == "noprereq":
		return "缺：%s" % short_name(_first_missing(id))
	if state == "blocked":
		return _blocked_text(id)
	if state == "blueprint":
		return "有图纸 · 试制 %d 回合" % _trial_turns(id)
	if state == "trial":
		var trial := _trial(id)
		return "试制 %d/%d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))]
	return _lock_label(int(tech.get("era", 1)))


static func primary_verb(id: String) -> String:
	var state := view_state(id)
	if state == "done":
		if unlocks_building(id):
			return "去推广"
		return ""
	if state == "designing":
		return "暂停设计"
	if state == "queued":
		return "移出队列"
	if state == "available":
		return "安排设计"
	if state == "noprereq":
		if GameState.tech_target == id:
			return ""
		return "设为目标"
	if state == "blocked":
		return "去补齐"
	if state == "blueprint":
		return "去匠作院试制"
	if state == "trial":
		return "查看试制"
	return ""


static func show_target_link(id: String) -> bool:
	if GameState.tech_target == id:
		return false
	var state := view_state(id)
	return state == "available" or state == "queued" or state == "designing" or state == "noprereq" or state == "blocked"


static func run_primary(id: String) -> String:
	var state := view_state(id)
	if state == "done":
		return "city" if unlocks_building(id) else ""
	if state == "designing":
		GameState.pause_design()
		return ""
	if state == "queued":
		GameState.remove_queued(id)
		return ""
	if state == "available":
		if GameState.tech_designing != "" and GameState.tech_designing != id:
			return "confirm_design"
		GameState.start_design(id)
		return ""
	if state == "noprereq":
		set_target(id)
		return ""
	if state == "blocked":
		return _blocked_jump(id)
	if state == "blueprint":
		return "confirm_trial"
	if state == "trial":
		return "workshop"
	return ""


static func set_target(id: String) -> void:
	GameState.tech_target = id
	GameState.tech_target_skip = []
	GameState.target_wait_noted = []
	GameState.target_added = []
	GameState.target_notice = ""
	GameState.target_advisor = ""
	GameState.refill_target_queue("set")
	EventBus.state_changed.emit()


static func _by_power(a: String, b: String) -> bool:
	return GameState.design_need(a) < GameState.design_need(b)


static func clear_target() -> void:
	GameState.tech_target = ""
	GameState.tech_target_skip = []
	EventBus.state_changed.emit()


static func spine(target: String) -> Array:
	var chain: Array = []
	if target == "" or not DataDB.tech_by_id.has(target):
		return chain
	var cur := target
	var guard := 0
	while cur != "" and guard < 12:
		chain.push_front(cur)
		guard += 1
		var tech: Dictionary = DataDB.tech_by_id.get(cur, {})
		var next := ""
		var best := -1
		for pre_v in tech.get("prereq", []):
			var pre := str(pre_v)
			if GameState.tech_done.has(pre):
				continue
			var rank := _open_rank(pre)
			if rank > best:
				best = rank
				next = pre
		cur = next
	return chain


static func totals(target: String) -> Dictionary:
	var power := 0
	var craft := 0
	var chain := spine(target)
	for id_v in chain:
		var id := str(id_v)
		if GameState.tech_done.has(id):
			continue
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		var cost: Dictionary = tech.get("cost", {})
		var craft_cost := int(cost.get("craft", 0))
		if GameState.tech_state(id) == "trial":
			# 匠在开试制时一次付清。剩下的是回合，不再计入总匠。
			continue
		elif GameState.tech_state(id) == "blueprint":
			craft += craft_cost
		elif GameState.tech_designing == id:
			power += maxi(0, GameState.design_need(id) - GameState.tech_design_prog)
			craft += craft_cost
		else:
			power += GameState.design_need(id)
			craft += craft_cost
	var target_craft := 0
	var target_tech: Dictionary = DataDB.tech_by_id.get(target, {})
	var target_cost: Dictionary = target_tech.get("cost", {})
	target_craft = int(target_cost.get("craft", 0))
	var months := int(round(float(power) / 10.0 + float(target_craft) / 10.0))
	return {
		"power": power,
		"craft": craft,
		"months": months,
		"eta": GameState.turn + months,
		"chain": chain,
	}


static func suggestion() -> Dictionary:
	var low := float(GameState.battery) / float(maxi(1, GameState.battery_cap())) < 0.2
	if GameState.tech_target != "":
		var step := _path_step(GameState.tech_target)
		if step.is_empty():
			return {}
		step["telegraph"] = low
		return step
	if GameState.turn < 15 and view_state("M02") == "available":
		return _suggest("M02", "design", "把「堡寨筑城法」排进设计", "堡寨先立住，延州才有地方练兵。", low)
	if not GameState.tech_done.has("E05") and GameState.tech_done.has("E03") and GameState.era_unlocked(2):
		return _suggest("E05", "target", "把「水轮发电机」设为目标", "人力坊每月吃 20 匠，水轮一座 +12 电还不吃匠。", low)
	var cheapest := ""
	var best := 999999
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if view_state(id) != "available":
			continue
		var need := GameState.design_need(id)
		if need < best:
			best = need
			cheapest = id
	if cheapest != "":
		var tech2: Dictionary = DataDB.tech_by_id.get(cheapest, {})
		return _suggest(cheapest, "design", "把「%s」排进设计" % str(tech2.get("name", cheapest)), str(tech2.get("effect", "")), low)
	return {}


static func adopt() -> String:
	var sug := suggestion()
	var id := str(sug.get("id", ""))
	if id == "":
		return ""
	var kind := str(sug.get("kind", ""))
	if kind == "target":
		set_target(id)
	elif kind == "design":
		GameState.start_design(id)
	elif kind == "trial":
		GameState.start_trial(id)
		return "workshop"
	return ""


static func blockers() -> Array:
	var out: Array = []
	if GameState.tech_trials.size() >= GameState.trial_slots() and not GameState.tech_blueprints.is_empty():
		var waiting := ""
		for id_v in GameState.tech_blueprints:
			var tech: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
			waiting = str(tech.get("name", str(id_v)))
			break
		out.append({
			"text": "试制槽 %d/%d 满，%s排队中" % [GameState.tech_trials.size(), GameState.trial_slots(), waiting],
			"jump": "workshop",
			"jump_label": "匠作院",
		})
	var focus := GameState.tech_target
	if focus == "":
		var sug := suggestion()
		focus = str(sug.get("id", ""))
	if focus != "":
		var short := _short_material(focus)
		if not short.is_empty():
			var tech: Dictionary = DataDB.tech_by_id.get(focus, {})
			out.append({
				"text": "%s %d/%d（%s）" % [str(short.get("name", "")), int(short.get("have", 0)), int(short.get("need", 0)), str(tech.get("name", focus))],
				"jump": "industry",
				"jump_label": "百工图",
			})
	if GameState.tech_designing != "" and GameState.battery <= GameState.standby_cost() and GameState.tech_design_prog < GameState.design_need(GameState.tech_designing):
		out.append({
			"text": "电不够，这一份图纸画不下去",
			"jump": "console",
			"jump_label": "控制台",
		})
	if out.size() > 3:
		out = out.slice(0, 3)
	return out


static func gate_rows(id: String) -> Array:
	var rows: Array = []
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		var pre := str(pre_v)
		var pre_tech: Dictionary = DataDB.tech_by_id.get(pre, {})
		var ok := GameState.tech_done.has(pre)
		var note := "已完成" if ok else status_text(pre)
		if not ok and GameState.tech_state(pre) != "blueprint" and GameState.tech_state(pre) != "trial" and GameState.tech_state(pre) != "designing":
			note = "需%s图纸" % str(pre_tech.get("name", pre))
		rows.append({"ok": ok, "text": "前置  %s" % str(pre_tech.get("name", pre)), "note": note})
	var cost: Dictionary = tech.get("cost", {})
	var power := int(cost.get("power", 0))
	var design_ok := GameState.prereqs_done(id) or GameState.tech_done.has(id) or GameState.tech_state(id) == "designing" or GameState.tech_state(id) == "blueprint" or GameState.tech_state(id) == "trial"
	var design_note := "约 %d 回合" % int(ceil(float(maxi(power, 1)) / 10.0))
	if not design_ok:
		design_note = _missing_sheet(id)
	rows.append({"ok": design_ok, "text": "设计  电 %d" % power, "note": design_note})
	var craft := int(cost.get("craft", 0))
	var trial_n := maxi(2, int(ceil(float(maxi(craft, 1)) / 12.0)))
	rows.append({"ok": can_afford(id) or GameState.tech_state(id) == "trial" or GameState.tech_done.has(id), "text": "试制  匠 %d" % craft, "note": "预计 %d 回合" % trial_n})
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		var key := str(key_v)
		var need := int(mats[key_v])
		var have := int(GameState.resources.get(key, 0))
		rows.append({
			"ok": have >= need,
			"text": "材料  %s %d" % [str(MAT_NAME.get(key, key)), need],
			"note": "库存 %d" % have,
		})
	var practice := practice_row(id)
	if str(practice.get("label", "")) != "":
		rows.append({
			"ok": bool(practice.get("ok", false)),
			"text": "实践  %s" % str(practice.get("label", "")),
			"note": "%d / %d" % [int(practice.get("have", 0)), int(practice.get("need", 0))],
		})
	return rows


static func practice_row(id: String) -> Dictionary:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var label := str(tech.get("practice", ""))
	if label == "":
		return {"ok": true, "have": 0, "need": 0, "label": ""}
	return {
		"ok": GameState.practice_ok(id),
		"have": GameState.practice_have(id),
		"need": GameState.practice_need(id),
		"label": label,
	}


static func era_progress(era: int) -> Vector2i:
	var done := 0
	var total := 0
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if int(tech.get("era", 0)) != era:
			continue
		total += 1
		if GameState.tech_done.has(str(tech.get("id", ""))):
			done += 1
	return Vector2i(done, total)


static func stage_progress(stage: int) -> Vector2i:
	var done := 0
	var total := 0
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if int(tech.get("stage", 0)) != stage:
			continue
		total += 1
		if GameState.tech_done.has(str(tech.get("id", ""))):
			done += 1
	return Vector2i(done, total)


static func current_era() -> int:
	if GameState.era_unlocked(3):
		return 3
	if GameState.era_unlocked(2):
		return 2
	return 1


static func era_complete(era: int) -> bool:
	var prog := era_progress(era)
	return prog.y > 0 and prog.x == prog.y


static func is_frontier(id: String, era_now: int) -> bool:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if int(tech.get("era", 1)) != era_now + 1:
		return false
	var touched := false
	for pre_v in tech.get("prereq", []):
		var pre: Dictionary = DataDB.tech_by_id.get(str(pre_v), {})
		var pre_era := int(pre.get("era", 1))
		if pre_era > era_now:
			return false
		if pre_era == era_now:
			touched = true
	return touched


static func unlocks_building(id: String) -> bool:
	for b_v in DataDB.buildings:
		var b: Dictionary = b_v
		if str(b.get("unlock", "")) == id:
			return true
	return false


static func can_afford(id: String) -> bool:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var cost: Dictionary = tech.get("cost", {})
	if int(GameState.resources.get("craft", 0)) < int(cost.get("craft", 0)):
		return false
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		if int(GameState.resources.get(str(key_v), 0)) < int(mats[key_v]):
			return false
	return true


static func missing_prereq_count(id: String) -> int:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var n := 0
	for pre_v in tech.get("prereq", []):
		if not GameState.tech_done.has(str(pre_v)):
			n += 1
	return n


static func related(id: String) -> Dictionary:
	var mark := {}
	if id == "":
		return mark
	var stack: Array = [id]
	while not stack.is_empty():
		var cur := str(stack.pop_back())
		if mark.has(cur):
			continue
		mark[cur] = true
		var tech: Dictionary = DataDB.tech_by_id.get(cur, {})
		for pre_v in tech.get("prereq", []):
			stack.append(str(pre_v))
	for tech_v in DataDB.techs:
		var tech2: Dictionary = tech_v
		var tid := str(tech2.get("id", ""))
		for pre_v in tech2.get("prereq", []):
			if str(pre_v) == id:
				_mark_down(tid, mark)
	return mark


static func passes_filter(id: String, branch: String, only_ready: bool, practice_only: bool, query: String) -> bool:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if branch != "" and str(tech.get("branch", "")) != branch:
		return false
	if only_ready and view_state(id) != "available" and view_state(id) != "queued":
		return false
	if practice_only and str(tech.get("practice", "")) == "":
		return false
	if query != "" and str(tech.get("name", "")).find(query) < 0 and id.find(query) < 0:
		return false
	return true


static func uses_material(id: String, mat: String) -> bool:
	if mat == "":
		return false
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var mats: Dictionary = tech.get("materials", {})
	return mats.has(mat)


static func _mark_down(id: String, mark: Dictionary) -> void:
	if mark.has(id):
		return
	mark[id] = true
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		for pre_v in tech.get("prereq", []):
			if str(pre_v) == id:
				_mark_down(str(tech.get("id", "")), mark)


static func _trial(id: String) -> Dictionary:
	for trial_v in GameState.tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) == id:
			return trial
	return {}


static func _blocked_text(id: String) -> String:
	if GameState.practice_gate_on and GameState.tech_state(id) == "blueprint" and not GameState.practice_ok(id):
		return "缺实践 %d/%d" % [GameState.practice_have(id), GameState.practice_need(id)]
	if GameState.tech_designing == id and GameState.battery <= 0:
		return "停电"
	var craft_cost := int(DataDB.tech_by_id.get(id, {}).get("cost", {}).get("craft", 0))
	if int(GameState.resources.get("craft", 0)) < craft_cost:
		return "缺匠"
	var short := _short_material(id)
	if not short.is_empty():
		return "缺%s %d/%d" % [str(short.get("name", "")), int(short.get("have", 0)), int(short.get("need", 0))]
	var practice := practice_row(id)
	if str(practice.get("label", "")) != "" and not bool(practice.get("ok", false)):
		return "缺实践 %d/%d" % [int(practice.get("have", 0)), int(practice.get("need", 0))]
	return "受阻"


static func _blocked_jump(id: String) -> String:
	if GameState.practice_gate_on and GameState.tech_state(id) == "blueprint" and not GameState.practice_ok(id):
		return "city"
	if GameState.tech_designing == id and GameState.battery <= GameState.standby_cost():
		return "console"
	if not _short_material(id).is_empty():
		return "industry"
	var practice := practice_row(id)
	if GameState.practice_gate_on and str(practice.get("label", "")) != "" and not bool(practice.get("ok", false)):
		return "city"
	return "workshop"


static func _short_material(id: String) -> Dictionary:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var mats: Dictionary = tech.get("materials", {})
	var worst: Dictionary = {}
	var worst_gap := 0
	for key_v in mats.keys():
		var key := str(key_v)
		var need := int(mats[key_v])
		var have := int(GameState.resources.get(key, 0))
		if have < need and need - have > worst_gap:
			worst_gap = need - have
			worst = {"key": key, "name": str(MAT_NAME.get(key, key)), "have": have, "need": need}
	return worst


static func _missing_sheet(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		var pre := str(pre_v)
		if GameState.tech_done.has(pre) or GameState.tech_blueprints.has(pre):
			continue
		var pre_tech: Dictionary = DataDB.tech_by_id.get(pre, {})
		return "需%s图纸" % str(pre_tech.get("name", pre))
	return "前置未齐"


static func _lock_label(era: int) -> String:
	if era >= 3:
		return "第 68 回合开"
	if era == 2:
		return "第 31 回合开"
	return "未开"


static func short_name(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var given := str(tech.get("short", ""))
	if given != "":
		return given
	var name := str(tech.get("name", id))
	if name.length() <= 5:
		return name
	return name.substr(0, 5)


static func _trial_turns(id: String) -> int:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var cost: Dictionary = tech.get("cost", {})
	return maxi(2, int(ceil(float(int(cost.get("craft", 8))) / 12.0)))


static func _first_missing(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		var pre := str(pre_v)
		if not GameState.tech_done.has(pre):
			return pre
	return ""


static func corner(id: String) -> String:
	var state := view_state(id)
	if state == "blocked":
		return "阻"
	if state == "done":
		return "√"
	if state == "designing":
		return "设"
	if state == "trial":
		return "试"
	if state == "blueprint":
		return "图"
	if state == "noprereq":
		return "缺%d" % missing_prereq_count(id)
	if state == "locked":
		return "锁"
	return ""


static func card_status(id: String) -> String:
	var state := view_state(id)
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if state == "noprereq":
		return "缺前置 · 还差 %d 项" % missing_prereq_count(id)
	if state == "available":
		if GameState.tech_designing == "":
			return "可设计 · 设计槽空着"
		return "可设计 · 设计槽占用，可排队（%d/%d）" % [GameState.tech_queue.size(), GameState.QUEUE_CAP]
	if state == "queued":
		return "在队列第 %d 位" % queue_index(id)
	if state == "designing":
		var left := maxi(0, GameState.design_need(id) - GameState.tech_design_prog)
		return "设计中 %d/%d 电 · 约 %d 回合" % [GameState.tech_design_prog, GameState.design_need(id), int(ceil(float(left) / 10.0))]
	if state == "blueprint":
		if GameState.tech_trials.size() < GameState.trial_slots():
			return "有图纸 · 可以开试制"
		return "有图纸 · 等试制槽"
	if state == "blocked":
		return _blocked_text(id)
	if state == "trial":
		var trial := _trial(id)
		return "试制中 第 %d/%d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))]
	if state == "done":
		return "已完成"
	var era := int(tech.get("era", 1))
	if era >= 3:
		var total := era_progress(2)
		return "时代三 · 第 68 回合或本时代完成 11/%d 开放" % int(total.y)
	return "时代二 · 第 31 回合开"


static func card_action(id: String) -> Dictionary:
	var state := view_state(id)
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var out := {"text": "", "enabled": false, "hint": "", "jump": ""}
	if state == "available":
		if GameState.tech_designing == "":
			out["text"] = "开始设计"
			out["enabled"] = true
		elif GameState.tech_queue.size() >= GameState.QUEUE_CAP:
			out["text"] = "加入队列"
			out["hint"] = "队列已满 3/3"
		else:
			out["text"] = "加入队列"
			out["enabled"] = true
			out["hint"] = "排第 %d 位 · 换下当前设计" % (GameState.tech_queue.size() + 1)
			out["jump"] = "swap"
		return out
	if state == "queued":
		out["text"] = "移出队列"
		out["enabled"] = true
		if queue_index(id) > 1:
			out["hint"] = "提前一位"
			out["jump"] = "bump"
		return out
	if state == "designing":
		out["text"] = "暂停设计"
		out["enabled"] = true
		return out
	if state == "noprereq":
		var miss := _first_missing(id)
		var miss_tech: Dictionary = DataDB.tech_by_id.get(miss, {})
		out["text"] = "开始设计"
		out["hint"] = "先完成：%s" % str(miss_tech.get("name", miss))
		out["jump"] = miss
		return out
	if state == "blueprint":
		out["text"] = "开始试制"
		var cost: Dictionary = tech.get("cost", {})
		var paid := "开工付清 匠 %d" % int(cost.get("craft", 0))
		var mats: Dictionary = tech.get("materials", {})
		for key_v in mats.keys():
			paid += "、%s %d" % [str(MAT_NAME.get(str(key_v), str(key_v))), int(mats[key_v])]
		out["hint"] = paid
		if GameState.tech_trials.size() >= GameState.trial_slots():
			out["hint"] = "试制槽 %d/%d 满" % [GameState.tech_trials.size(), GameState.trial_slots()]
		elif can_afford(id):
			out["enabled"] = true
		return out
	if state == "blocked":
		out["text"] = "去补齐"
		out["enabled"] = true
		out["hint"] = _blocked_text(id)
		out["jump"] = "blocked"
		return out
	if state == "trial":
		var trial := _trial(id)
		out["text"] = "查看试制"
		out["enabled"] = true
		out["hint"] = "第 %d/%d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))]
		out["jump"] = "workshop"
		return out
	if state == "done":
		if unlocks_building(id):
			out["text"] = "去推广"
			out["enabled"] = true
			out["jump"] = "city"
		else:
			out["hint"] = "已完成"
		return out
	out["text"] = "开始设计"
	out["hint"] = _lock_label(int(tech.get("era", 1)))
	return out


static func target_preview(id: String) -> Dictionary:
	var chain: Array = []
	for id_v in spine(id):
		var step := str(id_v)
		if not GameState.tech_done.has(step):
			chain.append(step)
	var now: Array = []
	var later: Array = []
	_preview_collect(id, now, later, {})
	now.sort_custom(func(a: String, b: String) -> bool: return GameState.design_need(a) < GameState.design_need(b))
	return {
		"chain": chain,
		"now": now,
		"later": later.size(),
		"room": GameState.QUEUE_CAP - GameState.tech_queue.size(),
		"old_target": GameState.tech_target,
	}


static func _preview_collect(id: String, now: Array, later: Array, seen: Dictionary) -> void:
	if id == "" or seen.has(id):
		return
	seen[id] = true
	if GameState.tech_done.has(id) or GameState.tech_blueprints.has(id):
		return
	if GameState._is_trialing(id) or GameState.tech_designing == id:
		return
	if view_state(id) == "available":
		if not GameState.tech_queue.has(id):
			now.append(id)
		return
	later.append(id)
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		_preview_collect(str(pre_v), now, later, seen)


static func route_start(target: String) -> String:
	var chain := spine(target)
	if chain.is_empty():
		return ""
	return str(chain[0])


static func _site_key(label: String) -> String:
	if label.contains("炼钢"):
		return "steel"
	if label.contains("蒸汽"):
		return "steam"
	if label.contains("焦炉"):
		return "coke"
	if label.contains("煤场"):
		return "coal"
	if label.contains("水磨") or label.contains("河畔"):
		return "mill"
	return "other"


static func _open_rank(id: String) -> int:
	var state := GameState.tech_state(id)
	if state == "trial":
		return 50
	if state == "designing":
		return 40
	if state == "blueprint":
		return 30
	if state == "queued":
		return 20
	return 10 + missing_prereq_count(id)


static func _collect_ready(id: String, into: Array, seen: Dictionary) -> void:
	if seen.has(id):
		return
	seen[id] = true
	if GameState.tech_done.has(id) or GameState.tech_blueprints.has(id):
		return
	if GameState.tech_state(id) == "trial" or GameState.tech_designing == id:
		return
	if view_state(id) == "available":
		into.append(id)
		return
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	for pre_v in tech.get("prereq", []):
		_collect_ready(str(pre_v), into, seen)


static func _path_step(target: String) -> Dictionary:
	var low := false
	for id_v in spine(target):
		var id := str(id_v)
		var state := view_state(id)
		if state == "blueprint" and GameState.tech_trials.size() < GameState.trial_slots():
			var tech: Dictionary = DataDB.tech_by_id.get(id, {})
			return _suggest(id, "trial", "把「%s」送去试制" % str(tech.get("name", id)), "目标路径上，这一份图纸可以开槽了。", low)
		if state == "available":
			var tech2: Dictionary = DataDB.tech_by_id.get(id, {})
			return _suggest(id, "design", "把「%s」排进设计" % str(tech2.get("name", id)), "顺着目标往下排，这一项的前置已经齐了。", low)
	return {}


static func _suggest(id: String, kind: String, title: String, reason: String, low: bool) -> Dictionary:
	var why := reason
	if low:
		why = "电低。先做「%s」。" % str(DataDB.tech_by_id.get(id, {}).get("name", id))
	return {"id": id, "kind": kind, "title": title, "reason": why, "telegraph": low}
