extends RefCounted

const TechPlan = preload("res://scripts/ui/tech_plan.gd")
const TileActions = preload("res://scripts/core/tile_actions.gd")
const EventSystem = preload("res://scripts/core/event_system.gd")
const EnemyPace = preload("res://scripts/core/enemy_pace.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")
const Bargain = preload("res://scripts/core/bargain.gd")
const Omen = preload("res://scripts/core/omen.gd")
const Campaign = preload("res://scripts/core/campaign.gd")

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
	check_playtest()
	check_pacing()
	check_goals()
	check_tech()
	check_camera()
	check_font()
	check_city_close()
	check_feedback()
	check_spec()
	check_round3()
	check_industry()
	check_desk_a()
	if failed > 0:
		push_error("失败 %d 项" % failed)
	else:
		print("ALL TESTS PASSED")
	return failed


func check_city_close() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ui := tree.get_first_node_in_group("game_ui") as GameUI
	if ui == null or ui.desk == null:
		check("city_close", false, "no ui")
		return
	if ui.pacing and ui.pacing.event_open:
		ui.pacing._close_event()
	if ui.goals and ui.goals.blocking():
		ui.goals.dismiss_card()
	var was_tutorial: bool = GameState.tutorial_done
	var was_playing: bool = GameState.playing
	GameState.tutorial_done = true
	GameState.playing = true
	ui.open_city("yanzhou")
	if ui.goals:
		if ui.goals.blocking():
			ui.goals.dismiss_card()
		ui.goals._bar.visible = true
		ui.goals.z_index = 50
	ui._order_layers()
	var stacked: bool = ui.goals != null and ui.desk.get_index() > ui.goals.get_index()
	check("city_stack", stacked)
	_layout(ui)
	var btn: Button = ui.desk.debug_btns.get("desk_close")
	var hit: Control = null
	if btn != null:
		hit = _top_at(ui, btn.get_global_rect().get_center())
	check("city_hit", btn != null and hit == btn, "hit %s btn %s" % [hit, btn.get_global_rect() if btn != null else Rect2()])
	if ui.goals:
		ui.goals.z_index = 90
		ui._order_layers()
		var front: bool = ui.goals.get_index() > ui.desk.get_index() and (ui.pacing == null or ui.goals.get_index() > ui.pacing.get_index())
		check("chapter_front", front)
		ui.goals.z_index = 50
		ui.goals._bar.visible = true
		ui._order_layers()
	var alive := [false]
	if btn != null:
		alive[0] = true
		btn.pressed.connect(func() -> void: alive[0] = is_instance_valid(btn))
		btn.pressed.emit()
	check("city_close", btn != null and ui.desk.mode == "" and not ui.desk.visible and alive[0])
	ui.open_city("yanzhou")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	ui.desk.dim.gui_input.emit(outside)
	check("city_outside", ui.desk.mode == "")
	ui.open_city("kaifeng")
	ui.hide_modals()
	check("city_esc", ui.desk.mode == "")
	ui.open_desk("codex")
	var codex: Button = ui.desk.debug_btns.get("desk_close")
	if codex != null:
		codex.pressed.emit()
	check("codex_close", codex != null and ui.desk.mode == "")
	ui.desk.open("tech")
	ui.desk.tech_show_legend = true
	ui.desk.tech_tutorial = -1
	ui.desk._fill()
	var sheet: Button = ui.desk.debug_btns.get("tech_sheet_close")
	var sheet_alive := [false]
	if sheet != null:
		sheet_alive[0] = true
		sheet.pressed.connect(func() -> void: sheet_alive[0] = is_instance_valid(sheet))
		sheet.pressed.emit()
	check("sheet_alive", sheet != null and sheet_alive[0] and ui.desk.mode == "tech")
	ui.desk._fill()
	check("sheet_close", not ui.desk.tech_show_legend and ui.desk.mode == "tech")
	ui.desk.shut()
	GameState.tutorial_done = was_tutorial
	GameState.playing = was_playing


func _layout(n: Node) -> void:
	if n is Container:
		n.notification(Container.NOTIFICATION_SORT_CHILDREN)
	for c in n.get_children():
		_layout(c)
	if n is CanvasItem:
		(n as CanvasItem).force_update_transform()


func _top_at(n: Node, pos: Vector2) -> Control:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	if n is Control:
		var clip := n as Control
		if clip.is_clipping_contents() and not clip.get_global_rect().has_point(pos):
			return null
	var kids := n.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var child := kids[i] as Node
		var hit := _top_at(child, pos)
		if hit != null:
			return hit
	if n is Control:
		var c := n as Control
		if c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(pos):
			return c
	return null


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


func check_playtest() -> void:
	GameState.new_game()
	var buba := _named_unit("步跋子")
	var gar := _named_unit("延州守军")
	var yan: Dictionary = DataDB.city_by_id("yanzhou")
	var city := Vector2i(int(yan.q), int(yan.r))
	check("buba_spawn", not buba.is_empty() and not gar.is_empty())
	if buba.is_empty() or gar.is_empty():
		return
	check("buba_off_city", int(buba.q) != city.x or int(buba.r) != city.y)
	var reach := Pathfinder.reachable(buba)
	check("buba_city_blocked", not reach.cost.has(city), str(reach.cost.keys()))
	var dist := HexGrid.distance(Vector2i(int(buba.q), int(buba.r)), Vector2i(int(gar.q), int(gar.r)))
	check("buba_beside_yan", dist == 1, str(dist))
	var hp0 := int(buba.hp)
	GameState.resolve_attack(int(buba.uid), int(gar.uid))
	check("buba_counter", int(buba.hp) < hp0 and int(buba.hp) > 0, "%d -> %d" % [hp0, int(buba.hp)])
	check("buba_stayed", int(buba.q) != city.x or int(buba.r) != city.y)
	check("battle_line", GameState.battle_lines.size() == 1 and str(GameState.battle_lines[0]).find("延州") >= 0 and str(GameState.battle_lines[0]).find("攻方 -") >= 0, str(GameState.battle_lines))
	GameState.announce_turn()
	check("battle_notice", GameState.notice.find("步跋子") >= 0 and GameState.advisor_text.find("打起来") >= 0, GameState.notice)
	check("battle_cleared", GameState.battle_lines.is_empty())
	for u_v in GameState.units.duplicate():
		var u: Dictionary = u_v
		if str(u.faction) == "song" and int(u.q) == city.x and int(u.r) == city.y:
			u.hp = 0
	GameState._remove_dead()
	buba.mp = int(buba.max_mp)
	var again := Pathfinder.reachable(buba)
	check("buba_city_still_blocked", not again.cost.has(city), str(again.cost.keys()))
	var song := {"faction": "song", "uid": 99}
	check("xia_held_city", Pathfinder._held_city(buba, city.x, city.y))
	check("song_own_city", not Pathfinder._held_city(song, city.x, city.y))
	GameState.tech_designing = ""
	GameState.tech_queue = []
	GameState.tech_trials = []
	GameState.tech_blueprints = ["M02"]
	GameState.battery = 10
	var waiting: Dictionary = GameState.research_blurb()
	check("blurb_blueprint", str(waiting.get("title", "")).find("图纸待试制") >= 0 and str(waiting.get("body", "")).find("去匠作院") >= 0, str(waiting))
	GameState.tech_blueprints = []
	GameState.battery = GameState.battery_cap()
	var idle: Dictionary = GameState.research_blurb()
	check("blurb_idle", str(idle.get("body", "")).find("选一份图纸") >= 0 and bool(idle.get("alert", false)) and str(idle.get("title", "")).find("电已满") >= 0, str(idle))
	GameState.research_idle_warned = false
	GameState.pending_blueprint = ""
	GameState.battle_lines.clear()
	GameState.announce_turn()
	check("idle_nag", GameState.notice.find("电已满") >= 0 and GameState.research_idle_warned, GameState.notice)
	var plan := TileActions.plan_reach(city, -1, {}, {})
	var joined := ""
	for line_v in plan.get("more", []):
		joined += str(line_v) + "\n"
	check("city_section", joined.find("城市 · 延州") >= 0, joined)


func check_pacing() -> void:
	GameState.new_game()
	var placeholder := false
	for ev_v in DataDB.events:
		var ev: Dictionary = ev_v
		if str(ev.get("body", "")).find("占位") >= 0:
			placeholder = true
	check("event_count", DataDB.events.size() >= 6, str(DataDB.events.size()))
	check("event_copy", not placeholder)
	check("sanchuan_queued", GameState.pending_events.has("sanchuan"))
	check("shaanxi_waits", not GameState.pending_events.has("shaanxi"))
	var saved: Dictionary = GameState.to_save()
	saved.erase("meters")
	saved.erase("pending_events")
	saved.erase("line_history")
	saved.erase("event_flags")
	check("old_save", GameState.from_save(saved) and int(saved.get("save_version", 0)) == 1)
	check("old_meters", int(GameState.meters.get("xia_war", 0)) == 70)
	GameState.new_game()
	var before := GameState.units.size()
	var liu := _named_unit("刘平部")
	check("liu_alive", not liu.is_empty())
	GameState.choose_event("sanchuan", "simulate")
	check("simulate_blocked", not GameState.event_choice.has("sanchuan"))
	GameState.choose_event("sanchuan", "march")
	liu = _named_unit("刘平部")
	var ambush := 0
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("name", "")).find("伏兵") >= 0:
			ambush += 1
	check("march_hp", not liu.is_empty() and int(liu.hp) == 60, str(liu.get("hp", -1)))
	check("march_spawn", ambush == 2 and GameState.units.size() == before + 2, "ambush %d size %d" % [ambush, GameState.units.size()])
	check("march_flag", GameState.event_flags.has("sanchuan_march"))
	GameState.new_game()
	var seen := {}
	var repeat_id := ""
	var used := {}
	for i in 20:
		GameState.turn = i + 1
		GameState.month = (i % 12) + 1
		AdvisorSystem.say_turn()
		var text := GameState.advisor_text
		if seen.has(text):
			repeat_id = text
		seen[text] = true
	for item_v in GameState.line_recent:
		var item: Dictionary = item_v
		var id := str(item.get("id", ""))
		if id == "boot" or id == "":
			continue
		if used.has(id) and int(item.get("turn", 0)) - int(used[id]) < 30:
			repeat_id = id
		used[id] = int(item.get("turn", 0))
	check("advisor_unique", seen.size() == 20 and repeat_id == "", repeat_id)
	EnemyPace.begin()
	check("pace_2x", is_equal_approx(EnemyPace.scale(1.0), 0.5))
	EnemyPace.request_skip()
	check("pace_skip", EnemyPace.scale(1.0) == 0.0)
	EnemyPace.finish()
	check("pace_idle", is_equal_approx(EnemyPace.scale(0.2), 0.2))
	GameState.new_game()


