class_name WorldMap
extends Node3D

const DIST := [780.0, 280.0, 115.0]
const PITCH := [50.0, 52.0, 40.0]
const VIEW_ANCHOR := Vector2(488, 326)

var camera: Camera3D
var zoom_index := 1
var look_xz := Vector2.ZERO
var hover := Vector2i.ZERO
var hover_ok := false
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
var heights := {}
var sprites := {}
var banners: Array[Node3D] = []
var _overlay: MeshInstance3D
var _focus_applied := ""
var _unit_kinds := {}
var _house: ArrayMesh
var _pagoda: ArrayMesh
var _perf_frames := 0
var _tris := 0

func _ready() -> void:
	var built: Dictionary = TerrainFactory.build()
	heights = built.heights
	_add_mesh("Land", built.land, _land_mat(), true)
	_add_mesh("Water", built.water, _water_mat(), false)
	_add_mesh("Rivers", built.rivers, _river_mat(), false)
	_add_mesh("Borders", built.borders, _glow_mat(), false)
	_add_trees(built)
	_tris = _count_tris(built.land) + _count_tris(built.water) + _count_tris(built.rivers)
	print("TRIS land %d water %d rivers %d" % [_count_tris(built.land), _count_tris(built.water), _count_tris(built.rivers)])
	_house = TerrainFactory.house_mesh()
	_pagoda = TerrainFactory.pagoda_mesh()
	_build_cities()
	_overlay = MeshInstance3D.new()
	_overlay.name = "Overlay"
	_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_overlay)
	_unit_kinds = {
		"infantry": TerrainFactory.unit_mesh("infantry"),
		"archer": TerrainFactory.unit_mesh("archer"),
		"cavalry": TerrainFactory.unit_mesh("cavalry"),
		"heavy": TerrainFactory.unit_mesh("heavy"),
	}
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 50.0
	camera.near = 0.5
	camera.far = 4200.0
	add_child(camera)
	camera.current = true
	_lighting()
	_measure()
	EventBus.state_changed.connect(_on_state)
	focus_city(str(DataDB.scenario.get("focus_city", "yanzhou")))
	_rebuild_units()
	_log_geometry()


func get_viewport_rect() -> Rect2:
	return get_viewport().get_visible_rect()


func _add_mesh(node_name: String, mesh: ArrayMesh, mat: Material, shadows: bool) -> void:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _land_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/land.gdshader")
	mat.set_shader_parameter("atlas", load("res://art/terrain/atlas.png"))
	return mat


func _water_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	return mat


func _glow_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/glow.gdshader")
	return mat


func _river_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/river.gdshader")
	return mat


func _add_trees(built: Dictionary) -> void:
	_scatter("Pines", built.pines, built.pine_trunk, built.pine_leaf, true)
	_scatter("Broads", built.broads, built.broad_trunk, built.broad_leaf, true)
	_scatter_one("Tufts", built.tufts, built.tuft_mesh, false)
	_scatter_one("Rocks", built.rocks, built.rock_mesh, true)


