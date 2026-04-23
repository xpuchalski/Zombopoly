extends CharacterBody2D

const CHARACTER_TEXTURES := {
	1: preload("res://assets/characters/1.png"),
	2: preload("res://assets/characters/2.png"),
	3: preload("res://assets/characters/3.png"),
	4: preload("res://assets/characters/4.png"),
	5: preload("res://assets/characters/5.png"),
	6: preload("res://assets/characters/6.png"),
	7: preload("res://assets/characters/7.png"),
	8: preload("res://assets/characters/8.png"),
	9: preload("res://assets/characters/9.png")
}

var player_id: int = 0
var character_id: int = 0
var move_radius: float = 300.0
var hp: int = 10
var max_hp: int = 10
var money: int = 0
var base_damage: int = 5
var max_ap: int = 20
var current_ap: int = 20
var collected_items: Array = []
var block_power: int = 0
var special_cost: int = 10

var is_active: bool = false
var is_zombified: bool = false
var movement_locked: bool = false
var is_in_dungeon: bool = false
var current_dungeon_id: String = ""

var zombie_move_radius_bonus: float = 100.0
var base_collision_radius: float = 30.0
var turn_origin: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 275.0
var visual_time: float = 0.0
var facing_right: bool = true
var idle_pulse_speed: float = 2.0
var idle_pulse_amount: float = 0.03
var move_tilt_speed: float = TAU * 1.5
var move_tilt_amount_degrees: float = 15.0
var base_sprite_scale: Vector2 = Vector2(0.25, 0.25)
var return_speed: float = 8.0
var stretch_return_speed: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	target_position = global_position
	var shape := collision_shape.shape as CircleShape2D
	if shape != null:
		base_collision_radius = shape.radius
	_update_visual()
	_reset_visual_pose()

func setup_from_data(data: Dictionary) -> void:
	player_id = data["player_id"]
	character_id = data["character_id"]
	move_radius = float(data["move_radius"])
	hp = int(data["hp"])
	max_hp = int(data["max_hp"])
	money = int(data["money"])
	is_zombified = bool(data.get("is_zombified", false))
	base_damage = int(data.get("base_damage", GameData.get_character_data(character_id).get("base_attack", 5)))
	max_ap = int(data.get("max_ap", 20))
	current_ap = int(data.get("current_ap", max_ap))
	collected_items = data.get("collected_items", []).duplicate(true)
	special_cost = int(GameData.get_character_data(character_id).get("special_cost", 10))
	_apply_character_sprite()
	_recalculate_from_items()
	_update_visual()

func _apply_character_sprite() -> void:
	if CHARACTER_TEXTURES.has(character_id):
		sprite.texture = CHARACTER_TEXTURES[character_id]
	sprite.scale = base_sprite_scale

func _save_to_gamedata() -> void:
	for player_data in GameData.players:
		if player_data["player_id"] != player_id:
			continue
		player_data["character_id"] = character_id
		player_data["move_radius"] = move_radius
		player_data["hp"] = hp
		player_data["max_hp"] = max_hp
		player_data["money"] = money
		player_data["is_zombified"] = is_zombified
		player_data["base_damage"] = base_damage
		player_data["max_ap"] = max_ap
		player_data["current_ap"] = current_ap
		player_data["collected_items"] = collected_items.duplicate(true)
		return

func snap_to_position(pos: Vector2) -> void:
	global_position = pos
	target_position = pos
	_reset_visual_pose()

func start_turn() -> void:
	is_active = true
	turn_origin = global_position
	target_position = global_position
	if current_ap < max_ap:
		current_ap += 1
	block_power = 0
	_reset_visual_pose()
	_update_visual()
	_save_to_gamedata()

func end_turn() -> void:
	is_active = false
	_update_visual()

func try_move_to(world_pos: Vector2) -> void:
	if not is_active or movement_locked:
		return
	if is_in_dungeon:
		target_position = world_pos
		return
	var usable_radius = max(move_radius - base_collision_radius, 0.0)
	var offset := world_pos - turn_origin
	var distance := offset.length()
	if distance <= usable_radius:
		target_position = world_pos
	elif distance > 0.0:
		target_position = turn_origin + offset.normalized() * usable_radius

func _physics_process(delta: float) -> void:
	var to_target := target_position - global_position
	if to_target.length() > 2.0:
		velocity = to_target.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
	_update_visual_animation(delta)

func _update_visual_animation(delta: float) -> void:
	visual_time += delta
	var is_moving := velocity.length() > 5.0
	if is_moving:
		if velocity.x > 0.1:
			facing_right = true
		elif velocity.x < -0.1:
			facing_right = false
		sprite.flip_h = facing_right
		var target_rotation := sin(visual_time * move_tilt_speed) * deg_to_rad(move_tilt_amount_degrees)
		sprite.rotation = lerp(sprite.rotation, target_rotation, delta * return_speed)
		sprite.scale = sprite.scale.lerp(base_sprite_scale, delta * stretch_return_speed)
	else:
		var idle_scale_y := 1.0 + sin(visual_time * idle_pulse_speed) * idle_pulse_amount
		var idle_target_scale := Vector2(base_sprite_scale.x, base_sprite_scale.y * idle_scale_y)
		sprite.rotation = lerp(sprite.rotation, 0.0, delta * return_speed)
		sprite.scale = sprite.scale.lerp(idle_target_scale, delta * stretch_return_speed)

