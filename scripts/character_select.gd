extends Control

@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton

@onready var character_buttons: Array[Button] = [
	$CenterContainer/VBoxContainer/Character1Button,
	$CenterContainer/VBoxContainer/Character2Button,
	$CenterContainer/VBoxContainer/Character3Button,
	$CenterContainer/VBoxContainer/Character4Button,
	$CenterContainer/VBoxContainer/Character5Button,
	$CenterContainer/VBoxContainer/Character6Button,
	$CenterContainer/VBoxContainer/Character7Button,
	$CenterContainer/VBoxContainer/Character8Button,
	$CenterContainer/VBoxContainer/Character9Button
]

func _ready() -> void:
	_update_info_label()
	_connect_character_buttons()
	back_button.pressed.connect(_on_back_pressed)

func _connect_character_buttons() -> void:
	for i in range(character_buttons.size()):
		var button := character_buttons[i]
		button.pressed.connect(func(): _on_character_selected(i + 1))

func _on_character_selected(character_id: int) -> void:
	# Prevent duplicate picks
	if character_id in GameData.selected_characters:
		return

	GameData.selected_characters.append(character_id)
	_disable_selected_button(character_id)

	if GameData.selected_characters.size() >= GameData.player_count:
		get_tree().change_scene_to_file("res://scenes/world/Overworld.tscn")
	else:
		_update_info_label()

func _disable_selected_button(character_id: int) -> void:
	var button_index := character_id - 1
	if button_index >= 0 and button_index < character_buttons.size():
		character_buttons[button_index].disabled = true

func _update_info_label() -> void:
	var current_player_number := GameData.selected_characters.size() + 1
	info_label.text = "Player %d: Select Your Character" % current_player_number

func _on_back_pressed() -> void:
	GameData.selected_characters.clear()
	get_tree().change_scene_to_file("res://scenes/menus/PlayerCountMenu.tscn")
