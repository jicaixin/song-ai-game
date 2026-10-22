class_name TerrainFactory
extends RefCounted

## Original low-poly terrain. Heights, colors, and meshes are authored here,
## not taken from any existing game.

const PALETTE := {
	"plain": "6f7348",
	"grass": "8a7d58",
	"hill": "7a6248",
	"mountain": "5c574f",
	"alpine": "6c766c",
	"loess": "b08a62",
	"forest": "3d6844",
	"marsh": "4e6e5a",
	"desert": "c6b79a",
	"erg": "d0c2a4",
	"rice": "4a7644",
	"lake": "3a6878",
	"sea": "1c4664",
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

# Mask bit i follows DIRS[i]. The geometric edge whose midpoint lies on that
# neighbour is not edge i: corners sit at 60°·k−30°, so edge k faces 60°·k.
const RIVER_DIR_EDGE := [0, 5, 4, 3, 2, 1]

static var _river_buckets: Dictionary = {}
static var _river_courses: Array = []


static func build() -> Dictionary:
	_prepare_rivers()
	var heights := {}
	var colors := {}
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			colors[ax] = _tint(id, ax)
	colors = _smooth_colors(colors)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax2 := HexGrid.axial_from_offset(col, row)
			var id2 := DataDB.terrain_id(ax2.x, ax2.y)
			if _water(id2):
				heights[ax2] = float(HEIGHTS.get(id2, -1.0))
			else:
				var center := HexGrid.axial_to_pixel(ax2.x, ax2.y)
				heights[ax2] = _surface_height(center)
	var land := _land_mesh(heights, colors)
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
		"features": _feature_list(heights),
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


static func swatch(id: String) -> Color:
	return Color(str(PALETTE.get(id, "7a7358")))


static func _tint(id: String, ax: Vector2i) -> Color:
	var c := swatch(id)
	# River valleys and the rice south read greener than the loess and steppe.
	if id == "plain" and _hex_has_river(ax):
		c = c.lerp(Color("4a7340"), 0.62)
	elif id == "rice":
		c = c.lerp(Color("3d6e3e"), 0.28)
		if _hex_has_river(ax):
			c = c.lerp(Color("347842"), 0.22)
	elif id == "forest":
		c = c.lerp(Color("2f6238"), 0.18)
	var n := sin(float(ax.x) * 0.9 + float(ax.y) * 1.4) * 0.015
	return Color(c.r + n, c.g + n * 0.85, c.b + n * 0.35)


static func _hex_has_river(ax: Vector2i) -> bool:
	var masks = DataDB.river_masks.get(ax, null)
	if masks == null:
		return false
	return int(masks[0]) != 0 or int(masks[1]) != 0


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
		out[ax] = own.lerp(acc / n, 0.22)
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
	# Mountain, hill, and loess meshes carry the relief. The ground under them
	# stays a low pad so the skirt meets the terrain instead of a knife ridge.
	if id == "alpine" or id == "mountain" or id == "hill" or id == "loess":
		return 0.46 + n * 0.28
	if id == "erg":
		var dune := sin(x * 0.28 + z * 0.04) * cos(z * 0.16)
		return 0.55 + dune * 0.9 + n * 0.15
	if id == "desert":
		return 0.4 + sin(x * 0.35 + z * 0.08) * 0.16 + n * 0.12
	if id == "forest":
		return 0.48 + n * 0.32
	if id == "marsh":
		return 0.12 + n * 0.06
	if id == "rice":
		return 0.22 + n * 0.08
	if id == "grass":
		return 0.4 + n * 0.85 + sin(x * 0.1) * cos(z * 0.08) * 0.16
	return 0.38 + n * 0.8 + sin(x * 0.11) * cos(z * 0.09) * 0.18


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
			if _water(id):
				continue
			h += _relief(id, p) * w
			wsum += w
	if wsum <= 0.001:
		return 0.3
	return h / wsum


static func _biome_color(p: Vector2, colors: Dictionary) -> Color:
	# Low-frequency warp so the blend line wanders off the hex edge.
	var warp := Vector2(
		(_vnoise(p.x * 0.018, p.y * 0.018) - 0.5) * HexGrid.SIZE * 1.7,
		(_vnoise(p.x * 0.018 + 8.0, p.y * 0.018 + 4.0) - 0.5) * HexGrid.SIZE * 1.7
	)
	var q := p + warp
	var ax := HexGrid.pixel_to_axial(q)
	var acc := Color(0, 0, 0, 0)
	var wsum := 0.0
	var reach := HexGrid.SIZE * 2.15
	for dz in range(-1, 2):
		for dq in range(-1, 2):
			var c := Vector2i(ax.x + dq, ax.y + dz)
			if not colors.has(c):
				continue
			if _water(DataDB.terrain_id(c.x, c.y)):
				continue
			var center := HexGrid.axial_to_pixel(c.x, c.y)
			var dist := q.distance_to(center)
			var w := maxf(0.0, 1.0 - dist / reach)
			if w <= 0.0:
				continue
			w *= w
			var col: Color = colors[c]
			acc += col * w
			wsum += w
	var base := Color("8a7a58")
	if wsum <= 0.001:
		if colors.has(ax):
			base = colors[ax]
	else:
		base = acc / wsum
	var patch := _vnoise(p.x * 0.055, p.y * 0.055)
	var fine := _vnoise(p.x * 0.2, p.y * 0.2)
	var dirt := Color(base.r * 0.76, base.g * 0.68, base.b * 0.56)
	var k := clampf((patch - 0.62) / 0.24, 0.0, 1.0)
	base = base.lerp(dirt, k * 0.2)
	var scale := 0.9 + fine * 0.12
	return Color(base.r * scale, base.g * scale, base.b * scale, 1.0)


static func _touches_land(ax: Vector2i) -> bool:
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and not _water(DataDB.terrain_id(n.x, n.y)):
			return true
	return false


static func _touches_water(ax: Vector2i) -> bool:
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and _water(DataDB.terrain_id(n.x, n.y)):
			return true
	return false


static func _coast_field(p: Vector2) -> float:
	var home := HexGrid.pixel_to_axial(p)
	if not DataDB.in_bounds(home.x, home.y):
		return 0.0
	if not _water(DataDB.terrain_id(home.x, home.y)) and not _touches_water(home):
		return 0.0
	# Warp the sample so the land/water contour leaves the hex edge and rounds the corners.
	var warp := Vector2(
		(_vnoise(p.x * 0.028 + 4.0, p.y * 0.028) - 0.5) * HexGrid.SIZE * 1.15,
		(_vnoise(p.x * 0.026, p.y * 0.030 + 6.0) - 0.5) * HexGrid.SIZE * 1.15
	)
	warp += Vector2(
		(_vnoise(p.x * 0.07 + 1.5, p.y * 0.07) - 0.5) * HexGrid.SIZE * 0.42,
		(_vnoise(p.x * 0.07, p.y * 0.07 + 2.4) - 0.5) * HexGrid.SIZE * 0.42
	)
	var q := p + warp
	var ax := HexGrid.pixel_to_axial(q)
	var water_w := 0.0
	var land_w := 0.0
	var reach := HexGrid.SIZE * 2.35
	for dz in range(-1, 2):
		for dq in range(-1, 2):
			var c := Vector2i(ax.x + dq, ax.y + dz)
			if not DataDB.in_bounds(c.x, c.y):
				continue
			var center := HexGrid.axial_to_pixel(c.x, c.y)
			var dist := q.distance_to(center)
			var w := maxf(0.0, 1.0 - dist / reach)
			if w <= 0.0:
				continue
			w *= w
			if _water(DataDB.terrain_id(c.x, c.y)):
				water_w += w
			else:
				land_w += w
	if water_w + land_w <= 0.001:
		return 0.0
	return water_w / (water_w + land_w)


static func _dist_to_seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _river_sink(p: Vector2) -> float:
	var ax := HexGrid.pixel_to_axial(p)
	if not _river_buckets.has(ax):
		return 0.0
	var best := 0.0
	var bucket: Array = _river_buckets[ax]
	for seg_v in bucket:
		var seg: Dictionary = seg_v
		var a: Vector2 = seg.a
		var b: Vector2 = seg.b
		var ab := b - a
		var len2 := ab.length_squared()
		var along := 0.0
		if len2 > 0.001:
			along = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		var dist := p.distance_to(a + ab * along)
		var half := lerpf(float(seg.wa), float(seg.wb), along)
		var radius := half + 5.6
		var depth := 0.17 + 0.16 * clampf(half / 7.2, 0.0, 1.0)
		var bed := 1.0 - smoothstep(radius * 0.56, radius, dist)
		best = maxf(best, depth * bed)
	return best


static func _shaped_height(p: Vector2, coast: float) -> float:
	var h := _world_height(p)
	# Wide ramp so the bank leans into the water instead of ending in a cliff.
	h = lerpf(h, -0.7, smoothstep(0.08, 0.52, coast))
	h -= _river_sink(p)
	return h


static func _surface_height(p: Vector2) -> float:
	return _shaped_height(p, _coast_field(p))


static func _hn(q: int, r: int, m: int) -> int:
	return posmod(q * 17 + r * 31 + q * r * 3, m)


static func _mix(q: int, r: int, m: int) -> int:
	# _hn stripes along a latitude. This one does not, so loess pieces scatter.
	var n: int = (q * 73856093) ^ (r * 19349663) ^ ((q + 13) * (r + 7) * 83492791)
	return absi(n) % m


static func _is_peak(id: String) -> bool:
	return id == "mountain" or id == "alpine"


static func _city_here(ax: Vector2i) -> bool:
	return not DataDB.city_at_hex(ax.x, ax.y).is_empty()


static func _peak_dirs(ax: Vector2i) -> Array:
	var dirs: Array = []
	for i in 6:
		var n: Vector2i = ax + HexGrid.DIRS[i]
		if DataDB.in_bounds(n.x, n.y) and _is_peak(DataDB.terrain_id(n.x, n.y)):
			dirs.append(i)
	return dirs


static func _best_pair(dirs: Array) -> Vector2i:
	# Prefer a straight spine (opposite edges), then a 120° bend. A 60° pair
	# has no matching piece.
	var best_score := 0
	var best := Vector2i(-1, -1)
	for i in dirs.size():
		for j in range(i + 1, dirs.size()):
			var a := int(dirs[i])
			var b := int(dirs[j])
			var diff := (b - a) % 6
			var score := 0
			if diff == 3:
				score = 3
			elif diff == 2 or diff == 4:
				score = 2
			if score > best_score:
				best_score = score
				best = Vector2i(a, b)
	return best


static func _piece_for_pair(a: int, b: int) -> Dictionary:
	# Kit edge j matches DIRS[j]. Godot yaw of j*60° swings edge 0 onto DIRS[j].
	# The bend's edges are 0 and 2, so yaw follows whichever end lands on edge 0.
	var lo := a
	var hi := b
	if hi < lo:
		lo = b
		hi = a
	var diff := (hi - lo) % 6
	if diff == 3:
		return {"mesh": "mountain_ridge", "yaw": lo * 60}
	if diff == 2:
		return {"mesh": "mountain_ridge_bend", "yaw": lo * 60}
	if diff == 4:
		return {"mesh": "mountain_ridge_bend", "yaw": hi * 60}
	return {"mesh": "", "yaw": 0}


static func _massif_name(ax: Vector2i, id: String) -> String:
	if id == "alpine" or ax.y <= 20 or ax.y >= 31:
		return "mountain_a"
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and DataDB.terrain_id(n.x, n.y) == "alpine":
			return "mountain_a"
	if _hn(ax.x, ax.y, 2) == 0:
		return "mountain_b"
	return "mountain_c"


static func _loess_belt(ax: Vector2i) -> bool:
	if ax.x >= 8 and ax.x <= 24 and ax.y >= 18 and ax.y <= 34:
		return true
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and DataDB.terrain_id(n.x, n.y) == "loess":
			return true
	return false


static func _beside_peak(ax: Vector2i) -> bool:
	for d in HexGrid.DIRS:
		var n: Vector2i = ax + d
		if DataDB.in_bounds(n.x, n.y) and _is_peak(DataDB.terrain_id(n.x, n.y)):
			return true
	return false


static func _forest_neighbors(ax: Vector2i) -> int:
	var n := 0
	for d in HexGrid.DIRS:
		var nb: Vector2i = ax + d
		if DataDB.in_bounds(nb.x, nb.y) and DataDB.terrain_id(nb.x, nb.y) == "forest":
			n += 1
	return n


static func _near_north_city(ax: Vector2i) -> bool:
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var cr := int(city.r)
		if cr > 34:
			continue
		var there := Vector2i(int(city.q), cr)
		var dist := HexGrid.distance(ax, there)
		if dist == 1:
			return true
	return false


static func _farm_targets() -> Dictionary:
	# One or two plain hexes beside each northern city, not a ring of six.
	var picked := {}
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if int(city.r) > 34:
			continue
		var there := Vector2i(int(city.q), int(city.r))
		var cands: Array = []
		for dir_i in 6:
			var n: Vector2i = there + HexGrid.DIRS[dir_i]
			if not DataDB.in_bounds(n.x, n.y) or _city_here(n):
				continue
			var tid := DataDB.terrain_id(n.x, n.y)
			if tid != "plain" and tid != "grass":
				continue
			var score := _hn(n.x, n.y, 17)
			if tid == "plain":
				score -= 20
			cands.append({"ax": n, "score": score})
		for ai in cands.size():
			var best := ai
			for bi in range(ai + 1, cands.size()):
				if int(cands[bi].score) < int(cands[best].score):
					best = bi
			if best != ai:
				var swap = cands[ai]
				cands[ai] = cands[best]
				cands[best] = swap
		var want := 2
		if _hn(there.x, there.y, 3) == 0:
			want = 1
		var got := 0
		for cand_v in cands:
			if got >= want:
				break
			var cand: Dictionary = cand_v
			picked[cand.ax] = true
			got += 1
	return picked


static func _push_feature(out: Array, ax: Vector2i, id: String, mesh: String, yaw_deg: int, heights: Dictionary, nudge: Vector2, drop: float = 0.0, sy: float = 1.0) -> void:
	var p := HexGrid.axial_to_pixel(ax.x, ax.y) + nudge
	var y := float(heights.get(ax, 0.4))
	if nudge != Vector2.ZERO:
		y = _surface_height(p)
	out.append({
		"q": ax.x,
		"r": ax.y,
		"id": id,
		"mesh": mesh,
		"x": p.x,
		"y": y - drop,
		"z": p.y,
		"yaw": deg_to_rad(float(yaw_deg)),
		"sy": sy,
	})


static func _feature_list(heights: Dictionary) -> Array:
	# One entry per kit piece. spawn_hex_features() groups them by mesh name.
	# Ridge pieces only keep a connector when the neighbour piece connects back,
	# so an open V profile never faces a slope.
	var out: Array = []
	var peaks: Array[Vector2i] = []
	var covered := {}
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if not _is_peak(DataDB.terrain_id(ax.x, ax.y)):
				continue
			peaks.append(ax)
			var dirs := _peak_dirs(ax)
			if _city_here(ax) or dirs.size() >= 6 or dirs.size() == 0:
				covered[ax] = []
			elif dirs.size() == 1:
				covered[ax] = [int(dirs[0])]
			else:
				var pair := _best_pair(dirs)
				if pair.x < 0:
					covered[ax] = []
				else:
					covered[ax] = [pair.x, pair.y]
	var mutual := {}
	for ax in peaks:
		var keep: Array = []
		var dirs_now: Array = covered[ax]
		for d_v in dirs_now:
			var d := int(d_v)
			var nb: Vector2i = ax + HexGrid.DIRS[d]
			var back := (d + 3) % 6
			var nb_dirs: Array = covered.get(nb, [])
			if nb_dirs.has(back):
				keep.append(d)
		mutual[ax] = keep
	for peak in peaks:
		if _city_here(peak):
			continue
		var id := DataDB.terrain_id(peak.x, peak.y)
		var keep2: Array = mutual[peak]
		var mesh := ""
		var yaw := 0
		if keep2.size() == 2:
			var spec: Dictionary = _piece_for_pair(int(keep2[0]), int(keep2[1]))
			mesh = str(spec.mesh)
			yaw = int(spec.yaw)
		elif keep2.size() == 1:
			mesh = "mountain_ridge_end"
			yaw = int(keep2[0]) * 60
		else:
			# Plateau interior is a solid mass. A mesh on every hex would bury the frame.
			if _peak_dirs(peak).size() >= 6 and _hn(peak.x, peak.y, 9) != 0:
				continue
			mesh = _massif_name(peak, id)
			yaw = _hn(peak.x, peak.y, 6) * 60
		if mesh == "":
			continue
		_push_feature(out, peak, id, mesh, yaw, heights, Vector2.ZERO)
	var farms := _farm_targets()
	for row2 in DataDB.height:
		for col2 in DataDB.width:
			var ax2 := HexGrid.axial_from_offset(col2, row2)
			if _city_here(ax2):
				continue
			var id2 := DataDB.terrain_id(ax2.x, ax2.y)
			var spin := _hn(ax2.x, ax2.y, 6) * 60
			if id2 == "loess" or (id2 == "hill" and _loess_belt(ax2)):
				# Most of the plateau stays flat ground. A minority keeps the
				# terrace mesh; the rest borrow a softer ochre hill.
				var roll := _mix(ax2.x, ax2.y, 10)
				var lyaw := _mix(ax2.x, ax2.y, 6) * 60
				if roll <= 3:
					_push_feature(out, ax2, id2, "hills_loess", lyaw, heights, Vector2.ZERO, 0.0, 0.7)
				elif roll <= 6:
					var ochre := "hills_a_loess" if _mix(ax2.x + 3, ax2.y, 2) == 0 else "hills_b_loess"
					_push_feature(out, ax2, id2, ochre, lyaw, heights, Vector2.ZERO, 0.0, 0.7)
			elif id2 == "hill":
				var hills := ["hills_a", "hills_b", "hills_c"]
				_push_feature(out, ax2, id2, str(hills[_hn(ax2.x, ax2.y, 3)]), spin, heights, Vector2.ZERO)
			elif id2 == "forest":
				var woods := "forest_sparse"
				if _forest_neighbors(ax2) >= 2:
					if ax2.y < 30 or _beside_peak(ax2):
						woods = "forest_conifer_a" if _hn(ax2.x, ax2.y, 2) == 0 else "forest_conifer_b"
					else:
						woods = "forest_mixed_a" if _hn(ax2.x, ax2.y, 2) == 0 else "forest_mixed_b"
				_push_feature(out, ax2, id2, woods, spin, heights, Vector2.ZERO)
			elif farms.has(ax2):
				_push_feature(out, ax2, id2, "farm_fields", spin, heights, Vector2.ZERO, 0.12, 1.0)
			elif id2 == "rice":
				_push_feature(out, ax2, id2, "rice_paddies", spin, heights, Vector2.ZERO)
			if id2 == "marsh" or (_hex_has_river(ax2) and (id2 == "plain" or id2 == "grass") and not _near_north_city(ax2) and _hn(ax2.x, ax2.y, 2) == 0):
				_push_feature(out, ax2, id2, "reeds", spin, heights, Vector2(4.2, -2.4))
			if id2 == "desert" or id2 == "erg":
				_push_feature(out, ax2, id2, "desert_scrub", spin, heights, Vector2.ZERO)
				_push_feature(out, ax2, id2, "desert_scrub", spin + 60, heights, Vector2(6.2, 3.4))
			elif id2 == "grass" and not _near_north_city(ax2):
				if _hn(ax2.x, ax2.y, 4) == 0:
					_push_feature(out, ax2, id2, "desert_scrub", spin, heights, Vector2(3.5, -2.0))
				elif _hn(ax2.x, ax2.y, 5) == 2:
					var rock := "rocks_a" if _hn(ax2.x, ax2.y, 2) == 0 else "rocks_b"
					_push_feature(out, ax2, id2, rock, spin, heights, Vector2(-3.0, 2.6))
	return out


static func _land_mesh(heights: Dictionary, colors: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_div := 4
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var tid := DataDB.terrain_id(ax.x, ax.y)
			var wet := _water(tid)
			# Open water has no land. Coastal water hexes are meshed so the bank can slope under the surface.
			if wet and not _touches_land(ax):
				continue
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			for edge in 6:
				var a0 := deg_to_rad(60.0 * float(edge) - 30.0)
				var a1 := deg_to_rad(60.0 * float(edge + 1) - 30.0)
				var off_a := Vector2(cos(a0), sin(a0)) * HexGrid.SIZE
				var off_b := Vector2(cos(a1), sin(a1)) * HexGrid.SIZE
				var pts: Array = []
				var cols: Array = []
				for s in n_div + 1:
					var row_pts: Array = []
					var row_cols: Array = []
					var u := float(s) / float(n_div)
					for k in s + 1:
						var v := 0.0 if s == 0 else float(k) / float(s)
						var p2: Vector2 = center + off_a.lerp(off_b, v) * u
						# Shared corners must be bit-identical or the index weld misses and a shading seam stays on the hex edge.
						p2 = Vector2(snapped(p2.x, 0.02), snapped(p2.y, 0.02))
						var coast := _coast_field(p2)
						var sample_h := _shaped_height(p2, coast)
						row_pts.append(Vector3(p2.x, sample_h, p2.y))
						var biome := _biome_color(p2, colors)
						biome.a = coast
						row_cols.append(biome)
					pts.append(row_pts)
					cols.append(row_cols)
				for s in n_div:
					for k in s + 1:
						var p00: Vector3 = pts[s][k]
						var p10: Vector3 = pts[s + 1][k]
						var p11: Vector3 = pts[s + 1][k + 1]
						var c00: Color = cols[s][k]
						var c10: Color = cols[s + 1][k]
						var c11: Color = cols[s + 1][k + 1]
						var e0 := float(s) / float(n_div)
						var e1 := float(s + 1) / float(n_div)
						if not (wet and p00.y < -0.32 and p10.y < -0.32 and p11.y < -0.32):
							_tri(st, p00, p10, p11, c00, c10, c11, e0, e1, e1, 0.0)
						if k < s:
							var p01: Vector3 = pts[s][k + 1]
							var c01: Color = cols[s][k + 1]
							if not (wet and p00.y < -0.32 and p11.y < -0.32 and p01.y < -0.32):
								_tri(st, p00, p11, p01, c00, c11, c01, e0, e1, e0, 0.0)
	# Weld shared hex edges so normals average across the border instead of
	# leaving a dark crease on every tile.
	st.index()
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, ua: float, ub: float, uc: float, _shore: float) -> void:
	st.set_color(ca)
	st.set_uv(Vector2(ua, 0.0))
	st.add_vertex(a)
	st.set_color(cb)
	st.set_uv(Vector2(ub, 0.0))
	st.add_vertex(b)
	st.set_color(cc)
	st.set_uv(Vector2(uc, 0.0))
	st.add_vertex(c)


static func _water_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := -0.1
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			var wet := _water(id)
			if not wet and not _touches_water(ax):
				continue
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var lake := 1.0 if id == "lake" else 0.0
			# Open sea is a flat deep hex. Coasts and lakes are subdivided so the foam can follow the curved shore.
			if wet and not _touches_land(ax):
				var deep := Color(0.92, lake, 0.0)
				var cp := Vector3(center.x, y, center.y)
				for i in 6:
					var ang0 := deg_to_rad(60.0 * float(i) - 30.0)
					var ang1 := deg_to_rad(60.0 * float(i + 1) - 30.0)
					var a := Vector3(center.x + cos(ang0) * HexGrid.SIZE * 1.01, y, center.y + sin(ang0) * HexGrid.SIZE * 1.01)
					var b := Vector3(center.x + cos(ang1) * HexGrid.SIZE * 1.01, y, center.y + sin(ang1) * HexGrid.SIZE * 1.01)
					_tri(st, cp, a, b, deep, deep, deep, 0.0, 0.0, 0.0, 0.0)
				continue
			var n_div := 3
			for edge in 6:
				var a0 := deg_to_rad(60.0 * float(edge) - 30.0)
				var a1 := deg_to_rad(60.0 * float(edge + 1) - 30.0)
				var off_a := Vector2(cos(a0), sin(a0)) * HexGrid.SIZE * 1.01
				var off_b := Vector2(cos(a1), sin(a1)) * HexGrid.SIZE * 1.01
				var pts: Array = []
				var cols: Array = []
				for s in n_div + 1:
					var row_pts: Array = []
					var row_cols: Array = []
					var u := float(s) / float(n_div)
					for k in s + 1:
						var v := 0.0 if s == 0 else float(k) / float(s)
						var p2: Vector2 = center + off_a.lerp(off_b, v) * u
						var coast := _coast_field(p2)
						row_pts.append(Vector3(p2.x, y, p2.y))
						row_cols.append(Color(coast, lake, 0.0, 1.0))
					pts.append(row_pts)
					cols.append(row_cols)
				for s in n_div:
					for k in s + 1:
						var c00: Color = cols[s][k]
						var c10: Color = cols[s + 1][k]
						var c11: Color = cols[s + 1][k + 1]
						if maxf(c00.r, maxf(c10.r, c11.r)) < 0.3:
							continue
						var p00: Vector3 = pts[s][k]
						var p10: Vector3 = pts[s + 1][k]
						var p11: Vector3 = pts[s + 1][k + 1]
						_tri(st, p00, p10, p11, c00, c10, c11, 0.0, 0.0, 0.0, 0.0)
						if k < s:
							var c01: Color = cols[s][k + 1]
							if maxf(c00.r, maxf(c11.r, c01.r)) < 0.3:
								continue
							var p01: Vector3 = pts[s][k + 1]
							_tri(st, p00, p11, p01, c00, c11, c01, 0.0, 0.0, 0.0, 0.0)
	st.generate_normals()
	return st.commit()


static func _ribbon_mesh(rivers: bool, heights: Dictionary, colors: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seen := {}
	if rivers:
		_build_rivers(st)
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


static func _corner_at(center: Vector2, i: int) -> Vector2:
	var ang := deg_to_rad(60.0 * float(posmod(i, 6)) - 30.0)
	var p := center + Vector2(cos(ang), sin(ang)) * HexGrid.SIZE
	return Vector2(snapped(p.x, 0.05), snapped(p.y, 0.05))


static func _pkey(p: Vector2) -> Vector2i:
	return Vector2i(int(round(p.x * 20.0)), int(round(p.y * 20.0)))


static func _pair_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d|%d,%d" % [b.x, b.y, a.x, a.y]


static func _edge_midpoint(ax: Vector2i, dir_i: int) -> Vector2:
	var edge := int(RIVER_DIR_EDGE[dir_i])
	var ang := deg_to_rad(60.0 * float(edge))
	var center := HexGrid.axial_to_pixel(ax.x, ax.y)
	var ap := HexGrid.SIZE * sqrt(3.0) * 0.5
	return center + Vector2(cos(ang), sin(ang)) * ap


static func _link_nodes(adj: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if a == b:
		return
	if not adj.has(a):
		adj[a] = []
	if not adj.has(b):
		adj[b] = []
	var na: Array = adj[a]
	if not na.has(b):
		na.append(b)
	adj[a] = na
	var nb: Array = adj[b]
	if not nb.has(a):
		nb.append(a)
	adj[b] = nb


static func _river_graph() -> Dictionary:
	# A river crosses a hex from one flagged edge to the other. Opposite edges
	# do not share a corner, so the polyline is midpoint to midpoint.
	var adj := {}
	var pos := {}
	var great := {}
	for key_v in DataDB.river_masks.keys():
		var ax: Vector2i = key_v
		var masks: Array = DataDB.river_masks[ax]
		var wide := int(masks[1])
		var bits := int(masks[0]) | wide
		var dirs: Array = []
		for dir_i in 6:
			if (bits & (1 << dir_i)) != 0:
				dirs.append(dir_i)
		if dirs.size() < 2:
			continue
		var mids: Array = []
		for dir_v in dirs:
			var raw := _edge_midpoint(ax, int(dir_v))
			var mid := _pkey(raw)
			if not pos.has(mid):
				pos[mid] = Vector2(float(mid.x) / 20.0, float(mid.y) / 20.0)
			mids.append(mid)
		if dirs.size() == 2:
			var ga := (wide & (1 << int(dirs[0]))) != 0 or (wide & (1 << int(dirs[1]))) != 0
			_link_nodes(adj, mids[0], mids[1])
			great[_pair_key(mids[0], mids[1])] = ga
		else:
			var center_raw := HexGrid.axial_to_pixel(ax.x, ax.y)
			var center := _pkey(center_raw)
			pos[center] = Vector2(float(center.x) / 20.0, float(center.y) / 20.0)
			for mi in mids.size():
				var gbit := (wide & (1 << int(dirs[mi]))) != 0
				_link_nodes(adj, center, mids[mi])
				great[_pair_key(center, mids[mi])] = gbit
	return {"adj": adj, "pos": pos, "great": great}


static func _nearest_water(p: Vector2, rad: int) -> Dictionary:
	var ax := HexGrid.pixel_to_axial(p)
	var best := Vector2.ZERO
	var best_d := 1.0e9
	var found := false
	for dz in range(-rad, rad + 1):
		for dq in range(-rad, rad + 1):
			var c := Vector2i(ax.x + dq, ax.y + dz)
			if not DataDB.in_bounds(c.x, c.y):
				continue
			if not _water(DataDB.terrain_id(c.x, c.y)):
				continue
			var center := HexGrid.axial_to_pixel(c.x, c.y)
			var d := p.distance_to(center)
			if d < best_d:
				best_d = d
				best = center
				found = true
	return {"ok": found, "p": best, "d": best_d}


static func _half_width(upstream: float) -> float:
	var t := sqrt(clampf(upstream / 78.0, 0.0, 1.0))
	return 2.25 + 5.35 * t


static func _prepare_rivers() -> void:
	_river_buckets = {}
	_river_courses = []
	var graph := _river_graph()
	var adj: Dictionary = graph.adj
	var pos: Dictionary = graph.pos
	var great: Dictionary = graph.great
	var seen := {}
	var kept := 0
	for start_v in adj.keys():
		var start: Vector2i = start_v
		if seen.has(start):
			continue
		var comp: Array = []
		var queue: Array = [start]
		seen[start] = true
		var qi := 0
		while qi < queue.size():
			var cur: Vector2i = queue[qi]
			qi += 1
			comp.append(cur)
			var nbrs: Array = adj[cur]
			for nb_v in nbrs:
				var nb: Vector2i = nb_v
				if seen.has(nb):
					continue
				seen[nb] = true
				queue.append(nb)
		if comp.size() < 6:
			continue
		kept += comp.size()
		_flow_component(comp, adj, pos, great)
	var pts := 0
	for course_v in _river_courses:
		pts += (course_v as Array).size()
	print("RIVERS courses %d pts %d nodes %d" % [_river_courses.size(), pts, kept])


static func _flow_component(comp: Array, adj: Dictionary, pos: Dictionary, great: Dictionary) -> void:
	var mouths: Array = []
	var water_mouth := {}
	var leaves: Array = []
	var east := Vector2i.ZERO
	var south := Vector2i.ZERO
	var have_leaf := false
	var min_x := 1.0e9
	var max_x := -1.0e9
	var min_y := 1.0e9
	var max_y := -1.0e9
	for n_v in comp:
		var n: Vector2i = n_v
		var p: Vector2 = pos[n]
		min_x = minf(min_x, p.x)
		max_x = maxf(max_x, p.x)
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
		if (adj[n] as Array).size() > 1:
			continue
		leaves.append(n)
		if not have_leaf or p.x > (pos[east] as Vector2).x:
			east = n
		if not have_leaf or p.y > (pos[south] as Vector2).y:
			south = n
		have_leaf = true
		var water := _nearest_water(p, 2)
		if bool(water.ok) and float(water.d) <= HexGrid.SIZE * 2.6:
			mouths.append(n)
			water_mouth[n] = water
	if mouths.is_empty():
		if not have_leaf:
			mouths.append(comp[0])
		elif max_y - min_y > (max_x - min_x) * 1.15:
			mouths.append(south)
		else:
			mouths.append(east)
	var down := {}
	var dist := {}
	var bfs: Array = []
	for m_v in mouths:
		var m: Vector2i = m_v
		if dist.has(m):
			continue
		dist[m] = 0
		bfs.append(m)
	var qj := 0
	while qj < bfs.size():
		var cur2: Vector2i = bfs[qj]
		qj += 1
		var nbrs2: Array = adj[cur2]
		for nb2_v in nbrs2:
			var nb2: Vector2i = nb2_v
			if dist.has(nb2):
				continue
			dist[nb2] = int(dist[cur2]) + 1
			down[nb2] = cur2
			bfs.append(nb2)
	var up := {}
	var order: Array = dist.keys()
	for ai in order.size():
		var best := ai
		for bi in range(ai + 1, order.size()):
			if int(dist[order[bi]]) > int(dist[order[best]]):
				best = bi
		if best != ai:
			var swap = order[ai]
			order[ai] = order[best]
			order[best] = swap
	for n2_v in order:
		var n2: Vector2i = n2_v
		var own := 1.0
		if down.has(n2) and bool(great.get(_pair_key(n2, down[n2]), false)):
			own = 2.15
		var acc := own
		var nbrs3: Array = adj[n2]
		for nb3_v in nbrs3:
			var nb3: Vector2i = nb3_v
			if down.has(nb3) and down[nb3] == n2:
				acc += float(up.get(nb3, 0.0))
		up[n2] = acc
	var inflow := {}
	for src_v in down.keys():
		var dest: Vector2i = down[src_v]
		inflow[dest] = int(inflow.get(dest, 0)) + 1
	for src2_v in dist.keys():
		var src2: Vector2i = src2_v
		if not down.has(src2):
			continue
		if int(inflow.get(src2, 0)) == 1:
			continue
		var chain: Array = [src2]
		var walk := src2
		var guard := 0
		while down.has(walk) and guard < 400:
			guard += 1
			var nxt: Vector2i = down[walk]
			chain.append(nxt)
			if int(inflow.get(nxt, 0)) >= 2 or not down.has(nxt):
				break
			walk = nxt
		_emit_chain(chain, pos, up, water_mouth)


static func _emit_chain(chain: Array, pos: Dictionary, up: Dictionary, water_mouth: Dictionary) -> void:
	if chain.size() < 2:
		return
	var raw: Array = []
	for node_v in chain:
		var node: Vector2i = node_v
		raw.append({
			"p": pos[node],
			"w": _half_width(float(up.get(node, 1.0))),
			"mouth": 0.0,
		})
	var last: Vector2i = chain[chain.size() - 1]
	if water_mouth.has(last):
		var info: Dictionary = water_mouth[last]
		var tip: Vector2 = raw[raw.size() - 1].p
		var aim: Vector2 = info.p - tip
		if aim.length() > 1.0:
			aim = aim.normalized()
			var wtip := float(raw[raw.size() - 1].w)
			raw.append({"p": tip + aim * 12.0, "w": wtip * 1.04, "mouth": 0.45})
			raw.append({"p": tip.lerp(info.p, 0.74), "w": wtip * 1.08, "mouth": 1.0})
	var smooth := _smooth_course(raw)
	if smooth.size() < 2:
		return
	_river_courses.append(smooth)
	for si in range(smooth.size() - 1):
		var s0: Dictionary = smooth[si]
		var s1: Dictionary = smooth[si + 1]
		_add_river_seg(s0.p, s1.p, float(s0.w), float(s1.w))


static func _catmull2(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


static func _smooth_course(raw: Array) -> Array:
	var n := raw.size()
	if n < 3:
		return raw
	var out: Array = []
	for i in range(n - 1):
		var i0 := i - 1
		if i0 < 0:
			i0 = 0
		var i3 := i + 2
		if i3 > n - 1:
			i3 = n - 1
		var p0: Vector2 = raw[i0].p
		var p1: Vector2 = raw[i].p
		var p2: Vector2 = raw[i + 1].p
		var p3: Vector2 = raw[i3].p
		var span := p1.distance_to(p2)
		var steps := int(round(span / 10.0))
		if steps < 1:
			steps = 1
		if steps > 6:
			steps = 6
		for s in steps:
			var t := float(s) / float(steps)
			out.append({
				"p": _catmull2(p0, p1, p2, p3, t),
				"w": lerpf(float(raw[i].w), float(raw[i + 1].w), t),
				"mouth": lerpf(float(raw[i].mouth), float(raw[i + 1].mouth), t),
			})
	out.append(raw[n - 1])
	return out


static func _add_river_seg(a: Vector2, b: Vector2, wa: float, wb: float) -> void:
	var seg := {"a": a, "b": b, "wa": wa, "wb": wb}
	var seen := {}
	var probes: Array[Vector2] = [a, b, (a + b) * 0.5]
	for probe in probes:
		var home := HexGrid.pixel_to_axial(probe)
		for dz in range(-1, 2):
			for dq in range(-1, 2):
				var cell := Vector2i(home.x + dq, home.y + dz)
				if seen.has(cell):
					continue
				seen[cell] = true
				if not _river_buckets.has(cell):
					_river_buckets[cell] = []
				var bucket: Array = _river_buckets[cell]
				bucket.append(seg)
				_river_buckets[cell] = bucket


static func _build_rivers(st: SurfaceTool) -> void:
	var col := Color(0.62, 0.74, 0.78, 1.0)
	for course_v in _river_courses:
		_course_ribbon(st, course_v, col)


static func _course_ribbon(st: SurfaceTool, course: Array, col: Color) -> void:
	var n := course.size()
	if n < 2:
		return
	var left: Array = []
	var right: Array = []
	var along: Array = []
	var acc := 0.0
	for i in n:
		var here: Dictionary = course[i]
		var p: Vector2 = here.p
		var tangent := Vector2.RIGHT
		if i == 0:
			tangent = (course[1] as Dictionary).p - p
		elif i == n - 1:
			tangent = p - (course[i - 1] as Dictionary).p
		else:
			tangent = (course[i + 1] as Dictionary).p - (course[i - 1] as Dictionary).p
		if tangent.length() < 0.001:
			tangent = Vector2.RIGHT
		tangent = tangent.normalized()
		var side := Vector2(-tangent.y, tangent.x) * float(here.w)
		var h := _surface_height(p) + 0.035
		h = lerpf(h, -0.06, float(here.mouth))
		left.append(Vector3(p.x + side.x, h, p.y + side.y))
		right.append(Vector3(p.x - side.x, h, p.y - side.y))
		along.append(acc)
		if i + 1 < n:
			acc += p.distance_to((course[i + 1] as Dictionary).p) / 16.0
	for j in n - 1:
		var u0 := float(along[j])
		var u1 := float(along[j + 1])
		_tri_uv(st, left[j], left[j + 1], right[j + 1], col, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0))
		_tri_uv(st, left[j], right[j + 1], right[j], col, Vector2(u0, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0))


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return "%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	return "%d,%d:%d,%d" % [b.x, b.y, a.x, a.y]


static func _edge_y(a: Vector2i, b: Vector2i, _heights: Dictionary, _colors: Dictionary) -> float:
	var pa := HexGrid.axial_to_pixel(a.x, a.y)
	var pb := HexGrid.axial_to_pixel(b.x, b.y)
	return _world_height((pa + pb) * 0.5)


static func _add_ribbon(st: SurfaceTool, a: Vector2i, b: Vector2i, width: float, color: Color, lift: float, _heights: Dictionary, _colors: Dictionary, meander: float = 0.0) -> void:
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
	if meander > 0.0:
		var nrm := Vector2(-dir.y, dir.x)
		q0 += nrm * sin(q0.x * 0.085 + q0.y * 0.13) * meander
		q1 += nrm * sin(q1.x * 0.085 + q1.y * 0.13 + 1.7) * meander
	var corners := [q0 - side2, q1 - side2, q1 + side2, q0 + side2]
	var pts: Array[Vector3] = []
	for q in corners:
		pts.append(Vector3(q.x, _surface_height(q) + lift, q.y))
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


static func _tree_lists(heights: Dictionary) -> Dictionary:
	# Forests, rocks, and crops come from the terrain kit. A few tufts remain
	# on open ground the kit does not cover.
	var tufts: Array = []
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			var id := DataDB.terrain_id(ax.x, ax.y)
			if id != "plain" and id != "grass" and id != "desert" and id != "erg":
				continue
			if _city_here(ax) or _near_north_city(ax):
				continue
			var center := HexGrid.axial_to_pixel(ax.x, ax.y)
			var y := float(heights.get(ax, 0.4))
			var tuft_n := 2
			for k2 in tuft_n:
				var ang2 := float(k2) * 2.4 + float(ax.x) * 0.37
				var rad2 := 5.5 + float(k2) * 4.0
				var p2 := Vector3(center.x + cos(ang2) * rad2, y, center.y + sin(ang2) * rad2)
				var s2 := 1.6 + absf(sin(ang2)) * 0.9
				var tint := Color("6d7a48")
				if id == "desert" or id == "erg":
					tint = Color("c4b48c")
				elif id == "plain" and _hex_has_river(ax):
					tint = Color("4a7344")
				tufts.append({"t": Transform3D(Basis(Vector3.UP, ang2).scaled(Vector3(s2, s2, s2)), p2), "color": tint})
	return {"pines": [], "broads": [], "tufts": tufts, "rocks": []}


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
