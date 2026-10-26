class_name TechDesk
extends Control

const PLAN = preload("res://scripts/ui/tech_plan.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")

const PAPER := Color("f3ead6")
const INK := Color("2a241c")
const CREAM := Color("fbf5e6")
const CINNABAR := Color("c23b2a")
const GOLD := Color("b8893a")
const CYAN := Color("1f7f8c")
const OCHRE := Color("8a4e22")
const MUTED := Color("76685a")
const HEADER := Color("1c2826")
const HEADER_H := 48.0
const FOOTER_H := 76.0
const LEFT_W := 288.0
const NAME_W := 40.0
const STAGE_H := 32.0
const NODE_W := 156.0
const NODE_H := 44.0
const ROW_H := 94.0
const COL_W := 214.0
const NEXT_W := 96.0
const LOCKED_A := 0.6
const CARD_W := 296.0
const TALENT_PID := {
	"燕肃": "yan_su",
	"毕昇": "bi_sheng",
	"种世衡": "zhong_shiheng",
	"冶铁匠师": "artisan_iron",
	"窑工匠师": "artisan_kiln",
	"船匠匠师": "artisan_ship",
	"曾公亮": "zeng_gongliang",
	"苏颂": "su_song",
}

var desk: Desk
var graph: Graph
var scroll: ScrollContainer
var name_banner: Label
var anchors := {}
var nodes := {}
var tutorial_shade: Shade
var tutorial_bubble: Control
var tutorial_key := ""
var _choice: Control
var _choice_dim: Control
var _flash_labels: Array = []
var _flash_until := 0
var edge_routes: Array = []
var route_marks := {}
var layout_box := {}
var _drag := false
var _press := Vector2.ZERO
var _drag_from := 0
var _next_x := 0.0


func build() -> void:
	_flash_labels = []
	_flash_until = 0
	set_process(false)
	if GameState.arm_era3_flash():
		_flash_until = Time.get_ticks_msec() + 1600
		set_process(true)
	theme = Settings.theme
	_floor_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(1280, 720)
	var bg := ColorRect.new()
	bg.color = PAPER
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if desk.tech_legend_bar < 0:
		desk.tech_legend_bar = 1 if GameState.turn <= 10 else 0
	var header_h := 92.0 if desk.tech_view == "overview" else HEADER_H
	_build_header(header_h)
	_build_footer()
	_build_body(header_h)
	if desk.tech_show_legend:
		_build_legend()
	if desk.tech_show_parts:
		_build_parts()
	if desk.tech_tutorial >= 0:
		_build_tutorial()


func _build_header(header_h: float) -> void:
	var bar := ColorRect.new()
	bar.color = HEADER
	bar.position = Vector2.ZERO
	bar.size = Vector2(1280, header_h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 8)
	row.size = Vector2(1248, 40)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var title := "格物图·总览" if desk.tech_view == "overview" else "格物图"
	var lab := Kit.label(title, "H2Label")
	lab.add_theme_color_override("font_color", CREAM)
	row.add_child(lab)
	if desk.tech_view != "overview":
		var era := PLAN.current_era()
		var prog := PLAN.era_progress(era)
		var era_name := _era_name(era)
		var chip := Kit.label("%s  %d/%d" % [era_name, prog.x, prog.y], "H3Label")
		chip.add_theme_color_override("font_color", Color("e7c98a"))
		row.add_child(chip)
		var era2 := PLAN.era_progress(2)
		var next_text := "时代三 · 火器初兴 已开"
		if not GameState.era_unlocked(3):
			next_text = "时代三：第 68 回合 或 本时代完成 11/%d 开放" % int(era2.y)
		var next := Kit.label(next_text, "CaptionLabel")
		next.add_theme_color_override("font_color", Color("d9cbb6"))
		row.add_child(next)
	else:
		_filter_row(row)
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)
	var focus := _header_button("聚焦", desk.tech_view != "overview")
	focus.pressed.connect(_set_view.bind("focus"))
	row.add_child(focus)
	desk.debug_btns["tech_focus"] = focus
	var overview := _header_button("总览", desk.tech_view == "overview")
	overview.pressed.connect(_set_view.bind("overview"))
	row.add_child(overview)
	desk.debug_btns["tech_overview"] = overview
	var help := _header_button("图例", false)
	help.custom_minimum_size = Vector2(64, 36)
	help.pressed.connect(_show_legend)
	row.add_child(help)
	desk.debug_btns["tech_help"] = help
	var close := _header_button("×", false)
	close.pressed.connect(desk.shut)
	row.add_child(close)
	desk.debug_btns["desk_close"] = close
	if desk.tech_view == "overview":
		var banner := "悬停节点看全名"
		if desk.tech_hover != "":
			var hovered: Dictionary = DataDB.tech_by_id.get(desk.tech_hover, {})
			banner = "%s    %s" % [str(hovered.get("name", desk.tech_hover)), PLAN.status_text(desk.tech_hover)]
		name_banner = Kit.label(banner, "BodyLabel")
		name_banner.add_theme_color_override("font_color", CREAM)
		name_banner.position = Vector2(16, 52)
		name_banner.size = Vector2(1100, 28)
		name_banner.clip_text = false
		name_banner.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		add_child(name_banner)


func _filter_row(row: HBoxContainer) -> void:
	var branch := OptionButton.new()
	branch.focus_mode = Control.FOCUS_NONE
	branch.custom_minimum_size = Vector2(108, 32)
	branch.add_item("分支：全部", 0)
	branch.set_item_metadata(0, "")
	var pick := 0
	var i := 1
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		var id := str(b.get("id", ""))
		if id == "zhong":
			continue
		branch.add_item(str(b.get("name", id)), i)
		branch.set_item_metadata(i, id)
		if id == desk.tech_branch:
			pick = i
		i += 1
	branch.select(pick)
	branch.item_selected.connect(_on_branch.bind(branch))
	row.add_child(branch)
	var ready := CheckBox.new()
	ready.text = "只看可设计"
	ready.focus_mode = Control.FOCUS_NONE
	ready.button_pressed = desk.tech_only_ready
	ready.add_theme_color_override("font_color", CREAM)
	ready.toggled.connect(_on_ready)
	row.add_child(ready)
	var practice := CheckBox.new()
	practice.text = "有实践门槛"
	practice.focus_mode = Control.FOCUS_NONE
	practice.button_pressed = desk.tech_practice
	practice.add_theme_color_override("font_color", CREAM)
	practice.toggled.connect(_on_practice)
	row.add_child(practice)
	var mat := OptionButton.new()
	mat.focus_mode = Control.FOCUS_NONE
	mat.custom_minimum_size = Vector2(120, 32)
	mat.add_item("材料叠加", 0)
	mat.set_item_metadata(0, "")
	var names: Array = ["copper", "iron", "wood", "coal", "steel", "money", "saltpeter", "sulfur"]
	var mi := 1
	var mpick := 0
	for key_v in names:
		var key := str(key_v)
		mat.add_item(str(PLAN.MAT_NAME.get(key, key)), mi)
		mat.set_item_metadata(mi, key)
		if key == desk.tech_mat:
			mpick = mi
		mi += 1
	mat.select(mpick)
	mat.item_selected.connect(_on_mat.bind(mat))
	row.add_child(mat)
	var search := LineEdit.new()
	search.placeholder_text = "搜索科技"
	search.text = desk.tech_query
	search.custom_minimum_size = Vector2(140, 32)
	search.focus_mode = Control.FOCUS_NONE
	search.text_changed.connect(_on_query)
	row.add_child(search)


func _build_body(header_h: float) -> void:
	var top := header_h
	var foot := FOOTER_H if desk.tech_view != "overview" else 32.0
	var height := 720.0 - header_h - foot
	var left_w := 0.0 if desk.tech_view == "overview" else LEFT_W
	if left_w > 0.0:
		var left := PanelContainer.new()
		left.position = Vector2(0, top)
		left.size = Vector2(left_w, height)
		left.clip_contents = true
		left.add_theme_stylebox_override("panel", _flat(Color("f7f1e4"), Color("e0d3b8"), 8, 0))
		add_child(left)
		var scroller := ScrollContainer.new()
		scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroller.clip_contents = true
		left.add_child(scroller)
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(264, 0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		scroller.add_child(box)
		_left(box)
	var tree_x := left_w
	var tree_w := 1280.0 - left_w
	var tree_paper := ColorRect.new()
	tree_paper.color = PAPER
	tree_paper.position = Vector2(tree_x, top)
	tree_paper.size = Vector2(tree_w, height)
	tree_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tree_paper)
	var host := HBoxContainer.new()
	host.position = Vector2(tree_x, top)
	host.size = Vector2(tree_w, height)
	host.add_theme_constant_override("separation", 0)
	add_child(host)
	var gutter := VBoxContainer.new()
	gutter.custom_minimum_size = Vector2(NAME_W if desk.tech_view != "overview" else 28.0, height)
	host.add_child(gutter)
	gutter.add_child(_spacer(STAGE_H if desk.tech_view != "overview" else 28.0))
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		if str(b.get("id", "")) == "zhong":
			continue
		var mark := Kit.label(str(b.get("name", "")), "H3Label")
		mark.custom_minimum_size = Vector2(NAME_W - 4.0, ROW_H if desk.tech_view != "overview" else 56)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.clip_text = true
		mark.autowrap_mode = TextServer.AUTOWRAP_OFF
		gutter.add_child(mark)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.gui_input.connect(_on_tree_input)
	host.add_child(scroll)
	graph = Graph.new()
	graph.board = self
	graph.mouse_filter = Control.MOUSE_FILTER_STOP
	graph.gui_input.connect(_on_paper_input)
	scroll.add_child(graph)
	if desk.tech_view == "overview":
		_layout_overview()
	else:
		_layout_focus()
	graph.custom_minimum_size = graph.need
	graph.size = graph.need
	_paint_fade()
	var era_now := PLAN.current_era()
	if desk.tech_scroll < 0 or desk.tech_scroll_era != era_now:
		desk.tech_scroll = _default_scroll(era_now)
		desk.tech_scroll_era = era_now
	_apply_scroll(desk.tech_scroll)
	_bring_into_view(desk.picked)
	_bring_into_view(GameState.tech_designing)
	layout_box = {
		"header_h": header_h,
		"left_w": left_w,
		"tree_w": tree_w,
		"tree_h": height,
		"footer_h": foot,
		"scroll": scroll.scroll_horizontal,
	}
	if desk.tech_view != "overview" and desk.picked != "":
		_build_card(desk.picked)


func _left(box: VBoxContainer) -> void:
	box.add_child(_design_block())
	box.add_child(_queue_block())
	box.add_child(_trial_block())
	box.add_child(_library_block())
	if GameState.tech_target != "":
		box.add_child(_target_card())
	else:
		var sug := PLAN.suggestion()
		if str(sug.get("id", "")) == "":
			box.add_child(_none_card())
		else:
			var card := _advice_card(str(sug.get("title", "")), str(sug.get("reason", "")), bool(sug.get("telegraph", false)), true)
			box.add_child(card)
			anchors["accept"] = card


func _design_block() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(264, 96)
	box.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(Kit.label("设计槽 %d/1" % (0 if GameState.tech_designing == "" else 1), "H3Label"))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	head.add_child(Kit.label("第 %d 回合" % GameState.turn, "SmallLabel"))
	anchors["now"] = box
	if GameState.tech_designing == "":
		var empty := Kit.label("选一份图纸", "H3Label")
		empty.add_theme_color_override("font_color", CINNABAR)
		box.add_child(empty)
		anchors["design"] = empty
		return box
	var id := GameState.tech_designing
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var need := GameState.design_need(id)
	var left := maxi(0, need - GameState.tech_design_prog)
	var row := _text_button(str(tech.get("name", id)))
	row.pressed.connect(_on_node.bind(id))
	box.add_child(row)
	anchors["design"] = row
	var pause := Kit.button("暂停", "Button")
	pause.custom_minimum_size = Vector2(64, 32)
	pause.pressed.connect(_pause_design)
	box.add_child(pause)
	var bar := ProgressBar.new()
	bar.theme_type_variation = "NodeBarDesign"
	bar.max_value = float(maxi(1, need))
	bar.value = float(GameState.tech_design_prog)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	box.add_child(bar)
	box.add_child(Kit.label("电 %d/%d · 约 %d 回合" % [GameState.tech_design_prog, need, int(ceil(float(left) / 10.0))], "SmallLabel"))
	return box


func _queue_block() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(264, 48)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(Kit.label("队列 %d/%d" % [GameState.tech_queue.size(), GameState.QUEUE_CAP], "H3Label"))
	if GameState.tech_queue.size() >= GameState.QUEUE_CAP:
		var full := Kit.label("满", "SmallLabel")
		full.add_theme_color_override("font_color", CINNABAR)
		head.add_child(full)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	for i in GameState.QUEUE_CAP:
		var text := "%s—" % _circ(i + 1)
		var qid := ""
		if i < GameState.tech_queue.size():
			qid = str(GameState.tech_queue[i])
			text = "%s%s" % [_circ(i + 1), PLAN.short_name(qid)]
		var chip := _text_button(text)
		if qid != "":
			chip.pressed.connect(_on_node.bind(qid))
		row.add_child(chip)
	return box


