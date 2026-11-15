extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D

const FRAME_SIZE = 128
const MOVE_SPEED = 28.0
const MAX_HEALTH = 3
const ATTACK_DISTANCE = 27.0
const ATTACK_COOLDOWN = 1.1
const HURT_TIME = 0.3
const GRAVITY = 900.0
const FLOOR_COLLISION_MASK = 1
const EDGE_CHECK_FORWARD = 10.0
const EDGE_CHECK_DOWN = 40.0
const MAX_CHASE_HEIGHT_DIFFERENCE = 48.0
const PATROL_SPEED = 16.0
const RANGED_ATTACK_DISTANCE = 150.0
const RANGED_KEEP_DISTANCE = 90.0
const PROJECTILE_SCENE = preload("res://entities/youkai_projectile.tscn")
const FLOATING_DAMAGE_SCENE = preload("res://entities/floating_damage.tscn")

var yokai_name = "Gotoku"
var _player: CharacterBody2D
var _health = MAX_HEALTH
var _attack_cooldown_left = 0.0
var _hurt_time_left = 0.0
var _is_attacking = false
var _is_hurt = false
var _is_dead = false
var _is_ranged = false
var _projectile_fired = false
var _patrol_direction = 1.0
var _is_placing = true


func _ready() -> void:
	_build_animations()
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.frame_changed.connect(_on_animation_frame_changed)
	_patrol_direction = -1.0 if randf() < 0.5 else 1.0
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	body_collision.set_deferred("disabled", true)
	_snap_to_ground.call_deferred()


func _snap_to_ground() -> void:
	await get_tree().physics_frame
	var from := Vector2(global_position.x, -1024.0)
	var to := Vector2(global_position.x, 2048.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, FLOOR_COLLISION_MASK)
	query.exclude = [get_rid()]
	var floor_hit := get_world_2d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty():
		body_collision.set_deferred("disabled", false)
		_is_placing = false
		return

	var floor_position: Vector2 = floor_hit["position"]
	var body_shape: CapsuleShape2D = body_collision.shape as CapsuleShape2D
	var foot_offset: float = body_collision.position.y + body_shape.height / 2.0
	global_position.y = floor_position.y - foot_offset - 32.0
	velocity = Vector2.ZERO
	body_collision.set_deferred("disabled", false)
	_is_placing = false


func set_player(player: CharacterBody2D) -> void:
	_player = player


func set_youkai_type(type_name: String) -> void:
	yokai_name = type_name


func set_ranged(ranged: bool) -> void:
	_is_ranged = ranged


func _physics_process(delta: float) -> void:
	if _is_dead or _is_placing:
		return

	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_hurt_time_left = maxf(_hurt_time_left - delta, 0.0)
	if _is_hurt and _hurt_time_left == 0.0:
		_is_hurt = false

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if _player != null and _player.has_method("is_alive") and not bool(_player.call("is_alive")):
		_player = null

	var horizontal_distance := 0.0
	if _player != null and not _player.is_queued_for_deletion():
		horizontal_distance = _player.global_position.x - global_position.x

	if horizontal_distance != 0.0:
		var facing_left := horizontal_distance < 0.0
		sprite.flip_h = facing_left
		attack_area.position.x = -6.0 if facing_left else 12.0

	if _is_hurt:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 3.0 * delta)
		_play("hurt")
	elif _is_attacking:
		velocity.x = 0.0
	elif _is_ranged and _can_reach_player():
		if absf(horizontal_distance) <= RANGED_ATTACK_DISTANCE:
			if absf(horizontal_distance) < RANGED_KEEP_DISTANCE:
				var retreat_direction := -signf(horizontal_distance)
				if _has_floor_ahead(retreat_direction):
					velocity.x = retreat_direction * PATROL_SPEED
					_play("walk")
				else:
					velocity.x = 0.0
					_play("idle")
			else:
				velocity.x = 0.0
				if _attack_cooldown_left == 0.0:
					_start_attack()
				else:
					_play("idle")
		else:
			var chase_direction := signf(horizontal_distance)
			if _has_floor_ahead(chase_direction):
				velocity.x = chase_direction * MOVE_SPEED
				_play("walk")
			else:
				_patrol()
	elif _can_reach_player() and absf(horizontal_distance) <= ATTACK_DISTANCE:
		velocity.x = 0.0
		if _attack_cooldown_left == 0.0:
			_start_attack()
		else:
			_play("idle")
	elif _can_reach_player():
		var chase_direction := signf(horizontal_distance)
		if _has_floor_ahead(chase_direction):
			velocity.x = chase_direction * MOVE_SPEED
			_play("walk")
		else:
			_patrol()
	else:
		_patrol()

	move_and_slide()