func _log_geometry() -> void:
	var meshes := 0
	var shadowers := 0
	var tris := 0
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MultiMeshInstance3D:
			var mm := (node as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			meshes += 1
			var count := mm.visible_instance_count
			if count < 0:
				count = mm.instance_count
			var t := _count_tris(mm.mesh) * count
			tris += t
			if (node as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadowers += 1
			print("MESH ", node.name, " inst ", count, " tris ", t)
		elif node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			meshes += 1
			var t2 := _count_tris(mi.mesh)
			tris += t2
			if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				shadowers += 1
	_tris = tris
	set_meta("mesh_draws", meshes)
	set_meta("shadow_draws", shadowers)
	print("GEOM draws %d shadowers %d tris %d" % [meshes, shadowers, tris])


func _count_tris(mesh: Mesh) -> int:
	var n := 0
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		if idx != null:
			n += int(idx.size() / 3)
		else:
			var verts = arrays[Mesh.ARRAY_VERTEX]
			n += int(verts.size() / 3)
	return n


func _scatter(node_name: String, items: Array, trunk: Mesh, leaf: Mesh, shadows: bool) -> void:
	if items.is_empty():
		return
	for part in [["Trunk", trunk, "trunk"], ["Leaf", leaf, "leaf"]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = part[1]
		mm.instance_count = items.size()
		for i in items.size():
			var item: Dictionary = items[i]
			mm.set_instance_transform(i, item.t)
			mm.set_instance_color(i, item[part[2]])
		var inst := MultiMeshInstance3D.new()
		inst.name = node_name + str(part[0])
		inst.multimesh = mm
		inst.material_override = _toon(Color.WHITE)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)


func _scatter_one(node_name: String, items: Array, mesh: Mesh, shadows: bool) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var item: Dictionary = items[i]
		mm.set_instance_transform(i, item.t)
		mm.set_instance_color(i, item.color)
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = mm
	inst.material_override = _toon(Color.WHITE)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


func _toon(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/toon.gdshader")
	mat.set_shader_parameter("albedo", color)
	return mat


func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50, -32, 0)
	sun.light_color = Color("ffe6c2")
	sun.light_energy = 1.02
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 1400.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 0.85
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 148, 0)
	fill.light_color = Color("b9cfe6")
	fill.light_energy = 0.16
	fill.shadow_enabled = false
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8eb8d6")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d7e4f0")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _measure() -> void:
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var p := HexGrid.axial_to_pixel(ax.x, ax.y)
			min_p = min_p.min(p)
			max_p = max_p.max(p)
	map_rect = Rect2(min_p - Vector2(40, 40), (max_p - min_p) + Vector2(80, 80))


func _build_cities() -> void:
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var ax := Vector2i(int(city.q), int(city.r))
		var px := HexGrid.axial_to_pixel(ax.x, ax.y)
		var root := Node3D.new()
		root.name = str(city.get("id", "city"))
		root.position = Vector3(px.x, _height_of(ax), px.y)
		var pop := int(city.get("pop", 1))
		var major := bool(city.get("major", false)) or bool(city.get("capital", false))
		var pad := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 7.4 if major else 5.6
		disc.bottom_radius = disc.top_radius
		disc.height = 0.16
		pad.mesh = disc
		pad.position = Vector3(0, 0.08, 0)
		pad.material_override = _toon(Color("c2b48a"))
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pad)
		var count := clampi(4 + pop / 2, 4, 7)
		if major:
			count = mini(count + 2, 8)
		for i in count:
			var house := MeshInstance3D.new()
			house.mesh = _house
			house.material_override = _toon(Color.WHITE)
			var ang := float(i) * 2.15 + 0.4
			var rad := 3.2 + float(i % 3) * 1.7
			house.position = Vector3(cos(ang) * rad, 0, sin(ang) * rad)
			house.rotation.y = ang
			var s := 2.05 + float(pop) * 0.03
			house.scale = Vector3(s, s, s)
			root.add_child(house)
		if major:
			var pagoda := MeshInstance3D.new()
			pagoda.mesh = _pagoda
			pagoda.material_override = _toon(Color.WHITE)
			pagoda.scale = Vector3(1.55, 1.55, 1.55)
			root.add_child(pagoda)
		var walls := int(city.get("walls", 0))
		if walls > 0 or major:
			for i in 8:
				var ang2 := TAU * float(i) / 8.0
				var seg := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(2.4, 0.85, 0.32)
				seg.mesh = box
				seg.material_override = _toon(Color("d9cbb0"))
				var wr := 6.6 if major else 5.2
				seg.position = Vector3(cos(ang2) * wr, 0.5, sin(ang2) * wr)
				seg.rotation.y = -ang2
				root.add_child(seg)
		var fc := DataDB.color_of(str(DataDB.faction(str(city.get("faction", ""))).get("color", "ffffff")))
		var by := 10.2 if major else 8.4
		var quad := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(8.2, 1.85)
		quad.mesh = qm
		var qmat := StandardMaterial3D.new()
		qmat.albedo_color = fc
		qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material_override = qmat
		quad.position = Vector3(0.4, by, 0)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(quad)
		var ball := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.72
		sm.height = 1.44
		ball.mesh = sm
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.albedo_color = fc.lightened(0.28)
		bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		ball.material_override = bmat
		ball.position = Vector3(-3.15, by, 0.02)
		ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ball)
		var short_name := str(city.get("short", city.get("name", "")))
		var shadow := _city_label(short_name, Vector3(0.72, by - 0.08, -0.04), Color(0, 0, 0, 0.45))
		root.add_child(shadow)
		var lab := _city_label(short_name, Vector3(0.65, by + 0.02, 0.06), Color("f7f1e4"))
		root.add_child(lab)
		var pop_lab := _city_label(str(pop), Vector3(-3.15, by + 0.02, 0.08), Color("1a2428"))
		pop_lab.font_size = 36
		pop_lab.pixel_size = 0.032
		root.add_child(pop_lab)
		if walls > 0:
			var wall_lab := _city_label("防%d" % walls, Vector3(0.7, by - 1.15, 0.05), Color("f4ead2"))
			wall_lab.font_size = 28
			wall_lab.pixel_size = 0.028
			root.add_child(wall_lab)
		var pri := 1
		if bool(city.get("major", false)):
			pri = 2
		if bool(city.get("capital", false)):
			pri = 3
		root.set_meta("pri", pri)
		root.set_meta("banner", true)
		add_child(root)
		banners.append(root)


