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
var _perf_frames := 0
var _tris := 0
var _cluster_mesh := {}
var _kit_mesh := {}
var _city_material: StandardMaterial3D
var _bake_mode := ""
var _env: Environment
var _land_shader: ShaderMaterial
var _debug_dist := 0.0
var feature_points: Array = []

const CITY_SCALE := 1.8
# Camera distance is 280 at the default zoom and 780 at strategic. Detail
# beyond this range drops out, which hides forests and fields when pulled back.
const DETAIL_RANGE := 560.0

func _ready() -> void:
	var built: Dictionary = TerrainFactory.build()
	heights = built.heights
	_add_mesh("Land", built.land, _land_mat(built.river_mask, built.border_mask), true)
	_add_mesh("Water", built.water, _water_mat(), false)
	feature_points = built.features
	_add_trees(built)
	_spawn_terrain_kit()
	_tris = _count_tris(built.land) + _count_tris(built.water)
	print("TRIS land %d water %d rivers 0" % [_count_tris(built.land), _count_tris(built.water)])
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
	_sync_grade()
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


func _land_mat(mask: Dictionary, border: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/land.gdshader")
	mat.set_shader_parameter("grid_fade", 0.04)
	mat.set_shader_parameter("river_map", mask.tex)
	mat.set_shader_parameter("river_origin", mask.origin)
	mat.set_shader_parameter("river_scale", mask.scale)
	mat.set_shader_parameter("border_map", border.tex)
	mat.set_shader_parameter("border_origin", border.origin)
	mat.set_shader_parameter("border_scale", border.scale)
	mat.set_shader_parameter("border_px", 2.6)
	_land_shader = mat
	return mat


func _water_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	return mat


func _glow_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/glow.gdshader")
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
	sun.light_color = Color("ffd2a0")
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 1400.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 0.85
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, 148, 0)
	fill.light_color = Color("d5cbb8")
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	add_child(fill)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a8b4bc")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c5c2b6")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.96
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.00005
	env.fog_light_color = Color("b7c0c4")
	env.fog_aerial_perspective = 0.08
	_env = env
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


func _sync_grade() -> void:
	var fade := 0.04
	var density := 0.00005
	var border_px := 2.6
	if zoom_index == 0:
		fade = 0.015
		density = 0.00012
		border_px = 3.6
	elif zoom_index >= 2:
		fade = 0.07
		density = 0.00002
		border_px = 2.2
	if _debug_dist > 900.0:
		density = 0.00007
		border_px = 4.0
	if _land_shader:
		_land_shader.set_shader_parameter("grid_fade", fade)
		_land_shader.set_shader_parameter("border_px", border_px)
	if _env:
		_env.fog_density = density