func _has_floor_ahead(direction: float) -> bool:
	if direction == 0.0:
		return true

	var probe_start := global_position + Vector2(direction * EDGE_CHECK_FORWARD, 10.0)
	var probe_end := probe_start + Vector2(0.0, EDGE_CHECK_DOWN)
	var query := PhysicsRayQueryParameters2D.create(
		probe_start,
		probe_end,
		FLOOR_COLLISION_MASK
	)
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _can_reach_player() -> bool:
	if _player == null:
		return false
	if absf(_player.global_position.y - global_position.y) > MAX_CHASE_HEIGHT_DIFFERENCE:
		return false

	var from := global_position + Vector2(0.0, -8.0)
	var to := _player.global_position + Vector2(0.0, -8.0)
	var query := PhysicsRayQueryParameters2D.create(from, to, FLOOR_COLLISION_MASK)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == _player


func _patrol() -> void:
	if is_on_wall() or not _has_floor_ahead(_patrol_direction):
		_patrol_direction *= -1.0

	if _has_floor_ahead(_patrol_direction):
		velocity.x = _patrol_direction * PATROL_SPEED
		_play("walk")
	else:
		velocity.x = 0.0
		_play("idle")


func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return

	var damage_number := FLOATING_DAMAGE_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(damage_number)
	damage_number.global_position = global_position
	damage_number.call("show_damage", amount)
	_health = maxi(_health - amount, 0)
	attack_area.monitoring = false
	attack_shape.set_deferred("disabled", true)
	_is_attacking = false

	if _health == 0:
		_is_dead = true
		velocity = Vector2.ZERO
		body_collision.set_deferred("disabled", true)
		sprite.play("dead")
	else:
		_is_hurt = true
		_hurt_time_left = HURT_TIME
		sprite.play("hurt")


func _start_attack() -> void:
	_is_attacking = true
	_projectile_fired = false
	_attack_cooldown_left = ATTACK_COOLDOWN
	attack_area.monitoring = false
	attack_shape.set_deferred("disabled", true)
	sprite.frame = 0
	sprite.play("attack")


func _shoot_at_player() -> void:
	if _player == null or not is_instance_valid(_player) or _player.is_queued_for_deletion():
		return

	var projectile: Area2D = PROJECTILE_SCENE.instantiate() as Area2D
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + Vector2(-12.0 if sprite.flip_h else 12.0, -8.0)
	projectile.call("set_direction", _player.global_position - projectile.global_position)


func _play(animation_name: StringName) -> void:
	if sprite.animation != animation_name:
		sprite.play(animation_name)


func _build_animations() -> void:
	var frames := SpriteFrames.new()
	_add_animation(frames, "idle", "Idle.png", 7.0, true)
	_add_animation(frames, "walk", "Walk.png", 10.0, true)
	_add_animation(frames, "attack", "Attack_1.png", 12.0, false)
	_add_animation(frames, "hurt", "Hurt.png", 10.0, false)
	_add_animation(frames, "dead", "Dead.png", 8.0, false)
	sprite.sprite_frames = frames
	sprite.animation = &"idle"
	sprite.play()


func _add_animation(
	frames: SpriteFrames,
	animation_name: StringName,
	file_name: String,
	frames_per_second: float,
	loops: bool
) -> void:
	var sheet := load("res://sprites/npcs/" + yokai_name + "/" + file_name) as Texture2D
	if sheet == null:
		push_error("Não foi possível carregar o sprite de " + yokai_name + ": " + file_name)
		return

	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, frames_per_second)
	frames.set_animation_loop(animation_name, loops)
	for frame_index in range(int(sheet.get_width() / float(FRAME_SIZE))):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = sheet
		frame_texture.region = Rect2(frame_index * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(animation_name, frame_texture)


func _on_animation_frame_changed() -> void:
	if not _is_attacking:
		return

	if _is_ranged:
		if sprite.frame >= 2 and not _projectile_fired:
			_projectile_fired = true
			_shoot_at_player()
		return

	if sprite.frame == 1:
		attack_shape.set_deferred("disabled", false)
		attack_area.monitoring = true
	elif sprite.frame >= 3:
		attack_area.monitoring = false
		attack_shape.set_deferred("disabled", true)


func _on_animation_finished() -> void:
	if sprite.animation == "attack":
		_is_attacking = false
		attack_area.monitoring = false
		attack_shape.set_deferred("disabled", true)
	elif sprite.animation == "hurt" and not _is_dead:
		_is_hurt = false
	elif sprite.animation == "dead":
		queue_free()


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
