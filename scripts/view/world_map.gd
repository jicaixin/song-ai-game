class_name WorldMap
extends Node2D

const ZOOMS: Array[float] = [0.5, 1.0, 2.0]
const VIEW_ANCHOR := Vector2(244, 163)

var camera: Camera2D
var terrain_layer: Node2D
var highlight_layer: Node2D
var bar_layer: Node2D
var city_layer: Node2D
var unit_layer: Node2D
var sprites := {}
var hover := Vector2i.ZERO
var hover_ok := false
var zoom_index := 1
var reach_cost := {}
var reach_parent := {}
var dragging := false
var order_press := false
var order_pos := Vector2.ZERO
var order_moved := false
var debug_clicks: Array = []
var animating := false
var suspend := 0
var map_rect := Rect2()
var _corners := PackedVector2Array()

func _ready() -> void:
	_corners = HexGrid.corners()
	var layer_script := load("res://scripts/view/map_layer.gd")
	terrain_layer = _layer(layer_script, "terrain")
	highlight_layer = _layer(layer_script, "highlight")
	city_layer = Node2D.new()
	city_layer.name = "Cities"
	city_layer.z_index = 3
	add_child(city_layer)
	unit_layer = Node2D.new()
	unit_layer.name = "Units"
	unit_layer.z_index = 4
	add_child(unit_layer)
	bar_layer = _layer(layer_script, "bars")
	bar_layer.z_index = 5
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	add_child(camera)
	camera.make_current()
	_build_cities()
	_measure()
	EventBus.state_changed.connect(_on_state)
	focus_city(str(DataDB.scenario.get("focus_city", "yanzhou")))


func _layer(script: Script, k: String) -> Node2D:
	var n := Node2D.new()
	n.set_script(script)
	n.set("kind", k)
	n.name = k
	add_child(n)
	return n


func _measure() -> void:
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var p := HexGrid.axial_to_pixel(ax.x, ax.y)
			min_p = min_p.min(p)
			max_p = max_p.max(p)
	map_rect = Rect2(min_p - Vector2(80, 80), (max_p - min_p) + Vector2(160, 160))


func _build_cities() -> void:
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var label := Label.new()
		label.text = str(city.get("short", city.get("name", "")))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.position = HexGrid.axial_to_pixel(int(city.q), int(city.r)) + Vector2(-24, -30)
		label.size = Vector2(48, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("f4ead2"))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 2)
		city_layer.add_child(label)


func _on_state() -> void:
	if suspend > 0:
		return
	full_refresh()


func full_refresh() -> void:
	_rebuild_units()
	recompute_reach()
	highlight_layer.queue_redraw()
	bar_layer.queue_redraw()


func recompute_reach() -> void:
	reach_cost = {}
	reach_parent = {}
	var u := GameState.selected_unit()
	if u.is_empty() or str(u.faction) != "song" or int(u.mp) <= 0 or GameState.input_locked:
		return
	var info := Pathfinder.reachable(u)
	reach_cost = info.get("cost", {})
	reach_parent = info.get("parent", {})


func _rebuild_units() -> void:
	for c in unit_layer.get_children():
		c.queue_free()
	sprites.clear()
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if int(u.hp) <= 0:
			continue
		var spec := DataDB.unit_type(str(u.def_id))
		var sprite := Sprite2D.new()
		sprite.texture = ArtBank.unit_tex(str(spec.get("sprite", "")))
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = HexGrid.axial_to_pixel(int(u.q), int(u.r))
		if int(u.uid) == GameState.selected_uid:
			sprite.modulate = Color(1.25, 1.15, 0.75)
		elif str(u.faction) == "song" and int(u.mp) <= 0:
			sprite.modulate = Color(0.72, 0.72, 0.72)
		unit_layer.add_child(sprite)
		sprites[int(u.uid)] = sprite


func animate_move(uid: int, path: Array) -> void:
	var sprite: Sprite2D = sprites.get(uid, null)
	if sprite == null:
		bar_layer.queue_redraw()
		return
	animating = true
	for h_v in path:
		var h: Vector2i = h_v
		var tw := create_tween()
		tw.tween_property(sprite, "position", HexGrid.axial_to_pixel(h.x, h.y), 0.12)
		await tw.finished
	animating = false
	bar_layer.queue_redraw()
	highlight_layer.queue_redraw()


