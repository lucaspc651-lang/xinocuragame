extends AnimatedSprite2D


func play_once(
	frames: Array[Texture2D],
	frames_per_second: float,
	effect_scale: Vector2,
	world_position: Vector2
) -> void:
	var effect_frames := SpriteFrames.new()
	effect_frames.add_animation("effect")
	effect_frames.set_animation_speed("effect", frames_per_second)
	effect_frames.set_animation_loop("effect", false)

	for frame_texture in frames:
		effect_frames.add_frame("effect", frame_texture)

	sprite_frames = effect_frames
	scale = effect_scale
	global_position = world_position
	z_index = 2
	animation_finished.connect(queue_free)
	play("effect")
