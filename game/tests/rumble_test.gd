extends SceneTree

# Simulate discovery/focus, but exercise Godot's real vibration request API.
class TestFx extends "res://scripts/Fx.gd":
	var pads: Array[int] = [7, 9]
	var focused := true

	func _connected_pads() -> Array[int]:
		return pads

	func _has_focus() -> bool:
		return focused

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
	Input.set_ignore_joypad_on_unfocused_application(false)
	var gm = root.get_node("GameManager")
	var fx := TestFx.new()
	root.add_child(fx)
	fx.set_process(false)
	gm.active_pad = 9
	fx.shot_rumble()
	check(Input.get_joy_vibration_strength(9).is_equal_approx(Vector2(0.18, 0.04)) and is_equal_approx(Input.get_joy_vibration_duration(9), 0.035), "Shot produces a short light recoil pulse")
	check(fx.shake_t == 0.0, "Shooting does not shake the camera")
	fx._process(0.04)
	check(Input.get_joy_vibration_strength(9) == Vector2.ZERO, "Shot pulse ends before the next normal shot")
	fx.shot_rumble()
	fx.shake(3.0, 0.25)
	check(fx.shot_rumble_t == 0.0, "Damage cancels ongoing recoil")
	for i in 5:
		fx.shot_rumble()
	check(Input.get_joy_vibration_strength(9).is_equal_approx(Vector2(0.35, 0.5)) and is_equal_approx(Input.get_joy_vibration_duration(9), 0.25), "Continuous fire cannot overwrite or shorten damage vibration")
	check(fx.rumble_pad == 9 and Input.get_joy_vibration_strength(9).is_equal_approx(Vector2(0.35, 0.5)), "Damage vibrates the active controller proportionally")
	check(is_equal_approx(Input.get_joy_vibration_duration(9), 0.25), "Rumble shares the shake duration")
	fx.shake(1.0, 0.1)
	check(Input.get_joy_vibration_strength(9).is_equal_approx(Vector2(0.35, 0.5)) and is_equal_approx(Input.get_joy_vibration_duration(9), 0.25), "Weaker overlapping impact does not shorten or weaken feedback")
	fx.shake(20.0, 0.5)
	check(Input.get_joy_vibration_strength(9).is_equal_approx(Vector2(0.7, 1.0)), "Large shakes clamp motor strengths")
	fx.reset()
	check(Input.get_joy_vibration_strength(9) == Vector2.ZERO and fx.rumble_pad == -1, "Reset stops the motors")
	fx.shot_rumble()
	check(fx.shot_rumble_t > 0.0, "Fresh shots resume after impact feedback ends")
	fx.reset()
	gm.active_pad = -1
	fx.shake(2.0, 0.2)
	check(fx.rumble_pad == 7, "Connected controller is used when desktop owns input")
	gm.active_pad = 9
	fx.shake(2.0, 0.2)
	check(fx.rumble_pad == 9 and Input.get_joy_vibration_strength(7) == Vector2.ZERO, "Changing controllers stops the previous motors")
	fx._process(0.3)
	check(Input.get_joy_vibration_strength(9) == Vector2.ZERO, "Shake expiration stops rumble")
	fx.shake(3.0, 0.2)
	paused = true
	fx._process(0.01)
	check(fx.rumble_pad == -1, "Pause stops rumble")
	paused = false
	fx.reset()
	fx.shake(3.0, 0.2)
	fx.focused = false
	fx._process(0.01)
	check(fx.rumble_pad == -1, "Focus loss stops rumble")
	fx.reset()
	fx.shake(3.0, 0.2)
	check(fx.rumble_pad == -1, "Unfocused window cannot start rumble")
	fx.focused = true
	fx.shake(3.0, 0.2)
	fx.pads.clear()
	fx._process(0.01)
	check(fx.rumble_pad == -1, "Disconnection clears rumble")
	fx.reset()
	fx.shake(3.0, 0.2)
	check(fx.shake_t > 0.0 and fx.rumble_pad == -1, "Screenshake works without controllers")
	fx.reset()
	fx.pads.assign([7])
	fx.shake(0.0, 0.2)
	fx.shake(3.0, 0.0)
	check(fx.shake_t == 0.0 and fx.rumble_pad == -1, "Empty effects never start indefinite vibration")
	var container := Node2D.new()
	root.add_child(container)
	var before := fx.live_bursts
	fx.burst(container, Vector2.ZERO, Color.WHITE)
	check(fx.live_bursts == before + 1, "Particle burst uses one budget slot")
	container.free()
	check(fx.live_bursts == before, "Removing unfinished particles restores their budget")
	container = Node2D.new()
	root.add_child(container)
	fx.burst(container, Vector2.ZERO, Color.WHITE, 2, 10.0, 0.05)
	await create_timer(0.4).timeout
	check(fx.live_bursts == before and container.get_child_count() == 0, "Finished particles free themselves and restore their budget")
	container.free()
	fx.shake(3.0, 0.2)
	fx.free()
	check(Input.get_joy_vibration_strength(7) == Vector2.ZERO, "Teardown stops rumble")
	gm.active_pad = -1
	print("RUMBLE TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
