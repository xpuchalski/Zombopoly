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

const CHARACTER_RUN_PATH := "res://assets/characters/run/%d.png"

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

var bleed_stacks: int = 0
var burn_stacks: int = 0
var temporary_hp: int = 0
var placebo_turns: int = 0
var counter_active: bool = false
var queued_reflect_damage: int = 0
var decoy_available: bool = false
var zombie_damage_memory: Array = []

var is_active: bool = false
var is_zombified: bool = false
var movement_locked: bool = false
var is_in_dungeon: bool = false
var current_dungeon_id: String = ""

var zombie_move_radius_bonus: float = 100.0
var base_collision_radius: float = 30.0
var turn_origin: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var move_speed: float = 250.0
var visual_time: float = 0.0
var facing_right: bool = true
var idle_pulse_speed: float = 2.0
var idle_pulse_amount: float = 0.03
var move_tilt_speed: float = TAU * 1.2
var move_tilt_amount_degrees: float = 12.0
var base_sprite_scale: Vector2 = Vector2(0.25, 0.25)
var idle_texture: Texture2D = null
var run_texture: Texture2D = null
var using_run_texture: bool = false
var return_speed: float = 8.0
var stretch_return_speed: float = 6.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	print_tree_pretty()
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
	bleed_stacks = int(data.get("bleed_stacks", 0))
	burn_stacks = int(data.get("burn_stacks", 0))
	temporary_hp = int(data.get("temporary_hp", 0))
	placebo_turns = int(data.get("placebo_turns", 0))
	counter_active = bool(data.get("counter_active", false))
	zombie_damage_memory = data.get("zombie_damage_memory", []).duplicate(true)
	special_cost = int(GameData.get_character_data(character_id).get("special_cost", 10))
	_apply_character_sprite()
	_recalculate_from_items()
	_update_visual()

func _apply_character_sprite() -> void:
	idle_texture = null
	run_texture = null
	using_run_texture = false
	if CHARACTER_TEXTURES.has(character_id):
		idle_texture = CHARACTER_TEXTURES[character_id]
		sprite.texture = idle_texture
	var run_path := CHARACTER_RUN_PATH % character_id
	if ResourceLoader.exists(run_path):
		run_texture = load(run_path)
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
		player_data["bleed_stacks"] = bleed_stacks
		player_data["burn_stacks"] = burn_stacks
		player_data["temporary_hp"] = temporary_hp
		player_data["placebo_turns"] = placebo_turns
		player_data["counter_active"] = counter_active
		player_data["zombie_damage_memory"] = zombie_damage_memory.duplicate(true)
		return

func snap_to_position(pos: Vector2) -> void:
	global_position = pos
	target_position = pos
	_reset_visual_pose()

func start_turn() -> void:
	is_active = true
	turn_origin = global_position
	target_position = global_position
	current_ap = min(max_ap, current_ap + 1 + get_total_modifier("ap_regen_bonus"))
	block_power = 0
	decoy_available = get_total_modifier("decoy_per_battle") > 0
	_apply_turn_start_item_effects()
	_reset_visual_pose()
	_update_visual()
	_save_to_gamedata()

func end_turn() -> void:
	_process_end_turn_effects()
	is_active = false
	_update_visual()
	_save_to_gamedata()

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
	_set_running_visual(is_moving)
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

func _set_running_visual(is_moving: bool) -> void:
	if is_moving and run_texture != null and not using_run_texture:
		sprite.texture = run_texture
		using_run_texture = true
	elif not is_moving and using_run_texture:
		if idle_texture != null:
			sprite.texture = idle_texture
		using_run_texture = false

func _reset_visual_pose() -> void:
	sprite.rotation = 0.0
	sprite.scale = base_sprite_scale

func _update_visual() -> void:
	if is_zombified:
		sprite.modulate = Color(0.407, 0.733, 0.479, 1.0)
	elif is_active:
		sprite.modulate = Color(1.0, 1.0, 1.0)
	else:
		sprite.modulate = Color(0.8, 0.8, 0.8)

