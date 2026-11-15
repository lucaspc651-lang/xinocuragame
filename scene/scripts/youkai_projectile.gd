extends Area2D

const SPEED = 150.0
const LIFE_TIME = 3.0

var _direction = Vector2.RIGHT
var _time_left = LIFE_TIME


func set_direction(direction: Vector2) -> void:
	_direction = direction.normalized()


func _physics_process(delta: float) -> void:
	global_position += _direction * SPEED * delta
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()
