class_name TerrainFactory
extends RefCounted

## Original low-poly terrain. Heights, colors, and meshes are authored here,
## not taken from any existing game.

const PALETTE := {
	"plain": "6e6238",
	"grass": "3c7434",
	"hill": "6a5034",
	"mountain": "5a4e44",
	"alpine": "4a545c",
	"loess": "8c4c1c",
	"forest": "214e26",
	"marsh": "3a624c",
	"desert": "9a6c2e",
	"erg": "b0883c",
	"rice": "4e8234",
	"lake": "2a6e96",
	"sea": "123e6e",
}

const HEIGHTS := {
	"sea": -1.35,
	"lake": -0.55,
	"marsh": 0.22,
	"plain": 0.52,
	"grass": 0.6,
	"rice": 0.4,
	"desert": 0.7,
	"erg": 0.95,
	"loess": 1.35,
	"forest": 0.68,
	"hill": 2.7,
	"mountain": 8.4,
	"alpine": 12.2,
}


static func build() -> Dictionary:
	var heights := {}
	var colors := {}
	var shore := {}
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			heights[ax] = _center_height(id, ax)
			colors[ax] = _tint(id, ax)
			shore[ax] = _touches_water(ax)
	colors = _smooth_colors(colors)
	var land := _land_mesh(heights, colors, shore)
	var water := _water_mesh()
	var rivers := _ribbon_mesh(true, heights, colors)
	var borders := _ribbon_mesh(false, heights, colors)
	var woods := _tree_lists(heights)
	return {
		"land": land,
		"water": water,
		"rivers": rivers,
		"borders": borders,
		"heights": heights,
		"pine_trunk": _trunk_mesh(),
		"pine_leaf": _pine_leaf(),
		"broad_trunk": _trunk_mesh(),
		"broad_leaf": _broad_leaf(),
		"pines": woods.pines,
		"broads": woods.broads,
	}


static func _water(id: String) -> bool:
	return id == "sea" or id == "lake"


static func _profile(id: String) -> Vector3:
	# extra summit height, shoulder radius (0 center .. 1 edge), terrace (0 spike .. 1 mesa)
	if id == "alpine":
		return Vector3(5.2, 0.38, 0.1)
	if id == "mountain":
		return Vector3(3.6, 0.44, 0.16)
	if id == "hill":
		return Vector3(1.15, 0.56, 0.32)
	if id == "loess":
		return Vector3(0.45, 0.46, 0.58)
	if id == "erg":
		return Vector3(0.9, 0.34, 0.12)
	if id == "desert":
		return Vector3(0.22, 0.62, 0.4)
	return Vector3(0.06, 0.7, 0.78)


static func _center_height(id: String, ax: Vector2i) -> float:
	var base: float = float(HEIGHTS.get(id, 0.45))
	if _water(id):
		return base
	var wobble := sin(float(ax.x) * 1.7 + float(ax.y) * 0.55) * cos(float(ax.y) * 1.25)
	var extra := _profile(id).x
	if id == "mountain" or id == "alpine":
		return base + extra + wobble * 1.25
	if id == "hill":
		return base + extra + wobble * 0.4
	if id == "erg" or id == "desert":
		return base + extra + absf(wobble) * 0.38
	if id == "loess":
		return base + extra + wobble * 0.18
	return base + extra + wobble * 0.14


static func _tint(id: String, ax: Vector2i) -> Color:
	var c := Color(str(PALETTE.get(id, "888888"))) as Color
	var n := sin(float(ax.x) * 0.9 + float(ax.y) * 1.4) * 0.04
	return Color(c.r + n, c.g + n * 0.6, c.b + n * 0.3)


static func _touches_water(ax: Vector2i) -> bool:
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and _water(DataDB.terrain_id(n.x, n.y)):
			return true
	return false


static func _smooth_colors(colors: Dictionary) -> Dictionary:
	var out := {}
	for key_v in colors.keys():
		var ax: Vector2i = key_v
		var own: Color = colors[ax]
		var acc := own
		var n := 1.0
		for d in HexGrid.DIRS:
			var nb: Vector2i = ax + d
			if not colors.has(nb):
				continue
			if _water(DataDB.terrain_id(nb.x, nb.y)):
				continue
			acc += colors[nb]
			n += 1.0
		out[ax] = own.lerp(acc / n, 0.42)
	return out


