class_name TerrainFactory
extends RefCounted

## Original low-poly terrain. Heights, colors, and meshes are authored here,
## not taken from any existing game.

const PALETTE := {
	"plain": "a08c3c",
	"grass": "3f8a38",
	"hill": "8a6840",
	"mountain": "6e6258",
	"alpine": "5c656e",
	"loess": "c46228",
	"forest": "2c6234",
	"marsh": "4a7a58",
	"desert": "d4a258",
	"erg": "e6c078",
	"rice": "3d9a55",
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
			colors[ax] = _tint(id, ax)
			shore[ax] = _touches_water(ax)
	colors = _smooth_colors(colors)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax2 := HexGrid.axial_from_offset(col, row)
			var id2 := DataDB.terrain_id(ax2.x, ax2.y)
			if _water(id2):
				heights[ax2] = float(HEIGHTS.get(id2, -1.0))
			else:
				var center := HexGrid.axial_to_pixel(ax2.x, ax2.y)
				heights[ax2] = _world_height(center)
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
		"tufts": woods.tufts,
		"rocks": woods.rocks,
		"tuft_mesh": _tuft_mesh(),
		"rock_mesh": _rock_mesh(),
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


static func _hash2(ix: int, iz: int) -> float:
	var s := sin(float(ix) * 127.1 + float(iz) * 311.7) * 43758.5453
	return s - floor(s)


static func _vnoise(x: float, z: float) -> float:
	var x0 := int(floor(x))
	var z0 := int(floor(z))
	var fx := x - float(x0)
	var fz := z - float(z0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := lerpf(_hash2(x0, z0), _hash2(x0 + 1, z0), fx)
	var b := lerpf(_hash2(x0, z0 + 1), _hash2(x0 + 1, z0 + 1), fx)
	return lerpf(a, b, fz)


static func _fbm(x: float, z: float) -> float:
	var a := 0.0
	var f := 1.0
	var w := 0.55
	var s := 0.0
	for _i in 3:
		a += _vnoise(x * f, z * f) * w
		s += w
		f *= 2.05
		w *= 0.5
	return a / s


static func _ridged(x: float, z: float) -> float:
	return 1.0 - absf(_fbm(x, z) * 2.0 - 1.0)


static func _relief(id: String, p: Vector2) -> float:
	var x := p.x
	var z := p.y
	var n := _fbm(x * 0.045, z * 0.045)
	if id == "alpine" or id == "mountain":
		# North-south ridges so a chain of mountain hexes reads as one range.
		var ridge := pow(_ridged(x * 0.11, z * 0.028), 1.35)
		var amp := 15.5 if id == "alpine" else 11.0
		return 1.6 + ridge * amp + _fbm(x * 0.18, z * 0.18) * 1.2
	if id == "hill":
		return 1.1 + _fbm(x * 0.09, z * 0.09) * 2.6
	if id == "loess":
		var field := _fbm(x * 0.05, z * 0.035)
		var terraced: float = floor(field * 5.0) / 5.0
		var gully := pow(1.0 - _ridged(x * 0.14, z * 0.04), 2.4)
		return 0.7 + terraced * 3.2 - gully * 1.15
	if id == "erg":
		var dune := sin(x * 0.28 + z * 0.04) * cos(z * 0.16)
		return 0.55 + dune * 0.9 + n * 0.15
	if id == "desert":
		return 0.4 + sin(x * 0.35 + z * 0.08) * 0.16 + n * 0.12
	if id == "forest":
		return 0.5 + n * 0.28
	if id == "marsh":
		return 0.12 + n * 0.05
	if id == "rice":
		return 0.22 + n * 0.04
	if id == "grass":
		return 0.42 + n * 0.22
	return 0.36 + n * 0.12


static func _world_height(p: Vector2) -> float:
	var ax := HexGrid.pixel_to_axial(p)
	var h := 0.0
	var wsum := 0.0
	var reach := HexGrid.SIZE * 1.15
	for dz in range(-1, 2):
		for dq in range(-1, 2):
			var c := Vector2i(ax.x + dq, ax.y + dz)
			if not DataDB.in_bounds(c.x, c.y):
				continue
			var center := HexGrid.axial_to_pixel(c.x, c.y)
			var dist := p.distance_to(center)
			var w := maxf(0.0, reach - dist)
			if w <= 0.0:
				continue
			w *= w
			var id := DataDB.terrain_id(c.x, c.y)
			var hh := 0.02 if _water(id) else _relief(id, p)
			h += hh * w
			wsum += w
	if wsum <= 0.001:
		return 0.3
	return h / wsum


static func _land_mesh(heights: Dictionary, colors: Dictionary, shore: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_div := 4
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if _water(DataDB.terrain_id(ax.x, ax.y)):
				continue
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var cc: Color = colors[ax]
			var shore_v := 1.0 if bool(shore[ax]) else 0.0
			for edge in 6:
				var a0 := deg_to_rad(60.0 * float(edge) - 30.0)
				var a1 := deg_to_rad(60.0 * float(edge + 1) - 30.0)
				var off_a := Vector2(cos(a0), sin(a0)) * HexGrid.SIZE
				var off_b := Vector2(cos(a1), sin(a1)) * HexGrid.SIZE
				var pts: Array = []
				for s in n_div + 1:
					var row_pts: Array = []
					var u := float(s) / float(n_div)
					for k in s + 1:
						var v := 0.0 if s == 0 else float(k) / float(s)
						var p2: Vector2 = center + off_a.lerp(off_b, v) * u
						var sample_h := _world_height(p2)
						row_pts.append(Vector3(p2.x, sample_h, p2.y))
					pts.append(row_pts)
				for s in n_div:
					for k in s + 1:
						var p00: Vector3 = pts[s][k]
						var p10: Vector3 = pts[s + 1][k]
						var p11: Vector3 = pts[s + 1][k + 1]
						var e0 := float(s) / float(n_div)
						var e1 := float(s + 1) / float(n_div)
						_tri(st, p00, p10, p11, cc, cc, cc, e0, e1, e1, shore_v)
						if k < s:
							var p01: Vector3 = pts[s][k + 1]
							_tri(st, p00, p11, p01, cc, cc, cc, e0, e1, e0, shore_v)
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
				var silt: float = 0.72 if great else 0.28
				var width: float = 6.4 if great else 2.35
				_add_ribbon(st, key, nb, width, Color(0.62, 0.48, 0.22, silt), 0.08, heights, colors)
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


static func _edge_y(a: Vector2i, b: Vector2i, _heights: Dictionary, _colors: Dictionary) -> float:
	var pa := HexGrid.axial_to_pixel(a.x, a.y)
	var pb := HexGrid.axial_to_pixel(b.x, b.y)
	return _world_height((pa + pb) * 0.5)


static func _add_ribbon(st: SurfaceTool, a: Vector2i, b: Vector2i, width: float, color: Color, lift: float, _heights: Dictionary, _colors: Dictionary) -> void:
	var pa := HexGrid.axial_to_pixel(a.x, a.y)
	var pb := HexGrid.axial_to_pixel(b.x, b.y)
	var dir := pb - pa
	if dir.length() < 0.001:
		return
	dir = dir.normalized()
	var mid := pa + dir * (HexGrid.SIZE * sqrt(3.0) / 2.0)
	var tang := Vector2(-dir.y, dir.x) * HexGrid.SIZE * 0.5
	var side2 := Vector2(-dir.y, dir.x).normalized() * width
	var q0 := mid - tang
	var q1 := mid + tang
	var corners := [q0 - side2, q1 - side2, q1 + side2, q0 + side2]
	var pts: Array[Vector3] = []
	for q in corners:
		pts.append(Vector3(q.x, _world_height(q) + lift, q.y))
	_tri_uv(st, pts[0], pts[1], pts[2], color, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1))
	_tri_uv(st, pts[0], pts[2], pts[3], color, Vector2(0, 0), Vector2(1, 1), Vector2(0, 1))


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
	var tufts: Array = []
	var rocks: Array = []
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var y := float(heights.get(ax, 0.4))
			if id == "forest" or id == "marsh":
				var count: int = 8 if id == "forest" else 4
				var pine := ax.y < 30 or _near_peak(ax)
				for k in count:
					var ang := float(k) * 2.17 + float(ax.x) * 0.71 + float(ax.y) * 0.19
					var rad := 3.1 + float(k) * 1.35
					var p := Vector3(center.x + cos(ang) * rad, y, center.y + sin(ang) * rad)
					var s := (0.95 + 0.4 * absf(sin(float(ax.x * 3 + k) * 1.3))) * 2.5
					var tall: float = 1.2 if pine else 0.95
					var basis := Basis(Vector3.UP, ang).scaled(Vector3(s, s * tall, s))
					var leaf := Color("2a6a40")
					if pine:
						leaf = Color("163e28").lerp(Color("2a6a40"), 0.5 + 0.5 * sin(ang))
					else:
						leaf = Color("2f7a32").lerp(Color("6a9a38"), 0.5 + 0.5 * sin(ang * 1.4))
					var item := {"t": Transform3D(basis, p), "trunk": Color("6a4630").lerp(Color("4a3020"), 0.5 + 0.5 * sin(ang)), "leaf": leaf}
					if pine:
						pines.append(item)
					else:
						broads.append(item)
			var tuft_n := 0
			if id == "grass" or id == "plain" or id == "forest":
				tuft_n = 3
			elif id == "loess" or id == "rice" or id == "hill" or id == "desert":
				tuft_n = 2
			for k2 in tuft_n:
				var ang2 := float(k2) * 2.4 + float(ax.x) * 0.37
				var rad2 := 4.0 + float(k2) * 3.2
				var p2 := Vector3(center.x + cos(ang2) * rad2, y, center.y + sin(ang2) * rad2)
				var s2 := 1.8 + absf(sin(ang2)) * 1.1
				var tint := Color("3c8a34")
				if id == "loess":
					tint = Color("c4a05a")
				elif id == "desert":
					tint = Color("d2b070")
				elif id == "rice":
					tint = Color("4aaa58")
				tufts.append({"t": Transform3D(Basis(Vector3.UP, ang2).scaled(Vector3(s2, s2, s2)), p2), "color": tint})
			var rock_n := 0
			if id == "mountain" or id == "alpine":
				rock_n = 3
			elif id == "hill" or id == "erg":
				rock_n = 2
			for k3 in rock_n:
				var ang3 := float(k3) * 1.9 + float(ax.y) * 0.41
				var rad3 := 5.0 + float(k3) * 2.8
				var p3 := Vector3(center.x + cos(ang3) * rad3, y, center.y + sin(ang3) * rad3)
				var s3 := 1.6 + absf(sin(ang3 * 1.3)) * 1.4
				if id == "alpine" or id == "mountain":
					s3 *= 1.45
				var rock_col := Color("6e675e")
				if id == "erg":
					rock_col = Color("c4a06a")
				rocks.append({"t": Transform3D(Basis(Vector3.UP, ang3).scaled(Vector3(s3, s3 * 0.8, s3)), p3), "color": rock_col})
	return {"pines": pines, "broads": broads, "tufts": tufts, "rocks": rocks}


static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 3:
		var ang := float(i) * 2.15
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var base := dir * 0.12
		var tip := base + Vector3(dir.x * 0.18, 0.9, dir.z * 0.18)
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.07
		_tri(st, base - side, base + side, tip, Color.WHITE, Color.WHITE, Color.WHITE, 0, 0, 0, 0)
	st.generate_normals()
	return st.commit()


static func _rock_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3(0, 0.32, 0), Vector3(0.55, 0.32, 0.4), Color.WHITE)
	_box(st, Vector3(0.42, 0.2, 0.12), Vector3(0.28, 0.2, 0.24), Color.WHITE)
	st.generate_normals()
	return st.commit()


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
	_box(st, Vector3(-0.55, 0.5, 0), Vector3(0.08, 0.5, 0.55), Color("8a5a3a"))
	_tri(st, Vector3(-0.85, 0.9, -0.7), Vector3(0.85, 0.9, -0.7), Vector3(0, 1.45, 0), Color("6a6e74"), Color("6a6e74"), Color("8a9098"), 0, 0, 0, 0)
	_tri(st, Vector3(0.85, 0.9, 0.7), Vector3(-0.85, 0.9, 0.7), Vector3(0, 1.45, 0), Color("6a6e74"), Color("6a6e74"), Color("8a9098"), 0, 0, 0, 0)
	_tri(st, Vector3(-0.85, 0.9, 0.7), Vector3(-0.85, 0.9, -0.7), Vector3(0, 1.45, 0), Color("5c6168"), Color("5c6168"), Color("6a6e74"), 0, 0, 0, 0)
	_tri(st, Vector3(0.85, 0.9, -0.7), Vector3(0.85, 0.9, 0.7), Vector3(0, 1.45, 0), Color("5c6168"), Color("5c6168"), Color("6a6e74"), 0, 0, 0, 0)
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
		_tri(st, Vector3(-rw, ry, -rw), Vector3(rw, ry, -rw), Vector3(0, ry + 0.55, 0), Color("6e7580"), Color("6e7580"), Color("9aa3ad"), 0, 0, 0, 0)
		_tri(st, Vector3(rw, ry, rw), Vector3(-rw, ry, rw), Vector3(0, ry + 0.55, 0), Color("6e7580"), Color("6e7580"), Color("9aa3ad"), 0, 0, 0, 0)
		_tri(st, Vector3(-rw, ry, rw), Vector3(-rw, ry, -rw), Vector3(0, ry + 0.55, 0), Color("5a6168"), Color("5a6168"), Color("6e7580"), 0, 0, 0, 0)
		_tri(st, Vector3(rw, ry, -rw), Vector3(rw, ry, rw), Vector3(0, ry + 0.55, 0), Color("5a6168"), Color("5a6168"), Color("6e7580"), 0, 0, 0, 0)
	st.generate_normals()
	return st.commit()
