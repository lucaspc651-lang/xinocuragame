extends Node2D

@onready var label: Label = $Label


func show_damage(amount: int) -> void:
	label.text = "-" + str(amount)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + Vector2(0.0, -12.0), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.finished.connect(queue_free)
