extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/actors/Zombie.tscn")
const ITEM_SCENE := preload("res://scenes/actors/ItemPickup.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/actors/DungeonEntrance.tscn")

@onready var players_node: Node2D = $Players
@onready var zombies_node: Node2D = $Zombies
@onready var items_node: Node2D = $Items
@onready var turn_radius_drawer: Node2D = $TurnRadiusDrawer

@onready var turn_label: Label = $CanvasLayer/HUD/TurnLabel
@onready var end_turn_button: Button = $CanvasLayer/HUD/EndTurnButton

@onready var combat_panel: Panel = $CanvasLayer/HUD/CombatPanel
@onready var combat_label: Label = $CanvasLayer/HUD/CombatPanel/CombatLabel
@onready var attack_button: Button = $CanvasLayer/HUD/CombatPanel/AttackButton
@onready var run_button: Button = $CanvasLayer/HUD/CombatPanel/RunButton

@onready var dungeon_entrances_node: Node2D = $DungeonEntrances

@onready var info_panel: Panel = $CanvasLayer/HUD/InfoPanel
@onready var info_label: Label = $CanvasLayer/HUD/InfoPanel/InfoLabel
@onready var info_close_button: Button = $CanvasLayer/HUD/InfoPanel/InfoCloseButton

var players: Array = []
var zombies: Array = []
var items: Array = []
var dungeon_entrances: Array = []

var current_player_index: int = 0
var combat_open: bool = false

var active_combat_player = null
var active_combat_zombies: Array = []
var active_combat_target_player = null
var combat_mode: String = ""

var rng := RandomNumberGenerator.new()
var zombie_cap: int = 5
var map_min: Vector2 = Vector2(100, 100)
var map_max: Vector2 = Vector2(900, 700)

func _ready() -> void:
	GameData.build_players()
	_spawn_players()
	_spawn_test_zombies()
	_spawn_test_items()
	_spawn_test_dungeon_entrances()

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	run_button.pressed.connect(_on_run_pressed)
	info_close_button.pressed.connect(_on_info_close_pressed)
	rng.randomize()
	GameData.global_turn = 1
	combat_panel.visible = false

	_start_current_player_turn()

func _on_info_close_pressed() -> void:
	info_panel.visible = false

func _spawn_players() -> void:
	var spawn_positions := [
		Vector2(200, 200),
		Vector2(400, 200),
		Vector2(200, 400),
		Vector2(400, 400)
	]

	for i in range(GameData.players.size()):
		var player_instance = PLAYER_SCENE.instantiate()
		players_node.add_child(player_instance)

		player_instance.setup_from_data(GameData.players[i])
		player_instance.snap_to_position(spawn_positions[i])

		players.append(player_instance)

func _spawn_test_zombies() -> void:
	var zombie_positions := [
		Vector2(300, 200),
		Vector2(325, 210),
		Vector2(500, 300)
	]

	for i in range(zombie_positions.size()):
		var zombie_instance = ZOMBIE_SCENE.instantiate()
		zombies_node.add_child(zombie_instance)

		zombie_instance.global_position = zombie_positions[i]
		zombie_instance.setup(i + 1)

		zombie_instance.body_entered.connect(_on_zombie_body_entered.bind(zombie_instance))

		zombies.append(zombie_instance)

func _spawn_test_dungeon_entrances() -> void:
	var entrance_data := [
		{ "pos": Vector2(600, 200), "id": "dungeon_1", "cost": 10 },
		{ "pos": Vector2(700, 450), "id": "dungeon_2", "cost": 20 }
	]

	for i in range(entrance_data.size()):
		var entrance_instance = DUNGEON_ENTRANCE_SCENE.instantiate()
		dungeon_entrances_node.add_child(entrance_instance)

		entrance_instance.global_position = entrance_data[i]["pos"]
		entrance_instance.setup(entrance_data[i]["id"], entrance_data[i]["cost"])

		entrance_instance.body_entered.connect(_on_dungeon_entrance_body_entered.bind(entrance_instance))

		dungeon_entrances.append(entrance_instance)

