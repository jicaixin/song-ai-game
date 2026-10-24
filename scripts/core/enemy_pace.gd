class_name EnemyPace
extends RefCounted

## Enemy-phase animation clock. Default speed is 2×. Esc skips the rest of the motion.

static var active := false
static var skip := false
static var attacks_only := false
static var boost := false
static var speed := 2.0
static var pinned := false
static var started_ms := 0
static var index := 0
static var total := 0


static func begin() -> void:
	active = true
	skip = false
	attacks_only = false
	boost = false
	if not pinned:
		speed = 2.0
	index = 0
	total = 0
	started_ms = Time.get_ticks_msec()


static func finish() -> void:
	active = false
	skip = false
	attacks_only = false
	boost = false
	pinned = false
	index = 0
	total = 0


static func scale(seconds: float) -> float:
	if not active:
		return seconds
	if skip:
		return 0.0
	var rate := speed
	if boost:
		rate *= 4.0
	if rate < 0.25:
		rate = 0.25
	return seconds / rate


static func skip_moves() -> bool:
	if not active:
		return false
	return skip or attacks_only


static func enforce_cap(big: bool) -> void:
	if not active or skip:
		return
	var cap := 12000 if big else 6000
	if Time.get_ticks_msec() - started_ms >= cap:
		attacks_only = true


static func request_skip() -> void:
	if active:
		skip = true
