extends RefCounted

const EventSystem = preload("res://scripts/core/event_system.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")
const Hunt = preload("res://scripts/core/hunt.gd")
const Campaign = preload("res://scripts/core/campaign.gd")

const CORE := {
	"E01": "sanchuan",
	"E02": "shaanxi",
	"E05": "haoshui",
	"E07": "zengbi",
	"E08": "dingchuan",
	"E10": "wanglun",
	"E12": "xinzheng",
	"E15": "heyi",
	"E20": "wangze",
	"E21": "yuanhao",
}


func run() -> int:
	var guarantees := {}
	for ev_v in DataDB.events:
		var ev: Dictionary = ev_v
		guarantees[str(ev.get("id", ""))] = int(ev.get("guarantee", ev.get("turn", 1)))
	var a1_fail := 0
	var a2_fail := 0
	var a4_fail := 0
	var caught := 0
	var reached := 0
	var grain_ok := 0
	var grain_n := 0
	var made := 0
	var wasted := 0
	var over := 0
	var sunk := 0
	var a14 := 0
	var seeds := 0
	while seeds < 100:
		seeds += 1
		GameState.new_game()
		GameState.seed_value = 1000 + seeds
		GameState.rng.seed = GameState.seed_value
		GameState.roll_weather()
		GameState.orders = []
		GameState.order_seen = {}
		GameState.order_place = {}
		GameState.rest_streak = 0
		GoalSystem.on_turn()
		_spend_power()
		var opening := GameState.food_start
		var flags: Array[bool] = []
		var first := {}
		if not _record(flags, first):
			a2_fail += 1
		var step := 0
		while step < 85:
			step += 1
			if step > 1 and GameState.can_sell_grain():
				GameState.sell_grain()
			GameState.finish_turn()
			if step == 1:
				var food_now := int(GameState.resources.get("food", 0))
				if opening > 0 and food_now * 100 >= opening * 95:
					a14 += 1
			EventSystem.scan()
			GoalSystem.on_turn()
			_spend_power()
			Hunt.step()
			if not _record(flags, first):
				a2_fail += 1
		var i := 0
		while i < flags.size() - 2:
			if not flags[i] and not flags[i + 1] and not flags[i + 2]:
				a1_fail += 1
				i = flags.size()
			i += 1
		if GameState.event_flags.has("wanglun_caught"):
			caught += 1
		if GameState.event_flags.has("wanglun_at_yangzhou"):
			reached += 1
		grain_ok += GameState.grain_le12
		grain_n += GameState.grain_samples
		made += GameState.power_made
		wasted += GameState.power_waste
		over += GameState.power_over
		sunk += GameState.power_sunk
		for code in CORE.keys():
			var id := str(CORE[code])
			var seen := int(first.get(id, 999))
			var limit := int(guarantees.get(id, 1))
			if seen > limit:
				a4_fail += 1
				print("A4 miss seed %d %s %s first %d guarantee %d" % [seeds, code, id, seen, limit])
	var a1_ok := a1_fail == 0
	var a2_ok := a2_fail == 0
	var a4_ok := a4_fail == 0
	print("SWEEP seeds %d" % seeds)
	print("A1 %s failures %d" % ["PASS" if a1_ok else "FAIL", a1_fail])
	print("A2 %s failures %d" % ["PASS" if a2_ok else "FAIL", a2_fail])
	print("A4 %s failures %d" % ["PASS" if a4_ok else "FAIL", a4_fail])
	print("WANG catch %d/100 reached %d/100" % [caught, reached])
	var grain_pct := 0
	if grain_n > 0:
		grain_pct = int(round(float(grain_ok) * 100.0 / float(grain_n)))
	var waste_pct := 0
	if made > 0:
		waste_pct = int(round(float(wasted) * 100.0 / float(made)))
	var use_pct := 0
	if over > 0:
		use_pct = int(round(float(sunk) * 100.0 / float(over)))
	print("A9 grain_le12 %d%% samples %d waste %d%% made %d use %d%% over %d" % [grain_pct, grain_n, waste_pct, made, use_pct, over])
	print("A14 %d/100" % a14)
	_wang_trials()
	if a1_ok and a2_ok and a4_ok:
		print("SWEEP PASSED")
		return 0
	print("SWEEP FAILED")
	return 1


func wang_only() -> int:
	_wang_trials()
	return 0


