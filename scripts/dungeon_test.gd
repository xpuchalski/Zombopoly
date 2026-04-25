extends Node2D

signal exit_requested(body: Node2D)
signal enemy_body_entered(body: Node2D, enemy: Area2D)
signal item_body_entered(body: Node2D, item: Area2D)

const ZOMBIE_SCENE := preload("res://scenes/actors/Zombie.tscn")
const ITEM_SCENE := preload("res://scenes/actors/ItemPickup.tscn")
const DUNGEON_MIN := Vector2(-750, -750)
const DUNGEON_MAX := Vector2(750, 750)
const GENERATED_OBSTACLE_COUNT := 5
const GENERATED_ITEM_MARKER_COUNT := 4
const GENERATED_ENEMY_COUNT := 3
const ENTITY_BLOCK_DISTANCE := 110.0
const BOTTOM_CENTER_EXCLUSION := Rect2(Vector2(-320.0, 220.0), Vector2(640.0, 530.0))

var pending_dungeon_id: String = ""
@onready var obstacles_node: StaticBody2D = $Obstacles
@onready var item_spawns_node: Node2D = $ItemSpawns
@onready var items_node: Node2D = $Items
@onready var enemies_node: Node2D = $Enemies
@onready var boss_spawn_node: Node2D = $BossSpawn
@onready var entrance_node: Area2D = $Entrance
@onready var exit_node: Area2D = $Exit

var dungeon_id: String = ""
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var generated: bool = false
var dungeon_items: Array = []
var dungeon_enemies: Array = []

func _ready() -> void:
	print_tree_pretty()
	rng.randomize()
	if exit_node != null and not exit_node.body_entered.is_connected(_on_exit_body_entered):
		exit_node.body_entered.connect(_on_exit_body_entered)
	if pending_dungeon_id != "":
		_initialize_now(pending_dungeon_id)

func initialize_dungeon(new_dungeon_id: String) -> void:
	pending_dungeon_id = new_dungeon_id
	if not is_inside_tree():
		return
	call_deferred("_initialize_now", new_dungeon_id)

func _initialize_now(new_dungeon_id: String) -> void:
	dungeon_id = new_dungeon_id
	if generated:
		return
	_clear_generated_contents()
	_generate_obstacles()
	_generate_item_markers()
	_spawn_items_from_markers()
	respawn_enemies_if_needed()
	respawn_boss_if_needed()
	generated = true

func get_entry_position() -> Vector2:
	if entrance_node != null:
		return entrance_node.global_position + Vector2(0, 500)
	return global_position

func _on_exit_body_entered(body: Node2D) -> void:
	emit_signal("exit_requested", body)

func _clear_generated_contents() -> void:
	for child in obstacles_node.get_children():
		if child.name.begins_with("Generated"):
			child.queue_free()
	for child in item_spawns_node.get_children():
		if child.name.begins_with("Generated"):
			child.queue_free()
	for child in items_node.get_children():
		child.queue_free()
	for child in enemies_node.get_children():
		child.queue_free()
	for child in boss_spawn_node.get_children():
		child.queue_free()
	dungeon_items.clear()
	dungeon_enemies.clear()

func _generate_obstacles() -> void:
	for i in range(GENERATED_OBSTACLE_COUNT):
		var size := Vector2(rng.randf_range(200.0, 360.0), rng.randf_range(200.0, 360.0))
		var local_pos = _find_open_local_position(size)
		if local_pos == null:
			continue

		# Generated obstacles must be physics bodies.
		# CollisionPolygon2D under plain Node2D will not block CharacterBody2D movement.
		var obstacle := StaticBody2D.new()
		obstacle.name = "GeneratedObstacle_%d" % i
		obstacle.position = local_pos
		obstacles_node.add_child(obstacle)

		var half := size * 0.5
		var polygon := PackedVector2Array([
			Vector2(-half.x, -half.y),
			Vector2(half.x, -half.y),
			Vector2(half.x, half.y),
			Vector2(-half.x, half.y)
		])

		var collision := CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		collision.polygon = polygon
		obstacle.add_child(collision)

		var visual := Polygon2D.new()
		visual.name = "Visual"
		visual.polygon = polygon
		visual.color = Color(0.516, 0.441, 0.29, 1.0)
		obstacle.add_child(visual)

func _generate_item_markers() -> void:
	for i in range(GENERATED_ITEM_MARKER_COUNT):
		var marker := Marker2D.new()
		marker.name = "GeneratedItemSpawn_%d" % i
		marker.position = _find_open_local_position(Vector2(90.0, 90.0))
		item_spawns_node.add_child(marker)

