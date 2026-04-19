extends Node2D

var target_player = null

func _draw() -> void:
	if target_player == null:
		return

	if not target_player.is_active:
		return

	draw_arc(
		target_player.turn_origin,
		target_player.move_radius,
		0.0,
		TAU,
		64,
		Color(0.2, 0.8, 1.0),
		2.0
	)
