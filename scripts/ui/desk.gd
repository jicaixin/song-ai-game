class_name Desk
extends Control

const Kit = preload("res://scripts/ui/kit.gd")

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
const STATE_NAME := {
	"locked": "时代未开",
	"noprereq": "缺前置",
	"available": "可设计",
	"queued": "排队",
	"designing": "设计中",
	"nopower": "停电",
	"blueprint": "图纸已成",
	"trial": "试制中",
	"blocked": "试制受阻",
	"done": "已推广",
}
const TALENTS := [
	["燕肃", "yan_su", "E01、K01、K02、E05", "追日支架、齿轮水磨、水排、水轮"],
	["毕昇", "bi_sheng", "C03", "活字与防伪交子"],
	["种世衡", "zhong_shiheng", "M02", "堡寨筑城"],
	["冶铁匠师", "artisan_iron", "I04、I07", "焦炭冶铁、坩埚炼钢"],
	["窑工匠师", "artisan_kiln", "I05、I06", "耐火砖、透明琉璃"],
	["船匠匠师", "artisan_ship", "C05", "海船与罗盘航运"],
	["曾公亮", "zeng_gongliang", "M05", "火药精炼"],
	["苏颂", "su_song", "K05、K06、X01", "增速齿轮、镗床、豆沙包二号"],
]

var mode := ""
var writing := false
var city_id := ""
var picked := ""
var dim: ColorRect
var host: Control
var detail: PanelContainer
var debug_btns := {}


func _ready() -> void:
	theme = Settings.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	EventBus.state_changed.connect(_on_state)


func is_open() -> bool:
	return mode != ""


func open(which: String) -> void:
	mode = which
	visible = true
	_fill()


func open_save(write: bool) -> void:
	writing = write
	open("save")


func open_city(id: String) -> void:
	city_id = id
	open("city")


func shut() -> void:
	mode = ""
	visible = false
	_wipe()


func _on_state() -> void:
	if mode != "":
		_fill()


func _wipe() -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.free()
	debug_btns = {}
	detail = null


func _fill() -> void:
	var keep_pick := picked
	_wipe()
	picked = keep_pick
	var wide := 1180.0 if mode == "tech" else 1040.0
	var high := 660.0 if mode == "tech" else 620.0
	var paper := _place_paper(wide, high)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.add_child(box)
	if mode == "tech":
		_page_tech(box)
	elif mode == "console":
		_page_console(box)
	elif mode == "workshop":
		_page_workshop(box)
	elif mode == "industry":
		_page_industry(box)
	elif mode == "talent":
		_page_talent(box)
	elif mode == "court":
		_page_court(box)
	elif mode == "codex":
		_page_codex(box)
	elif mode == "save":
		_page_save(box)
	elif mode == "city":
		_page_city(box)
	elif mode == "diplomacy":
		_page_diplomacy(box)
	elif mode == "events":
		_page_events(box)


func _place_paper(wide: float, high: float) -> PanelContainer:
	var paper := Kit.panel("PaperPanel")
	paper.position = Vector2((1280.0 - wide) * 0.5, (720.0 - high) * 0.5)
	paper.size = Vector2(wide, high)
	paper.custom_minimum_size = Vector2(wide, high)
	paper.clip_contents = true
	host.add_child(paper)
	return paper


func _header(parent: VBoxContainer, title: String, close_key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var ribbon := Kit.panel("HeaderRibbon")
	ribbon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ribbon)
	var lab := Kit.label(title, "H2Label")
	lab.add_theme_color_override("font_color", Color("fbf5e6"))
	ribbon.add_child(lab)
	var close := Kit.button("关闭", "Button")
	close.custom_minimum_size = Vector2(88, 40)
	close.pressed.connect(shut)
	row.add_child(close)
	debug_btns["desk_close"] = close
	if close_key != "":
		debug_btns[close_key] = close


func _page_tech(box: VBoxContainer) -> void:
	_header(box, "格物图", "tech_close")
	box.add_child(Kit.label("设计耗电，试制耗匠与材料。走完第 30 回合开时代二，走完第 75 回合开时代三。", "CaptionLabel"))
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	box.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(720, 500)
	split.add_child(scroll)
	var tree := VBoxContainer.new()
	tree.add_theme_constant_override("separation", 6)
	scroll.add_child(tree)
	_build_tree(tree)
	detail = Kit.panel("PlainPanel")
	detail.custom_minimum_size = Vector2(320, 500)
	split.add_child(detail)
	_fill_detail()


