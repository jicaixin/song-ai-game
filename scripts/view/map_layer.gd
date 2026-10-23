extends Node2D

var kind := "terrain"

func _draw() -> void:
	var map := get_parent()
	if map == null:
		return
	if kind == "terrain":
		map.call("paint_terrain", self)
	elif kind == "highlight":
		map.call("paint_highlight", self)
	else:
		map.call("paint_bars", self)
