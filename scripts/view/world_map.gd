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
var _water_shader: ShaderMaterial
var _border_shader: ShaderMaterial
var _wash_shader: ShaderMaterial
var _wash_node: MeshInstance3D
var _fill_node: MeshInstance3D
var _debug_dist := 0.0
var overview := false
var _overview_dist := 1400.0
var _saved_look := Vector2.ZERO
var _saved_zoom := 1
var _pan_from := Vector2.ZERO
var _pan_to := Vector2.ZERO
var _pan_t := 0.0
var _pan_dur := 0.5
var _pan_active := false
var _center_hex := Vector2i(999999, 0)
var guide_hex := Vector2i(999999, 0)
var _booting := false
var _boot_seen := false
var _boot_state: Dictionary = {}
var _label_layer: CanvasLayer
var _realm_labels := {}
var _realm_centroid := {}
var _mini_base: Image
var _mini_size := Vector2.ZERO
var feature_points: Array = []

const MINI_HEX_W := 10.0
const MINI_PAD := 10.0
const REALM_NAMES := {
	"song": "大宋",
	"liao": "大辽",
	"xia": "西夏",
	"gusiluo": "吐蕃唃厮啰",
	"dali": "大理",
	"jiaozhi": "交趾",
	"goryeo": "高丽",
	"uyghur": "西州回鹘",
}

const CITY_SCALE := 1.8
# Camera distance is 280 at the default zoom and 780 at strategic. Detail
# beyond this range drops out, which hides forests and fields when pulled back.
const DETAIL_RANGE := 560.0

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--test"):
		_boot_apply(TerrainFactory.build())
		return
	_booting = true
	EventBus.map_boot.emit(0, 5, "豆沙包正在铺延州…")


func _boot_tick() -> void:
	if not _boot_seen:
		_boot_seen = true
		return
	if _boot_state.is_empty():
		_boot_state = TerrainFactory.boot_begin()
	if bool(_boot_state.get("done", false)):
		_booting = false
		_boot_apply(_boot_state["out"])
		EventBus.map_ready.emit()
		return
	TerrainFactory.boot_step(_boot_state)
	EventBus.map_boot.emit(int(_boot_state.get("phase", 0)), 5, str(_boot_state.get("label", "")))


func _boot_apply(built: Dictionary) -> void:
	heights = built.heights
	_add_mesh("Land", built.land, _land_mat(built.river_mask), true)
	_add_mesh("Water", built.water, _water_mat(), false)
	_border_shader = _stroke_mat()
	_add_mesh("RealmStroke", built.border_stroke, _border_shader, false)
	_wash_node = _add_mesh("RealmWash", built.border_wash, _wash_mat(40.0), false)
	_fill_node = _add_mesh("RealmFill", built.realm_fill, _fill_mat(), false)
	_fill_node.visible = false
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
	_build_realm_labels()
	EventBus.state_changed.connect(_on_state)
	EventBus.turn_started.connect(_on_turn_started)
	focus_city(str(DataDB.scenario.get("focus_city", "yanzhou")))
	_rebuild_units()
	_log_geometry()


func get_viewport_rect() -> Rect2:
	return get_viewport().get_visible_rect()


func _add_mesh(node_name: String, mesh: ArrayMesh, mat: Material, shadows: bool) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


