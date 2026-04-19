extends Area2D

var item_id: int = 0
var item_type: String = ""
var collected: bool = false
var spawn_position: Vector2 = Vector2.ZERO

func setup(id: int, type: String) -> void:
	item_id = id
	item_type = type
	spawn_position = global_position
	collected = false
	visible = true
	monitoring = true
	monitorable = true
	_update_visual()

func _update_visual() -> void:
	var polygon: Polygon2D = $Polygon2D

	match item_type:
		"hp":
			polygon.color = Color(1.0, 0.8, 0.2)
		"radius":
			polygon.color = Color(0.3, 0.8, 1.0)
		_:
			polygon.color = Color(1.0, 1.0, 1.0)

func collect() -> void:
	collected = true
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func respawn() -> void:
	collected = false
	global_position = spawn_position
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
