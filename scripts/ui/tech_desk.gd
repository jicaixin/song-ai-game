class_name TechDesk
extends Control

const PLAN = preload("res://scripts/ui/tech_plan.gd")

const PAPER := Color("f3ead6")
const INK := Color("2a241c")
const CREAM := Color("fbf5e6")
const CINNABAR := Color("c23b2a")
const GOLD := Color("b8893a")
const CYAN := Color("1f7f8c")
const OCHRE := Color("8a4e22")
const MUTED := Color("76685a")
const HEADER := Color("1c2826")
const NODE_W := 136.0
const NODE_H := 42.0
const ROW_H := 96.0
const COL_W := 146.0
const LOCKED_A := 0.65
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


func build() -> void:
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
	var header_h := 92.0 if desk.tech_view == "overview" else 56.0
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
		var next := Kit.label("时代三：第 75 回合或 11/17 开启", "CaptionLabel")
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
	var help := _header_button("?", false)
	help.custom_minimum_size = Vector2(40, 36)
	help.pressed.connect(_rewatch)
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
	var height := 720.0 - header_h - 32.0
	var left_w := 0.0 if desk.tech_view == "overview" else 300.0
	var drawer_w := 0.0
	if desk.tech_view != "overview" and desk.picked != "":
		drawer_w = 360.0
	if left_w > 0.0:
		var left := PanelContainer.new()
		left.position = Vector2(8, top + 8)
		left.size = Vector2(left_w - 12, height - 16)
		left.add_theme_stylebox_override("panel", _flat(Color("f7f1e4"), Color("e0d3b8"), 8, 0))
		add_child(left)
		var scroller := ScrollContainer.new()
		scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroller)
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 8)
		scroller.add_child(box)
		_left(box)
		call_deferred("_fit_guide", left, box)
	var tree_x := left_w
	var tree_w := 1280.0 - left_w - drawer_w
	var tree_paper := ColorRect.new()
	tree_paper.color = PAPER
	tree_paper.position = Vector2(tree_x, top)
	tree_paper.size = Vector2(tree_w, height)
	tree_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tree_paper)
	var host := HBoxContainer.new()
	host.position = Vector2(tree_x, top)
	host.size = Vector2(tree_w, height)
	host.add_theme_constant_override("separation", 4)
	add_child(host)
	if desk.tech_view != "overview":
		_era_rails(host, height)
	var gutter := VBoxContainer.new()
	gutter.custom_minimum_size = Vector2(28, height)
	host.add_child(gutter)
	gutter.add_child(_spacer(32))
	for b_v in DataDB.branches:
		var b: Dictionary = b_v
		if str(b.get("id", "")) == "zhong":
			continue
		var mark := Kit.label(str(b.get("name", "")), "H3Label")
		mark.custom_minimum_size = Vector2(28, ROW_H if desk.tech_view != "overview" else 56)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gutter.add_child(mark)
	scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	host.add_child(scroll)
	graph = Graph.new()
	graph.board = self
	graph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(graph)
	if desk.tech_view == "overview":
		_layout_overview()
	else:
		_layout_focus()
	graph.custom_minimum_size = graph.need
	graph.size = graph.need
	_paint_fade()
	if desk.picked != "" and graph.spots.has(desk.picked):
		var sx: float = graph.spots[desk.picked].position.x
		scroll.scroll_horizontal = int(maxf(0.0, sx - 40.0))
	elif desk.tech_scroll > 0:
		scroll.scroll_horizontal = desk.tech_scroll
	if drawer_w > 0.0:
		_build_drawer(1280.0 - drawer_w, top, drawer_w, height)


