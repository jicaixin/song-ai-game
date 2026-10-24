extends Node

var map: Dictionary = {}
var terrains: Array = []
var owners: Array = []
var width := 64
var height := 68
var terrain_by_char := {}
var owner_by_char := {}
var terrain_defs := {}
var factions := {}
var unit_types := {}
var cities: Array = []
var cities_by_id := {}
var city_hexes := {}
var lines: Array = []
var techs: Array = []
var tech_by_id := {}
var branches: Array = []
var eras: Array = []
var balance: Dictionary = {}
var resources_meta: Array = []
var buildings: Array = []
var firmware: Array = []
var firmware_by_id := {}
var edicts: Array = []
var edict_by_id := {}
var stages: Array = []
var events: Array = []
var event_by_id := {}
var chapters: Array = []
var chapter_by_id := {}
var goal_orders: Array = []
var scenario: Dictionary = {}
var river_masks := {}
var feature_hexes := {}

func _ready() -> void:
	balance = _load_dict("res://data/balance.json")
	scenario = _load_dict("res://data/scenario_1040.json")
	var terrain_doc := _load_dict("res://data/terrains.json")
	for t_v in terrain_doc.get("terrains", []):
		terrain_defs[str(t_v.get("id", ""))] = t_v
	var faction_doc := _load_dict("res://data/factions.json")
	for f_v in faction_doc.get("factions", []):
		factions[str(f_v.get("id", ""))] = f_v
	var unit_doc := _load_dict("res://data/units.json")
	for u_v in unit_doc.get("units", []):
		unit_types[str(u_v.get("id", ""))] = u_v
	var city_doc := _load_dict("res://data/cities.json")
	cities = city_doc.get("cities", [])
	for c_v in cities:
		var city: Dictionary = c_v
		city["q"] = int(city.get("q", 0))
		city["r"] = int(city.get("r", 0))
		cities_by_id[str(city.get("id", ""))] = city
		city_hexes[Vector2i(int(city.q), int(city.r))] = city
	var talk := _load_dict("res://data/dialogue/doushabao.json")
	lines = talk.get("lines", [])
	var tech_doc := _load_dict("res://data/techs.json")
	techs = tech_doc.get("techs", [])
	branches = tech_doc.get("branches", [])
	eras = tech_doc.get("eras", [])
	for tech_v in techs:
		tech_by_id[str(tech_v.get("id", ""))] = tech_v
	firmware = tech_doc.get("firmware", [])
	for fw_v in firmware:
		var fw: Dictionary = fw_v
		firmware_by_id[str(fw.get("id", ""))] = fw
	edicts = tech_doc.get("edicts", [])
	for ed_v in edicts:
		var ed: Dictionary = ed_v
		edict_by_id[str(ed.get("id", ""))] = ed
	stages = tech_doc.get("stages", [])
	var event_doc := _load_dict("res://data/events.json")
	events = event_doc.get("events", [])
	for ev_v in events:
		var ev: Dictionary = ev_v
		event_by_id[str(ev.get("id", ""))] = ev
	var chapter_doc := _load_dict("res://data/chapters.json")
	chapters = chapter_doc.get("chapters", [])
	for ch_v in chapters:
		var ch: Dictionary = ch_v
		chapter_by_id[str(ch.get("id", ""))] = ch
	var goal_doc := _load_dict("res://data/goals.json")
	goal_orders = goal_doc.get("orders", [])
	var res_doc := _load_dict("res://data/resources.json")
	resources_meta = res_doc.get("resources", [])
	var bdoc := _load_dict("res://data/buildings.json")
	buildings = bdoc.get("buildings", [])
	map = _load_dict("res://data/map/map_1040.json")
	width = int(map.get("width", 64))
	height = int(map.get("height", 68))
	terrains = map.get("terrains", [])
	owners = map.get("owners", [])
	terrain_by_char = _char_key(map.get("terrain_legend", {}))
	owner_by_char = _char_key(map.get("owner_legend", {}))
	for riv_v in map.get("rivers", []):
		var riv: Array = riv_v
		if riv.size() < 4:
			continue
		river_masks[Vector2i(int(riv[0]), int(riv[1]))] = [int(riv[2]), int(riv[3])]
	for feat_v in map.get("features", []):
		var feat: Dictionary = feat_v
		feature_hexes[Vector2i(int(feat.get("q", 0)), int(feat.get("r", 0)))] = feat


func _load_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("无法读取 %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON 无效 %s" % path)
		return {}
	return parsed


func _char_key(legend: Dictionary) -> Dictionary:
	var long_key := false
	for k in legend.keys():
		if str(k).length() != 1:
			long_key = true
			break
	if not long_key:
		return legend
	var out := {}
	for k in legend.keys():
		out[str(legend[k])] = str(k)
	return out


func in_bounds(q: int, r: int) -> bool:
	var off := HexGrid.offset_from_axial(q, r)
	return off.x >= 0 and off.y >= 0 and off.x < width and off.y < height


func _char_at(rows: Array, q: int, r: int) -> String:
	if not in_bounds(q, r):
		return ""
	var off := HexGrid.offset_from_axial(q, r)
	var row := str(rows[off.y])
	if off.x < 0 or off.x >= row.length():
		return ""
	return row.substr(off.x, 1)


func terrain_id(q: int, r: int) -> String:
	var ch := _char_at(terrains, q, r)
	return str(terrain_by_char.get(ch, ""))


func owner_id(q: int, r: int) -> String:
	var ch := _char_at(owners, q, r)
	return str(owner_by_char.get(ch, ""))


func terrain(id: String) -> Dictionary:
	return terrain_defs.get(id, {})


func faction(id: String) -> Dictionary:
	return factions.get(id, {})


func unit_type(id: String) -> Dictionary:
	return unit_types.get(id, {})


func city_by_id(id: String) -> Dictionary:
	return cities_by_id.get(id, {})


func city_at_hex(q: int, r: int) -> Dictionary:
	return city_hexes.get(Vector2i(q, r), {})


func feature_at(q: int, r: int) -> Dictionary:
	return feature_hexes.get(Vector2i(q, r), {})


func hostile(a: String, b: String) -> bool:
	if a == "" or b == "" or a == b:
		return false
	var pair := [a, b]
	pair.sort()
	return pair == ["song", "xia"] or pair == ["liao", "song"]


func color_of(hex_str: String) -> Color:
	var s := hex_str
	if not s.begins_with("#"):
		s = "#" + s
	return Color.html(s)