func heal(amount: int) -> void:
	var cap := max_hp
	if get_bool_modifier("overheal_all"):
		cap = max(max_hp * 2, max_hp + amount)
	else:
		var overheal_percent := get_total_modifier_float("overheal_percent")
		if overheal_percent > 0.0:
			cap = int(ceil(max_hp * (1.0 + overheal_percent)))
	hp = min(hp + amount, cap)
	_save_to_gamedata()

func increase_move_radius(amount: float) -> void:
	move_radius += amount
	_save_to_gamedata()

func basic_attack_damage() -> int:
	var raw := float(base_damage + get_total_modifier("attack_bonus"))
	raw *= 1.0 + get_total_modifier_float("attack_multiplier")
	if placebo_turns > 0:
		raw *= 3.0
	return max(1, int(round(raw)))

func _roll_damage_with_crit(base_amount: int, target = null) -> Dictionary:
	var damage := base_amount
	var did_crit := false
	var instant_kill := false
	if randf() < get_total_modifier_float("instant_kill_chance"):
		instant_kill = true
	var guaranteed_bleed_crit := false
	if target != null and get_bool_modifier("guaranteed_crit_bleeding") and target.has_method("get_bleed_stacks"):
		guaranteed_bleed_crit = target.get_bleed_stacks() > 0
	if guaranteed_bleed_crit or randf() < get_total_modifier_float("crit_chance"):
		damage *= 3
		did_crit = true
	return {"damage": damage, "crit": did_crit, "instant_kill": instant_kill}

func take_damage(amount: int) -> void:
	var incoming = max(amount, 0)
	queued_reflect_damage = 0

	if incoming <= 0:
		return

	if counter_active:
		counter_active = false
		queued_reflect_damage += incoming
		_save_to_gamedata()
		return

	if decoy_available:
		decoy_available = false
		_save_to_gamedata()
		return

	if randf() < get_total_modifier_float("damage_negate_chance"):
		_save_to_gamedata()
		return

	var reduced = max(incoming - block_power - get_total_modifier("damage_reduction"), 0)
	block_power = 0

	var thorns_fraction := get_total_modifier_float("thorns_fraction")
	if thorns_fraction > 0.0:
		queued_reflect_damage += int(ceil(float(reduced) * thorns_fraction))

	if temporary_hp > 0 and reduced > 0:
		var absorbed = min(temporary_hp, reduced)
		temporary_hp -= absorbed
		reduced -= absorbed

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

func get_bool_modifier(key: String) -> bool:
	for item_id in collected_items:
		var data = GameData.get_item_data(item_id)
		var modifiers: Dictionary = data.get("modifiers", {})
		if bool(modifiers.get(key, false)):
			return true
	return false

func _recalculate_from_items() -> void:
	var old_max := max_hp
	var base_data = GameData.get_character_data(character_id)
	max_hp = int(base_data.get("base_hp", 100)) + get_total_modifier("max_hp_bonus")
	if max_hp > old_max:
		hp += max_hp - old_max
	hp = clamp(hp, 0, max_hp)
	move_radius = float(base_data.get("move_radius", 1000.0)) + get_total_modifier_float("move_radius_bonus")
	max_ap = 20 + get_total_modifier("ap_max_bonus")
	current_ap = min(current_ap, max_ap)
	base_damage = int(base_data.get("base_attack", 5))

func perform_basic_attack(target) -> Dictionary:
	var roll := _roll_damage_with_crit(basic_attack_damage(), target)
	var damage: int = int(roll["damage"])
	if roll["instant_kill"] and target != null and target.has_method("take_damage"):
		damage = max(damage, 999999)
	target.take_damage(damage)
	_apply_on_hit_effects(damage, target)
	var text := "%s dealt %d damage." % [GameData.get_character_data(character_id).get("basic_name", "Attack"), damage]
	if roll["crit"]:
		text += " Critical!"
	if roll["instant_kill"]:
		text += " Instant kill!"
	return {"damage": damage, "text": text}