func _on_dungeon_entrance_body_entered(body: Node2D, entrance: Area2D) -> void:
	if combat_open:
		return

	var current_player = players[current_player_index]

	if body != current_player:
		return

	if current_player.is_zombified:
		_enter_dungeon(entrance.dungeon_id)
		return

	if GameData.is_dungeon_unlocked(entrance.dungeon_id):
		_show_info("Dungeon already unlocked.\nEntering now.")
		_enter_dungeon(entrance.dungeon_id)
		return

	if current_player.money >= entrance.cost:
		current_player.money -= entrance.cost
		GameData.unlock_dungeon(entrance.dungeon_id)
		_refresh_turn_label()
		_show_info("Unlocked %s for %d money.\nEntering now." % [entrance.dungeon_id, entrance.cost])
		_enter_dungeon(entrance.dungeon_id)
	else:
		_show_info("Not enough money.\nNeed %d money." % entrance.cost)

func _show_info(text: String) -> void:
	info_label.text = text
	info_panel.visible = true
	
func _enter_dungeon(dungeon_id: String) -> void:
	print("Entering dungeon: %s" % dungeon_id)
	get_tree().change_scene_to_file("res://scenes/world/DungeonTest.tscn")

func _spawn_test_items() -> void:
	var item_data := [
		{ "pos": Vector2(350, 200), "type": "hp" },
		{ "pos": Vector2(450, 400), "type": "radius" },
		{ "pos": Vector2(250, 300), "type": "hp" }
	]

	for i in range(item_data.size()):
		var item_instance = ITEM_SCENE.instantiate()
		items_node.add_child(item_instance)

		item_instance.global_position = item_data[i]["pos"]
		item_instance.setup(i + 1, item_data[i]["type"])

		item_instance.body_entered.connect(_on_item_body_entered.bind(item_instance))

		items.append(item_instance)

func _start_current_player_turn() -> void:
	for i in range(players.size()):
		if players[i] != null:
			players[i].end_turn()
			players[i].movement_locked = false

	var safety := 0
	while safety < players.size() and _is_player_defeated(players[current_player_index]):
		current_player_index += 1
		if current_player_index >= players.size():
			current_player_index = 0
		safety += 1

	if safety >= players.size():
		turn_label.text = "No players remaining"
		return

	var current_player = players[current_player_index]
	current_player.start_turn()

	turn_radius_drawer.target_player = current_player
	turn_radius_drawer.queue_redraw()

	_refresh_turn_label()

func _refresh_turn_label() -> void:
	var current_player = players[current_player_index]

	if current_player == null or not is_instance_valid(current_player) or not current_player.visible:
		turn_label.text = "Turn %d | Defeated Player" % GameData.global_turn
	else:
		var state_text := "Zombie" if current_player.is_zombified else "Human"
		turn_label.text = "Turn %d | Player %d | %s | HP: %d | Radius: %.0f | Money: %d" % [
			GameData.global_turn,
			current_player.player_id,
			state_text,
			current_player.hp,
			current_player.move_radius,
			current_player.money
		]

	turn_radius_drawer.queue_redraw()
	
func _process_global_turn_end() -> void:
	GameData.global_turn += 1
	print("Global Turn %d" % GameData.global_turn)

	_respawn_zombies_up_to_cap()

	if GameData.global_turn % 3 == 0:
		_respawn_items()

	_refresh_turn_label()

func _on_end_turn_pressed() -> void:
	if combat_open:
		return

	if players[current_player_index] != null:
		players[current_player_index].end_turn()

	current_player_index += 1
	if current_player_index >= players.size():
		current_player_index = 0
		_process_global_turn_end()
	_start_current_player_turn()

