extends RefCounted

const EventSystem = preload("res://scripts/core/event_system.gd")
const GoalSystem = preload("res://scripts/core/goal_system.gd")

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
		var flags: Array[bool] = []
		var first := {}
		if not _record(flags, first):
			a2_fail += 1
		var step := 0
		while step < 85:
			step += 1
			GameState.finish_turn()
			EventSystem.scan()
			GoalSystem.on_turn()
			if not _record(flags, first):
				a2_fail += 1
		var i := 0
		while i < flags.size() - 2:
			if not flags[i] and not flags[i + 1] and not flags[i + 2]:
				a1_fail += 1
				i = flags.size()
			i += 1
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
	if a1_ok and a2_ok and a4_ok:
		print("SWEEP PASSED")
		return 0
	print("SWEEP FAILED")
	return 1


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
