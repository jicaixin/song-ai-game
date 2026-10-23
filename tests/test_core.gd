extends RefCounted

const TechPlan = preload("res://scripts/ui/tech_plan.gd")
const TileActions = preload("res://scripts/core/tile_actions.gd")

var failed := 0

func run_tests() -> int:
	check_hex()
	check_pixel_roundtrip()
	check_calendar()
	check_combat_range()
	check_geo_and_cities()
	check_path()
	check_save_roundtrip()
	check_tiles()
	check_tech()
	check_camera()
	check_font()
	if failed > 0:
		push_error("失败 %d 项" % failed)
	else:
		print("ALL TESTS PASSED")
	return failed


func check_camera() -> void:
	var map := Engine.get_main_loop().root.find_child("WorldMap", true, false) as WorldMap
	if map == null:
		check("camera", false, "no map")
		return
	map.focus_city("yanzhou")
	var yan := DataDB.city_by_id("yanzhou")
	var screen := map.world_to_screen(HexGrid.axial_to_pixel(int(yan.q), int(yan.r)))
	var dx := absf(screen.x - 488.0)
	var dy := absf(screen.y - 326.0)
	check("camera", dx < 50.0 and dy < 50.0, "screen %s cam %s vp %s" % [screen, map.camera.position, map.get_viewport_rect().size])
	for z in 3:
		map.zoom_index = z
		map.focus_city("yanzhou")
		print("SPAN z%d %.2f" % [z, map.visible_hex_span()])
	map.zoom_index = 1
	map.focus_city("yanzhou")