func spawn_hex_features(mesh_key: String, mesh: Mesh, lift: float = 0.0, detail_range: float = 0.0) -> MultiMeshInstance3D:
	# One MultiMesh per chunk of this piece, scaled from the kit's 10 m hex
	# to the 18 m map hex. Chunks frustum-cull; a single map-sized mesh would not.
	if mesh == null:
		return null
	var groups := {}
	var total := 0
	for item_v in feature_points:
		var item: Dictionary = item_v
		var key := str(item.get("mesh", ""))
		if key == "":
			key = str(item.get("id", ""))
		if key != mesh_key:
			continue
		var yaw := float(item.get("yaw", 0.0))
		var pos := Vector3(float(item.x), float(item.y) + lift, float(item.z))
		var sy := float(item.get("sy", 1.0))
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(CITY_SCALE, CITY_SCALE * sy, CITY_SCALE))
		var cq := int(floor(float(item.q) / 6.0))
		var cr := int(floor(float(item.r) / 6.0))
		var ck := Vector2i(cq, cr)
		if not groups.has(ck):
			groups[ck] = []
		var bucket: Array = groups[ck]
		bucket.append(Transform3D(basis, pos))
		groups[ck] = bucket
		total += 1
	if total == 0:
		return null
	var holder := get_node_or_null("Features") as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Features"
		add_child(holder)
	var first: MultiMeshInstance3D = null
	for ck_v in groups.keys():
		var ck: Vector2i = ck_v
		var bucket2: Array = groups[ck]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = bucket2.size()
		for i in bucket2.size():
			mm.set_instance_transform(i, bucket2[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Feature_%s_%d_%d" % [mesh_key, ck.x, ck.y]
		inst.multimesh = mm
		inst.material_override = _city_mat()
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inst.extra_cull_margin = 48.0
		if detail_range > 0.0:
			inst.visibility_range_end = detail_range
		holder.add_child(inst)
		if first == null:
			first = inst
	print("FEATURE %s chunks %d inst %d tris %d" % [mesh_key, groups.size(), total, _count_tris(mesh) * total])
	return first


func _spawn_terrain_kit() -> void:
	var keys: Array[String] = [
		"mountain_a", "mountain_b", "mountain_c",
		"mountain_ridge", "mountain_ridge_bend", "mountain_ridge_end",
		"hills_a", "hills_b", "hills_c", "hills_loess", "hills_a_loess", "hills_b_loess",
		"forest_conifer_a", "forest_conifer_b",
		"forest_mixed_a", "forest_mixed_b", "forest_sparse",
		"farm_fields", "rice_paddies",
		"reeds", "desert_scrub", "rocks_a", "rocks_b",
	]
	for key in keys:
		var detail := DETAIL_RANGE
		if key.begins_with("mountain"):
			detail = 0.0
		elif key == "farm_fields":
			# Default zoom sits ~280 m from the focus, so 210 m hides the
			# wheat sticks there and at strategic zoom. A close view is inside it.
			detail = 210.0
		spawn_hex_features(key, _terrain_mesh(key), 0.0, detail)


func _terrain_mesh(key: String) -> ArrayMesh:
	if _kit_mesh.has(key):
		return _kit_mesh[key]
	var source := key
	_bake_mode = ""
	if key == "hills_a_loess":
		source = "hills_a"
		_bake_mode = "loess_hill"
	elif key == "hills_b_loess":
		source = "hills_b"
		_bake_mode = "loess_hill"
	elif key == "hills_loess":
		_bake_mode = "loess"
	elif key.begins_with("mountain"):
		_bake_mode = "mountain"
	elif key == "farm_fields":
		_bake_mode = "farm"
	var path := "res://art/models/song_terrain/%s.glb" % source
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("missing terrain mesh " + path)
		_bake_mode = ""
		return null
	var scene := packed.instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_city_mat())
	var stats := _bake_cluster(scene, Transform3D.IDENTITY, st)
	scene.free()
	_bake_mode = ""
	var mesh := st.commit()
	_kit_mesh[key] = mesh
	print("TERRAIN %s tris %d verts %d color %.2f..%.2f" % [key, _count_tris(mesh), stats.x, stats.y, stats.z])
	return mesh


func _city_mat() -> StandardMaterial3D:
	if _city_material != null:
		return _city_material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.84
	mat.metallic = 0.0
	mat.metallic_specular = 0.12
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_city_material = mat
	return mat


func _cluster_kind(city: Dictionary) -> String:
	if bool(city.get("capital", false)):
		return "capital"
	if bool(city.get("major", false)):
		return "walled"
	return "town"


func _merged_cluster(kind: String) -> ArrayMesh:
	_bake_mode = ""
	if _cluster_mesh.has(kind):
		return _cluster_mesh[kind]
	var path := "res://art/models/song_city/clusters/cluster_%s.glb" % kind
	var packed: PackedScene = load(path)
	var scene := packed.instantiate()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(_city_mat())
	var stats := _bake_cluster(scene, Transform3D.IDENTITY, st)
	scene.free()
	var mesh := st.commit()
	_cluster_mesh[kind] = mesh
	print("CLUSTER %s tris %d verts %d color %.2f..%.2f" % [kind, _count_tris(mesh), stats.x, stats.y, stats.z])
	return mesh


func _bake_cluster(node: Node, parent_xf: Transform3D, st: SurfaceTool) -> Vector3:
	var xf := parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	var lo := 1.0
	var hi := 0.0
	var nverts := 0
	if node is MeshInstance3D:
		var baked := _bake_mesh(node as MeshInstance3D, xf, st)
		lo = baked.y
		hi = baked.z
		nverts = int(baked.x)
	for child in node.get_children():
		var sub := _bake_cluster(child, xf, st)
		nverts += int(sub.x)
		lo = minf(lo, sub.y)
		hi = maxf(hi, sub.z)
	return Vector3(float(nverts), lo, hi)


func _bake_mesh(mi: MeshInstance3D, xf: Transform3D, st: SurfaceTool) -> Vector3:
	var mesh := mi.mesh
	if mesh == null:
		return Vector3.ZERO
	var lo := 1.0
	var hi := 0.0
	var nverts := 0
	var normal_xf := xf.basis.inverse().transposed()
	# The hex plate is a separate green tile. Fields and roads live on other nodes.
	if str(mi.name).begins_with("hex_ground"):
		return Vector3.ZERO
	for s in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var index_data = arrays[Mesh.ARRAY_INDEX]
		var indices := PackedInt32Array()
		if index_data is PackedInt32Array:
			indices = index_data
		var albedo := Color.WHITE
		var mname := ""
		var mat := mesh.surface_get_material(s)
		if mat == null:
			mat = mi.get_surface_override_material(s)
		if mat is StandardMaterial3D:
			var sm := mat as StandardMaterial3D
			albedo = sm.albedo_color
			mname = sm.resource_name
		var order: Array = []
		if indices.is_empty():
			for i in verts.size():
				order.append(i)
		else:
			for i in indices.size():
				order.append(int(indices[i]))
		for i_v in order:
			var i := int(i_v)
			var col := Color.WHITE
			if i < cols.size():
				col = cols[i]
			col = Color(col.r * albedo.r, col.g * albedo.g, col.b * albedo.b, 1.0)
			var v := verts[i]
			var tinted := _tint_baked(col, albedo, v, mname)
			col = tinted.color
			v = tinted.vertex
			var lum := col.r * 0.3 + col.g * 0.5 + col.b * 0.2
			lo = minf(lo, lum)
			hi = maxf(hi, lum)
			st.set_color(col)
			var n := Vector3.UP
			if i < norms.size():
				n = (normal_xf * norms[i]).normalized()
			st.set_normal(n)
			st.add_vertex(xf * v)
			nverts += 1
	return Vector3(float(nverts), lo, hi)


func _build_cities() -> void:
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var ax := Vector2i(int(city.q), int(city.r))
		var px := HexGrid.axial_to_pixel(ax.x, ax.y)
		var root := Node3D.new()
		root.name = str(city.get("id", "city"))
		root.position = Vector3(px.x, _height_of(ax) + 0.04, px.y)
		var pop := int(city.get("pop", 1))
		var kind := _cluster_kind(city)
		var visual := MeshInstance3D.new()
		visual.name = "CityMesh"
		visual.mesh = _merged_cluster(kind)
		visual.material_override = _city_mat()
		visual.scale = Vector3(CITY_SCALE, CITY_SCALE, CITY_SCALE)
		var steps := posmod(hash(str(city.get("id", ""))), 6)
		visual.rotation.y = deg_to_rad(60.0 * float(steps))
		# Contact darkening is baked into the vertex colors. A real-time
		# shadow for every city redraws tens of thousands of triangles.
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(visual)
		var fc := DataDB.color_of(str(DataDB.faction(str(city.get("faction", ""))).get("color", "ffffff")))
		var by := 11.2
		if kind == "walled":
			by = 13.2
		elif kind == "capital":
			by = 20.4
		var banner := Node3D.new()
		banner.name = "Banner"
		root.add_child(banner)
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
		banner.add_child(quad)
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
		banner.add_child(ball)
		var short_name := str(city.get("short", city.get("name", "")))
		var shadow := _city_label(short_name, Vector3(0.72, by - 0.08, -0.04), Color(0, 0, 0, 0.45))
		banner.add_child(shadow)
		var lab := _city_label(short_name, Vector3(0.65, by + 0.02, 0.06), Color("f7f1e4"))
		banner.add_child(lab)
		var pop_lab := _city_label(str(pop), Vector3(-3.15, by + 0.02, 0.08), Color("1a2428"))
		pop_lab.font_size = 36
		pop_lab.pixel_size = 0.032
		banner.add_child(pop_lab)
		var walls := int(city.get("walls", 0))
		if walls > 0:
			var wall_lab := _city_label("防%d" % walls, Vector3(0.7, by - 1.15, 0.05), Color("f4ead2"))
			wall_lab.font_size = 28
			wall_lab.pixel_size = 0.028
			banner.add_child(wall_lab)
		var pri := 1
		if bool(city.get("major", false)):
			pri = 2
		if bool(city.get("capital", false)):
			pri = 3
		root.set_meta("pri", pri)
		root.set_meta("kind", kind)
		root.set_meta("banner_h", by)
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
		return Color("7a4e78")
	if faction == "liao":
		return Color("2c4a86")
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


func _cam_dist() -> float:
	if _debug_dist > 1.0:
		return _debug_dist
	return DIST[zoom_index]


func _place_camera() -> void:
	var dist := _cam_dist()
	var pitch_deg: float = float(PITCH[zoom_index])
	if _debug_dist > 1.0:
		pitch_deg = 48.0
	var pitch := deg_to_rad(pitch_deg)
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
		var scale: float = _cam_dist() / (view_w * 0.5)
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
	if _playing():
		_perf_frames += 1
		if _perf_frames >= 4:
			_perf_frames = 0
			var draws := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var prims := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			if not has_meta("perf_ready"):
				set_meta("perf_ready", true)
				print("PERF draws %.0f prims %.0f tris %d span %.1f" % [draws, prims, _tris, visible_hex_span()])
			set_meta("draw_calls", draws)
			set_meta("prims", prims)
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
		var step: Vector2 = dir.normalized() * (42.0 * delta * _cam_dist() / 54.0)
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
	_debug_dist = 0.0
	if bits.size() > 1:
		zoom_index = clampi(int(bits[1]), 0, DIST.size() - 1)
	if bits.size() > 3:
		_debug_dist = maxf(float(bits[3]), 0.0)
	_sync_grade()
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
	_debug_dist = 0.0
	zoom_index = clampi(zoom_index + step, 0, DIST.size() - 1)
	_sync_grade()
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
		var banner_h: float = float(node.get_meta("banner_h", 12.0))
		var sp := camera.unproject_position(node.global_position + Vector3(0, banner_h, 0))
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
		var city_root := item.n as Node3D
		var banner_node := city_root.get_node_or_null("Banner") as Node3D
		if banner_node:
			banner_node.visible = show
		var city_mesh := city_root.get_node_or_null("CityMesh") as MeshInstance3D
		if city_mesh:
			var city_kind := str(city_root.get_meta("kind", "town"))
			var show_mesh := true
			if city_kind == "town":
				if zoom_index <= 0:
					show_mesh = false
				elif zoom_index == 1:
					var here := HexGrid.pixel_to_axial(look_xz)
					var there := HexGrid.pixel_to_axial(Vector2(city_root.position.x, city_root.position.z))
					show_mesh = HexGrid.distance(here, there) <= 7
			city_mesh.visible = show_mesh


func _gray_of(col: Color, albedo: Color) -> float:
	var gray := 0.75
	if albedo.r > 0.08:
		gray = col.r / albedo.r
	elif albedo.g > 0.08:
		gray = col.g / albedo.g
	elif albedo.b > 0.08:
		gray = col.b / albedo.b
	return clampf(gray, 0.35, 1.0)


func _retint(col: Color, albedo: Color, target: Color) -> Color:
	var gray := _gray_of(col, albedo)
	return Color(target.r * gray, target.g * gray, target.b * gray, 1.0)


func _tint_baked(col: Color, albedo: Color, v: Vector3, mname: String) -> Dictionary:
	# Imported albedos are the display colours, not the glTF factors. Match the
	# material name so a green hex skirt cannot slip through a colour test.
	if _bake_mode == "mountain" and (mname == "M_meadow" or mname == "M_alpine"):
		var oy := v.y
		if mname == "M_meadow" and oy < 1.4:
			var sink_t := 1.0 - smoothstep(0.85, 1.4, oy)
			v.y = lerpf(oy, -0.38, sink_t * 0.98)
		if oy < 1.8:
			var t := 1.0 - smoothstep(0.3, 1.7, maxf(oy, 0.0))
			col = col.lerp(Color(0.42, 0.36, 0.30), clampf(0.78 + t * 0.2, 0.0, 0.98))
	elif _bake_mode == "loess" or _bake_mode == "loess_hill":
		var ochre := Color("a48462")
		var px := absf(v.x)
		var pz := absf(v.z)
		# Pointy hex in the kit, apothem about 8.66. The orange plate is the
		# outer terrace, so the rim has to sink or the hex step stays visible.
		var metric := maxf(px, px * 0.5 + pz * 0.8660254)
		var rim := smoothstep(3.4, 7.4, metric)
		var oy := v.y
		var shelf := 1.0 - smoothstep(0.35, 1.15, oy)
		var sink_t := rim * 0.85 + shelf * maxf(rim, 0.35) * 0.7
		var pad := mname == "M_skirt" or mname == "M_meadow" or (mname == "M_loess_gully" and oy < 0.35)
		if pad:
			sink_t = 1.0
		elif _bake_mode == "loess_hill":
			var grass := mname.begins_with("M_t_grass") or mname == "M_skirt"
			if not grass:
				sink_t = 0.0
			elif oy > 0.55 and rim < 0.45:
				sink_t *= 0.25
		if sink_t > 0.02:
			v.y = lerpf(oy, -0.7, clampf(sink_t, 0.0, 1.0))
		var tint_t := 0.88
		if rim > 0.35:
			tint_t = 1.0
		if _bake_mode == "loess" and (mname.begins_with("M_loess") or mname == "M_skirt" or mname == "M_meadow" or mname == "M_scrub"):
			col = col.lerp(_retint(col, albedo, ochre), tint_t)
			# Keep the sun from blowing the terrace back up to a white-orange plate.
			col = Color(col.r * 0.84, col.g * 0.86, col.b * 0.9, 1.0)
		elif mname.begins_with("M_t_grass") or mname == "M_bush_g" or mname == "M_skirt" or mname == "M_t_earth":
			col = col.lerp(_retint(col, albedo, ochre), 0.92)
			col = Color(col.r * 0.88, col.g * 0.88, col.b * 0.9, 1.0)
	elif _bake_mode == "farm":
		if mname == "M_canal":
			col = _retint(col, albedo, Color(0.10, 0.15, 0.17))
		elif mname == "M_wheat" or mname == "M_millet" or mname == "M_veg" or mname == "M_leaf_a" or mname == "M_leaf_b" or mname == "M_bund":
			col = col.lerp(_retint(col, albedo, Color(0.46, 0.43, 0.27)), 0.72)
	return {"color": col, "vertex": v}


func minimap_image() -> Image:
	var scale := 4
	var img := Image.create(DataDB.width * scale, DataDB.height * scale, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.10, 0.13, 0.16, 1.0))
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var color := TerrainFactory.swatch(tid)
			var owner := DataDB.owner_id(ax.x, ax.y)
			if owner != "" and tid != "sea" and tid != "lake":
				color = color.lerp(DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff"))), 0.48)
			for py in scale:
				for px in scale:
					img.set_pixel(col * scale + px, row * scale + py, color)
	for row2 in DataDB.height:
		for col2 in DataDB.width:
			var ax2 := HexGrid.axial_from_offset(col2, row2)
			var owner2 := DataDB.owner_id(ax2.x, ax2.y)
			var tid2 := DataDB.terrain_id(ax2.x, ax2.y)
			if owner2 == "" or tid2 == "sea" or tid2 == "lake":
				continue
			var pure := DataDB.color_of(str(DataDB.faction(owner2).get("color", "ffffff")))
			for dir_i in 6:
				var nb: Vector2i = ax2 + HexGrid.DIRS[dir_i]
				var draw := true
				if DataDB.in_bounds(nb.x, nb.y):
					if DataDB.terrain_id(nb.x, nb.y) == "lake":
						draw = false
					elif DataDB.owner_id(nb.x, nb.y) == owner2:
						draw = false
				if draw:
					_minimap_edge(img, col2, row2, scale, dir_i, pure)
	for u_v in GameState.units:
		var u: Dictionary = u_v
		var off := HexGrid.offset_from_axial(int(u.q), int(u.r))
		if off.x < 0 or off.y < 0 or off.x >= DataDB.width or off.y >= DataDB.height:
			continue
		var dot := Color("f4ead2")
		if str(u.faction) == "xia":
			dot = Color("d7a8cc")
		elif str(u.faction) == "liao":
			dot = Color("9ec0ea")
		for py2 in 2:
			for px2 in 2:
				img.set_pixel(off.x * scale + 1 + px2, off.y * scale + 1 + py2, dot)
	return img


func _minimap_edge(img: Image, col: int, row: int, scale: int, dir_i: int, color: Color) -> void:
	# Pointy neighbours folded onto the square cell: east/west columns, the two
	# northern neighbours share the top edge, the two southern ones the bottom.
	var x0 := col * scale
	var y0 := row * scale
	var thick := 2
	if dir_i == 0:
		for py in scale:
			for t in thick:
				img.set_pixel(x0 + scale - 1 - t, y0 + py, color)
	elif dir_i == 3:
		for py2 in scale:
			for t2 in thick:
				img.set_pixel(x0 + t2, y0 + py2, color)
	elif dir_i == 1 or dir_i == 2:
		for px in scale:
			for t3 in thick:
				img.set_pixel(x0 + px, y0 + t3, color)
	else:
		for px2 in scale:
			for t4 in thick:
				img.set_pixel(x0 + px2, y0 + scale - 1 - t4, color)


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
