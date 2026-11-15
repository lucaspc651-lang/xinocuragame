extends Area2D

var _ending_started = false


func _on_body_entered(body: Node2D) -> void:
	if _ending_started or not body.is_in_group("player"):
		return

	_ending_started = true
	body.velocity = Vector2.ZERO
	body.set_physics_process(false)
	_show_ending()


func _show_ending() -> void:
	var ending_layer := CanvasLayer.new()
	var screen := ColorRect.new()
	var message := Label.new()
	var tween := create_tween()

	ending_layer.layer = 10
	get_tree().root.add_child(ending_layer)

	screen.color = Color(0.015, 0.02, 0.04, 0.0)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_layer.add_child(screen)

	message.text = "VOCÊ VENCEU\n\nA jornada chegou ao fim"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.72, 1.0, 0.91))
	message.add_theme_font_size_override("font_size", 26)
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.modulate.a = 0.0
	ending_layer.add_child(message)

	tween.tween_property(screen, "color:a", 0.88, 1.5)
	tween.parallel().tween_property(message, "modulate:a", 1.0, 1.5)
	tween.tween_interval(3.0)
	tween.tween_callback(get_tree().quit)
