extends Area2D

var zombie_id: int = 0
var hp: int = 10
var max_hp: int = 10
var attack_damage: int = 5
var money_drop: int = 5

func setup(id: int) -> void:
	zombie_id = id

func take_damage(amount: int) -> void:
	hp -= amount
	print("Zombie %d took %d damage. HP: %d" % [zombie_id, amount, hp])

func is_dead() -> bool:
	return hp <= 0
