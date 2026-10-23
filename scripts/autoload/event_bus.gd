extends Node

signal state_changed
signal advisor_changed
signal turn_started
signal combat_finished
signal unit_cycled(uid: int)
signal oriented(kind: String)
signal map_boot(step: int, total: int, text: String)
signal map_ready
signal hover_changed(hex: Vector2i)
signal camera_moved
signal tile_menu(open: bool)
