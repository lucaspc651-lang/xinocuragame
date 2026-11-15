extends CharacterBody2D

signal health_changed(current_health: int, maximum_health: int)

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const WALK_SPEED = 30.0
const RUN_SPEED = 75.0
const CROUCH_SPEED = 18.0
const JUMP_VELOCITY = -250.0
const DASH_SPEED = 175.0
const DASH_COOLDOWN = 0.45
const CROUCH_HEIGHT = 18.0
const MAX_HEALTH = 5
const DAMAGE_INVULNERABILITY = 0.8
const HURT_LOCK_TIME = 0.35
const ATTACK_COOLDOWN = 0.35
const VOID_DEATH_Y = 260.0
const ATTACKS = ["attack_1", "attack_2", "attack_3"]
const COMBAT_EFFECT = preload("res://entities/combat_effect.tscn")
const SWORD_SLASH = preload("res://entities/sword_slash.tscn")

var _standing_shape: CapsuleShape2D
var _standing_height = 0.0
var _standing_bottom = 0.0
var _spawn_position: Vector2 = Vector2.ZERO
var _crouch_height = CROUCH_HEIGHT
var _is_crouching = false
var _is_dashing = false
var _is_attacking = false
var _is_hurt = false
var _is_dead = false
var _attack_hit_applied = false
var _health = MAX_HEALTH
var _current_attack = "attack_1"
var _dash_cooldown_left = 0.0
var _attack_cooldown_left = 0.0
var _invulnerability_left = 0.0
var _hurt_lock_left = 0.0
var _jumps_left = 2
var _dash_direction = 1.0
var _facing_direction = 1.0


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	animation.sprite_frames = animation.sprite_frames.duplicate()
	_add_attack_animation()
	_set_animation_speeds()
	animation.animation_finished.connect(_on_animation_finished)
	animation.frame_changed.connect(_on_animation_frame_changed)

	var capsule := collision_shape.shape as CapsuleShape2D
	if capsule == null:
		push_error("O CollisionShape2D do player precisa usar um CapsuleShape2D.")
		set_physics_process(false)
		return

	_standing_shape = capsule.duplicate() as CapsuleShape2D
	collision_shape.shape = _standing_shape
	_standing_height = _standing_shape.height
	_standing_bottom = collision_shape.position.y + _standing_height / 2.0
	_crouch_height = minf(CROUCH_HEIGHT, _standing_height)
	_facing_direction = -1.0 if animation.flip_h else 1.0
	health_changed.emit(_health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_invulnerability_left = maxf(_invulnerability_left - delta, 0.0)
	_hurt_lock_left = maxf(_hurt_lock_left - delta, 0.0)
	if _is_hurt and _hurt_lock_left == 0.0:
		_is_hurt = false

	if _is_dashing and not animation.is_playing():
		_end_dash()

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction != 0.0 and not _is_attacking and not _is_hurt:
		_facing_direction = signf(direction)
		animation.flip_h = _facing_direction < 0.0

	if not _is_dashing and not _is_attacking and not _is_hurt:
		var wants_to_crouch := Input.is_action_pressed("agachar") and is_on_floor()
		if wants_to_crouch and not _is_crouching:
			_set_crouching(true)
		elif _is_crouching and not wants_to_crouch and _can_stand_up():
			_set_crouching(false)

		var can_dash := Input.is_action_just_pressed("dash")
		can_dash = can_dash and _dash_cooldown_left == 0.0 and not _is_crouching
		if can_dash:
			_start_dash(direction)

		var can_attack := Input.is_action_just_pressed("attack")
		can_attack = can_attack and _attack_cooldown_left == 0.0
		can_attack = can_attack and not _is_dashing and not _is_crouching
		if can_attack:
			_start_attack()

	if _is_dashing:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity += get_gravity() * delta

	var current_speed := WALK_SPEED
	if Input.is_action_pressed("correr"):
		current_speed = RUN_SPEED

	if is_on_floor():
		_jumps_left = 2

	var can_jump := not _is_dashing and not _is_hurt and not _is_crouching
	can_jump = can_jump and Input.is_action_just_pressed("ui_accept") and _jumps_left > 0
	if can_jump:
		var is_double_jump: bool = _jumps_left == 1
		velocity.y = JUMP_VELOCITY if _jumps_left == 2 else JUMP_VELOCITY * 0.9
		_jumps_left -= 1
		if is_double_jump:
			_play_double_jump_effect()

	if _is_dashing:
		velocity.x = _dash_direction * DASH_SPEED
	elif _is_attacking or _is_hurt:
		velocity.x = 0.0
	elif _is_crouching:
		velocity.x = direction * CROUCH_SPEED
	else:
		if direction != 0.0:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0.0, current_speed)

	move_and_slide()

	if global_position.y > VOID_DEATH_Y:
		_health = 0
		health_changed.emit(_health, MAX_HEALTH)
		_die()
		return

	if is_on_floor():
		_jumps_left = 2

	_update_animation(direction)


