class_name Calendar
extends RefCounted

const MONTHS: Array[String] = [
	"", "正月", "二月", "三月", "四月", "五月", "六月",
	"七月", "八月", "九月", "十月", "十一月", "腊月",
]
const NIAN: Array[String] = ["", "元", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
const SEASON_NAME := {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}

static func month_name(month: int) -> String:
	if month >= 1 and month <= 12:
		return MONTHS[month]
	return "%d月" % month


static func season(month: int) -> String:
	if month <= 3:
		return "spring"
	if month <= 6:
		return "summer"
	if month <= 9:
		return "autumn"
	return "winter"


static func era_name(year: int, month: int) -> String:
	if year == 1040 and month == 1:
		return "宝元三年"
	if year == 1040:
		return "康定元年"
	if year == 1041 and month <= 10:
		return "康定二年"
	if year == 1041:
		return "庆历元年"
	if year >= 1042 and year <= 1048:
		var n := year - 1040
		var label := NIAN[n] if n >= 0 and n < NIAN.size() else str(n)
		return "庆历%s年" % label
	if year == 1049:
		return "皇祐元年"
	return "%d年" % year


static func format_date(year: int, month: int) -> String:
	return "%s %s · %d" % [era_name(year, month), month_name(month), year]
