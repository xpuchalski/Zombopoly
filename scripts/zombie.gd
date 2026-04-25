extends Area2D

const MAP_SPRITE_SCALE := Vector2(0.25, 0.25)

@onready var sprite: Sprite2D = $Sprite2D

var zombie_id: int = 0
var zombie_type: String = "walker"
var hp: int = 10
var max_hp: int = 10
var attack_damage: int = 5
var money_drop: int = 5
var display_name: String = "Zombie"
var bleed_stacks: int = 0
var burn_stacks: int = 0
var visual_time: float = 0.0
var idle_pulse_speed: float = 2.0
var idle_pulse_amount: float = 0.06


func _ready() -> void:
	print_tree_pretty()
	_apply_map_sprite_scale()

func _process(delta: float) -> void:
	visual_time += delta
	var pulse_y := 1.0 + sin(visual_time * idle_pulse_speed) * idle_pulse_amount
	var pulse_x := 1.0 - sin(visual_time * idle_pulse_speed) * idle_pulse_amount * 0.4
	if sprite != null:
		sprite.scale = Vector2(MAP_SPRITE_SCALE.x * pulse_x, MAP_SPRITE_SCALE.y * pulse_y)
	z_index = int(global_position.y)


func setup(id: int, type_name: String = "walker") -> void:
	zombie_id = id
	zombie_type = type_name
	_apply_type_data(GameData.get_zombie_type_data(zombie_type))


func _apply_type_data(data: Dictionary) -> void:
	display_name = data.get("display_name", "Zombie")
	max_hp = int(data.get("hp", 10))
	hp = max_hp
	attack_damage = int(data.get("attack_damage", 5))
	money_drop = int(data.get("money_drop", 5))

	var path := str(data.get("sprite_path", ""))
	if path != "" and ResourceLoader.exists(path):
		sprite.texture = load(path)

	_apply_map_sprite_scale()


func _apply_map_sprite_scale() -> void:
	if sprite != null:
		sprite.scale = MAP_SPRITE_SCALE

func get_portrait_texture() -> Texture2D:
	var data := GameData.get_zombie_type_data(zombie_type)
	var path := str(data.get("portrait_path", ""))

	if path != "" and ResourceLoader.exists(path):
		return load(path)

	return null

func take_damage(amount: int) -> void:
	hp = max(hp - max(amount, 0), 0)


func is_dead() -> bool:
	return hp <= 0


func apply_bleed(stacks: int) -> void:
	bleed_stacks += max(stacks, 0)


func apply_burn(stacks: int) -> void:
	burn_stacks += max(stacks, 0)


func get_bleed_stacks() -> int:
	return bleed_stacks


func get_burn_stacks() -> int:
	return burn_stacks


func process_end_turn_effects() -> void:
	if bleed_stacks > 0:
		take_damage(bleed_stacks * 3)

	if burn_stacks > 0 and hp > 0:
		var burn_damage = max(1, int(ceil(float(hp) * 0.05 * float(burn_stacks))))
		take_damage(burn_damage)