func _build_tree(tree: VBoxContainer) -> void:
	var head := HBoxContainer.new()
	tree.add_child(head)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(76, 18)
	head.add_child(pad)
	for col in range(1, 14):
		var cap := ""
		for st_v in DataDB.stages:
			var st: Dictionary = st_v
			if int(st.get("col_from", 0)) == col:
				cap = "%s %s" % [str(st.get("name", "")), str(st.get("subtitle", ""))]
		var lab := Kit.label(cap, "SmallLabel")
		lab.custom_minimum_size = Vector2(220, 18)
		lab.clip_text = true
		head.add_child(lab)
	for b_v in DataDB.branches:
		var branch: Dictionary = b_v
		var bid := str(branch.get("id", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		tree.add_child(row)
		var mark := VBoxContainer.new()
		mark.custom_minimum_size = Vector2(72, 36)
		row.add_child(mark)
		mark.add_child(Kit.icon_rect("branch_%s" % bid, 28))
		mark.add_child(Kit.label(str(branch.get("name", "")), "SmallLabel"))
		for col in range(1, 14):
			var cell := VBoxContainer.new()
			cell.custom_minimum_size = Vector2(220, 4)
			cell.add_theme_constant_override("separation", 4)
			row.add_child(cell)
			var found: Array = []
			for tech_v in DataDB.techs:
				var tech: Dictionary = tech_v
				if str(tech.get("branch", "")) == bid and int(tech.get("col", 0)) == col:
					found.append(tech)
			found.sort_custom(_slot_less)
			for tech_v2 in found:
				var tech2: Dictionary = tech_v2
				cell.add_child(_node_button(tech2))


func _slot_less(a: Dictionary, b: Dictionary) -> bool:
	return _slot_rank(str(a.get("slot", "c"))) < _slot_rank(str(b.get("slot", "c")))


func _slot_rank(slot: String) -> int:
	if slot == "u":
		return 0
	if slot == "c":
		return 1
	return 2


func _node_button(tech: Dictionary) -> Control:
	var id := str(tech.get("id", ""))
	var state := GameState.tech_state(id)
	var wrap := VBoxContainer.new()
	var b := Kit.button(str(tech.get("name", "")), Kit.state_variation("TechNodeButton", state))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = Kit.icon("tech_%s" % id)
	b.expand_icon = true
	b.clip_text = false
	b.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(212, 40)
	b.pressed.connect(_pick_tech.bind(id))
	wrap.add_child(b)
	if state == "designing" or state == "nopower":
		var bar := ProgressBar.new()
		bar.theme_type_variation = "NodeBarNoPower" if state == "nopower" else "NodeBarDesign"
		bar.max_value = float(GameState.design_need(id))
		bar.value = float(GameState.tech_design_prog)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 6)
		wrap.add_child(bar)
	elif state == "trial":
		var trial := _trial(id)
		var bar := ProgressBar.new()
		bar.theme_type_variation = "NodeBarTrial"
		bar.max_value = float(maxi(1, int(trial.get("need", 1))))
		bar.value = float(int(trial.get("prog", 0)))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 6)
		wrap.add_child(bar)
	return wrap


func _pick_tech(id: String) -> void:
	picked = id
	_fill_detail()


