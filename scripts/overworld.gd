extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/actors/Zombie.tscn")
const ITEM_SCENE := preload("res://scenes/actors/ItemPickup.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/actors/DungeonEntrance.tscn")
const DUNGEON_SCENE := preload("res://scenes/world/DungeonTest.tscn")
const PORTRAIT_PATH := "res://assets/characters/portraits/%d.png"
const BATTLE_PORTRAIT_SIZE := Vector2(440, 440)
const BATTLE_PORTRAIT_Y := 170.0
const BATTLE_ATTACK_MOVE_DISTANCE := 90.0
const ENTITY_OVERLAP_DISTANCE := 52.0
const ITEM_BLOCK_DISTANCE := 32.0
const PLAYER_TOUCH_DISTANCE := 40.0
const ZOMBIE_RESPAWN_INTERVAL := 3
const ITEM_RESPAWN_INTERVAL := 5
const BOSS_RESPAWN_INTERVAL := 10
const DUNGEON_INSTANCE_SPACING := 12000.0

@onready var players_node: Node2D = $Players
@onready var zombies_node: Node2D = $Zombies
@onready var items_node: Node2D = $Items
@onready var dungeon_entrances_node: Node2D = $DungeonEntrances
@onready var turn_radius_drawer: Node2D = $TurnRadiusDrawer
@onready var camera: Camera2D = $Camera2D
@onready var active_dungeon_holder: Node2D = $ActiveDungeonHolder
@onready var hud: Control = $CanvasLayer/HUD
@onready var turn_label: Label = $CanvasLayer/HUD/TurnLabel
@onready var end_turn_button: Button = $CanvasLayer/HUD/EndTurnButton
@onready var turn_order_list: HBoxContainer = $CanvasLayer/HUD/TurnOrderBar/UnitList
@onready var combat_panel: Panel = $CanvasLayer/HUD/CombatPanel
@onready var combat_label: Label = $CanvasLayer/HUD/CombatPanel/CombatLabel
@onready var attack_button: Button = $CanvasLayer/HUD/CombatPanel/AttackButton
@onready var special_button: Button = $CanvasLayer/HUD/CombatPanel/SpecialButton
@onready var block_button: Button = $CanvasLayer/HUD/CombatPanel/BlockButton
@onready var run_button: Button = $CanvasLayer/HUD/CombatPanel/RunButton
@onready var info_panel: Panel = $CanvasLayer/HUD/InfoPanel
@onready var info_label: Label = $CanvasLayer/HUD/InfoPanel/InfoLabel
@onready var info_close_button: Button = $CanvasLayer/HUD/InfoPanel/InfoCloseButton
@onready var item_spawn_points_node: Node = get_node_or_null("ItemSpawnPoints")
@onready var dungeon_spawn_points_node: Node = get_node_or_null("DungeonSpawnPoints")

var players: Array = []
var zombies: Array = []
var items: Array = []
var dungeon_entrances: Array = []
var active_dungeon_instances: Dictionary = {}
var player_return_positions: Dictionary = {}
var current_player_index: int = 0
var combat_open: bool = false
var active_combat_player = null
var active_combat_zombies: Array = []
var zombie_turn_in_progress: bool = false
var combat_action_locked: bool = false
var battle_player_portrait: TextureRect
var battle_zombie_portrait: TextureRect
var loading_rect: ColorRect
var battle_player_home_position := Vector2.ZERO
var battle_zombie_home_position := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var zombie_cap: int = 6
var map_min: Vector2 = Vector2(-2400, -2400)
var map_max: Vector2 = Vector2(2400, 2400)
var camera_follow_speed: float = 6.0
var camera_zoom_step: float = 0.10
var camera_zoom_min: float = 0.35
var camera_zoom_max: float = 2.0
var camera_zoom_speed: float = 8.0
var target_camera_zoom: Vector2 = Vector2.ONE

func _ready() -> void:
	rng.randomize()
	if GameData.players.is_empty():
		GameData.build_players()
	_spawn_players()
	_spawn_items_from_points()
	_spawn_dungeon_entrances_from_points()
	_respawn_zombies_up_to_cap()
	combat_panel.visible = false
	info_panel.visible = false
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	attack_button.pressed.connect(_on_attack_pressed)
	special_button.pressed.connect(_on_special_pressed)
	block_button.pressed.connect(_on_block_pressed)
	run_button.pressed.connect(_on_run_pressed)
	info_close_button.pressed.connect(func(): info_panel.visible = false)
	_ensure_battle_portraits()
	_ensure_loading_overlay()
	_update_battle_portrait_positions()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_battle_portrait_positions)
	target_camera_zoom = camera.zoom
	_start_current_player_turn()
	refresh_turn_order_bar()