static func _river_on(ax: Vector2i, edge: int) -> bool:
	if edge < 0:
		return false
	var masks = DataDB.river_masks.get(ax, null)
	if masks == null:
		return false
	var bit := 1 << edge
	return (int(masks[0]) & bit) != 0 or (int(masks[1]) & bit) != 0


static func _corner_sample(ax: Vector2i, i: int, heights: Dictionary, colors: Dictionary) -> Dictionary:
	# A hex corner is shared by up to three land tiles. Water is excluded so
	# coasts stay a beach instead of a hole, and high ranges get saddles.
	var prev := (i + 5) % 6
	var ids: Array[Vector2i] = [ax]
	var a := ax + HexGrid.DIRS[i]
	var b := ax + HexGrid.DIRS[prev]
	if DataDB.in_bounds(a.x, a.y):
		ids.append(a)
	if DataDB.in_bounds(b.x, b.y):
		ids.append(b)
	var h := 0.0
	var low := 99.0
	var high := -99.0
	var col := Color(0, 0, 0)
	var n := 0
	var wet := false
	for id in ids:
		if _water(DataDB.terrain_id(id.x, id.y)):
			wet = true
			continue
		var hh := float(heights[id])
		h += hh
		low = minf(low, hh)
		high = maxf(high, hh)
		col += colors[id]
		n += 1
	if n == 0:
		h = 0.05
		col = colors[ax]
	else:
		h /= float(n)
		col /= float(n)
		if high > 5.0 and low > 4.0:
			h = lerpf(low * 0.5, h, 0.12)
		elif high - low > 3.0:
			h = lerpf(low, h, 0.28)
		else:
			h = lerpf(low, h, 0.66)
	if wet:
		h = minf(h, 0.07)
	if _river_on(ax, i) or _river_on(ax, prev):
		h -= 0.46
	var ang := deg_to_rad(60.0 * float(i) - 30.0)
	var center := HexGrid.axial_to_pixel(ax.x, ax.y)
	var pos := Vector3(center.x + cos(ang) * HexGrid.SIZE, h, center.y + sin(ang) * HexGrid.SIZE)
	return {"p": pos, "c": col}


static func _land_mesh(heights: Dictionary, colors: Dictionary, shore: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if _water(DataDB.terrain_id(ax.x, ax.y)):
				continue
			var id := DataDB.terrain_id(ax.x, ax.y)
			var center_px := HexGrid.axial_to_pixel(ax.x, ax.y)
			var prof := _profile(id)
			var peak := Vector3(center_px.x, float(heights[ax]), center_px.y)
			var cc: Color = colors[ax]
			var shore_v := 1.0 if bool(shore[ax]) else 0.0
			var corners: Array = []
			for i in 6:
				corners.append(_corner_sample(ax, i, heights, colors))
			var shoulders: Array = []
			for i in 6:
				var ap: Vector3 = corners[i].p
				var ac: Color = corners[i].c
				var lift := lerpf(0.26, 0.9, prof.z)
				var sp := Vector3(lerpf(peak.x, ap.x, prof.y), lerpf(ap.y, peak.y, lift), lerpf(peak.z, ap.z, prof.y))
				shoulders.append({"p": sp, "c": cc.lerp(ac, prof.y)})
			for i in 6:
				var a: Dictionary = corners[i]
				var b: Dictionary = corners[(i + 1) % 6]
				var sa: Dictionary = shoulders[i]
				var sb: Dictionary = shoulders[(i + 1) % 6]
				var ap: Vector3 = a.p
				var bp: Vector3 = b.p
				var sap: Vector3 = sa.p
				var sbp: Vector3 = sb.p
				var ac: Color = a.c
				var bc: Color = b.c
				var sac: Color = sa.c
				var sbc: Color = sb.c
				var m_ab := (ap + bp) * 0.5
				var c_ab := ac.lerp(bc, 0.5)
				_tri(st, peak, sap, sbp, cc, sac, sbc, 0.0, 0.42, 0.42, shore_v)
				_tri(st, sap, ap, m_ab, sac, ac, c_ab, 0.42, 1.0, 1.0, shore_v)
				_tri(st, sbp, m_ab, bp, sbc, c_ab, bc, 0.42, 1.0, 1.0, shore_v)
				_tri(st, sap, m_ab, sbp, sac, c_ab, sbc, 0.42, 1.0, 0.42, shore_v)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, ua: float, ub: float, uc: float, shore: float) -> void:
	st.set_color(ca)
	st.set_uv(Vector2(ua, shore))
	st.add_vertex(a)
	st.set_color(cb)
	st.set_uv(Vector2(ub, shore))
	st.add_vertex(b)
	st.set_color(cc)
	st.set_uv(Vector2(uc, shore))
	st.add_vertex(c)


