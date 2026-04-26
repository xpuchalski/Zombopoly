extends Node2D

const PLAYER_SCENE := preload("res://scenes/actors/Player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/actors/Zombie.tscn")
const ITEM_SCENE := preload("res://scenes/actors/ItemPickup.tscn")
const DUNGEON_ENTRANCE_SCENE := preload("res://scenes/actors/DungeonEntrance.tscn")
const WAREHOUSE_ENTRANCE_SCENE := preload("res://scenes/actors/WarehouseEntrance.tscn")
const DUNGEON_SCENE := preload("res://scenes/world/DungeonTest.tscn")
const WAREHOUSE_SCENE := preload("res://scenes/world/Warehouse.tscn")
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
const DUNGEON_INSTANCE_SPACING := 10000.0
const WAREHOUSE_INSTANCE_POSITION := Vector2(-10000.0, 0.0)
const HEALING_AREA_RADIUS := 220.0
const HEALING_AREA_HEAL_PERCENT := 0.35
const ENCOUNTER_JOIN_RADIUS := 200.0
const PVP_OVERLAP_DISTANCE := 72.0
const DEPTH_Z_OFFSET := 1000
const BACKGROUND_Z_INDEX := -1000
const ZOMBIE_SPAWN_COLLISION_RADIUS := 34.0

@onready var players_node: Node2D = $Players
@onready var zombies_node: Node2D = $Zombies
@onready var items_node: Node2D = $Items
@onready var dungeon_entrances_node: Node2D = $DungeonEntrances
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
@onready var warehouse_entrances_node: Node = get_node_or_null("WarehouseEntrances")
@onready var warehouse_spawn_points_node: Node = get_node_or_null("WarehouseSpawnPoints")
@onready var healing_areas_node: Node = get_node_or_null("HealingAreas")
@onready var encounters_node: Node = get_node_or_null("Encounters")
@onready var obstacles_node: Node = get_node_or_null("Obstacles")
@onready var terrain_node: Node2D = get_node_or_null("terrain")
@onready var bushes_node: Node2D = get_node_or_null("bushes")
@onready var fences_node: Node2D = get_node_or_null("fences")

var players: Array = []
var zombies: Array = []
var items: Array = []
var dungeon_entrances: Array = []
var warehouse_entrances: Array = []
var healing_area_positions: Array[Vector2] = []
var active_dungeon_instances: Dictionary = {}
var active_warehouse_instance = null
var player_return_positions: Dictionary = {}
var current_player_index: int = 0
var combat_open: bool = false
var encounters: Array = []
var next_encounter_id: int = 1
var active_encounter_id: int = -1
var active_combat_player = null
var active_combat_target_player = null
var active_combat_zombies: Array = []
var zombie_turn_in_progress: bool = false
var combat_action_locked: bool = false
var battle_player_portrait: TextureRect
var battle_zombie_portrait: TextureRect
var loading_rect: ColorRect
var battle_player_home_position := Vector2.ZERO
var battle_zombie_home_position := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var zombie_cap: int = 15
var map_min: Vector2 = Vector2(-2400, -2400)
var map_max: Vector2 = Vector2(2400, 2400)
var camera_follow_speed: float = 6.0
var camera_zoom_step: float = 0.10
var camera_zoom_min: float = 0.55
var camera_zoom_max: float = 2.0
var camera_zoom_speed: float = 8.0
var target_camera_zoom: Vector2 = Vector2.ONE
var location_transition_in_progress: bool = false
var inventory_button: Button
var inventory_panel: Panel
var inventory_item_list: HBoxContainer
var inventory_name_label: Label
var inventory_description_label: Label
var trade_button: Button
var trade_panel: Panel
var trade_status_label: Label
var trade_player_list: HBoxContainer
var pending_trade_offer: Dictionary = {}

func _ready() -> void:
	rng.randomize()
	if GameData.players.is_empty():
		GameData.build_players()
	_spawn_players()
	_spawn_items_from_points()
	_spawn_dungeon_entrances_from_points()
	_spawn_warehouse_entrances_from_points()
	_cache_healing_areas()
	queue_redraw()	
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
	_ensure_inventory_ui()
	_ensure_trade_ui()
	_update_battle_portrait_positions()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_update_battle_portrait_positions)
	target_camera_zoom = camera.zoom
	_start_current_player_turn()
	refresh_turn_order_bar()

func _process(delta: float) -> void:
	_update_camera_follow(delta)
	_update_camera_zoom(delta)
	_update_depth_sorting()

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
	var next_zoom = clamp(target_camera_zoom.x - delta_amount, camera_zoom_min, camera_zoom_max)
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
	var encounter = _get_encounter_by_id(active_encounter_id)

	if encounter != null:
		for zombie in encounter.get("zombies", []):
			if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
				return zombie

	for zombie in active_combat_zombies:
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			return zombie

	return null

func _get_active_combat_target():
	var zombie = _get_active_combat_zombie()
	if zombie != null:
		return zombie

	return _get_active_player_target()

func _get_active_player_target():
	var encounter = _get_encounter_by_id(active_encounter_id)
	if encounter == null or active_combat_player == null:
		return null
	var participants: Array = encounter.get("players", [])
	for player in participants:
		if player != null and is_instance_valid(player) and player.visible and player != active_combat_player:
			return player
	return null

func _get_encounter_by_id(encounter_id: int):
	for encounter in encounters:
		if int(encounter.get("id", -1)) == encounter_id:
			return encounter

	return null

func _get_encounter_for_player(player):
	if player == null:
		return null
	for encounter in encounters:
		for participant in encounter.get("players", []):
			if participant == player:
				return encounter
	return null

func _get_encounter_for_zombie(zombie):
	if zombie == null:
		return null

	for encounter in encounters:
		for participant in encounter.get("zombies", []):
			if participant == zombie:
				return encounter

	return null