func _process(delta: float) -> void:
	_update_camera_follow(delta)
	_update_camera_zoom(delta)

func _unhandled_input(event: InputEvent) -> void:
	if loading_rect.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_adjust_camera_zoom(-camera_zoom_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				_adjust_camera_zoom(camera_zoom_step)
			MOUSE_BUTTON_LEFT:
				if combat_open and _is_current_player_in_active_combat():
					return
				var current_player = _get_current_player()
				if current_player != null:
					current_player.try_move_to(get_global_mouse_position())

func _adjust_camera_zoom(delta_amount: float) -> void:
	var next_zoom = clamp(target_camera_zoom.x + delta_amount, camera_zoom_min, camera_zoom_max)
	target_camera_zoom = Vector2(next_zoom, next_zoom)

func _update_camera_zoom(delta: float) -> void:
	camera.zoom = camera.zoom.lerp(target_camera_zoom, delta * camera_zoom_speed)

func _get_current_player():
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return null
	var player = players[current_player_index]
	if player == null or not is_instance_valid(player) or not player.visible:
		return null
	return player

func _get_active_combat_zombie():
	_cleanup_active_combat_zombies()
	return active_combat_zombies[0] if not active_combat_zombies.is_empty() else null

func _spawn_players() -> void:
	var spawn_positions := [
		Vector2(300, 300),
		Vector2(650, 300),
		Vector2(300, 650),
		Vector2(650, 650)
	]
	
	for i in range(GameData.players.size()):
		var player_instance = PLAYER_SCENE.instantiate()
		players_node.add_child(player_instance)
		player_instance.setup_from_data(GameData.players[i])
		player_instance.snap_to_position(spawn_positions[i])
		players.append(player_instance)

func _spawn_items_from_points() -> void:
	if item_spawn_points_node == null:
		return
	for child in item_spawn_points_node.get_children():
		if not child is Node2D:
			continue
		var item_instance = ITEM_SCENE.instantiate()
		items_node.add_child(item_instance)
		item_instance.global_position = child.global_position
		item_instance.setup(GameData.roll_random_item_id())
		item_instance.body_entered.connect(_on_item_body_entered.bind(item_instance))
		items.append(item_instance)

func _spawn_dungeon_entrances_from_points() -> void:
	if dungeon_spawn_points_node == null:
		return
	var fallback_index := 1
	for child in dungeon_spawn_points_node.get_children():
		if not child is Node2D:
			continue
		var entrance_instance = DUNGEON_ENTRANCE_SCENE.instantiate()
		dungeon_entrances_node.add_child(entrance_instance)
		var dungeon_id := str(child.get_meta("dungeon_id")) if child.has_meta("dungeon_id") else "dungeon_%d" % fallback_index
		var cost := int(child.get_meta("cost")) if child.has_meta("cost") else 10 * fallback_index
		entrance_instance.global_position = child.global_position
		entrance_instance.setup(dungeon_id, cost)
		entrance_instance.body_entered.connect(_on_dungeon_entrance_body_entered.bind(entrance_instance))
		dungeon_entrances.append(entrance_instance)
		fallback_index += 1

func _start_current_player_turn() -> void:
	for player in players:
		if player != null and is_instance_valid(player):
			player.end_turn()
			player.movement_locked = false
	var next_player = _find_next_available_player()
	if next_player == null:
		turn_label.text = "No players remaining"
		return
	next_player.start_turn()
	if next_player.is_in_dungeon:
		turn_radius_drawer.target_player = null
	else:
		turn_radius_drawer.target_player = next_player
	turn_radius_drawer.queue_redraw()
	_refresh_turn_label()
	_refresh_combat_ui_state()
	refresh_turn_order_bar()

func _find_next_available_player():
	var checked := 0
	while checked < players.size():
		var candidate = players[current_player_index]
		if not _is_player_defeated(candidate):
			return candidate
		current_player_index = (current_player_index + 1) % players.size()
		checked += 1
	return null

func _refresh_turn_label() -> void:
	var current_player = _get_current_player()
	if current_player == null:
		turn_label.text = "Turn %d | No active player" % GameData.global_turn
		return
	var character_data := GameData.get_character_data(current_player.character_id)
	var location_text := "Dungeon" if current_player.is_in_dungeon else "Overworld"
	turn_label.text = "Turn %d | P%d | %s | HP %d/%d | AP %d/%d | $%d | %s" % [
		GameData.global_turn,
		current_player.player_id,
		character_data.get("display_name", "Character"),
		current_player.hp,
		current_player.max_hp,
		current_player.current_ap,
		current_player.max_ap,
		current_player.money,
		location_text
	]

func refresh_turn_order_bar() -> void:
	for child in turn_order_list.get_children():
		child.queue_free()
	var active_zombie = _get_active_combat_zombie()
	for i in range(players.size()):
		var player = players[i]
		if player == null or not is_instance_valid(player) or not player.visible:
			continue
		var in_combat = combat_open and player == active_combat_player
		_add_turn_bar_entry(_get_player_portrait_texture(player.character_id), (not combat_open and i == current_player_index) or (combat_open and player == _get_current_player()), player.is_zombified, in_combat)
		if in_combat and active_zombie != null:
			_add_turn_bar_entry(_get_zombie_display_texture(active_zombie), zombie_turn_in_progress, false, true)

func _add_turn_bar_entry(texture: Texture2D, is_current: bool, is_zombified: bool = false, is_combatant: bool = false) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(62, 62)
	var entry := TextureRect.new()
	entry.custom_minimum_size = Vector2(54, 54)
	entry.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	entry.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	entry.texture = texture
	if is_current:
		entry.modulate = Color(1.0, 0.85, 0.3)
	elif is_combatant:
		entry.modulate = Color(1.0, 0.45, 0.45)
	elif is_zombified:
		entry.modulate = Color(0.8, 0.5, 1.0)
	else:
		entry.modulate = Color(0.8, 0.8, 0.8)
	panel.add_child(entry)
	turn_order_list.add_child(panel)

func _on_end_turn_pressed() -> void:
	if combat_action_locked or zombie_turn_in_progress or _is_current_player_in_active_combat():
		return
	var current_player = _get_current_player()
	if current_player != null:
		current_player.end_turn()
	_advance_to_next_player_turn()

func _advance_to_next_player_turn() -> void:
	current_player_index += 1
	if current_player_index >= players.size():
		current_player_index = 0
		_process_global_turn_end()
	_start_current_player_turn()

func _process_global_turn_end() -> void:
	GameData.global_turn += 1
	if GameData.global_turn % ZOMBIE_RESPAWN_INTERVAL == 0:
		_respawn_zombies_up_to_cap()
		_respawn_active_dungeon_enemies()
	if GameData.global_turn % ITEM_RESPAWN_INTERVAL == 0:
		_respawn_items()
		_respawn_active_dungeon_items()
	if GameData.global_turn % BOSS_RESPAWN_INTERVAL == 0:
		_respawn_active_dungeon_bosses()
	_refresh_turn_label()

func _on_attack_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	var target_zombie = _get_active_combat_zombie()
	if target_zombie == null:
		_end_combat()
		return
	combat_action_locked = true
	await _animate_player_attack()
	var result: Dictionary = active_combat_player.perform_basic_attack(target_zombie)
	combat_label.text = result.get("text", "Attack")
	await _shake_portrait(battle_zombie_portrait, battle_zombie_home_position)
	await _resolve_post_attack(target_zombie)

func _on_special_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	var target_zombie = _get_active_combat_zombie()
	if target_zombie == null:
		_end_combat()
		return
	combat_action_locked = true
	await _animate_player_attack()
	var result: Dictionary = active_combat_player.perform_special_attack(target_zombie)
	combat_label.text = result.get("text", "Special")
	if not result.get("ok", true):
		combat_action_locked = false
		_refresh_combat_ui_state()
		return
	await _shake_portrait(battle_zombie_portrait, battle_zombie_home_position)
	await _resolve_post_attack(target_zombie)

func _on_block_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	active_combat_player.activate_block()
	combat_label.text = "%s is blocking." % GameData.get_character_data(active_combat_player.character_id).get("display_name", "Player")
	combat_action_locked = false
	active_combat_player.end_turn()
	await _take_zombie_combat_turn()

func _on_run_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	var zombie = _get_active_combat_zombie()
	var push_dir := Vector2.DOWN
	if zombie != null and is_instance_valid(zombie):
		push_dir = (active_combat_player.global_position - zombie.global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.DOWN
	active_combat_player.snap_to_position(active_combat_player.global_position + push_dir * 100.0)
	active_combat_player.end_turn()
	_end_combat()
	_advance_to_next_player_turn()

func _resolve_post_attack(target_zombie) -> void:
	if target_zombie == null or not is_instance_valid(target_zombie):
		_end_combat()
		return
	if target_zombie.is_dead():
		if active_combat_player.can_collect_rewards():
			active_combat_player.add_money(target_zombie.money_drop)
		zombies.erase(target_zombie)
		active_combat_zombies.erase(target_zombie)
		target_zombie.queue_free()
		combat_action_locked = false
		_end_combat()
		_refresh_turn_label()
		_advance_to_next_player_turn()
		return
	active_combat_player.end_turn()
	combat_action_locked = false
	await _take_zombie_combat_turn()

func _take_zombie_combat_turn() -> void:
	var zombie = _get_active_combat_zombie()
	if not combat_open or active_combat_player == null or zombie == null:
		_end_combat()
		return
	zombie_turn_in_progress = true
	_refresh_combat_ui_state()
	refresh_turn_order_bar()
	await get_tree().create_timer(1.0).timeout
	await _animate_zombie_attack()
	if zombie == null or not is_instance_valid(zombie) or active_combat_player == null:
		_end_combat()
		return
	active_combat_player.take_damage(zombie.attack_damage)
	var thorns = active_combat_player.get_thorns_damage()
	if thorns > 0:
		zombie.take_damage(thorns)
	await _shake_portrait(battle_player_portrait, battle_player_home_position)
	if zombie.is_dead():
		if active_combat_player.can_collect_rewards():
			active_combat_player.add_money(zombie.money_drop)
		zombies.erase(zombie)
		active_combat_zombies.erase(zombie)
		zombie.queue_free()
	if active_combat_player.is_dead():
		_handle_player_defeat(active_combat_player)
		if _show_game_over_if_needed():
			return
		_end_combat()
		_advance_to_next_player_turn()
		return
	zombie_turn_in_progress = false
	_refresh_combat_ui_state()
	_advance_to_next_player_turn()

func _can_current_player_act_in_combat() -> bool:
	return combat_open and active_combat_player != null and _is_current_player_in_active_combat() and not combat_action_locked and not zombie_turn_in_progress

func _end_combat() -> void:
	combat_open = false
	zombie_turn_in_progress = false
	combat_action_locked = false
	if active_combat_player != null and is_instance_valid(active_combat_player):
		active_combat_player.movement_locked = false
	active_combat_player = null
	active_combat_zombies.clear()
	_refresh_combat_ui_state()
	_hide_battle_portraits()
	_refresh_turn_label()
	refresh_turn_order_bar()

func _handle_player_defeat(player) -> void:
	if player.is_zombified:
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
	else:
		player.zombify()

func _show_game_over_if_needed() -> bool:
	if GameData.player_count <= 1 or _count_remaining_players() > 1:
		return false
	combat_open = true
	combat_panel.visible = true
	attack_button.visible = false
	special_button.visible = false
	block_button.visible = false
	run_button.visible = false
	combat_label.text = "Game Over"
	return true

func _on_item_body_entered(body: Node2D, item: Area2D) -> void:
	if combat_open and _is_current_player_in_active_combat():
		return
	var current_player = _get_current_player()
	if current_player == null or body != current_player or current_player.is_zombified or item.collected:
		return
	var data: Dictionary = current_player.collect_item(item.item_id)
	item.collect()
	_show_info("Picked up %s\n%s" % [data.get("display_name", item.item_id), data.get("description", "")])
	_refresh_turn_label()

func _on_zombie_body_entered(body: Node2D, zombie: Area2D) -> void:
	if combat_open:
		return
	var current_player = _get_current_player()
	if current_player == null or body != current_player or current_player.is_zombified:
		return
	active_combat_player = current_player
	active_combat_zombies = [zombie]
	combat_open = true
	current_player.movement_locked = true
	current_player.target_position = current_player.global_position
	_refresh_combat_ui_state()
	refresh_turn_order_bar()

func _cleanup_active_combat_zombies() -> void:
	var cleaned: Array = []
	for zombie in active_combat_zombies:
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			cleaned.append(zombie)
	active_combat_zombies = cleaned

func _respawn_zombies_up_to_cap() -> void:
	_cleanup_zombie_array()
	var to_spawn := zombie_cap - zombies.size()
	for _i in range(max(to_spawn, 0)):
		var spawn_pos = _find_valid_zombie_spawn_position()
		if spawn_pos == null:
			break
		_spawn_single_zombie(spawn_pos)

func _cleanup_zombie_array() -> void:
	var cleaned: Array = []
	for zombie in zombies:
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			cleaned.append(zombie)
	zombies = cleaned

func _spawn_single_zombie(pos: Vector2) -> void:
	var zombie_instance = ZOMBIE_SCENE.instantiate()
	zombies_node.add_child(zombie_instance)
	zombie_instance.global_position = pos
	zombie_instance.setup(zombies.size() + 1, GameData.roll_random_zombie_type())
	zombie_instance.body_entered.connect(_on_zombie_body_entered.bind(zombie_instance))
	zombies.append(zombie_instance)

func _find_valid_zombie_spawn_position():
	for _attempt in range(120):
		var pos := Vector2(rng.randf_range(map_min.x, map_max.x), rng.randf_range(map_min.y, map_max.y))
		if _is_inside_any_player_radius(pos) or _position_overlaps_existing_collision(pos):
			continue
		return pos
	return null

func _is_inside_any_player_radius(pos: Vector2) -> bool:
	for player in players:
		if player != null and is_instance_valid(player) and player.visible and pos.distance_to(player.global_position) <= player.move_radius:
			return true
	return false

func _position_overlaps_existing_collision(pos: Vector2) -> bool:
	for collection in [players, zombies, items, dungeon_entrances]:
		for entry in collection:
			if entry == null or not is_instance_valid(entry):
				continue
			if entry in items and entry.collected:
				continue
			if pos.distance_to(entry.global_position) < ENTITY_OVERLAP_DISTANCE:
				return true
	return false

func _respawn_items() -> void:
	for item in items:
		if item != null and item.collected and not _is_player_on_item_spawn(item.spawn_position):
			item.setup(GameData.roll_random_item_id())
			item.respawn()

func _is_player_on_item_spawn(pos: Vector2) -> bool:
	for player in players:
		if player != null and is_instance_valid(player) and player.visible and player.global_position.distance_to(pos) < ITEM_BLOCK_DISTANCE:
			return true
	return false

func _is_player_defeated(player) -> bool:
	return player == null or not is_instance_valid(player) or not player.visible

func _count_remaining_players() -> int:
	var count := 0
	for player in players:
		if player != null and is_instance_valid(player) and player.visible:
			count += 1
	return count

func _is_current_player_in_active_combat() -> bool:
	return combat_open and active_combat_player != null and _get_current_player() == active_combat_player and not zombie_turn_in_progress

func _refresh_combat_ui_state() -> void:
	var show_ui := combat_open and active_combat_player != null and (_is_current_player_in_active_combat() or zombie_turn_in_progress)
	combat_panel.visible = show_ui
	if show_ui:
		_show_battle_portraits()
		attack_button.visible = not zombie_turn_in_progress
		special_button.visible = not zombie_turn_in_progress
		block_button.visible = not zombie_turn_in_progress
		run_button.visible = not zombie_turn_in_progress
		_update_combat_label()
	else:
		_hide_battle_portraits()

func _update_combat_label() -> void:
	if not combat_open or active_combat_player == null:
		combat_label.text = "No active combat."
		return
	var zombie = _get_active_combat_zombie()
	if zombie == null:
		combat_label.text = "Combat ended."
		return
	var character_data := GameData.get_character_data(active_combat_player.character_id)
	combat_label.text = "%s\nHP %d/%d | AP %d/%d\n%s | HP %d/%d\n\n%s" % [
		character_data.get("display_name", "Player"),
		active_combat_player.hp,
		active_combat_player.max_hp,
		active_combat_player.current_ap,
		active_combat_player.max_ap,
		zombie.display_name,
		zombie.hp,
		zombie.max_hp,
		"Zombie is attacking..." if zombie_turn_in_progress else "%s / %s / %s / Run" % [character_data.get("basic_name", "Attack"), character_data.get("special_name", "Special"), character_data.get("block_name", "Block")]
	]

func _update_camera_follow(delta: float) -> void:
	var current_player = _get_current_player()
	if current_player != null:
		camera.global_position = camera.global_position.lerp(current_player.global_position, delta * camera_follow_speed)

func _get_or_create_active_dungeon(dungeon_id: String):
	if active_dungeon_instances.has(dungeon_id):
		var existing = active_dungeon_instances[dungeon_id]
		if existing != null and is_instance_valid(existing):
			return existing
	var dungeon_instance = DUNGEON_SCENE.instantiate()
	active_dungeon_holder.add_child(dungeon_instance)
	dungeon_instance.position = Vector2(DUNGEON_INSTANCE_SPACING * float(active_dungeon_instances.size() + 1), 0.0)
	if dungeon_instance.has_signal("exit_requested"):
		dungeon_instance.exit_requested.connect(_on_dungeon_exit_requested.bind(dungeon_instance))
	if dungeon_instance.has_signal("enemy_body_entered"):
		dungeon_instance.enemy_body_entered.connect(_on_zombie_body_entered)
	if dungeon_instance.has_signal("item_body_entered"):
		dungeon_instance.item_body_entered.connect(_on_item_body_entered)
	if dungeon_instance.has_method("initialize_dungeon"):
		dungeon_instance.call_deferred("initialize_dungeon", dungeon_id)
	active_dungeon_instances[dungeon_id] = dungeon_instance
	return dungeon_instance

func _enter_dungeon(entrance) -> void:
	var current_player = _get_current_player()
	if current_player == null:
		return
	var dungeon_instance = _get_or_create_active_dungeon(entrance.dungeon_id)
	if dungeon_instance == null:
		return
	await _flash_loading_screen()
	player_return_positions[current_player.player_id] = {"position": entrance.global_position + Vector2(0, 100), "dungeon_id": entrance.dungeon_id}
	current_player.is_in_dungeon = true
	current_player.current_dungeon_id = entrance.dungeon_id
	var entry_position = dungeon_instance.get_entry_position() if dungeon_instance.has_method("get_entry_position") else dungeon_instance.global_position
	current_player.snap_to_position(entry_position)
	current_player.target_position = entry_position
	turn_radius_drawer.target_player = null
	turn_radius_drawer.queue_redraw()
	_refresh_turn_label()

func _exit_dungeon(player, _dungeon_instance) -> void:
	if player == null or not is_instance_valid(player):
		return
	var return_position := Vector2.ZERO
	if player_return_positions.has(player.player_id):
		return_position = player_return_positions[player.player_id].get("position", Vector2.ZERO)
	player.is_in_dungeon = false
	player.current_dungeon_id = ""
	player.snap_to_position(return_position + Vector2(0, 100))
	player.target_position = return_position + Vector2(0, 100)
	if _get_current_player() == player:
		turn_radius_drawer.target_player = player
		turn_radius_drawer.queue_redraw()
	_refresh_turn_label()

func _on_dungeon_exit_requested(body: Node2D, dungeon_instance) -> void:
	var current_player = _get_current_player()
	if current_player != null and body == current_player and current_player.is_in_dungeon:
		_exit_dungeon(current_player, dungeon_instance)

func _on_dungeon_entrance_body_entered(body: Node2D, entrance: Area2D) -> void:
	if combat_open and _is_current_player_in_active_combat():
		return
	var current_player = _get_current_player()
	if current_player == null or body != current_player:
		return
	if GameData.is_dungeon_unlocked(entrance.dungeon_id):
		call_deferred("_enter_dungeon", entrance)
		return
	if current_player.spend_money(entrance.cost):
		GameData.unlock_dungeon(entrance.dungeon_id)
		_show_info("Unlocked %s for %d money" % [entrance.dungeon_id, entrance.cost])
		call_deferred("_enter_dungeon", entrance)
	else:
		_show_info("Not enough money. Need %d" % entrance.cost)

func _respawn_active_dungeon_items() -> void:
	for dungeon in active_dungeon_instances.values():
		if dungeon != null and is_instance_valid(dungeon) and dungeon.has_method("respawn_items"):
			dungeon.respawn_items(players)

func _respawn_active_dungeon_enemies() -> void:
	for dungeon in active_dungeon_instances.values():
		if dungeon != null and is_instance_valid(dungeon) and dungeon.has_method("respawn_enemies_if_needed"):
			dungeon.respawn_enemies_if_needed(players)

func _respawn_active_dungeon_bosses() -> void:
	for dungeon in active_dungeon_instances.values():
		if dungeon != null and is_instance_valid(dungeon) and dungeon.has_method("respawn_boss_if_needed"):
			dungeon.respawn_boss_if_needed()

func _show_info(text: String) -> void:
	info_label.text = text
	info_panel.visible = true

func _ensure_battle_portraits() -> void:
	battle_player_portrait = TextureRect.new()
	battle_player_portrait.name = "BattlePlayerPortrait"
	battle_zombie_portrait = TextureRect.new()
	battle_zombie_portrait.name = "BattleZombiePortrait"
	for portrait in [battle_player_portrait, battle_zombie_portrait]:
		portrait.custom_minimum_size = BATTLE_PORTRAIT_SIZE
		portrait.size = BATTLE_PORTRAIT_SIZE
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.visible = false
		hud.add_child(portrait)

func _ensure_loading_overlay() -> void:
	loading_rect = ColorRect.new()
	loading_rect.color = Color.GRAY
	loading_rect.visible = false
	loading_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	loading_rect.size = Vector2(1280,720)
	hud.add_child(loading_rect)

func _flash_loading_screen() -> void:
	loading_rect.visible = true
	await get_tree().create_timer(1.0).timeout
	loading_rect.visible = false

func _update_battle_portrait_positions() -> void:
	var viewport_size := get_viewport_rect().size
	battle_player_home_position = Vector2(32.0, BATTLE_PORTRAIT_Y)
	battle_zombie_home_position = Vector2(viewport_size.x - BATTLE_PORTRAIT_SIZE.x - 32.0, BATTLE_PORTRAIT_Y)
	if not battle_player_portrait.visible:
		battle_player_portrait.position = battle_player_home_position
	if not battle_zombie_portrait.visible:
		battle_zombie_portrait.position = battle_zombie_home_position

func _show_battle_portraits() -> void:
	if active_combat_player != null:
		battle_player_portrait.texture = _get_player_portrait_texture(active_combat_player.character_id)
	battle_zombie_portrait.texture = _get_zombie_display_texture(_get_active_combat_zombie())
	battle_player_portrait.position = battle_player_home_position
	battle_zombie_portrait.position = battle_zombie_home_position
	battle_player_portrait.visible = true
	battle_zombie_portrait.visible = true

func _hide_battle_portraits() -> void:
	battle_player_portrait.visible = false
	battle_zombie_portrait.visible = false

func _get_player_portrait_texture(character_id: int) -> Texture2D:
	var path := PORTRAIT_PATH % character_id
	return load(path) if ResourceLoader.exists(path) else null

func _get_zombie_display_texture(zombie) -> Texture2D:
	if zombie != null and is_instance_valid(zombie) and zombie.has_node("Sprite2D"):
		return zombie.get_node("Sprite2D").texture
	return null

func _animate_player_attack() -> void:
	_show_battle_portraits()
	var tween := create_tween()
	tween.tween_property(battle_player_portrait, "position", battle_player_home_position + Vector2(BATTLE_ATTACK_MOVE_DISTANCE, 0), 0.12)
	tween.tween_property(battle_player_portrait, "position", battle_player_home_position, 0.12)
	await tween.finished

func _animate_zombie_attack() -> void:
	_show_battle_portraits()
	var tween := create_tween()
	tween.tween_property(battle_zombie_portrait, "position", battle_zombie_home_position + Vector2(-BATTLE_ATTACK_MOVE_DISTANCE, 0), 0.12)
	tween.tween_property(battle_zombie_portrait, "position", battle_zombie_home_position, 0.12)
	await tween.finished

func _shake_portrait(portrait: Control, home_position: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(portrait, "position", home_position + Vector2(12, 0), 0.04)
	tween.tween_property(portrait, "position", home_position + Vector2(-12, 0), 0.04)
	tween.tween_property(portrait, "position", home_position, 0.04)
	await tween.finished