func _city_label(text: String, pos: Vector3, color: Color) -> Label3D:
	var lab := Label3D.new()
	lab.text = text
	lab.font = Settings.banner_font
	lab.font_size = 48
	lab.pixel_size = 0.036
	lab.position = pos
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.modulate = color
	lab.outline_size = 0
	lab.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lab.no_depth_test = true
	return lab


func _on_state() -> void:
	if suspend > 0:
		return
	full_refresh()


func full_refresh() -> void:
	_rebuild_units()
	recompute_reach()
	_refresh_overlay()


func recompute_reach() -> void:
	reach_cost = {}
	reach_parent = {}
	var u := GameState.selected_unit()
	if u.is_empty() or str(u.faction) != "song" or int(u.mp) <= 0 or GameState.input_locked:
		return
	var info := Pathfinder.reachable(u)
	reach_cost = info.get("cost", {})
	reach_parent = info.get("parent", {})


func _kind_for(sprite_id: String) -> String:
	if sprite_id.find("archer") >= 0:
		return "archer"
	if sprite_id.find("tieyaozi") >= 0:
		return "heavy"
	if sprite_id.find("tribal") >= 0 or sprite_id.find("pishi") >= 0:
		return "cavalry"
	return "infantry"


func _cloth(faction: String) -> Color:
	if faction == "xia":
		return Color("a3483c")
	if faction == "liao":
		return Color("d2b15c")
	return Color("efe2c0")


func _rebuild_units() -> void:
	for id in sprites.keys():
		var n: Node = sprites[id]
		if is_instance_valid(n):
			n.queue_free()
	sprites.clear()
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if int(u.hp) <= 0:
			continue
		var spec := DataDB.unit_type(str(u.def_id))
		var kind := _kind_for(str(spec.get("sprite", "")))
		var root := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = _unit_kinds[kind]
		body.material_override = _toon(_cloth(str(u.faction)))
		root.add_child(body)
		var pole := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.06, 1.6, 0.06)
		pole.mesh = pm
		pole.position = Vector3(-0.35, 2.6, 0)
		pole.material_override = _toon(Color("5a4632"))
		root.add_child(pole)
		var flag := MeshInstance3D.new()
		var fm := QuadMesh.new()
		fm.size = Vector2(0.7, 0.46)
		flag.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = DataDB.color_of(str(DataDB.faction(str(u.faction)).get("color", "ffffff")))
		fmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		flag.material_override = fmat
		flag.position = Vector3(0.05, 3.15, 0)
		root.add_child(flag)
		var ax := Vector2i(int(u.q), int(u.r))
		root.position = _unit_pos(ax)
		root.scale = Vector3(2.5, 2.5, 2.5)
		add_child(root)
		sprites[int(u.uid)] = root


func _unit_pos(ax: Vector2i) -> Vector3:
	var p := HexGrid.axial_to_pixel(ax.x, ax.y)
	return Vector3(p.x, _height_of(ax) + 0.05, p.y)


func _height_of(ax: Vector2i) -> float:
	if heights.has(ax):
		return float(heights[ax])
	return 0.4


