extends Control

const Kit = preload("res://scripts/ui/kit.gd")

const LINES := [
	"先点刘平部。左键，选自己人。城下那支西夏先别惹。",
	"鼠标先放到这格亮着的地方，看看要走几步。再左键点一下，人就过去了。绿格子是这个月还走得到的路。",
	"右下有小地图。点一格就到那一格。迷了路，按回延州，或按 Home。",
	"空格换下一支还能动的宋军。殿前司远在开封，空格会把镜头带过去。",
	"看明白了就按结束回合，或按回车。西夏会自己动。",
]

var active := false
var step := 0
var host: GameUI
var shade: Control
var dim_top: ColorRect
var dim_bottom: ColorRect
var dim_left: ColorRect
var dim_right: ColorRect
var dim_frame: Control
var bubble: PanelContainer
var body: Label
var note: Label
var dots: Label
var skip_btn: Button
var next_btn: Button
var hole_global := Rect2()
var track_uid := -1
var track_q := 0
var track_r := 0
var guide := Vector2i(999999, 0)
var _wired := false
var _busy := false


func begin(ui: GameUI) -> void:
	host = ui
	step = 0
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 40
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	var vp := get_viewport_rect().size
	if vp.x < 2.0:
		vp = Vector2(1280, 720)
	size = vp
	custom_minimum_size = vp
	_wire()
	_ensure()
	_show_step()


func _wire() -> void:
	if _wired:
		return
	_wired = true
	EventBus.oriented.connect(_on_oriented)
	EventBus.unit_cycled.connect(_on_cycled)
	EventBus.turn_started.connect(_on_turn)


