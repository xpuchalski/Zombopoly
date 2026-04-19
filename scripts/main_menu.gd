extends Control

@onready var start_button = $CenterContainer/VBoxContainer/StartButton
@onready var options_button = $CenterContainer/VBoxContainer/OptionsButton
@onready var exit_button = $CenterContainer/VBoxContainer/ExitButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/PlayerCountMenu.tscn")
func _on_options_pressed() -> void:
	print("Options not built yet.")

func _on_exit_pressed() -> void:
	get_tree().quit()