func _land_mat(mask: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/land.gdshader")
	mat.set_shader_parameter("grid_fade", 0.04)
	mat.set_shader_parameter("river_map", mask.tex)
	mat.set_shader_parameter("river_origin", mask.origin)
	mat.set_shader_parameter("river_scale", mask.scale)
	_land_shader = mat
	return mat


func _water_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	_water_shader = mat
	return mat


func _stroke_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/border_stroke.gdshader")
	mat.set_shader_parameter("border_half_m", 3.0)
	mat.set_shader_parameter("border_ref_m", 0.5)
	return mat


func _wash_mat(bias: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/border_wash.gdshader")
	mat.set_shader_parameter("cam_bias", bias)
	mat.set_shader_parameter("wash_inset", 2.0)
	# After trees and the other transparent props, so the tint stays on top.
	mat.render_priority = 20
	_wash_shader = mat
	return mat


func _fill_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/border_fill.gdshader")
	mat.set_shader_parameter("cam_bias", 0.2)
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
	var any := false
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if DataDB.terrain_id(ax.x, ax.y) == "sea":
				continue
			var p := HexGrid.axial_to_pixel(ax.x, ax.y)
			min_p = min_p.min(p)
			max_p = max_p.max(p)
			any = true
	if not any:
		for row2 in DataDB.height:
			for col2 in DataDB.width:
				var ax2 := HexGrid.axial_from_offset(col2, row2)
				var p2 := HexGrid.axial_to_pixel(ax2.x, ax2.y)
				min_p = min_p.min(p2)
				max_p = max_p.max(p2)
	var margin := HexGrid.SIZE * 3.0
	map_rect = Rect2(min_p - Vector2(margin, margin), (max_p - min_p) + Vector2(margin * 2.0, margin * 2.0))


func _sync_grade() -> void:
	# border_px is the full on-screen width of the realm stroke.
	var fade := 0.04
	var density := 0.00005
	var border_px := 7.0
	if overview:
		fade = 0.0
		density = 0.000008
		border_px = 4.0
	elif zoom_index == 0:
		fade = 0.015
		density = 0.00012
		border_px = 5.0
	elif zoom_index >= 2:
		fade = 0.07
		density = 0.00002
		border_px = 8.0
	if _debug_dist > 900.0 and not overview:
		density = 0.00007
		border_px = 5.0
	if _land_shader:
		_land_shader.set_shader_parameter("grid_fade", fade)
	if _border_shader:
		var half_m := _border_half_metres(border_px)
		_border_shader.set_shader_parameter("border_half_m", half_m)
		if _wash_shader:
			_wash_shader.set_shader_parameter("wash_inset", half_m + 0.6)
	if _env:
		_env.fog_density = density
		_env.fog_aerial_perspective = 0.0 if overview else 0.08
	if _label_layer:
		_label_layer.visible = overview
	_apply_overview_actors()


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
		root.visible = not overview
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
	_pan_active = false
	look_xz = world
	_place_camera()
	_seat_anchor(world)


func focus_smooth(world: Vector2, dur: float = 0.5) -> void:
	if camera == null:
		focus_world(world)
		return
	var saved := look_xz
	focus_world(world)
	var dest := look_xz
	look_xz = saved
	_pan_active = false
	_place_camera()
	if saved.distance_to(dest) < 4.0:
		look_xz = dest
		_place_camera()
		_pan_active = false
		return
	_pan_from = saved
	_pan_to = dest
	_pan_t = 0.0
	_pan_dur = maxf(dur, 0.05)
	_pan_active = true


func return_home() -> void:
	if overview:
		_leave_overview(false)
	_debug_dist = 0.0
	var u := GameState.selected_unit()
	if not u.is_empty():
		focus_smooth(HexGrid.axial_to_pixel(int(u.q), int(u.r)))
	else:
		var city := DataDB.city_by_id("yanzhou")
		if city.is_empty():
			return
		focus_smooth(HexGrid.axial_to_pixel(int(city.q), int(city.r)))
	EventBus.oriented.emit("home")


func _tick_pan(delta: float) -> void:
	if not _pan_active:
		return
	_pan_t += delta
	var t := clampf(_pan_t / _pan_dur, 0.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t)
	look_xz = _pan_from.lerp(_pan_to, s)
	if t >= 1.0:
		look_xz = _pan_to
		_pan_active = false
	_place_camera()


func _on_turn_started() -> void:
	if camera == null or not _playing():
		return
	var u := GameState.selected_unit()
	if u.is_empty():
		for u_v in GameState.units:
			var cand: Dictionary = u_v
			if str(cand.faction) == "song" and int(cand.hp) > 0 and int(cand.mp) > 0:
				u = cand
				break
	if u.is_empty():
		return
	var world := HexGrid.axial_to_pixel(int(u.q), int(u.r))
	var sp := world_to_screen(world)
	var vp := get_viewport_rect().grow(-40.0)
	if vp.size.x < 2.0 or not vp.has_point(sp):
		if overview:
			_leave_overview(false)
		focus_smooth(world)


func _cam_dist() -> float:
	if overview:
		return _overview_dist
	if _debug_dist > 1.0:
		return _debug_dist
	return DIST[zoom_index]


func _place_camera() -> void:
	var dist := _cam_dist()
	var pitch_deg: float = float(PITCH[zoom_index])
	if overview:
		pitch_deg = 68.0
	elif _debug_dist > 1.0:
		pitch_deg = 48.0
	var pitch := deg_to_rad(pitch_deg)
	var yaw := deg_to_rad(12.0)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var focus := Vector3(look_xz.x, 0.6, look_xz.y)
	camera.position = focus + offset
	camera.look_at(focus, Vector3.UP)


func _seat_anchor(world: Vector2) -> void:
	_seat_toward(world, VIEW_ANCHOR)


func _seat_toward(world: Vector2, anchor: Vector2) -> void:
	for _i in 8:
		_place_camera()
		var screen := world_to_screen(world)
		var err := anchor - screen
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


func enter_overview() -> void:
	_enter_overview()


func focus_from_minimap(ax: Vector2i) -> void:
	if overview:
		_leave_overview(false)
	_debug_dist = 0.0
	zoom_index = 1
	_sync_grade()
	focus_smooth(HexGrid.axial_to_pixel(ax.x, ax.y))
	EventBus.oriented.emit("minimap")


func _enter_overview() -> void:
	if not overview:
		_saved_look = look_xz
		_saved_zoom = zoom_index
	_debug_dist = 0.0
	overview = true
	if map_rect.size.x < 10.0:
		_measure()
	var frame := _political_rect()
	var pitch := deg_to_rad(68.0)
	var dist_h := frame.size.x * 1.08 / 1.658
	var dist_v := frame.size.y * 1.12 * sin(pitch) / 0.932
	_overview_dist = clampf(maxf(dist_h, dist_v), 900.0, 3000.0)
	var center := frame.get_center()
	look_xz = center
	_sync_grade()
	_seat_toward(center, Vector2(600, 300))
	_place_realm_labels()
	print("OVERVIEW dist %.0f" % _overview_dist)


func _leave_overview(restore: bool) -> void:
	if not overview:
		return
	overview = false
	_debug_dist = 0.0
	if restore:
		look_xz = _saved_look
		zoom_index = _saved_zoom
	_sync_grade()
	_place_camera()


func _apply_overview_actors() -> void:
	for id in sprites.keys():
		var node: Node = sprites[id]
		if is_instance_valid(node):
			node.visible = not overview
	if _fill_node:
		_fill_node.visible = overview
	if _wash_node:
		_wash_node.visible = not overview
	_cull_banners()


func _political_rect() -> Rect2:
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	var any := false
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if DataDB.owner_id(ax.x, ax.y) == "":
				continue
			var tid := DataDB.terrain_id(ax.x, ax.y)
			if tid == "sea" or tid == "lake":
				continue
			var p := HexGrid.axial_to_pixel(ax.x, ax.y)
			min_p = min_p.min(p)
			max_p = max_p.max(p)
			any = true
	if not any:
		return map_rect
	return Rect2(min_p - Vector2(150, 120), (max_p - min_p) + Vector2(300, 240))


func _border_half_metres(px: float) -> float:
	var vh := get_viewport_rect().size.y
	if vh < 2.0:
		vh = 720.0
	var pitch_deg := float(PITCH[zoom_index])
	if overview:
		pitch_deg = 68.0
	elif _debug_dist > 1.0:
		pitch_deg = 48.0
	var mpp := _cam_dist() * tan(deg_to_rad(25.0)) / (vh * 0.5)
	mpp = mpp / maxf(sin(deg_to_rad(pitch_deg)), 0.4)
	return maxf(px * mpp * 0.5, 0.45)


func _build_realm_labels() -> void:
	var sum := {}
	var count := {}
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var owner := DataDB.owner_id(ax.x, ax.y)
			if owner == "" or not REALM_NAMES.has(owner):
				continue
			var tid := DataDB.terrain_id(ax.x, ax.y)
			if tid == "sea" or tid == "lake":
				continue
			var p := HexGrid.axial_to_pixel(ax.x, ax.y)
			if not sum.has(owner):
				sum[owner] = Vector2.ZERO
				count[owner] = 0
			sum[owner] = sum[owner] + p
			count[owner] = int(count[owner]) + 1
	_realm_centroid = {}
	for owner in sum.keys():
		_realm_centroid[owner] = sum[owner] / float(count[owner])
	_label_layer = CanvasLayer.new()
	_label_layer.name = "RealmLabels"
	_label_layer.layer = 8
	_label_layer.visible = false
	add_child(_label_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label_layer.add_child(root)
	for owner2 in REALM_NAMES.keys():
		var lab := Label.new()
		lab.text = str(REALM_NAMES[owner2])
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab.add_theme_font_override("font", Settings.font)
		var size := 32
		if owner2 == "song":
			size = 44
		elif owner2 == "liao":
			size = 40
		elif owner2 == "xia" or owner2 == "gusiluo":
			size = 30
		elif owner2 == "jiaozhi" or owner2 == "uyghur":
			size = 26
		lab.add_theme_font_size_override("font_size", size)
		var ink := DataDB.color_of(str(DataDB.faction(owner2).get("color", "ffffff"))).lerp(Color("f7f1e4"), 0.42)
		lab.add_theme_color_override("font_color", ink)
		lab.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.04, 0.92))
		lab.add_theme_constant_override("outline_size", 12)
		lab.visible = false
		root.add_child(lab)
		_realm_labels[owner2] = lab
	var hint := Label.new()
	hint.text = "按 M 返回"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.position = Vector2(430, 68)
	hint.add_theme_font_override("font", Settings.font)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("f4efe4"))
	hint.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.04, 0.92))
	hint.add_theme_constant_override("outline_size", 8)
	root.add_child(hint)
	_realm_labels["_hint"] = hint


