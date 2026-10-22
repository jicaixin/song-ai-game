extends RefCounted

var failed := 0

func run_tests() -> int:
	check_hex()
	check_pixel_roundtrip()
	check_calendar()
	check_combat_range()
	check_geo_and_cities()
	check_path()
	check_save_roundtrip()
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
	if face is FontFile:
		check("font_no_sys", not (face as FontFile).allow_system_fallback)
		check("font_aa", (face as FontFile).antialiasing == TextServer.FONT_ANTIALIASING_GRAY)
	var banner := Settings.banner_font
	check("banner_font", banner != null and banner.has_char("延".unicode_at(0)))
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
	check("techs", DataDB.techs.size() == 42, str(DataDB.techs.size()))
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