func _trial_block() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(264, 152)
	var head := HBoxContainer.new()
	box.add_child(head)
	var slots := GameState.trial_slots()
	head.add_child(Kit.label("试制槽 %d/%d" % [GameState.tech_trials.size(), slots], "H3Label"))
	if slots < 2:
		var pad := Control.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(pad)
		head.add_child(Kit.label("开格物院后 2 槽", "SmallLabel"))
	anchors["trial"] = box
	for trial_v in GameState.tech_trials:
		var trial: Dictionary = trial_v
		var id := str(trial.get("id", ""))
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		var brow := _link_row(str(tech.get("name", id)), "workshop")
		box.add_child(brow)
		var tbar := ProgressBar.new()
		tbar.theme_type_variation = "NodeBarTrial"
		tbar.max_value = float(maxi(1, int(trial.get("need", 1))))
		tbar.value = float(int(trial.get("prog", 0)))
		tbar.show_percentage = false
		tbar.custom_minimum_size = Vector2(0, 8)
		box.add_child(tbar)
		box.add_child(Kit.label("第 %d/%d 回合" % [int(trial.get("prog", 0)), int(trial.get("need", 1))], "SmallLabel"))
		var who := str(tech.get("talent", ""))
		var paid := _paid_text(tech)
		var note := who
		if paid != "":
			note = paid if note == "" else "%s · %s" % [note, paid]
		if note != "":
			box.add_child(Kit.label(note, "SmallLabel"))
	var open_slots := maxi(0, slots - GameState.tech_trials.size())
	for _slot in open_slots:
		var empty_slot := _text_button("空槽 · 去匠作院")
		empty_slot.pressed.connect(_jump.bind("workshop"))
		box.add_child(empty_slot)
	if slots < 2:
		box.add_child(Kit.label("第 2 槽 · 颁布「开格物院」后开放", "SmallLabel"))
	return box


func _paid_text(tech: Dictionary) -> String:
	var cost: Dictionary = tech.get("cost", {})
	var bits := PackedStringArray()
	bits.append("匠 %d" % int(cost.get("craft", 0)))
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		var key := str(key_v)
		bits.append("%s %d" % [str(PLAN.MAT_NAME.get(key, key)), int(mats[key_v])])
	return "、".join(bits) + " 已付"


func _library_block() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(264, 88)
	var cap := GameState.blueprint_cap()
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(Kit.label("图纸库 %d/%d" % [GameState.tech_blueprints.size(), cap], "H3Label"))
	var hint := ""
	if not GameState.tech_blueprints.is_empty():
		if GameState.tech_trials.size() >= GameState.trial_slots():
			hint = "等试制槽空出"
		else:
			hint = "可以开试制"
	if hint != "":
		var pad := Control.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(pad)
		head.add_child(Kit.label(hint, "SmallLabel"))
	var previews := _preview_chapters()
	var n := mini(5, cap + previews.size())
	var gap := 6.0
	var cell_w := (264.0 - gap * float(n - 1)) / float(maxi(1, n))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(gap))
	box.add_child(row)
	anchors["prints"] = row
	for i in cap:
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(cell_w, 60)
		cell.set_meta("lib_kind", "real")
		cell.set_meta("lib_w", cell_w)
		var inner := CenterContainer.new()
		cell.add_child(inner)
		cell.clip_contents = true
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cell.add_theme_stylebox_override("panel", _cell_box())
		var inner_w := maxf(8.0, cell_w - 4.0)
		if i < GameState.tech_blueprints.size():
			var id := str(GameState.tech_blueprints[i])
			var btn := _text_button(PLAN.short_name(id))
			btn.clip_text = true
			btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			btn.custom_minimum_size = Vector2(inner_w, 18)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.pressed.connect(_on_node.bind(id))
			inner.add_child(btn)
		else:
			var empty_lab := Kit.label("空", "SmallLabel")
			empty_lab.clip_text = true
			empty_lab.autowrap_mode = TextServer.AUTOWRAP_OFF
			empty_lab.custom_minimum_size = Vector2(inner_w, 16)
			empty_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			inner.add_child(empty_lab)
		row.add_child(cell)
	for title_v in previews:
		var title := str(title_v)
		var cell2 := PanelContainer.new()
		cell2.custom_minimum_size = Vector2(cell_w, 60)
		cell2.clip_contents = true
		cell2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cell2.add_theme_stylebox_override("panel", _cell_box())
		cell2.set_meta("lib_kind", "preview")
		cell2.set_meta("lib_w", cell_w)
		cell2.tooltip_text = "%s主目标完成后 +1 格（只完成一半不给）" % title
		var inner2 := VBoxContainer.new()
		inner2.add_theme_constant_override("separation", 0)
		cell2.add_child(inner2)
		var chapter := Kit.label(title, "SmallLabel")
		chapter.clip_text = true
		chapter.autowrap_mode = TextServer.AUTOWRAP_OFF
		chapter.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		chapter.custom_minimum_size = Vector2(maxf(8.0, cell_w - 4.0), 16)
		chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner2.add_child(chapter)
		var reward := Kit.label("奖励", "SmallLabel")
		reward.clip_text = true
		reward.autowrap_mode = TextServer.AUTOWRAP_OFF
		reward.custom_minimum_size = Vector2(maxf(8.0, cell_w - 4.0), 16)
		reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner2.add_child(reward)
		row.add_child(cell2)
	return box


func _preview_chapters() -> PackedStringArray:
	var out := PackedStringArray()
	var pairs := [["liao", "第二章"], ["heyi", "第四章"]]
	for pair_v in pairs:
		var pair: Array = pair_v
		var ch: Dictionary = DataDB.chapter_by_id.get(str(pair[0]), {})
		if ch.is_empty():
			continue
		if GameState.chapter_rewarded.has(str(pair[0])):
			continue
		var state := str(GoalSystem.chapter_state(ch))
		if state == "done" or state == "partial" or state == "fail":
			continue
		out.append(str(pair[1]))
	return out



func _fit_guide(panel: PanelContainer, box: VBoxContainer) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(box):
		return
	box.size.x = maxf(240.0, panel.size.x - 24.0)
	var content := box.get_combined_minimum_size().y + 20.0
	var max_h := 720.0 - panel.position.y - 40.0
	panel.size.y = clampf(content, 200.0, max_h)