func focus_city(id: String) -> void:
	var city := DataDB.city_by_id(id)
	if city.is_empty():
		return
	focus_world(HexGrid.axial_to_pixel(int(city.q), int(city.r)))


func focus_world(world: Vector2) -> void:
	var screen_c := get_viewport_rect().size * 0.5
	camera.position = world - (VIEW_ANCHOR - screen_c) / camera.zoom
	_clamp_camera()


func _screen_center() -> Vector2:
	return get_viewport_rect().size * 0.5


func world_to_screen(world: Vector2) -> Vector2:
	return (world - camera.position) * camera.zoom + _screen_center()


func screen_to_world(screen: Vector2) -> Vector2:
	return camera.position + (screen - _screen_center()) / camera.zoom


func _clamp_camera() -> void:
	camera.position.x = clampf(camera.position.x, map_rect.position.x, map_rect.end.x)
	camera.position.y = clampf(camera.position.y, map_rect.position.y, map_rect.end.y)


func _playing() -> bool:
	return GameState.playing


func _modal() -> bool:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return false
	return bool(ui.call("modal_open"))


func _process(delta: float) -> void:
	if not _playing():
		return
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		camera.position += dir.normalized() * 280.0 * delta / camera.zoom.x
		_clamp_camera()


func _note_click(mb: InputEventMouseButton) -> void:
	debug_clicks.append({
		"b": int(mb.button_index),
		"x": mb.position.x,
		"y": mb.position.y,
		"p": mb.pressed,
	})
	if debug_clicks.size() > 8:
		debug_clicks.pop_front()


func _unhandled_input(event: InputEvent) -> void:
	if not _playing():
		return
	if event is InputEventMouseMotion:
		var mot := event as InputEventMouseMotion
		# A middle press that does not drag issues the same order as a right
		# click. Dragging pans the map.
		if order_press and not order_moved and mot.relative.length() >= 5.0:
			order_moved = true
			dragging = true
		if dragging:
			camera.position -= mot.relative / camera.zoom
			_clamp_camera()
		_update_hover(mot.position)
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		_note_click(mb)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, 1)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, -1)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			order_press = true
			order_pos = mb.position
			order_moved = false
			dragging = false
			get_viewport().set_input_as_handled()
			return
		if _modal() or GameState.input_locked:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_left_click(mb.position)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_right_click(mb.position)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and not event.pressed:
		var mb2 := event as InputEventMouseButton
		_note_click(mb2)
		if mb2.button_index == MOUSE_BUTTON_MIDDLE:
			var fire := order_press and not order_moved
			var pos := order_pos
			order_press = false
			dragging = false
			if fire and not _modal() and not GameState.input_locked:
				_right_click(pos)
				get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		_key(event as InputEventKey)


func _key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		var ui := get_tree().get_first_node_in_group("game_ui")
		if ui and bool(ui.call("modal_open")):
			ui.call("hide_modals")
		else:
			GameState.selected_uid = -1
			GameState.inspected_uid = -1
			recompute_reach()
			highlight_layer.queue_redraw()
			EventBus.state_changed.emit()
		return
	if _modal() or GameState.input_locked:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		TurnManager.request_end()
	elif event.keycode == KEY_SPACE:
		_cycle_unit()
	elif event.keycode == KEY_F:
		var u := GameState.selected_unit()
		if not u.is_empty():
			GameState.fortify(int(u.uid))
	elif event.keycode == KEY_F5:
		SaveManager.save_slot(1)
	elif event.keycode == KEY_F9:
		if SaveManager.load_slot(1):
			focus_after_load()


func _cycle_unit() -> void:
	var ids: Array[int] = []
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.faction) == "song" and int(u.hp) > 0 and int(u.mp) > 0:
			ids.append(int(u.uid))
	if ids.is_empty():
		return
	var idx := ids.find(GameState.selected_uid)
	var nxt: int = ids[(idx + 1) % ids.size()]
	GameState.selected_uid = nxt
	GameState.inspected_uid = -1
	var u := GameState.unit_by_id(nxt)
	focus_world(HexGrid.axial_to_pixel(int(u.q), int(u.r)))
	full_refresh()


