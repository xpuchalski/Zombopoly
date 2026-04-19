extends Area2D

var dungeon_id: String = ""
var cost: int = 0

func setup(new_dungeon_id: String, new_cost: int) -> void:
	dungeon_id = new_dungeon_id
	cost = new_cost
