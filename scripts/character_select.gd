extends Control

const PORTRAIT_PATH := "res://assets/characters/portraits/%d.png"

@onready var buttons: Array = [
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
@onready var info_label: Label = $CenterContainer/VBoxContainer/InfoLabel
@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton
@onready var portrait_slots: Array = [$Portraits/P1Portrait, $Portraits/P2Portrait, $Portraits/P3Portrait, $Portraits/P4Portrait]

var selected_characters: Array = []
var current_player_index: int = 0
var player_count: int = 1
var confirm_button: Button

func _ready() -> void:
	player_count = GameData.player_count
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_character_selected.bind(i + 1))
	back_button.pressed.connect(_on_back_pressed)
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.disabled = false
	confirm_button.position = Vector2(-40, 650)
	add_child(confirm_button)
	confirm_button.pressed.connect(_finish_selection)
	_clear_portraits()
	_update_info_label()

func _on_character_selected(character_id: int) -> void:
	if character_id in selected_characters or selected_characters.size() >= player_count:
		return
	selected_characters.append(character_id)
	_update_portrait(current_player_index, character_id)
	current_player_index += 1
	_update_button_states()
	_update_info_label()
	if selected_characters.size() >= player_count:
		confirm_button.disabled = false

func _update_button_states() -> void:
	for i in range(buttons.size()):
		buttons[i].disabled = (i + 1) in selected_characters or selected_characters.size() >= player_count

func _update_info_label() -> void:
	if selected_characters.size() >= player_count:
		info_label.text = "All players selected. Press Confirm."
	else:
		info_label.text = "Select character for Player %d" % [selected_characters.size() + 1]

func _update_portrait(player_index: int, character_id: int) -> void:
	if player_index >= portrait_slots.size():
		return
	var portrait_node: TextureRect = portrait_slots[player_index]
	var base_texture: Texture2D = load(PORTRAIT_PATH % character_id)
	if base_texture == null:
		return
	var tex_size: Vector2i = base_texture.get_size()
	var crop_height: int = int(tex_size.y * 0.55)
	var atlas := AtlasTexture.new()
	atlas.atlas = base_texture
	atlas.region = Rect2i(0, 0, tex_size.x, crop_height)
	portrait_node.texture = atlas
	portrait_node.visible = true

func _clear_portraits() -> void:
	for p in portrait_slots:
		p.texture = null
		p.visible = false

func _finish_selection() -> void:
	if selected_characters.size() < player_count:
		return
	GameData.selected_characters = selected_characters.duplicate()
	get_tree().change_scene_to_file("res://scenes/world/Overworld.tscn")

func _on_back_pressed() -> void:
	GameData.selected_characters.clear()
	get_tree().change_scene_to_file("res://scenes/menus/PlayerCountMenu.tscn")
