extends Node2D

const PANEL_COLOR = Color(0.035, 0.09, 0.1, 0.9)
const BAR_COLOR = Color(0.2, 0.85, 0.62, 1.0)
const TEXT_COLOR = Color(1.0, 0.85, 0.68, 1.0)

var _current_health = 0
var _maximum_health = 1


func update_health(current_health: int, maximum_health: int) -> void:
	_current_health = current_health
	_maximum_health = maxi(maximum_health, 1)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 52.0, 15.0), PANEL_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(4.0, 7.0),
		"VIDA %d/%d" % [_current_health, _maximum_health],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		6,
		TEXT_COLOR
	)
	draw_rect(Rect2(4.0, 10.0, 44.0, 3.0), Color(0.1, 0.18, 0.17, 1.0))
	var health_width := 44.0 * float(_current_health) / float(_maximum_health)
	if health_width > 0.0:
		draw_rect(Rect2(4.0, 10.0, health_width, 3.0), BAR_COLOR)