func _start_dash(direction: float) -> void:
	_dash_direction = signf(direction) if direction != 0.0 else _facing_direction
	_is_dashing = true
	_dash_cooldown_left = DASH_COOLDOWN
	animation.frame = 0
	animation.play("dash")


func _start_attack() -> void:
	_is_attacking = true
	_attack_hit_applied = false
	_attack_cooldown_left = ATTACK_COOLDOWN
	_current_attack = ATTACKS[randi_range(0, ATTACKS.size() - 1)]
	animation.frame = 0
	animation.play(_current_attack)


func _end_dash() -> void:
	_is_dashing = false
	velocity.x = 0.0


func take_damage(amount: int = 1) -> void:
	if _is_dead or _invulnerability_left > 0.0:
		return

	_health = maxi(_health - amount, 0)
	health_changed.emit(_health, MAX_HEALTH)
	_invulnerability_left = DAMAGE_INVULNERABILITY
	_is_attacking = false
	_is_dashing = false
	_is_crouching = false
	_set_crouching(false)
	velocity.x = 0.0

	if _health == 0:
		_die()
	else:
		_is_hurt = true
		_hurt_lock_left = HURT_LOCK_TIME
		animation.play("hurt")


func _die() -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_hurt = false
	_is_attacking = false
	_is_dashing = false
	velocity = Vector2.ZERO
	collision_shape.set_deferred("disabled", true)
	animation.play("dead")


func get_max_health() -> int:
	return MAX_HEALTH


func is_alive() -> bool:
	return not _is_dead


func _set_crouching(crouching: bool) -> void:
	_is_crouching = crouching
	if crouching:
		var crouch_shape := _standing_shape.duplicate() as CapsuleShape2D
		crouch_shape.height = _crouch_height
		collision_shape.shape = crouch_shape
		collision_shape.position.y = _standing_bottom - _crouch_height / 2.0
	else:
		collision_shape.shape = _standing_shape
		collision_shape.position.y = _standing_bottom - _standing_height / 2.0


func _can_stand_up() -> bool:
	var space_to_stand: float = _standing_height - _crouch_height
	return not test_move(global_transform, Vector2.UP * space_to_stand)


func _update_animation(direction: float) -> void:
	if _is_dashing or _is_attacking or _is_hurt or _is_dead:
		return

	if _is_crouching:
		if animation.animation != "crouch":
			animation.play("crouch")
	elif not is_on_floor():
		_play_animation("jump")
	elif direction != 0.0:
		if Input.is_action_pressed("correr"):
			_play_animation("run")
		else:
			_play_animation("walk")
	else:
		_play_animation("idle")


func _play_animation(animation_name: StringName) -> void:
	if animation.animation != animation_name:
		animation.play(animation_name)


func _add_attack_animation() -> void:
	var sprite_frames := animation.sprite_frames
	_add_attack_frames(sprite_frames, "attack_1", "Attack_1.png")
	_add_attack_frames(sprite_frames, "attack_2", "Attack_2.png")
	_add_attack_frames(sprite_frames, "attack_3", "Attack_3.png")

	sprite_frames.set_animation_loop("hurt", false)
	sprite_frames.set_animation_loop("dead", false)
	_set_attack_timing(sprite_frames, "attack_1", [1.2, 1.2, 0.7, 0.7, 1.0, 1.4])
	_set_attack_timing(sprite_frames, "attack_2", [1.3, 0.7, 0.8, 1.4])
	_set_attack_timing(sprite_frames, "attack_3", [1.2, 0.7, 1.4])


func _set_attack_timing(sprite_frames: SpriteFrames, animation_name: String, timings: Array) -> void:
	for frame_index in range(mini(sprite_frames.get_frame_count(animation_name), timings.size())):
		var frame_texture := sprite_frames.get_frame_texture(animation_name, frame_index)
		sprite_frames.remove_frame(animation_name, frame_index)
		sprite_frames.add_frame(animation_name, frame_texture, float(timings[frame_index]), frame_index)