func _ensure() -> void:
	if shade != null:
		return
	shade = Control.new()
	shade.name = "TutorialShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.z_index = 1
	add_child(shade)
	dim_top = _dim_piece()
	dim_bottom = _dim_piece()
	dim_left = _dim_piece()
	dim_right = _dim_piece()
	dim_frame = HoleFrame.new()
	dim_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_frame.z_index = 1
	add_child(dim_frame)
	bubble = PanelContainer.new()
	bubble.name = "TutorialBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.z_index = 2
	bubble.position = Vector2(300, 78)
	bubble.size = Vector2(620, 188)
	bubble.add_theme_stylebox_override("panel", _panel_style())
	add_child(bubble)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	bubble.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var face := TextureRect.new()
	face.texture = Kit.portrait_head("doushabao", "serious")
	face.custom_minimum_size = Vector2(56, 56)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(face)
	body = Kit.label("", "BodyLabel")
	body.add_theme_color_override("font_color", Color("fbf5e6"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(body)
	note = Kit.label("用惯右键的话，右键也行。", "CaptionLabel")
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color("f3e9d2"))
	note.visible = false
	box.add_child(note)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	box.add_child(foot)
	dots = Kit.label("", "CaptionLabel")
	dots.add_theme_color_override("font_color", Color("f3e9d2"))
	foot.add_child(dots)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(spacer)
	skip_btn = Kit.button("跳过", "Button")
	skip_btn.pressed.connect(_on_skip)
	foot.add_child(skip_btn)
	next_btn = Kit.button("下一步", "PrimaryButton")
	next_btn.pressed.connect(_on_next)
	foot.add_child(next_btn)


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("14343a")
	box.border_color = Color("e7c98a")
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(12)
	return box


func _show_step() -> void:
	_remember()
	body.text = LINES[step]
	var marks := ""
	for i in LINES.size():
		marks += "● " if i == step else "○ "
	dots.text = marks + "  %d / %d" % [step + 1, LINES.size()]
	next_btn.text = "知道了" if step == LINES.size() - 1 else "下一步"
	if note:
		note.visible = step == 1
	if host:
		host.btn_map["tutor_skip"] = skip_btn
		host.btn_map["tutor_next"] = next_btn
	_place()
	_push_guide()


func _remember() -> void:
	track_uid = -1
	guide = Vector2i(999999, 0)
	if step == 0:
		var garrison := _garrison()
		if not garrison.is_empty():
			guide = Vector2i(int(garrison.q), int(garrison.r))
	elif step == 1:
		var u := GameState.selected_unit()
		if u.is_empty() or str(u.name) != "刘平部":
			u = _garrison()
		if not u.is_empty():
			track_uid = int(u.uid)
			track_q = int(u.q)
			track_r = int(u.r)
			guide = _pick_hex(u)


func _process(_delta: float) -> void:
	if not active:
		return
	var vp := get_viewport_rect().size
	if vp.x > 2.0:
		size = vp
	_place()
	_check()
	if step == 1 and body != null and active:
		var map := _map()
		if map != null and map.hover_ok and map.hover == guide and str(map.hover_plan.get("head", "")) != "":
			body.text = "看见‘%s’没有？大宋的路况，我替您算好了。" % str(map.hover_plan.get("head", ""))
		else:
			body.text = LINES[1]


func _place() -> void:
	hole_global = _hole_for_step()
	var vp := get_viewport_rect().size
	if vp.x < 2.0:
		vp = Vector2(1280, 720)
	if bubble != null:
		var tall := 210.0 if step == 1 else 176.0
		var bsize := Vector2(620, tall)
		bubble.size = bsize
		bubble.custom_minimum_size = bsize
		bubble.position = _bubble_pos(vp, bsize)
	if shade == null:
		return
	shade.visible = true
	shade.position = Vector2.ZERO
	shade.size = vp
	shade.custom_minimum_size = vp
	var hole := hole_global
	_fill_dim(dim_top, Rect2(0, 0, vp.x, maxf(0.0, hole.position.y)))
	_fill_dim(dim_bottom, Rect2(0, hole.end.y, vp.x, maxf(0.0, vp.y - hole.end.y)))
	_fill_dim(dim_left, Rect2(0, hole.position.y, maxf(0.0, hole.position.x), maxf(0.0, hole.size.y)))
	_fill_dim(dim_right, Rect2(hole.end.x, hole.position.y, maxf(0.0, vp.x - hole.end.x), maxf(0.0, hole.size.y)))
	if dim_frame != null:
		dim_frame.position = hole.position - global_position
		dim_frame.size = hole.size
		dim_frame.queue_redraw()


func _hole_for_step() -> Rect2:
	var map := _map()
	if step == 0 or step == 1:
		var h := guide
		if map != null and DataDB.in_bounds(h.x, h.y):
			var sp := map.world_to_screen(HexGrid.axial_to_pixel(h.x, h.y))
			return Rect2(sp - Vector2(46, 46), Vector2(92, 92))
	if step == 2 and host != null and host.dock != null and host.home_button != null:
		var top := host.minimap.get_global_rect()
		if top.size.x < 4.0:
			top = host.dock.get_global_rect()
		return top.merge(host.home_button.get_global_rect()).grow(8.0)
	if step == 3 and host != null and host.key_plate != null:
		return host.key_plate.get_global_rect().grow(10.0)
	if step == 3 and host != null and host.key_hint != null:
		return host.key_hint.get_global_rect().grow(12.0)
	if step == 4 and host != null and host.end_button != null:
		return host.end_button.get_global_rect().grow(8.0)
	return Rect2(560, 280, 160, 90)


func _check() -> void:
	if step == 0:
		var picked := GameState.selected_unit()
		if not picked.is_empty() and str(picked.name) == "刘平部":
			_advance()
	elif step == 1 and track_uid >= 0:
		var moved := GameState.unit_by_id(track_uid)
		if not moved.is_empty() and (int(moved.q) != track_q or int(moved.r) != track_r):
			_advance()


func _on_oriented(_kind: String) -> void:
	if active and step == 2:
		_advance()


func _on_cycled(_uid: int) -> void:
	if active and step == 3:
		_advance()


func _on_turn() -> void:
	if active and step == 4:
		_advance()


func _on_skip() -> void:
	_finish()


func _on_next() -> void:
	_advance()


func _advance() -> void:
	if _busy or not active:
		return
	_busy = true
	step += 1
	if host and host.has_method("close_tile_menu"):
		host.close_tile_menu()
	if step >= LINES.size():
		_finish()
	else:
		_show_step()
	_busy = false


func _finish() -> void:
	active = false
	visible = false
	if shade:
		shade.visible = false
	guide = Vector2i(999999, 0)
	_push_guide()
	GameState.tutorial_done = true
	if GameState.playing:
		SaveManager.save_slot(0, true)
	EventBus.state_changed.emit()


func _push_guide() -> void:
	var map := _map()
	if map == null:
		return
	map.guide_hex = guide
	if map._overlay != null:
		map._refresh_overlay()


func _garrison() -> Dictionary:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.name) == "刘平部":
			return u
	return {}


