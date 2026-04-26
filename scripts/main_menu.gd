extends Control

@onready var main_menu_panel: Control = $MainMenuPanel
@onready var start_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/StartButton
@onready var how_to_play_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/HowToPlayButton
@onready var lore_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/LoreButton
@onready var exit_button: Button = $MainMenuPanel/CenterContainer/VBoxContainer/ExitButton

@onready var how_to_play_panel: Control = $HowToPlayPanel
@onready var how_to_play_back_button: Button = $HowToPlayPanel/BackButton
@onready var how_to_play_scroll: ScrollContainer = $HowToPlayPanel/ScrollContainer

@onready var lore_panel: Control = $LorePanel
@onready var lore_back_button: Button = $LorePanel/BackButton
@onready var lore_scroll: ScrollContainer = $LorePanel/ScrollContainer
@onready var lore_label: Label = $LorePanel/ScrollContainer/Label


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	lore_button.pressed.connect(_on_lore_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	how_to_play_back_button.pressed.connect(_on_back_pressed)
	lore_back_button.pressed.connect(_on_back_pressed)

	_show_main_menu()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/PlayerCountMenu.tscn")


func _on_how_to_play_pressed() -> void:
	_hide_all_panels()
	how_to_play_panel.visible = true
	_reset_scroll(how_to_play_scroll)


func _on_lore_pressed() -> void:
	_hide_all_panels()
	lore_panel.visible = true
	_reset_scroll(lore_scroll)


func _on_back_pressed() -> void:
	_show_main_menu()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _show_main_menu() -> void:
	_hide_all_panels()
	main_menu_panel.visible = true


func _hide_all_panels() -> void:
	main_menu_panel.visible = false
	how_to_play_panel.visible = false
	lore_panel.visible = false


func _reset_scroll(scroll_container: ScrollContainer) -> void:
	await get_tree().process_frame
	scroll_container.scroll_vertical = 0
	scroll_container.scroll_horizontal = 0