func _create_encounter(initial_players: Array = [], initial_zombies: Array = []) -> Dictionary:
	var encounter := {
		"id": next_encounter_id,
		"players": [],
		"zombies": [],
		"center": Vector2.ZERO,
		"active": true
	}
	next_encounter_id += 1
	encounters.append(encounter)
	for player in initial_players:
		_add_player_to_encounter(encounter, player)
	for zombie in initial_zombies:
		_add_zombie_to_encounter(encounter, zombie)
	_update_encounter_center(encounter)
	return encounter

func _add_player_to_encounter(encounter: Dictionary, player) -> void:
	if encounter == null or player == null or not is_instance_valid(player) or not player.visible:
		return
	var existing = _get_encounter_for_player(player)
	if existing != null and existing != encounter:
		_merge_encounters(existing, encounter)
		encounter = existing
	var participant_list: Array = encounter.get("players", [])
	if not participant_list.has(player):
		participant_list.append(player)
		encounter["players"] = participant_list
	player.movement_locked = true
	player.target_position = player.global_position
	_update_encounter_center(encounter)

func _add_zombie_to_encounter(encounter: Dictionary, zombie) -> void:
	if encounter == null or zombie == null or not is_instance_valid(zombie) or zombie.is_dead():
		return
	var existing = _get_encounter_for_zombie(zombie)
	if existing != null and existing != encounter:
		_merge_encounters(existing, encounter)
		encounter = existing
	var participant_list: Array = encounter.get("zombies", [])
	if not participant_list.has(zombie):
		participant_list.append(zombie)
		encounter["zombies"] = participant_list
	_update_encounter_center(encounter)

func _merge_encounters(primary: Dictionary, secondary: Dictionary) -> Dictionary:
	if primary == null or secondary == null or primary == secondary:
		return primary
	for player in secondary.get("players", []):
		if player != null and is_instance_valid(player) and not primary.get("players", []).has(player):
			primary["players"].append(player)
	for zombie in secondary.get("zombies", []):
		if zombie != null and is_instance_valid(zombie) and not primary.get("zombies", []).has(zombie):
			primary["zombies"].append(zombie)
	encounters.erase(secondary)
	_update_encounter_center(primary)
	return primary

func _update_encounter_center(encounter: Dictionary) -> void:
	if encounter == null:
		return
	var total := Vector2.ZERO
	var count := 0
	for player in encounter.get("players", []):
		if player != null and is_instance_valid(player) and player.visible:
			total += player.global_position
			count += 1
	for zombie in encounter.get("zombies", []):
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			total += zombie.global_position
			count += 1
	encounter["center"] = total / float(count) if count > 0 else Vector2.ZERO

func _cleanup_encounters() -> void:
	var cleaned: Array = []
	for encounter in encounters:
		var clean_players: Array = []
		for player in encounter.get("players", []):
			if player != null and is_instance_valid(player) and player.visible:
				clean_players.append(player)
		var clean_zombies: Array = []
		for zombie in encounter.get("zombies", []):
			if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
				clean_zombies.append(zombie)
		encounter["players"] = clean_players
		encounter["zombies"] = clean_zombies
		_update_encounter_center(encounter)
		if clean_players.size() > 0 and (clean_zombies.size() > 0 or clean_players.size() > 1):
			cleaned.append(encounter)
		else:
			for player in clean_players:
				if player != null and is_instance_valid(player):
					player.movement_locked = false
	encounters = cleaned

func _activate_encounter_for_player(player, encounter: Dictionary) -> void:
	if player == null or encounter == null:
		return

	_update_encounter_center(encounter)

	active_encounter_id = int(encounter.get("id", -1))
	active_combat_player = player
	active_combat_zombies = encounter.get("zombies", []).duplicate()
	active_combat_target_player = _get_first_other_player_in_encounter(encounter, player)
	_register_player_zombie_memory(player, active_combat_zombies)
	_apply_battle_start_effects(player, active_combat_zombies)

	combat_open = true
	zombie_turn_in_progress = false
	combat_action_locked = false

	player.movement_locked = true
	player.target_position = player.global_position

	_refresh_combat_ui_state()
	refresh_turn_order_bar()

func _register_player_zombie_memory(player, zombie_list: Array) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("note_zombie_fought"):
		return
	for zombie in zombie_list:
		if zombie != null and is_instance_valid(zombie):
			player.note_zombie_fought(zombie)

func _apply_battle_start_effects(player, zombie_list: Array) -> void:
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("get_total_modifier"):
		return
	var burn_stacks := int(player.get_total_modifier("burn_battle_start"))
	if burn_stacks <= 0:
		return
	for zombie in zombie_list:
		if zombie != null and is_instance_valid(zombie) and zombie.has_method("apply_burn"):
			zombie.apply_burn(burn_stacks)

func _get_first_other_player_in_encounter(encounter: Dictionary, player):
	for other in encounter.get("players", []):
		if other != null and is_instance_valid(other) and other.visible and other != player:
			return other
	return null

func _start_or_join_encounter_with_zombie(player, zombie) -> void:
	if player == null or zombie == null or not is_instance_valid(zombie):
		return
	var encounter = _get_encounter_for_zombie(zombie)
	var player_encounter = _get_encounter_for_player(player)
	if encounter == null and player_encounter == null:
		encounter = _create_encounter([player], [zombie])
	elif encounter == null:
		encounter = player_encounter
		_add_zombie_to_encounter(encounter, zombie)
	elif player_encounter != null and player_encounter != encounter:
		encounter = _merge_encounters(encounter, player_encounter)
	else:
		_add_player_to_encounter(encounter, player)
	print("Starting zombie encounter: ", encounter)
	_activate_encounter_for_player(player, encounter)