func check_goals() -> void:
	var d1 := Calendar.apply_turn(1)
	var d60 := Calendar.apply_turn(60)
	var d61 := Calendar.apply_turn(61)
	var d68 := Calendar.apply_turn(68)
	var d75 := Calendar.apply_turn(75)
	var d76 := Calendar.apply_turn(76)
	var d86 := Calendar.apply_turn(86)
	check("cal_t1", d1.x == 1040 and d1.y == 1 and d1.z == 1, str(d1))
	check("cal_t60", d60.x == 1044 and d60.y == 12 and d60.z == 1, str(d60))
	check("cal_t61", d61.x == 1045 and d61.y == 1 and d61.z == 2, str(d61))
	check("cal_t68", d68.x == 1046 and d68.y == 3 and d68.z == 2, str(d68))
	check("cal_t75", d75.x == 1047 and d75.y == 5 and d75.z == 2, str(d75))
	check("cal_t76", d76.x == 1047 and d76.y == 7 and d76.z == 1, str(d76))
	check("cal_t86", d86.x == 1048 and d86.y == 5 and d86.z == 1, str(d86))
	check("chapters", DataDB.chapters.size() == 7, str(DataDB.chapters.size()))
	GameState.new_game()
	var long_label := false
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		if str(item.get("text", "")).length() > 14:
			long_label = true
	check("orders_present", GameState.orders.size() >= 1 and GameState.orders.size() <= 3, str(GameState.orders.size()))
	check("orders_short", not long_label)
	check("order_main", GoalSystem.collapsed_text().length() <= 13 and GoalSystem.collapsed_text() != "")
	var food_before := int(GameState.resources.get("food", 0))
	GameState.turn = 60
	GameState.finish_turn()
	check("skip_month", GameState.turn == 61 and GameState.year == 1045 and GameState.month == 1 and GameState.month_span == 2)
	check("skip_once", int(GameState.resources.get("food", 0)) != food_before)
	GameState.year = 1046
	GameState.month = 1
	check("era3_wait", not GameState.era_unlocked(3))
	GameState.month = 3
	check("era3_open", GameState.era_unlocked(3))
	GameState.meters["liao_demand"] = 8
	check("beiding_reduced", GoalSystem.beiding_done() == "reduced")
	GameState.meters["xia_war"] = 10
	check("xiping_done", GoalSystem.xiping_done() and GoalSystem.xiping() >= 85)
	check("lines_pool", DataDB.lines.size() >= 250, str(DataDB.lines.size()))
	check("chapter_art", ResourceLoader.exists("res://ui/art/chapters/chapter_00_sanchuankou.png"))
	check("rebel_hostile", DataDB.hostile("song", "rebel") and not DataDB.hostile("rebel", "xia"))
	GameState.new_game()
	GameState.turn = 27
	EventSystem.scan()
	var demand_before := int(GameState.meters.get("liao_demand", 0))
	var round_ok: bool = Bargain.commit(["fubi"])
	check("bargain_round", round_ok and GameState.bargain_round == 1 and not GameState.event_choice.has("zengbi"), str(GameState.bargain_round))
	check("bargain_cut", int(GameState.meters.get("liao_demand", 0)) == demand_before - 3, str(GameState.meters.get("liao_demand", 0)))
	GameState.turn = 29
	EventSystem.scan()
	check("bargain_again", GameState.pending_events.has("zengbi"))
	Bargain.commit(["refuse"])
	check("bargain_refuse", GameState.event_flags.has("zengbi_refuse"))
	Campaign.on_turn()
	check("liao_spawn", Campaign.alive("liao_south") == 3 and not Campaign.full_push(), str(Campaign.alive("liao_south")))
	GameState.turn = 33
	EventSystem.scan()
	Bargain.settle()
	check("bargain_signed", GameState.event_choice.get("zengbi", "") == "sign" and GameState.event_flags.has("zengbi_signed"))
	GameState.new_game()
	GameState.turn = 41
	var before_units := GameState.units.size()
	GameState.choose_event("wanglun", "fight")
	var slow := false
	var guard := false
	for spawned_v in GameState.units:
		var spawned: Dictionary = spawned_v
		if str(spawned.get("tag", "")) == "wanglun" and int(spawned.get("move_mod", 0)) == 1:
			slow = true
		if str(spawned.get("name", "")) == "徐州厢军":
			guard = true
	check("rebel_spawn", Campaign.alive("wanglun") == 2 and GameState.units.size() == before_units + 3, str(GameState.units.size() - before_units))
	check("rebel_move", slow)
	check("jingdong_guard", guard)
	GameState.new_game()
	GameState.resources["food"] = 10
	GameState.resources["money"] = 10
	GameState.turn = 41
	GameState.choose_event("wanglun", "amnesty")
	check("amnesty_blocked", not GameState.event_choice.has("wanglun"))
	GameState.new_game()
	GameState.resources["food"] = 5000
	var sold: bool = GameState.sell_grain()
	check("grain_sell", sold and int(GameState.resources.get("food", 0)) == 4700 and int(GameState.resources.get("money", 0)) >= 120)
	check("grain_once", not GameState.sell_grain())
	GameState.battery = GameState.battery_cap()
	GameState.tech_designing = ""
	GameState.tech_design_prog = 0
	var prints_before := GameState.tech_blueprints.size()
	GameState.apply_power()
	var sunk: bool = GameState.presearch > 0 or GameState.tech_design_prog > 0 or GameState.tech_blueprints.size() > prints_before
	check("presearch", sunk, "pre %d prog %d" % [GameState.presearch, GameState.tech_design_prog])
	GameState.turn = 12
	check("omen_hao", str(Omen.current().get("title", "")) == "好水川")
	GameState.new_game()
	var start_food := int(GameState.resources.get("food", 0))
	GameState.finish_turn()
	var chip := Calendar.apply_turn(GameState.turn)
	check("date_chip", GameState.year == chip.x and GameState.month == chip.y and GameState.month_span == chip.z)
	var held_food := int(GameState.resources.get("food", 0))
	check("grain_hold", start_food > 0 and held_food * 100 >= start_food * 95, "%d/%d" % [held_food, start_food])
	check("grain_cap", held_food > GameState.monthly_food() * 12, str(held_food))
	check("monthly_need", GameState.monthly_need() > GameState.monthly_food(), str(GameState.monthly_need()))
	check("presearch_cap", GameState.presearch_cap() == 60)
	var morale_before := GameState.morale
	GameState.choose_event("sanchuan", "march")
	check("recovery_window", GameState.recovery_until >= GameState.turn + 10)
	GoalSystem.on_turn()
	var saw_heal := false
	for order_v in GameState.orders:
		var order: Dictionary = order_v
		if str(order.get("id", "")) == "G30":
			saw_heal = true
	check("recovery_order", saw_heal)
	var healed := 0
	while healed < 4 and GameState.morale < morale_before:
		healed += 1
		GameState.recover_army()
		GameState.finish_turn()
	check("recovery_back", GameState.morale >= morale_before, str(GameState.morale))
	GameState.new_game()
	GoalSystem.on_turn()
	if not GameState.orders.is_empty():
		var first: Dictionary = GameState.orders[0]
		var main_id := str(first.get("id", ""))
		var refused: bool = not GoalSystem.shelve(main_id)
		check("shelve_main", refused and GameState.shelved.is_empty() and GameState.notice == "主令不可搁置", GameState.notice)
		var side_id := ""
		var side_born := 0
		if GameState.orders.size() > 1:
			var second: Dictionary = GameState.orders[1]
			side_id = str(second.get("id", ""))
			side_born = int(second.get("born", 0))
		var held := false
		if side_id != "":
			held = GoalSystem.shelve(side_id)
		check("shelve", held)
		if held:
			if GameState.orders.size() >= 3:
				GameState.orders.pop_back()
			GoalSystem.restore(side_id)
			var born_now := -1
			for order_v in GameState.orders:
				var order: Dictionary = order_v
				if str(order.get("id", "")) == side_id:
					born_now = int(order.get("born", -1))
			check("shelve_born", born_now == side_born, "%d/%d" % [born_now, side_born])
		else:
			check("shelve_born", false, "no side order")
	else:
		check("shelve", false, "no order")
		check("shelve_main", false, "no order")
		check("shelve_born", false, "no order")
	GameState.new_game()
	GameState.turn = 38
	GoalSystem.on_turn()
	var g31 := false
	if not GameState.orders.is_empty():
		var lead: Dictionary = GameState.orders[0]
		g31 = str(lead.get("id", "")) == "G31" and bool(lead.get("main", false))
	check("g31_main", g31, str(GameState.orders))
	check("huai_band", Pathfinder.huai(28, 33))
	GameState.rating_floor = 3
	GameState.morale = 10
	check("rating_floor", int(GoalSystem.verdict().get("score", 0)) == 3)
	var probe_atk: Dictionary = {}
	var probe_def: Dictionary = {}
	for unit_v in GameState.units:
		var unit: Dictionary = unit_v
		if probe_atk.is_empty() and str(unit.get("faction", "")) == "song":
			probe_atk = unit
		if probe_def.is_empty() and str(unit.get("faction", "")) == "xia":
			probe_def = unit
	probe_def["q"] = 14
	probe_def["r"] = 22
	var xing := CombatResolver.assess(probe_atk, probe_def)
	var xing_bonus := false
	for part_v in xing.get("def_parts", []):
		var part: Dictionary = part_v
		if str(part.get("name", "")) == "兴庆" and int(part.get("value", 0)) == 6:
			xing_bonus = true
	check("xingqing_bonus", xing_bonus)
	GameState.new_game()


func check_feedback() -> void:
	GameState.new_game()
	GameState.weather_id = "clear"
	var yan: Dictionary = DataDB.city_by_id("yanzhou")
	var city := Vector2i(int(yan.q), int(yan.r))
	check("yan_cap", GameState.city_cap(yan) == 2, str(GameState.city_cap(yan)))
	var shi := _named_unit("石元孙部")
	var liu := _named_unit("刘平部")
	var gar := _named_unit("延州守军")
	var buba := _named_unit("步跋子")
	check("garrison_cast", not shi.is_empty() and not liu.is_empty() and not gar.is_empty() and not buba.is_empty())
	if shi.is_empty():
		return
	var home := Vector2i(int(shi.q), int(shi.r))
	var reach := Pathfinder.reachable(shi)
	check("song_enters_zhou", reach.cost.has(city), str(reach.cost.keys()))
	var plan := TileActions.plan(city, int(shi.uid))
	var enter := _action(plan, "enter")
	check("enter_label", str(enter.get("label", "")).find("入城驻防") >= 0 and str(enter.get("label", "")).find("1/2") >= 0 and bool(enter.get("enabled", false)), str(enter))
	check("xia_still_out", not Pathfinder.reachable(buba).cost.has(city))
	GameState.set_pos(int(shi.uid), city)
	var full := TileActions.plan(city, int(liu.uid))
	var blocked := _action(full, "enter")
	check("city_full_reason", str(blocked.get("reason", "")).find("延州已满 2/2") >= 0 and not bool(blocked.get("enabled", false)), str(blocked))
	check("city_full_path", not Pathfinder.reachable(liu).cost.has(city))
	GameState.set_pos(int(shi.uid), home)
	shi.mp = int(shi.max_mp)
	GameState.weather_id = "snow"
	var snow := TileActions.plan(city, int(shi.uid))
	var snow_enter := _action(snow, "enter")
	check("snow_reason", str(snow_enter.get("reason", "")).find("雪天 −1") >= 0 and not bool(snow_enter.get("enabled", false)), str(snow_enter))
	check("snow_caption", GameState.move_caption(shi).find("雪天实走") >= 0, GameState.move_caption(shi))
	GameState.weather_id = "clear"
	shi.mp = 0
	check("spent_caption", GameState.move_caption(shi).find("移动 0/2") >= 0, GameState.move_caption(shi))
	shi.mp = int(shi.max_mp)
	GameState.set_pos(int(shi.uid), city)
	gar.hp = 30
	shi.hp = 100
	var top := GameState.city_top(city)
	var expect := int(shi.uid) if GameState.unit_power(shi) >= GameState.unit_power(gar) else int(gar.uid)
	check("city_top", int(top.get("uid", -1)) == expect and int(GameState.defender_at(city).get("uid", -1)) == expect, str(top.get("name", "")))
	top.hp = 0
	GameState._remove_dead()
	check("garrison_remains", GameState.units_at(city).size() == 1, str(GameState.units_at(city).size()))
	GameState.new_game()
	GameState.weather_id = "clear"
	gar = _named_unit("延州守军")
	gar.hp = 80
	GameState.restore_movement()
	check("garrison_heal", int(_named_unit("延州守军").hp) == 90, str(_named_unit("延州守军").hp))
	gar = _named_unit("延州守军")
	gar.hp = 80
	gar["attacked"] = true
	GameState.restore_movement()
	check("no_heal_after_attack", int(_named_unit("延州守军").hp) == 80, str(_named_unit("延州守军").hp))
	GameState.new_game()
	var turn0 := GameState.turn
	check("end_needs_confirm", TurnManager.needs_end_confirm())
	TurnManager.request_end()
	check("end_waits", GameState.turn == turn0 and TurnManager.confirm_open and not TurnManager.busy)
	TurnManager.dismiss_confirm()
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("faction", "")) == "song" and int(u.get("mp", 0)) > 0:
			u["skip_turn"] = true
	check("end_standby_clear", not TurnManager.needs_end_confirm() and not TurnManager.confirm_open)
	GameState.new_game()
	var walker := _named_unit("刘平部")
	var before := GameState.hint_mp_seen
	GameState.spend_mp(int(walker.uid), int(walker.mp))
	check("hint_once", not before and GameState.hint_mp_seen and GameState.advisor_text.find("走完了") >= 0, GameState.advisor_text)
	var said := GameState.advisor_text
	var other := _named_unit("石元孙部")
	GameState.spend_mp(int(other.uid), int(other.mp))
	check("hint_stays", GameState.hint_mp_seen and GameState.advisor_text == said)
	var ids: Array = []
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if GameState.tech_state(id) == "available":
			ids.append(id)
	check("design_pool", ids.size() >= 4, str(ids.size()))
	if ids.size() < 4:
		return
	GameState.tech_design_prog = 0
	check("design_start", GameState.start_design(str(ids[0])))
	GameState.tech_design_prog = 9
	check("design_queue", GameState.start_design(str(ids[1])) and GameState.tech_designing == str(ids[0]) and GameState.tech_design_prog == 9 and str(GameState.tech_queue[0]) == str(ids[1]))
	check("design_cap", GameState.start_design(str(ids[2])) and GameState.start_design(str(ids[3])) and not GameState.start_design(str(ids[0])) )
	# ids[0] is designing, so a fifth available may not exist. Cap is queue size.
	check("queue_at_cap", GameState.tech_queue.size() == 3, str(GameState.tech_queue))
	GameState.tech_queue = [str(ids[1])]
	GameState.tech_designing = str(ids[0])
	GameState.tech_design_prog = 9
	check("swap_keeps", GameState.swap_design(str(ids[1])) and GameState.tech_designing == str(ids[1]) and str(GameState.tech_queue[0]) == str(ids[0]) and int(GameState.tech_paused.get(str(ids[0]), -1)) == 9)
	GameState.pause_design()
	check("swap_resumes", GameState.tech_designing == str(ids[0]) and GameState.tech_design_prog == 9, "%s %d" % [GameState.tech_designing, GameState.tech_design_prog])
	GameState.tech_trials = [{"id": str(ids[2]), "prog": 1, "need": 3}]
	var blurb := GameState.research_blurb()
	check("blurb_both", str(blurb.get("design", "")).find("设计") >= 0 and str(blurb.get("trial", "")).find("试制") >= 0, str(blurb))
	GameState.tech_blueprints = ["Z1", "Z2", "Z3"]
	GameState.tech_design_prog = GameState.design_need(GameState.tech_designing)
	var held := GameState.tech_designing
	GameState._research_tick()
	check("blueprint_cap", GameState.tech_blueprints.size() == 3 and GameState.tech_designing == held and GameState.notice.find("试制") >= 0, GameState.notice)