func _zoom_at(screen: Vector2, step: int) -> void:
	var before := screen_to_world(screen)
	zoom_index = clampi(zoom_index + step, 0, ZOOMS.size() - 1)
	camera.zoom = Vector2.ONE * ZOOMS[zoom_index]
	var after := screen_to_world(screen)
	camera.position += before - after
	_clamp_camera()
	_update_hover(screen)


func _update_hover(screen: Vector2) -> void:
	if screen.x > 488.0 or screen.y < 24.0 or screen.y > 300.0:
		if hover_ok:
			hover_ok = false
			highlight_layer.queue_redraw()
		return
	var world := screen_to_world(screen)
	var h := HexGrid.pixel_to_axial(world)
	var ok := DataDB.in_bounds(h.x, h.y)
	if ok != hover_ok or h != hover:
		hover = h
		hover_ok = ok
		highlight_layer.queue_redraw()


func _left_click(screen: Vector2) -> void:
	var h := _hex_at(screen)
	if h == Vector2i(999999, 0):
		return
	var u := GameState.unit_at(h)
	if not u.is_empty() and str(u.faction) == "song":
		GameState.selected_uid = int(u.uid)
		GameState.inspected_uid = -1
	elif not u.is_empty():
		GameState.inspected_uid = int(u.uid)
	else:
		GameState.selected_uid = -1
		GameState.inspected_uid = -1
	full_refresh()


func _right_click(screen: Vector2) -> void:
	var h := _hex_at(screen)
	if h == Vector2i(999999, 0):
		return
	var u := GameState.selected_unit()
	if u.is_empty() or str(u.faction) != "song":
		return
	var enemy := GameState.unit_at(h)
	if not enemy.is_empty() and DataDB.hostile(str(u.faction), str(enemy.faction)):
		_try_attack(u, enemy)
		return
	if reach_cost.has(h):
		_move_to(u, h)


func _try_attack(u: Dictionary, enemy: Dictionary) -> void:
	if _can_attack_now(u, enemy):
		_open_preview(u, enemy)
		return
	var spec := DataDB.unit_type(str(u.def_id))
	var max_range := int(spec.get("range", 1)) if int(spec.get("ranged", 0)) > 0 else 1
	var best := Vector2i(999999, 0)
	var best_cost := 9999
	var target := Vector2i(int(enemy.q), int(enemy.r))
	for h_v in reach_cost.keys():
		var h: Vector2i = h_v
		var cost := int(reach_cost[h])
		if cost >= int(u.mp):
			continue
		if HexGrid.distance(h, target) > max_range or HexGrid.distance(h, target) < 1:
			continue
		if cost < best_cost:
			best_cost = cost
			best = h
	if best.x == 999999:
		return
	await _move_to(u, best)
	u = GameState.unit_by_id(int(u.uid))
	enemy = GameState.unit_by_id(int(enemy.uid))
	if u.is_empty() or enemy.is_empty():
		return
	if _can_attack_now(u, enemy):
		_open_preview(u, enemy)


func _can_attack_now(u: Dictionary, enemy: Dictionary) -> bool:
	if int(u.mp) <= 0:
		return false
	var spec := DataDB.unit_type(str(u.def_id))
	var dist := HexGrid.distance(Vector2i(int(u.q), int(u.r)), Vector2i(int(enemy.q), int(enemy.r)))
	if int(spec.get("ranged", 0)) > 0:
		return dist >= 1 and dist <= int(spec.get("range", 0))
	return dist == 1


func _open_preview(atk: Dictionary, dfd: Dictionary) -> void:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui:
		ui.call("show_combat", CombatResolver.assess(atk, dfd), int(atk.uid), int(dfd.uid))