func _place_realm_labels() -> void:
	if _label_layer == null:
		return
	var vp := get_viewport_rect().size
	for owner in _realm_centroid.keys():
		var lab: Label = _realm_labels[owner]
		var sp := world_to_screen(_realm_centroid[owner])
		var on_screen := sp.x > 8.0 and sp.y > 48.0 and sp.x < vp.x - 8.0 and sp.y < vp.y - 8.0
		lab.visible = on_screen
		if not on_screen:
			continue
		lab.reset_size()
		lab.position = sp - lab.size * 0.5


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


func _sync_center_hex() -> void:
	if camera == null or _overlay == null:
		return
	var next := Vector2i(999999, 0)
	if not overview:
		var vp := get_viewport_rect()
		if vp.size.x > 2.0 and vp.size.y > 2.0:
			next = HexGrid.pixel_to_axial(screen_to_world(vp.size * 0.5))
	if next == _center_hex:
		return
	_center_hex = next
	_refresh_overlay()


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
	if _booting:
		_boot_tick()
		return
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
	if overview:
		_place_realm_labels()
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
		_pan_active = false
		var right := camera.global_transform.basis.x
		var fwd := -camera.global_transform.basis.z
		right.y = 0.0
		fwd.y = 0.0
		var step: Vector2 = dir.normalized() * (42.0 * delta * _cam_dist() / 54.0)
		look_xz += Vector2(right.x, right.z) * step.x + Vector2(fwd.x, fwd.z) * step.y
		_clamp_look()
		_place_camera()
	else:
		_tick_pan(delta)
	_sync_center_hex()


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
	if bits[0] == "overview":
		_enter_overview()
		return
	if overview:
		overview = false
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
	var ui := get_tree().get_first_node_in_group("game_ui")
	if ui and ui.has_method("blocks_pointer"):
		return bool(ui.call("blocks_pointer", screen))
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
			_pan_active = false
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
	if event.keycode == KEY_HOME:
		return_home()
		return
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
	if event.unicode == 63:
		var help_ui := get_tree().get_first_node_in_group("game_ui")
		if help_ui and help_ui.has_method("replay_tutorial"):
			help_ui.call("replay_tutorial")
		return
	var desk_ui := get_tree().get_first_node_in_group("game_ui")
	if desk_ui:
		if event.keycode == KEY_T:
			desk_ui.call("open_desk", "tech")
			return
		if event.keycode == KEY_P:
			desk_ui.call("open_desk", "console")
			return
		if event.keycode == KEY_J:
			desk_ui.call("open_desk", "workshop")
			return
		if event.keycode == KEY_I:
			desk_ui.call("open_desk", "industry")
			return
		if event.keycode == KEY_L:
			desk_ui.call("open_desk", "talent")
			return
		if event.keycode == KEY_Y:
			desk_ui.call("open_desk", "court")
			return
		if event.keycode == KEY_H:
			desk_ui.call("open_desk", "codex")
			return
		if event.keycode == KEY_E:
			desk_ui.call("open_desk", "events")
			return
		if event.keycode == KEY_R:
			desk_ui.call("open_desk", "diplomacy")
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
	elif event.keycode == KEY_M:
		if overview:
			_leave_overview(true)
		else:
			_enter_overview()


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
	EventBus.unit_cycled.emit(nxt)