func _advice_card(title: String, reason: String, telegraph: bool, live: bool) -> PanelContainer:
	var bg := Color("14343a") if telegraph else Color("f7f1e4")
	var fg := CREAM if telegraph else INK
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(248, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", _flat(bg, CYAN, 8, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var face := TextureRect.new()
	face.texture = Kit.portrait_head("doushabao", "lowpower" if telegraph else "thinking")
	face.custom_minimum_size = Vector2(42, 42)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(face)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(text)
	var h := Kit.label(title, "H3Label")
	h.add_theme_color_override("font_color", fg)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.custom_minimum_size = Vector2(160, 0)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(h)
	var body := Kit.label(reason, "CaptionLabel")
	body.add_theme_color_override("font_color", fg)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(160, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(body)
	if live:
		var act := Kit.button("采纳", "PrimaryButton")
		act.custom_minimum_size = Vector2(88, 32)
		act.pressed.connect(_adopt)
		box.add_child(act)
		desk.debug_btns["tech_accept"] = act
	return card


func _none_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _flat(Color("efe6d4"), MUTED, 8, 1))
	var box := VBoxContainer.new()
	card.add_child(box)
	var h := Kit.label("本月无需操作", "H3Label")
	box.add_child(h)
	var body := Kit.label("没有可执行的建议，也没有新的阻塞。可以直接离开格物图。", "CaptionLabel")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return card


func _target_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(264, 140)
	card.add_theme_stylebox_override("panel", _flat(Color("e7f4f6"), CYAN, 8, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var tech: Dictionary = DataDB.tech_by_id.get(GameState.tech_target, {})
	var title := Kit.label("目标  %s" % str(tech.get("name", GameState.tech_target)), "H3Label")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var sum: Dictionary = PLAN.totals(GameState.tech_target)
	var chain: Array = PLAN.spine(GameState.tech_target)
	var route := ""
	if chain.size() >= 2:
		var head: Dictionary = DataDB.tech_by_id.get(str(chain[0]), {})
		var tail: Dictionary = DataDB.tech_by_id.get(str(chain[chain.size() - 1]), {})
		route = "起 %s → 标 %s" % [str(head.get("name", "")), str(tail.get("name", ""))]
	elif chain.size() == 1:
		route = "标 %s" % str(tech.get("name", GameState.tech_target))
	if route != "":
		var path_lab := Kit.label(route, "SmallLabel")
		path_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(path_lab)
	box.add_child(Kit.label("总电 %d · 总匠 %d · 约 %d 回合" % [int(sum.get("power", 0)), int(sum.get("craft", 0)), int(sum.get("months", 0))], "SmallLabel"))
	var short := _target_gap(GameState.tech_target)
	if short != "":
		var gap := _link_row("卡点：" + short, "industry")
		box.add_child(gap)
	var cancel := Kit.button("取消目标", "Button")
	cancel.pressed.connect(_clear_target)
	box.add_child(cancel)
	desk.debug_btns["tech_clear"] = cancel
	anchors["accept"] = card
	return card


func _blocker(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var bang := Kit.label("!", "H3Label")
	bang.add_theme_color_override("font_color", CINNABAR)
	row.add_child(bang)
	var text := Kit.label(str(item.get("text", "")), "SmallLabel")
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(text)
	var jump := str(item.get("jump", ""))
	if jump != "":
		var link := _text_button(str(item.get("jump_label", jump)) + " >")
		link.pressed.connect(_jump.bind(jump))
		row.add_child(link)
		desk.debug_btns["jump_" + jump] = link
	return row


func _build_drawer(x: float, y: float, w: float, h: float) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(x, y + 8)
	panel.size = Vector2(w - 12, h - 16)
	panel.add_theme_stylebox_override("panel", _flat(CREAM, Color("e0d3b8"), 8, 1))
	add_child(panel)
	var scroll_box := ScrollContainer.new()
	scroll_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll_box)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size = Vector2(w - 40, 0)
	box.add_theme_constant_override("separation", 6)
	scroll_box.add_child(box)
	var id := desk.picked
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(Kit.icon_rect("tech_%s" % id, 36))
	var talent_face := _talent_face(str(tech.get("talent", "")))
	if talent_face != null:
		head.add_child(talent_face)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	var name := Kit.label(str(tech.get("name", id)), "H2Label")
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(name)
	titles.add_child(Kit.label("%s  ·  %s" % [id, _branch_stage(tech)], "SmallLabel"))
	var state := Kit.label("状态  " + PLAN.status_text(id), "H3Label")
	box.add_child(state)
	box.add_child(Kit.label("门槛", "H3Label"))
	for row_v in PLAN.gate_rows(id):
		var row: Dictionary = row_v
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var mark := Kit.label("✓" if bool(row.get("ok", false)) else "×", "H3Label")
		mark.add_theme_color_override("font_color", Color("2f7d4a") if bool(row.get("ok", false)) else CINNABAR)
		line.add_child(mark)
		var t := Kit.label(str(row.get("text", "")), "CaptionLabel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(t)
		var note := Kit.label(str(row.get("note", "")), "SmallLabel")
		line.add_child(note)
		if str(row.get("text", "")).begins_with("实践") and not bool(row.get("ok", false)):
			var go := _text_button("去建造")
			go.pressed.connect(_open_practice_city.bind(id))
			line.add_child(go)
		box.add_child(line)
	box.add_child(Kit.label("效果", "H3Label"))
	var effect := Kit.label(str(tech.get("effect", "")), "BodyLabel")
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(effect)
	var verb := PLAN.primary_verb(id)
	if verb != "":
		var act := Kit.button(verb, "PrimaryButton")
		act.custom_minimum_size = Vector2(0, 40)
		act.pressed.connect(_run.bind(id))
		box.add_child(act)
		desk.debug_btns["tech_verb"] = act
	elif GameState.tech_target == id:
		var held := Kit.label("当前目标", "H3Label")
		held.add_theme_color_override("font_color", CYAN)
		box.add_child(held)
	if PLAN.show_target_link(id):
		var link := _text_button("设为目标")
		link.pressed.connect(_make_target.bind(id))
		box.add_child(link)
		desk.debug_btns["tech_make_target"] = link
	var short := _target_gap(id)
	if short != "" and verb != "去补齐":
		var gap := _text_button("去补齐：" + short)
		gap.pressed.connect(_jump.bind("industry"))
		box.add_child(gap)
	_fold(box, id, "history", "史册", str(tech.get("history", "")))
	_fold(box, id, "hands", "豆沙包能做的 / 大宋得自己做的", "能跳过：%s\n跳不过：%s" % [str(tech.get("skip", "")), str(tech.get("noskip", ""))])


func _fold(box: VBoxContainer, id: String, key: String, title: String, body_text: String) -> void:
	var open := desk.tech_fold == key and desk.picked == id
	var btn := _text_button(title + ("  收起" if open else "  展开"))
	btn.pressed.connect(_toggle_fold.bind(key))
	box.add_child(btn)
	if open:
		var body := Kit.label(body_text, "CaptionLabel")
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)


func _layout_focus() -> void:
	var era := PLAN.current_era()
	var last_col := 0
	var prev_era := 0
	for stage_v in DataDB.stages:
		var stage: Dictionary = stage_v
		var stage_era := int(stage.get("era", 0))
		if stage_era > era:
			continue
		var col_from := int(stage.get("col_from", 1))
		var col_to := int(stage.get("col_to", col_from))
		last_col = maxi(last_col, col_to)
		var x := float(col_from - 1) * COL_W
		var prog := PLAN.stage_progress(int(stage.get("id", 0)))
		var cap := Kit.label("%s %s  %d/%d" % [str(stage.get("name", "")), str(stage.get("subtitle", "")), prog.x, prog.y], "SmallLabel")
		cap.position = Vector2(x, 0)
		cap.size = Vector2(float(col_to - col_from + 1) * COL_W, STAGE_H)
		cap.clip_text = true
		cap.autowrap_mode = TextServer.AUTOWRAP_OFF
		cap.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_mark_era3_head(cap, stage)
		graph.add_child(cap)
		if prev_era != 0 and stage_era != prev_era:
			var rule := ColorRect.new()
			rule.color = GOLD
			rule.position = Vector2(x - 2.0, 0)
			rule.size = Vector2(2, STAGE_H + 6.0 * ROW_H)
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			graph.add_child(rule)
		elif prev_era == stage_era:
			var thin := ColorRect.new()
			thin.color = Color("d8cbb0")
			thin.position = Vector2(x, 0)
			thin.size = Vector2(1, STAGE_H + 6.0 * ROW_H)
			thin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			graph.add_child(thin)
		prev_era = stage_era
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if int(tech.get("era", 1)) > era:
			continue
		var id := str(tech.get("id", ""))
		var row := _branch_row(str(tech.get("branch", "")))
		if row < 0 and str(tech.get("branch", "")) == "zhong" and era >= 3:
			row = 5
		if row < 0:
			continue
		var col := int(tech.get("col", 1))
		var pos := Vector2(float(col - 1) * COL_W, STAGE_H + float(row) * ROW_H + _slot_y(str(tech.get("slot", "c"))))
		_place_node(id, pos, false)
	var width := float(last_col) * COL_W
	if era < 3:
		_layout_next(era, width)
		width += NEXT_W
	graph.need = Vector2(width, STAGE_H + 6.0 * ROW_H)
	_build_edges()


func _layout_next(era: int, x: float) -> void:
	_next_x = x
	var head := Kit.label("时代%s · 后继" % _era_han(era + 1), "SmallLabel")
	head.position = Vector2(x, 0)
	head.clip_text = true
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	graph.add_child(head)
	var head_h := maxf(16.0, head.get_combined_minimum_size().y)
	head.size = Vector2(NEXT_W, head_h)
	var sub := Kit.label(_lock_head(era + 1), "SmallLabel")
	sub.clip_text = true
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	graph.add_child(sub)
	var sub_h := maxf(16.0, sub.get_combined_minimum_size().y)
	sub.position = Vector2(x, head_h)
	sub.size = Vector2(NEXT_W, sub_h)
	var buckets := {}
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if int(tech.get("era", 1)) != era + 1:
			continue
		var id := str(tech.get("id", ""))
		var row := _branch_row(str(tech.get("branch", "")))
		if row < 0:
			continue
		if not buckets.has(row):
			buckets[row] = []
		var list: Array = buckets[row]
		list.append(tech)
	for row_v in buckets.keys():
		var row := int(row_v)
		var list: Array = buckets[row]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("col", 0)) < int(b.get("col", 0)))
		var shown := 0
		for tech_v2 in list:
			if shown >= 2:
				break
			var tech2: Dictionary = tech_v2
			var id2 := str(tech2.get("id", ""))
			var pos := Vector2(x + 4.0 + float(shown) * 44.0, STAGE_H + float(row) * ROW_H + 8.0)
			_place_chip(id2, pos)
			shown += 1


func _place_chip(id: String, pos: Vector2) -> void:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(slot, empty)
	var wh := Vector2(40, 64)
	b.custom_minimum_size = wh
	b.size = wh
	b.clip_contents = true
	b.position = pos
	b.tooltip_text = "%s\n%s" % [str(tech.get("name", id)), PLAN.status_text(id)]
	b.pressed.connect(_on_node.bind(id))
	b.mouse_entered.connect(_on_enter.bind(id))
	b.mouse_exited.connect(_on_exit.bind(id))
	graph.add_child(b)
	var face := Face.new()
	face.state = "locked"
	face.tile = false
	face.corner = "锁"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = wh
	b.add_child(face)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(2, 2)
	col.size = Vector2(36, 60)
	col.clip_contents = true
	col.add_theme_constant_override("separation", 0)
	b.add_child(col)
	col.add_child(Kit.icon_rect("tech_%s" % id, 22))
	var short := PLAN.short_name(id)
	if short.length() > 4:
		short = short.substr(0, 4)
	var line_a := short.substr(0, mini(2, short.length()))
	var line_b := ""
	if short.length() > 2:
		line_b = short.substr(2, 2)
	col.add_child(_chip_name(line_a))
	if line_b != "":
		col.add_child(_chip_name(line_b))
	b.modulate.a = LOCKED_A
	nodes[id] = b
	graph.spots[id] = Rect2(pos, wh)
	desk.debug_btns["node_" + id] = b


func _chip_name(text: String) -> Label:
	var nm := Kit.label(text, "SmallLabel")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_OFF
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.custom_minimum_size = Vector2(36, 14)
	nm.add_theme_font_size_override("font_size", 13)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return nm


func _layout_overview() -> void:
	var x := 4.0
	for stage_v in DataDB.stages:
		var stage: Dictionary = stage_v
		var col_from := int(stage.get("col_from", 1))
		var col_to := int(stage.get("col_to", col_from))
		var cols := col_to - col_from + 1
		var prog := PLAN.stage_progress(int(stage.get("id", 0)))
		var done := prog.x == prog.y and prog.y > 0
		var title := "%s %s %d/%d" % [str(stage.get("name", "")), "齐" if done else str(stage.get("subtitle", "")), prog.x, prog.y]
		if not GameState.era_unlocked(int(stage.get("era", 1))):
			title = "锁 · %s" % _lock_head(int(stage.get("era", 1)))
		var cap := Kit.label(title, "SmallLabel")
		cap.position = Vector2(x, 4)
		cap.size = Vector2(cols * 48.0, 22)
		_mark_era3_head(cap, stage)
		cap.clip_text = false
		graph.add_child(cap)
		for tech_v in DataDB.techs:
			var tech: Dictionary = tech_v
			if int(tech.get("stage", 0)) != int(stage.get("id", 0)):
				continue
			var id := str(tech.get("id", ""))
			var col := int(tech.get("col", col_from)) - col_from
			var row := _branch_row(str(tech.get("branch", "")))
			if row < 0:
				row = 5
			var pos := Vector2(x + float(col) * 48.0, 28.0 + float(row) * 56.0)
			_place_node(id, pos, true)
		x += float(cols) * 48.0 + 14.0
	graph.need = Vector2(x, 28.0 + 6.0 * 56.0)
	_build_edges()


func _place_node(id: String, pos: Vector2, tile: bool) -> void:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var state := PLAN.view_state(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.flat = true
	var empty := StyleBoxEmpty.new()
	for slot in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(slot, empty)
	var wh := Vector2(40, 40) if tile else Vector2(NODE_W, NODE_H)
	b.custom_minimum_size = wh
	b.size = wh
	b.clip_contents = true
	b.position = pos
	b.tooltip_text = "%s\n%s" % [str(tech.get("name", id)), PLAN.status_text(id)]
	b.pressed.connect(_on_node.bind(id))
	b.mouse_entered.connect(_on_enter.bind(id))
	b.mouse_exited.connect(_on_exit.bind(id))
	graph.add_child(b)
	var face := Face.new()
	face.state = state
	face.tile = tile
	face.queue_n = PLAN.queue_index(id)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.position = Vector2.ZERO
	face.size = wh
	var shown := _node_progress(id, state)
	face.prog = int(shown.x)
	face.need = int(shown.y)
	face.corner = PLAN.corner(id)
	face.raw = GameState.tech_state(id)
	face.selected = desk.picked == id
	var mark := _route_mark(id)
	face.route = mark != "off"
	face.route_mark = "" if mark == "off" else mark
	if mark != "off":
		route_marks[id] = mark
	b.add_child(face)
	if tile:
		var icon := TextureRect.new()
		icon.texture = Kit.icon("tech_%s" % id)
		icon.position = Vector2(8, 8)
		icon.size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		if desk.tech_mat != "" and PLAN.uses_material(id, desk.tech_mat):
			var dot := ColorRect.new()
			dot.color = CINNABAR
			dot.position = Vector2(30, 2)
			dot.size = Vector2(8, 8)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dot)
	else:
		var row := HBoxContainer.new()
		row.position = Vector2(4, 2)
		row.size = Vector2(NODE_W - 8, NODE_H - 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		row.clip_contents = true
		b.add_child(row)
		row.add_child(Kit.icon_rect("tech_%s" % id, 24))
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.clip_contents = true
		row.add_child(col)
		var nm := Kit.label(str(tech.get("name", id)), "SmallLabel")
		nm.add_theme_font_size_override("font_size", _fit_size(str(tech.get("name", id)), 96.0))
		nm.add_theme_color_override("font_color", MUTED if state == "noprereq" or state == "locked" else INK)
		nm.clip_text = true
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size = Vector2(0, 16)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		var sl := Kit.label(PLAN.status_text(id), "SmallLabel")
		sl.clip_text = true
		sl.autowrap_mode = TextServer.AUTOWRAP_OFF
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		sl.custom_minimum_size = Vector2(0, 14)
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sl)
	if state == "locked":
		b.modulate.a = LOCKED_A
	nodes[id] = b
	graph.spots[id] = Rect2(pos, wh)
	desk.debug_btns["node_" + id] = b


func _build_edges() -> void:
	var chain: Array = PLAN.spine(GameState.tech_target) if GameState.tech_target != "" else []
	var on_path := {}
	for id_v in chain:
		on_path[str(id_v)] = true
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if not graph.spots.has(id):
			continue
		for pre_v in tech.get("prereq", []):
			var pre := str(pre_v)
			if not graph.spots.has(pre):
				continue
			var kind := "miss"
			var pre_state := GameState.tech_state(pre)
			var adjacent := on_path.has(id) and on_path.has(pre) and _adjacent(chain, pre, id)
			if adjacent and not GameState.tech_done.has(id):
				kind = "path"
			elif GameState.tech_done.has(pre) and GameState.tech_done.has(id):
				kind = "done"
			elif GameState.tech_done.has(pre):
				kind = "open"
			elif pre_state == "blueprint" or pre_state == "trial" or GameState.tech_designing == pre:
				kind = "sheet"
			graph.edges.append({"from": pre, "to": id, "kind": kind})
	_route_edges()


func _paint_fade() -> void:
	var focus := desk.picked if desk.picked != "" else desk.tech_hover
	var rel := PLAN.related(focus) if focus != "" else {}
	for id_v in nodes.keys():
		var id := str(id_v)
		var b: Button = nodes[id]
		var state := PLAN.view_state(id)
		var fade := false
		if focus != "":
			fade = not rel.has(id)
		var filtered := not PLAN.passes_filter(id, desk.tech_branch, desk.tech_only_ready, desk.tech_practice, desk.tech_query)
		var alpha := 1.0
		if state == "locked":
			alpha = LOCKED_A
		if fade or filtered:
			alpha = 0.5
		b.modulate = Color(1, 1, 1, alpha)
	if graph:
		graph.queue_redraw()


func _build_footer() -> void:
	var foot_h := 32.0 if desk.tech_view == "overview" else FOOTER_H
	var bar := ColorRect.new()
	bar.color = Color("2a241c")
	bar.position = Vector2(0, 720.0 - foot_h)
	bar.size = Vector2(1280, foot_h)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	if desk.tech_view == "overview":
		var sheet := _text_button("状态表")
		sheet.add_theme_color_override("font_color", CREAM)
		sheet.position = Vector2(1100, 720.0 - foot_h + 2)
		sheet.pressed.connect(_show_legend)
		add_child(sheet)
		desk.debug_btns["tech_legend"] = sheet
		return
	var map := MiniMap.new()
	map.board = self
	map.position = Vector2(12, 720.0 - foot_h + 8)
	map.size = Vector2(280, 60)
	map.custom_minimum_size = Vector2(280, 60)
	add_child(map)
	desk.debug_btns["tech_minimap"] = map
	var era_box := VBoxContainer.new()
	era_box.position = Vector2(300, 720.0 - foot_h + 6)
	era_box.size = Vector2(150, 64)
	add_child(era_box)
	var cur := PLAN.current_era()
	for era in [1, 2, 3]:
		var prog := PLAN.era_progress(era)
		var open := GameState.era_unlocked(era)
		var mark := "●" if era == cur else ("▶" if era > cur else "◀")
		var tail := "%d/%d" % [prog.x, prog.y] if open else "未开"
		var btn := _text_button("%s 时代%s %s" % [mark, _era_han(era), tail])
		btn.add_theme_color_override("font_color", Color("e7c98a") if era == cur else CREAM)
		btn.pressed.connect(_scroll_era.bind(era))
		era_box.add_child(btn)
	var legend := VBoxContainer.new()
	legend.position = Vector2(460, 720.0 - foot_h + 4)
	legend.size = Vector2(700, 68)
	add_child(legend)
	var title := Kit.label("图例（常驻）", "SmallLabel")
	title.add_theme_color_override("font_color", CREAM)
	legend.add_child(title)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 8)
	legend.add_child(cells)
	for word_v in ["√ 已完成", "试 试制中", "图 已有图纸", "设 设计中", "可设计", "缺 缺前置", "阻 受阻", "锁 时代未开", "目标路线", "① 在队列中"]:
		var lab := Kit.label(str(word_v), "SmallLabel")
		lab.add_theme_color_override("font_color", CREAM)
		cells.add_child(lab)
	if OS.is_debug_build():
		var parts := _text_button("组件")
		parts.add_theme_color_override("font_color", CREAM)
		parts.position = Vector2(1180, 720.0 - foot_h + 4)
		parts.pressed.connect(_show_parts)
		add_child(parts)
		desk.debug_btns["tech_parts"] = parts