func _reset_visual_pose() -> void:
	sprite.rotation = 0.0
	sprite.scale = base_sprite_scale

func _update_visual() -> void:
	if is_zombified:
		sprite.modulate = Color(0.8, 0.5, 1.0)
	elif is_active:
		sprite.modulate = Color(1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.8, 0.8, 0.8)

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)
	_save_to_gamedata()

func increase_move_radius(amount: float) -> void:
	move_radius += amount
	_save_to_gamedata()

func basic_attack_damage() -> int:
	return max(1, base_damage + get_total_modifier("attack_bonus"))

func special_attack_damage() -> int:
	return basic_attack_damage() + 2

func take_damage(amount: int) -> void:
	var reduced = max(amount - block_power, 0)
	block_power = 0
	hp = max(hp - reduced, 0)
	_save_to_gamedata()

func is_dead() -> bool:
	return hp <= 0

func add_money(amount: int) -> void:
	money += amount
	_save_to_gamedata()

func spend_money(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	_save_to_gamedata()
	return true

func zombify() -> void:
	if is_zombified:
		return
	is_zombified = true
	money = 0
	move_radius += zombie_move_radius_bonus
	hp = max(1, int(ceil(max_hp / 2.0)))
	_save_to_gamedata()
	_update_visual()

func can_collect_rewards() -> bool:
	return not is_zombified

func can_use_special() -> bool:
	return current_ap >= get_special_cost()

func get_special_cost() -> int:
	return max(1, special_cost + get_total_modifier("special_cost_delta"))

func spend_ap(amount: int) -> bool:
	if current_ap < amount:
		return false
	current_ap -= amount
	_save_to_gamedata()
	return true

func activate_block() -> void:
	block_power = 3 + get_total_modifier("block_bonus")
	_save_to_gamedata()

func collect_item(item_id: String) -> Dictionary:
	collected_items.append(item_id)
	var data = GameData.get_item_data(item_id)
	var pickup_money := int(data.get("modifiers", {}).get("money_on_pickup", 0))
	if pickup_money > 0:
		money += pickup_money
	_recalculate_from_items()
	_save_to_gamedata()
	return data

func get_total_modifier(key: String) -> int:
	var total := 0
	for item_id in collected_items:
		var data = GameData.get_item_data(item_id)
		var modifiers: Dictionary = data.get("modifiers", {})
		total += int(modifiers.get(key, 0))
	return total

func get_total_modifier_float(key: String) -> float:
	var total := 0.0
	for item_id in collected_items:
		var data = GameData.get_item_data(item_id)
		var modifiers: Dictionary = data.get("modifiers", {})
		total += float(modifiers.get(key, 0.0))
	return total

func _recalculate_from_items() -> void:
	var base_data = GameData.get_character_data(character_id)
	max_hp = int(base_data.get("base_hp", 100)) + get_total_modifier("max_hp_bonus")
	hp = clamp(hp, 0, max_hp)
	move_radius = float(base_data.get("move_radius", 1000.0)) + get_total_modifier_float("move_radius_bonus")
	max_ap = 20 + get_total_modifier("ap_max_bonus")
	current_ap = min(current_ap, max_ap)

func perform_basic_attack(target) -> Dictionary:
	var damage := basic_attack_damage()
	match character_id:
		1:
			damage += 1
		2:
			damage += 2
		3:
			damage += 0
		4:
			damage += 1
		5:
			damage += 0
		6:
			damage += 2
		7:
			damage += 1
		8:
			damage += 2
		9:
			damage += 0
	target.take_damage(damage)
	_apply_on_hit_effects(damage)
	return {"damage": damage, "text": "%s dealt %d damage." % [GameData.get_character_data(character_id).get("basic_name", "Attack"), damage]}

func perform_special_attack(target) -> Dictionary:
	var cost := get_special_cost()
	if not spend_ap(cost):
		return {"ok": false, "text": "Not enough AP."}
	var damage := special_attack_damage()
	var text = GameData.get_character_data(character_id).get("special_name", "Special")
	match character_id:
		1:
			damage += 4
			target.take_damage(damage)
			if not target.is_dead():
				target.take_damage(int(ceil(damage * 0.5)))
			text += " hit twice"
		2:
			damage += 6
			target.take_damage(damage)
		3:
			damage += 3
			target.take_damage(damage)
			heal(3)
		4:
			damage += 5
			target.take_damage(damage)
			current_ap = min(max_ap, current_ap + 2)
		5:
			activate_block()
			target.take_damage(damage)
		6:
			damage += 7
			target.take_damage(damage)
		7:
			damage += 4
			target.take_damage(damage)
			base_damage += 1
		8:
			damage += 8
			target.take_damage(damage)
		9:
			damage += 2
			target.take_damage(damage)
			heal(8)
	_apply_on_hit_effects(damage)
	_save_to_gamedata()
	return {"ok": true, "damage": damage, "text": "%s dealt %d damage." % [text, damage]}

func _apply_on_hit_effects(_damage: int) -> void:
	var lifesteal := get_total_modifier("lifesteal")
	if lifesteal > 0:
		heal(lifesteal)

func get_thorns_damage() -> int:
	return get_total_modifier("thorns")