func _zoom_at(screen: Vector2, step: int) -> void:
	_pan_active = false
	var before := screen_to_world(screen)
	_debug_dist = 0.0
	if overview:
		overview = false
		zoom_index = clampi(step, 0, DIST.size() - 1)
	else:
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
		var city := DataDB.city_at_hex(h.x, h.y)
		var gui := get_tree().get_first_node_in_group("game_ui")
		if gui:
			if city.is_empty():
				gui.call("close_city")
			else:
				gui.call("open_city", str(city.get("id", "")))
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
	if DataDB.in_bounds(guide_hex.x, guide_hex.y):
		_fill_hex(st, guide_hex, Color(0.91, 0.74, 0.32, 0.35))
		_stroke_hex(st, guide_hex, Color("e7c98a"), 0.42)
	if not overview and DataDB.in_bounds(_center_hex.x, _center_hex.y):
		var selected_hex := Vector2i(999999, 0)
		if not u.is_empty():
			selected_hex = Vector2i(int(u.q), int(u.r))
		if _center_hex != selected_hex and _center_hex != hover and _center_hex != guide_hex:
			_stroke_hex(st, _center_hex, Color(0.95, 0.9, 0.72, 0.32), 0.1)
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
	if overview:
		for node in banners:
			if not is_instance_valid(node):
				continue
			var banner_node := node.get_node_or_null("Banner") as Node3D
			if banner_node:
				banner_node.visible = false
			var city_mesh := node.get_node_or_null("CityMesh") as MeshInstance3D
			if city_mesh:
				city_mesh.visible = false
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