func _respawn_zombies_up_to_cap() -> void:
	_cleanup_zombie_array()

	var living_zombie_count := zombies.size()
	var to_spawn := zombie_cap - living_zombie_count
	if to_spawn <= 0:
		return

	for i in range(to_spawn):
		var spawn_pos = _find_valid_zombie_spawn_position()
		if spawn_pos == null:
			break

		_spawn_single_zombie(spawn_pos)

func _cleanup_zombie_array() -> void:
	var cleaned: Array = []

	for zombie in zombies:
		if zombie != null and is_instance_valid(zombie):
			cleaned.append(zombie)

	zombies = cleaned

func _spawn_single_zombie(pos: Vector2) -> void:
	var zombie_instance = ZOMBIE_SCENE.instantiate()
	zombies_node.add_child(zombie_instance)

	zombie_instance.global_position = pos
	zombie_instance.setup(zombies.size() + 1)
	zombie_instance.body_entered.connect(_on_zombie_body_entered.bind(zombie_instance))

	zombies.append(zombie_instance)

func _find_valid_zombie_spawn_position():
	for attempt in range(100):
		var pos = Vector2(
			rng.randf_range(map_min.x, map_max.x),
			rng.randf_range(map_min.y, map_max.y)
		)

		if _is_inside_any_player_radius(pos):
			continue

		if _position_overlaps_existing_collision(pos):
			continue

		return pos

	return null

func _is_inside_any_player_radius(pos: Vector2) -> bool:
	for player in players:
		if player == null or player.is_dead():
			continue

		if pos.distance_to(player.global_position) <= player.move_radius:
			return true

	return false

func _position_overlaps_existing_collision(pos: Vector2) -> bool:
	for player in players:
		if player == null or player.is_dead():
			continue
		if pos.distance_to(player.global_position) < 40.0:
			return true

	for zombie in zombies:
		if zombie == null or not is_instance_valid(zombie):
			continue
		if pos.distance_to(zombie.global_position) < 40.0:
			return true

	for item in items:
		if item == null:
			continue
		if item.collected:
			continue
		if pos.distance_to(item.global_position) < 40.0:
			return true

	return false

func _unhandled_input(event: InputEvent) -> void:
	if combat_open:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var current_player = players[current_player_index]
			current_player.try_move_to(event.position)

func _on_item_body_entered(body: Node2D, item: Area2D) -> void:
	if combat_open:
		return

	var current_player = players[current_player_index]

	if body != current_player:
		return

	if item.collected:
		return

	match item.item_type:
		"hp":
			current_player.heal(5)
		"radius":
			current_player.increase_move_radius(50.0)

	_refresh_turn_label()
	item.collect()

func _respawn_items() -> void:
	for item in items:
		if item == null:
			continue
		if not item.collected:
			continue
		if _is_player_on_item_spawn(item.spawn_position):
			continue

		item.respawn()

func _is_player_on_item_spawn(pos: Vector2) -> bool:
	for player in players:
		if player == null or player.is_dead():
			continue

		if player.global_position.distance_to(pos) < 20.0:
			return true

	return false

func _get_human_player_touched_by(attacker) -> Node:
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		if player == attacker:
			continue
		if not player.visible:
			continue
		if player.is_zombified:
			continue

		if attacker.global_position.distance_to(player.global_position) <= 32.0:
			return player

	return null

func _process(delta: float) -> void:
	if combat_open:
		return

	if players.is_empty():
		return

	var current_player = players[current_player_index]
	if current_player == null or not is_instance_valid(current_player):
		return
	if not current_player.visible:
		return

	if current_player.is_zombified:
		var target = _get_human_player_touched_by(current_player)
		if target != null:
			_start_player_vs_player_combat(current_player, target)
			
func _start_player_vs_player_combat(attacker, defender) -> void:
	if combat_open:
		return

	combat_open = true
	combat_mode = "player_vs_player"
	active_combat_player = attacker
	active_combat_target_player = defender
	active_combat_zombies.clear()

	attacker.movement_locked = true
	attacker.target_position = attacker.global_position

	combat_panel.visible = true
	_update_combat_label()