func _wang_trials() -> void:
	var fight_ok := 0
	var amnesty_ok := 0
	var idle_fail := 0
	var seize_n := 0
	var time_n := 0
	var i := 0
	while i < 100:
		i += 1
		if _wang_fight(3000 + i):
			fight_ok += 1
		elif GameState.event_flags.has("wanglun_seized"):
			seize_n += 1
		elif GameState.event_flags.has("wanglun_timeout"):
			time_n += 1
		if _wang_amnesty(4000 + i):
			amnesty_ok += 1
		if _wang_idle(5000 + i):
			idle_fail += 1
	var seized: bool = _wang_f1()
	print("A13 fight %d/100 amnesty %d/100 idle_fail %d/100 seize %d timeout %d" % [fight_ok, amnesty_ok, idle_fail, seize_n, time_n])
	print("A13b %s" % ["PASS" if seized else "FAIL"])


func _wang_fight(seed: int) -> bool:
	_arm_wang(seed)
	GameState.choose_event("wanglun", "fight")
	return _march(true)


func _wang_amnesty(seed: int) -> bool:
	_arm_wang(seed)
	GameState.resources["food"] = 5000
	GameState.resources["money"] = 5000
	GameState.choose_event("wanglun", "amnesty")
	var quiet: bool = Campaign.alive("wanglun") <= 0
	var picked: bool = str(GameState.event_choice.get("wanglun", "")) == "amnesty"
	var clean: bool = not GameState.event_flags.has("wanglun_seized")
	return quiet and picked and clean


func _wang_idle(seed: int) -> bool:
	_arm_wang(seed)
	GameState.choose_event("wanglun", "fight")
	var step := 0
	while step < 12:
		step += 1
		Hunt.step_rebels()
		if GameState.event_flags.has("wanglun_seized") or GameState.event_flags.has("wanglun_timeout"):
			return true
		if Campaign.alive("wanglun") <= 0:
			return false
		GameState.turn += 1
		GameState.restore_movement()
		Campaign.on_turn()
	var failed: bool = GameState.event_flags.has("wanglun_seized") or GameState.event_flags.has("wanglun_timeout")
	return failed


func _march(chase: bool) -> bool:
	var step := 0
	while step < 12:
		step += 1
		if chase:
			Hunt.step()
		if Campaign.alive("wanglun") <= 0 and not GameState.event_flags.has("wanglun_seized"):
			return true
		if GameState.event_flags.has("wanglun_seized") or GameState.event_flags.has("wanglun_timeout"):
			return false
		GameState.turn += 1
		GameState.restore_movement()
		Campaign.on_turn()
	var held: bool = Campaign.alive("wanglun") <= 0 and not GameState.event_flags.has("wanglun_seized")
	return held


func _arm_wang(seed: int) -> void:
	GameState.new_game()
	GameState.seed_value = seed
	GameState.rng.seed = seed
	GameState.turn = 41


func _wang_f1() -> bool:
	_arm_wang(7)
	GameState.choose_event("wanglun", "fight")
	var city := DataDB.city_by_id("yangzhou")
	var spot := Vector2i(int(city.get("q", 28)), int(city.get("r", 35)))
	for u_v in GameState.units:
		var u: Dictionary = u_v
		if str(u.get("tag", "")) == "wanglun" and int(u.get("hp", 0)) > 0:
			GameState.set_pos(int(u.get("uid", -1)), spot)
			break
	Campaign.seize_yangzhou()
	var flipped: bool = str(city.get("faction", "")) == "rebel" and GameState.jingnei_mod < 0
	GameState.new_game()
	var home := DataDB.city_by_id("yangzhou")
	var restored: bool = str(home.get("faction", "")) == "song"
	return flipped and restored


func _spend_power() -> void:
	if GameState.tech_designing == "":
		for tech_v in DataDB.techs:
			var tech: Dictionary = tech_v
			var id := str(tech.get("id", ""))
			if GameState.tech_state(id) == "available":
				GameState.start_design(id)
				break
	if GameState.tech_trials.size() >= GameState.trial_slots():
		return
	var pending: Array = GameState.tech_blueprints.duplicate()
	for bid_v in pending:
		if GameState.start_trial(str(bid_v)):
			return


func _record(flags: Array[bool], first: Dictionary) -> bool:
	var filled := not GameState.orders.is_empty()
	var ok := false
	for item_v in GameState.orders:
		var item: Dictionary = item_v
		if GoalSystem.completable(item):
			ok = true
	flags.append(ok)
	for id_v in GameState.pending_events:
		var id := str(id_v)
		if not first.has(id):
			first[id] = GameState.turn
	for id_v2 in GameState.event_log:
		var logged := str(id_v2)
		if not first.has(logged):
			first[logged] = GameState.turn
	for key_v in GameState.event_choice.keys():
		var chosen := str(key_v)
		if not first.has(chosen):
			first[chosen] = GameState.turn
	return filled