func _left(box: VBoxContainer) -> void:
	box.add_child(_section_title("1  正在做"))
	var now := VBoxContainer.new()
	now.add_theme_constant_override("separation", 4)
	box.add_child(now)
	anchors["now"] = now
	if GameState.tech_designing == "":
		var empty := Kit.label("选一份图纸", "H3Label")
		empty.add_theme_color_override("font_color", CINNABAR)
		now.add_child(empty)
		anchors["design"] = empty
	else:
		var id := GameState.tech_designing
		var tech: Dictionary = DataDB.tech_by_id.get(id, {})
		var need := GameState.design_need(id)
		var left := maxi(0, need - GameState.tech_design_prog)
		var row := _link_row("设计  %s" % str(tech.get("name", id)), "console")
		now.add_child(row)
		anchors["design"] = row
		var bar := ProgressBar.new()
		bar.theme_type_variation = "NodeBarDesign"
		bar.max_value = float(maxi(1, need))
		bar.value = float(GameState.tech_design_prog)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		now.add_child(bar)
		now.add_child(Kit.label("电 %d/%d    约 %d 回合" % [GameState.tech_design_prog, need, int(ceil(float(left) / 10.0))], "CaptionLabel"))
	if not GameState.tech_queue.is_empty():
		var bits := "队列"
		var n := 1
		for id_v in GameState.tech_queue:
			var tech2: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
			bits += "  %d %s" % [n, str(tech2.get("name", str(id_v)))]
			n += 1
		var q := Kit.label(bits, "SmallLabel")
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		now.add_child(q)
	var trials := VBoxContainer.new()
	trials.add_theme_constant_override("separation", 2)
	now.add_child(trials)
	anchors["trial"] = trials
	if GameState.tech_trials.is_empty():
		trials.add_child(Kit.label("试制槽空着", "SmallLabel"))
	for trial_v in GameState.tech_trials:
		var trial: Dictionary = trial_v
		var id2 := str(trial.get("id", ""))
		var tech3: Dictionary = DataDB.tech_by_id.get(id2, {})
		var who := str(tech3.get("talent", ""))
		var line := "试制  %s  %d/%d" % [str(tech3.get("name", id2)), int(trial.get("prog", 0)), int(trial.get("need", 1))]
		if who != "":
			line += "  " + who
		var brow := _link_row(line, "workshop")
		var face := _talent_face(who)
		if face != null:
			var wrap := HBoxContainer.new()
			wrap.add_theme_constant_override("separation", 6)
			wrap.alignment = BoxContainer.ALIGNMENT_CENTER
			wrap.add_child(face)
			wrap.add_child(brow)
			trials.add_child(wrap)
		else:
			trials.add_child(brow)
		var tbar := ProgressBar.new()
		tbar.theme_type_variation = "NodeBarTrial"
		tbar.max_value = float(maxi(1, int(trial.get("need", 1))))
		tbar.value = float(int(trial.get("prog", 0)))
		tbar.show_percentage = false
		tbar.custom_minimum_size = Vector2(0, 8)
		trials.add_child(tbar)
	var prints := VBoxContainer.new()
	now.add_child(prints)
	anchors["prints"] = prints
	if GameState.tech_blueprints.is_empty():
		prints.add_child(Kit.label("图纸库 0/3", "SmallLabel"))
	else:
		var names := ""
		for id_v in GameState.tech_blueprints:
			var tech4: Dictionary = DataDB.tech_by_id.get(str(id_v), {})
			if names != "":
				names += "、"
			names += str(tech4.get("name", str(id_v)))
		prints.add_child(_link_row("图纸库 %d/3  %s" % [GameState.tech_blueprints.size(), names], "workshop"))
	if GameState.tech_target != "":
		box.add_child(_target_card())
	else:
		box.add_child(_section_title("2  豆沙包建议"))
		var sug := PLAN.suggestion()
		if str(sug.get("id", "")) == "":
			box.add_child(_none_card())
		else:
			var card := _advice_card(str(sug.get("title", "")), str(sug.get("reason", "")), bool(sug.get("telegraph", false)), true)
			box.add_child(card)
			anchors["accept"] = card
	box.add_child(_section_title("3  还缺"))
	var blocks: Array = PLAN.blockers()
	if blocks.is_empty():
		var ok := Kit.label("一切顺利，本月没有卡住的材料。", "SmallLabel")
		ok.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(ok)
	for item_v in blocks:
		var item: Dictionary = item_v
		box.add_child(_blocker(item))
	box.add_child(_section_title("4  读图"))
	var how := Kit.label("金边是已成，青框是正在画。点一格看说明。按 T 关闭这张图。电满了就别空着槽。", "SmallLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(how)


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
	text.add_child(h)
	var body := Kit.label(reason, "CaptionLabel")
	body.add_theme_color_override("font_color", fg)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	card.add_theme_stylebox_override("panel", _flat(Color("e7f4f6"), CYAN, 8, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var tech: Dictionary = DataDB.tech_by_id.get(GameState.tech_target, {})
	var title := Kit.label("目标  %s" % str(tech.get("name", GameState.tech_target)), "H3Label")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var sum: Dictionary = PLAN.totals(GameState.tech_target)
	var chain: Array = sum.get("chain", [])
	var path := "路径 %d 项：" % chain.size()
	var first := true
	for id_v in chain:
		var id := str(id_v)
		var node: Dictionary = DataDB.tech_by_id.get(id, {})
		if not first:
			path += " → "
		first = false
		path += str(node.get("name", id))
		var st := GameState.tech_state(id)
		if st == "trial":
			path += "（试制）"
		elif st == "designing":
			path += "（设计）"
	var path_lab := Kit.label(path, "CaptionLabel")
	path_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(path_lab)
	box.add_child(Kit.label("总电 %d    总匠 %d" % [int(sum.get("power", 0)), int(sum.get("craft", 0))], "H3Label"))
	box.add_child(Kit.label("预计约 %d 回合（T%d 前后）" % [int(sum.get("months", 0)), int(sum.get("eta", 0))], "SmallLabel"))
	var short := _target_gap(GameState.tech_target)
	if short != "":
		var gap := _link_row("卡点：" + short, "industry")
		box.add_child(gap)
	var sug := PLAN.suggestion()
	if str(sug.get("id", "")) != "" and str(sug.get("kind", "")) != "target":
		var why := Kit.label(str(sug.get("title", "")), "CaptionLabel")
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(why)
		var act := Kit.button("采纳", "PrimaryButton")
		act.pressed.connect(_adopt)
		box.add_child(act)
		desk.debug_btns["tech_accept"] = act
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
	var x := 8.0
	var header_y := 4.0
	for stage_v in DataDB.stages:
		var stage: Dictionary = stage_v
		if int(stage.get("era", 0)) != era:
			continue
		var col_from := int(stage.get("col_from", 1))
		var col_to := int(stage.get("col_to", col_from))
		var cols := col_to - col_from + 1
		var prog := PLAN.stage_progress(int(stage.get("id", 0)))
		var cap := Kit.label("%s %s  %d/%d" % [str(stage.get("name", "")), str(stage.get("subtitle", "")), prog.x, prog.y], "SmallLabel")
		cap.position = Vector2(x, header_y)
		cap.size = Vector2(cols * COL_W, 24)
		graph.add_child(cap)
		for tech_v in DataDB.techs:
			var tech: Dictionary = tech_v
			if int(tech.get("stage", 0)) != int(stage.get("id", 0)):
				continue
			var id := str(tech.get("id", ""))
			var col := int(tech.get("col", col_from)) - col_from
			var row := _branch_row(str(tech.get("branch", "")))
			if row < 0:
				continue
			var y := 32.0 + float(row) * ROW_H + _slot_y(str(tech.get("slot", "c")))
			var pos := Vector2(x + float(col) * COL_W, y)
			_place_node(id, pos, false)
		x += float(cols) * COL_W + 12.0
	var cap2 := Kit.label("后继  %s" % _lock_head(era + 1), "SmallLabel")
	cap2.position = Vector2(x, header_y)
	cap2.size = Vector2(COL_W, 24)
	graph.add_child(cap2)
	var stack := {}
	for tech_v2 in DataDB.techs:
		var tech2: Dictionary = tech_v2
		var id2 := str(tech2.get("id", ""))
		if not PLAN.is_frontier(id2, era):
			continue
		var row2 := _branch_row(str(tech2.get("branch", "")))
		if row2 < 0:
			continue
		var n := int(stack.get(row2, 0))
		stack[row2] = n + 1
		var y2 := 32.0 + float(row2) * ROW_H + (4.0 if n == 0 else 48.0)
		_place_node(id2, Vector2(x, y2), false)
	graph.need = Vector2(x + COL_W + 8.0, 32.0 + 6.0 * ROW_H)
	_build_edges()


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
			title = "%s 锁" % str(stage.get("name", ""))
		var cap := Kit.label(title, "SmallLabel")
		cap.position = Vector2(x, 4)
		cap.size = Vector2(cols * 48.0, 22)
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
	b.position = pos
	b.tooltip_text = "%s\n%s" % [str(tech.get("name", id)), PLAN.status_text(id)]
	b.pressed.connect(_on_node.bind(id))
	b.gui_input.connect(_on_node_input.bind(id))
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
		row.position = Vector2(6, 4)
		row.size = Vector2(NODE_W - 10, NODE_H - 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		b.add_child(row)
		row.add_child(Kit.icon_rect("tech_%s" % id, 22))
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(col)
		var nm := Kit.label(str(tech.get("name", id)), "SmallLabel")
		nm.add_theme_font_size_override("font_size", _fit_size(str(tech.get("name", id)), 96.0))
		nm.add_theme_color_override("font_color", MUTED if state == "noprereq" or state == "locked" else INK)
		nm.clip_text = false
		nm.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(nm)
		var sub := HBoxContainer.new()
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sub)
		var st := TextureRect.new()
		st.texture = Kit.piece("st3_%s" % _icon_state(state))
		st.custom_minimum_size = Vector2(12, 12)
		st.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		st.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(st)
		var sl := Kit.label(PLAN.status_text(id), "CaptionLabel")
		sl.clip_text = false
		sl.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sub.add_child(sl)
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
			var adjacent := on_path.has(id) and on_path.has(pre) and _adjacent(chain, pre, id)
			if adjacent and not GameState.tech_done.has(id):
				kind = "path"
			elif GameState.tech_done.has(pre):
				kind = "done"
			elif GameState.tech_state(pre) == "blueprint":
				kind = "sheet"
			graph.edges.append({"from": pre, "to": id, "kind": kind})


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
			alpha = 0.3
		b.modulate = Color(1, 1, 1, alpha)
	if graph:
		graph.queue_redraw()


func _build_footer() -> void:
	var bar := ColorRect.new()
	bar.color = Color("2a241c")
	bar.position = Vector2(0, 688)
	bar.size = Vector2(1280, 32)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := HBoxContainer.new()
	row.position = Vector2(12, 690)
	row.size = Vector2(1256, 28)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	if desk.tech_legend_bar == 1:
		for pair_v in [["st3_done", "已完成"], ["st3_designing", "研发中"], ["st3_available", "可设计"], ["st3_noprereq", "缺前置"], ["st3_blocked", "受阻"], ["st3_blueprint", "待试制"], ["st3_trial", "试制中"], ["st3_locked", "未开"]]:
			var pair: Array = pair_v
			row.add_child(_footer_chip(str(pair[0]), str(pair[1])))
	var pad := Control.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pad)
	var legend := _text_button("图例" if desk.tech_legend_bar == 0 else "收起图例")
	legend.add_theme_color_override("font_color", CREAM)
	legend.pressed.connect(_toggle_bar)
	row.add_child(legend)
	desk.debug_btns["tech_legend_bar"] = legend
	var sheet := _text_button("状态表")
	sheet.add_theme_color_override("font_color", CREAM)
	sheet.pressed.connect(_show_legend)
	row.add_child(sheet)
	desk.debug_btns["tech_legend"] = sheet
	var parts := _text_button("组件")
	parts.add_theme_color_override("font_color", CREAM)
	parts.pressed.connect(_show_parts)
	row.add_child(parts)
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
		return 4.0
	if slot == "d":
		return ROW_H - NODE_H - 4.0
	return (ROW_H - NODE_H) * 0.5


func _icon_state(state: String) -> String:
	if state == "queued":
		return "available"
	if state == "blocked":
		return "blocked"
	return state


func _fit_size(_text: String, _width: float) -> int:
	return 13


func _lock_head(era: int) -> String:
	if GameState.era_unlocked(era):
		return "已开"
	if era >= 3:
		return "T75开"
	return "T31开"


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
	desk._fill()


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
	desk.picked = id
	PLAN.set_target(id)


func _run(id: String) -> void:
	var jump := PLAN.run_primary(id)
	if jump == "city":
		desk.open_city("kaifeng")
	elif jump != "":
		_jump(jump)


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
	var now := Time.get_ticks_msec()
	var dbl := desk.tech_click_id == id and now - desk.tech_click_ms < 450
	desk.tech_click_id = id
	desk.tech_click_ms = now
	_remember_scroll()
	if dbl and desk.tech_view != "overview":
		_run(id)
		return
	desk.picked = id
	if desk.tech_view == "overview":
		desk.tech_view = "focus"
	desk._fill()


func _on_node_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			desk.picked = id
			desk.tech_fold = "history"
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
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.ctrl_pressed or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		_set_view("focus")
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_set_view("overview")
		get_viewport().set_input_as_handled()


class Face extends Control:
	var state := "available"
	var tile := false
	var queue_n := 0

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		if tile:
			var tex := Kit.piece("tile3_%s" % _key())
			if tex:
				draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			if queue_n > 0:
				_badge(Vector2(2, 2))
			return
		if state == "done":
			_round(r, Color("f4e2b0"), Color("b8893a"), 2.0)
		elif state == "designing":
			draw_rect(r.grow(2), Color(0.12, 0.5, 0.55, 0.35), true)
			_round(r, Color("fbf5e6"), Color("1f7f8c"), 2.0)
			_round(r.grow(-4), Color("fbf5e6"), Color("1f7f8c"), 1.0)
		elif state == "queued" or state == "available":
			_round(r, Color("fbf5e6"), Color("4a4036"), 1.5)
		elif state == "noprereq":
			_dashed_rect(r, Color("8a8175"))
		elif state == "blocked":
			_cut(r, Color("f8e6e0"), Color("c23b2a"))
		elif state == "blueprint":
			_round(r, Color("fbf5e6"), Color("83501f"), 1.5)
			draw_rect(Rect2(r.position, Vector2(7, r.size.y)), Color("83501f"), false, 1.5)
			draw_rect(Rect2(Vector2(r.end.x - 7, r.position.y), Vector2(7, r.size.y)), Color("83501f"), false, 1.5)
		elif state == "trial":
			_chamfer(r, Color("f6e7d4"), Color("83501f"))
		else:
			_round(r, Color("e7e0d4"), Color("76685a"), 1.0)
		if queue_n > 0:
			_badge(r.position + Vector2(2, 2))

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

	func _badge(at: Vector2) -> void:
		var center := at + Vector2(9, 9)
		draw_circle(center, 9, Color("1f7f8c"))
		var font := get_theme_font("font", "Label")
		if font:
			draw_string(font, center + Vector2(-9, 5), str(queue_n), HORIZONTAL_ALIGNMENT_CENTER, 18, 13, Color("fbf5e6"))


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
			["与选中无关的线淡到 30%", GOLD, "fade"],
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