func check_font() -> void:
	var face := Settings.font
	check("font_wo", face != null and face.has_char("我".unicode_at(0)))
	check("font_song", face != null and face.has_char("宋".unicode_at(0)))
	check("font_realm", face != null and face.has_char("唃".unicode_at(0)) and face.has_char("厮".unicode_at(0)) and face.has_char("啰".unicode_at(0)) and face.has_char("鹘".unicode_at(0)))
	if face is FontFile:
		check("font_no_sys", not (face as FontFile).allow_system_fallback)
		check("font_aa", (face as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_GRAY)
	var banner := Settings.banner_font
	check("banner_font", banner != null and banner.has_char("延".unicode_at(0)))
	var layer := CanvasLayer.new()
	Engine.get_main_loop().root.add_child(layer)
	var themed := Label.new()
	themed.theme_type_variation = "H2Label"
	themed.text = "朝堂"
	layer.add_child(themed)
	var resolved := themed.get_theme_font("font")
	var face_name := ""
	if resolved is FontFile:
		face_name = (resolved as FontFile).font_name
	check("ui_font_h2", resolved != null and resolved.has_char("朝".unicode_at(0)) and face_name != "Open Sans SemiBold", face_name)
	var body := Label.new()
	body.theme_type_variation = "BodyLabel"
	layer.add_child(body)
	var body_font := body.get_theme_font("font")
	check("ui_font_body", body_font != null and body_font.has_char("遣".unicode_at(0)) and body_font.has_char("〇".unicode_at(0)))
	var brush := Label.new()
	brush.theme_type_variation = "BrushLabel"
	layer.add_child(brush)
	var brush_font := brush.get_theme_font("font")
	check("ui_font_brush", brush_font != null and brush_font.has_char("宝".unicode_at(0)) and brush_font.has_char("祐".unicode_at(0)))
	layer.queue_free()
	if banner is FontFile:
		check("banner_msdf", (banner as FontFile).multichannel_signed_distance_field)
	else:
		check("font_file", false, "not a FontFile")


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("ok ", name)
		return
	failed += 1
	push_error("FAIL %s %s" % [name, detail])


func check_hex() -> void:
	for row in 68:
		for col in 64:
			var ax := HexGrid.axial_from_offset(col, row)
			var back := HexGrid.offset_from_axial(ax.x, ax.y)
			if back != Vector2i(col, row):
				check("offset", false, "%s %s" % [Vector2i(col, row), back])
				return
	check("offset", true)
	var a := Vector2i(0, 0)
	var b := Vector2i(2, -1)
	check("distance", HexGrid.distance(a, b) == 2, str(HexGrid.distance(a, b)))
	check("dirs", HexGrid.DIRS.size() == 6 and HexGrid.DIRS[0] == Vector2i(1, 0))


func check_pixel_roundtrip() -> void:
	var bad := 0
	for row in [0, 1, 17, 26, 40, 67]:
		for col in [0, 1, 15, 32, 63]:
			var ax := HexGrid.axial_from_offset(col, row)
			var back := HexGrid.pixel_to_axial(HexGrid.axial_to_pixel(ax.x, ax.y))
			if back != ax:
				bad += 1
	check("pixel", bad == 0, "bad %d" % bad)


func check_calendar() -> void:
	check("era1040m1", Calendar.era_name(1040, 1) == "宝元三年")
	check("era1040m2", Calendar.era_name(1040, 2) == "康定元年")
	check("era1041m10", Calendar.era_name(1041, 10) == "康定二年")
	check("era1041m11", Calendar.era_name(1041, 11) == "庆历元年")
	check("era1042", Calendar.era_name(1042, 1) == "庆历二年")
	check("era1048", Calendar.era_name(1048, 6) == "庆历八年")
	check("era1049", Calendar.era_name(1049, 1) == "皇祐元年")
	check("month", Calendar.month_name(1) == "正月" and Calendar.month_name(12) == "腊月")
	check("season", Calendar.season(1) == "spring" and Calendar.season(11) == "winter")


func check_combat_range() -> void:
	var lo := CombatResolver.damage_amount(0.0, 0.8)
	var hi := CombatResolver.damage_amount(0.0, 1.2)
	check("dmg24", lo == 24, str(lo))
	check("dmg36", hi == 36, str(hi))
	var atk := {"def_id": "song_spear", "q": 0, "r": 0, "hp": 100, "faction": "song", "uid": 1, "general_bonus": 0}
	var dfd := {"def_id": "song_spear", "q": 1, "r": 0, "hp": 100, "faction": "xia", "uid": 2, "general_bonus": 0}
	GameState.weather_id = "clear"
	GameState.morale = 60
	var preview := CombatResolver.assess(atk, dfd)
	check("preview_span", int(preview.def_min) == 24 and int(preview.def_max) == 36, str(preview.def_min) + "," + str(preview.def_max))


func check_geo_and_cities() -> void:
	check("cities", DataDB.cities.size() >= 70, str(DataDB.cities.size()))
	check("techs", DataDB.techs.size() == 43, str(DataDB.techs.size()))
	var e06: Dictionary = DataDB.tech_by_id.get("E06", {})
	var e06_mats: Dictionary = e06.get("materials", {})
	check("e06", int(e06_mats.get("copper", 0)) == 10 and int(e06_mats.get("sulfur", 0)) == 10 and not e06_mats.has("lead"), str(e06_mats))
	check("firmware", DataDB.firmware.size() == 4 and DataDB.edicts.size() == 8, "%d %d" % [DataDB.firmware.size(), DataDB.edicts.size()])
	check("events", DataDB.events.size() >= 4, str(DataDB.events.size()))
	var worst := 0.0
	for c_v in DataDB.cities:
		var city: Dictionary = c_v
		var ll := Geo.lonlat(int(city.q), int(city.r))
		var dlon := absf(ll.x - float(city.get("hex_lon", ll.x)))
		var dlat := absf(ll.y - float(city.get("hex_lat", ll.y)))
		worst = maxf(worst, maxf(dlon, dlat))
	check("geo", worst < 0.05, "worst %s" % worst)
	var chk: Dictionary = DataDB.map.get("check", {})
	var yan: Dictionary = DataDB.city_by_id("yanzhou")
	check("yanzhou_hex", int(yan.q) == int(chk.get("q", -1)) and int(yan.r) == int(chk.get("r", -1)))
	check("dist_kf_yz", _dist("kaifeng", "yanzhou") == 10, str(_dist("kaifeng", "yanzhou")))
	check("dist_yz_xq", _dist("yanzhou", "xingqing") == 7, str(_dist("yanzhou", "xingqing")))
	check("dist_kf_yzhou", _dist("kaifeng", "youzhou") == 12, str(_dist("kaifeng", "youzhou")))
	check("dist_kf_hz", _dist("kaifeng", "hangzhou") == 14, str(_dist("kaifeng", "hangzhou")))
	check("dist_kf_cd", _dist("kaifeng", "chengdu") == 21, str(_dist("kaifeng", "chengdu")))
	check("owner_yan", _owner("yanzhou") == "song")
	check("owner_xiong", _owner("xiongzhou") == "song")
	check("owner_you", _owner("youzhou") == "liao")
	check("owner_shuo", _owner("shuozhou") == "liao")
	check("owner_dai", _owner("daizhou") == "song")
	check("owner_yin", _owner("yinzhou") == "xia")
	check("owner_sha", _owner("shazhou") == "xia")
	check("owner_xi", _owner("xizhou") == "uyghur")
	check("owner_tang", _owner("thanglong") == "jiaozhi")
	check("touch_xiong", _within("xiongzhou", "liao", 1))
	check("touch_yan", _within("yanzhou", "xia", 2))
	check("touch_zhuo", _within("zhuozhou", "song", 1))


func _owner(id: String) -> String:
	var city: Dictionary = DataDB.city_by_id(id)
	return DataDB.owner_id(int(city.q), int(city.r))


func _within(id: String, faction: String, rad: int) -> bool:
	var city: Dictionary = DataDB.city_by_id(id)
	var origin := Vector2i(int(city.q), int(city.r))
	for dq in range(-rad, rad + 1):
		for dr in range(-rad, rad + 1):
			var nb := origin + Vector2i(dq, dr)
			if HexGrid.distance(origin, nb) > rad:
				continue
			if DataDB.owner_id(nb.x, nb.y) == faction:
				return true
	return false


func _dist(a: String, b: String) -> int:
	var ca: Dictionary = DataDB.city_by_id(a)
	var cb: Dictionary = DataDB.city_by_id(b)
	return HexGrid.distance(Vector2i(int(ca.q), int(ca.r)), Vector2i(int(cb.q), int(cb.r)))


func check_path() -> void:
	var yan: Dictionary = DataDB.city_by_id("yanzhou")
	var fake := {
		"uid": 99,
		"def_id": "song_spear",
		"faction": "song",
		"q": int(yan.q),
		"r": int(yan.r),
		"mp": 2,
		"hp": 100,
	}
	GameState.weather_id = "clear"
	GameState.units = []
	var info := Pathfinder.reachable(fake)
	check("path", info.cost.size() > 0, str(info.cost.size()))


func check_save_roundtrip() -> void:
	GameState.new_game()
	var packed: String = SaveManager.pack(GameState.to_save())
	var data: Dictionary = SaveManager.unpack(packed)
	var turn: int = int(GameState.turn)
	var year: int = int(GameState.year)
	var text: String = str(GameState.advisor_text)
	check("pack", int(data.get("save_version", 0)) == 1 and str(data.get("advisor_text", "")) == text)
	GameState.year = 999
	check("load", GameState.from_save(data) and GameState.year == year and GameState.turn == turn)
	check("advisor", GameState.advisor_text.find("豆沙包") >= 0, GameState.advisor_text)
	check("controls_line", text.find("左键") >= 0 and text.find("右键") < 0 and text.find("豆沙包") >= 0, text)
	check("tutorial_flag", data.has("tutorial_done") and not bool(data.get("tutorial_done")))
	check("design", GameState.start_design("A01") and GameState.tech_designing == "A01")
	var packed_design: String = SaveManager.pack(GameState.to_save())
	GameState.tech_designing = ""
	var design_data: Dictionary = SaveManager.unpack(packed_design)
	check("design_load", GameState.from_save(design_data) and GameState.tech_designing == "A01", GameState.tech_designing)


func check_tiles() -> void:
	GameState.new_game()
	var liu := _named_unit("刘平部")
	check("liu", not liu.is_empty(), "missing 刘平部")
	if liu.is_empty():
		return
	GameState.selected_uid = int(liu.uid)
	var info := Pathfinder.reachable(liu)
	var cost: Dictionary = info.get("cost", {})
	var parent: Dictionary = info.get("parent", {})
	var saw_move := false
	for h_v in cost.keys():
		var h: Vector2i = h_v
		if not GameState.unit_at(h).is_empty():
			continue
		if not DataDB.city_at_hex(h.x, h.y).is_empty():
			continue
		var plan := TileActions.plan_reach(h, int(liu.uid), cost, parent)
		if bool(plan.get("direct", false)):
			var head := str(plan.get("head", ""))
			var n := TileActions.enabled_cmds(plan).size()
			check("tile_direct", head.begins_with("移动") and not head.begins_with("移动并") and n == 1, head)
			saw_move = true
			break
	check("tile_direct_found", saw_move, str(cost.size()))
	var enemy := _named_unit("铁鹞子")
	if enemy.is_empty():
		for u_v in GameState.units:
			var cand: Dictionary = u_v
			if DataDB.hostile("song", str(cand.faction)) and int(cand.hp) > 0:
				enemy = cand
				break
	check("tile_enemy", not enemy.is_empty(), "")
	if enemy.is_empty():
		return
	var saved_q := int(enemy.q)
	var saved_r := int(enemy.r)
	var home := Vector2i(int(liu.q), int(liu.r))
	var spot := home
	for d in HexGrid.DIRS:
		var cand_h: Vector2i = home + d
		if not DataDB.in_bounds(cand_h.x, cand_h.y):
			continue
		var occ := GameState.unit_at(cand_h)
		if occ.is_empty() or int(occ.uid) == int(enemy.uid):
			spot = cand_h
			break
	enemy.q = spot.x
	enemy.r = spot.y
	var q0 := int(liu.q)
	var r0 := int(liu.r)
	var mp0 := int(liu.mp)
	var atk := TileActions.plan(spot, int(liu.uid))
	var ahead := str(atk.get("head", ""))
	check("tile_attack", not bool(atk.get("direct", false)) and (ahead.begins_with("攻击") or ahead.begins_with("远程攻击")), ahead)
	check("tile_pure", int(liu.q) == q0 and int(liu.r) == r0 and int(liu.mp) == mp0, "%d,%d mp %d" % [int(liu.q), int(liu.r), int(liu.mp)])
	enemy.q = saved_q
	enemy.r = saved_r
	var far := TileActions.plan(Vector2i(saved_q, saved_r), int(liu.uid))
	check("tile_pure_far", int(liu.q) == q0 and int(liu.r) == r0 and int(liu.mp) == mp0, str(far.get("head", "")))
	var lake := Vector2i(999999, 0)
	for row in DataDB.height:
		for col in DataDB.width:
			var ax := HexGrid.axial_from_offset(col, row)
			if not GameState.unit_at(ax).is_empty():
				continue
			var terr := DataDB.terrain(DataDB.terrain_id(ax.x, ax.y))
			if bool(terr.get("passable", true)):
				continue
			lake = ax
			if str(terr.get("name", "")) == "湖泊":
				break
		if lake.x < 999999 and str(DataDB.terrain(DataDB.terrain_id(lake.x, lake.y)).get("name", "")) == "湖泊":
			break
	var blocked := TileActions.plan(lake, int(liu.uid))
	check("tile_block", lake.x < 999999 and TileActions.enabled_cmds(blocked).size() == 0 and str(blocked.get("head", "")).find("不可通行") >= 0, str(blocked.get("head", "")))
	liu.mp = 0
	liu["undo"] = {"q": int(liu.q) + 1, "r": int(liu.r), "mp": 2}
	var self_hex := Vector2i(int(liu.q), int(liu.r))
	var self_plan := TileActions.plan(self_hex, int(liu.uid))
	var fort := {}
	var undo := {}
	for a_v in self_plan.get("actions", []):
		var action: Dictionary = a_v
		if str(action.get("id", "")) == "fortify":
			fort = action
		if str(action.get("id", "")) == "undo":
			undo = action
	check("tile_fortify", not fort.is_empty() and not bool(fort.get("enabled", true)) and str(fort.get("reason", "")) == "本月已行动", str(fort))
	check("tile_undo", not undo.is_empty() and bool(undo.get("enabled", false)), str(undo))
	var trait_blob := "\n".join(self_plan.get("more", []))
	check("tile_trait", trait_blob.find("vs_class") < 0 and trait_blob.find("克制骑兵") >= 0, trait_blob)
	var shi := _named_unit("石元孙部")
	var bu := _named_unit("步跋子")
	if not shi.is_empty() and not bu.is_empty():
		var ranged := TileActions.plan(Vector2i(int(bu.q), int(bu.r)), int(shi.uid))
		var rhead := str(ranged.get("head", ""))
		var rsub := str(ranged.get("card_sub", ""))
		check("tile_zero", rhead.find("我 0") >= 0 and rhead.find("-0~0") < 0, rhead)
		check("tile_sub", rsub.find("步跋子") >= 0 and rsub.find("生命") >= 0 and rsub.find("相距") >= 0 and rsub.find("山地步兵") >= 0, rsub)
	check("tile_loss", TileActions.loss_text("我", 0, 0) == "我 0" and TileActions.loss_text("敌", 4, 8) == "敌 -4~8", "")
	var low: Dictionary = TileActions.place_card(Vector2(400, 680), 20.0, Vector2(260, 320))
	var low_pos: Vector2 = low.get("pos", Vector2.ZERO)
	check("tile_place_low", low_pos.y >= 60.0 and low_pos.y + 320.0 <= 704.0, str(low_pos))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1040
	var bad := 0
	var held := 0
	for _i in 100:
		for radius in [15.0, 42.0, 105.0]:
			var anchor := Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0))
			var card := Vector2(232, 188)
			var placed: Dictionary = TileActions.place_card(anchor, radius, card)
			held += 1
			if bool(placed.get("nudge", false)):
				continue
			var pos: Vector2 = placed.get("pos", Vector2.ZERO)
			var rect := Rect2(pos, card)
			var safe := Rect2(16, 60, 1248, 644)
			var pad := float(radius) + 8.0
			var hex := Rect2(anchor - Vector2(pad, pad), Vector2(pad * 2.0, pad * 2.0))
			if not safe.encloses(rect) or rect.intersects(hex):
				bad += 1
	check("tile_place", bad == 0, "bad %d of %d" % [bad, held])
	var packed: String = SaveManager.pack(GameState.to_save())
	var data: Dictionary = SaveManager.unpack(packed)
	check("tile_undo_save", GameState.from_save(data))
	var restored := _named_unit("刘平部")
	var snap: Dictionary = restored.get("undo", {})
	check("tile_undo_load", int(snap.get("mp", -1)) == 2, str(snap))