func perform_special_attack(target) -> Dictionary:
	var cost := get_special_cost()
	if not spend_ap(cost):
		return {"ok": false, "text": "Not enough AP."}

	var base := basic_attack_damage()
	var damage := base
	var text: String = GameData.get_character_data(character_id).get("special_name", "Special")

	match character_id:
		1:
			damage = base * 3
			target.take_damage(damage)
			heal(int(ceil(float(damage) * 0.5)))
			placebo_turns = 4
			text += " empowered Penny for 4 turns"
		2:
			damage = base * 5
			target.take_damage(damage)
			if not target.is_dead() and target.hp < 50:
				target.take_damage(target.hp)
				text += " executed the target"
		3:
			damage = base * 3
			target.take_damage(damage)
			_apply_burn_to_target(target, 5)
		4:
			damage = base * 2 * max(collected_items.size(), 1)
			target.take_damage(damage)
		5:
			damage = 0
			counter_active = true
			text += " prepared a counter"
		6:
			damage = hp
			target.take_damage(damage)
		7:
			damage = base * 2
			target.take_damage(damage)
			_apply_bleed_to_target(target, 10)
		8:
			damage = int(round(float(base) * (move_radius / 100.0)))
			target.take_damage(damage)
		9:
			damage = 0
			for stored_damage in zombie_damage_memory:
				damage += int(stored_damage)
			damage = max(damage, base)
			target.take_damage(damage)
		_:
			target.take_damage(damage)

	if damage > 0:
		_apply_on_hit_effects(damage, target)
	_save_to_gamedata()
	return {"ok": true, "damage": damage, "text": "%s dealt %d damage." % [text, damage]}

func _apply_on_hit_effects(damage: int, target = null) -> void:
	var lifesteal := get_total_modifier("lifesteal")
	if placebo_turns > 0:
		lifesteal += int(ceil(float(damage) * 0.5))
	if lifesteal > 0:
		heal(lifesteal)

	var bleed_on_hit := get_total_modifier("bleed_on_hit")
	if bleed_on_hit > 0 and target != null:
		_apply_bleed_to_target(target, bleed_on_hit)

func _apply_bleed_to_target(target, stacks: int) -> void:
	if target != null and target.has_method("apply_bleed"):
		target.apply_bleed(stacks)

func _apply_burn_to_target(target, stacks: int) -> void:
	if target != null and target.has_method("apply_burn"):
		target.apply_burn(stacks)

func apply_bleed(stacks: int) -> void:
	bleed_stacks += max(stacks, 0)
	_save_to_gamedata()

func apply_burn(stacks: int) -> void:
	burn_stacks += max(stacks, 0)
	_save_to_gamedata()

func get_bleed_stacks() -> int:
	return bleed_stacks

func get_burn_stacks() -> int:
	return burn_stacks

func _process_end_turn_effects() -> void:
	var status_heal := (bleed_stacks + burn_stacks) * get_total_modifier("status_heal_per_instance")
	if status_heal > 0:
		heal(status_heal)

	if bleed_stacks > 0:
		take_damage(bleed_stacks * 3)

	if burn_stacks > 0 and hp > 0:
		var burn_damage = max(1, int(ceil(float(hp) * 0.05 * float(burn_stacks))))
		take_damage(burn_damage)

	if placebo_turns > 0:
		placebo_turns -= 1

func _apply_turn_start_item_effects() -> void:
	var heal_per_turn := get_total_modifier("heal_per_turn")
	if heal_per_turn > 0:
		heal(heal_per_turn)

	var temp_hp_gain := get_total_modifier("temp_hp_per_turn")
	if temp_hp_gain > 0:
		temporary_hp += temp_hp_gain

func get_thorns_damage() -> int:
	var damage := queued_reflect_damage
	queued_reflect_damage = 0
	_save_to_gamedata()
	return damage

func note_zombie_fought(zombie) -> void:
	if zombie == null:
		return
	var stored_damage := 0
	if "attack_damage" in zombie:
		stored_damage = int(zombie.attack_damage)
	if stored_damage <= 0:
		return
	zombie_damage_memory.append(stored_damage)
	_save_to_gamedata()

func get_portrait_texture(hurt: bool = false) -> Texture2D:
	var path := "res://assets/characters/portraits/hurt/%d.png" % character_id if hurt else "res://assets/characters/portraits/%d.png" % character_id
	if ResourceLoader.exists(path):
		return load(path)
	return null
