extends Control

const GAME_SCENE = "res://scene/node_2d.tscn"


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color(0.035, 0.045, 0.08)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 14)
	center.add_child(menu)

	var title := Label.new()
	title.text = "SAMURAI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.35, 0.92, 0.85))
	title.add_theme_font_size_override("font_size", 32)
	menu.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A jornada começa"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	subtitle.add_theme_font_size_override("font_size", 14)
	menu.add_child(subtitle)

	var start_button := _make_button("Jogar")
	start_button.pressed.connect(_start_game)
	menu.add_child(start_button)

	var exit_button := _make_button("Sair")
	exit_button.pressed.connect(get_tree().quit)
	menu.add_child(exit_button)
	start_button.grab_focus()


func _make_button(button_text: String) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(180, 38)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _start_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