static func _water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			if not _water(id):
				continue
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var land_n := 0
			for d in HexGrid.DIRS:
				var n: Vector2i = ax + d
				if DataDB.in_bounds(n.x, n.y) and not _water(DataDB.terrain_id(n.x, n.y)):
					land_n += 1
			var shore_amt := float(land_n) / 6.0
			var lake := 0.0
			if id == "lake":
				shore_amt = maxf(shore_amt, 0.72)
				lake = 1.0
			var y := -0.02
			var cp := Vector3(center.x, y, center.y)
			var wet := Color(shore_amt, lake, 0.55)
			for i in 6:
				var ang0 := deg_to_rad(60.0 * float(i) - 30.0)
				var ang1 := deg_to_rad(60.0 * float(i + 1) - 30.0)
				var a := Vector3(center.x + cos(ang0) * HexGrid.SIZE * 1.02, y, center.y + sin(ang0) * HexGrid.SIZE * 1.02)
				var b := Vector3(center.x + cos(ang1) * HexGrid.SIZE * 1.02, y, center.y + sin(ang1) * HexGrid.SIZE * 1.02)
				_tri(st, cp, a, b, wet, wet, wet, 0.0, 0.0, 0.0, shore_amt)
	st.generate_normals()
	return st.commit()


static func _ribbon_mesh(rivers: bool, heights: Dictionary, colors: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seen := {}
	if rivers:
		for key_v in DataDB.river_masks.keys():
			var key: Vector2i = key_v
			var masks: Array = DataDB.river_masks[key]
			for i in 6:
				var bit := 1 << i
				var great := (int(masks[1]) & bit) != 0
				var minor := (int(masks[0]) & bit) != 0
				if not great and not minor:
					continue
				var nb: Vector2i = key + HexGrid.DIRS[i]
				var silt: float = 0.42 if great else 0.12
				var width: float = 3.6 if great else 1.45
				_add_ribbon(st, key, nb, width, Color(0.25, 0.55, silt, 1.0), 0.1, heights, colors)
	else:
		for row in DataDB.height:
			for col in DataDB.width:
				var ax := HexGrid.axial_from_offset(col, row)
				var owner := DataDB.owner_id(ax.x, ax.y)
				if owner == "":
					continue
				var tid := DataDB.terrain_id(ax.x, ax.y)
				if _water(tid):
					continue
				for i in 6:
					var nb: Vector2i = ax + HexGrid.DIRS[i]
					var o2 := ""
					if DataDB.in_bounds(nb.x, nb.y):
						o2 = DataDB.owner_id(nb.x, nb.y)
					if o2 == owner:
						continue
					var mark := _edge_key(ax, nb)
					if seen.has(mark):
						continue
					seen[mark] = true
					var fc := DataDB.color_of(str(DataDB.faction(owner).get("color", "ffffff")))
					fc.a = 0.85
					_add_ribbon(st, ax, nb, 0.42, fc, 0.16, heights, colors)
	st.generate_normals()
	return st.commit()


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]


static func _edge_y(a: Vector2i, b: Vector2i, heights: Dictionary, colors: Dictionary) -> float:
	var dir := b - a
	var idx := -1
	for i in HexGrid.DIRS.size():
		if HexGrid.DIRS[i] == dir:
			idx = i
			break
	if idx < 0 or not heights.has(a):
		return float(heights.get(a, 0.4))
	var c0: Dictionary = _corner_sample(a, idx, heights, colors)
	var c1: Dictionary = _corner_sample(a, (idx + 1) % 6, heights, colors)
	return (c0.p.y + c1.p.y) * 0.5


