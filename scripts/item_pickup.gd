extends Area2D

const RARITY_COLORS := {
	"common": Color(0.85, 0.85, 0.85),
	"uncommon": Color(0.35, 0.9, 0.45),
	"rare": Color(0.3, 0.65, 1.0),
	"epic": Color(0.8, 0.45, 1.0),
	"legendary": Color(1.0, 0.72, 0.2)
}

var item_id: String = ""
var item_data: Dictionary = {}
var collected: bool = false
var spawn_position: Vector2 = Vector2.ZERO

func setup(new_item_id: String) -> void:
	item_id = new_item_id
	item_data = GameData.get_item_data(item_id)
	spawn_position = global_position
	collected = false
	visible = true
	monitoring = true
	monitorable = true
	_update_visual()

func _update_visual() -> void:
	var polygon: Polygon2D = $Polygon2D
	polygon.color = RARITY_COLORS.get(item_data.get("rarity", "common"), Color.WHITE)

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