func _on_zombie_body_entered(body: Node2D, zombie: Area2D) -> void:
	if combat_open:
		return

	var current_player = players[current_player_index]

	if body != current_player:
		return

	if current_player.is_zombified:
		return

	var encountered_zombies = _get_zombies_touching_player(current_player)
	if encountered_zombies.is_empty():
		encountered_zombies.append(zombie)

	combat_open = true
	combat_mode = "zombies"
	active_combat_player = current_player
	active_combat_target_player = null
	active_combat_zombies = encountered_zombies

	current_player.movement_locked = true
	current_player.target_position = current_player.global_position

	combat_panel.visible = true
	_update_combat_label()

func _update_combat_label() -> void:
	if active_combat_player == null:
		combat_label.text = "No active combat."
		return

	if combat_mode == "zombies":
		var text = "Player %d | HP: %d\n" % [
			active_combat_player.player_id,
			active_combat_player.hp
		]

		text += "Zombies:\n"

		for i in range(active_combat_zombies.size()):
			var zombie = active_combat_zombies[i]
			if zombie == null or not is_instance_valid(zombie):
				continue

			text += "- Zombie %d | HP: %d\n" % [zombie.zombie_id, zombie.hp]

		combat_label.text = text
		return

	if combat_mode == "player_vs_player":
		if active_combat_target_player == null or not is_instance_valid(active_combat_target_player):
			combat_label.text = "Target player missing."
			return

		combat_label.text = "Player %d (%s) | HP: %d\nvs\nPlayer %d (%s) | HP: %d" % [
			active_combat_player.player_id,
			"Zombie" if active_combat_player.is_zombified else "Human",
			active_combat_player.hp,
			active_combat_target_player.player_id,
			"Zombie" if active_combat_target_player.is_zombified else "Human",
			active_combat_target_player.hp
		]

func _get_zombies_touching_player(player) -> Array:
	var result: Array = []

	for zombie in zombies:
		if zombie == null or not is_instance_valid(zombie):
			continue

		var distance = player.global_position.distance_to(zombie.global_position)
		if distance <= 32.0:
			result.append(zombie)

	return result