func _build_legend() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 48)
	panel.size = Vector2(1200, 624)
	panel.add_theme_stylebox_override("panel", _flat(PAPER, Color("c4b498"), 10, 1))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(Kit.label("节点状态与连线", "H2Label"))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	var close := Kit.button("关闭", "Button")
	close.pressed.connect(_hide_sheets)
	head.add_child(close)
	desk.debug_btns["tech_sheet_close"] = close
	box.add_child(Kit.label("形状、图标、文字各说一遍。颜色只是辅助。", "CaptionLabel"))
	for pair_v in [["done", "已完成", "去推广"], ["designing", "研发中", "暂停设计"], ["available", "可设计", "安排设计"], ["noprereq", "缺前置", "设为目标"], ["blocked", "受阻", "去补齐"], ["blueprint", "待试制", "去匠作院试制"], ["trial", "试制中", "查看试制"], ["locked", "已锁定", "无按钮"]]:
		var pair: Array = pair_v
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		box.add_child(line)
		var sample := _sample_node(str(pair[0]), str(pair[1]))
		line.add_child(sample)
		var verb := Kit.button(str(pair[2]), "PrimaryButton" if str(pair[2]) != "无按钮" else "Button")
		verb.disabled = true
		verb.custom_minimum_size = Vector2(160, 36)
		line.add_child(verb)
	var lines := LineKey.new()
	lines.custom_minimum_size = Vector2(1100, 120)
	box.add_child(lines)


func _build_parts() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(80, 36)
	panel.size = Vector2(1120, 650)
	panel.add_theme_stylebox_override("panel", _flat(PAPER, Color("c4b498"), 10, 1))
	add_child(panel)
	var scroll_box := ScrollContainer.new()
	panel.add_child(scroll_box)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1060, 0)
	box.add_theme_constant_override("separation", 10)
	scroll_box.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(Kit.label("格物图组件", "H2Label"))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(pad)
	var close := Kit.button("关闭", "Button")
	close.pressed.connect(_hide_sheets)
	head.add_child(close)
	box.add_child(Kit.label("建议卡", "H3Label"))
	box.add_child(_advice_card("把「水轮发电机」设为目标", "人力坊每月吃 20 匠，水轮一座 +12 电还不吃匠。", false, false))
	box.add_child(_advice_card("电低。先做「水轮发电机」。", "电低。先做「水轮发电机」。", true, false))
	box.add_child(_none_card())
	box.add_child(Kit.label("还缺", "H3Label"))
	box.add_child(_blocker({"text": "试制槽 2/2 满，耐火砖与坩埚排队中", "jump": "workshop", "jump_label": "匠作院"}))
	box.add_child(Kit.label("主按钮", "H3Label"))
	var verbs := HBoxContainer.new()
	verbs.add_theme_constant_override("separation", 6)
	box.add_child(verbs)
	for word_v in ["去推广", "暂停设计", "安排设计", "设为目标", "去补齐", "去匠作院试制", "查看试制"]:
		var btn := Kit.button(str(word_v), "PrimaryButton")
		btn.disabled = true
		verbs.add_child(btn)
	var link := _text_button("设为目标")
	box.add_child(link)
	if GameState.tech_target != "":
		box.add_child(Kit.label("当前目标卡", "H3Label"))
		box.add_child(_target_card())


func _sample_node(state: String, word: String) -> Control:
	var b := Control.new()
	b.custom_minimum_size = Vector2(NODE_W, NODE_H)
	var face := Face.new()
	face.state = state
	face.tile = false
	face.size = Vector2(NODE_W, NODE_H)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(face)
	var lab := Kit.label(word, "SmallLabel")
	lab.position = Vector2(28, 12)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	var icon := TextureRect.new()
	icon.texture = Kit.piece("st3_%s" % _icon_state(state))
	icon.position = Vector2(8, 13)
	icon.size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	return b


func _build_tutorial() -> void:
	var steps: Array = [
		["now", "陛下，先说清楚：我能画图纸，但造不出来。我是 AI，不是铁匠。"],
		["design", "画图纸花电。晴天我画得飞快，阴天……我尽力，别催。"],
		["prints", "画好的图纸进库，最多 3 份。再多？工匠看不过来，我也存不下。"],
		["trial", "试制靠匠人、材料和手艺。他们没干过的活，图纸再好也白搭。"],
		["accept", "不知道点什么？点‘采纳’，我替你排好。免费，不是订阅制。"],
	]
	var step := clampi(desk.tech_tutorial, 0, steps.size() - 1)
	var pair: Array = steps[step]
	var key := str(pair[0])
	tutorial_key = key
	var hole := _tutorial_hole(key)
	var shade := Shade.new()
	shade.hole = hole
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.offset_left = 0.0
	shade.offset_top = 0.0
	shade.offset_right = 0.0
	shade.offset_bottom = 0.0
	shade.custom_minimum_size = Vector2(1280, 720)
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.queue_redraw()
	tutorial_shade = shade
	var bubble := PanelContainer.new()
	var bx := minf(hole.end.x + 16.0, 760.0)
	var by := clampf(hole.position.y, 80.0, 460.0)
	bubble.position = Vector2(bx, by)
	bubble.size = Vector2(460, 168)
	bubble.add_theme_stylebox_override("panel", _flat(Color("14343a"), CYAN, 12, 2))
	add_child(bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bubble.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var face := TextureRect.new()
	face.texture = Kit.portrait_head("doushabao", "smug")
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(face)
	var said := Kit.label(str(pair[1]), "BodyLabel")
	said.add_theme_color_override("font_color", CREAM)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(said)
	var dots := ""
	for i in steps.size():
		dots += "● " if i == step else "○ "
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	box.add_child(foot)
	var dot := Kit.label(dots + "  %d / %d" % [step + 1, steps.size()], "CaptionLabel")
	dot.add_theme_color_override("font_color", CREAM)
	foot.add_child(dot)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var skip := Kit.button("跳过引导", "Button")
	skip.pressed.connect(_skip_tutorial)
	foot.add_child(skip)
	desk.debug_btns["tech_skip"] = skip
	var nxt := Kit.button("下一步", "PrimaryButton")
	if step == steps.size() - 1:
		nxt.text = "知道了"
	nxt.pressed.connect(_next_tutorial)
	foot.add_child(nxt)
	desk.debug_btns["tech_next"] = nxt
	tutorial_bubble = bubble
	call_deferred("_place_tutorial")


func _tutorial_hole(key: String) -> Rect2:
	var hole := Rect2(12, 68, 286, 220)
	if anchors.has(key) and anchors[key] is Control:
		var ctl: Control = anchors[key]
		var got := ctl.get_global_rect()
		got.position -= get_global_rect().position
		if got.size.x > 20.0 and got.size.y > 20.0:
			hole = got.grow(8)
	return hole


func _place_tutorial() -> void:
	if tutorial_shade == null or tutorial_bubble == null:
		return
	if not is_instance_valid(tutorial_shade) or not is_instance_valid(tutorial_bubble):
		return
	var hole := _tutorial_hole(tutorial_key)
	tutorial_shade.hole = hole
	tutorial_shade.queue_redraw()
	var bx := minf(hole.end.x + 16.0, 760.0)
	var by := clampf(hole.position.y, 80.0, 460.0)
	tutorial_bubble.position = Vector2(bx, by)


func _era_rails(host: HBoxContainer, height: float) -> void:
	var era := PLAN.current_era()
	for e in range(1, era):
		if not PLAN.era_complete(e):
			continue
		var rail := PanelContainer.new()
		rail.custom_minimum_size = Vector2(44, height - 8)
		rail.add_theme_stylebox_override("panel", _flat(Color("e7dcc0"), GOLD, 6, 1))
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		rail.add_child(box)
		var prog := PLAN.era_progress(e)
		box.add_child(Kit.icon_rect("st3_done", 16) if false else _mini_icon("st3_done"))
		var name := Kit.label("时代%d" % e, "SmallLabel")
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(name)
		var count := Kit.label("%d/%d" % [prog.x, prog.y], "CaptionLabel")
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)
		host.add_child(rail)


