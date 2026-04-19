extends Control

func _ready() -> void:
	$CenterContainer/VBoxContainer/OnePlayerButton.pressed.connect(func(): _set_player_count(1))
	$CenterContainer/VBoxContainer/TwoPlayerButton.pressed.connect(func(): _set_player_count(2))
	$CenterContainer/VBoxContainer/ThreePlayerButton.pressed.connect(func(): _set_player_count(3))
	$CenterContainer/VBoxContainer/FourPlayerButton.pressed.connect(func(): _set_player_count(4))
	$CenterContainer/VBoxContainer/BackButton.pressed.connect(_on_back_pressed)

func _set_player_count(count: int) -> void:
	GameData.player_count = count
	GameData.selected_characters.clear()
	get_tree().change_scene_to_file("res://scenes/menus/CharacterSelect.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