func _on_attack_pressed() -> void:
	if not combat_open:
		return

	if active_combat_player == null:
		return

	if combat_mode == "zombies":
		_cleanup_active_combat_zombies()

		if active_combat_zombies.is_empty():
			_end_combat()
			return

		var target_zombie = active_combat_zombies[0]
		var damage = active_combat_player.basic_attack_damage()
		target_zombie.take_damage(damage)

		if target_zombie.is_dead():
			var reward: int = target_zombie.money_drop
			if active_combat_player.can_collect_rewards():
				active_combat_player.add_money(reward)

			zombies.erase(target_zombie)
			active_combat_zombies.erase(target_zombie)
			target_zombie.queue_free()

			_cleanup_active_combat_zombies()

			if active_combat_zombies.is_empty():
				combat_label.text = "All zombies defeated!"
				_end_combat()
				return

		var total_damage: int = 0
		for zombie in active_combat_zombies:
			if zombie == null or not is_instance_valid(zombie):
				continue
			total_damage += zombie.attack_damage

		active_combat_player.take_damage(total_damage)

		if active_combat_player.is_dead():
			_handle_player_defeat(active_combat_player)

			if _count_remaining_players() <= 1 and GameData.player_count > 1:
				combat_open = true
				combat_panel.visible = true
				attack_button.visible = false
				run_button.visible = false

				var winner_id := -1
				for player in players:
					if player != null and is_instance_valid(player) and player.visible:
						winner_id = player.player_id
						break

				if winner_id != -1:
					combat_label.text = "Game Over\nPlayer %d wins!" % winner_id
				else:
					combat_label.text = "Game Over\nNo players remain."
				return

			combat_label.text = "Player %d was defeated!" % active_combat_player.player_id
			_end_combat()
			return

		_update_combat_label()
		_refresh_turn_label()
		return

	if combat_mode == "player_vs_player":
		if active_combat_target_player == null or not is_instance_valid(active_combat_target_player):
			_end_combat()
			return

		var damage = active_combat_player.basic_attack_damage()
		active_combat_target_player.take_damage(damage)

		if active_combat_target_player.is_dead():
			_handle_player_defeat(active_combat_target_player)

			if _count_remaining_players() <= 1 and GameData.player_count > 1:
				combat_open = true
				combat_panel.visible = true
				attack_button.visible = false
				run_button.visible = false

				var winner_id := -1
				for player in players:
					if player != null and is_instance_valid(player) and player.visible:
						winner_id = player.player_id
						break

				if winner_id != -1:
					combat_label.text = "Game Over\nPlayer %d wins!" % winner_id
				else:
					combat_label.text = "Game Over\nNo players remain."
				return

			_update_combat_label()
			_end_combat()
			return

		# Defender fights back
		active_combat_player.take_damage(active_combat_target_player.basic_attack_damage())

		if active_combat_player.is_dead():
			_handle_player_defeat(active_combat_player)

			if _count_remaining_players() <= 1 and GameData.player_count > 1:
				combat_open = true
				combat_panel.visible = true
				attack_button.visible = false
				run_button.visible = false

				var winner_id := -1
				for player in players:
					if player != null and is_instance_valid(player) and player.visible:
						winner_id = player.player_id
						break

				if winner_id != -1:
					combat_label.text = "Game Over\nPlayer %d wins!" % winner_id
				else:
					combat_label.text = "Game Over\nNo players remain."
				return

			_update_combat_label()
			_end_combat()
			return

		_update_combat_label()
		_refresh_turn_label()

func _handle_player_defeat(player) -> void:
	if player.is_zombified:
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		print("Zombified Player %d has been permanently defeated." % player.player_id)
	else:
		player.zombify()
		print("Player %d has become zombified." % player.player_id)

func _on_run_pressed() -> void:
	if not combat_open:
		return

	if active_combat_player == null:
		return

	var angle = randf() * TAU
	var escape_position = active_combat_player.turn_origin + Vector2.RIGHT.rotated(angle) * active_combat_player.move_radius

	active_combat_player.snap_to_position(escape_position)

	_end_combat()

func _end_combat() -> void:
	combat_open = false
	combat_panel.visible = false
	attack_button.visible = true
	run_button.visible = true

	if active_combat_player != null:
		active_combat_player.movement_locked = false

	active_combat_player = null
	active_combat_target_player = null
	active_combat_zombies.clear()
	combat_mode = ""

	turn_radius_drawer.queue_redraw()
	_refresh_turn_label()

func _cleanup_active_combat_zombies() -> void:
	var cleaned: Array = []

	for zombie in active_combat_zombies:
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			cleaned.append(zombie)

	active_combat_zombies = cleaned

func _is_player_defeated(player) -> bool:
	return player == null or not is_instance_valid(player) or not player.visible

func _count_remaining_players() -> int:
	var count := 0
	for player in players:
		if player == null:
			continue
		if not is_instance_valid(player):
			continue
		if not player.visible:
			continue

		count += 1
	return count
	
func _check_for_game_end() -> void:
	var remaining := _count_remaining_players()

	if GameData.player_count == 1:
		return

	if remaining <= 1:
		combat_open = true
		combat_panel.visible = true
		attack_button.visible = false
		run_button.visible = false

		var winner_id := -1
		for player in players:
			if player != null and not player.is_dead():
				winner_id = player.player_id
				break

		if winner_id != -1:
			combat_label.text = "Game Over\nPlayer %d wins!" % winner_id
		else:
			combat_label.text = "Game Over\nNo players remain."