func _move_to(u: Dictionary, dest: Vector2i) -> void:
	if not reach_cost.has(dest):
		return
	var start := Vector2i(int(u.q), int(u.r))
	var path := Pathfinder.reconstruct(reach_parent, start, dest)
	if path.is_empty():
		return
	var cost := int(reach_cost[dest])
	suspend += 1
	GameState.spend_mp(int(u.uid), cost)
	GameState.set_pos(int(u.uid), dest)
	GameState.last_event = "%s 行至所选格子。" % str(u.name)
	await animate_move(int(u.uid), path)
	suspend -= 1
	full_refresh()
	EventBus.state_changed.emit()


func _hex_at(screen: Vector2) -> Vector2i:
	if screen.x > 488.0 or screen.y < 24.0 or screen.y > 300.0:
		return Vector2i(999999, 0)
	var h := HexGrid.pixel_to_axial(screen_to_world(screen))
	if not DataDB.in_bounds(h.x, h.y):
		return Vector2i(999999, 0)
	return h


func focus_after_load() -> void:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.faction) == "song":
			focus_world(HexGrid.axial_to_pixel(int(u.q), int(u.r)))
			return
	focus_city("yanzhou")


func paint_terrain(c: CanvasItem) -> void:
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var terr := DataDB.terrain(tid)
			var color := DataDB.color_of(str(terr.get("color", "888888")))
			var owner := DataDB.owner_id(ax.x, ax.y)
			if owner != "" and tid != "sea" and tid != "lake":
				var fc := DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff")))
				color = color.lerp(fc, 0.33)
			if not DataDB.city_at_hex(ax.x, ax.y).is_empty():
				color = color.lightened(0.14)
			var pts := PackedVector2Array()
			for corner in _corners:
				pts.append(center + corner)
			c.draw_colored_polygon(pts, color)
			for i in HexGrid.DIRS.size():
				var nb: Vector2i = ax + HexGrid.DIRS[i]
				var o2 := ""
				if DataDB.in_bounds(nb.x, nb.y):
					o2 = DataDB.owner_id(nb.x, nb.y)
				if o2 == owner:
					continue
				if nb.x < ax.x or (nb.x == ax.x and nb.y < ax.y):
					continue
				var seg := _edge(center, HexGrid.axial_to_pixel(nb.x, nb.y))
				var border := Color(0.1, 0.08, 0.06, 0.85)
				if owner != "":
					border = DataDB.color_of(str(DataDB.faction(owner).get("color", "241c16"))).darkened(0.2)
				c.draw_line(seg[0], seg[1], border, 2.0)
	for key_v in DataDB.river_masks.keys():
		var key: Vector2i = key_v
		var masks: Array = DataDB.river_masks[key]
		var center := HexGrid.axial_to_pixel(key.x, key.y)
		for i in 6:
			var bit := 1 << i
			var great := (int(masks[1]) & bit) != 0
			var minor := (int(masks[0]) & bit) != 0
			if not great and not minor:
				continue
			var nb: Vector2i = key + HexGrid.DIRS[i]
			var seg := _edge(center, HexGrid.axial_to_pixel(nb.x, nb.y))
			if great:
				c.draw_line(seg[0], seg[1], Color("1a4f78"), 3.2)
			else:
				c.draw_line(seg[0], seg[1], Color("3d88b8"), 1.7)
	for key_v in DataDB.feature_hexes.keys():
		var key: Vector2i = key_v
		var center := HexGrid.axial_to_pixel(key.x, key.y)
		c.draw_circle(center + Vector2(0, 10), 2.4, Color("f0d060"))


func paint_highlight(c: CanvasItem) -> void:
	var reach_col := Color(0.18, 0.45, 0.36, 0.38)
	for h_v in reach_cost.keys():
		var h: Vector2i = h_v
		_fill_hex(c, h, reach_col)
	var u := GameState.selected_unit()
	if not u.is_empty():
		_stroke_hex(c, Vector2i(int(u.q), int(u.r)), Color("f0d060"), 2.4)
		var spec := DataDB.unit_type(str(u.def_id))
		var max_range := int(spec.get("range", 0)) if int(spec.get("ranged", 0)) > 0 else 1
		if int(u.mp) > 0:
			for other_v in GameState.units:
				var other: Dictionary = other_v
				if not DataDB.hostile(str(u.faction), str(other.faction)):
					continue
				var dist := HexGrid.distance(Vector2i(int(u.q), int(u.r)), Vector2i(int(other.q), int(other.r)))
				if dist >= 1 and dist <= max_range:
					_stroke_hex(c, Vector2i(int(other.q), int(other.r)), Color("a33b2b"), 2.2)
	if hover_ok and reach_cost.has(hover):
		var start := Vector2i(int(u.q), int(u.r)) if not u.is_empty() else hover
		var path := Pathfinder.reconstruct(reach_parent, start, hover)
		var prev := start
		for step in path:
			c.draw_line(HexGrid.axial_to_pixel(prev.x, prev.y), HexGrid.axial_to_pixel(step.x, step.y), Color("f4ead2"), 1.5)
			prev = step
	if hover_ok:
		_stroke_hex(c, hover, Color(1, 1, 1, 0.9), 1.4)