func animate_move(uid: int, path: Array) -> void:
	var node: Node3D = sprites.get(uid, null)
	if node == null:
		return
	animating = true
	for h_v in path:
		var h: Vector2i = h_v
		var dest := _unit_pos(h)
		var mid := node.position.lerp(dest, 0.5) + Vector3(0, 1.4, 0)
		var tw := create_tween()
		tw.tween_property(node, "position", mid, 0.09)
		tw.tween_property(node, "position", dest, 0.1)
		await tw.finished
	animating = false
	_refresh_overlay()


func animate_strike(uid: int, target: Vector2i) -> void:
	var node: Node3D = sprites.get(uid, null)
	if node == null:
		return
	var home := node.position
	var dest := _unit_pos(target)
	var lunge := home.lerp(dest, 0.28)
	lunge.y = maxf(home.y, dest.y) + 0.4
	var tw := create_tween()
	tw.tween_property(node, "position", lunge, 0.12)
	tw.tween_property(node, "position", home, 0.16)
	await tw.finished


func visible_hex_span() -> float:
	var vp := get_viewport_rect().size
	if camera == null or vp.x < 2.0:
		return 0.0
	var ax := HexGrid.pixel_to_axial(look_xz)
	var s0 := world_to_screen(HexGrid.axial_to_pixel(ax.x, ax.y))
	var s1 := world_to_screen(HexGrid.axial_to_pixel(ax.x + 1, ax.y))
	var dx := absf(s1.x - s0.x)
	if dx < 0.5:
		return 0.0
	return vp.x / dx


func focus_city(id: String) -> void:
	var city := DataDB.city_by_id(id)
	if city.is_empty():
		return
	focus_world(HexGrid.axial_to_pixel(int(city.q), int(city.r)))


func focus_world(world: Vector2) -> void:
	look_xz = world
	_place_camera()
	_seat_anchor(world)


func _place_camera() -> void:
	var dist: float = DIST[zoom_index]
	var pitch: float = deg_to_rad(PITCH[zoom_index])
	var yaw := deg_to_rad(12.0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var focus := Vector3(look_xz.x, 0.6, look_xz.y)
	camera.position = focus + offset
	camera.look_at(focus, Vector3.UP)


func _seat_anchor(world: Vector2) -> void:
	for _i in 8:
		_place_camera()
		var screen := world_to_screen(world)
		var err := VIEW_ANCHOR - screen
		if err.length() < 1.2:
			return
		var right := camera.global_transform.basis.x
		var fwd := -camera.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		if right.length() < 0.001 or fwd.length() < 0.001:
			return
		right = right.normalized()
		fwd = fwd.normalized()
		var view_w: float = get_viewport_rect().size.x
		if view_w < 2.0:
			view_w = 1280.0
		var scale: float = DIST[zoom_index] / (view_w * 0.5)
		look_xz += Vector2(right.x, right.z) * (-err.x) * scale
		look_xz += Vector2(fwd.x, fwd.z) * err.y * scale
	_place_camera()


func world_to_screen(world: Vector2) -> Vector2:
	var h := HexGrid.pixel_to_axial(world)
	var y := _height_of(h)
	return camera.unproject_position(Vector3(world.x, y, world.y))


func screen_to_world(screen: Vector2) -> Vector2:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if absf(dir.y) < 0.0001:
		return Vector2(origin.x, origin.z)
	var hit := origin
	for _i in 3:
		var t := (0.5 - origin.y) / dir.y
		hit = origin + dir * t
		var y := _height_of(HexGrid.pixel_to_axial(Vector2(hit.x, hit.z)))
		t = (y - origin.y) / dir.y
		hit = origin + dir * t
	return Vector2(hit.x, hit.z)


func _clamp_look() -> void:
	look_xz.x = clampf(look_xz.x, map_rect.position.x, map_rect.end.x)
	look_xz.y = clampf(look_xz.y, map_rect.position.y, map_rect.end.y)


func focus_after_load() -> void:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.faction) == "song":
			focus_world(HexGrid.axial_to_pixel(int(u.q), int(u.r)))
			return
	focus_city("yanzhou")


func _playing() -> bool:
	return GameState.playing


func _modal() -> bool:
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui == null:
		return false
	return bool(ui.call("modal_open"))