func _start_or_join_player_encounter(attacker, defender) -> void:
	if attacker == null or defender == null or attacker == defender:
		return
	var encounter = _get_encounter_for_player(defender)
	var attacker_encounter = _get_encounter_for_player(attacker)
	if encounter == null and attacker_encounter == null:
		encounter = _create_encounter([attacker, defender], [])
	elif encounter == null:
		encounter = attacker_encounter
		_add_player_to_encounter(encounter, defender)
	elif attacker_encounter != null and attacker_encounter != encounter:
		encounter = _merge_encounters(encounter, attacker_encounter)
	else:
		_add_player_to_encounter(encounter, attacker)
	_activate_encounter_for_player(attacker, encounter)

func _try_current_player_join_or_start_player_encounter(current_player) -> void:
	if current_player == null or _get_encounter_for_player(current_player) != null:
		return
	var nearby_encounter = _get_nearby_encounter_for_player(current_player)
	if nearby_encounter != null:
		_add_player_to_encounter(nearby_encounter, current_player)
		_activate_encounter_for_player(current_player, nearby_encounter)
		return
	var target_player = _get_nearby_attackable_player(current_player)
	if target_player != null:
		_start_or_join_player_encounter(current_player, target_player)

func _get_nearby_encounter_for_player(player):
	for encounter in encounters:
		for other_player in encounter.get("players", []):
			if other_player != null and is_instance_valid(other_player) and other_player != player:
				if player.global_position.distance_to(other_player.global_position) <= PLAYER_TOUCH_DISTANCE:
					return encounter
		for zombie in encounter.get("zombies", []):
			if zombie != null and is_instance_valid(zombie):
				if player.global_position.distance_to(zombie.global_position) <= PLAYER_TOUCH_DISTANCE:
					return encounter
	return null

func _get_nearby_attackable_player(attacker):
	for player in players:
		if player == null or not is_instance_valid(player) or not player.visible or player == attacker:
			continue
		if not _can_players_pvp(attacker, player):
			continue
		if _players_are_overlapping_for_pvp(attacker, player):
			return player
	return null

func _check_pvp_overlap_on_turn_start(active_player) -> void:
	if active_player == null or combat_open:
		return
	var target = _get_overlapping_pvp_target(active_player)
	if target != null:
		_start_or_join_player_encounter(active_player, target)

func _get_overlapping_pvp_target(active_player):
	for other_player in players:
		if other_player == null or not is_instance_valid(other_player):
			continue
		if other_player == active_player or not other_player.visible:
			continue
		if not _can_players_pvp(active_player, other_player):
			continue
		if _players_are_overlapping_for_pvp(active_player, other_player):
			return other_player
	return null


func _can_players_pvp(a, b) -> bool:
	if a == null or b == null:
		return false

	# Humans cannot fight humans. Zombified players can fight humans, and humans can fight zombified players.
	if not a.is_zombified and not b.is_zombified:
		return false

	# Zombified players do not fight each other for now.
	if a.is_zombified and b.is_zombified:
		return false

	return true


func _players_are_overlapping_for_pvp(a, b) -> bool:
	var allowed_distance := PVP_OVERLAP_DISTANCE

	if "base_collision_radius" in a and "base_collision_radius" in b:
		allowed_distance = max(PVP_OVERLAP_DISTANCE, float(a.base_collision_radius) + float(b.base_collision_radius))

	return a.global_position.distance_to(b.global_position) <= allowed_distance

func _pull_nearby_zombies_into_encounters() -> void:
	_cleanup_zombie_array()
	_cleanup_encounters()
	for encounter in encounters:
		_update_encounter_center(encounter)
		var center: Vector2 = encounter.get("center", Vector2.ZERO)
		for zombie in zombies:
			if zombie == null or not is_instance_valid(zombie) or zombie.is_dead():
				continue
			if _get_encounter_for_zombie(zombie) != null:
				continue
			if zombie.global_position.distance_to(center) <= ENCOUNTER_JOIN_RADIUS:
				_add_zombie_to_encounter(encounter, zombie)
	_cleanup_encounters()

func _sync_active_encounter_from_state() -> void:
	var encounter = _get_encounter_by_id(active_encounter_id)
	if encounter == null:
		active_combat_zombies.clear()
		active_combat_target_player = null
		return
	active_combat_zombies = encounter.get("zombies", []).duplicate()
	active_combat_target_player = _get_first_other_player_in_encounter(encounter, active_combat_player)

func _remove_participant_from_encounters(participant) -> void:
	for encounter in encounters:
		if encounter.get("players", []).has(participant):
			encounter["players"].erase(participant)
		if encounter.get("zombies", []).has(participant):
			encounter["zombies"].erase(participant)
	_cleanup_encounters()

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
	_cleanup_encounters()
	for player in players:
		if player != null and is_instance_valid(player):
			player.end_turn()
			if _get_encounter_for_player(player) == null:
				player.movement_locked = false
	var next_player = _find_next_available_player()
	if next_player == null:
		turn_label.text = "No players remaining"
		return
	next_player.start_turn()
	_check_pvp_overlap_on_turn_start(next_player)
	var encounter = _get_encounter_for_player(next_player)
	if encounter != null:
		_activate_encounter_for_player(next_player, encounter)
	else:
		combat_open = false
		active_encounter_id = -1
		active_combat_player = null
		active_combat_target_player = null
		active_combat_zombies.clear()
		_refresh_combat_ui_state()
	queue_redraw()
	_refresh_turn_label()
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
	queue_redraw()
	var current_player = _get_current_player()
	if current_player == null:
		turn_label.text = "Turn %d | No active player" % GameData.global_turn
		return
	var character_data := GameData.get_character_data(current_player.character_id)
	var location_text := _get_player_location_text(current_player)
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
	_cleanup_encounters()
	var shown_zombie_ids: Array = []
	for i in range(players.size()):
		var player = players[i]
		if player == null or not is_instance_valid(player) or not player.visible:
			continue
		var encounter = _get_encounter_for_player(player)
		var in_combat := encounter != null
		var is_current = i == current_player_index and player == _get_current_player()
		_add_turn_bar_entry(_get_player_portrait_texture(player.character_id), is_current, player.is_zombified, in_combat)
		if in_combat:
			for zombie in encounter.get("zombies", []):
				if zombie == null or not is_instance_valid(zombie):
					continue
				if shown_zombie_ids.has(zombie.get_instance_id()):
					continue
				shown_zombie_ids.append(zombie.get_instance_id())
				_add_turn_bar_entry(_get_zombie_display_texture(zombie), false, false, true)

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
		_apply_healing_area_if_needed(current_player)
		current_player.end_turn()
	_advance_to_next_player_turn()

