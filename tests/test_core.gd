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