func _process(delta: float) -> void:
	if _playing() and not has_meta("perf_ready"):
		_perf_frames += 1
		if _perf_frames >= 6:
			var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			set_meta("draw_calls", draws)
			set_meta("prims", prims)
			set_meta("perf_ready", true)
			print("PERF draws %.0f prims %.0f tris %d span %.1f" % [draws, prims, _tris, visible_hex_span()])
	_poll_focus()
	if Engine.get_process_frames() % 12 == 0:
		_cull_banners()
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
	if dir != Vector2.ZERO and camera != null:
		var right := camera.global_transform.basis.x
		var fwd := -camera.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		var step: Vector2 = dir.normalized() * (42.0 * delta * float(DIST[zoom_index]) / 54.0)
		look_xz += Vector2(right.x, right.z) * step.x + Vector2(fwd.x, fwd.z) * step.y
		_clamp_look()
		_place_camera()


func _poll_focus() -> void:
	if not OS.has_feature("web"):
		return
	var raw = JavaScriptBridge.eval("window.__focusCity || ''")
	if not (raw is String):
		return
	var text := str(raw)
	if text == "" or text == _focus_applied:
		return
	_focus_applied = text
	var bits := text.split(",")
	if bits.size() > 1:
		zoom_index = clampi(int(bits[1]), 0, DIST.size() - 1)
	if bits[0].contains(":"):
		var qr := bits[0].split(":")
		focus_world(HexGrid.axial_to_pixel(int(qr[0]), int(qr[1])))
	else:
		focus_city(bits[0])


func _note_click(mb: InputEventMouseButton) -> void:
	debug_clicks.append({
		"b": int(mb.button_index),
		"x": mb.position.x,
		"y": mb.position.y,
		"p": mb.pressed,
	})
	if debug_clicks.size() > 8:
		debug_clicks.pop_front()


func _blocked(screen: Vector2) -> bool:
	if screen.y < 56.0:
		return true
	if screen.x < 430.0 and screen.y < 250.0:
		return true
	if screen.y > 608.0 and screen.x < 900.0:
		return true
	if screen.x > 1064.0 and screen.y > 440.0:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _playing() or not visible:
		return
	if event is InputEventMouseMotion:
		var mot := event as InputEventMouseMotion
		if order_press and not order_moved and mot.relative.length() >= 5.0:
			order_moved = true
			dragging = true
		if dragging:
			var before := screen_to_world(mot.position - mot.relative)
			var after := screen_to_world(mot.position)
			look_xz += before - after
			_clamp_look()
			_place_camera()
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
			_refresh_overlay()
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
	zoom_index = clampi(zoom_index + step, 0, DIST.size() - 1)
	_place_camera()
	var after := screen_to_world(screen)
	look_xz += before - after
	_clamp_look()
	_place_camera()
	_update_hover(screen)
	_cull_banners()


func _update_hover(screen: Vector2) -> void:
	if _blocked(screen):
		if hover_ok:
			hover_ok = false
			_refresh_overlay()
		return
	var world := screen_to_world(screen)
	var h := HexGrid.pixel_to_axial(world)
	var ok := DataDB.in_bounds(h.x, h.y)
	if ok != hover_ok or h != hover:
		hover = h
		hover_ok = ok
		_refresh_overlay()


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
	if _blocked(screen):
		return Vector2i(999999, 0)
	var h := HexGrid.pixel_to_axial(screen_to_world(screen))
	if not DataDB.in_bounds(h.x, h.y):
		return Vector2i(999999, 0)
	return h


func _refresh_overlay() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var reach_col := Color(0.25, 0.72, 0.48, 0.42)
	for h_v in reach_cost.keys():
		_fill_hex(st, h_v, reach_col)
	var u := GameState.selected_unit()
	if not u.is_empty():
		_stroke_hex(st, Vector2i(int(u.q), int(u.r)), Color("f0d060"), 0.28)
		var spec := DataDB.unit_type(str(u.def_id))
		var max_range := int(spec.get("range", 0)) if int(spec.get("ranged", 0)) > 0 else 1
		if int(u.mp) > 0:
			for other_v in GameState.units:
				var other: Dictionary = other_v
				if not DataDB.hostile(str(u.faction), str(other.faction)):
					continue
				var dist := HexGrid.distance(Vector2i(int(u.q), int(u.r)), Vector2i(int(other.q), int(other.r)))
				if dist >= 1 and dist <= max_range:
					_stroke_hex(st, Vector2i(int(other.q), int(other.r)), Color("c44a3a"), 0.26)
	if hover_ok:
		_stroke_hex(st, hover, Color(1, 1, 1, 0.85), 0.16)
	st.generate_normals()
	_overlay.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_overlay.material_override = mat