func minimap_pixel_size() -> Vector2:
	return _minimap_size()


func minimap_axial(u: float, v: float) -> Vector2i:
	var sz := _minimap_size()
	var row_h := MINI_HEX_W * 0.8660254
	var hex_r := MINI_HEX_W / sqrt(3.0)
	var y := v * sz.y
	var row := clampi(int(round((y - MINI_PAD - hex_r) / row_h)), 0, DataDB.height - 1)
	var x := u * sz.x
	var q_plus := (x - MINI_PAD - MINI_HEX_W * 0.5) / MINI_HEX_W
	var col := clampi(int(round(q_plus - 0.5 * float(row & 1))), 0, DataDB.width - 1)
	return HexGrid.axial_from_offset(col, row)


func minimap_image() -> Image:
	if _mini_base == null:
		_mini_base = _paint_minimap_base()
		_mini_size = Vector2(_mini_base.get_width(), _mini_base.get_height())
	var img := _mini_base.duplicate()
	for u_v in GameState.units:
		var u: Dictionary = u_v
		var world := HexGrid.axial_to_pixel(int(u.q), int(u.r))
		var at := _mini_point(world)
		var dot := Color("f4ead2")
		if str(u.faction) == "xia":
			dot = Color("d7a8cc")
		elif str(u.faction) == "liao":
			dot = Color("9ec0ea")
		_mini_disc(img, at, 3.2, dot, dot)
	_mini_viewport(img)
	_mini_mark_city(img, "yanzhou", Color("f0d060"))
	_mini_mark_city(img, "kaifeng", Color("c23b2a"))
	return img


func _mini_mark_city(img: Image, id: String, fill: Color) -> void:
	var city := DataDB.city_by_id(id)
	if city.is_empty():
		return
	var at := _mini_point(HexGrid.axial_to_pixel(int(city.q), int(city.r)))
	if at.x < 2.0 or at.y < 2.0 or at.x >= float(img.get_width()) - 2.0 or at.y >= float(img.get_height()) - 2.0:
		return
	if id == "kaifeng":
		var arm := 5.5
		var up := at + Vector2(0, -arm)
		var right := at + Vector2(arm, 0)
		var down := at + Vector2(0, arm)
		var left := at + Vector2(-arm, 0)
		_mini_stroke(img, up, right, fill, 2.2)
		_mini_stroke(img, right, down, fill, 2.2)
		_mini_stroke(img, down, left, fill, 2.2)
		_mini_stroke(img, left, up, fill, 2.2)
		_mini_disc(img, at, 2.2, Color("f4ead2"), Color("f4ead2"))
		return
	_mini_disc(img, at, 5.2, Color("1a140c"), Color("1a140c"))
	_mini_disc(img, at, 3.3, fill, fill)


func _mini_viewport(img: Image) -> void:
	if camera == null:
		return
	var vp := get_viewport_rect()
	if vp.size.x < 2.0 or vp.size.y < 2.0:
		return
	var corners: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(vp.size.x, 0),
		Vector2(vp.size.x, vp.size.y),
		Vector2(0, vp.size.y),
	]
	var pts: Array[Vector2] = []
	for corner in corners:
		pts.append(_mini_point(screen_to_world(corner)))
	var col := Color(0.96, 0.86, 0.48, 1.0)
	for i in 4:
		_mini_stroke(img, pts[i], pts[(i + 1) % 4], col, 2.2)


