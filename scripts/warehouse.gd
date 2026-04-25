extends Node2D

signal exit_requested(body: Node2D)

@onready var entrance_node: Area2D = $Entrance
@onready var exit_node: Area2D = $Exit

func _ready() -> void:
	if exit_node != null and not exit_node.body_entered.is_connected(_on_exit_body_entered):
		exit_node.body_entered.connect(_on_exit_body_entered)

func initialize_warehouse() -> void:
	pass

func get_entry_position() -> Vector2:
	if entrance_node != null:
		return entrance_node.global_position + Vector2(0, 500)
	return global_position

func _on_exit_body_entered(body: Node2D) -> void:
	emit_signal("exit_requested", body)
