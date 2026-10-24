extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		quit(1)
		return
	root.get_node("Database").start_offline()
	var fx = root.get_node("Fx")
	var gm = root.get_node("GameManager")
	gm.reset_run()
	var level = load("res://scripts/Level.gd").new()
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.boss.set_physics_process(false)
	level.boss._enter_fight()
	# Effects use world coordinates even under a translated level.
	var container := Node2D.new()
	container.position = Vector2(75, 12)
	level.add_child(container)
	for key in fx.EFFECTS:
		var effect = fx.impact(container, Vector2(150, 100), key)
		check(effect.global_position == Vector2(150, 100), key + ": world placement")
		check(not effect.sprite_frames.get_animation_loop("default"), key + ": one-shot animation")
		for i in effect.sprite_frames.get_frame_count("default"):
			var atlas = effect.sprite_frames.get_frame_texture("default", i)
			check(Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region), key + ": frame %d stays inside the sheet" % i)
	await create_timer(0.8).timeout
	check(get_nodes_in_group("sprite_effect").is_empty(), "Finished animations release their nodes")
	var enemy = load("res://scripts/Enemy.gd").new()
	enemy.kind = "robot"
	enemy.age = 1.0
	level.add_child(enemy)
	enemy.take_damage(100.0)
	await process_frame
	check(not is_instance_valid(enemy) and not get_nodes_in_group("sprite_effect").is_empty(), "Enemy explosion survives deletion of its owner")
	level.player.invuln = 0.0
	level.player.hurt()
	var after_hit := get_nodes_in_group("sprite_effect").size()
	level.player.hurt()
	check(get_nodes_in_group("sprite_effect").size() == after_hit, "Invulnerability rejects duplicate player hit effects")
	fx.reset()
	level.boss._die()
	var after_death := get_nodes_in_group("sprite_effect").size()
	level.boss._die()
	check(get_nodes_in_group("sprite_effect").size() == after_death, "Boss death starts only once")
	fx.reset()
	level.boss.st_t = 2.5
	level.boss._physics_process(0.2)
	check(not level.boss.is_queued_for_deletion() and level.boss.modulate.a == 1.0, "Boss stays opaque while final explosion begins")
	level.boss._physics_process(0.26)
	check(level.boss.is_queued_for_deletion(), "Boss pops out halfway through final explosion")
	check(get_nodes_in_group("sprite_effect").any(func(n): return n.sprite_frames == fx.effect_frames.finale), "Final explosion exists before the KO transition")
	level.queue_free()
	await process_frame
	check(get_nodes_in_group("sprite_effect").is_empty(), "Level teardown removes ongoing effects")
	var main = load("res://scripts/Main.gd").new()
	root.add_child(main)
	await create_timer(0.4).timeout
	var credit_button = main.credits_btn
	check(credit_button.get_global_rect().end.y <= 270.0, "Credits button fits viewport")
	main._show_credits()
	await process_frame
	check(main.credits_layer.visible, "Credits open from menu")
	var texts: Array = main.credits_layer.find_children("*", "RichTextLabel", true, false)
	var credit_text: RichTextLabel = texts[0]
	check(credit_text.text.contains("pimen") and credit_text.text.contains("CC BY 4.0") and credit_text.text.contains("Aim studios") and credit_text.text.contains("Kenney"), "Credits include effect and exit creators and licenses")
	main.queue_free()
	await process_frame
	print("COMBAT EFFECT TESTS: ", failures, " failures")
	quit(1 if failures else 0)