func _fill_hex(st: SurfaceTool, h: Vector2i, color: Color) -> void:
	var center := HexGrid.axial_to_pixel(h.x, h.y)
	var y := _height_of(h) + 0.18
	var cp := Vector3(center.x, y, center.y)
	for i in 6:
		var a0 := deg_to_rad(60.0 * float(i) - 30.0)
		var a1 := deg_to_rad(60.0 * float(i + 1) - 30.0)
		var p0 := Vector3(center.x + cos(a0) * HexGrid.SIZE * 0.92, y, center.y + sin(a0) * HexGrid.SIZE * 0.92)
		var p1 := Vector3(center.x + cos(a1) * HexGrid.SIZE * 0.92, y, center.y + sin(a1) * HexGrid.SIZE * 0.92)
		st.set_color(color)
		st.add_vertex(cp)
		st.set_color(color)
		st.add_vertex(p0)
		st.set_color(color)
		st.add_vertex(p1)


func _stroke_hex(st: SurfaceTool, h: Vector2i, color: Color, width: float) -> void:
	var center := HexGrid.axial_to_pixel(h.x, h.y)
	var y := _height_of(h) + 0.28
	for i in 6:
		var a0 := deg_to_rad(60.0 * float(i) - 30.0)
		var a1 := deg_to_rad(60.0 * float(i + 1) - 30.0)
		var p0 := Vector3(center.x + cos(a0) * HexGrid.SIZE, y, center.y + sin(a0) * HexGrid.SIZE)
		var p1 := Vector3(center.x + cos(a1) * HexGrid.SIZE, y, center.y + sin(a1) * HexGrid.SIZE)
		var dir := (p1 - p0)
		if dir.length() < 0.001:
			continue
		var side := dir.cross(Vector3.UP).normalized() * width
		st.set_color(color)
		st.add_vertex(p0 - side)
		st.set_color(color)
		st.add_vertex(p1 - side)
		st.set_color(color)
		st.add_vertex(p1 + side)
		st.set_color(color)
		st.add_vertex(p0 - side)
		st.set_color(color)
		st.add_vertex(p1 + side)
		st.set_color(color)
		st.add_vertex(p0 + side)


func _cull_banners() -> void:
	if camera == null:
		return
	var ranked: Array = []
	for node in banners:
		if not is_instance_valid(node):
			continue
		var sp := camera.unproject_position(node.global_position + Vector3(0, 10.0, 0))
		ranked.append({"n": node, "s": sp, "p": int(node.get_meta("pri", 1))})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.p) > int(b.p))
	var gap := 150.0
	if zoom_index == 1:
		gap = 100.0
	elif zoom_index >= 2:
		gap = 68.0
	var kept: Array[Vector2] = []
	for item in ranked:
		var pri := int(item.p)
		var show := true
		if zoom_index == 0 and pri < 2:
			show = false
		elif zoom_index == 1 and pri < 1:
			show = false
		if show:
			var sp: Vector2 = item.s
			for prev in kept:
				if sp.distance_to(prev) < gap:
					show = false
					break
			if show:
				kept.append(sp)
		(item.n as Node3D).visible = show


func minimap_image() -> Image:
	var img := Image.create(DataDB.width, DataDB.height, false, Image.FORMAT_RGBA8)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var color := DataDB.color_of(str(DataDB.terrain(tid).get("color", "333333")))
			var owner := DataDB.owner_id(ax.x, ax.y)
			if owner != "" and tid != "sea" and tid != "lake":
				color = color.lerp(DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff"))), 0.35)
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
	img.resize(DataDB.width * 4, DataDB.height * 4, Image.INTERPOLATE_BILINEAR)
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