static func _add_ribbon(st: SurfaceTool, a: Vector2i, b: Vector2i, width: float, color: Color, lift: float, heights: Dictionary, colors: Dictionary) -> void:
	var pa := HexGrid.axial_to_pixel(a.x, a.y)
	var pb := HexGrid.axial_to_pixel(b.x, b.y)
	var dir := pb - pa
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var mid := pa + dir * (HexGrid.SIZE * sqrt(3.0) / 2.0)
	var tang := Vector2(-dir.y, dir.x) * HexGrid.SIZE * 0.5
	var y := _edge_y(a, b, heights, colors) + lift
	var p0 := Vector3(mid.x - tang.x, y, mid.y - tang.y)
	var p1 := Vector3(mid.x + tang.x, y, mid.y + tang.y)
	var side := Vector3(-dir.y, 0, dir.x).normalized() * width
	var a0 := p0 - side
	var a1 := p0 + side
	var b0 := p1 - side
	var b1 := p1 + side
	_tri_uv(st, a0, b0, b1, color, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	_tri_uv(st, a0, b1, a1, color, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	st.set_color(color)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_color(color)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_color(color)
	st.set_uv(uc)
	st.add_vertex(c)


static func _near_peak(ax: Vector2i) -> bool:
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if not DataDB.in_bounds(n.x, n.y):
			continue
		var id := DataDB.terrain_id(n.x, n.y)
		if id == "mountain" or id == "alpine" or id == "hill":
			return true
	return false


static func _tree_lists(heights: Dictionary) -> Dictionary:
	var pines: Array = []
	var broads: Array = []
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			if id != "forest" and id != "marsh":
				continue
			var count: int = 6 if id == "forest" else 3
			var pine := ax.y < 30 or _near_peak(ax)
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var y := float(heights[ax])
			for k in count:
				var ang := float(k) * 2.17 + float(ax.x) * 0.71 + float(ax.y) * 0.19
				var rad := 2.4 + float(k) * 1.15
				var p := Vector3(center.x + cos(ang) * rad, y, center.y + sin(ang) * rad)
				var s := (0.9 + 0.45 * absf(sin(float(ax.x * 3 + k) * 1.3))) * 1.25
				var tall: float = 1.15 if pine else 0.9
				var basis := Basis(Vector3.UP, ang).scaled(Vector3(s, s * tall, s))
				var leaf := Color("1e5c34")
				if pine:
					leaf = Color("163e28").lerp(Color("2a6a40"), 0.5 + 0.5 * sin(ang))
				else:
					leaf = Color("2f7a32").lerp(Color("6a9a38"), 0.5 + 0.5 * sin(ang * 1.4))
				var item := {"t": Transform3D(basis, p), "trunk": Color("6a4630").lerp(Color("4a3020"), 0.5 + 0.5 * sin(ang)), "leaf": leaf}
				if pine:
					pines.append(item)
				else:
					broads.append(item)
	return {"pines": pines, "broads": broads}


static func _trunk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.18, 1.05, 5, Color.WHITE, 0.0)
	st.generate_normals()
	return st.commit()


static func _pine_leaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 0.95, 1.7, 6, Color.WHITE, 0.85)
	_cone(st, 0.7, 1.35, 6, Color.WHITE, 1.85)
	_cone(st, 0.42, 1.0, 6, Color.WHITE, 2.7)
	st.generate_normals()
	return st.commit()


static func _broad_leaf() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_cone(st, 1.35, 1.55, 7, Color.WHITE, 0.85)
	_cone(st, 1.0, 1.25, 7, Color.WHITE, 1.7)
	st.generate_normals()
	return st.commit()


static func _cone(st: SurfaceTool, radius: float, height: float, sides: int, color: Color, y0: float) -> void:
	var tip := Vector3(0, y0 + height, 0)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := Vector3(cos(a0) * radius, y0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, y0, sin(a1) * radius)
		_tri(st, tip, p1, p0, color, color, color, 0, 0, 0, 0)


