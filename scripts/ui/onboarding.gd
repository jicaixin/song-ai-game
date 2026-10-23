extends Control

const Kit = preload("res://scripts/ui/kit.gd")

const LINES := [
	"先点延州守军。左键，选自己人。城下那支西夏先别惹。",
	"右键点这一格亮着的地方。绿格子是今天还走得动的路。",
	"右下有小地图。点一格就到那一格。迷了路，按回延州，或按 Home。",
	"空格换下一支还能动的宋军。殿前司远在开封，空格会把镜头带过去。",
	"看明白了就按结束回合，或按回车。西夏会自己动。",
]

var active := false
var step := 0
var host: GameUI
var shade: Shade
var bubble: PanelContainer
var body: Label
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
	shade = Shade.new()
	shade.name = "TutorialShade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2.ZERO
	shade.size = size
	shade.custom_minimum_size = size
	add_child(shade)
	bubble = PanelContainer.new()
	bubble.name = "TutorialBubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_STOP
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
		if u.is_empty() or str(u.name) != "延州守军":
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


func _place() -> void:
	hole_global = _hole_for_step()
	if shade == null:
		return
	shade.position = Vector2.ZERO
	shade.size = size
	shade.custom_minimum_size = size
	shade.hole = Rect2(hole_global.position - global_position, hole_global.size)
	shade.queue_redraw()


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
	if step == 3 and host != null and host.key_hint != null:
		return host.key_hint.get_global_rect().grow(12.0)
	if step == 4 and host != null and host.end_button != null:
		return host.end_button.get_global_rect().grow(8.0)
	return Rect2(560, 280, 160, 90)


func _check() -> void:
	if step == 0:
		var picked := GameState.selected_unit()
		if not picked.is_empty() and str(picked.name) == "延州守军":
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
	if step >= LINES.size():
		_finish()
	else:
		_show_step()
	_busy = false


func _finish() -> void:
	active = false
	visible = false
	guide = Vector2i(999999, 0)
	_push_guide()
	GameState.tutorial_done = true
	if GameState.playing:
		SaveManager.save_slot(0, true)


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
		if str(u.name) == "延州守军":
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
		if bubble != null and bubble.get_global_rect().has_point(mb.position):
			return
		if hole_global.has_point(mb.position):
			return
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if _key_ok(key):
			return
		get_viewport().set_input_as_handled()


func _key_ok(key: InputEventKey) -> bool:
	if step == 2 and key.keycode == KEY_HOME:
		return true
	if step == 3 and key.keycode == KEY_SPACE:
		return true
	if step == 4 and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		return true
	return false


class Shade extends Control:
	var hole := Rect2()

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		var dim := Color(0, 0, 0, 0.62)
		var s := size
		if s.x < 2.0 or s.y < 2.0:
			s = get_viewport_rect().size
			if s.x < 2.0:
				s = Vector2(1280, 720)
		draw_rect(Rect2(0, 0, s.x, maxf(0.0, hole.position.y)), dim, true)
		draw_rect(Rect2(0, hole.end.y, s.x, maxf(0.0, s.y - hole.end.y)), dim, true)
		draw_rect(Rect2(0, hole.position.y, maxf(0.0, hole.position.x), hole.size.y), dim, true)
		draw_rect(Rect2(hole.end.x, hole.position.y, maxf(0.0, s.x - hole.end.x), hole.size.y), dim, true)
		if hole.size.x > 2.0 and hole.size.y > 2.0:
			draw_rect(hole, Color("e7c98a"), false, 3.0)