func _spawn_items_from_markers() -> void:
	dungeon_items.clear()
	for child in item_spawns_node.get_children():
		if not child is Node2D:
			continue
		var item_instance = ITEM_SCENE.instantiate()
		items_node.add_child(item_instance)
		item_instance.global_position = child.global_position
		item_instance.setup(GameData.roll_random_item_id())
		item_instance.body_entered.connect(_on_item_body_entered.bind(item_instance))
		dungeon_items.append(item_instance)

func respawn_items(active_players: Array = []) -> void:
	for item in dungeon_items:
		if item == null or not is_instance_valid(item) or not item.collected:
			continue
		if _is_player_on_position(item.spawn_position, active_players):
			continue
		item.setup(GameData.roll_random_item_id())
		item.respawn()

func respawn_enemies_if_needed(active_players: Array = []) -> void:
	_cleanup_enemy_arrays()
	var to_spawn := GENERATED_ENEMY_COUNT - dungeon_enemies.size()
	for _i in range(to_spawn):
		var local_pos = _find_open_local_position(Vector2(100.0, 100.0), active_players)
		if local_pos == null:
			break
		var enemy_instance = ZOMBIE_SCENE.instantiate()
		enemies_node.add_child(enemy_instance)
		enemy_instance.position = local_pos
		enemy_instance.setup(dungeon_enemies.size() + 1, GameData.roll_random_zombie_type())
		enemy_instance.body_entered.connect(_on_enemy_body_entered.bind(enemy_instance))
		dungeon_enemies.append(enemy_instance)

func respawn_boss_if_needed() -> void:
	if GameData.is_boss_defeated(dungeon_id):
		return
	for child in boss_spawn_node.get_children():
		if child != null and is_instance_valid(child) and not child.is_dead():
			return
	var boss_instance = ZOMBIE_SCENE.instantiate()
	boss_spawn_node.add_child(boss_instance)
	boss_instance.position = Vector2.ZERO
	boss_instance.setup(999, "boss")
	boss_instance.set_meta("boss_id", dungeon_id)
	boss_instance.set_meta("zombie_type", "boss")
	boss_instance.body_entered.connect(_on_enemy_body_entered.bind(boss_instance))

func _cleanup_enemy_arrays() -> void:
	var cleaned: Array = []
	for enemy in dungeon_enemies:
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dead():
			cleaned.append(enemy)
	dungeon_enemies = cleaned

func _on_enemy_body_entered(body: Node2D, enemy: Area2D) -> void:
	emit_signal("enemy_body_entered", body, enemy)

func _on_item_body_entered(body: Node2D, item: Area2D) -> void:
	emit_signal("item_body_entered", body, item)

func _is_player_on_position(global_pos: Vector2, active_players: Array) -> bool:
	for player in active_players:
		if player != null and is_instance_valid(player) and player.visible and player.global_position.distance_to(global_pos) < 24.0:
			return true
	return false

func _find_open_local_position(size_or_clearance, active_players: Array = []):
	var size := Vector2(100.0, 100.0)
	if size_or_clearance is Vector2:
		size = size_or_clearance
	else:
		size = Vector2(float(size_or_clearance) * 2.0, float(size_or_clearance) * 2.0)
	var half := size * 0.5
	for _attempt in range(120):
		var local_pos := Vector2(rng.randf_range(DUNGEON_MIN.x + half.x, DUNGEON_MAX.x - half.x), rng.randf_range(DUNGEON_MIN.y + half.y, DUNGEON_MAX.y - half.y))
		if BOTTOM_CENTER_EXCLUSION.has_point(local_pos):
			continue
		if local_pos.distance_to(entrance_node.position) < 180.0 or local_pos.distance_to(exit_node.position) < 180.0 or local_pos.distance_to(boss_spawn_node.position) < 200.0:
			continue
		if _overlaps_generated_obstacle(local_pos, half.length()):
			continue
		if _overlaps_existing_entities(local_pos, half.length(), active_players):
			continue
		return local_pos
	return null

func _overlaps_generated_obstacle(local_pos: Vector2, clearance: float) -> bool:
	for child in obstacles_node.get_children():
		if child.name.begins_with("Generated") and child.position.distance_to(local_pos) < clearance + 150.0:
			return true
	return false

func _overlaps_existing_entities(local_pos: Vector2, clearance: float, active_players: Array) -> bool:
	for item in dungeon_items:
		if item != null and is_instance_valid(item) and item.global_position.distance_to(to_global(local_pos)) < clearance + ENTITY_BLOCK_DISTANCE:
			return true
	for enemy in dungeon_enemies:
		if enemy != null and is_instance_valid(enemy) and enemy.position.distance_to(local_pos) < clearance + ENTITY_BLOCK_DISTANCE:
			return true
	for player in active_players:
		if player != null and is_instance_valid(player) and player.visible and player.global_position.distance_to(to_global(local_pos)) < clearance + ENTITY_BLOCK_DISTANCE:
			return true
	return false	