static func unit_mesh(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloth := Color(1, 1, 1)
	if kind == "cavalry" or kind == "heavy":
		_box(st, Vector3(0, 1.15, 0), Vector3(1.5, 0.7, 0.55), cloth)
		_box(st, Vector3(0.95, 1.45, 0), Vector3(0.45, 0.35, 0.28), cloth)
		_box(st, Vector3(1.35, 1.55, 0), Vector3(0.28, 0.22, 0.2), cloth)
		for x in [-0.45, 0.4]:
			for z in [-0.22, 0.22]:
				_box(st, Vector3(x, 0.45, z), Vector3(0.16, 0.5, 0.16), cloth)
		_box(st, Vector3(-0.15, 2.15, 0), Vector3(0.32, 0.42, 0.28), cloth)
		_box(st, Vector3(-0.15, 2.6, 0), Vector3(0.22, 0.22, 0.22), cloth)
		if kind == "heavy":
			_box(st, Vector3(0, 1.55, 0), Vector3(1.15, 0.18, 0.7), cloth)
	elif kind == "archer":
		_person(st, cloth)
		_box(st, Vector3(0.35, 1.7, 0.2), Vector3(0.55, 0.1, 0.1), cloth)
	else:
		_person(st, cloth)
		_box(st, Vector3(0.15, 1.2, 0), Vector3(0.08, 1.3, 0.08), cloth)
	st.generate_normals()
	return st.commit()


static func _person(st: SurfaceTool, color: Color) -> void:
	_box(st, Vector3(0, 1.35, 0), Vector3(0.42, 0.55, 0.28), color)
	_box(st, Vector3(0, 2.05, 0), Vector3(0.26, 0.26, 0.26), color)
	_box(st, Vector3(-0.16, 0.5, 0), Vector3(0.14, 0.55, 0.14), color)
	_box(st, Vector3(0.16, 0.5, 0), Vector3(0.14, 0.55, 0.14), color)


static func _box(st: SurfaceTool, center: Vector3, half: Vector3, color: Color) -> void:
	var signs := [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]
	var pts: Array[Vector3] = []
	for s in signs:
		pts.append(center + Vector3(s.x * half.x, s.y * half.y, s.z * half.z))
	var faces := [
		[0, 1, 2, 3],
		[4, 6, 5, 7],
		[0, 4, 5, 1],
		[3, 2, 6, 7],
		[0, 3, 7, 4],
		[1, 5, 6, 2],
	]
	for f in faces:
		_tri(st, pts[f[0]], pts[f[1]], pts[f[2]], color, color, color, 0, 0, 0, 0)
		_tri(st, pts[f[0]], pts[f[2]], pts[f[3]], color, color, color, 0, 0, 0, 0)


static func house_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0.45, 0), Vector3(0.7, 0.45, 0.55), Color("f3e6c4"))
	# Two slopes of a tiled roof.
	_tri(st, Vector3(-0.85, 0.9, -0.7), Vector3(0.85, 0.9, -0.7), Vector3(0, 1.45, 0), Color("a34732"), Color("a34732"), Color("c45a3a"), 0, 0, 0, 0)
	_tri(st, Vector3(0.85, 0.9, 0.7), Vector3(-0.85, 0.9, 0.7), Vector3(0, 1.45, 0), Color("a34732"), Color("a34732"), Color("c45a3a"), 0, 0, 0, 0)
	_tri(st, Vector3(-0.85, 0.9, 0.7), Vector3(-0.85, 0.9, -0.7), Vector3(0, 1.45, 0), Color("8c3a28"), Color("8c3a28"), Color("a34732"), 0, 0, 0, 0)
	_tri(st, Vector3(0.85, 0.9, -0.7), Vector3(0.85, 0.9, 0.7), Vector3(0, 1.45, 0), Color("8c3a28"), Color("8c3a28"), Color("a34732"), 0, 0, 0, 0)
	st.generate_normals()
	return st.commit()


static func pagoda_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in 3:
		var y := 0.4 + float(tier) * 1.15
		var w := 0.85 - float(tier) * 0.18
		_box(st, Vector3(0, y, 0), Vector3(w * 0.45, 0.35, w * 0.45), Color("f4ead2"))
		var rw := w
		var ry := y + 0.45
		_tri(st, Vector3(-rw, ry, -rw), Vector3(rw, ry, -rw), Vector3(0, ry + 0.55, 0), Color("9c3b2c"), Color("9c3b2c"), Color("d06040"), 0, 0, 0, 0)
		_tri(st, Vector3(rw, ry, rw), Vector3(-rw, ry, rw), Vector3(0, ry + 0.55, 0), Color("9c3b2c"), Color("9c3b2c"), Color("d06040"), 0, 0, 0, 0)
		_tri(st, Vector3(-rw, ry, rw), Vector3(-rw, ry, -rw), Vector3(0, ry + 0.55, 0), Color("7d3024"), Color("7d3024"), Color("9c3b2c"), 0, 0, 0, 0)
		_tri(st, Vector3(rw, ry, -rw), Vector3(rw, ry, rw), Vector3(0, ry + 0.55, 0), Color("7d3024"), Color("7d3024"), Color("9c3b2c"), 0, 0, 0, 0)
	st.generate_normals()
	return st.commit()