func _advance_to_next_player_turn() -> void:
	_cleanup_encounters()
	current_player_index += 1
	if current_player_index >= players.size():
		current_player_index = 0
		_process_global_turn_end()
	_start_current_player_turn()

func _process_global_turn_end() -> void:
	GameData.global_turn += 1
	_pull_nearby_zombies_into_encounters()
	if GameData.global_turn % ZOMBIE_RESPAWN_INTERVAL == 0:
		_respawn_zombies_up_to_cap()
		_respawn_active_dungeon_enemies()
	if GameData.global_turn % ITEM_RESPAWN_INTERVAL == 0:
		_respawn_items()
		_respawn_active_dungeon_items()
	if GameData.global_turn % BOSS_RESPAWN_INTERVAL == 0:
		_respawn_active_dungeon_bosses()
	_refresh_turn_label()
	refresh_turn_order_bar()

func _on_attack_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	var target = _get_active_combat_target()
	if target == null:
		_end_combat()
		return
	combat_action_locked = true
	await _animate_player_attack()
	var result: Dictionary = active_combat_player.perform_basic_attack(target)
	combat_label.text = result.get("text", "Attack")
	await _shake_portrait(battle_zombie_portrait, battle_zombie_home_position)
	await _resolve_post_attack(target)

func _on_special_pressed() -> void:
	if not _can_current_player_act_in_combat():
		return
	var target = _get_active_combat_target()
	if target == null:
		_end_combat()
		return
	combat_action_locked = true
	await _animate_player_attack()
	var result: Dictionary = active_combat_player.perform_special_attack(target)
	combat_label.text = result.get("text", "Special")
	if not result.get("ok", true):
		combat_action_locked = false
		_refresh_combat_ui_state()
		return
	await _shake_portrait(battle_zombie_portrait, battle_zombie_home_position)
	await _resolve_post_attack(target)

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
	var push_dir := Vector2.DOWN
	var target = _get_active_combat_target()
	if target != null and is_instance_valid(target):
		push_dir = (active_combat_player.global_position - target.global_position).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.DOWN
	active_combat_player.snap_to_position(active_combat_player.global_position + push_dir * 100.0)
	var leaving_player = active_combat_player
	_remove_participant_from_encounters(leaving_player)
	leaving_player.end_turn()
	_end_combat()
	_advance_to_next_player_turn()

func _resolve_post_attack(target) -> void:
	if target == null or not is_instance_valid(target):
		_end_combat()
		_advance_to_next_player_turn()
		return
	if target.is_dead():
		if target is Area2D:
			_register_boss_defeated_if_needed(target)
			if active_combat_player.can_collect_rewards():
				active_combat_player.add_money(target.money_drop)
			zombies.erase(target)
			active_combat_zombies.erase(target)
			_remove_participant_from_encounters(target)
			target.queue_free()
		else:
			_handle_player_defeat(target)
			_remove_participant_from_encounters(target)
			if _show_game_over_if_needed():
				return
		_cleanup_encounters()
		combat_action_locked = false
		_end_combat()
		_refresh_turn_label()
		_advance_to_next_player_turn()
		return
	if target is Area2D:
		active_combat_player.end_turn()
		combat_action_locked = false
		await _take_zombie_combat_turn()
	else:
		active_combat_player.end_turn()
		combat_action_locked = false
		_end_combat()
		_advance_to_next_player_turn()

func _take_zombie_combat_turn() -> void:
	_sync_active_encounter_from_state()
	var zombie = _get_active_combat_zombie()
	if not combat_open or active_combat_player == null or zombie == null:
		_end_combat()
		_advance_to_next_player_turn()
		return
	zombie_turn_in_progress = true
	_refresh_combat_ui_state()
	refresh_turn_order_bar()
	await get_tree().create_timer(1.0).timeout
	await _animate_zombie_attack()
	if zombie == null or not is_instance_valid(zombie) or active_combat_player == null:
		_end_combat()
		_advance_to_next_player_turn()
		return
	active_combat_player.take_damage(zombie.attack_damage)
	var thorns = active_combat_player.get_thorns_damage()
	if thorns > 0:
		zombie.take_damage(thorns)
	if zombie.has_method("process_end_turn_effects"):
		zombie.process_end_turn_effects()
	await _shake_portrait(battle_player_portrait, battle_player_home_position)
	if zombie.is_dead():
		_register_boss_defeated_if_needed(zombie)
		if active_combat_player.can_collect_rewards():
			active_combat_player.add_money(zombie.money_drop)
		zombies.erase(zombie)
		active_combat_zombies.erase(zombie)
		_remove_participant_from_encounters(zombie)
		zombie.queue_free()
	if active_combat_player.is_dead():
		_handle_player_defeat(active_combat_player)
		_remove_participant_from_encounters(active_combat_player)
		if _show_game_over_if_needed():
			return
		_end_combat()
		_advance_to_next_player_turn()
		return
	zombie_turn_in_progress = false
	_refresh_combat_ui_state()
	_end_combat()
	_advance_to_next_player_turn()

func _can_current_player_act_in_combat() -> bool:
	return combat_open and active_combat_player != null and _is_current_player_in_active_combat() and not combat_action_locked and not zombie_turn_in_progress

