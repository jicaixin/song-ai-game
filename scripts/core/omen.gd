class_name Omen
extends RefCounted

## Countdown cards for the two or three turns before a large event.

const LIST := [
	{"id": "haoshui", "event": "haoshui", "from": 11, "until": 13, "title": "好水川", "sub": "镇戎军以北 · 天都山集结", "order": "部署镇戎周边", "place": "zhenrong", "city": "zhenrong", "need": 2},
	{"id": "zengbi", "event": "zengbi", "from": 23, "until": 26, "title": "庆历增币", "sub": "辽聚兵幽蓟", "order": "守住雄州一线", "place": "xiongzhou", "city": "xiongzhou", "need": 1},
	{"id": "dingchuan", "event": "dingchuan", "from": 30, "until": 32, "title": "定川寨", "sub": "西夏三路集结", "order": "留意定川集结", "place": "dingchuan", "city": "zhenrong", "need": 1},
	{"id": "wanglun", "event": "wanglun", "from": 38, "until": 40, "title": "王伦兵变", "sub": "沂州欠饷，兵心不稳", "order": "留意沂州兵变", "place": "yizhou", "city": "yizhou", "need": 1},
	{"id": "zhanghai", "event": "zhanghai", "from": 43, "until": 44, "title": "商山聚众", "sub": "商山一带有人聚众", "order": "留意商山聚众", "place": "shang", "city": "yanzhou", "need": 1},
	{"id": "heyi", "event": "heyi", "from": 52, "until": 58, "title": "庆历和议", "sub": "西夏使者将来议", "order": "留意西夏遣使", "place": "xingqing", "city": "xingqing", "need": 1},
	{"id": "wangze", "event": "wangze", "from": 77, "until": 79, "title": "贝州流言", "sub": "贝州、冀州一带流言四起", "order": "留意贝州流言", "place": "beizhou", "city": "beizhou", "need": 1},
	{"id": "yuanhao", "event": "yuanhao", "from": 80, "until": 81, "title": "兴庆宫变", "sub": "兴庆府宫中不和", "order": "留意兴庆宫变", "place": "xingqing", "city": "xingqing", "need": 1},
]


static func current() -> Dictionary:
	var best: Dictionary = {}
	var best_until := 999
	for row_v in LIST:
		var row: Dictionary = row_v
		var at := GameState.turn
		if at < int(row.get("from", 1)) or at > int(row.get("until", 1)):
			continue
		var ev := str(row.get("event", ""))
		if GameState.event_choice.has(ev) or GameState.event_log.has(ev):
			continue
		var until := int(row.get("until", 99))
		if until < best_until:
			best_until = until
			best = row
	return best


static func turns_left(row: Dictionary) -> int:
	if row.is_empty():
		return 0
	var left := int(row.get("until", GameState.turn)) - GameState.turn + 1
	if left < 1:
		left = 1
	return left


static func urgent(row: Dictionary) -> bool:
	return turns_left(row) <= 1