func _set_animation_speeds() -> void:
	var sprite_frames := animation.sprite_frames
	sprite_frames.set_animation_speed("idle", 7.0)
	sprite_frames.set_animation_speed("walk", 10.0)
	sprite_frames.set_animation_speed("run", 12.0)
	sprite_frames.set_animation_speed("jump", 14.0)
	sprite_frames.set_animation_speed("crouch", 10.0)
	sprite_frames.set_animation_speed("hurt", 10.0)
	sprite_frames.set_animation_speed("dead", 8.0)


func _add_attack_frames(sprite_frames: SpriteFrames, animation_name: String, file_name: String) -> void:
	if sprite_frames.has_animation(animation_name):
		return

	var attack_sheet := load("res://sprites/players/Samurai/" + file_name) as Texture2D
	if attack_sheet == null:
		push_error("Não foi possível carregar o sprite de ataque: " + file_name)
		return

	sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, 12.0)
	sprite_frames.set_animation_loop(animation_name, false)
	for frame_index in range(int(attack_sheet.get_width() / 128.0)):
		var frame_texture := AtlasTexture.new()
		frame_texture.atlas = attack_sheet
		frame_texture.region = Rect2(frame_index * 128, 0, 128, 128)
		sprite_frames.add_frame(animation_name, frame_texture)


func _on_animation_frame_changed() -> void:
	if not _is_attacking:
		return
	if _attack_hit_applied:
		return
	if not str(animation.animation).begins_with("attack_"):
		return
	if animation.frame < _attack_frame_first() or animation.frame > _attack_frame_last():
		return

	_attack_hit_applied = true
	var slash := SWORD_SLASH.instantiate() as Node2D
	get_tree().current_scene.add_child(slash)
	slash.call(
		"play_once",
		global_position + Vector2(_facing_direction * 20.0, -8.0),
		_facing_direction
	)
	var attack_shape := RectangleShape2D.new()
	attack_shape.size = Vector2(40.0, 30.0)
	var attack_position := global_position + Vector2(_facing_direction * 24.0, -6.0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = attack_shape
	query.transform = Transform2D(0.0, attack_position)
	query.collision_mask = 4
	query.exclude = [get_rid()]

	for hit in get_world_2d().direct_space_state.intersect_shape(query, 16):
		var target: Object = hit.get("collider")
		if target is Node2D and target.has_method("take_damage"):
			target.call("take_damage", 1)


func _play_double_jump_effect() -> void:
	var frames: Array[Texture2D] = [
		preload("res://scene/effects/PNG/Explosion_7/4/Explosion_3_1.png"),
		preload("res://scene/effects/PNG/Explosion_7/4/Explosion_3_2.png"),
		preload("res://scene/effects/PNG/Explosion_7/4/Explosion_3_3.png"),
		preload("res://scene/effects/PNG/Explosion_7/4/Explosion_3_4.png"),
	]
	_play_effect(frames, 18.0, Vector2(0.15, 0.15), global_position + Vector2(0.0, 2.0))


func _play_effect(
	frames: Array[Texture2D],
	frames_per_second: float,
	effect_scale: Vector2,
	world_position: Vector2
) -> void:
	var effect := COMBAT_EFFECT.instantiate() as AnimatedSprite2D
	get_tree().current_scene.add_child(effect)
	effect.call("play_once", frames, frames_per_second, effect_scale, world_position)


func _attack_frame_first() -> int:
	return 2 if _current_attack == "attack_1" else 1


func _attack_frame_last() -> int:
	if _current_attack == "attack_1":
		return 4
	return animation.sprite_frames.get_frame_count(_current_attack) - 1


func _on_animation_finished() -> void:
	if str(animation.animation).begins_with("attack_"):
		_is_attacking = false
	elif animation.animation == "hurt" and _hurt_lock_left == 0.0:
		_is_hurt = false
	elif animation.animation == "dead" and _is_dead:
		_respawn()


func _respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO
	_health = MAX_HEALTH
	_jumps_left = 2
	_is_dead = false
	_is_hurt = false
	_is_attacking = false
	_is_dashing = false
	_is_crouching = false
	_attack_hit_applied = false
	_invulnerability_left = 1.5
	_hurt_lock_left = 0.0
	collision_shape.set_deferred("disabled", false)
	_set_crouching(false)
	animation.play("idle")
	health_changed.emit(_health, MAX_HEALTH)