func _end_combat() -> void:
	combat_open = false
	zombie_turn_in_progress = false
	combat_action_locked = false
	if active_combat_player != null and is_instance_valid(active_combat_player):
		if _get_encounter_for_player(active_combat_player) == null:
			active_combat_player.movement_locked = false
	active_encounter_id = -1
	active_combat_player = null
	active_combat_target_player = null
	active_combat_zombies.clear()
	_cleanup_encounters()
	_refresh_combat_ui_state()
	_hide_battle_portraits()
	_refresh_turn_label()
	refresh_turn_order_bar()

func _handle_player_defeat(player) -> void:
	if player.is_zombified:
		player.visible = false
		player.set_process(false)
		player.set_physics_process(false)
		_remove_participant_from_encounters(player)
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
	var current_player = _get_current_player()
	if current_player == null or body != current_player or current_player.is_zombified:
		return
	_start_or_join_encounter_with_zombie(current_player, zombie)

func _cleanup_active_combat_zombies() -> void:
	var cleaned: Array = []

	for zombie in active_combat_zombies:
		if zombie != null and is_instance_valid(zombie) and not zombie.is_dead():
			cleaned.append(zombie)

	active_combat_zombies = cleaned

	var encounter: Variant = _get_encounter_by_id(active_encounter_id)
	if encounter is Dictionary:
		encounter["zombies"] = cleaned.duplicate()
		_update_encounter_center(encounter)

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
	for collection in [players, zombies, items, dungeon_entrances, warehouse_entrances]:
		for entry in collection:
			if entry == null or not is_instance_valid(entry):
				continue
			if entry in items and entry.collected:
				continue
			if pos.distance_to(entry.global_position) < ENTITY_OVERLAP_DISTANCE:
				return true

	if _position_overlaps_obstacle_collision(pos, ZOMBIE_SPAWN_COLLISION_RADIUS):
		return true

	return false


func _position_overlaps_obstacle_collision(pos: Vector2, radius: float) -> bool:
	if obstacles_node == null:
		return false

	return _node_tree_collision_contains_point(obstacles_node, pos, radius)


func _node_tree_collision_contains_point(node: Node, pos: Vector2, radius: float) -> bool:
	for child in node.get_children():
		if child is CollisionShape2D:
			if _collision_shape_contains_world_point(child, pos, radius):
				return true
		elif child is CollisionPolygon2D:
			if _collision_polygon_contains_world_point(child, pos):
				return true

		if _node_tree_collision_contains_point(child, pos, radius):
			return true

	return false


func _collision_shape_contains_world_point(collision: CollisionShape2D, pos: Vector2, radius: float) -> bool:
	if collision == null or collision.disabled or collision.shape == null:
		return false

	var local_pos := collision.to_local(pos)

	if collision.shape is CircleShape2D:
		var shape := collision.shape as CircleShape2D
		return local_pos.length() <= shape.radius + radius

	if collision.shape is RectangleShape2D:
		var shape := collision.shape as RectangleShape2D
		var half := shape.size * 0.5
		return abs(local_pos.x) <= half.x + radius and abs(local_pos.y) <= half.y + radius

	if collision.shape is CapsuleShape2D:
		var shape := collision.shape as CapsuleShape2D
		var half_height = max((shape.height * 0.5) - shape.radius, 0.0)
		var clamped_y = clamp(local_pos.y, -half_height, half_height)
		var closest := Vector2(0.0, clamped_y)
		return local_pos.distance_to(closest) <= shape.radius + radius

	return false


func _collision_polygon_contains_world_point(collision: CollisionPolygon2D, pos: Vector2) -> bool:
	if collision == null or collision.disabled:
		return false

	var local_pos := collision.to_local(pos)
	return Geometry2D.is_point_in_polygon(local_pos, collision.polygon)

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
		_sync_active_encounter_from_state()
		_show_battle_portraits()
		attack_button.visible = not zombie_turn_in_progress
		special_button.visible = not zombie_turn_in_progress
		special_button.disabled = active_combat_player == null or not active_combat_player.can_use_special()
		block_button.visible = not zombie_turn_in_progress
		run_button.visible = not zombie_turn_in_progress
		_update_combat_label()
	else:
		_hide_battle_portraits()

