extends Node

var player_count: int = 1
var selected_characters: Array[int] = []
var global_turn: int = 1

var players: Array[Dictionary] = []

var unlocked_dungeons: Dictionary = {}

func build_players() -> void:
	players.clear()

	for i in range(selected_characters.size()):
		players.append({
			"player_id": i + 1,
			"character_id": selected_characters[i],
			"max_hp": 10,
			"hp": 10,
			"move_radius": 450.0,
			"money": 0
		})
		
func reset_run_state() -> void:
	global_turn = 1
	players.clear()
	unlocked_dungeons.clear()

func is_dungeon_unlocked(dungeon_id: String) -> bool:
	return unlocked_dungeons.get(dungeon_id, false)

func unlock_dungeon(dungeon_id: String) -> void:
	unlocked_dungeons[dungeon_id] = true
