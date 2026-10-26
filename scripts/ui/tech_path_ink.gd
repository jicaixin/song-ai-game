extends Control

const SHADER := preload("res://shaders/tech_path.gdshader")

var segs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat


func set_segs(next: Array) -> void:
	segs = next
	queue_redraw()


func _draw() -> void:
	for seg_v in segs:
		var seg: Dictionary = seg_v
		var color: Color = seg.get("color", Color.WHITE)
		var alpha := float(seg.get("alpha", 1.0))
		var width := float(seg.get("width", 3.0))
		if seg.has("pts"):
			var poly: PackedVector2Array = seg.get("pts", PackedVector2Array())
			var u0 := 0.0
			for i in maxi(0, poly.size() - 1):
				var a: Vector2 = poly[i]
				var b: Vector2 = poly[i + 1]
				var length := a.distance_to(b)
				_ribbon(a, b, color, width, alpha, u0)
				u0 += length / 16.0
				if i == poly.size() - 2:
					_arrow(a, b, color, alpha)
		else:
			var a2: Vector2 = seg.get("a", Vector2.ZERO)
			var b2: Vector2 = seg.get("b", Vector2.ZERO)
			_ribbon(a2, b2, color, width, alpha, 0.0)
			_arrow(a2, b2, color, alpha)


func _ribbon(a: Vector2, b: Vector2, color: Color, width: float, alpha: float, u_start: float = 0.0) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var side := Vector2(-dir.y, dir.x) * (width * 0.5)
	var pts := PackedVector2Array([a + side, a - side, b - side, b + side])
	var u := length / 16.0
	var uvs := PackedVector2Array([Vector2(u_start, 0), Vector2(u_start, 1), Vector2(u_start + u, 1), Vector2(u_start + u, 0)])
	var tint := Color(color, alpha)
	draw_polygon(pts, PackedColorArray([tint, tint, tint, tint]), uvs)


func _arrow(a: Vector2, b: Vector2, color: Color, alpha: float) -> void:
	var dir := b - a
	if dir.length() < 8.0:
		return
	dir = dir.normalized()
	var side := Vector2(-dir.y, dir.x)
	var tip := b
	var p1 := tip - dir * 10.0 + side * 5.0
	var p2 := tip - dir * 10.0 - side * 5.0
	var tint := Color(color, alpha)
	var uvs := PackedVector2Array([Vector2(0, 2), Vector2(0, 2), Vector2(0, 2)])
	draw_polygon(PackedVector2Array([tip, p1, p2]), PackedColorArray([tint, tint, tint]), uvs)