func _update_combat_label() -> void:
	if not combat_open or active_combat_player == null:
		combat_label.text = "No active combat."
		return
	var target = _get_active_combat_target()
	if target == null:
		combat_label.text = "Combat ended."
		return
	var character_data := GameData.get_character_data(active_combat_player.character_id)
	var target_name := "Enemy"
	var target_hp := 0
	var target_max_hp := 0
	if target is Area2D:
		target_name = target.display_name
		target_hp = target.hp
		target_max_hp = target.max_hp
	else:
		var target_character_data := GameData.get_character_data(target.character_id)
		target_name = "P%d %s" % [target.player_id, target_character_data.get("display_name", "Player")]
		target_hp = target.hp
		target_max_hp = target.max_hp
	combat_label.text = "%s\nHP %d/%d | AP %d/%d\n%s | HP %d/%d\n\n%s" % [
		character_data.get("display_name", "Player"),
		active_combat_player.hp,
		active_combat_player.max_hp,
		active_combat_player.current_ap,
		active_combat_player.max_ap,
		target_name,
		target_hp,
		target_max_hp,
		"Enemy is attacking..." if zombie_turn_in_progress else "%s / %s / %s / Run" % [character_data.get("basic_name", "Attack"), character_data.get("special_name", "Special"), character_data.get("block_name", "Block")]
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
	queue_redraw()
	_refresh_turn_label()
	_end_turn_after_location_change(current_player)

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
		queue_redraw()
	_refresh_turn_label()
	_end_turn_after_location_change(player)

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


func _get_player_location_text(player) -> String:
	if player == null:
		return "Unknown"
	if player.is_in_dungeon and player.current_dungeon_id == "warehouse":
		return "Warehouse"
	if player.is_in_dungeon:
		return "Dungeon"
	return "Overworld"

func _cache_healing_areas() -> void:
	healing_area_positions.clear()
	if healing_areas_node == null:
		return
	for child in healing_areas_node.get_children():
		if child is Node2D:
			healing_area_positions.append(child.global_position)

func _apply_healing_area_if_needed(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.is_zombified or player.is_in_dungeon:
		return
	for pos in healing_area_positions:
		if player.global_position.distance_to(pos) <= HEALING_AREA_RADIUS:
			var heal_amount = max(1, int(ceil(float(player.max_hp) * HEALING_AREA_HEAL_PERCENT)))
			player.heal(heal_amount)
			_show_info("Healing area restored %d HP." % heal_amount)
			_refresh_turn_label()
			return

func _draw() -> void:
	var current_player = _get_current_player()
	if current_player != null and current_player.is_active and not current_player.is_in_dungeon and _get_encounter_for_player(current_player) == null:
		draw_arc(current_player.turn_origin, current_player.move_radius, 0.0, TAU, 96, Color(0.2, 0.8, 1.0, 0.95), 3.0)
		draw_circle(current_player.turn_origin, current_player.move_radius, Color(0.2, 0.8, 1.0, 0.08))

	if healing_areas_node == null:
		return

	for child in healing_areas_node.get_children():
		if child is Node2D:
			draw_circle(child.global_position, HEALING_AREA_RADIUS, Color(0.846, 0.296, 0.594, 0.18))
			draw_arc(child.global_position, HEALING_AREA_RADIUS, 0.0, TAU, 64, Color(0.908, 0.378, 0.659, 0.639), 2.0)

func _spawn_warehouse_entrances_from_points() -> void:
	if warehouse_entrances_node == null:
		return

	if warehouse_spawn_points_node != null:
		var index := 1
		for child in warehouse_spawn_points_node.get_children():
			if not child is Node2D:
				continue
			var entrance_instance = WAREHOUSE_ENTRANCE_SCENE.instantiate()
			warehouse_entrances_node.add_child(entrance_instance)
			entrance_instance.global_position = child.global_position
			if entrance_instance.has_method("setup"):
				entrance_instance.setup("warehouse_%d" % index)
			index += 1

	for child in warehouse_entrances_node.get_children():
		if not child is Area2D:
			continue
		if child.body_entered.is_connected(_on_warehouse_entrance_body_entered):
			continue
		child.body_entered.connect(_on_warehouse_entrance_body_entered.bind(child))
		warehouse_entrances.append(child)

func _get_or_create_warehouse():
	if active_warehouse_instance != null and is_instance_valid(active_warehouse_instance):
		return active_warehouse_instance
	var warehouse_instance = WAREHOUSE_SCENE.instantiate()
	active_dungeon_holder.add_child(warehouse_instance)
	warehouse_instance.position = WAREHOUSE_INSTANCE_POSITION
	if warehouse_instance.has_signal("exit_requested"):
		warehouse_instance.exit_requested.connect(_on_warehouse_exit_requested.bind(warehouse_instance))
	if warehouse_instance.has_method("initialize_warehouse"):
		warehouse_instance.call_deferred("initialize_warehouse")
	active_warehouse_instance = warehouse_instance
	return active_warehouse_instance

func _on_warehouse_entrance_body_entered(body: Node2D, entrance: Area2D) -> void:
	if combat_open and _is_current_player_in_active_combat():
		return
	var current_player = _get_current_player()
	if current_player == null or body != current_player:
		return
	call_deferred("_enter_warehouse", entrance)

func _enter_warehouse(entrance) -> void:
	if location_transition_in_progress:
		return
	var current_player = _get_current_player()
	if current_player == null:
		return
	location_transition_in_progress = true
	var warehouse_instance = _get_or_create_warehouse()
	await _flash_loading_screen()
	player_return_positions[current_player.player_id] = {"position": entrance.global_position + Vector2(0, 100), "dungeon_id": "warehouse"}
	current_player.is_in_dungeon = true
	current_player.current_dungeon_id = "warehouse"
	var entry_position = warehouse_instance.get_entry_position() if warehouse_instance.has_method("get_entry_position") else warehouse_instance.global_position
	current_player.snap_to_position(entry_position)
	current_player.target_position = entry_position
	queue_redraw()
	_refresh_turn_label()
	location_transition_in_progress = false
	if _show_cooperative_win_if_needed():
		return
	_end_turn_after_location_change(current_player)

func _exit_warehouse(player, _warehouse_instance) -> void:
	if location_transition_in_progress:
		return
	if player == null or not is_instance_valid(player):
		return
	location_transition_in_progress = true
	var return_position := Vector2.ZERO
	if player_return_positions.has(player.player_id):
		return_position = player_return_positions[player.player_id].get("position", Vector2.ZERO)
	await _flash_loading_screen()
	player.is_in_dungeon = false
	player.current_dungeon_id = ""
	player.snap_to_position(return_position + Vector2(0, 100))
	player.target_position = return_position + Vector2(0, 100)
	if _get_current_player() == player:
		queue_redraw()
	_refresh_turn_label()
	location_transition_in_progress = false
	_end_turn_after_location_change(player)

func _on_warehouse_exit_requested(body: Node2D, warehouse_instance) -> void:
	var current_player = _get_current_player()
	if current_player != null and body == current_player and current_player.is_in_dungeon and current_player.current_dungeon_id == "warehouse":
		_exit_warehouse(current_player, warehouse_instance)

func _end_turn_after_location_change(player) -> void:
	if player == null or not is_instance_valid(player):
		return
	if combat_open:
		return
	if _get_current_player() != player:
		return
	player.end_turn()
	call_deferred("_advance_to_next_player_turn")

func _register_boss_defeated_if_needed(zombie) -> void:
	if zombie == null or not is_instance_valid(zombie):
		return
	var zombie_type := str(zombie.get("zombie_type"))
	if zombie_type != "boss" and zombie.has_meta("zombie_type"):
		zombie_type = str(zombie.get_meta("zombie_type"))
	if zombie_type != "boss" and str(zombie.get("display_name")).to_lower() == "boss":
		zombie_type = "boss"
	if zombie_type != "boss":
		return

	var boss_id := ""
	if zombie.has_meta("boss_id"):
		boss_id = str(zombie.get_meta("boss_id"))
	elif active_combat_player != null and is_instance_valid(active_combat_player):
		boss_id = active_combat_player.current_dungeon_id
	if boss_id == "":
		boss_id = "boss_%d" % (GameData.get_defeated_boss_count() + 1)

	var was_new = GameData.register_boss_defeated(boss_id)
	if was_new and GameData.are_all_bosses_defeated() and not GameData.warehouse_win_prompt_shown:
		GameData.warehouse_win_prompt_shown = true
		_show_info("All bosses defeated!\nGo to the warehouse to win.")

func _show_cooperative_win_if_needed() -> bool:
	if not GameData.are_all_bosses_defeated():
		return false
	for player in players:
		if player == null or not is_instance_valid(player) or not player.visible:
			continue
		if not (player.is_in_dungeon and player.current_dungeon_id == "warehouse"):
			return false
	GameData.cooperative_win_achieved = true
	combat_open = true
	combat_panel.visible = true
	attack_button.visible = false
	special_button.visible = false
	block_button.visible = false
	run_button.visible = false
	combat_label.text = "Cooperative Victory!\nAll bosses were defeated and everyone returned to the warehouse."
	_show_info("Cooperative Victory!\nAll bosses were defeated and everyone returned to the warehouse.")
	return true


func _ensure_inventory_ui() -> void:
	inventory_button = Button.new()
	inventory_button.name = "InventoryButton"
	inventory_button.text = "Inventory"
	inventory_button.position = Vector2(16, 610)
	inventory_button.size = Vector2(130, 40)
	hud.add_child(inventory_button)
	inventory_button.pressed.connect(_toggle_inventory_panel)

	inventory_panel = Panel.new()
	inventory_panel.name = "InventoryPanel"
	inventory_panel.visible = false
	inventory_panel.position = Vector2(160, 430)
	inventory_panel.size = Vector2(720, 240)
	hud.add_child(inventory_panel)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	inventory_panel.add_child(root)

	var title := Label.new()
	title.text = "Inventory"
	root.add_child(title)

	var inventory_scroll := ScrollContainer.new()
	inventory_scroll.name = "InventoryScroll"
	inventory_scroll.custom_minimum_size = Vector2(680, 92)
	root.add_child(inventory_scroll)

	inventory_item_list = HBoxContainer.new()
	inventory_item_list.name = "ItemList"
	inventory_item_list.custom_minimum_size = Vector2(680, 72)
	inventory_scroll.add_child(inventory_item_list)

	inventory_name_label = Label.new()
	inventory_name_label.text = "Select an item."
	root.add_child(inventory_name_label)

	inventory_description_label = Label.new()
	inventory_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_description_label.text = ""
	root.add_child(inventory_description_label)

	var close_button := Button.new()
	close_button.text = "Close"
	root.add_child(close_button)
	close_button.pressed.connect(func(): inventory_panel.visible = false)

func _toggle_inventory_panel() -> void:
	inventory_panel.visible = not inventory_panel.visible
	if inventory_panel.visible:
		_refresh_inventory_panel()

func _refresh_inventory_panel() -> void:
	for child in inventory_item_list.get_children():
		child.queue_free()
	var current_player = _get_current_player()
	if current_player == null:
		inventory_name_label.text = "No active player."
		inventory_description_label.text = ""
		return
	if current_player.collected_items.is_empty():
		inventory_name_label.text = "No items."
		inventory_description_label.text = ""
		return
	inventory_name_label.text = "Select an item."
	inventory_description_label.text = ""
	for item_id in current_player.collected_items:
		var data := GameData.get_item_data(item_id)
		var button := Button.new()
		button.text = "%s" % data.get("display_name", item_id)
		button.custom_minimum_size = Vector2(120, 36)
		inventory_item_list.add_child(button)
		button.pressed.connect(_show_inventory_item.bind(item_id))

func _show_inventory_item(item_id: String) -> void:
	var data := GameData.get_item_data(item_id)
	inventory_name_label.text = "%s [%s]" % [data.get("display_name", item_id), str(data.get("rarity", "common")).capitalize()]
	inventory_description_label.text = str(data.get("description", "No description."))

func _ensure_trade_ui() -> void:
	trade_button = Button.new()
	trade_button.name = "TradeButton"
	trade_button.text = "Trade"
	trade_button.position = Vector2(16, 656)
	trade_button.size = Vector2(130, 40)
	hud.add_child(trade_button)
	trade_button.pressed.connect(_toggle_trade_panel)

	trade_panel = Panel.new()
	trade_panel.name = "TradePanel"
	trade_panel.visible = false
	trade_panel.position = Vector2(900, 380)
	trade_panel.size = Vector2(360, 290)
	hud.add_child(trade_panel)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 12
	root.offset_top = 12
	root.offset_right = -12
	root.offset_bottom = -12
	trade_panel.add_child(root)

	trade_status_label = Label.new()
	trade_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	trade_status_label.text = "Warehouse trading only."
	root.add_child(trade_status_label)

	trade_player_list = HBoxContainer.new()
	root.add_child(trade_player_list)

	var accept_button := Button.new()
	accept_button.text = "Accept Pending Offer"
	root.add_child(accept_button)
	accept_button.pressed.connect(_accept_pending_trade)

	var decline_button := Button.new()
	decline_button.text = "Decline Pending Offer"
	root.add_child(decline_button)
	decline_button.pressed.connect(_decline_pending_trade)

	var close_button := Button.new()
	close_button.text = "Close"
	root.add_child(close_button)
	close_button.pressed.connect(func(): trade_panel.visible = false)

func _toggle_trade_panel() -> void:
	trade_panel.visible = not trade_panel.visible
	if trade_panel.visible:
		_refresh_trade_panel()

func _refresh_trade_panel() -> void:
	for child in trade_player_list.get_children():
		child.queue_free()
	var current_player = _get_current_player()
	if current_player == null:
		trade_status_label.text = "No active player."
		return
	if not _is_player_in_warehouse(current_player):
		trade_status_label.text = "You must be in the warehouse to trade."
	else:
		trade_status_label.text = "Select a warehouse player to send a trade request."
	if not pending_trade_offer.is_empty() and int(pending_trade_offer.get("to", -1)) == current_player.player_id:
		trade_status_label.text = "Trade request from Player %d." % int(pending_trade_offer.get("from", -1))
	for player in players:
		if player == null or not is_instance_valid(player) or not player.visible or player == current_player:
			continue
		var button := Button.new()
		button.size = Vector2(58, 58)
		button.icon = _get_player_portrait_texture(player.character_id)
		button.text = "P%d" % player.player_id
		button.disabled = not (_is_player_in_warehouse(current_player) and _is_player_in_warehouse(player))
		trade_player_list.add_child(button)
		button.pressed.connect(_send_trade_offer.bind(player))

func _send_trade_offer(target_player) -> void:
	var current_player = _get_current_player()
	if current_player == null or target_player == null:
		return
	if not _is_player_in_warehouse(current_player) or not _is_player_in_warehouse(target_player):
		trade_status_label.text = "Both players must be in the warehouse."
		return
	pending_trade_offer = {"from": current_player.player_id, "to": target_player.player_id, "accepted": false}
	trade_status_label.text = "Trade offer sent to Player %d. They can accept on their turn." % target_player.player_id

func _accept_pending_trade() -> void:
	var current_player = _get_current_player()
	if current_player == null or pending_trade_offer.is_empty():
		return
	if int(pending_trade_offer.get("to", -1)) != current_player.player_id:
		trade_status_label.text = "No offer for this player."
		return
	pending_trade_offer["accepted"] = true
	trade_status_label.text = "Trade accepted. Full item/money proposal UI is ready for the next pass."

func _decline_pending_trade() -> void:
	var current_player = _get_current_player()
	if current_player == null or pending_trade_offer.is_empty():
		return
	if int(pending_trade_offer.get("to", -1)) != current_player.player_id:
		trade_status_label.text = "No offer for this player."
		return
	pending_trade_offer.clear()
	trade_status_label.text = "Trade declined."

func _is_player_in_warehouse(player) -> bool:
	return player != null and is_instance_valid(player) and player.is_in_dungeon and player.current_dungeon_id == "warehouse"

func _update_depth_sorting() -> void:
	_force_background_layers_back()

	for collection in [players, zombies, items, dungeon_entrances, warehouse_entrances]:
		for node in collection:
			if node != null and is_instance_valid(node) and node is Node2D:
				node.z_index = _depth_z_for_node(node)

	if obstacles_node != null:
		_apply_depth_sort_to_children(obstacles_node)

	if active_dungeon_holder != null:
		active_dungeon_holder.z_index = DEPTH_Z_OFFSET


func _force_background_layers_back() -> void:
	for node in [terrain_node, bushes_node, fences_node]:
		if node != null and is_instance_valid(node):
			node.z_as_relative = false
			node.z_index = BACKGROUND_Z_INDEX


func _depth_z_for_node(node: Node2D) -> int:
	var raw_z := int(node.global_position.y * 0.25) + 1000
	return clamp(raw_z, -4096, 4096)


func _apply_depth_sort_to_children(parent: Node) -> void:
	for child in parent.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			continue

		if child is Node2D:
			child.z_index = _depth_z_for_node(child)

		_apply_depth_sort_to_children(child)

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
	var target = _get_active_combat_target()
	if target != null and is_instance_valid(target):
		if target is Area2D:
			battle_zombie_portrait.texture = _get_zombie_display_texture(target)
		else:
			battle_zombie_portrait.texture = _get_player_portrait_texture(target.character_id)
	battle_player_portrait.position = battle_player_home_position
	battle_zombie_portrait.position = battle_zombie_home_position
	battle_player_portrait.visible = true
	battle_zombie_portrait.visible = true

func _hide_battle_portraits() -> void:
	battle_player_portrait.visible = false
	battle_zombie_portrait.visible = false

func _get_player_portrait_texture(character_id: int, hurt: bool = false) -> Texture2D:
	var path := "res://assets/characters/portraits/hurt/%d.png" % character_id if hurt else PORTRAIT_PATH % character_id
	return load(path) if ResourceLoader.exists(path) else null

func _get_zombie_display_texture(zombie) -> Texture2D:
	if zombie == null or not is_instance_valid(zombie):
		return null

	if zombie.has_method("get_portrait_texture"):
		return zombie.get_portrait_texture()

	if zombie.has_node("Sprite2D"):
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
	var old_texture = null
	if portrait == battle_player_portrait and active_combat_player != null:
		old_texture = battle_player_portrait.texture
		var hurt_texture := _get_player_portrait_texture(active_combat_player.character_id, true)
		if hurt_texture != null:
			battle_player_portrait.texture = hurt_texture
	var tween := create_tween()
	tween.tween_property(portrait, "position", home_position + Vector2(12, 0), 0.04)
	tween.tween_property(portrait, "position", home_position + Vector2(-12, 0), 0.04)
	tween.tween_property(portrait, "position", home_position, 0.04)
	await tween.finished
	if old_texture != null and portrait == battle_player_portrait:
		battle_player_portrait.texture = old_texture