func _action(plan: Dictionary, id: String) -> Dictionary:
	for a_v in plan.get("actions", []):
		var action: Dictionary = a_v
		if str(action.get("id", "")) == id:
			return action
	return {}


func _named_unit(unit_name: String) -> Dictionary:
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("name", "")) == unit_name:
			return u
	return {}


func _label_boxes(root: Node) -> String:
	if root == null:
		return "无根"
	var hidden: Array = []
	var current: Node = root
	var layer: CanvasLayer = null
	while current != null:
		if layer == null and current is CanvasLayer:
			layer = current
		if current is CanvasItem and not (current as CanvasItem).visible:
			hidden.append(current)
			(current as CanvasItem).visible = true
		current = current.get_parent()
	if layer != null:
		layer.visible = false
		layer.visible = true
	_layout(root)
	var err := _label_boxes_now(root)
	for item_v in hidden:
		if item_v is CanvasItem:
			(item_v as CanvasItem).visible = false
		elif item_v is Window:
			(item_v as Window).visible = false
	return err


func _label_boxes_now(root: Node) -> String:
	var labels: Array = []
	_collect_labels(root, labels)
	var rects: Array = []
	var names: Array = []
	var seen := 0
	for lab_v in labels:
		var lab := lab_v as Label
		if lab == null or not _shown(lab):
			continue
		var text := lab.text.strip_edges()
		if text == "":
			continue
		seen += 1
		var own := lab.get_global_rect()
		var font := lab.get_theme_font_size("font_size")
		if font < 1:
			font = 13
		var parent := lab.get_parent() as Control
		if own.size.x + 0.5 < float(font):
			return "不足一字『%s』宽%.0f" % [text.substr(0, 10), own.size.x]
		if parent != null and parent.size.x > 4.0 and parent.size.y > 4.0:
			if not parent.get_global_rect().grow(2.0).encloses(own):
				return "越界『%s』" % text.substr(0, 10)
		var vis := _clipped_rect(lab)
		if vis.size.x < 2.0 or vis.size.y < 2.0:
			continue
		rects.append(vis)
		names.append(text.substr(0, 10))
	if seen == 0:
		return "没有可见标签"
	for i in rects.size():
		var a: Rect2 = rects[i]
		for j in range(i + 1, rects.size()):
			var b: Rect2 = rects[j]
			if a.grow(-1.0).intersects(b.grow(-1.0)):
				return "重叠『%s』『%s』" % [str(names[i]), str(names[j])]
	return ""


func _shown(node: CanvasItem) -> bool:
	var current: Node = node
	while current is CanvasItem:
		if not (current as CanvasItem).visible:
			return false
		current = current.get_parent()
	return node.is_inside_tree()


func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for child in node.get_children():
		_collect_labels(child, out)