func _fill_detail() -> void:
	if detail == null:
		return
	for child in detail.get_children():
		detail.remove_child(child)
		child.free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	detail.add_child(box)
	if picked == "" or not DataDB.tech_by_id.has(picked):
		box.add_child(Kit.label("点一项。", "BodyLabel"))
		box.add_child(Kit.label("青的是设计，赭的是试制，金的是已经推广。", "CaptionLabel"))
		return
	var tech: Dictionary = DataDB.tech_by_id[picked]
	var state := GameState.tech_state(picked)
	box.add_child(Kit.icon_rect("tech_%s" % picked, 40))
	box.add_child(Kit.label(str(tech.get("name", "")), "H2Label"))
	box.add_child(Kit.label("%s · %s · %s" % [picked, _branch_full(str(tech.get("branch", ""))), str(STATE_NAME.get(state, state))], "SmallLabel"))
	box.add_child(Kit.label(str(tech.get("effect", "")), "BodyLabel"))
	var cost: Dictionary = tech.get("cost", {})
	box.add_child(Kit.label("设计 %d 电 · 试制 %d 匠" % [int(cost.get("power", 0)), int(cost.get("craft", 0))], "CaptionLabel"))
	var mats := _mat_text(tech.get("materials", {}))
	if mats != "":
		box.add_child(Kit.label("材料 " + mats, "CaptionLabel"))
	var practice := str(tech.get("practice", ""))
	if practice != "":
		box.add_child(Kit.label("实践 " + practice, "CaptionLabel"))
	var talent := str(tech.get("talent", ""))
	if talent != "":
		box.add_child(Kit.label("可请 " + talent, "CaptionLabel"))
	if state == "designing" or state == "nopower":
		var need := GameState.design_need(picked)
		var left := maxi(0, need - GameState.tech_design_prog)
		var turns := int(ceil(float(left) / 10.0))
		var extra := ""
		if GameState.firmware_done.has("D03"):
			extra = "，约 %d 回合" % turns
		box.add_child(Kit.label("进度 %d / %d%s" % [GameState.tech_design_prog, need, extra], "SmallLabel"))
	elif state == "trial":
		var trial := _trial(picked)
		box.add_child(Kit.label("试制 %d / %d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))], "SmallLabel"))
	box.add_child(Kit.label(str(tech.get("history", "")), "CaptionLabel"))
	box.add_child(Kit.label("能跳过：" + str(tech.get("skip", "")), "CaptionLabel"))
	box.add_child(Kit.label("跳不过：" + str(tech.get("noskip", "")), "CaptionLabel"))
	if state == "available":
		var act := Kit.button("开始设计" if GameState.tech_designing == "" else "加入队列", "PrimaryButton")
		act.pressed.connect(func() -> void: GameState.start_design(picked))
		box.add_child(act)
	elif state == "queued":
		var act := Kit.button("移出队列", "Button")
		act.pressed.connect(func() -> void: GameState.remove_queued(picked))
		box.add_child(act)
	elif state == "designing" or state == "nopower":
		var act := Kit.button("取消设计", "Button")
		act.pressed.connect(func() -> void: GameState.cancel_design())
		box.add_child(act)
	elif state == "blueprint":
		var act := Kit.button("投入试制", "PrimaryButton")
		act.pressed.connect(func() -> void: GameState.start_trial(picked))
		box.add_child(act)


func _page_console(box: VBoxContainer) -> void:
	_header(box, "豆沙包控制台", "")
	var lead := HBoxContainer.new()
	lead.add_theme_constant_override("separation", 12)
	box.add_child(lead)
	var full := TextureRect.new()
	full.texture = Kit.portrait_full("doushabao", Kit.mood_key(GameState.advisor_mood))
	if full.texture == null:
		full.texture = Kit.portrait_bust("doushabao", Kit.mood_key(GameState.advisor_mood))
	full.custom_minimum_size = Vector2(112, 156)
	full.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	full.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lead.add_child(full)
	var lead_text := VBoxContainer.new()
	lead_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lead.add_child(lead_text)
	var cap := GameState.battery_cap()
	var standby := GameState.standby_cost()
	lead_text.add_child(Kit.label("电池 %d / %d    本月发电 %d    待机 %d" % [GameState.battery, cap, GameState.last_gen, standby], "H3Label"))
	var bar := ProgressBar.new()
	bar.theme_type_variation = "NodeBarDesign"
	bar.max_value = float(maxi(1, cap))
	bar.value = float(GameState.battery)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	lead_text.add_child(bar)
	lead_text.add_child(Kit.label(_power_line(), "BodyLabel"))
	lead_text.add_child(Kit.label("设计每回合最多抽 10 电。固件写入立刻耗电。", "CaptionLabel"))
	box.add_child(_facility_row())
	box.add_child(Kit.label("固件", "H3Label"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for fw_v in DataDB.firmware:
		var fw: Dictionary = fw_v
		list.add_child(_firmware_card(fw))


func _power_line() -> String:
	var season := Calendar.season(GameState.month)
	var s := float(DataDB.balance.get("season", {}).get(season, 1.0))
	var wx: Dictionary = DataDB.balance.get("weather", {}).get(GameState.weather_id, {})
	var w := float(wx.get("factor", 1.0))
	var base := int(DataDB.balance.get("power", {}).get("base", 36))
	var line := "发电 %d × %s %.2f × %s %.2f" % [base, str(Calendar.SEASON_NAME.get(season, season)), s, str(wx.get("name", "")), w]
	if GameState.tech_done.has("E01"):
		line += " × 追日 1.15"
	if GameState.firmware_done.has("D01"):
		line += "。待机已由节能调度降到 2"
	return line


func _firmware_card(fw: Dictionary) -> PanelContainer:
	var id := str(fw.get("id", ""))
	var pre := str(fw.get("prereq", ""))
	var kind := "FirmwareAvailable"
	if GameState.firmware_done.has(id):
		kind = "FirmwareDone"
	elif pre != "" and not GameState.firmware_done.has(pre):
		kind = "FirmwareLocked"
	var card := Kit.panel(kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(Kit.icon_rect("fw_%s" % id, 32))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Kit.label("%s  %s" % [id, str(fw.get("name", ""))], "H3Label"))
	text.add_child(Kit.label(str(fw.get("effect", "")), "CaptionLabel"))
	var need := "耗电 %d" % int(fw.get("power", 0))
	if pre != "":
		need += " · 需要 " + pre
	text.add_child(Kit.label(need, "SmallLabel"))
	if kind == "FirmwareAvailable":
		var act := Kit.button("写入", "PrimaryButton")
		act.custom_minimum_size = Vector2(88, 36)
		act.pressed.connect(GameState.write_firmware.bind(id))
		row.add_child(act)
	elif kind == "FirmwareDone":
		row.add_child(Kit.label("已写入", "SmallLabel"))
	return card


func _page_workshop(box: VBoxContainer) -> void:
	_header(box, "匠作院", "")
	var open_slots := GameState.trial_slots()
	box.add_child(Kit.label("试制槽 %d / %d。开槽时一次扣掉材料和匠。第二槽要在朝堂颁布格物院。" % [GameState.tech_trials.size(), open_slots], "BodyLabel"))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	box.add_child(slots)
	for i in 2:
		if i < GameState.tech_trials.size():
			slots.add_child(_trial_slot(GameState.tech_trials[i]))
		elif i < open_slots:
			slots.add_child(_empty_slot("空槽", "设计完成的图纸从下面开进来。"))
		else:
			slots.add_child(_empty_slot("未开", "格物院还没颁布，这一槽锁着。"))
	box.add_child(Kit.label("图纸", "H3Label"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if GameState.tech_blueprints.is_empty():
		list.add_child(Kit.label("还没有图纸。格物图里设计做完，题目会堆在这里。", "BodyLabel"))
	for id_v in GameState.tech_blueprints:
		var id := str(id_v)
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		var card := Kit.panel("BlueprintCard")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		row.add_child(Kit.icon_rect("tech_%s" % id, 32))
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		text.add_child(Kit.label(str(tech.get("name", id)), "H3Label"))
		text.add_child(Kit.label(_trial_cost(tech), "CaptionLabel"))
		var act := Kit.button("开槽", "PrimaryButton")
		act.custom_minimum_size = Vector2(88, 36)
		act.disabled = GameState.tech_trials.size() >= open_slots
		act.pressed.connect(GameState.start_trial.bind(id))
		row.add_child(act)
		list.add_child(card)


func _page_industry(box: VBoxContainer) -> void:
	_header(box, "百工图", "")
	box.add_child(Kit.label("原料到成品的路径是真的。产量还没接上城池，推广了也只是把这一格点亮。", "CaptionLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	_chain(list, "铁到钢", [["铁矿", "", "raw"], ["灌钢", "I01", "proc"], ["焦炭", "I04", "proc"], ["坩埚钢", "I07", "dest"]])
	_chain(list, "煤与矿", [["煤", "", "raw"], ["通风排水", "I02", "proc"], ["蒸汽抽水", "K07", "dest"]])
	_chain(list, "粮到电", [["粮", "", "raw"], ["手摇发电", "E03", "power"], ["牛转", "K05", "proc"], ["水轮", "E05", "power"]])
	_chain(list, "铜", [["铜矿", "", "raw"], ["胆铜", "I03", "proc"], ["铜线", "E02", "proc"], ["电堆", "E04", "power"]])


func _chain(parent: VBoxContainer, title: String, steps: Array) -> void:
	parent.add_child(Kit.label(title, "H3Label"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var first := true
	for step_v in steps:
		var step: Array = step_v
		if not first:
			row.add_child(Kit.label("→", "H2Label"))
		first = false
		row.add_child(_chain_card(str(step[0]), str(step[1]), str(step[2])))


func _chain_card(title: String, tech_id: String, role: String) -> PanelContainer:
	var done := tech_id == "" or GameState.tech_done.has(tech_id)
	var kind := "ChainRaw"
	var state := "原料"
	if role == "power":
		kind = "ChainPower" if done else "ChainLocked"
		state = "已接电" if done else "还没推广"
	elif role == "dest":
		kind = "ChainDest" if done else "ChainLocked"
		state = "已推广" if done else "还没推广"
	elif role == "proc":
		kind = "ChainProd" if done else "ChainLocked"
		state = "已推广" if done else "还没推广"
	var card := Kit.panel(kind)
	card.custom_minimum_size = Vector2(148, 78)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)
	if tech_id != "":
		inner.add_child(Kit.icon_rect("tech_%s" % tech_id, 22))
	var name := Kit.label(title, "H3Label")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name)
	inner.add_child(Kit.label(state, "SmallLabel"))
	return card


func _facility_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var solar_kind := "FacilityCardAlert" if GameState.battery <= GameState.standby_cost() else "FacilityCard"
	row.add_child(_facility_card(solar_kind, "太阳能板", "本月 +%d" % GameState.last_gen, "在线"))
	var hand_on := GameState.tech_done.has("E03")
	row.add_child(_facility_card(
		"FacilityCard" if hand_on else "FacilityCardOff",
		"人力发电坊",
		"匠可以转成电" if hand_on else "先推广磁钢手摇",
		"还没接入结算" if hand_on else "未建"
	))
	var hydro_on := GameState.tech_done.has("E05")
	row.add_child(_facility_card(
		"FacilityCard" if hydro_on else "FacilityCardOff",
		"水轮电站",
		"设计是 +12 电" if hydro_on else "先推广水轮发电",
		"还没接入结算" if hydro_on else "未建"
	))
	row.add_child(_facility_card("FacilityCard", "蓄电池", "容量 %d" % GameState.battery_cap(), "%d / %d" % [GameState.battery, GameState.battery_cap()]))
	return row


func _facility_card(kind: String, title: String, body: String, state: String) -> PanelContainer:
	var card := Kit.panel(kind)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(160, 88)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)
	inner.add_child(Kit.label(title, "H3Label"))
	inner.add_child(Kit.label(body, "CaptionLabel"))
	inner.add_child(Kit.label(state, "SmallLabel"))
	return card


func _trial_slot(trial: Dictionary) -> PanelContainer:
	var id := str(trial.get("id", ""))
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var card := Kit.panel("SlotActive")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(280, 96)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	inner.add_child(head)
	head.add_child(Kit.icon_rect("tech_%s" % id, 28))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	text.add_child(Kit.label(str(tech.get("name", id)), "H3Label"))
	text.add_child(Kit.label("试制 %d / %d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))], "CaptionLabel"))
	var bar := ProgressBar.new()
	bar.theme_type_variation = "NodeBarTrial"
	bar.max_value = float(maxi(1, int(trial.get("need", 1))))
	bar.value = float(int(trial.get("prog", 0)))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	inner.add_child(bar)
	return card


func _empty_slot(title: String, body: String) -> PanelContainer:
	var locked := title == "未开"
	var card := Kit.panel("SlotLocked" if locked else "SlotEmpty")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(280, 96)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	inner.add_child(Kit.label(title, "H3Label"))
	var note := Kit.label(body, "CaptionLabel")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(note)
	return card


func _page_talent(box: VBoxContainer) -> void:
	_header(box, "贤才录", "")
	box.add_child(Kit.label("名字和能加速的科技是真的。延揽还没接上试制速度。", "CaptionLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for row_v in TALENTS:
		var row: Array = row_v
		var card := Kit.panel("TalentCard")
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		card.add_child(line)
		var face := TextureRect.new()
		face.texture = Kit.portrait_frame(str(row[1]), "normal")
		face.custom_minimum_size = Vector2(64, 64)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(face)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		text.add_child(Kit.label(str(row[0]), "H3Label"))
		text.add_child(Kit.label(str(row[3]), "CaptionLabel"))
		text.add_child(Kit.label(_talent_state(str(row[2])), "SmallLabel"))
		grid.add_child(card)


func _talent_state(ids: String) -> String:
	var bits := ids.split("、")
	var done := 0
	for id in bits:
		if GameState.tech_done.has(id):
			done += 1
	if done == 0:
		return "相关科技都还没推广"
	if done == bits.size():
		return "相关科技都已推广"
	return "已推广 %d / %d" % [done, bits.size()]


func _page_court(box: VBoxContainer) -> void:
	_header(box, "朝堂 · 制度改革", "")
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	box.add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(280, 0)
	split.add_child(left)
	var scene := TextureRect.new()
	scene.texture = Kit.tex("res://ui/art/portraits/full/emperor_zhaozhen_court_scene.png")
	scene.custom_minimum_size = Vector2(260, 150)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(scene)
	var portrait := TextureRect.new()
	portrait.texture = Kit.emperor_tex("court")
	portrait.custom_minimum_size = Vector2(260, 280)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(portrait)
	var plate := Kit.panel("NamePlate")
	plate.add_child(Kit.label("赵祯", "H3Label"))
	left.add_child(plate)
	left.add_child(Kit.label("皇威 %d · 钱 %d" % [GameState.morale, int(GameState.resources.get("money", 0))], "SmallLabel"))
	_court_ministers(left)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for ed_v in DataDB.edicts:
		var edict: Dictionary = ed_v
		list.add_child(_edict_row(edict))


func _court_ministers(parent: VBoxContainer) -> void:
	parent.add_child(Kit.label("在殿上", "SmallLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var people := [
		["fan_zhongyan", "serious", "范仲淹"],
		["han_qi", "normal", "韩琦"],
		["di_qing", "normal", "狄青"],
		["taijian", "normal", "台谏"],
	]
	for person_v in people:
		var person: Array = person_v
		var col := VBoxContainer.new()
		row.add_child(col)
		var face := TextureRect.new()
		face.texture = Kit.portrait_bust(str(person[0]), str(person[1]))
		face.custom_minimum_size = Vector2(64, 80)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(face)
		col.add_child(Kit.label(str(person[2]), "CaptionLabel"))


func _page_diplomacy(box: VBoxContainer) -> void:
	_header(box, "外交", "")
	box.add_child(Kit.label("遣使一次 80 钱，当月不可再派。岁币每回合 40 钱。榷场每回合进账 6 钱。态度先记着，仗还是地图上的仗。", "CaptionLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for fac_v in DataDB.factions.values():
		var fac: Dictionary = fac_v
		if str(fac.get("id", "")) == "song" or bool(fac.get("player", false)):
			continue
		list.add_child(_faction_row(fac))


func _faction_row(fac: Dictionary) -> PanelContainer:
	var id := str(fac.get("id", ""))
	var card := Kit.panel("PlainPanel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(72, 96)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := _ruler_portrait(id)
	if who.is_empty():
		face.texture = Kit.piece(_banner_key(id))
	else:
		face.texture = Kit.portrait_bust(str(who[0]), str(who[1]))
	row.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var attitude := int(GameState.relations.get(id, 0))
	text.add_child(Kit.label("%s · %s" % [str(fac.get("name", "")), str(fac.get("ruler", ""))], "H3Label"))
	text.add_child(Kit.label("态度 %d · %s" % [attitude, _attitude_name(attitude)], "BodyLabel"))
	if who.is_empty():
		text.add_child(Kit.label("这位还没有画像，先以国号相见。", "CaptionLabel"))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	text.add_child(buttons)
	var envoy := Kit.button("遣使", "Button")
	envoy.pressed.connect(GameState.send_envoy.bind(id))
	buttons.add_child(envoy)
	if id == "xia" or id == "liao":
		var sub_label := "停岁币" if GameState.subsidies.has(id) else "许岁币"
		var sub := Kit.button(sub_label, "PrimaryButton")
		sub.pressed.connect(GameState.toggle_subsidy.bind(id))
		buttons.add_child(sub)
		var market_label := "闭榷场" if GameState.markets.has(id) else "开榷场"
		var market := Kit.button(market_label, "Button")
		market.pressed.connect(GameState.toggle_market.bind(id))
		buttons.add_child(market)
	return card


func _banner_key(fid: String) -> String:
	if fid == "gusiluo":
		return "banner_tubo"
	return "banner_%s" % fid


func _ruler_portrait(fid: String) -> Array:
	if fid == "xia":
		return ["li_yuanhao", "angry" if int(GameState.relations.get(fid, 0)) < -20 else "normal"]
	if fid == "liao":
		return ["liao_xingzong", "smug"]
	return []


func _attitude_name(n: int) -> String:
	if n <= -40:
		return "敌对"
	if n <= -10:
		return "冷淡"
	if n >= 30:
		return "和睦"
	if n >= 10:
		return "尚可"
	return "平"


func _page_events(box: VBoxContainer) -> void:
	_header(box, "时事", "")
	box.add_child(Kit.label("到了日子才掀开。选定之后记在存档里，不重演。", "CaptionLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var any := false
	for ev_v in DataDB.events:
		var ev: Dictionary = ev_v
		if GameState.turn < int(ev.get("turn", 1)):
			continue
		any = true
		list.add_child(_event_card(ev))
	if not any:
		list.add_child(Kit.label("这个月没有新的奏报。", "BodyLabel"))


func _event_card(ev: Dictionary) -> PanelContainer:
	var id := str(ev.get("id", ""))
	var card := Kit.panel("PlainPanel")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(140, 200)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pid := str(ev.get("who", ""))
	var expr := str(ev.get("expr", "normal"))
	face.texture = Kit.portrait_full(pid, expr)
	if face.texture == null:
		face.texture = Kit.portrait_bust(pid, expr)
	row.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Kit.label("%s · %s" % [str(ev.get("title", "")), str(ev.get("name", ""))], "H3Label"))
	var body := Kit.label(str(ev.get("body", "")), "BodyLabel")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(body)
	var comment := Kit.label(str(ev.get("comment", "")), "CaptionLabel")
	comment.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(comment)
	var picked_choice := str(GameState.event_choice.get(id, ""))
	if picked_choice != "":
		text.add_child(Kit.label("已决：" + _choice_label(ev, picked_choice), "SmallLabel"))
		return card
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	text.add_child(buttons)
	var choices: Array = ev.get("choices", [])
	var first := true
	for choice_v in choices:
		var choice: Dictionary = choice_v
		var cid := str(choice.get("id", ""))
		var act := Kit.button(str(choice.get("label", cid)), "PrimaryButton" if first else "Button")
		first = false
		act.pressed.connect(GameState.choose_event.bind(id, cid))
		buttons.add_child(act)
	return card


func _choice_label(ev: Dictionary, choice_id: String) -> String:
	for choice_v in ev.get("choices", []):
		var choice: Dictionary = choice_v
		if str(choice.get("id", "")) == choice_id:
			return str(choice.get("label", choice_id))
	return choice_id


func _edict_row(edict: Dictionary) -> PanelContainer:
	var id := str(edict.get("id", ""))
	var blocked := GameState.edict_block(edict)
	var kind := "EdictRowSelected" if GameState.edicts_done.has(id) else "EdictRow"
	var card := Kit.panel(kind)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(Kit.icon_rect("edict_%s" % id, 32))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(Kit.label("%s  %s" % [str(edict.get("glyph", "")), str(edict.get("name", ""))], "H3Label"))
	text.add_child(Kit.label(str(edict.get("effect", "")), "CaptionLabel"))
	var cost: Dictionary = edict.get("cost", {})
	text.add_child(Kit.label("条件 %s · %s" % [str(edict.get("prereq", "")), str(cost.get("text", ""))], "SmallLabel"))
	var opp := HBoxContainer.new()
	opp.add_theme_constant_override("separation", 4)
	text.add_child(opp)
	var groups: Array = edict.get("opposition", [])
	if groups.is_empty():
		opp.add_child(Kit.label("没有成气候的反对", "CaptionLabel"))
	for g_v in groups:
		var g: Dictionary = g_v
		var who := str(g.get("who", ""))
		var strength := clampi(int(g.get("strength", 0)), 0, 3)
		var bits := who + " "
		opp.add_child(Kit.label(bits, "CaptionLabel"))
		for i in 3:
			var mark := TextureRect.new()
			mark.texture = Kit.piece("tri_opp" if i < strength else "tri_opp_empty")
			mark.custom_minimum_size = Vector2(14, 14)
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			opp.add_child(mark)
	if GameState.edicts_done.has(id):
		row.add_child(Kit.label("已颁布", "SmallLabel"))
	elif blocked == "":
		var act := Kit.button("颁布", "PrimaryButton")
		act.custom_minimum_size = Vector2(88, 36)
		act.pressed.connect(GameState.enact_edict.bind(id))
		row.add_child(act)
	else:
		row.add_child(Kit.label(blocked, "SmallLabel"))
	return card


func _page_codex(box: VBoxContainer) -> void:
	_header(box, "史册 · 格物", "")
	box.add_child(Kit.label("已入册 %d / %d" % [GameState.tech_done.size(), DataDB.techs.size()], "H3Label"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if GameState.tech_done.is_empty():
		list.add_child(Kit.label("史册还是空白。先把一件事从设计做到推广。", "BodyLabel"))
		return
	for id_v in GameState.tech_done:
		var id := str(id_v)
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		var card := Kit.panel("PlainPanel")
		var inner := VBoxContainer.new()
		card.add_child(inner)
		inner.add_child(Kit.label("%s  %s" % [id, str(tech.get("name", ""))], "H3Label"))
		inner.add_child(Kit.label(str(tech.get("effect", "")), "BodyLabel"))
		inner.add_child(Kit.label(str(tech.get("history", "")), "CaptionLabel"))
		list.add_child(card)


func _page_save(box: VBoxContainer) -> void:
	_header(box, "写入存档" if writing else "读取存档", "save_close")
	var labels := ["自动", "槽一", "槽二", "槽三"]
	for i in 4:
		var has := SaveManager.has_slot(i)
		var b := Kit.button("", "ListItemButton")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		if writing and i == 0:
			b.text = "自动 · 回合结束时写入"
			b.disabled = true
		elif writing:
			b.text = "写入%s" % labels[i]
		else:
			b.text = "读取%s%s" % [labels[i], "" if has else "（空）"]
			b.disabled = not has
		if writing:
			b.pressed.connect(_write_slot.bind(i))
		else:
			b.pressed.connect(_read_slot.bind(i))
		box.add_child(b)


func _write_slot(slot: int) -> void:
	SaveManager.save_slot(slot)
	shut()


func _read_slot(slot: int) -> void:
	if SaveManager.load_slot(slot):
		shut()
		var map := get_tree().get_first_node_in_group("world_map")
		if map:
			map.call("focus_after_load")


func _page_city(box: VBoxContainer) -> void:
	var city := DataDB.city_by_id(city_id)
	if city.is_empty():
		_header(box, "城市", "")
		box.add_child(Kit.label("这座城不在名册里。", "BodyLabel"))
		return
	_header(box, str(city.get("name", "")), "")
	var faction := str(DataDB.faction(str(city.get("faction", ""))).get("name", ""))
	box.add_child(Kit.label("%s · %s · 城墙 %d · 人口 %d" % [faction, str(city.get("circuit", "")), int(city.get("walls", 0)), int(city.get("pop", 0))], "H3Label"))
	var output: Dictionary = city.get("output", {})
	box.add_child(Kit.label("每回合 粮 %d · 钱 %d · 匠 %d" % [int(output.get("food", 0)), int(output.get("money", 0)), int(output.get("craft", 0))], "BodyLabel"))
	box.add_child(Kit.label("能建的和还锁着的。这一页还不打地基。", "CaptionLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for b_v in DataDB.buildings:
		var spec: Dictionary = b_v
		var open := GameState.building_unlocked(spec)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var icon_name := str(spec.get("icon", ""))
		if icon_name != "":
			row.add_child(Kit.icon_rect(icon_name, 28))
		var text := Kit.label("%s · %s" % [str(spec.get("name", "")), str(spec.get("effect", ""))], "BodyLabel")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		row.add_child(Kit.label("可建" if open else _lock_text(spec), "SmallLabel"))


func _lock_text(spec: Dictionary) -> String:
	var unlock := str(spec.get("unlock", ""))
	if unlock.begins_with("edict_"):
		return "待政令"
	var tech: Dictionary = DataDB.tech_by_id.get(unlock, {})
	if tech.is_empty():
		return "未开放"
	return "待 " + str(tech.get("name", unlock))


func _branch_full(id: String) -> String:
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		if str(b.get("id", "")) == id:
			return str(b.get("full", b.get("name", id)))
	return id


func _mat_text(raw) -> String:
	if typeof(raw) != TYPE_DICTIONARY:
		return ""
	var mats: Dictionary = raw
	var bits: PackedStringArray = []
	for key_v in mats.keys():
		var key := str(key_v)
		bits.append("%s%d" % [str(MAT_NAME.get(key, key)), int(mats[key_v])])
	return "、".join(bits)


func _trial_cost(tech: Dictionary) -> String:
	var cost: Dictionary = tech.get("cost", {})
	var line := "匠 %d" % int(cost.get("craft", 0))
	var mats := _mat_text(tech.get("materials", {}))
	if mats != "":
		line += " · " + mats
	return line


func _trial(id: String) -> Dictionary:
	for trial_v in GameState.tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) == id:
			return trial
	return {}
