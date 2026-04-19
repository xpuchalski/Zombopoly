extends CharacterBody2D

var player_id: int = 0
var character_id: int = 0

var move_radius: float = 150.0
var hp: int = 10
var max_hp: int = 10
var money: int = 0

var is_active: bool = false
var is_zombified: bool = false
var movement_locked: bool = false

var zombie_move_radius_bonus: float = 100.0

var turn_origin: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 250.0

var visual_time: float = 0.0
var facing_right: bool = true

var idle_pulse_speed: float = 2.0
var idle_pulse_amount: float = 0.03

var move_tilt_speed: float = TAU
var move_tilt_amount_degrees: float = 15.0

var return_speed: float = 8.0
var stretch_return_speed: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	target_position = global_position
	_update_visual()
	_reset_visual_pose()

func setup_from_data(data: Dictionary) -> void:
	player_id = data["player_id"]
	character_id = data["character_id"]
	move_radius = data["move_radius"]
	hp = data["hp"]
	max_hp = data["max_hp"]
	money = data["money"]

func snap_to_position(pos: Vector2) -> void:
	global_position = pos
	target_position = pos
	_reset_visual_pose()

func start_turn() -> void:
	is_active = true
	turn_origin = global_position
	target_position = global_position
	_reset_visual_pose()
	_update_visual()

func end_turn() -> void:
	is_active = false
	_update_visual()

func try_move_to(world_pos: Vector2) -> void:
	if not is_active:
		return

	if movement_locked:
		return

	if world_pos.distance_to(turn_origin) <= move_radius:
		target_position = world_pos

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

		var target_rotation = sin(visual_time * move_tilt_speed) * deg_to_rad(move_tilt_amount_degrees)
		sprite.rotation = lerp(sprite.rotation, target_rotation, delta * return_speed)

		var target_scale = Vector2.ONE
		sprite.scale = sprite.scale.lerp(target_scale, delta * stretch_return_speed)
	else:
		var idle_scale_y = 1.0 + sin(visual_time * idle_pulse_speed) * idle_pulse_amount
		var target_scale = Vector2(1.0, idle_scale_y)

		sprite.rotation = lerp(sprite.rotation, 0.0, delta * return_speed)
		sprite.scale = sprite.scale.lerp(target_scale, delta * stretch_return_speed)

func _reset_visual_pose() -> void:
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE

func _update_visual() -> void:
	if is_zombified:
		sprite.modulate = Color(0.8, 0.5, 1.0)
	elif is_active:
		sprite.modulate = Color(1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.8, 0.8, 0.8)

func heal(amount: int) -> void:
	hp = min(hp + amount, max_hp)
	print("Player %d healed to %d / %d" % [player_id, hp, max_hp])

func increase_move_radius(amount: float) -> void:
	move_radius += amount
	print("Player %d move radius is now %.1f" % [player_id, move_radius])

func basic_attack_damage() -> int:
	return 10

func take_damage(amount: int) -> void:
	hp -= amount
	if hp < 0:
		hp = 0
	print("Player %d took %d damage. HP: %d / %d" % [player_id, amount, hp, max_hp])

func is_dead() -> bool:
	return hp <= 0

func add_money(amount: int) -> void:
	money += amount
	print("Player %d gained %d money. Total: %d" % [player_id, amount, money])

func spend_money(amount: int) -> bool:
	if money < amount:
		return false

	money -= amount
	return true

func zombify() -> void:
	is_zombified = true
	money = 0
	move_radius += zombie_move_radius_bonus
	hp = max(1, int(ceil(max_hp / 2.0)))
	print("Player %d has been zombified. HP: %d | Radius: %.1f" % [player_id, hp, move_radius])
	_update_visual()

func can_collect_rewards() -> bool:
	return not is_zombified