func _named_unit(unit_name: String) -> Dictionary:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("name", "")) == unit_name:
			return u
	return {}


func _walk_tech_font(node: Node, small: Array) -> void:
	if node is Label or node is Button or node is CheckBox or node is LineEdit or node is OptionButton:
		var text := str(node.text).strip_edges()
		if text != "":
			var sz := (node as Control).get_theme_font_size("font_size")
			if sz > 0 and sz < 13:
				small.append("%s:%d" % [text.substr(0, 12), sz])
	for child in node.get_children():
		_walk_tech_font(child, small)


func check_tech() -> void:
	GameState.new_game()
	GameState.load_tech_sample()
	check("sample_done", GameState.tech_done.size() == 21, str(GameState.tech_done.size()))
	var era2 := TechPlan.era_progress(2)
	check("sample_era2", era2 == Vector2i(4, 17), str(era2))
	check("sample_era", TechPlan.current_era() == 2 and TechPlan.era_complete(1) and not GameState.era_unlocked(3))
	check("state_k03", TechPlan.view_state("K03") == "designing" and GameState.tech_design_prog == 22)
	check("state_i05", TechPlan.view_state("I05") == "blueprint")
	check("state_k02", TechPlan.view_state("K02") == "trial")
	check("state_a05", TechPlan.view_state("A05") == "available")
	check("state_e05", TechPlan.view_state("E05") == "noprereq" and TechPlan.queue_index("E05") == 2)
	check("state_k05", TechPlan.view_state("K05") == "noprereq" and TechPlan.queue_index("K05") == 1)
	check("state_i07", TechPlan.view_state("I07") == "locked")
	var frontier: Array = []
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if TechPlan.is_frontier(id, 2):
			frontier.append(id)
	frontier.sort()
	check("frontier", frontier == ["C07", "E06", "E07", "I07"], ",".join(frontier))
	var sug: Dictionary = TechPlan.suggestion()
	check("suggest_e05", str(sug.get("id", "")) == "E05" and str(sug.get("kind", "")) == "target", str(sug))
	var chain: Array = TechPlan.spine("E05")
	check("spine", chain == ["K02", "K05", "E05"], ",".join(chain))
	var sum: Dictionary = TechPlan.totals("E05")
	check("totals", int(sum.get("power", 0)) == 125 and int(sum.get("craft", 0)) == 126 and int(sum.get("months", 0)) == 20 and int(sum.get("eta", 0)) == 72, str(sum))
	var jumps := ""
	for block_v in TechPlan.blockers():
		var block: Dictionary = block_v
		jumps += str(block.get("jump", "")) + ","
	check("blockers", jumps.contains("workshop") and jumps.contains("industry"), jumps)
	var practice: Dictionary = TechPlan.practice_row("E05")
	check("practice", bool(practice.get("ok", false)) and int(practice.get("have", 0)) == 6 and int(practice.get("need", 0)) == 6, str(practice))
	check("verb_before", TechPlan.primary_verb("E05") == "设为目标")
	TechPlan.set_target("E05")
	check("target_keeps_design", GameState.tech_target == "E05" and GameState.tech_designing == "K03" and GameState.tech_state("E05") != "designing")
	check("verb_after", TechPlan.primary_verb("E05") == "")
	var packed: String = SaveManager.pack(GameState.to_save())
	GameState.tech_target = ""
	GameState.tech_trials = []
	var loaded: Dictionary = SaveManager.unpack(packed)
	var restored := GameState.from_save(loaded)
	var need := 0
	for trial_v in GameState.tech_trials:
		var trial: Dictionary = trial_v
		if str(trial.get("id", "")) == "K02":
			need = int(trial.get("need", 0))
	check("tech_save", restored and GameState.tech_target == "E05" and need == 28 and int(GameState.site_turns.get("mill", 0)) == 6, "need %d target %s" % [need, GameState.tech_target])
	var desk := Engine.get_main_loop().root.find_child("Desk", true, false) as Desk
	check("desk_node", desk != null)
	if desk != null:
		GameState.load_tech_sample()
		desk.open("tech")
		check("tech_focus", desk.mode == "tech" and desk.debug_btns.has("node_E05") and desk.debug_btns.has("tech_accept"))
		var locked: Button = desk.debug_btns.get("node_I07")
		var locked_a := locked.modulate.a if locked != null else -1.0
		check("locked_alpha", locked != null and is_equal_approx(locked_a, 0.65), str(locked_a))
		var small: Array = []
		_walk_tech_font(desk, small)
		check("tech_font", small.is_empty(), ",".join(small))
		check("caption_global", Settings.theme.get_font_size("font_size", "CaptionLabel") == 12)
		var path_shader = load("res://shaders/tech_path.gdshader")
		var path_code := ""
		if path_shader != null:
			path_code = str(path_shader.code)
		check("path_shader", path_code.contains("TIME") and path_code.contains("UV") and not path_code.contains("return"), path_code.substr(0, 60))
		desk.picked = "E05"
		desk._fill()
		check("tech_drawer", desk.debug_btns.has("tech_verb") or desk.debug_btns.has("tech_make_target"))
		desk.tech_view = "overview"
		desk.tech_show_legend = false
		desk.tech_show_parts = false
		desk.picked = ""
		desk._fill()
		var tiles := 0
		for key_v in desk.debug_btns.keys():
			if str(key_v).begins_with("node_"):
				tiles += 1
		check("tech_overview", tiles == 43, str(tiles))
		desk.tech_view = "focus"
		desk.tech_tutorial = 0
		desk._fill()
		check("tech_tutorial", desk.debug_btns.has("tech_skip") and desk.debug_btns.has("tech_next"))
		desk.tech_tutorial = -1
		desk.tech_show_legend = true
		desk._fill()
		check("tech_legend", desk.debug_btns.has("tech_sheet_close"))
		desk.shut()
	GameState.new_game()