func _footer_chip(icon_name: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var icon := TextureRect.new()
	icon.texture = Kit.piece(icon_name)
	icon.custom_minimum_size = Vector2(14, 14)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var lab := Kit.label(text, "CaptionLabel")
	lab.add_theme_color_override("font_color", CREAM)
	row.add_child(lab)
	return row


func _mini_icon(name: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Kit.piece(name)
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _section_title(text: String) -> Label:
	var lab := Kit.label(text, "H3Label")
	lab.add_theme_color_override("font_color", CINNABAR)
	return lab


func _link_row(text: String, jump: String) -> Button:
	var btn := _text_button(text)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_jump.bind(jump))
	return btn


func _text_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	var empty := StyleBoxEmpty.new()
	for slot in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(slot, empty)
	btn.add_theme_color_override("font_color", CYAN)
	btn.add_theme_color_override("font_hover_color", Color("0d4e56"))
	btn.add_theme_font_size_override("font_size", 14)
	return btn


func _header_button(text: String, on: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(64, 36)
	var box := _flat(CYAN if on else Color("31423f"), Color("d9cbb6"), 6, 1)
	for slot in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(slot, box)
	btn.add_theme_color_override("font_color", CREAM)
	btn.add_theme_color_override("font_hover_color", CREAM)
	return btn


func _cell_box() -> StyleBoxFlat:
	var box := _flat(Color("fbf5e6"), Color("d8cbb0"), 4, 1)
	box.content_margin_left = 2
	box.content_margin_top = 2
	box.content_margin_right = 2
	box.content_margin_bottom = 2
	return box


func _flat(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_top = 6
	box.content_margin_right = 8
	box.content_margin_bottom = 6
	return box


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _era_han(era: int) -> String:
	var marks := ["一", "二", "三", "四"]
	if era >= 1 and era <= marks.size():
		return str(marks[era - 1])
	return str(era)


func _era_name(era: int) -> String:
	for era_v in DataDB.eras:
		var row: Dictionary = era_v
		if int(row.get("id", 0)) == era:
			return "时代%s·%s" % ["一二三".substr(era - 1, 1), str(row.get("name", ""))]
	return "时代%d" % era


func _branch_stage(tech: Dictionary) -> String:
	var branch := ""
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		if str(b.get("id", "")) == str(tech.get("branch", "")):
			branch = str(b.get("full", b.get("name", "")))
	var stage := ""
	for s_v in DataDB.stages:
		var s: Dictionary = s_v
		if int(s.get("id", 0)) == int(tech.get("stage", 0)):
			stage = "%s %s" % [str(s.get("name", "")), str(s.get("subtitle", ""))]
	return "%s · %s" % [branch, stage]


func branch_of(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	return str(tech.get("branch", ""))


func _floor_theme() -> void:
	if theme == null:
		return
	var local := theme.duplicate()
	local.set_font_size("font_size", "CaptionLabel", 13)
	theme = local


func _talent_face(who: String) -> TextureRect:
	var pid := str(TALENT_PID.get(who, ""))
	if pid == "":
		return null
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(26, 26)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.texture = Kit.portrait_head(pid, "normal")
	return rect


func _branch_row(id: String) -> int:
	var row := 0
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		var bid := str(b.get("id", ""))
		if bid == "zhong":
			continue
		if bid == id:
			return row
		row += 1
	return -1


func _slot_y(slot: String) -> float:
	if slot == "u":
		return 1.0
	if slot == "d":
		return 49.0
	return 25.0


func _icon_state(state: String) -> String:
	if state == "queued":
		return "available"
	if state == "blocked":
		return "blocked"
	return state


func _fit_size(text: String, _width: float) -> int:
	if text.length() <= 8:
		return 14
	return 13


func era3_flash_left() -> int:
	return maxi(0, _flash_until - Time.get_ticks_msec())


func _mark_era3_head(cap: Label, stage: Dictionary) -> void:
	if _flash_until <= Time.get_ticks_msec():
		return
	if int(stage.get("era", 0)) != 3:
		return
	cap.add_theme_color_override("font_color", GOLD)
	_flash_labels.append(cap)


func _open_practice_city(id: String) -> void:
	desk.open_city(GameState.practice_city(id))


func _process(_delta: float) -> void:
	if _flash_until <= 0:
		set_process(false)
		return
	var now := Time.get_ticks_msec()
	if now >= _flash_until:
		for lab_v in _flash_labels:
			var lab := lab_v as Label
			if lab != null:
				# Dropping the override leaves the last pale gold cached.
				lab.remove_theme_color_override("font_color")
				lab.add_theme_color_override("font_color", MUTED)
				lab.queue_redraw()
		_flash_labels = []
		_flash_until = 0
		set_process(false)
		return
	var phase := 0.5 + 0.5 * sin(float(now) * 0.012)
	var col := GOLD.lerp(Color("e8c56a"), phase)
	for lab_v in _flash_labels:
		var lab2 := lab_v as Label
		if lab2 != null:
			lab2.add_theme_color_override("font_color", col)


func _lock_head(era: int) -> String:
	if GameState.era_unlocked(era):
		return "已开"
	if era >= 3:
		return "第 68 回合开"
	return "第 31 回合开"


func _adjacent(chain: Array, a: String, b: String) -> bool:
	for i in chain.size() - 1:
		if str(chain[i]) == a and str(chain[i + 1]) == b:
			return true
	return false


func _target_gap(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		var key := str(key_v)
		var need := int(mats[key_v])
		var have := int(GameState.resources.get(key, 0))
		if have < need:
			return "%s %d/%d" % [str(PLAN.MAT_NAME.get(key, key)), have, need]
	return ""


func _remember_scroll() -> void:
	if scroll:
		desk.tech_scroll = scroll.scroll_horizontal


func _set_view(which: String) -> void:
	_remember_scroll()
	desk.tech_view = which
	desk._fill()


func _rewatch() -> void:
	desk.tech_tutorial = 0
	desk.tech_show_legend = false
	desk.tech_show_parts = false
	desk._fill()


func _show_legend() -> void:
	desk.tech_show_legend = true
	desk.tech_show_parts = false
	desk._fill()


func _show_parts() -> void:
	desk.tech_show_parts = true
	desk.tech_show_legend = false
	desk._fill()


func _hide_sheets() -> void:
	desk.tech_show_legend = false
	desk.tech_show_parts = false
	# Rebuilding now would delete this button inside its own click and stall the web frame.
	desk._fill.call_deferred()


func _toggle_bar() -> void:
	desk.tech_legend_bar = 0 if desk.tech_legend_bar == 1 else 1
	desk._fill()


func _adopt() -> void:
	var sug := PLAN.suggestion()
	var id := str(sug.get("id", ""))
	if id != "":
		desk.picked = id
	var jump := PLAN.adopt()
	if jump != "":
		_jump(jump)


func _clear_target() -> void:
	PLAN.clear_target()


func _make_target(id: String) -> void:
	_open_target_confirm(id)


func _run(id: String) -> void:
	var jump := PLAN.run_primary(id)
	if jump == "confirm_design":
		_open_design_confirm(id)
		return
	if jump == "confirm_trial":
		_open_trial_confirm(id)
		return
	if jump == "city":
		var dest := "kaifeng"
		if GameState.practice_gate_on and GameState.tech_state(id) == "blueprint" and not GameState.practice_ok(id):
			dest = GameState.practice_city(id)
		desk.open_city(dest)
	elif jump != "":
		_jump(jump)


func _node_progress(id: String, state: String) -> Vector2i:
	if state == "designing" or GameState.tech_designing == id:
		return Vector2i(GameState.tech_design_prog, maxi(1, GameState.design_need(id)))
	if state == "trial":
		for trial_v in GameState.tech_trials:
			var trial: Dictionary = trial_v
			if str(trial.get("id", "")) == id:
				return Vector2i(int(trial.get("prog", 0)), maxi(1, int(trial.get("need", 1))))
	return Vector2i(0, 1)


func _circ(n: int) -> String:
	var marks := ["①", "②", "③"]
	if n >= 1 and n <= marks.size():
		return str(marks[n - 1])
	return str(n)


func _focus_tech(id: String) -> void:
	desk.picked = id
	if desk.tech_view == "overview":
		desk.tech_view = "focus"
	desk._fill.call_deferred()


func _pause_design() -> void:
	GameState.pause_design()
	desk._fill.call_deferred()


func _bump_queue(id: String) -> void:
	GameState.bump_queue(id)
	desk._fill.call_deferred()


func _drop_queue(id: String) -> void:
	GameState.remove_queued(id)
	desk._fill.call_deferred()


func _open_design_confirm(id: String) -> void:
	var cur: Dictionary = DataDB.tech_by_id.get(GameState.tech_designing, {})
	var nxt: Dictionary = DataDB.tech_by_id.get(id, {})
	var need := maxi(1, GameState.design_need(GameState.tech_designing))
	var left := maxi(0, need - GameState.tech_design_prog)
	var eta := int(ceil(float(left) / 10.0))
	var full := GameState.tech_queue.size() >= GameState.QUEUE_CAP
	var place := GameState.tech_queue.size() + 1
	var lines := "正在设计 %s（%d/%d，约 %d 回合）。\n%s 要怎么安排？" % [
		str(cur.get("name", GameState.tech_designing)), GameState.tech_design_prog, need, eta, str(nxt.get("name", id)),
	]
	var back := "排在后面（第 %d 位）" % place
	_open_choice(lines, back, not full, "队列已满 3/3" if full else "", _queue_behind.bind(id), _swap_to.bind(id))


func _open_trial_confirm(id: String) -> void:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var cost: Dictionary = tech.get("cost", {})
	var bits: PackedStringArray = []
	var craft := int(cost.get("craft", 0))
	if craft > 0:
		bits.append("匠 %d" % craft)
	var mats: Dictionary = tech.get("materials", {})
	for key_v in mats.keys():
		var key := str(key_v)
		bits.append("%s %d" % [str(PLAN.MAT_NAME.get(key, key)), int(mats[key_v])])
	if bits.is_empty():
		bits.append("匠 0")
	var used := "%d/%d" % [GameState.tech_trials.size(), GameState.trial_slots()]
	var turns := maxi(2, int(ceil(float(craft) / 12.0)))
	var lines := "开试制要花 %s，占 1 个试制槽（%s）。\n开工一次付清：%s；工期 %d 回合；占 1 个试制槽（%s）。" % ["、".join(bits), used, "、".join(bits), turns, used]
	_open_choice(lines, "开始试制", true, "", _start_trial.bind(id), _start_trial.bind(""))


func _open_choice(lines: String, yes_text: String, yes_on: bool, why: String, yes: Callable, alt: Callable) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var panel := PanelContainer.new()
	panel.position = Vector2(340, 180)
	panel.custom_minimum_size = Vector2(296 if yes_text == "确定" else 600, 160)
	panel.size = Vector2(320 if yes_text == "确定" else 600, 280)
	if yes_text == "确定":
		panel.position = Vector2(480, 200)
	panel.add_theme_stylebox_override("panel", _flat(CREAM, Color("1f7f8c"), 10, 2))
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var body := Kit.label(lines, "BodyLabel")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(280 if yes_text == "确定" else 560, 72)
	box.add_child(body)
	if why != "":
		var note := Kit.label(why, "CaptionLabel")
		note.add_theme_color_override("font_color", CINNABAR)
		box.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var yes_btn := Kit.button(yes_text, "PrimaryButton")
	yes_btn.custom_minimum_size = Vector2(180, 40)
	yes_btn.disabled = not yes_on
	yes_btn.focus_mode = Control.FOCUS_ALL
	yes_btn.pressed.connect(yes)
	row.add_child(yes_btn)
	var alt_btn := Kit.button("先做这个", "Button")
	alt_btn.custom_minimum_size = Vector2(140, 40)
	alt_btn.pressed.connect(alt)
	if yes_text == "开始试制" or yes_text == "确定":
		alt_btn.visible = false
	row.add_child(alt_btn)
	var no_btn := Kit.button("取消" if yes_text == "确定" else "算了", "Button")
	no_btn.custom_minimum_size = Vector2(100, 40)
	no_btn.pressed.connect(_dismiss_choice)
	row.add_child(no_btn)
	desk.debug_btns["tech_yes"] = yes_btn
	desk.debug_btns["tech_swap"] = alt_btn
	desk.debug_btns["tech_no"] = no_btn
	if yes_on:
		_focus_later.call_deferred(yes_btn)
	_choice = panel
	_choice_dim = dim


func _focus_later(btn: Button) -> void:
	if btn != null and is_instance_valid(btn) and btn.is_inside_tree():
		btn.grab_focus()


func _queue_behind(id: String) -> void:
	GameState.start_design(id)
	_dismiss_choice()


func _swap_to(id: String) -> void:
	if id == "":
		_dismiss_choice()
		return
	GameState.swap_design(id)
	_dismiss_choice()


func _start_trial(id: String) -> void:
	if id != "":
		GameState.start_trial(id)
	_dismiss_choice()
	if id != "":
		_jump.call_deferred("workshop")


func _dismiss_choice() -> void:
	var panel := _choice
	var dim := _choice_dim
	_choice = null
	_choice_dim = null
	desk.debug_btns.erase("tech_yes")
	desk.debug_btns.erase("tech_swap")
	desk.debug_btns.erase("tech_no")
	if panel != null and is_instance_valid(panel):
		panel.visible = false
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim != null and is_instance_valid(dim):
		dim.visible = false
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_choice.call_deferred(panel, dim)
	desk._fill.call_deferred()


func _drop_choice(panel: Node, dim: Node) -> void:
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	if dim != null and is_instance_valid(dim):
		dim.queue_free()


func _jump(which: String) -> void:
	desk.open(which)


func _toggle_fold(key: String) -> void:
	desk.tech_fold = "" if desk.tech_fold == key else key
	desk._fill()


func _on_branch(index: int, branch: OptionButton) -> void:
	desk.tech_branch = str(branch.get_item_metadata(index))
	_paint_fade()


func _on_ready(on: bool) -> void:
	desk.tech_only_ready = on
	_paint_fade()


func _on_practice(on: bool) -> void:
	desk.tech_practice = on
	_paint_fade()


func _on_mat(index: int, mat: OptionButton) -> void:
	desk.tech_mat = str(mat.get_item_metadata(index))
	desk._fill()


func _on_query(text: String) -> void:
	desk.tech_query = text
	if name_banner and text != "":
		name_banner.text = "搜索：%s" % text
	_paint_fade()


func _on_node(id: String) -> void:
	_remember_scroll()
	if desk.picked == id and desk.tech_view != "overview":
		desk.picked = ""
		desk.tech_fold = ""
	else:
		desk.picked = id
		desk.tech_fold = ""
		if desk.tech_view == "overview":
			desk.tech_view = "focus"
	desk._fill()


func _on_enter(id: String) -> void:
	desk.tech_hover = id
	if name_banner:
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		name_banner.text = "%s    %s" % [str(tech.get("name", id)), PLAN.status_text(id)]
	_paint_fade()


func _on_exit(id: String) -> void:
	if desk.tech_hover == id:
		desk.tech_hover = ""
		_paint_fade()


func _skip_tutorial() -> void:
	GameState.tech_tutorial_done = true
	desk.tech_tutorial = -1
	desk._fill()


func _next_tutorial() -> void:
	if desk.tech_tutorial >= 4:
		_skip_tutorial()
		return
	desk.tech_tutorial += 1
	desk._fill()


func _input(event: InputEvent) -> void:
	if _choice != null and event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			var yes: Button = desk.debug_btns.get("tech_yes")
			if yes != null and not yes.disabled:
				yes.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and scroll != null:
		var key2 := event as InputEventKey
		if key2.keycode == KEY_LEFT:
			_apply_scroll(desk.tech_scroll - int(COL_W))
			get_viewport().set_input_as_handled()
			return
		if key2.keycode == KEY_RIGHT:
			_apply_scroll(desk.tech_scroll + int(COL_W))
			get_viewport().set_input_as_handled()
			return
	if event is InputEventPanGesture and scroll != null:
		var pan := event as InputEventPanGesture
		_apply_scroll(desk.tech_scroll + int(pan.delta.x))
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.ctrl_pressed and mb.pressed:
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_view("focus")
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_view("overview")
		return
	if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		if scroll == null:
			return
		var over := scroll.get_global_rect().has_point(mb.global_position)
		if not over and scroll.size.x < 2.0:
			over = true
		if not over:
			return
		var step := -107 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 107
		_apply_scroll(desk.tech_scroll + step)
		get_viewport().set_input_as_handled()


func _default_scroll(era: int) -> int:
	for stage_v in DataDB.stages:
		var stage: Dictionary = stage_v
		if int(stage.get("era", 0)) == era:
			return (int(stage.get("col_from", 1)) - 1) * int(COL_W)
	return 0


func _view_w() -> float:
	return 952.0


func _apply_scroll(n: int) -> void:
	if graph == null:
		desk.tech_scroll = n
		return
	var max_s := int(maxf(0.0, graph.need.x - _view_w()))
	n = clampi(n, 0, max_s)
	desk.tech_scroll = n
	if scroll == null:
		return
	var bar := scroll.get_h_scroll_bar()
	bar.max_value = maxf(graph.need.x, _view_w())
	bar.page = _view_w()
	scroll.scroll_horizontal = n


func _bring_into_view(id: String) -> void:
	if id == "" or graph == null or not graph.spots.has(id):
		return
	var rect: Rect2 = graph.spots[id]
	var left := float(desk.tech_scroll)
	var right := left + _view_w()
	if rect.position.x >= left - 1.0 and rect.end.x <= right + 1.0:
		return
	_apply_scroll(int(rect.position.x - 8.0))


func _on_tree_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.ctrl_pressed or not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN and mb.button_index != MOUSE_BUTTON_WHEEL_LEFT and mb.button_index != MOUSE_BUTTON_WHEEL_RIGHT:
		return
	var step := 107
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_LEFT:
		step = -107
	_apply_scroll(desk.tech_scroll + step)
	get_viewport().set_input_as_handled()


func _on_paper_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag = false
			_press = mb.position
			_drag_from = desk.tech_scroll
			return
		var dragged := _drag
		_drag = false
		if not dragged:
			desk.picked = ""
			desk.tech_fold = ""
			desk._fill()
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			return
		if _press.distance_to(motion.position) < 6.0:
			return
		_drag = true
		_apply_scroll(_drag_from - int(motion.position.x - _press.x))


func _route_mark(id: String) -> String:
	if GameState.tech_target == "":
		return "off"
	var unfinished: Array = []
	for step_v in PLAN.spine(GameState.tech_target):
		var step := str(step_v)
		if not GameState.tech_done.has(step):
			unfinished.append(step)
	if unfinished.find(id) < 0:
		return "off"
	if unfinished.size() <= 1:
		return "标"
	if id == str(unfinished[0]):
		return "起"
	if id == GameState.tech_target:
		return "标"
	return ""


func _scroll_era(era: int) -> void:
	if GameState.era_unlocked(era):
		_apply_scroll(_default_scroll(era))
		return
	if graph == null:
		return
	_apply_scroll(int(graph.need.x - NEXT_W))


func _minimap_to(frac: float) -> void:
	var total := 13.0 * COL_W
	var center := clampf(frac, 0.0, 1.0) * total
	_apply_scroll(int(center - _view_w() * 0.5))


func consume_escape() -> bool:
	if _choice != null:
		_dismiss_choice()
		return true
	if desk.picked != "":
		desk.picked = ""
		desk.tech_fold = ""
		desk._fill()
		return true
	return false


func _tech_col(id: String) -> int:
	return int(DataDB.tech_by_id.get(id, {}).get("col", 1))


func _tech_era(id: String) -> int:
	return int(DataDB.tech_by_id.get(id, {}).get("era", 1))


func _edge_gutters(pre: String, id: String) -> Array:
	var ca := _tech_col(pre)
	var cb := _tech_col(id)
	var out: Array = [ca]
	if absi(cb - ca) == 2:
		out.append(mini(ca, cb) + 1)
	return out


func _route_edges() -> void:
	edge_routes.clear()
	if desk == null or desk.tech_view == "overview" or graph == null:
		return
	var full: Array = []
	var stubs: Array = []
	for edge_v in graph.edges:
		var edge: Dictionary = (edge_v as Dictionary).duplicate()
		var pre := str(edge.get("from", ""))
		var id := str(edge.get("to", ""))
		var span := absi(_tech_col(id) - _tech_col(pre))
		edge["span"] = span
		var chip := false
		if graph.spots.has(pre) and graph.spots.has(id):
			var sa: Rect2 = graph.spots[pre]
			var sb: Rect2 = graph.spots[id]
			chip = sa.size.x < 100.0 or sb.size.x < 100.0
		if chip or _tech_era(pre) != _tech_era(id) or span >= 3 or span <= 0:
			stubs.append(edge)
		else:
			full.append(edge)
	var by_gutter := {}
	for edge_v2 in full:
		var edge2: Dictionary = edge_v2
		for gutter_v in _edge_gutters(str(edge2.get("from", "")), str(edge2.get("to", ""))):
			var gutter := int(gutter_v)
			if not by_gutter.has(gutter):
				by_gutter[gutter] = []
			var bucket: Array = by_gutter[gutter]
			bucket.append(edge2)
	var dropped := {}
	for col_v in by_gutter.keys():
		var list: Array = by_gutter[col_v]
		var ranked: Array = list.duplicate()
		ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("span", 0)) > int(b.get("span", 0)))
		var alive := {}
		for edge_v3 in list:
			alive[str((edge_v3 as Dictionary).get("from", ""))] = true
		var used := alive.size()
		if used <= 7:
			continue
		for edge_v4 in ranked:
			if used <= 7:
				break
			var edge4: Dictionary = edge_v4
			var key := "%s>%s" % [str(edge4.get("from", "")), str(edge4.get("to", ""))]
			if dropped.has(key):
				continue
			dropped[key] = true
			var src4 := str(edge4.get("from", ""))
			var still := false
			for edge_v5 in list:
				var edge5: Dictionary = edge_v5
				var key5 := "%s>%s" % [str(edge5.get("from", "")), str(edge5.get("to", ""))]
				if str(edge5.get("from", "")) == src4 and not dropped.has(key5):
					still = true
					break
			if not still and alive.has(src4):
				alive.erase(src4)
				used -= 1
	var lane_x := {}
	for col_v2 in by_gutter.keys():
		var col := int(col_v2)
		var list2: Array = by_gutter[col]
		var sources: Array = []
		for edge_v6 in list2:
			var edge6: Dictionary = edge_v6
			var key6 := "%s>%s" % [str(edge6.get("from", "")), str(edge6.get("to", ""))]
			if dropped.has(key6):
				continue
			var src6 := str(edge6.get("from", ""))
			if not sources.has(src6):
				sources.append(src6)
		sources.sort()
		var gutter_left := float(col - 1) * COL_W + NODE_W
		for i in sources.size():
			lane_x["%d|%s" % [col, str(sources[i])]] = gutter_left + 8.0 + float(i) * 6.0
	for edge_v7 in full:
		var edge7: Dictionary = edge_v7
		var pre7 := str(edge7.get("from", ""))
		var id7 := str(edge7.get("to", ""))
		var key7 := "%s>%s" % [pre7, id7]
		if dropped.has(key7):
			stubs.append(edge7)
			continue
		var pts := _route_pts(pre7, id7, lane_x)
		if pts.size() < 2:
			stubs.append(edge7)
			continue
		edge_routes.append({"from": pre7, "to": id7, "kind": str(edge7.get("kind", "")), "pts": pts, "stub": false})
	_place_stubs(stubs)


func _place_stubs(stubs: Array) -> void:
	var taken: Array = []
	for stub_v in stubs:
		var stub: Dictionary = stub_v
		var src_id := str(stub.get("from", ""))
		var dest_id := str(stub.get("to", ""))
		edge_routes.append({"from": src_id, "to": dest_id, "kind": str(stub.get("kind", "")), "stub": true, "pts": PackedVector2Array()})
		if not graph.spots.has(dest_id):
			continue
		var dest: Rect2 = graph.spots[dest_id]
		var text := "← %s" % PLAN.short_name(src_id)
		var spot := _stub_spot(dest, taken, true)
		if spot.size.x < 8.0:
			spot = _stub_spot(dest, taken, false)
		if spot.size.x < 8.0:
			continue
		var btn := _text_button(text)
		btn.tooltip_text = text
		btn.clip_text = true
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", INK)
		btn.add_theme_color_override("font_hover_color", INK)
		btn.position = spot.position
		btn.size = spot.size
		btn.custom_minimum_size = Vector2(0, 0)
		btn.pressed.connect(_stub_pick.bind(src_id))
		graph.add_child(btn)
		taken.append(spot)


func _stub_spot(dest: Rect2, taken: Array, avoid_routes: bool) -> Rect2:
	var lanes := _stub_lanes(dest)
	for lane_v in lanes:
		var lane: Rect2 = lane_v
		var y := lane.position.y
		while y + 16.0 <= lane.end.y + 0.5:
			var spot := Rect2(lane.position.x, y, lane.size.x, 16.0)
			if _stub_clear(spot, taken, avoid_routes):
				return spot
			y += 18.0
	return Rect2()


func _stub_lanes(dest: Rect2) -> Array:
	var lanes: Array = []
	var row := clampi(int(floor((dest.position.y - STAGE_H) / ROW_H)), 0, 5)
	var top := STAGE_H + float(row) * ROW_H
	var bottom := top + ROW_H
	if dest.size.x < 100.0 and _next_x > COL_W:
		var cell_x := _next_x - COL_W
		lanes.append(Rect2(cell_x + 6.0, top + 2.0, NODE_W - 12.0, ROW_H - 4.0))
		var gutter_x := _next_x - 54.0
		if gutter_x >= 2.0:
			lanes.append(Rect2(gutter_x, top + 2.0, 48.0, ROW_H - 4.0))
		return lanes
	var above_y := dest.position.y - 18.0
	if above_y >= top:
		lanes.append(Rect2(dest.position.x, above_y, minf(dest.size.x, 148.0), 16.0))
	var below_y := dest.end.y + 2.0
	if below_y + 16.0 <= bottom:
		lanes.append(Rect2(dest.position.x, below_y, minf(dest.size.x, 148.0), 16.0))
	var gutter_x := dest.position.x - 54.0
	if gutter_x >= 2.0:
		lanes.append(Rect2(gutter_x, top + 2.0, 48.0, ROW_H - 4.0))
	return lanes


func _stub_clear(spot: Rect2, taken: Array, avoid_routes: bool) -> bool:
	for id_v in graph.spots.keys():
		var rect: Rect2 = graph.spots[id_v]
		if rect.intersects(spot):
			return false
	for prev_v in taken:
		var prev: Rect2 = prev_v
		if prev.intersects(spot):
			return false
	if avoid_routes and _stub_hits_route(spot):
		return false
	return true


func _stub_hits_route(spot: Rect2) -> bool:
	var pad := spot.grow(2.0)
	for route_v in edge_routes:
		var route: Dictionary = route_v
		var pts: PackedVector2Array = route.get("pts", PackedVector2Array())
		if pts.size() < 2:
			continue
		for i in pts.size() - 1:
			if _stub_seg_hits(pts[i], pts[i + 1], pad):
				return true
	return false


func _stub_seg_hits(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	var min_x := minf(a.x, b.x)
	var max_x := maxf(a.x, b.x)
	var min_y := minf(a.y, b.y)
	var max_y := maxf(a.y, b.y)
	if max_x < rect.position.x or min_x > rect.end.x:
		return false
	if max_y < rect.position.y or min_y > rect.end.y:
		return false
	return true


func _stub_pick(id: String) -> void:
	desk.picked = id
	desk.tech_fold = ""
	_remember_scroll()
	desk._fill()


func _route_pts(pre: String, id: String, lane_x: Dictionary) -> PackedVector2Array:
	if not graph.spots.has(pre) or not graph.spots.has(id):
		return PackedVector2Array()
	var ra: Rect2 = graph.spots[pre]
	var rb: Rect2 = graph.spots[id]
	var col_a := _tech_col(pre)
	var col_b := _tech_col(id)
	var span := absi(col_b - col_a)
	var out := Vector2(ra.end.x, ra.get_center().y)
	var inn := Vector2(rb.position.x, rb.get_center().y)
	var lane_a := float(lane_x.get("%d|%s" % [col_a, pre], -1.0))
	if lane_a < 0.0:
		return PackedVector2Array()
	if span == 1:
		return PackedVector2Array([out, Vector2(lane_a, out.y), Vector2(lane_a, inn.y), inn])
	var mid_col := mini(col_a, col_b) + 1
	var lane_b := float(lane_x.get("%d|%s" % [mid_col, pre], -1.0))
	if lane_b < 0.0:
		return PackedVector2Array()
	var channel := _channel_y(mid_col, rb)
	if channel < 0.0:
		return PackedVector2Array()
	return PackedVector2Array([
		out,
		Vector2(lane_a, out.y),
		Vector2(lane_a, channel),
		Vector2(lane_b, channel),
		Vector2(lane_b, inn.y),
		inn,
	])


func _channel_y(mid_col: int, dest: Rect2) -> float:
	var row := int(floor((dest.position.y - STAGE_H) / ROW_H))
	row = clampi(row, 0, 5)
	var row_top := STAGE_H + float(row) * ROW_H
	var candidates: Array = [row_top + ROW_H * 0.5, row_top + 12.0, row_top + ROW_H - 12.0]
	var left := float(mid_col - 1) * COL_W
	var right := left + NODE_W
	for y_v in candidates:
		var y := float(y_v)
		var blocked := false
		for id_v in graph.spots.keys():
			var rect: Rect2 = graph.spots[id_v]
			if rect.end.x <= left + 0.5 or rect.position.x >= right - 0.5:
				continue
			if y > rect.position.y + 0.5 and y < rect.end.y - 0.5:
				blocked = true
				break
		if not blocked:
			return y
	return -1.0


func _cream(text: String, kind: String) -> Label:
	var lab := Kit.label(text, kind)
	lab.add_theme_color_override("font_color", CREAM)
	lab.autowrap_mode = TextServer.AUTOWRAP_OFF
	lab.clip_text = true
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return lab


func _wrap_cream(text: String, kind: String, width: float = -1.0) -> Label:
	var lab := _cream(text, kind)
	var w := CARD_W - 36.0 if width < 0.0 else width
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.clip_text = false
	lab.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	lab.custom_minimum_size = Vector2(w, 0)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lab


func _build_card(id: String) -> void:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	if tech.is_empty() or graph == null or not graph.spots.has(id):
		return
	var panel := PanelContainer.new()
	panel.name = "NodeCard"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", _flat(Color("1c2826"), GOLD, 6, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CARD_W - 36.0, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	if desk.tech_fold == "history":
		_card_history(box, tech)
	else:
		_card_body(box, id, tech)
	add_child(panel)
	var want := box.get_combined_minimum_size().y + 28.0
	var bottom := 636.0
	var top_min := HEADER_H + 4.0
	var max_h := bottom - top_min
	var h := clampf(want, 160.0, minf(560.0, max_h))
	panel.custom_minimum_size = Vector2(CARD_W, h)
	panel.size = Vector2(CARD_W, h)
	var rect: Rect2 = graph.spots[id]
	var header_h := float(layout_box.get("header_h", HEADER_H))
	var left_w := float(layout_box.get("left_w", LEFT_W))
	var node_x := left_w + NAME_W + rect.position.x - float(desk.tech_scroll)
	var node_y := header_h + rect.position.y
	var x := node_x + rect.size.x + 8.0
	if x + CARD_W > 1272.0:
		x = node_x - 8.0 - CARD_W
	var y := clampf(node_y, top_min, bottom - h)
	panel.position = Vector2(maxf(8.0, x), y)
	panel.set_meta("card_id", id)
	desk.debug_btns["tech_card"] = panel


func _card_history(box: VBoxContainer, tech: Dictionary) -> void:
	var title := _wrap_cream(str(tech.get("name", "")), "H3Label")
	box.add_child(title)
	box.add_child(_wrap_cream(str(tech.get("history", "")), "SmallLabel"))
	box.add_child(_wrap_cream("豆沙包能做的 / 大宋得自己做的", "SmallLabel"))
	box.add_child(_wrap_cream("能跳过：%s" % str(tech.get("skip", "")), "SmallLabel"))
	box.add_child(_wrap_cream("跳不过：%s" % str(tech.get("noskip", "")), "SmallLabel"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	var back := Kit.button("返回", "Button")
	back.pressed.connect(_card_back)
	row.add_child(back)
	var close := Kit.button("关闭", "Button")
	close.pressed.connect(_close_card)
	row.add_child(close)


func _card_body(box: VBoxContainer, id: String, tech: Dictionary) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	head.add_child(Kit.icon_rect("tech_%s" % id, 40))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_wrap_cream(str(tech.get("name", id)), "H3Label", CARD_W - 96.0))
	titles.add_child(_wrap_cream("%s · %s" % [_branch_stage(tech), id], "SmallLabel", CARD_W - 96.0))
	var corner := PLAN.corner(id)
	var status := PLAN.card_status(id)
	box.add_child(_wrap_cream(("%s  %s" % [corner, status]).strip_edges(), "SmallLabel"))
	var pres: Array = tech.get("prereq", [])
	if not pres.is_empty():
		for pre_v in pres:
			var pre := str(pre_v)
			var pre_tech: Dictionary = DataDB.tech_by_id.get(pre, {})
			var done := GameState.tech_done.has(pre)
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			line.custom_minimum_size = Vector2(CARD_W - 36.0, 18)
			box.add_child(line)
			var mark := _cream("√" if done else "×", "SmallLabel")
			mark.add_theme_color_override("font_color", Color("7dcea0") if done else CINNABAR)
			mark.custom_minimum_size = Vector2(16, 18)
			line.add_child(mark)
			if done:
				var done_name := _cream(str(pre_tech.get("name", pre)), "SmallLabel")
				done_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(done_name)
			else:
				var link := _text_button(str(pre_tech.get("name", pre)))
				link.add_theme_color_override("font_color", CREAM)
				link.clip_text = true
				link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				link.pressed.connect(_on_node.bind(pre))
				line.add_child(link)
			var pre_status := _cream(PLAN.status_text(pre), "SmallLabel")
			pre_status.custom_minimum_size = Vector2(124, 18)
			pre_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			line.add_child(pre_status)
	var cost: Dictionary = tech.get("cost", {})
	var cost_bits := PackedStringArray()
	cost_bits.append("设计 %d 电" % GameState.design_need(id))
	cost_bits.append("试制 %d 匠" % int(cost.get("craft", 0)))
	var mats: Dictionary = tech.get("materials", {})
	var short_mat := false
	for key_v in mats.keys():
		var key := str(key_v)
		var need := int(mats[key_v])
		var have := int(GameState.resources.get(key, 0))
		if have < need:
			short_mat = true
		cost_bits.append("%s %d" % [str(PLAN.MAT_NAME.get(key, key)), need])
	cost_bits.append("%d 回合" % PLAN._trial_turns(id))
	var cost_line := _wrap_cream(" · ".join(cost_bits), "SmallLabel")
	if short_mat:
		cost_line.add_theme_color_override("font_color", CINNABAR)
	box.add_child(cost_line)
	if str(tech.get("practice", "")) != "":
		var practice: Dictionary = PLAN.practice_row(id)
		var site_name := str(GameState.PRACTICE_NAME.get(GameState.practice_site(id), "实践"))
		var have_n := int(practice.get("have", 0))
		var need_n := int(practice.get("need", 0))
		box.add_child(_wrap_cream("实践 %s %d/%d" % [site_name, mini(have_n, need_n), need_n], "SmallLabel"))
	box.add_child(_wrap_cream(str(tech.get("effect", "")), "SmallLabel"))
	var act: Dictionary = PLAN.card_action(id)
	var verb := str(act.get("text", ""))
	var hint := str(act.get("hint", ""))
	var jump := str(act.get("jump", ""))
	if verb != "" or hint != "":
		var act_row := HBoxContainer.new()
		act_row.add_theme_constant_override("separation", 6)
		box.add_child(act_row)
		if verb != "":
			var primary := Kit.button(verb, "PrimaryButton")
			primary.disabled = not bool(act.get("enabled", false))
			primary.pressed.connect(_card_primary.bind(id))
			act_row.add_child(primary)
			desk.debug_btns["tech_verb"] = primary
			if PLAN.view_state(id) == "queued":
				desk.debug_btns["queue_drop_%d" % (PLAN.queue_index(id) - 1)] = primary
		if hint != "":
			var hint_btn := _text_button(hint)
			hint_btn.add_theme_color_override("font_color", CREAM)
			if jump == "swap":
				hint_btn.pressed.connect(_open_design_confirm.bind(id))
			elif jump == "bump":
				hint_btn.pressed.connect(_bump_queue.bind(id))
				desk.debug_btns["queue_up_%d" % (PLAN.queue_index(id) - 1)] = hint_btn
			elif jump == "blocked":
				hint_btn.pressed.connect(_jump.bind(PLAN._blocked_jump(id)))
			elif jump == "workshop":
				hint_btn.pressed.connect(_jump.bind("workshop"))
			elif jump == "city":
				hint_btn.pressed.connect(_open_practice_city.bind(id))
			elif jump != "":
				hint_btn.pressed.connect(_on_node.bind(jump))
			act_row.add_child(hint_btn)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	box.add_child(foot)
	var target_btn := Kit.button("取消目标" if GameState.tech_target == id else "设为目标", "Button")
	if GameState.tech_target == id:
		target_btn.pressed.connect(_clear_target)
	else:
		target_btn.disabled = not PLAN.show_target_link(id)
		target_btn.pressed.connect(_open_target_confirm.bind(id))
	foot.add_child(target_btn)
	desk.debug_btns["tech_make_target"] = target_btn
	var hist := Kit.button("史册", "Button")
	hist.pressed.connect(_open_history)
	foot.add_child(hist)
	desk.debug_btns["tech_history"] = hist
	var close_btn := Kit.button("关闭", "Button")
	close_btn.pressed.connect(_close_card)
	foot.add_child(close_btn)
	desk.debug_btns["tech_card_close"] = close_btn


func _card_primary(id: String) -> void:
	var act: Dictionary = PLAN.card_action(id)
	if not bool(act.get("enabled", false)):
		return
	var text := str(act.get("text", ""))
	if text == "开始设计" or text == "加入队列":
		GameState.start_design(id)
		desk._fill()
	elif text == "移出队列":
		GameState.remove_queued(id)
		desk._fill()
	elif text == "暂停设计":
		GameState.pause_design()
		desk._fill()
	elif text == "开始试制":
		_open_trial_confirm(id)
	elif text == "去补齐":
		_jump(PLAN._blocked_jump(id))
	elif text == "查看试制":
		_jump("workshop")
	elif text == "去推广":
		desk.open_city(GameState.practice_city(id) if GameState.practice_gate_on else "kaifeng")


func _card_back() -> void:
	desk.tech_fold = ""
	desk._fill()


func _close_card() -> void:
	desk.picked = ""
	desk.tech_fold = ""
	desk._fill()


func _open_history() -> void:
	desk.tech_fold = "history"
	desk._fill()


func _open_target_confirm(id: String) -> void:
	var lines := _target_lines(id)
	_open_choice(lines, "确定", true, "", _confirm_target.bind(id), _confirm_target.bind(""))


func _confirm_target(id: String) -> void:
	if id != "":
		PLAN.set_target(id)
		desk.picked = id
	_dismiss_choice()


func _target_lines(id: String) -> String:
	var tech: Dictionary = DataDB.tech_by_id.get(id, {})
	var prev: Dictionary = PLAN.target_preview(id)
	var lines := PackedStringArray()
	lines.append("设为目标：%s" % str(tech.get("name", id)))
	var chain: Array = prev.get("chain", [])
	if chain.size() >= 2:
		if chain.size() > 4:
			var head: Dictionary = DataDB.tech_by_id.get(str(chain[0]), {})
			var tail: Dictionary = DataDB.tech_by_id.get(str(chain[chain.size() - 1]), {})
			lines.append("路线：%s → … → %s（共 %d 项）" % [str(head.get("name", "")), str(tail.get("name", "")), chain.size()])
		else:
			var bits := PackedStringArray()
			for step_v in chain:
				var node: Dictionary = DataDB.tech_by_id.get(str(step_v), {})
				bits.append(str(node.get("name", str(step_v))))
			lines.append("路线：%s" % " → ".join(bits))
	var now: Array = prev.get("now", [])
	var room := int(prev.get("room", 0))
	if now.is_empty():
		lines.append("路线上暂时没有能设计的项，前置齐后自动排入。")
	elif room <= 0:
		lines.append("队列已满 %d/%d，新路线等空位。原来排着的 %d 项不动，不想要可以在左栏队列里移出。" % [GameState.QUEUE_CAP, GameState.QUEUE_CAP, GameState.tech_queue.size()])
	elif room >= now.size():
		lines.append("现在排入 %d 项：%s" % [now.size(), _join_names(now)])
	else:
		var take: Array = now.slice(0, room)
		lines.append("现在排入 %d 项：%s；其余 %d 项等空位" % [room, _join_names(take), now.size() - room])
	if int(prev.get("later", 0)) > 0:
		lines.append("其余 %d 项前置齐后自动排入。" % int(prev.get("later", 0)))
	var old := str(prev.get("old_target", ""))
	if old != "":
		var old_tech: Dictionary = DataDB.tech_by_id.get(old, {})
		lines.append("当前目标「%s」会被替换。" % str(old_tech.get("name", old)))
	return "\n".join(lines)


func _join_names(ids: Array) -> String:
	var bits := PackedStringArray()
	for id_v in ids:
		var node: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
		bits.append(str(node.get("name", str(id_v))))
	return "、".join(bits)


class Face extends Control:
	var state := "available"
	var tile := false
	var queue_n := 0
	var prog := 0
	var need := 1
	var route := false
	var route_mark := ""
	var corner := ""
	var raw := ""
	var selected := false

	func _ready() -> void:
		set_process(state == "designing")

	func _process(_delta: float) -> void:
		var t := float(Time.get_ticks_msec() % 1600) / 1600.0
		modulate.a = 0.8 + 0.2 * sin(t * TAU)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var paint := state
		if state == "blocked":
			paint = "blueprint" if raw == "blueprint" else "designing"
		if tile:
			var tex := Kit.piece("tile3_%s" % _key())
			if tex:
				draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			_marks()
			return
		if paint == "done":
			_round(r, Color("d8b864"), Color("8c6d1f"), 1.0)
		elif paint == "designing":
			_round(r, Color("fbf5e6"), Color("2e7d8c"), 3.0)
			_ring(Color("2e7d8c"))
		elif paint == "queued" or paint == "available":
			_round(r, Color("f6efdf"), Color("3a3026"), 2.0)
		elif paint == "noprereq":
			draw_rect(r, Color("d9d2c3"), true)
			_dashed_rect(r, Color("8f8574"))
		elif paint == "blueprint":
			_round(r, Color("d3e0e4"), Color("2e7d8c"), 1.0)
			for gx in range(3, int(r.size.x), 8):
				draw_line(Vector2(r.position.x + gx, r.position.y), Vector2(r.position.x + gx, r.end.y), Color("2e7d8c", 0.25), 1.0, true)
		elif paint == "trial":
			_round(r, Color("e8cfa6"), Color("a0612b"), 3.0)
			_ring(Color("a0612b"))
		else:
			_round(r, Color("e7e0d4"), Color("e7e0d4"), 0.0)
		_marks()

	func _marks() -> void:
		if route:
			draw_rect(Rect2(Vector2(-5, -5), size + Vector2(10, 10)), Color("2f8f6f"), false, 3.0)
		if selected:
			draw_rect(Rect2(Vector2(3, 4), size), Color(0, 0, 0, 0.28), false, 4.0)
			draw_rect(Rect2(Vector2(-1, -1), size + Vector2(2, 2)), Color("2a241c"), false, 2.0)
		var corner_w := 0.0
		if corner != "":
			corner_w = maxf(18.0, float(corner.length()) * 13.0)
			var at := Vector2(size.x - corner_w + 8.0, -10.0)
			draw_rect(Rect2(at, Vector2(corner_w, 18)), _corner_bg(), true)
			var font := get_theme_font("font", "Label")
			if font:
				draw_string(font, at + Vector2(0, 14), corner, HORIZONTAL_ALIGNMENT_CENTER, corner_w, 13, _corner_fg())
		if state == "queued" and queue_n > 0:
			var bx := size.x - 18.0
			if corner_w > 0.0:
				bx = size.x - corner_w + 8.0 - 20.0
			_badge(Vector2(bx, -8.0))
		if route_mark != "":
			var stamp := Rect2(size.x - 18.0, size.y - 18.0, 16, 16)
			draw_rect(stamp, Color("2f8f6f"), true)
			var font2 := get_theme_font("font", "Label")
			if font2:
				draw_string(font2, stamp.position + Vector2(0, 13), route_mark, HORIZONTAL_ALIGNMENT_CENTER, 16, 13, Color("fbf5e6"))

	func _corner_bg() -> Color:
		if corner == "设" or corner == "阻":
			return Color("c23b2a")
		if corner == "试":
			return Color("a0612b")
		if corner == "图":
			return Color("2e7d8c")
		if corner.begins_with("缺"):
			return Color("fbf5e6")
		if corner == "锁":
			return Color("8a8175")
		return Color("8c6d1f")

	func _corner_fg() -> Color:
		if corner.begins_with("缺"):
			return Color("3a3026")
		return Color("fbf5e6")

	func _key() -> String:
		if state == "queued":
			return "available"
		return state

	func _round(r: Rect2, fill: Color, border: Color, width: float) -> void:
		draw_rect(r, fill, true)
		draw_rect(r, border, false, width)

	func _dashed_rect(r: Rect2, color: Color) -> void:
		_dash(r.position, Vector2(r.end.x, r.position.y), color)
		_dash(Vector2(r.end.x, r.position.y), r.end, color)
		_dash(r.end, Vector2(r.position.x, r.end.y), color)
		_dash(Vector2(r.position.x, r.end.y), r.position, color)

	func _dash(a: Vector2, b: Vector2, color: Color) -> void:
		var dir := b - a
		var length := dir.length()
		if length < 1.0:
			return
		var step := dir / length
		var t := 0.0
		while t < length:
			var t2 := minf(t + 4.0, length)
			draw_line(a + step * t, a + step * t2, color, 1.4, true)
			t += 7.0

	func _cut(r: Rect2, fill: Color, border: Color) -> void:
		var c := 14.0
		var pts := PackedVector2Array([
			r.position,
			Vector2(r.end.x - c, r.position.y),
			Vector2(r.end.x, r.position.y + c),
			r.end,
			Vector2(r.position.x, r.end.y),
		])
		draw_colored_polygon(pts, fill)
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()], border, 1.6, true)

	func _chamfer(r: Rect2, fill: Color, border: Color) -> void:
		var c := 8.0
		var pts := PackedVector2Array([
			Vector2(r.position.x + c, r.position.y),
			Vector2(r.end.x - c, r.position.y),
			Vector2(r.end.x, r.position.y + c),
			Vector2(r.end.x, r.end.y - c),
			Vector2(r.end.x - c, r.end.y),
			Vector2(r.position.x + c, r.end.y),
			Vector2(r.position.x, r.end.y - c),
			Vector2(r.position.x, r.position.y + c),
		])
		draw_colored_polygon(pts, fill)
		for i in pts.size():
			draw_line(pts[i], pts[(i + 1) % pts.size()], border, 1.6, true)

	func _ring(color: Color) -> void:
		var frac := clampf(float(prog) / float(maxi(1, need)), 0.0, 1.0)
		if frac <= 0.0:
			return
		var inset := 3.0
		var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
		var pts := PackedVector2Array([
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
		var total := rect.size.x * 2.0 + rect.size.y * 2.0
		var remain := total * frac
		for i in 4:
			if remain <= 0.4:
				break
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % 4]
			var length := a.distance_to(b)
			var take := minf(remain, length)
			draw_line(a, a.lerp(b, take / maxf(length, 0.001)), color, 2.5, true)
			remain -= take

	func _badge(at: Vector2) -> void:
		var center := at + Vector2(9, 9)
		draw_circle(center, 9, Color("6d655c"))
		var font := get_theme_font("font", "Label")
		var mark := str(queue_n)
		if queue_n >= 1 and queue_n <= 3:
			mark = ["①", "②", "③"][queue_n - 1]
		if font:
			draw_string(font, center + Vector2(-9, 5), mark, HORIZONTAL_ALIGNMENT_CENTER, 18, 13, Color("fbf5e6"))


class Graph extends Control:
	const PLAN = preload("res://scripts/ui/tech_plan.gd")
	const Ink = preload("res://scripts/ui/tech_path_ink.gd")
	const GOLD := Color("b8893a")
	const CYAN := Color("1f7f8c")
	const CINNABAR := Color("c23b2a")
	var board = null
	var spots := {}
	var edges: Array = []
	var need := Vector2(400, 400)
	var ink: Control

	func _ready() -> void:
		ink = Ink.new()
		ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ink)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("f3ead6"), true)
		if board and board.desk and board.desk.tech_view != "overview" and board.edge_routes.size() > 0:
			_draw_routes()
			return
		var focus := ""
		var hover_id := ""
		var pick_id := ""
		var overview := false
		if board and board.desk:
			hover_id = str(board.desk.tech_hover)
			pick_id = str(board.desk.picked)
			focus = pick_id if pick_id != "" else hover_id
			overview = board.desk.tech_view == "overview"
		var rel := {}
		if focus != "":
			rel = PLAN.related(focus)
		var paths: Array = []
		for edge_v in edges:
			var edge: Dictionary = edge_v
			var a_id := str(edge.get("from", ""))
			var b_id := str(edge.get("to", ""))
			var kind := str(edge.get("kind", ""))
			if not spots.has(a_id) or not spots.has(b_id):
				continue
			if kind == "miss" and focus != b_id and focus != a_id:
				continue
			var fade := focus != "" and not rel.has(a_id) and not rel.has(b_id) and kind != "path"
			var alpha := 0.3 if fade else 1.0
			if overview and kind != "path" and _lane_dim(a_id, b_id):
				var hot := (hover_id != "" and (hover_id == a_id or hover_id == b_id)) or (pick_id != "" and (pick_id == a_id or pick_id == b_id))
				alpha = 1.0 if hot else 0.3
			var ra: Rect2 = spots[a_id]
			var rb: Rect2 = spots[b_id]
			var a := _port(ra, rb.get_center())
			var b := _port(rb, ra.get_center())
			if kind == "done":
				_poly([a, b], GOLD, 2.0, alpha, false, 0.0)
			elif kind == "sheet":
				_dash_line(a, b, CYAN, 1.6, alpha, PackedFloat32Array([8, 3, 2, 3]), 0.0)
			elif kind == "path":
				paths.append({"a": a, "b": b, "color": CYAN, "alpha": alpha, "width": 3.0})
			else:
				_dash_line(a, b, CINNABAR, 1.5, alpha, PackedFloat32Array([4, 3]), 0.0)
				var mid := (a + b) * 0.5
				draw_line(mid + Vector2(-4, -4), mid + Vector2(4, 4), Color(CINNABAR, alpha), 1.6, true)
				draw_line(mid + Vector2(-4, 4), mid + Vector2(4, -4), Color(CINNABAR, alpha), 1.6, true)
		_sync_paths(paths)

	func _draw_routes() -> void:
		var focus := ""
		if board and board.desk:
			var pick_id := str(board.desk.picked)
			var hover_id := str(board.desk.tech_hover)
			focus = pick_id if pick_id != "" else hover_id
		var rel := {}
		if focus != "":
			rel = PLAN.related(focus)
		var paths: Array = []
		var path_color := Color("2f8f6f")
		var gold := Color("c9a44c")
		var ink := Color("3a3026")
		var miss := Color("a8402f")
		for route_v in board.edge_routes:
			var route: Dictionary = route_v
			if bool(route.get("stub", false)):
				continue
			var kind := str(route.get("kind", ""))
			var a_id := str(route.get("from", ""))
			var b_id := str(route.get("to", ""))
			if kind == "miss" and focus != a_id and focus != b_id:
				continue
			var fade := focus != "" and not rel.has(a_id) and not rel.has(b_id) and kind != "path"
			var alpha := 0.25 if fade else 1.0
			var pts: PackedVector2Array = route.get("pts", PackedVector2Array())
			if pts.size() < 2:
				continue
			if kind == "path":
				paths.append({"pts": pts, "color": path_color, "alpha": 1.0, "width": 3.0})
			elif kind == "done":
				_poly(pts, gold, 1.0, alpha * 0.4, false, 0.0)
			elif kind == "open":
				_poly(pts, gold, 2.0, alpha, false, 0.0)
				_arrow_last(pts, gold, alpha)
			elif kind == "sheet":
				_poly(pts, ink, 1.5, alpha * 0.7, false, 0.0)
				_arrow_last(pts, ink, alpha * 0.7)
			else:
				for i in pts.size() - 1:
					_dash_line(pts[i], pts[i + 1], miss, 1.5, alpha, PackedFloat32Array([4, 3]), 0.0)
				var mid := (pts[pts.size() - 2] + pts[pts.size() - 1]) * 0.5
				draw_line(mid + Vector2(-4, -4), mid + Vector2(4, 4), Color(miss, alpha), 1.6, true)
				draw_line(mid + Vector2(-4, 4), mid + Vector2(4, -4), Color(miss, alpha), 1.6, true)
		_sync_paths(paths)

	func _arrow_last(pts: PackedVector2Array, color: Color, alpha: float) -> void:
		if pts.size() < 2:
			return
		var a: Vector2 = pts[pts.size() - 2]
		var b: Vector2 = pts[pts.size() - 1]
		var dir := b - a
		if dir.length() < 8.0:
			return
		dir = dir.normalized()
		var side := Vector2(-dir.y, dir.x)
		var tip := b
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 10.0 + side * 5.0, tip - dir * 10.0 - side * 5.0]), Color(color, alpha))

	func _lane_dim(a_id: String, b_id: String) -> bool:
		if board == null:
			return false
		var ba := str(board.branch_of(a_id))
		var bb := str(board.branch_of(b_id))
		return ba == "gong" or ba == "xie" or bb == "gong" or bb == "xie"

	func _sync_paths(paths: Array) -> void:
		if ink == null:
			ink = Ink.new()
			ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(ink)
			move_child(ink, 0)
		ink.position = Vector2.ZERO
		ink.size = size
		ink.set_segs(paths)

	func _port(rect: Rect2, toward: Vector2) -> Vector2:
		var c := rect.get_center()
		if absf(toward.x - c.x) >= absf(toward.y - c.y):
			return Vector2(rect.position.x if toward.x < c.x else rect.end.x, c.y)
		return Vector2(c.x, rect.position.y if toward.y < c.y else rect.end.y)

	func _poly(pts: PackedVector2Array, color: Color, width: float, alpha: float, _dashed: bool, _phase: float) -> void:
		for i in pts.size() - 1:
			draw_line(pts[i], pts[i + 1], Color(color, alpha), width, true)

	func _dash_line(a: Vector2, b: Vector2, color: Color, width: float, alpha: float, pattern: PackedFloat32Array, phase: float) -> void:
		var dir := b - a
		var length := dir.length()
		if length < 1.0:
			return
		var step := dir / length
		var span := 0.0
		for n in pattern:
			span += n
		var t := -phase * span
		var on := true
		var pi := 0
		while t < length:
			var seg := pattern[pi % pattern.size()]
			var t2 := minf(t + seg, length)
			if on and t2 > 0.0:
				draw_line(a + step * maxf(t, 0.0), a + step * t2, Color(color, alpha), width, true)
			t = t2
			on = not on
			pi += 1