func _minimap_size() -> Vector2:
	var row_h := MINI_HEX_W * 0.8660254
	var hex_r := MINI_HEX_W / sqrt(3.0)
	var w := MINI_PAD * 2.0 + (float(DataDB.width) + 0.5) * MINI_HEX_W
	var h := MINI_PAD * 2.0 + float(DataDB.height - 1) * row_h + hex_r * 2.0
	return Vector2(w, h)


func _mini_point(world: Vector2) -> Vector2:
	var r := world.y / (HexGrid.SIZE * 1.5)
	var q_plus := world.x / (HexGrid.SIZE * sqrt(3.0))
	var row_h := MINI_HEX_W * 0.8660254
	var hex_r := MINI_HEX_W / sqrt(3.0)
	return Vector2(MINI_PAD + q_plus * MINI_HEX_W + MINI_HEX_W * 0.5, MINI_PAD + r * row_h + hex_r)


func _paint_minimap_base() -> Image:
	var sz := _minimap_size()
	var img := Image.create(int(ceil(sz.x)), int(ceil(sz.y)), false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.12, 0.16, 1.0))
	var hex_r := MINI_HEX_W / sqrt(3.0)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var color := Color(0.09, 0.15, 0.21)
			var owner := DataDB.owner_id(ax.x, ax.y)
			if tid == "lake":
				color = Color(0.16, 0.32, 0.36)
			elif owner != "" and tid != "sea":
				var faction := DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff")))
				color = Color(0.94, 0.91, 0.84).lerp(faction, 0.9)
			elif tid != "sea":
				color = TerrainFactory.swatch(tid).lerp(Color(0.55, 0.5, 0.4), 0.35)
			var center := _mini_point(HexGrid.axial_to_pixel(ax.x, ax.y))
			_mini_fill_hex(img, center, hex_r * 1.06, color)
	var chords: Array = TerrainFactory._border_chords()
	for chord_v in chords:
		var chord: Dictionary = chord_v
		var tint: Color = chord["color"]
		var a := _mini_point(chord["a"])
		var b := _mini_point(chord["b"])
		_mini_stroke(img, a, b, tint.darkened(0.42), 7.4)
	for chord_v2 in chords:
		var chord2: Dictionary = chord_v2
		var tint2: Color = chord2["color"]
		var a2 := _mini_point(chord2["a"])
		var b2 := _mini_point(chord2["b"])
		_mini_stroke(img, a2, b2, tint2.lightened(0.42), 3.2)
	return img


func _mini_fill_hex(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var x0 := clampi(int(floor(center.x - radius - 1.0)), 0, img.get_width() - 1)
	var x1 := clampi(int(ceil(center.x + radius + 1.0)), 0, img.get_width() - 1)
	var y0 := clampi(int(floor(center.y - radius - 1.0)), 0, img.get_height() - 1)
	var y1 := clampi(int(ceil(center.y + radius + 1.0)), 0, img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := absf(float(x) + 0.5 - center.x) / radius
			var dy := absf(float(y) + 0.5 - center.y) / radius
			if dx <= 0.8660254 and dy <= 1.0 and dx * 0.5 + dy * 0.8660254 <= 0.8660254:
				img.set_pixel(x, y, color)


func _mini_stroke(img: Image, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var ab := b - a
	var length := ab.length()
	var steps := int(maxf(length * 2.0, 1.0))
	var rad := width * 0.5
	for s in steps + 1:
		var p := a.lerp(b, float(s) / float(steps))
		_mini_disc(img, p, rad, color, color)


func _mini_disc(img: Image, p: Vector2, rad: float, core: Color, edge: Color) -> void:
	var x0 := clampi(int(floor(p.x - rad)), 0, img.get_width() - 1)
	var x1 := clampi(int(ceil(p.x + rad)), 0, img.get_width() - 1)
	var y0 := clampi(int(floor(p.y - rad)), 0, img.get_height() - 1)
	var y1 := clampi(int(ceil(p.y + rad)), 0, img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(p)
			if d <= rad:
				var t := clampf(d / rad, 0.0, 1.0)
				img.set_pixel(x, y, core.lerp(edge, t))


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