func paint_bars(c: CanvasItem) -> void:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if int(u.hp) <= 0:
			continue
		var p := HexGrid.axial_to_pixel(int(u.q), int(u.r))
		if animating and sprites.has(int(u.uid)):
			p = (sprites[int(u.uid)] as Sprite2D).position
		c.draw_rect(Rect2(p.x - 10, p.y + 12, 20, 3), Color(0, 0, 0, 0.7), true)
		var w := 20.0 * clampf(float(int(u.hp)) / 100.0, 0.0, 1.0)
		var col := Color("2f6d5a") if str(u.faction) == "song" else Color("a33b2b")
		if str(u.faction) == "liao":
			col = Color("a6842e")
		c.draw_rect(Rect2(p.x - 10, p.y + 12, w, 3), col, true)


func _fill_hex(c: CanvasItem, h: Vector2i, color: Color) -> void:
	var center := HexGrid.axial_to_pixel(h.x, h.y)
	var pts := PackedVector2Array()
	for corner in _corners:
		pts.append(center + corner)
	c.draw_colored_polygon(pts, color)


func _stroke_hex(c: CanvasItem, h: Vector2i, color: Color, width: float) -> void:
	var center := HexGrid.axial_to_pixel(h.x, h.y)
	var pts := PackedVector2Array()
	for corner in _corners:
		pts.append(center + corner)
	pts.append(pts[0])
	c.draw_polyline(pts, color, width)


func _edge(center: Vector2, other: Vector2) -> PackedVector2Array:
	var dir := other - center
	if dir.length() < 0.001:
		return PackedVector2Array([center, center])
	dir = dir.normalized()
	var mid := center + dir * (HexGrid.SIZE * sqrt(3.0) / 2.0)
	var tang := Vector2(-dir.y, dir.x) * HexGrid.SIZE * 0.5
	return PackedVector2Array([mid - tang, mid + tang])


func minimap_image() -> Image:
	var img := Image.create(DataDB.width, DataDB.height, false, Image.FORMAT_RGBA8)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var color := DataDB.color_of(str(DataDB.terrain(tid).get("color", "333333")))
			var owner := DataDB.owner_id(ax.x, ax.y)
			if owner != "" and tid != "sea" and tid != "lake":
				color = color.lerp(DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff"))), 0.4)
			img.set_pixel(col, row, color)
	for u_v in GameState.units:
		var u: Dictionary = u_v
		var off := HexGrid.offset_from_axial(int(u.q), int(u.r))
		if off.x < 0 or off.y < 0 or off.x >= DataDB.width or off.y >= DataDB.height:
			continue
		var dot := Color("f4ead2")
		if str(u.faction) == "xia":
			dot = Color("e07068")
		elif str(u.faction) == "liao":
			dot = Color("e6d080")
		img.set_pixel(off.x, off.y, dot)
	return img


func debug_units() -> Array:
	var out: Array = []
	for u_v in GameState.units:
		var u: Dictionary = u_v
		var world := HexGrid.axial_to_pixel(int(u.q), int(u.r))
		var screen := world_to_screen(world)
		out.append({
			"uid": int(u.uid),
			"name": str(u.name),
			"faction": str(u.faction),
			"def_id": str(u.def_id),
			"q": int(u.q),
			"r": int(u.r),
			"sx": screen.x,
			"sy": screen.y,
			"hp": int(u.hp),
			"mp": int(u.mp),
		})
	return out