func _clipped_rect(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p is Control:
		var clip := p as Control
		if clip.is_clipping_contents():
			r = r.intersection(clip.get_global_rect())
			if r.size.x <= 0.0 or r.size.y <= 0.0:
				return Rect2()
		p = p.get_parent()
	return r


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
	check("state_e05", TechPlan.view_state("E05") == "noprereq" and TechPlan.queue_index("E05") == 0)
	check("state_k05", TechPlan.view_state("K05") == "noprereq" and TechPlan.queue_index("K05") == 0)
	check("state_k04", TechPlan.view_state("K04") == "blueprint")
	check("sample_queue", GameState.tech_queue.is_empty())
	check("sample_slots", GameState.trial_slots() == 1 and not GameState.edicts_done.has("gewuyuan"))
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
	check("totals", int(sum.get("power", 0)) == 125 and int(sum.get("craft", 0)) == 120 and int(sum.get("months", 0)) == 20 and int(sum.get("eta", 0)) == 72, str(sum))
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
	check("tech_save", restored and GameState.tech_target == "E05" and need == 4 and int(GameState.site_turns.get("mill", 0)) == 6, "need %d target %s" % [need, GameState.tech_target])
	var desk := Engine.get_main_loop().root.find_child("Desk", true, false) as Desk
	check("desk_node", desk != null)
	if desk != null:
		GameState.load_tech_sample()
		desk.open("tech")
		check("tech_focus", desk.mode == "tech" and desk.debug_btns.has("node_E05") and desk.debug_btns.has("tech_accept"))
		var locked: Button = desk.debug_btns.get("node_I07")
		var locked_a := locked.modulate.a if locked != null else -1.0
		check("locked_alpha", locked != null and is_equal_approx(locked_a, 0.6), str(locked_a))
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


func _stamp(at: int) -> void:
	GameState.turn = at
	var date := Calendar.apply_turn(at)
	GameState.year = date.x
	GameState.month = date.y
	GameState.month_span = date.z


func _era1_done() -> void:
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		var id := str(tech.get("id", ""))
		if int(tech.get("era", 1)) == 1 and not GameState.tech_done.has(id):
			GameState.tech_done.append(id)


func _walk_text(node: Node, bucket: Array) -> void:
	if node is Label or node is Button:
		var text := str(node.text).strip_edges()
		if text != "":
			bucket.append(text)
	for child in node.get_children():
		_walk_text(child, bucket)


func check_spec() -> void:
	GameState.new_game()
	GameState.load_tech_sample()
	var trial: Dictionary = GameState.tech_trials[0]
	var trial_keys: Array = trial.keys()
	trial_keys.sort()
	check("b_trial", GameState.tech_trials.size() == 1 and str(trial.get("id", "")) == "K02" and int(trial.get("prog", 0)) == 2 and int(trial.get("need", 0)) == 4 and trial_keys == ["id", "need", "prog"], str(trial))
	var craft_mid := int(TechPlan.totals("E05").get("craft", -1))
	trial["prog"] = 0
	var craft_start := int(TechPlan.totals("E05").get("craft", -1))
	trial["prog"] = int(trial.get("need", 1))
	var craft_end := int(TechPlan.totals("E05").get("craft", -1))
	trial["prog"] = 2
	check("b_craft", craft_mid == 120 and craft_start == 120 and craft_end == 120, "%d %d %d" % [craft_mid, craft_start, craft_end])
	check("b_sheets", GameState.tech_blueprints == ["I05", "K04"] and TechPlan.view_state("I05") == "blueprint" and TechPlan.view_state("K04") == "blueprint")
	check("b_power", GameState.battery == 46 and GameState.battery_bonus == 0 and GameState.battery_cap() == 80 and int(GameState.resources.get("copper", 0)) == 14 and GameState.blueprint_cap() == 3)
	check("b9_view", TechPlan.view_state("A05") == "available" and TechPlan.view_state("I06") == "noprereq" and TechPlan.view_state("E04") == "noprereq")
	check("b_sites", int(GameState.site_turns.get("mill", 0)) == 6 and int(GameState.site_turns.get("coal", 0)) == 4 and int(GameState.site_turns.get("coke", 0)) == 6, str(GameState.site_turns))
	var row_i04: Dictionary = TechPlan.practice_row("I04")
	var row_c06: Dictionary = TechPlan.practice_row("C06")
	var row_i07: Dictionary = TechPlan.practice_row("I07")
	check("b_i04", bool(row_i04.get("ok", false)) and int(row_i04.get("have", 0)) == 4 and int(row_i04.get("need", 0)) == 4, str(row_i04))
	check("b_c06", bool(row_c06.get("ok", false)) and int(row_c06.get("have", 0)) == 6 and int(row_c06.get("need", 0)) == 4, str(row_c06))
	check("b_i07", not bool(row_i07.get("ok", false)) and int(row_i07.get("have", 0)) == 6 and int(row_i07.get("need", 0)) == 12, str(row_i07))
	var block_text := ""
	var blocks: Array = TechPlan.blockers()
	if not blocks.is_empty():
		block_text = str(blocks[0].get("text", ""))
	check("b_block", block_text == "试制槽 1/1 满，耐火砖与坩埚排队中" and str(blocks[0].get("jump", "")) == "workshop", block_text)
	GameState.edicts_done.append("gewuyuan")
	check("b_slot_open", GameState.trial_slots() == 2)
	GameState.load_tech_sample()
	check("b_slot_back", GameState.trial_slots() == 1 and not GameState.edicts_done.has("gewuyuan"))
	var said := GameState.advisor_text
	TechPlan.set_target("E05")
	check("a1_queue", GameState.tech_target == "E05" and GameState.tech_queue.is_empty() and GameState.advisor_text == said and not GameState.line_history.has("target_queue"))
	for trial_v in GameState.tech_trials:
		var row: Dictionary = trial_v
		if str(row.get("id", "")) == "K02":
			row["prog"] = int(row.get("need", 1)) - 1
	GameState.battery = 40
	GameState.finish_turn()
	check("a2_enqueue", GameState.tech_done.has("K02") and (GameState.tech_queue.has("K05") or GameState.tech_designing == "K05") and GameState.notice.find("目标路线 · 增速齿轮与铸铁轴承 进队列") >= 0, GameState.notice)
	GameState.announce_turn()
	check("a2_advisor", GameState.advisor_text.find("前置齐了") >= 0 and GameState.line_history.has("target_queue"), GameState.advisor_text)
	GameState.resources["craft"] = 800
	GameState.resources["iron"] = 80
	GameState.resources["copper"] = 80
	GameState.resources["wood"] = 80
	GameState.tech_blueprints = []
	var guard := 0
	while not GameState.tech_done.has("K05") and guard < 40:
		guard += 1
		if GameState.tech_blueprints.has("K05") and GameState.tech_trials.is_empty():
			GameState.start_trial("K05")
		GameState.battery = GameState.battery_cap()
		GameState.finish_turn()
	check("a3_enqueue", GameState.tech_done.has("K05") and (GameState.tech_queue.has("E05") or GameState.tech_designing == "E05") and GameState.notice.find("水轮发电机") >= 0, "guard %d design %s queue %s notice %s" % [guard, GameState.tech_designing, str(GameState.tech_queue), GameState.notice])
	GameState.tech_queue.erase("E05")
	GameState.tech_blueprints.erase("E05")
	if GameState.tech_designing == "E05":
		GameState.tech_designing = ""
		GameState.tech_design_prog = 0
	GameState.tech_target = "E05"
	GameState.tech_trials = [{"id": "E05", "prog": 2, "need": 3}]
	GameState.finish_turn()
	check("a4_done", GameState.tech_target == "" and GameState.tech_done.has("E05") and GameState.notice.find("目标达成 · 水轮发电机") >= 0, GameState.notice)
	GameState.new_game()
	_era1_done()
	_stamp(40)
	GameState.tech_designing = "X01"
	GameState.tech_design_prog = 0
	GameState.tech_queue = ["A05", "E02", "K04"]
	GameState.tech_target = "C07"
	GameState.tech_target_skip = []
	GameState.target_added = []
	GameState.target_wait_noted = []
	GameState.notice = ""
	GameState.finish_turn()
	check("a5_wait", GameState.tech_queue.size() == 3 and GameState.notice.find("等队列空位（3/3）") >= 0 and GameState.notice.find("焦炭冶铁") >= 0, GameState.notice)
	GameState.announce_turn()
	var wait_text := GameState.advisor_text
	check("a5_advisor", wait_text.find("门口") >= 0, wait_text)
	GameState.notice = ""
	GameState.advisor_text = "quiet"
	GameState.finish_turn()
	GameState.announce_turn()
	check("a5_once", GameState.notice.find("等队列空位") < 0 and GameState.advisor_text == "quiet", GameState.notice)
	GameState.new_game()
	_era1_done()
	_stamp(40)
	GameState.tech_blueprints = []
	GameState.tech_trials = []
	GameState.tech_designing = "A05"
	GameState.tech_design_prog = GameState.design_need("A05")
	GameState.tech_queue = ["E02", "K04", "M06"]
	GameState.tech_target = "C07"
	GameState.tech_target_skip = []
	GameState.target_added = []
	GameState.target_wait_noted = []
	GameState.battery = GameState.battery_cap()
	GameState.finish_turn()
	check("a6_refill", GameState.tech_designing == "E02" and GameState.tech_queue.size() == 3 and GameState.tech_queue.has("I04"), "%s %s" % [GameState.tech_designing, str(GameState.tech_queue)])
	GameState.new_game()
	GameState.load_tech_sample()
	TechPlan.set_target("E05")
	for trial_v3 in GameState.tech_trials:
		var row3: Dictionary = trial_v3
		if str(row3.get("id", "")) == "K02":
			row3["prog"] = int(row3.get("need", 1)) - 1
	GameState.battery = 40
	GameState.finish_turn()
	GameState.remove_queued("K05")
	check("a7_skip", GameState.tech_target_skip.has("K05") and not GameState.tech_queue.has("K05"))
	for _step in 3:
		GameState.battery = 30
		GameState.finish_turn()
	var sug: Dictionary = TechPlan.suggestion()
	check("a7_stays", not GameState.tech_queue.has("K05") and GameState.tech_designing != "K05" and str(sug.get("title", "")).find("排进设计") >= 0, "%s %s" % [str(sug), str(GameState.tech_queue)])
	GameState.tech_designing = "K03"
	GameState.tech_design_prog = 1
	GameState.tech_queue = []
	check("a8_manual", GameState.start_design("K05") and GameState.tech_queue.has("K05") and not GameState.tech_target_skip.has("K05"))
	var kept: Array = GameState.tech_queue.duplicate()
	TechPlan.clear_target()
	check("a9_clear", GameState.tech_target == "" and GameState.tech_target_skip.is_empty() and GameState.tech_queue == kept)
	GameState.tech_target = "E05"
	GameState.tech_target_skip = ["K05"]
	GameState.tech_queue = ["A05", "E02"]
	var packed: String = SaveManager.pack(GameState.to_save())
	GameState.tech_target = ""
	GameState.tech_target_skip = []
	GameState.tech_queue = []
	var loaded: Dictionary = SaveManager.unpack(packed)
	check("a10_load", GameState.from_save(loaded) and GameState.tech_target == "E05" and GameState.tech_target_skip == ["K05"] and GameState.tech_queue == ["A05", "E02"])
	var old: Dictionary = GameState.to_save()
	old.erase("tech_target_skip")
	old["tech_target"] = "E05"
	check("a11_old", GameState.from_save(old) and GameState.tech_target == "E05" and GameState.tech_target_skip.is_empty())
	GameState.new_game()
	_era1_done()
	_stamp(40)
	var first := ""
	var later := ""
	for tech_v2 in DataDB.techs:
		var tech2: Dictionary = tech_v2
		var id2 := str(tech2.get("id", ""))
		if GameState.tech_state(id2) != "available":
			continue
		if first == "":
			first = id2
		elif later == "":
			later = id2
			break
	GameState.tech_designing = ""
	GameState.tech_design_prog = 0
	GameState.tech_queue = []
	GameState.tech_target = later
	GameState.tech_target_skip = []
	GameState.target_added = []
	GameState.target_notice = ""
	GameState.battery = GameState.battery_cap()
	GameState._pour_design(5)
	check("a12_pour", later != "" and later != first and GameState.tech_designing == later and GameState.notice.find("开始设计") >= 0 and GameState.notice.find("电满了") < 0, "first %s later %s design %s notice %s" % [first, later, GameState.tech_designing, GameState.notice])
	GameState.new_game()
	_era1_done()
	_stamp(40)
	GameState.tech_done.append("I04")
	TechPlan.set_target("E04")
	check("a13_pair", GameState.tech_queue == ["E02", "I05"] and GameState.notice.find("铜线拉丝与丝漆绝缘、耐火砖与坩埚") >= 0 and GameState.notice.find("\n") < 0, "%s %s" % [str(GameState.tech_queue), GameState.notice])
	check("a13_silent", not GameState.line_history.has("target_queue"))
	GameState.new_game()
	_era1_done()
	_stamp(40)
	TechPlan.set_target("C07")
	check("a14_era2", GameState.tech_queue.has("I04") and not GameState.tech_queue.has("C07") and not GameState.era_unlocked(3), str(GameState.tech_queue))
	GameState.tech_done.append("I04")
	GameState.tech_queue.erase("I04")
	GameState.refill_target_queue("turn")
	check("a14_locked", not GameState.tech_queue.has("C07") and not GameState.era_unlocked(3))
	_stamp(67)
	GameState.tech_designing = "X01"
	GameState.tech_design_prog = 0
	GameState.notice = ""
	GameState.finish_turn()
	check("a14_open", GameState.turn == 68 and GameState.era_unlocked(3) and GameState.tech_queue.has("C07") and GameState.notice.find("碎石官道") >= 0, "turn %d queue %s notice %s" % [GameState.turn, str(GameState.tech_queue), GameState.notice])
	GameState.new_game()
	check("c1_cap", GameState.blueprint_cap() == 3 and GameState.blueprint_bonus == 0)
	var liao: Dictionary = DataDB.chapter_by_id.get("liao", {})
	GameState.meters["liao_demand"] = 8
	check("c2_state", GoalSystem.chapter_state(liao) == "done")
	GoalSystem.grant_chapter(liao, "done")
	var fly := ""
	for item_v in GameState.reward_queue:
		var item: Dictionary = item_v
		if str(item.get("text", "")).find("图纸库") >= 0:
			fly = str(item.get("text", ""))
	check("c2_bonus", GameState.blueprint_bonus == 1 and GameState.blueprint_cap() == 4 and fly == "图纸库 +1（上限 4）", fly)
	var heyi: Dictionary = DataDB.chapter_by_id.get("heyi", {})
	GoalSystem.grant_chapter(heyi, "done")
	var fly2 := ""
	for item_v2 in GameState.reward_queue:
		var item2: Dictionary = item_v2
		if str(item2.get("text", "")).find("图纸库") >= 0:
			fly2 = str(item2.get("text", ""))
	check("c3_bonus", GameState.blueprint_cap() == 5 and fly2 == "图纸库 +1（上限 5）", fly2)
	GameState.new_game()
	var craft_before := int(GameState.resources.get("craft", 0))
	var morale_before := GameState.morale
	GoalSystem.grant_chapter(DataDB.chapter_by_id.get("liao", {}), "partial")
	check("c4_partial", GameState.blueprint_bonus == 0 and int(GameState.resources.get("craft", 0)) == craft_before + 10 and GameState.morale == morale_before + 1)
	GameState.new_game()
	GoalSystem.grant_chapter(DataDB.chapter_by_id.get("liao", {}), "done")
	GoalSystem.grant_chapter(DataDB.chapter_by_id.get("liao", {}), "done")
	check("c5_once", GameState.blueprint_bonus == 1)
	GameState.new_game()
	GameState.tech_blueprints = ["A01", "M01", "C01"]
	GameState.tech_designing = "M02"
	GameState.tech_design_prog = GameState.design_need("M02")
	GameState.tech_target = ""
	GameState.tech_queue = []
	GoalSystem.grant_chapter(DataDB.chapter_by_id.get("liao", {}), "done")
	GameState._research_tick()
	check("c6_enter", GameState.tech_blueprints.size() == 4 and GameState.tech_blueprints.has("M02"), str(GameState.tech_blueprints))
	GameState.blueprint_bonus = 1
	var again: String = SaveManager.pack(GameState.to_save())
	GameState.blueprint_bonus = 0
	check("c7_save", GameState.from_save(SaveManager.unpack(again)) and GameState.blueprint_bonus == 1)
	var bare: Dictionary = GameState.to_save()
	bare.erase("blueprint_bonus")
	bare["chapter_rewarded"] = {"liao": "done", "heyi": "done"}
	check("c8_infer", GameState.from_save(bare) and GameState.blueprint_cap() == 5 and GameState.blueprint_bonus == 2)
	var huge: Dictionary = GameState.to_save()
	huge["blueprint_bonus"] = 7
	check("c9_clamp", GameState.from_save(huge) and GameState.blueprint_bonus == 2 and GameState.blueprint_cap() == 5)
	GameState.new_game()
	GoalSystem.grant_chapter(DataDB.chapter_by_id.get("forts", {}), "done")
	check("c10_other", GameState.blueprint_bonus == 0 and GameState.blueprint_cap() == 3 and GameState.battery_bonus == 10)
	GameState.new_game()
	_stamp(67)
	check("d1_wait", GameState.year == 1046 and GameState.month == 1 and not GameState.era_unlocked(3))
	_stamp(68)
	check("d2_open", GameState.month == 3 and GameState.era_unlocked(3))
	_stamp(67)
	GameState.finish_turn()
	check("d3_tick", GameState.turn == 68 and GameState.era_unlocked(3))
	GameState.load_tech_sample()
	_stamp(68)
	check("d4_c07", TechPlan.view_state("C07") == "available" and TechPlan.current_era() == 3)
	GameState.load_tech_sample()
	check("d5_sample", not GameState.era_unlocked(3))
	var extra := 0
	for tech_v3 in DataDB.techs:
		var tech3: Dictionary = tech_v3
		var id3 := str(tech3.get("id", ""))
		if int(tech3.get("era", 1)) != 2 or GameState.tech_done.has(id3):
			continue
		GameState.tech_done.append(id3)
		extra += 1
		if GameState._era_done_count(2) >= 11:
			break
	check("d6_count", extra >= 7 and GameState.era_unlocked(3) and GameState.turn == 52)
	var desk := Engine.get_main_loop().root.find_child("Desk", true, false) as Desk
	check("d7_desk", desk != null)
	if desk != null:
		GameState.load_tech_sample()
		desk.tech_tutorial = -1
		desk.open("tech")
		var board: Node = desk.host.get_child(0)
		check("d7_lock", board.has_method("_lock_head") and str(board.call("_lock_head", 3)) == "第 68 回合开" and TechPlan._lock_label(3) == "第 68 回合开")
		var lines: Array = []
		_walk_text(desk, lines)
		var joined := "\n".join(PackedStringArray(lines))
		var old_turn := "第 75 " + "回合"
		var old_lock := "T75" + "开"
		check("d7_copy", joined.find("第 68 回合") >= 0 and joined.find(old_turn) < 0 and joined.find(old_lock) < 0 and joined.find("第 68 回合开") >= 0, joined)
		_stamp(68)
		check("d8_open", str(board.call("_lock_head", 3)) == "已开")
		desk.shut()
	check("d9_span", str(DataDB.eras[1].get("span", "")) == "T31–67" and str(DataDB.eras[2].get("span", "")) == "T68–86")
	var legacy: Dictionary = GameState.to_save()
	legacy["turn"] = 70
	check("d11_old", GameState.from_save(legacy) and GameState.era_unlocked(3) and int(legacy.get("save_version", 0)) == 1)
	GameState.new_game()
	_stamp(76)
	GameState.tech_done.append("C07")
	GoalSystem.on_turn()
	var craft0 := int(GameState.resources.get("craft", 0))
	var queued_end := false
	for card_v in GameState.card_queue:
		if str(card_v) == "end:gewu":
			queued_end = true
	var gewu: Dictionary = DataDB.chapter_by_id.get("gewu", {})
	check("d12_state", queued_end and GoalSystem.chapter_state(gewu) == "done")
	GoalSystem.grant_chapter(gewu, "done")
	check("d12_pay", GameState.battery_bonus == 10 and int(GameState.resources.get("craft", 0)) == craft0 + 15, "bonus %d craft %d" % [GameState.battery_bonus, int(GameState.resources.get("craft", 0))])
	GameState.new_game()
	var ui := Engine.get_main_loop().get_first_node_in_group("game_ui") as GameUI
	if ui != null and ui.goals != null:
		ui.goals._clear_flights()
		ui.goals.fly_time = 8.0
		GameState.reward_queue = [
			{"text": "匠 +20"},
			{"text": "皇威 +2"},
			{"text": "图纸库 +1（上限 4）"},
		]
		ui.goals._drain_rewards()
		ui.goals.tick(0.25)
		var seen := ""
		var wide := 0.0
		for mark_v in ui.goals.fly_debug():
			var mark: Dictionary = mark_v
			seen += str(mark.get("t", "")) + "|"
			if str(mark.get("t", "")).begins_with("图纸库"):
				wide = float(mark.get("w", 0))
		check("c_fly", seen.find("匠 +20") >= 0 and seen.find("皇威 +2") >= 0 and seen.find("图纸库 +1（上限 4）") >= 0 and wide >= 200.0, seen)
		ui.goals._clear_flights()
		ui.goals.fly_time = 1.0
	else:
		check("c_fly", false, "no hud")


func check_round3() -> void:
	var date_line := "庆历六年春，格物图翻到第三卷「火器初兴」。坩埚炼钢、燧发机构都能画了。陛下，工匠们的眉毛，这回怕是真保不住了。"
	var early_line := "时代二做满十一项，格物图提前翻到第三卷「火器初兴」。坩埚炼钢、燧发机构都能画了。陛下，工匠们的眉毛，这回怕是真保不住了。"
	var gewu: Dictionary = DataDB.chapter_by_id.get("gewu", {})
	check("ch5_text", str(gewu.get("main", "")) == "画出一张时代三图纸" and str(gewu.get("check", "")) == "era3_blueprint")
	check("p_gate", GameState.practice_gate_on == false)
	GameState.new_game()
	check("ch5_open", GoalSystem.chapter_state(gewu) == "open")
	check("ch5_legacy", GoalSystem.chapter_state({"check": "era3"}) == "open")
	GameState.tech_designing = "C07"
	GameState.tech_design_prog = 1
	check("ch5_partial", GoalSystem.chapter_state(gewu) == "partial")
	GameState.tech_designing = ""
	GameState.tech_design_prog = 0
	GameState.tech_paused = {"E06": 4}
	check("ch5_paused", GoalSystem.chapter_state(gewu) == "partial")
	GameState.tech_paused = {}
	GameState.tech_blueprints = ["C07"]
	check("ch5_sheet", GoalSystem.chapter_state(gewu) == "done")
	GameState.tech_blueprints = []
	GameState.tech_trials = [{"id": "E06", "prog": 1, "need": 7}]
	check("ch5_trial", GoalSystem.chapter_state(gewu) == "done")
	GameState.tech_trials = []
	GameState.tech_done.append("I07")
	check("ch5_done_tech", GoalSystem.chapter_state(gewu) == "done")
	check("ch5_legacy_done", GoalSystem.chapter_state({"check": "era3"}) == "done")
	GameState.tech_done.erase("I07")
	GameState.tech_blueprints = ["K02", "K04", "A05"]
	GameState.tech_designing = "C07"
	GameState.tech_design_prog = GameState.design_need("C07")
	check("ch5_full", GoalSystem.chapter_state(gewu) == "done", str(GameState.tech_design_prog))
	GameState.new_game()
	GameState.tech_blueprints = ["K02"]
	GameState.tech_designing = "K03"
	GameState.tech_design_prog = 3
	GameState.tech_trials = [{"id": "K04", "prog": 1, "need": 3}]
	check("ch5_era2", GoalSystem.chapter_state(gewu) == "open")
	GameState.new_game()
	var craft0 := int(GameState.resources.get("craft", 0))
	GoalSystem.grant_chapter(gewu, "done")
	check("ch5_pay_done", int(GameState.resources.get("craft", 0)) == craft0 + 15 and GameState.battery_bonus == 10 and GameState.presearch_bonus == 10)
	GoalSystem.grant_chapter(gewu, "done")
	check("ch5_pay_once", int(GameState.resources.get("craft", 0)) == craft0 + 15 and GameState.battery_bonus == 10 and GameState.presearch_bonus == 10)
	GameState.new_game()
	var craft1 := int(GameState.resources.get("craft", 0))
	GoalSystem.grant_chapter(gewu, "partial")
	check("ch5_pay_partial", int(GameState.resources.get("craft", 0)) == craft1 + 8 and GameState.battery_bonus == 0 and GameState.presearch_bonus == 10)
	GameState.new_game()
	_stamp(65)
	check("ch5_hint", GoalSystem.era3_hint() == "时代三 T68 开放", GoalSystem.era3_hint())
	_stamp(68)
	check("ch5_hint_open", GoalSystem.era3_hint() == "")
	GameState.tech_blueprints = ["A01", "M01", "C01"]
	check("ch5_hint_full", GoalSystem.era3_hint() == "图纸库已满，先去试制")
	GameState.new_game()
	_stamp(75)
	GameState.tech_designing = "C07"
	GameState.tech_design_prog = GameState.design_need("C07") - 1
	GameState.battery = 40
	GameState.tech_blueprints = []
	GameState.finish_turn()
	GoalSystem.on_turn()
	var queued := false
	for card_v in GameState.card_queue:
		if str(card_v) == "end:gewu":
			queued = true
	check("ch5_tick", GameState.turn == 76 and GameState.tech_blueprints.has("C07") and GoalSystem.chapter_state(gewu) == "done" and queued, "turn %d sheets %s" % [GameState.turn, str(GameState.tech_blueprints)])
	GameState.new_game()
	GameState.chapter_rewarded["gewu"] = "done"
	GameState.battery_bonus = 4
	var kept := int(GameState.resources.get("craft", 0))
	GoalSystem.grant_chapter(gewu, "partial")
	check("ch5_settled", str(GameState.chapter_rewarded.get("gewu", "")) == "done" and GameState.battery_bonus == 4 and int(GameState.resources.get("craft", 0)) == kept)
	var old_save: Dictionary = GameState.to_save()
	old_save.erase("city_buildings")
	old_save.erase("practice_said")
	old_save["turn"] = 70
	old_save["chapter_rewarded"] = {}
	old_save["site_turns"] = {"mill": 3}
	check("p17_load", GameState.from_save(old_save) and GameState.city_buildings.is_empty() and GameState.practice_said.is_empty() and int(GameState.site_turns.get("mill", 0)) == 3)
	GameState.tech_blueprints = ["C07"]
	check("ch5_old_live", GoalSystem.chapter_state(gewu) == "done" and not GameState.chapter_rewarded.has("gewu"))
	check("ch5_t68", TechPlan._lock_label(3) == "第 68 回合开")
	GameState.new_game()
	var money0 := int(GameState.resources.get("money", 0))
	var craft2 := int(GameState.resources.get("craft", 0))
	check("p1_build", GameState.can_build("daming", "coalpit") == "" and GameState.build("daming", "coalpit") and GameState.notice.find("已建 · 煤场（大名）") >= 0, GameState.notice)
	check("p1_paid", int(GameState.resources.get("money", 0)) == money0 - 80 and int(GameState.resources.get("craft", 0)) == craft2 - 30)
	GameState.finish_turn()
	check("p1_tick", int(GameState.site_turns.get("coal", 0)) == 1, str(GameState.site_turns))
	for _i in 3:
		GameState.finish_turn()
		GameState.announce_turn()
	check("p2_ready", int(GameState.site_turns.get("coal", 0)) == 4 and GameState.practice_ok("I04") and GameState.notice.find("实践够了 · 焦炭冶铁") >= 0, GameState.notice)
	check("p2_said", GameState.practice_said.has("I04") and GameState.advisor_text.find("煤场跑够了") >= 0, GameState.advisor_text)
	GameState.notice = ""
	GameState.finish_turn()
	GameState.announce_turn()
	check("p2_once", GameState.notice.find("实践够了") < 0, GameState.notice)
	GameState.new_game()
	for _j in 10:
		GameState.finish_turn()
	check("p3_idle", GameState.site_turns.is_empty(), str(GameState.site_turns))
	var money1 := int(GameState.resources.get("money", 0))
	var craft3 := int(GameState.resources.get("craft", 0))
	check("p4_coal", GameState.can_build("kaifeng", "coalpit") == "需煤矿")
	check("p4_keep", int(GameState.resources.get("money", 0)) == money1 and int(GameState.resources.get("craft", 0)) == craft3)
	var river := ""
	var dry := ""
	for city_v in DataDB.cities:
		var city: Dictionary = city_v
		if str(city.get("faction", "")) != "song":
			continue
		var cid := str(city.get("id", ""))
		if GameState._city_has_river(cid) and river == "":
			river = cid
		if not GameState._city_has_river(cid) and dry == "":
			dry = cid
	check("p5_locked", river != "" and GameState.can_build(river, "watermill") == "待 齿轮与水磨规范", river)
	GameState.tech_done.append("K01")
	check("p5_river", GameState.can_build(river, "watermill") == "", GameState.can_build(river, "watermill"))
	check("p5_dry", dry != "" and GameState.can_build(dry, "watermill") == "需河畔", dry)
	var mills: Array = []
	for city_v2 in DataDB.cities:
		var city2: Dictionary = city_v2
		var cid2 := str(city2.get("id", ""))
		if GameState.can_build(cid2, "watermill") == "":
			mills.append(cid2)
		if mills.size() >= 4:
			break
	check("p6_cities", mills.size() >= 4, str(mills))
	for n in 3:
		GameState.build(str(mills[n]), "watermill")
	GameState.site_turns = {}
	GameState.finish_turn()
	check("p6_three", int(GameState.site_turns.get("mill", 0)) == 3, str(GameState.site_turns))
	GameState.build(str(mills[3]), "watermill")
	GameState.finish_turn()
	check("p6_cap", int(GameState.site_turns.get("mill", 0)) == 6, str(GameState.site_turns))
	check("p7_again", GameState.can_build(str(mills[0]), "watermill") == "已建")
	GameState.new_game()
	GameState.tech_done.append("K01")
	check("p8_build", GameState.build("yangzhou", "watermill"))
	GameState.finish_turn()
	check("p8_ran", int(GameState.site_turns.get("mill", 0)) == 1, str(GameState.site_turns))
	Campaign.seize_yangzhou()
	GameState.finish_turn()
	GameState.finish_turn()
	var yang: Array = GameState.city_buildings.get("yangzhou", [])
	check("p8_lost", int(GameState.site_turns.get("mill", 0)) == 1 and yang.has("watermill"), str(GameState.site_turns))
	GameState.new_game()
	check("p9_build", GameState.can_build("xuzhou", "ironworks") == "" and GameState.build("xuzhou", "ironworks"), GameState.can_build("xuzhou", "ironworks"))
	GameState.finish_turn()
	check("p9_wait", int(GameState.site_turns.get("mill", 0)) == 0, str(GameState.site_turns))
	GameState.tech_done.append("K02")
	GameState.finish_turn()
	check("p9_mill", int(GameState.site_turns.get("mill", 0)) == 1, str(GameState.site_turns))
	GameState.new_game()
	GameState.tech_blueprints = ["I04"]
	GameState.resources["coal"] = 40
	GameState.resources["craft"] = 200
	GameState.site_turns = {"coal": 3}
	check("p11_open", TechPlan.view_state("I04") == "blueprint", TechPlan.view_state("I04"))
	GameState.practice_gate_on = true
	check("p11_flag", TechPlan.view_state("I04") == "blocked" and TechPlan._blocked_text("I04") == "缺实践 3/4" and TechPlan._blocked_jump("I04") == "city", TechPlan._blocked_text("I04"))
	check("p11_city", GameState.practice_city("I04") == "daming", GameState.practice_city("I04"))
	var coal_before := int(GameState.resources.get("coal", 0))
	var craft_before := int(GameState.resources.get("craft", 0))
	var trials_before := GameState.tech_trials.size()
	check("p10_flag", GameState.start_trial("I04") == false and GameState.tech_trials.size() == trials_before and int(GameState.resources.get("coal", 0)) == coal_before and int(GameState.resources.get("craft", 0)) == craft_before and GameState.notice == "实践不够 · 煤场 3/4", GameState.notice)
	GameState.practice_gate_on = false
	GameState.advisor_text = ""
	GameState.line_history.erase("practice_short_I04")
	check("p10_open", GameState.start_trial("I04") and GameState.tech_trials.size() == 1 and int(GameState.resources.get("coal", 0)) == coal_before - 20 and GameState.advisor_text.find("煤场还差 1 回合") >= 0 and GameState.line_history.has("practice_short_I04"), "trials %d coal %d text %s" % [GameState.tech_trials.size(), int(GameState.resources.get("coal", 0)), GameState.advisor_text])
	GameState.tech_trials = []
	GameState.tech_blueprints = ["I04"]
	GameState.resources["coal"] = 40
	GameState.resources["craft"] = 200
	GameState.site_turns = {"coal": 4}
	GameState.advisor_text = "quiet"
	GameState.line_history.erase("practice_short_I04")
	check("p12_ok", GameState.start_trial("I04") and GameState.advisor_text == "quiet" and GameState.practice_ok("I04"))
	check("p14_free", GameState.practice_ok("K01"))
	GameState.new_game()
	GameState.tech_done.append("K04")
	GameState.enact_edict("jiangyi")
	check("p13_cut", GameState.practice_need("I07") == 9 and GameState.practice_need("K03") == 3 and GameState.practice_need("M08") == 2, "%d %d %d" % [GameState.practice_need("I07"), GameState.practice_need("K03"), GameState.practice_need("M08")])
	GameState.new_game()
	GameState.load_tech_sample()
	var sample_i04: Dictionary = TechPlan.practice_row("I04")
	var sample_c06: Dictionary = TechPlan.practice_row("C06")
	var sample_i07: Dictionary = TechPlan.practice_row("I07")
	var kaifeng_built: Array = GameState.city_buildings.get("kaifeng", [])
	var daming_built: Array = GameState.city_buildings.get("daming", [])
	check("p15_sample", GameState.site_turns.get("mill", 0) == 6 and GameState.site_turns.get("coal", 0) == 4 and GameState.site_turns.get("coke", 0) == 6 and bool(sample_i04.get("ok", false)) and bool(sample_c06.get("ok", false)) and not bool(sample_i07.get("ok", false)) and kaifeng_built.has("watermill") and daming_built.has("coalpit"), str(GameState.site_turns))
	check("d21_sample", not GameState.event_flags.has("era3_open") and not GameState.event_flags.has("era3_tree_seen") and not GameState.line_history.has("era3_open") and int(GameState.tech_trials[0].get("prog", 0)) == 2 and int(GameState.tech_trials[0].get("need", 0)) == 4)
	GameState.practice_said = ["I04"]
	var packed: String = SaveManager.pack(GameState.to_save())
	GameState.city_buildings = {}
	GameState.practice_said = []
	GameState.site_turns = {}
	var loaded: Dictionary = SaveManager.unpack(packed)
	var back_kf: Array = []
	if GameState.from_save(loaded):
		back_kf = GameState.city_buildings.get("kaifeng", [])
	check("p16_round", back_kf.has("watermill") and GameState.practice_said.has("I04") and int(GameState.site_turns.get("coke", 0)) == 6, str(GameState.city_buildings))
	GameState.new_game()
	GameState.build("daming", "coalpit")
	GameState.site_turns["coal"] = 3
	GameState.tech_designing = "A01"
	GameState.tech_design_prog = GameState.design_need("A01") - 1
	GameState.battery = 30
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("p18_both", GameState.notice.find("图纸已成") >= 0 and GameState.notice.find("实践够了 · 焦炭冶铁") >= 0 and GameState.advisor_text.find("图纸画好了") >= 0 and GameState.advisor_text.find("跑够了") < 0, GameState.notice + " / " + GameState.advisor_text)
	var tree := Engine.get_main_loop() as SceneTree
	var ui := tree.get_first_node_in_group("game_ui") as GameUI
	if ui != null and ui.desk != null:
		GameState.new_game()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		ui.open_city("daming")
		var coal_btn: Button = ui.desk.debug_btns.get("build_daming_coalpit")
		var iron_btn: Button = ui.desk.debug_btns.get("build_daming_ironworks")
		var lines: Array = []
		_walk_text(ui.desk, lines)
		var joined := "\n".join(PackedStringArray(lines))
		check("p19_coal", coal_btn != null and coal_btn.text.begins_with("建造（钱 80") and not coal_btn.disabled, coal_btn.text if coal_btn != null else "missing")
		check("p19_iron", iron_btn != null and iron_btn.text.begins_with("建造（钱 100"), iron_btn.text if iron_btn != null else "missing")
		check("p19_copy", joined.find("能建的和还锁着的。带实践的建筑每回合给门槛记一笔。") >= 0 and joined.find("可建") >= 0 and not ui.desk.debug_btns.has("build_daming_pasture"), joined)
		ui.open_city("kaifeng")
		var no_coal: Button = ui.desk.debug_btns.get("build_kaifeng_coalpit")
		check("p19_block", no_coal != null and no_coal.disabled and no_coal.text == "需煤矿", no_coal.text if no_coal != null else "missing")
		ui.desk.shut()
	else:
		check("p19_coal", false, "no ui")
	var i04: Dictionary = DataDB.tech_by_id["I04"]
	var saved_site := str(i04.get("practice_site", ""))
	i04.erase("practice_site")
	var bad := DataDB.check_practice_sites()
	i04["practice_site"] = saved_site
	check("p20_site", bad.has("I04") and DataDB.check_practice_sites().is_empty(), ",".join(bad))
	GameState.new_game()
	_stamp(67)
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("d14_toast", GameState.turn == 68 and GameState.notice.find("时代三 · 火器初兴 开了") >= 0 and GameState.advisor_text == date_line and GameState.advisor_mood == "smug" and GameState.event_flags.has("era3_open") and int(GameState.line_history.get("era3_open", 0)) == 68, GameState.notice + " / " + GameState.advisor_text)
	GameState.notice = ""
	GameState.finish_turn()
	GameState.announce_turn()
	check("d15_once", GameState.notice.find("时代三") < 0 and int(GameState.line_history.get("era3_open", 0)) == 68, GameState.notice)
	var again: String = SaveManager.pack(GameState.to_save())
	check("d16_load", GameState.from_save(SaveManager.unpack(again)) and GameState.event_flags.has("era3_open") and GameState.line_history.has("era3_open"))
	GameState.notice = ""
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("d16_quiet", GameState.notice.find("时代三") < 0 and int(GameState.line_history.get("era3_open", 0)) == 68, GameState.notice)
	GameState.new_game()
	_stamp(67)
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.battle_lines = ["延州城下打了一场。"]
	GameState.announce_turn()
	check("d19_battle", GameState.notice.find("时代三 · 火器初兴 开了") >= 0 and GameState.line_history.has("battle_brief") and not GameState.line_history.has("era3_open") and GameState.advisor_text.find("城下打起来了") >= 0, GameState.advisor_text)
	GameState.notice = ""
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("d19_later", GameState.advisor_text == date_line and GameState.notice.find("时代三") < 0 and GameState.line_history.has("era3_open"), GameState.notice + " / " + GameState.advisor_text)
	GameState.new_game()
	_stamp(70)
	var aged: Dictionary = GameState.to_save()
	aged["advisor_text"] = "旧档"
	if typeof(aged.get("event_flags", {})) == TYPE_DICTIONARY:
		(aged["event_flags"] as Dictionary).erase("era3_open")
		(aged["event_flags"] as Dictionary).erase("era3_tree_seen")
	if typeof(aged.get("line_history", {})) == TYPE_DICTIONARY:
		(aged["line_history"] as Dictionary).erase("era3_open")
	check("d17_fill", GameState.from_save(aged) and GameState.event_flags.has("era3_open") and GameState.event_flags.has("era3_tree_seen") and int(GameState.line_history.get("era3_open", 0)) == 70 and GameState.advisor_text != date_line and GameState.notice.find("时代三") < 0, GameState.advisor_text)
	GameState.notice = ""
	GameState.battle_lines = []
	GameState.advisor_text = "旧档"
	GameState.finish_turn()
	GameState.announce_turn()
	check("d17_quiet", GameState.notice.find("时代三") < 0 and GameState.advisor_text != date_line and int(GameState.line_history.get("era3_open", 0)) == 70, GameState.notice + " / " + GameState.advisor_text)
	GameState.new_game()
	_stamp(67)
	var young: Dictionary = GameState.to_save()
	check("d18_keep", GameState.from_save(young) and not GameState.event_flags.has("era3_open") and not GameState.line_history.has("era3_open"))
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("d18_fire", GameState.turn == 68 and GameState.notice.find("时代三 · 火器初兴 开了") >= 0 and GameState.advisor_text == date_line, GameState.advisor_text)
	var desk := tree.root.find_child("Desk", true, false) as Desk
	if desk != null:
		GameState.tech_tutorial_done = true
		desk.tech_tutorial = -1
		desk.tech_view = "focus"
		desk.open("tech")
		var board: Node = desk.host.get_child(0)
		var left := int(board.call("era3_flash_left"))
		var heads: Array = board.get("_flash_labels")
		check("d22_flash", left > 1200 and left <= 1600 and GameState.event_flags.has("era3_tree_seen") and heads.size() == 2, "left %d heads %d" % [left, heads.size()])
		board.set("_flash_until", Time.get_ticks_msec() - 1)
		board.call("_process", 0.016)
		var ink_ok := heads.size() == 2
		var ink_detail := ""
		for lab_v in heads:
			var lab := lab_v as Label
			if lab == null or not is_instance_valid(lab):
				ink_ok = false
				continue
			var col: Color = lab.get_theme_color("font_color")
			ink_detail = col.to_html(false)
			if col.r > 0.6 or col.g > 0.55 or col.b > 0.5:
				ink_ok = false
		check("d22_ink", ink_ok, ink_detail)
		desk.shut()
		desk.open("tech")
		var board2: Node = desk.host.get_child(0)
		check("d22_second", int(board2.call("era3_flash_left")) == 0)
		var flash_save: String = SaveManager.pack(GameState.to_save())
		desk.shut()
		GameState.from_save(SaveManager.unpack(flash_save))
		GameState.tech_tutorial_done = true
		desk.tech_tutorial = -1
		desk.open("tech")
		var board3: Node = desk.host.get_child(0)
		check("d22_load", int(board3.call("era3_flash_left")) == 0 and GameState.event_flags.has("era3_tree_seen"))
		desk.shut()
	else:
		check("d22_flash", false, "no desk")
	GameState.new_game()
	check("d23_clear", not GameState.event_flags.has("era3_open") and not GameState.event_flags.has("era3_tree_seen") and not GameState.line_history.has("era3_open"))
	GameState.new_game()
	_stamp(60)
	var era2: Array = []
	for tech_v in DataDB.techs:
		var tech: Dictionary = tech_v
		if int(tech.get("era", 0)) == 2:
			era2.append(str(tech.get("id", "")))
	for n2 in 10:
		GameState.tech_done.append(str(era2[n2]))
	GameState.tech_trials = [{"id": str(era2[10]), "prog": 0, "need": 1}]
	GameState.tech_target = ""
	GameState.tech_queue = []
	GameState.battle_lines = []
	GameState.finish_turn()
	GameState.announce_turn()
	check("d20_early", GameState.era_unlocked(3) and GameState._era_done_count(2) >= 11 and GameState.advisor_text == early_line and GameState.notice.find("时代三 · 火器初兴 开了") >= 0, GameState.advisor_text)
	GameState.new_game()
	GameState.build("daming", "coalpit")
	var steps := 0
	while steps < 85:
		steps += 1
		GameState.finish_turn()
		GameState.announce_turn()
	check("p21_turns", GameState.turn == 86 and int(GameState.site_turns.get("coal", 0)) == 85, "turn %d coal %s" % [GameState.turn, str(GameState.site_turns.get("coal", 0))])
	GameState.practice_gate_on = false


func check_industry() -> void:
	var steel_bar := false
	for row_v in GameUI.RES_BAR:
		var row: Array = row_v
		if str(row[0]) == "steel":
			steel_bar = true
	check("m10_bar", steel_bar)
	GameState.new_game()
	check("m2_geo", GameState.can_build("chanzhou", "coalpit") == "需煤矿", GameState.can_build("chanzhou", "coalpit"))
	check("m1_build", GameState.build("daming", "coalpit"))
	for _i in 4:
		GameState.finish_turn()
	check("m1_coal", int(GameState.resources.get("coal", 0)) == 20 and GameState.last_event.find("煤+2") >= 0, GameState.last_event + " coal %d" % int(GameState.resources.get("coal", 0)))
	GameState.new_game()
	check("m3_build", GameState.build("xuzhou", "ironworks"))
	var iron0 := int(GameState.resources.get("iron", 0))
	GameState.finish_turn()
	check("m3_iron", int(GameState.resources.get("iron", 0)) == iron0 + 2, str(GameState.resources.get("iron", 0)))
	GameState.new_game()
	GameState.tech_done.append("I04")
	GameState.city_buildings = {"daming": ["ironworks", "coke"]}
	GameState.resources["coal"] = 5
	GameState.resources["iron"] = 40
	GameState.finish_turn()
	check("m4_yield", int(GameState.resources.get("coal", 0)) == 4 and int(GameState.resources.get("iron", 0)) == 43 and int(GameState.industry_ran.get("coke", 0)) == 1 and int(GameState.site_turns.get("coke", 0)) == 1, "coal %d iron %d ran %s site %s" % [int(GameState.resources.get("coal", 0)), int(GameState.resources.get("iron", 0)), str(GameState.industry_ran), str(GameState.site_turns)])
	GameState.new_game()
	GameState.tech_done.append("I04")
	GameState.city_buildings = {"daming": ["ironworks", "coke"]}
	GameState.resources["coal"] = 0
	GameState.resources["iron"] = 40
	GameState.line_history.erase("stall_coke")
	GameState.advisor_text = ""
	GameState.finish_turn()
	var stall_turn := int(GameState.line_history.get("stall_coke", -1))
	check("m5_stall", int(GameState.resources.get("iron", 0)) == 42 and int(GameState.resources.get("coal", 0)) == 0 and int(GameState.site_turns.get("coke", 0)) == 0 and GameState.advisor_text.find("焦炉断煤了") >= 0 and GameState.industry_line("daming", "coke") == "停工：缺煤", GameState.advisor_text)
	GameState.finish_turn()
	check("m5_once", int(GameState.site_turns.get("coke", 0)) == 0 and int(GameState.line_history.get("stall_coke", -1)) == stall_turn, str(GameState.site_turns))
	GameState.new_game()
	GameState.tech_done.append("I04")
	GameState.resources["money"] = 5000
	GameState.resources["craft"] = 500
	check("m6_build", GameState.build("kaifeng", "coke"))
	GameState.resources["coal"] = 3
	GameState.resources["iron"] = 40
	GameState.finish_turn()
	check("m6_coke", int(GameState.resources.get("coal", 0)) == 2 and int(GameState.resources.get("iron", 0)) == 40 and int(GameState.site_turns.get("coke", 0)) == 1 and GameState.industry_line("kaifeng", "coke").find("同城无冶铁务") >= 0, GameState.industry_line("kaifeng", "coke"))
	GameState.new_game()
	GameState.tech_done.append("I03")
	GameState.resources["money"] = 5000
	GameState.resources["craft"] = 500
	check("m7_build", GameState.build("hongzhou", "copperbath"), GameState.can_build("hongzhou", "copperbath"))
	GameState.resources["iron"] = 4
	GameState.resources["copper"] = 10
	GameState.finish_turn()
	check("m7_copper", int(GameState.resources.get("iron", 0)) == 2 and int(GameState.resources.get("copper", 0)) == 11, "iron %d copper %d" % [int(GameState.resources.get("iron", 0)), int(GameState.resources.get("copper", 0))])
	GameState.resources["iron"] = 1
	GameState.finish_turn()
	check("m7_stall", int(GameState.resources.get("iron", 0)) == 1 and int(GameState.resources.get("copper", 0)) == 11 and GameState.industry_line("hongzhou", "copperbath") == "停工：缺铁", GameState.industry_line("hongzhou", "copperbath"))
	GameState.tech_done.append("I03")
	check("m8_hang", GameState.can_build("hangzhou", "copperbath") == "需铜矿", GameState.can_build("hangzhou", "copperbath"))
	GameState.new_game()
	GameState.resources["money"] = 5000
	GameState.resources["craft"] = 500
	check("m9_build", GameState.build("mingzhou", "shibosi"))
	GameState.finish_turn()
	check("m9_sulfur", int(GameState.resources.get("sulfur", 0)) == 1 and not GameState.industry_button("hangzhou", "shibosi") and not GameState.industry_button("guangzhou", "shibosi"), str(GameState.resources.get("sulfur", 0)))
	GameState.new_game()
	GameState.tech_done.append("I07")
	GameState.city_buildings = {"kaifeng": ["steel"]}
	GameState.resources["iron"] = 2
	GameState.resources["coal"] = 2
	GameState.finish_turn()
	check("m10_steel", int(GameState.resources.get("steel", 0)) == 1 and int(GameState.resources.get("iron", 0)) == 0 and int(GameState.resources.get("coal", 0)) == 0, "steel %d iron %d coal %d" % [int(GameState.resources.get("steel", 0)), int(GameState.resources.get("iron", 0)), int(GameState.resources.get("coal", 0))])
	GameState.new_game()
	GameState.build("daming", "coalpit")
	GameState.finish_turn()
	var coal_live := int(GameState.resources.get("coal", 0))
	var site_live := int(GameState.site_turns.get("coal", 0))
	var seized: Dictionary = DataDB.city_by_id("daming")
	seized["faction"] = "rebel"
	GameState.finish_turn()
	check("m11_lost", int(GameState.resources.get("coal", 0)) == coal_live and int(GameState.site_turns.get("coal", 0)) == site_live, "coal %d site %d" % [int(GameState.resources.get("coal", 0)), int(GameState.site_turns.get("coal", 0))])
	seized["faction"] = "song"
	GameState.finish_turn()
	check("m11_back", int(GameState.resources.get("coal", 0)) == coal_live + 2 and int(GameState.site_turns.get("coal", 0)) == site_live + 1, "coal %d site %d" % [int(GameState.resources.get("coal", 0)), int(GameState.site_turns.get("coal", 0))])
	var packed: Dictionary = GameState.to_save()
	GameState.resources["coal"] = 1
	GameState.city_buildings = {}
	check("m12_round", GameState.from_save(packed) and int(GameState.resources.get("coal", 0)) == coal_live + 2 and GameState._city_has_building("daming", "coalpit"))
	var legacy: Dictionary = GameState.to_save()
	legacy.erase("city_buildings")
	check("m12_old", GameState.from_save(legacy) and GameState.city_buildings.is_empty())
	var coal_old := int(GameState.resources.get("coal", 0))
	GameState.finish_turn()
	check("m12_quiet", GameState.city_buildings.is_empty() and int(GameState.resources.get("coal", 0)) == coal_old)
	GameState.new_game()
	GameState.tech_blueprints = ["I04"]
	GameState.resources["coal"] = 40
	GameState.resources["craft"] = 200
	GameState.site_turns = {"coal": 0}
	GameState.practice_gate_on = false
	check("m13_open", GameState.start_trial("I04"))
	GameState.tech_trials = []
	GameState.tech_blueprints = ["I04"]
	GameState.resources["coal"] = 40
	GameState.resources["craft"] = 200
	GameState.practice_gate_on = true
	GameState.line_history.erase("practice_short_I04")
	check("m13_shut", GameState.start_trial("I04") == false and GameState.notice == "实践不够 · 煤场 0/4", GameState.notice)
	GameState.practice_gate_on = false
	GameState.new_game()
	GameState.turn = 2
	var sweep := preload("res://scripts/core/sweep.gd").new()
	sweep._auto_build()
	var built_dm: Array = GameState.city_buildings.get("daming", [])
	var built_ly: Array = GameState.city_buildings.get("luoyang", [])
	check("m14_auto", built_dm.has("coalpit") and built_dm.has("ironworks") and built_ly.has("saltpeter") and GameState._any_building("lumberyard") and GameState.practice_gate_on == false, str(GameState.city_buildings))
	GameState.new_game()
	check("m15_yan", GameState.can_build("yanzhou", "saltpeter") == "需硝矿", GameState.can_build("yanzhou", "saltpeter"))
	check("m15_build", GameState.build("luoyang", "saltpeter"))
	for _k in 6:
		GameState.finish_turn()
	check("m15_salt", int(GameState.resources.get("saltpeter", 0)) == 10 and GameState.last_event.find("硝+1") >= 0, GameState.last_event)
	GameState.new_game()
	GameState.tech_blueprints = ["M05"]
	GameState.resources["saltpeter"] = 9
	GameState.resources["sulfur"] = 5
	GameState.resources["craft"] = 200
	check("m16_short", GameState.start_trial("M05") == false)
	GameState.resources["saltpeter"] = 10
	GameState.tech_blueprints = ["M05"]
	check("m16_pay", GameState.start_trial("M05") and int(GameState.resources.get("saltpeter", 0)) == 0, str(GameState.resources.get("saltpeter", 0)))
	GameState.new_game()
	check("m17_kai", GameState.can_build("kaifeng", "lumberyard") == "需森林", GameState.can_build("kaifeng", "lumberyard"))
	var wood0 := int(GameState.resources.get("wood", 0))
	check("m17_build", GameState.build("hangzhou", "lumberyard"), GameState.can_build("hangzhou", "lumberyard"))
	GameState.finish_turn()
	check("m17_wood", int(GameState.resources.get("wood", 0)) == wood0 + 2, str(GameState.resources.get("wood", 0)))
	GameState.new_game()
	GameState.tech_blueprints = ["K02"]
	GameState.resources["wood"] = 14
	GameState.resources["craft"] = 200
	check("m18_short", GameState.start_trial("K02") == false and int(GameState.resources.get("wood", 0)) == 14)
	GameState.resources["money"] = 5000
	GameState.resources["craft"] = 500
	check("m18_yard", GameState.build("hangzhou", "lumberyard"))
	GameState.finish_turn()
	GameState.resources["craft"] = 200
	check("m18_pay", int(GameState.resources.get("wood", 0)) >= 15 and GameState.start_trial("K02"), str(GameState.resources.get("wood", 0)))
	GameState.new_game()
	GameState.site_turns["coal"] = 5
	var frac := GameState.practice_tech_line("coal")
	check("m_frac", frac.find("焦炭冶铁 4/4") >= 0 and frac.find("5/4") < 0, frac)
	var counted := GameState.practice_count_text("daming", "coalpit")
	check("m_frac_raw", counted.find("煤场 5") >= 0 and counted.find("4/4") >= 0 and counted.find("5/4") < 0, counted)
	var tree := Engine.get_main_loop() as SceneTree
	var ui := tree.get_first_node_in_group("game_ui") as GameUI
	if ui != null and ui.desk != null:
		GameState.new_game()
		if ui.goals and ui.goals.blocking():
			ui.goals.dismiss_card()
		ui.open_city("chanzhou")
		var blocked: Button = ui.desk.debug_btns.get("build_chanzhou_coalpit")
		check("m2_btn", blocked != null and blocked.disabled and blocked.text == "需煤矿", blocked.text if blocked != null else "missing")
		ui.open_city("hangzhou")
		check("m9_btn", not ui.desk.debug_btns.has("build_hangzhou_shibosi"))
		ui.desk.shut()
		ui.open_desk("industry")
		var lines: Array = []
		_walk_text(ui.desk, lines)
		var joined := "\n".join(PackedStringArray(lines))
		check("m_blurb", joined.find("推广后去城里建对应的坊，才有产量。") >= 0, joined)
		ui.desk.shut()
	else:
		check("m2_btn", false, "no ui")


func check_desk_a() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var ui := tree.get_first_node_in_group("game_ui") as GameUI
	if ui == null or ui.desk == null:
		check("g_desk", false, "no desk")
		return
	var desk := ui.desk
	GameState.new_game()
	if ui.goals and ui.goals.blocking():
		ui.goals.dismiss_card()
	GameState.load_tech_sample()
	desk.tech_scroll = -1
	desk.tech_scroll_era = -1
	desk.tech_view = "focus"
	desk.tech_tutorial = -1
	desk.tech_show_legend = false
	desk.tech_show_parts = false
	desk.picked = ""
	desk.tech_fold = ""
	desk.open("tech")
	var board: Node = _tech_board(desk)
	check("g_board", board != null)
	if board == null:
		desk.shut()
		return
	var box: Dictionary = board.layout_box
	check("g1_header", int(box.get("header_h", 0)) == 48, str(box))
	check("g1_left", int(box.get("left_w", 0)) == 288, str(box))
	check("g1_tree", int(box.get("tree_h", 0)) == 596, str(box))
	check("g1_foot", int(box.get("footer_h", 0)) == 76, str(box))
	check("g1_scroll", desk.tech_scroll == 856 and board.scroll.scroll_horizontal == 856, "%s / %s" % [desk.tech_scroll, board.scroll.scroll_horizontal])
	check("g1_vscroll", board.scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	var node_a05: Button = desk.debug_btns.get("node_A05")
	check("g1_node", node_a05 != null and node_a05.size == Vector2(156, 44), str(node_a05.size if node_a05 != null else Vector2.ZERO))
	var locked_n := 0
	for key_v in desk.debug_btns.keys():
		var key := str(key_v)
		if not key.begins_with("node_"):
			continue
		var btn: Button = desk.debug_btns[key]
		if btn != null and is_equal_approx(btn.modulate.a, 0.6):
			locked_n += 1
	check("g1_chips", locked_n == 8 and desk.debug_btns.has("node_K07") and not desk.debug_btns.has("node_X01"), str(locked_n))
	var page := _desk_text(desk)
	check("g1_rows", page.contains("农") and page.contains("工") and page.contains("械") and page.contains("商") and page.contains("军") and page.contains("电"))
	check("g1_next", page.contains("时代三 · 后继") and page.contains("第 68 回合开"))
	var small: Array = []
	_walk_tech_font(desk, small)
	check("g2_font", small.is_empty(), ",".join(small))
	check("g2_nine", _font_of(desk, "水排鼓风与水力锻锤") == 13, str(_font_of(desk, "水排鼓风与水力锻锤")))
	var overlap := _label_boxes(desk)
	desk.picked = "A06"
	desk.tech_fold = ""
	desk._fill()
	board = _tech_board(desk)
	var card := board.find_child("NodeCard", true, false) as Control
	if card == null:
		overlap = "无节点卡" if overlap == "" else overlap
	else:
		var card_end := card.position.y + card.size.y
		if card.size.y < 180.0 or card.size.y > 480.0 or card_end > 636.5:
			var geom := "卡高 %.0f 底 %.0f" % [card.size.y, card_end]
			overlap = geom if overlap == "" else overlap + " | " + geom
		var card_err := _label_boxes(card)
		if card_err != "":
			overlap = card_err if overlap == "" else overlap + " | " + card_err
	desk.picked = ""
	desk.tech_fold = ""
	desk._fill()
	board = _tech_board(desk)
	check("g2_overlap", overlap == "", overlap)
	var route_err := _routes_ok(board)
	check("g3_routes", route_err == "", route_err)
	check("g4_a05", str(_face_prop(desk, "A05", "corner")) == "")
	check("g4_i05", str(_face_prop(desk, "I05", "corner")) == "图")
	check("g4_k02", str(_face_prop(desk, "K02", "corner")) == "试")
	check("g4_k03", str(_face_prop(desk, "K03", "corner")) == "设")
	check("g4_a06", str(_face_prop(desk, "A06", "corner")) == "缺1")
	check("g4_i07", str(_face_prop(desk, "I07", "corner")) == "锁")
	check("g4_count", TechPlan.missing_prereq_count("A06") == 1)
	GameState.tech_queue.append("A05")
	desk._fill()
	check("g5_badge", int(_face_prop(desk, "A05", "queue_n")) == 1 and str(_face_prop(desk, "E05", "state")) != "queued")
	var queued_bad := false
	for key_v2 in desk.debug_btns.keys():
		var key2 := str(key_v2)
		if not key2.begins_with("node_"):
			continue
		var id2 := key2.substr(5)
		var qn := int(_face_prop(desk, id2, "queue_n"))
		if qn > 0 and TechPlan.view_state(id2) != "queued":
			queued_bad = true
		if TechPlan.view_state(id2) == "queued" and qn != GameState.tech_queue.find(id2) + 1:
			queued_bad = true
	check("g5_only", not queued_bad)
	page = _desk_text(desk)
	check("g5_left", page.contains("①苜蓿轮作"))
	GameState.tech_queue.clear()
	desk.picked = "E05"
	desk._fill()
	board = _tech_board(desk)
	var lines := str(board._target_lines("E05"))
	board._open_target_confirm("E05")
	var shown := _desk_text(board._choice)
	check("g6_dialog", shown.contains(lines) and shown.contains("确定") and shown.contains("取消"), shown)
	board._confirm_target("E05")
	desk._fill()
	check("g6_target", GameState.tech_target == "E05")
	check("g6_start", str(_face_prop(desk, "K02", "route_mark")) == "起" and bool(_face_prop(desk, "K02", "route")))
	check("g6_mark", str(_face_prop(desk, "E05", "route_mark")) == "标" and bool(_face_prop(desk, "K05", "route")) and str(_face_prop(desk, "K05", "route_mark")) == "")
	check("g6_no_end", not _desk_text(desk).contains("终"))
	GameState.load_tech_sample()
	GameState.tech_queue = ["C01", "C02", "A01"]
	GameState.tech_target = ""
	desk.picked = "A06"
	desk.tech_fold = ""
	desk._fill()
	board = _tech_board(desk)
	var full := str(board._target_lines("A06"))
	check("g7_copy", full.contains("队列已满 3/3，新路线等空位。原来排着的 3 项不动，不想要可以在左栏队列里移出。") and not full.contains("会移出"), full)
	var before: Array = GameState.tech_queue.duplicate()
	board._confirm_target("A06")
	check("g7_keep", GameState.tech_target == "A06" and GameState.tech_queue == before, str(GameState.tech_queue))
	GameState.load_tech_sample()
	GameState.tech_queue = ["K03"]
	GameState.tech_target = ""
	desk._fill()
	board = _tech_board(desk)
	var roomy := str(board._target_lines("A06"))
	check("g8_copy", roomy.contains("现在排入 1 项：苜蓿轮作与牧监") and roomy.contains("其余 1 项前置齐后自动排入。"), roomy)
	board._confirm_target("A06")
	check("g8_queue", GameState.tech_target == "A06" and GameState.tech_queue.has("A05") and not GameState.tech_queue.has("A06"), str(GameState.tech_queue))
	GameState.load_tech_sample()
	desk.picked = ""
	GameState.tech_target = ""
	desk.tech_fold = ""
	desk._fill()
	board = _tech_board(desk)
	board._on_node("A06")
	board = _tech_board(desk)
	page = _desk_text(desk)
	var verb: Button = desk.debug_btns.get("tech_verb")
	check("g9_card", desk.picked == "A06" and verb != null and verb.disabled and verb.text == "开始设计" and page.contains("先完成：苜蓿轮作与牧监") and page.contains("设为目标") and page.contains("史册") and page.contains("关闭"), page)
	var jump: Button = _button_text(desk, "先完成：苜蓿轮作与牧监")
	check("g10_link", jump != null)
	if jump != null:
		jump.pressed.emit()
	check("g10_card", desk.picked == "A05")
	var hist: Button = desk.debug_btns.get("tech_history")
	if hist != null:
		hist.pressed.emit()
	page = _desk_text(desk)
	check("g11_hist", desk.tech_fold == "history" and page.contains("豆沙包能做的 / 大宋得自己做的") and page.contains("返回"), page)
	var back: Button = _button_text(desk, "返回")
	if back != null:
		back.pressed.emit()
	check("g11_back", desk.tech_fold == "" and desk.picked == "A05")
	board = _tech_board(desk)
	var picked_before := desk.picked
	check("g12_method", not board.has_method("_on_node_input"))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(30, 30)
	board._on_paper_input(right)
	check("g12_right", desk.picked == picked_before and desk.tech_fold == "")
	desk.picked = ""
	desk._fill()
	board = _tech_board(desk)
	var designing := GameState.tech_designing
	board._on_node("A05")
	board = _tech_board(desk)
	check("g13_open", desk.picked == "A05" and GameState.tech_designing == designing)
	board._on_node("A05")
	check("g13_shut", desk.picked == "" and GameState.tech_designing == designing)
	board = _tech_board(desk)
	board._apply_scroll(400)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = board.scroll.get_global_position() + Vector2(20, 20)
	board._input(wheel)
	check("g14_wheel", desk.tech_scroll == 293, str(desk.tech_scroll))
	wheel.shift_pressed = true
	board._input(wheel)
	check("g14_shift", desk.tech_scroll == 186, str(desk.tech_scroll))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(200, 80)
	board._on_paper_input(press)
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = Vector2(120, 80)
	board._on_paper_input(drag)
	check("g14_drag", desk.tech_scroll == 266, str(desk.tech_scroll))
	var key := InputEventKey.new()
	key.keycode = KEY_LEFT
	key.pressed = true
	board._input(key)
	check("g14_key", desk.tech_scroll == 52, str(desk.tech_scroll))
	var ctrl := InputEventMouseButton.new()
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	ctrl.button_index = MOUSE_BUTTON_WHEEL_DOWN
	board._input(ctrl)
	check("g14_ctrl", desk.tech_view == "overview")
	desk.tech_view = "focus"
	desk._fill()
	board = _tech_board(desk)
	board._minimap_to(0.0)
	check("g15_map", desk.tech_scroll == 0, str(desk.tech_scroll))
	GameState.load_tech_sample()
	desk.tech_scroll = -1
	desk.tech_scroll_era = -1
	desk.tech_view = "focus"
	desk.picked = ""
	desk._fill()
	page = _desk_text(desk)
	check("g16_trial", page.contains("第 2/4 回合") and page.contains("匠 40、木 15 已付") and page.contains("第 2 槽 · 颁布「开格物院」后开放") and page.contains("图纸库 2/3"), page)
	var libs := _lib_count(desk)
	check("g17_lib", int(libs.get("real", 0)) == 3 and int(libs.get("preview", 0)) == 2 and is_equal_approx(float(libs.get("w", 0)), 48.0), str(libs))
	GameState.chapter_rewarded["liao"] = "done"
	GameState.blueprint_bonus = 1
	desk._fill()
	page = _desk_text(desk)
	libs = _lib_count(desk)
	check("g18_lib", page.contains("图纸库 2/4") and int(libs.get("real", 0)) == 4 and int(libs.get("preview", 0)) == 1 and str(libs.get("title", "")) == "第四章", str(libs) + page)
	GameState.chapter_rewarded = {"liao": "partial"}
	GameState.blueprint_bonus = 0
	desk._fill()
	page = _desk_text(desk)
	libs = _lib_count(desk)
	check("g19_lib", page.contains("图纸库 2/3") and int(libs.get("real", 0)) == 3 and int(libs.get("preview", 0)) == 1 and str(libs.get("title", "")) == "第四章", str(libs))
	GameState.new_game()
	if ui.goals and ui.goals.blocking():
		ui.goals.dismiss_card()
	_stamp(68)
	GameState.event_flags.erase("era3_tree_seen")
	desk.tech_scroll = -1
	desk.tech_scroll_era = -1
	desk.tech_view = "focus"
	desk.picked = ""
	desk.open("tech")
	board = _tech_board(desk)
	check("g20_flash", GameState.event_flags.has("era3_tree_seen") and board.era3_flash_left() > 0, str(board.era3_flash_left()))
	desk.shut()
	desk.open("tech")
	board = _tech_board(desk)
	check("g20_once", board.era3_flash_left() == 0)
	var packed := SaveManager.pack(GameState.to_save())
	GameState.event_flags.erase("era3_tree_seen")
	GameState.from_save(SaveManager.unpack(packed))
	desk.tech_scroll = -1
	desk.open("tech")
	board = _tech_board(desk)
	check("g20_save", board.era3_flash_left() == 0 and GameState.event_flags.has("era3_tree_seen"))
	GameState.new_game()
	if ui.goals and ui.goals.blocking():
		ui.goals.dismiss_card()
	_stamp(67)
	desk.tech_scroll = -1
	desk.tech_scroll_era = -1
	desk.tech_view = "focus"
	desk.picked = ""
	desk.open("tech")
	page = _desk_text(desk)
	var tip := ""
	var locked: Button = desk.debug_btns.get("node_I07")
	if locked != null:
		tip = locked.tooltip_text
	check("g21_copy", page.contains("时代三：第 68 回合 或 本时代完成 11/17 开放") and page.contains("第 68 回合开") and tip.contains("第 68 回合开") and not page.contains("T75") and not tip.contains("T75"), page)
	_stamp(68)
	desk.tech_scroll_era = -1
	desk.tech_view = "focus"
	desk._fill()
	board = _tech_board(desk)
	var spot: Rect2 = board.graph.spots.get("X01", Rect2())
	check("g22_x01", desk.debug_btns.has("node_X01") and is_equal_approx(spot.position.x, 12.0 * 214.0) and not _desk_text(desk).contains("后继"), str(spot))
	page = _desk_text(desk)
	check("g23_edict", page.contains("「开格物院」") and not page.contains("颁布格物院"))
	var workshop := FileAccess.get_file_as_string("res://scripts/ui/desk.gd")
	check("g23_desk", workshop.contains("第二槽要在朝堂颁布「开格物院」。") and workshop.contains("「开格物院」还没颁布，这一槽锁着。"))
	GameState.load_tech_sample()
	GameState.battery = 0
	GameState.resources["iron"] = 3
	GameState.resources["saltpeter"] = 40
	if not GameState.tech_blueprints.has("M06"):
		GameState.tech_blueprints.append("M06")
	desk.tech_view = "focus"
	desk.tech_scroll_era = 2
	desk.picked = ""
	desk._fill()
	check("g24_power", str(_face_prop(desk, "K03", "corner")) == "阻" and TechPlan.status_text("K03") == "停电")
	check("g24_mat", str(_face_prop(desk, "M06", "corner")) == "阻" and TechPlan.status_text("M06") == "缺铁 3/15", TechPlan.status_text("M06"))
	check("g24_legend", _desk_text(desk).contains("阻 受阻"))
	GameState.tech_target = "E05"
	GameState.tech_queue = ["A05"]
	desk.tech_view = "overview"
	desk.picked = ""
	desk._fill()
	page = _desk_text(desk)
	check("g25_lock", page.contains("锁 · 第 68 回合开"))
	check("g25_queue", int(_face_prop(desk, "A05", "queue_n")) == 1)
	check("g25_route", bool(_face_prop(desk, "K02", "route")) and str(_face_prop(desk, "E05", "route_mark")) == "标" and str(_face_prop(desk, "K02", "route_mark")) == "起")
	desk.shut()
	GameState.new_game()


func _tech_board(desk: Desk) -> Node:
	if desk.host.get_child_count() == 0:
		return null
	return desk.host.get_child(0)


func _desk_text(node: Node) -> String:
	var lines: Array = []
	_walk_text(node, lines)
	return "\n".join(PackedStringArray(lines))


func _font_of(node: Node, text: String) -> int:
	if node is Label and str((node as Label).text) == text:
		return (node as Control).get_theme_font_size("font_size")
	for child in node.get_children():
		var found := _font_of(child, text)
		if found > 0:
			return found
	return 0


func _face_prop(desk: Desk, id: String, prop: String):
	var btn: Button = desk.debug_btns.get("node_" + id)
	if btn == null:
		return null
	for child in btn.get_children():
		if child.get("queue_n") != null and child.get("corner") != null:
			return child.get(prop)
	return null


func _button_text(node: Node, text: String) -> Button:
	if node is Button and str((node as Button).text) == text:
		return node
	for child in node.get_children():
		var found := _button_text(child, text)
		if found != null:
			return found
	return null


func _lib_count(node: Node) -> Dictionary:
	var out := {"real": 0, "preview": 0, "w": 0.0, "title": ""}
	_lib_walk(node, out)
	return out


func _lib_walk(node: Node, out: Dictionary) -> void:
	if node.has_meta("lib_kind"):
		if str(node.get_meta("lib_kind")) == "preview":
			out["preview"] = int(out["preview"]) + 1
			if node is Control:
				for child in node.get_children():
					if child is VBoxContainer and child.get_child_count() > 0 and child.get_child(0) is Label:
						out["title"] = str((child.get_child(0) as Label).text)
		else:
			out["real"] = int(out["real"]) + 1
			out["w"] = float(node.get_meta("lib_w"))
	for child in node.get_children():
		_lib_walk(child, out)


func _routes_ok(board) -> String:
	var spots: Dictionary = board.graph.spots
	for edge_v in board.graph.edges:
		var edge: Dictionary = edge_v
		var pre := str(edge.get("from", ""))
		var id := str(edge.get("to", ""))
		var pa: Dictionary = DataDB.tech_by_id.get(pre, {})
		var pb: Dictionary = DataDB.tech_by_id.get(id, {})
		var span := absi(int(pb.get("col", 1)) - int(pa.get("col", 1)))
		var cross := int(pa.get("era", 1)) != int(pb.get("era", 1))
		var route := {}
		for route_v in board.edge_routes:
			var item: Dictionary = route_v
			if str(item.get("from", "")) == pre and str(item.get("to", "")) == id:
				route = item
				break
		if route.is_empty():
			return "无线 %s %s" % [pre, id]
		if span >= 3 or cross:
			if not bool(route.get("stub", false)):
				return "应改小签 %s %s" % [pre, id]
			continue
		if bool(route.get("stub", false)):
			continue
		var pts: PackedVector2Array = route.get("pts", PackedVector2Array())
		if pts.size() < 2:
			return "空线 %s %s" % [pre, id]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if absf(a.x - b.x) > 0.2 and absf(a.y - b.y) > 0.2:
				return "斜线 %s %s" % [pre, id]
			if _seg_hits(a, b, spots):
				return "穿节点 %s %s" % [pre, id]
	return ""


func _seg_hits(a: Vector2, b: Vector2, spots: Dictionary) -> bool:
	for id_v in spots.keys():
		var rect: Rect2 = spots[id_v]
		var inner := Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, 2))
		if inner.size.x <= 1.0 or inner.size.y <= 1.0:
			continue
		var min_x := minf(a.x, b.x)
		var max_x := maxf(a.x, b.x)
		var min_y := minf(a.y, b.y)
		var max_y := maxf(a.y, b.y)
		if absf(a.y - b.y) < 0.2:
			if a.y <= inner.position.y or a.y >= inner.end.y:
				continue
			if max_x <= inner.position.x or min_x >= inner.end.x:
				continue
			return true
		if absf(a.x - b.x) < 0.2:
			if a.x <= inner.position.x or a.x >= inner.end.x:
				continue
			if max_y <= inner.position.y or min_y >= inner.end.y:
				continue
			return true
	return false
