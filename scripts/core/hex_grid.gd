class_name HexGrid
extends RefCounted

## Pointy-top axial hexes. Odd-r offset. Neighbor order matches the map generator.
const SIZE := 18.0
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

static func idiv(a: int, b: int) -> int:
	return int(float(a) / float(b))


static func axial_from_offset(col: int, row: int) -> Vector2i:
	var q := col - idiv(row - (row & 1), 2)
	return Vector2i(q, row)


static func offset_from_axial(q: int, r: int) -> Vector2i:
	var col := q + idiv(r - (r & 1), 2)
	return Vector2i(col, r)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	return idiv(abs(dq) + abs(dr) + abs(dq + dr), 2)


static func neighbors_of(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(h + d)
	return out


static func dir_between(a: Vector2i, b: Vector2i) -> int:
	var d := b - a
	for i in DIRS.size():
		if DIRS[i] == d:
			return i
	return -1


static func axial_to_pixel(q: int, r: int) -> Vector2:
	var x := SIZE * sqrt(3.0) * (float(q) + float(r) / 2.0)
	var y := SIZE * 1.5 * float(r)
	return Vector2(x, y)


static func pixel_to_axial(p: Vector2) -> Vector2i:
	var qf := (sqrt(3.0) / 3.0 * p.x - (1.0 / 3.0) * p.y) / SIZE
	var rf := ((2.0 / 3.0) * p.y) / SIZE
	return _cube_round(qf, rf)


static func _cube_round(qf: float, rf: float) -> Vector2i:
	var xf := qf
	var zf := rf
	var yf := -xf - zf
	var x: float = round(xf)
	var y: float = round(yf)
	var z: float = round(zf)
	var dx := absf(x - xf)
	var dy := absf(y - yf)
	var dz := absf(z - zf)
	if dx > dy and dx > dz:
		x = -y - z
	elif dy > dz:
		y = -x - z
	else:
		z = -x - y
	return Vector2i(int(x), int(z))


static func corners() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var ang := deg_to_rad(60.0 * float(i) - 30.0)
		pts.append(Vector2(cos(ang), sin(ang)) * SIZE)
	return pts
