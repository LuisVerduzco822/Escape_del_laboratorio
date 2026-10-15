extends RefCounted

static func build_four_dir_frames(idle_tex: Texture2D, run_tex: Texture2D,
		frame_w: int = 16, frame_h: int = 32, frames_per_dir: int = 6,
		idle_fps: float = 6.0, run_fps: float = 12.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var directions := ["down", "up", "left", "right"]
	_add(frames, "idle", idle_tex, directions, frames_per_dir, idle_fps, frame_w, frame_h)
	_add(frames, "run", run_tex, directions, frames_per_dir, run_fps, frame_w, frame_h)
	return frames


static func _add(frames: SpriteFrames, prefix: String, tex: Texture2D, directions: Array,
		frames_per_dir: int, fps: float, fw: int, fh: int) -> void:
	for i in directions.size():
		var anim_name := "%s_%s" % [prefix, directions[i]]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, true)
		for f in range(frames_per_dir):
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2((i * frames_per_dir + f) * fw, 0, fw, fh)
			frames.add_frame(anim_name, atlas)