func _pick_hex(u: Dictionary) -> Vector2i:
	var origin := Vector2i(int(u.q), int(u.r))
	var map := _map()
	var best := origin
	var best_d := 99
	if map == null:
		return origin
	for h_v in map.reach_cost.keys():
		var h: Vector2i = h_v
		if h == origin:
			continue
		var dist := HexGrid.distance(origin, h)
		if dist >= 1 and dist < best_d:
			best = h
			best_d = dist
	return best


func _bubble_pos(vp: Vector2, bsize: Vector2) -> Vector2:
	var avoid: Array[Rect2] = []
	avoid.append(hole_global.grow(18.0))
	avoid.append(Rect2(0, 568, 1020, 160))
	avoid.append(Rect2(1000, 420, 280, 300))
	avoid.append(Rect2(0, 52, 330, 250))
	if step <= 1:
		var map := _map()
		if map != null:
			var box := hole_global
			for h_v in map.reach_cost.keys():
				var h: Vector2i = h_v
				var sp := map.world_to_screen(HexGrid.axial_to_pixel(h.x, h.y))
				box = box.merge(Rect2(sp - Vector2(22, 22), Vector2(44, 44)))
			if map.camera != null and DataDB.in_bounds(guide.x, guide.y):
				var gsp := map.world_to_screen(HexGrid.axial_to_pixel(guide.x, guide.y))
				box = box.merge(Rect2(gsp - Vector2(36, 36), Vector2(72, 72)))
			avoid.append(box.grow(12.0))
	var candidates: Array[Vector2] = [
		Vector2(24, 348),
		Vector2(640, 68),
		Vector2(340, 68),
		Vector2(24, 188),
	]
	var best := candidates[0]
	var best_hit := 999999.0
	for spot in candidates:
		var rect := Rect2(spot, bsize)
		if rect.end.x > vp.x - 8.0 or rect.end.y > vp.y - 8.0 or rect.position.x < 8.0:
			continue
		var hit := 0.0
		for block in avoid:
			if rect.intersects(block):
				var overlap := rect.intersection(block)
				hit += overlap.size.x * overlap.size.y
		if hit < best_hit:
			best_hit = hit
			best = spot
			if hit <= 0.0:
				break
	return best


func _map() -> WorldMap:
	return get_tree().get_first_node_in_group("world_map") as WorldMap


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_MIDDLE:
			get_viewport().set_input_as_handled()
			return
		var at := mb.position
		var hole_hit := _passes(at) or _passes(mb.global_position)
		if hole_hit:
			return
		if bubble != null and bubble.get_global_rect().has_point(at):
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _key_ok(key):
			return
		get_viewport().set_input_as_handled()


func _passes(at: Vector2) -> bool:
	if hole_global.has_point(at):
		return true
	var map := _map()
	if map != null and map.camera != null and DataDB.in_bounds(guide.x, guide.y):
		var sp := map.world_to_screen(HexGrid.axial_to_pixel(guide.x, guide.y))
		if at.distance_to(sp) <= 72.0:
			return true
	return false


func _key_ok(key: InputEventKey) -> bool:
	if step == 2 and key.keycode == KEY_HOME:
		return true
	if step == 3 and key.keycode == KEY_SPACE:
		return true
	if step == 4 and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		return true
	return false


func _dim_piece() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0.62)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 0
	add_child(rect)
	return rect


func _fill_dim(rect: ColorRect, area: Rect2) -> void:
	if rect == null:
		return
	rect.position = area.position - global_position
	rect.size = Vector2(maxf(0.0, area.size.x), maxf(0.0, area.size.y))
	rect.visible = area.size.x > 1.0 and area.size.y > 1.0


class HoleFrame extends Control:
	func _draw() -> void:
		if size.x < 2.0 or size.y < 2.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size).grow(-1), Color(0.05, 0.04, 0.03, 0.9), false, 7.0)
		draw_rect(Rect2(Vector2.ZERO, size).grow(-3), Color("e7c98a"), false, 3.0)
