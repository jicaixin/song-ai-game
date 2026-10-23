extends Control

const Kit = preload("res://scripts/ui/kit.gd")

var _tex := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var map := get_tree().get_first_node_in_group("world_map") as WorldMap
	if map == null or not map.hover_ok:
		return
	if map.zoom_index > 0:
		_badges(map, map.hover, map.hover_plan)
		if DataDB.in_bounds(map.guide_hex.x, map.guide_hex.y):
			var gp := map.world_to_screen(HexGrid.axial_to_pixel(map.guide_hex.x, map.guide_hex.y))
			_icon_at(gp + Vector2(0, 10), "hb_guide")
	var path: Array = map.hover_plan.get("path", [])
	if path.is_empty():
		return
	var pts: PackedVector2Array = []
	var u := GameState.selected_unit()
	if not u.is_empty():
		pts.append(map.world_to_screen(HexGrid.axial_to_pixel(int(u.q), int(u.r))))
	for h_v in path:
		var h: Vector2i = h_v
		pts.append(map.world_to_screen(HexGrid.axial_to_pixel(h.x, h.y)))
	var col := Color("f4efe4")
	for i in maxi(0, pts.size() - 1):
		_dash(pts[i], pts[i + 1], col)
	var remain := int(map.hover_plan.get("remain", -1))
	if remain >= 0 and pts.size() > 0:
		var at := pts[pts.size() - 1] + Vector2(14, -18)
		draw_rect(Rect2(at, Vector2(46, 18)), Color("1b2b2ce6"), true)
		var font := ThemeDB.fallback_font
		if font != null:
			draw_string(font, at + Vector2(4, 14), "剩 %d" % remain, HORIZONTAL_ALIGNMENT_LEFT, 40, 13, Color("f4efe4"))


func _badges(map: WorldMap, hex: Vector2i, plan: Dictionary) -> void:
	var badges: Array = plan.get("badges", [])
	if badges.is_empty():
		return
	var center := map.world_to_screen(HexGrid.axial_to_pixel(hex.x, hex.y))
	var occ := GameState.unit_at(hex)
	var origin := center + Vector2(0, 12 if not occ.is_empty() else 0)
	var n := 0
	for name_v in badges:
		var name := str(name_v)
		var at := origin
		if name == "hb_river" or name == "hb_pass" or name == "hb_resource" or name == "hb_city_own" or name == "hb_city_enemy":
			at = center + Vector2(12 + n * 14, -16)
			n += 1
		_icon_at(at, name)


func _icon_at(at: Vector2, name: String) -> void:
	var tex := _texture(name)
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(at - Vector2(8, 8), Vector2(16, 16)), false)


func _texture(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var path := "res://ui/components/png/%s.png" % name
	if not ResourceLoader.exists(path):
		_tex[name] = null
		return null
	var loaded := load(path) as Texture2D
	_tex[name] = loaded
	return loaded


func _dash(a: Vector2, b: Vector2, color: Color) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 1.0:
		return
	dir /= length
	var t := 0.0
	var on := true
	while t < length:
		var seg := 8.0 if on else 5.0
		var t2 := minf(t + seg, length)
		if on:
			draw_line(a + dir * t, a + dir * t2, color, 2.0, true)
		t = t2
		on = not on
