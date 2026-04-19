extends Control

@onready var return_button: Button = $CenterContainer/VBoxContainer/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_pressed)

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/Overworld.tscn")
