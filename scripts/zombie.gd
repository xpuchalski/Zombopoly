extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

var zombie_id: int = 0
var zombie_type: String = "walker"
var hp: int = 10
var max_hp: int = 10
var attack_damage: int = 5
var money_drop: int = 5
var display_name: String = "Zombie"

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

func take_damage(amount: int) -> void:
	hp -= amount

func is_dead() -> bool:
	return hp <= 0
