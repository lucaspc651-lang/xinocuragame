extends Node2D

const LIFETIME = 0.2
const SLASH_START_ANGLE = -1.3
const SLASH_END_ANGLE = 1.3

var _elapsed = 0.0
var _direction = 1.0


func play_once(world_position: Vector2, direction: float) -> void:
	global_position = world_position
	_direction = direction


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(_elapsed / LIFETIME, 0.0, 1.0)
	var fade := 1.0 - progress
	var angle_end := lerpf(SLASH_START_ANGLE, SLASH_END_ANGLE, progress)
	var radius := lerpf(20.0, 31.0, progress)
	var points := PackedVector2Array()
	var point_count := maxi(2, int(lerpf(3.0, 15.0, progress)))
	for index in range(point_count):
		var amount := float(index) / float(point_count - 1)
		var angle := lerpf(SLASH_START_ANGLE, angle_end, amount)
		points.append(Vector2(cos(angle) * radius * _direction, sin(angle) * radius))

	if points.size() < 2:
		return

	draw_polyline(points, Color(0.2, 0.7, 1.0, 0.35 * fade), 8.0, true)
	draw_polyline(points, Color(0.55, 0.86, 1.0, 0.8 * fade), 4.0, true)
	draw_polyline(points, Color(1.0, 1.0, 1.0, fade), 1.5, true)

	if progress > 0.55:
		var tip_angle := angle_end
		var tip := Vector2(cos(tip_angle) * radius * _direction, sin(tip_angle) * radius)
		var spark_length := 5.0 * fade
		for offset in [-0.5, 0.0, 0.5]:
			var spark_angle: float = tip_angle + float(offset)
			var spark_end := tip + Vector2(
				cos(spark_angle) * spark_length * _direction,
				sin(spark_angle) * spark_length
			)
			draw_line(tip, spark_end, Color(0.85, 0.95, 1.0, fade), 1.2, true)