class Shade extends Control:
	var hole := Rect2()

	func _ready() -> void:
		resized.connect(queue_redraw)
		call_deferred("_fit")

	func _fit() -> void:
		if size.x < 2.0 or size.y < 2.0:
			var vp := get_viewport_rect().size
			if vp.x < 2.0:
				vp = Vector2(1280, 720)
			size = vp
			custom_minimum_size = vp
		queue_redraw()

	func _draw() -> void:
		var dim := Color(0, 0, 0, 0.6)
		var s := size
		if s.x < 2.0 or s.y < 2.0:
			s = get_viewport_rect().size
			if s.x < 2.0:
				s = Vector2(1280, 720)
		draw_rect(Rect2(0, 0, s.x, maxf(0.0, hole.position.y)), dim, true)
		draw_rect(Rect2(0, hole.end.y, s.x, maxf(0.0, s.y - hole.end.y)), dim, true)
		draw_rect(Rect2(0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y), dim, true)
		draw_rect(Rect2(hole.end.x, hole.position.y, maxf(0.0, s.x - hole.end.x), hole.size.y), dim, true)
		draw_rect(hole, Color("e7c98a"), false, 2.0)


class LineKey extends Control:
	const GOLD := Color("b8893a")
	const CYAN := Color("1f7f8c")
	const CINNABAR := Color("c23b2a")
	const INK := Color("2a241c")

	func _draw() -> void:
		var rows: Array = [
			["实线 2px 金", GOLD, "solid"],
			["点划线 青蓝（前置只有图纸）", CYAN, "sheet"],
			["短虚线 朱红，中间断开（缺前置，悬停才出现）", CINNABAR, "miss"],
			["流动虚线 3px 青蓝（目标路径）", CYAN, "path"],
			["与选中无关的线淡到 25%", GOLD, "fade"],
		]
		var font := get_theme_font("font", "Label")
		for i in rows.size():
			var row: Array = rows[i]
			var y := 16.0 + float(i) * 22.0
			var a := Vector2(8, y)
			var b := Vector2(168, y)
			var kind := str(row[2])
			var color: Color = row[1]
			if kind == "solid":
				draw_line(a, b, color, 2.0, true)
			elif kind == "sheet":
				_seg(a, b, color, 1.6, 1.0)
			elif kind == "miss":
				_seg(a, b, color, 1.5, 1.0)
				var mid := (a + b) * 0.5
				draw_line(mid + Vector2(-3, -3), mid + Vector2(3, 3), color, 1.4, true)
			elif kind == "path":
				_seg(a, b, color, 3.0, 1.0)
			else:
				draw_line(a, b, Color(color, 0.3), 2.0, true)
			if font:
				draw_string(font, Vector2(180, y + 4), str(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

	func _seg(a: Vector2, b: Vector2, color: Color, width: float, alpha: float) -> void:
		var dir := (b - a).normalized()
		var t := 0.0
		var length := a.distance_to(b)
		while t < length:
			var t2 := minf(t + 8.0, length)
			draw_line(a + dir * t, a + dir * t2, Color(color, alpha), width, true)
			t += 12.0


class MiniMap extends Control:
	var board = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if board == null:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				_jump(mb.position)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion:
			var motion := event as InputEventMouseMotion
			if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				_jump(motion.position)

	func _jump(local: Vector2) -> void:
		var frac := clampf((local.x - 12.0) / 256.0, 0.0, 1.0)
		board._minimap_to(frac)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("3a3026"), true)
		var origin := Vector2(12, 4)
		var map := Vector2(256, 52)
		draw_rect(Rect2(origin, map), Color("1c2826"), true)
		var total_w := 13.0 * 214.0
		var total_h := 32.0 + 6.0 * 94.0
		if board == null or board.graph == null:
			return
		for id_v in board.graph.spots.keys():
			var id := str(id_v)
			var rect: Rect2 = board.graph.spots[id]
			var tech: Dictionary = DataDB.tech_by_id.get(id, {})
			var col := int(tech.get("col", 1))
			var row: int = int(board._branch_row(str(tech.get("branch", ""))))
			if row < 0:
				row = 5
			var px := origin.x + (float(col - 1) * 214.0 / total_w) * map.x
			var py := origin.y + ((32.0 + float(row) * 94.0) / total_h) * map.y
			draw_rect(Rect2(Vector2(px, py), Vector2(14, 6)), _swatch(id), true)
		var view := 952.0
		var scroll_x := float(board.desk.tech_scroll) if board.desk else 0.0
		var vx := origin.x + (scroll_x / total_w) * map.x
		var vw := (view / total_w) * map.x
		draw_rect(Rect2(Vector2(vx, origin.y), Vector2(vw, map.y)), Color("c23b2a"), false, 2.0)

	func _swatch(id: String) -> Color:
		var state := TechPlan.view_state(id)
		if state == "done":
			return Color("d8b864")
		if state == "blueprint":
			return Color("2e7d8c")
		if state == "designing" or state == "trial":
			return Color("a0612b")
		if state == "available" or state == "queued":
			return Color("3a3026")
		if state == "noprereq":
			return Color("8a8175")
		return Color("d9d2c3")
