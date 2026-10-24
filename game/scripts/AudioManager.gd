extends Node

const DIR := "res://assets/audio/"
const SFX_FILES := {
	"shoot": "filmcow/enemy.wav", "pshoot": "filmcow/player_1.wav",
	"boost_shoot": "filmcow/boost.wav", "jump": "sfx_jump.wav", "dash": "filmcow/dash.wav",
	"hurt": "filmcow/hurt.wav", "coin": "sfx_coin.wav", "parry": "filmcow/parry.wav",
	"super": "filmcow/super.wav", "ultra": "filmcow/ultra.wav", "tick": "sfx_tick.wav",
	"boom": "filmcow/boom.wav", "ko": "sfx_ko.wav", "warn": "sfx_warn.wav",
	"select": "sfx_select.wav", "confirm": "sfx_confirm.wav", "craft": "sfx_craft.wav",
	"pause": "sfx_pause.wav", "phase": "sfx_phase.wav", "pickup": "sfx_pickup.wav",
	"gameover": "sfx_gameover.wav",
	"player_hurt": "filmcow/player_hurt_1.wav",
	"player_death": "filmcow/player_death_5.wav",
	"elevator_open": "filmcow/elevator_open.wav", "victory": "sfx_victory.wav",
	"death_robot": "filmcow/death_robot.wav",
	"death_drone": "filmcow/death_drone.wav",
	"death_bat": "filmcow/death_bat.wav",
	"death_spore": "filmcow/death_spore.wav",
	"death_fireball": "filmcow/death_fireball.wav",
	"robot_shoot": "filmcow/robot_shoot.wav",
	"drone_shoot": "filmcow/drone_shoot.wav",
	"robot_charge": "filmcow/robot_charge.wav",
	"drone_charge": "filmcow/drone_charge.wav",
	"bat_flap": "filmcow/bat_flap.wav",
	"spore_land": "filmcow/spore_land.wav",
	"spore_roll": "filmcow/spore_roll.wav",
	"drone_move": "filmcow/drone_move_1.wav",
	"robot_step": "filmcow/robot_step_2.wav",
}

# Música más baja que los efectos: las pistas están normalizadas (-24 LUFS); las .wav antiguas son
# algo más fuertes y se compensan.
const MUSIC_DB := -7.5
const WAV_COMP_DB := -5.0
const SFX_DB := -3.0

var music: AudioStreamPlayer
var pool: Array = []
var cache := {}
var current := ""
var music_tween: Tween
var ducked := false
var shutting_down := false
var shutdown_complete := false
var quit_requested := false


func _exit_tree() -> void:
	_release_audio()


func _release_audio() -> void:
	if music_tween:
		music_tween.kill()
	# Release active playback before the audio server shuts down.
	for player in pool + [music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	cache.clear()
	current = ""


func shutdown() -> void:
	if shutting_down:
		while not shutdown_complete:
			await get_tree().process_frame
		return
	shutting_down = true
	_release_audio()
	# stop() queues a fade/removal on the audio thread. Tree teardown is too late
	# to drain it. Use wall time: --fixed-fps and hitstop change game-time timers.
	var drain_until := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < drain_until:
		await get_tree().process_frame
	shutdown_complete = true


func quit_game(code: int = 0) -> void:
	if quit_requested:
		return
	quit_requested = true
	get_tree().paused = true
	get_node("/root/Fx").reset()
	await shutdown()
	get_tree().quit(code)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	music = AudioStreamPlayer.new()
	music.bus = &"Music"
	music.volume_db = MUSIC_DB
	add_child(music)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		p.volume_db = SFX_DB
		add_child(p)
		pool.append(p)


# Separar movimiento impide que una multitud consuma las voces de muertes/alertas.
const MOVEMENT := ["robot_step", "bat_flap", "spore_roll", "drone_move"]
const ENTITY_DB := {"robot_step": -13.0, "bat_flap": -18.0, "spore_roll": -17.0,
	 "drone_move": -16.0, "spore_land": -8.0,
	"robot_shoot": -7.0, "drone_shoot": -7.0, "robot_charge": -2.0, "drone_charge": -2.0}
const VARIANTS := {
	"pshoot": ["player_1", "player_2"],
	"player_hurt": ["player_hurt_1", "player_hurt_2", "player_hurt_3"],
	"player_death": ["player_death_5", "player_death_6", "player_death_8", "player_death_9", "player_death_14"],
	"robot_step": ["robot_step_2", "robot_step_3", "robot_step_8", "robot_step_9"],
	"drone_move": ["drone_move_1", "drone_move_3", "drone_move_6"],
}
var variant_indices := {}


func _setup_buses() -> void:
	for bus_name in ["SFX", "Movement", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"SFX" if bus_name == "Movement" else &"Master")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_bus) == 0:
		var highpass := AudioEffectHighPassFilter.new()
		highpass.cutoff_hz = 65.0
		AudioServer.add_bus_effect(sfx_bus, highpass)
		var compressor := AudioEffectCompressor.new()
		compressor.threshold = -22.0
		compressor.ratio = 3.0
		compressor.attack_us = 2000.0
		compressor.release_ms = 120.0
		compressor.gain = 3.0
		AudioServer.add_bus_effect(sfx_bus, compressor)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -1.5
		limiter.pre_gain_db = 0.0
		limiter.release = 0.12
		AudioServer.add_bus_effect(0, limiter)


# Se omiten entidades fuera de cámara y se atenúan las lejanas al jugador.
func entity_sfx(event: String, at: Vector2) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var attenuation := 0.0
	if player:
		var left: Variant = player.get_parent().get("view_left")
		var view_left := float(left) if left != null else 0.0
		if at.x < view_left - 24.0 or at.x > view_left + Cfg.W + 24.0:
			return
		attenuation = -clampf(player.global_position.distance_to(at) / 35.0, 0.0, 10.0)
	sfx(event, attenuation + float(ENTITY_DB.get(event, 0.0)), randf_range(0.96, 1.04))


func _load(file: String) -> AudioStream:
	if cache.has(file):
		return cache[file]
	var path := DIR + file
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	if s == null:
		push_warning("Audio no encontrado: " + path)
	cache[file] = s
	return s


# Ataques y alertas (jefes, enemigos, avisos) suenan más bajo que el resto de efectos.
const ATTACK_DB := {"shoot": -7.0, "warn": -9.0, "phase": -7.0, "boom": -6.0, "select": -6.0, "tick": -3.0, "boost_shoot": -15.0, "pshoot": -5.0, "coin": -7.0}
# Los disparos conservan su cadencia de juego; sólo se limita su representación sonora.
const REPEAT_GAP_MS := {"player_fire": 120, "coin": 180}
const REPEAT_VOICES := {"player_fire": 2, "coin": 1}
const MIN_GAP_MS := 40
var last_ms := {}


func sfx(name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if shutting_down:
		return
	var key := name
	if not SFX_FILES.has(key):
		return
	var now := Time.get_ticks_msec()
	var repeat_group := "player_fire" if name in ["pshoot", "boost_shoot"] else ("coin" if name == "coin" else "")
	var timing_key := repeat_group if repeat_group != "" else name
	var gap := int(REPEAT_GAP_MS.get(repeat_group, 120 if name in MOVEMENT else MIN_GAP_MS))
	if now - int(last_ms.get(timing_key, -1000)) < gap:
		return   # evita apilar el mismo sonido decenas de veces (ráfagas de balas)
	if repeat_group != "":
		var voices := 0
		for p in pool:
			if p.playing and p.get_meta("repeat_group", "") == repeat_group:
				voices += 1
		if voices >= int(REPEAT_VOICES[repeat_group]):
			return
	vol += float(ATTACK_DB.get(name, 0.0))
	var file: String = SFX_FILES[key]
	if VARIANTS.has(key):
		var variants: Array = VARIANTS[key]
		var index := int(variant_indices.get(key, 0))
		file = "filmcow/%s.wav" % variants[index % variants.size()]
		variant_indices[key] = index + 1
	var s := _load(file)
	if s == null:
		return
	var movement := name in MOVEMENT
	var chosen: AudioStreamPlayer = null
	# Cuatro voces de movimiento; doce de combate. Muertes y avisos pueden
	# reemplazar la voz de combate más antigua cuando hay una ráfaga masiva.
	for i in range(12, 16) if movement else range(0, 12):
		if not pool[i].playing:
			chosen = pool[i]
			break
	if chosen == null and (name.begins_with("death_") or name in ["hurt", "player_hurt", "player_death", "elevator_open", "warn", "parry", "gameover"]):
		for i in 12:
			if chosen == null or int(pool[i].get_meta("started", 0)) < int(chosen.get_meta("started", 0)):
				chosen = pool[i]
	if chosen == null:
		return
	last_ms[timing_key] = now
	chosen.stop()
	chosen.bus = &"Movement" if movement else &"SFX"
	chosen.stream = s
	chosen.volume_db = SFX_DB + vol
	chosen.pitch_scale = pitch
	chosen.set_meta("repeat_group", repeat_group)
	chosen.set_meta("started", now)
	chosen.play()


func play_music(name: String) -> void:
	if shutting_down:
		return
	if name == current and music.playing:
		return
	current = name
	# El lobby (menú, login y taller) suena con "Containment Lockdown".
	var file := ("containment" if name == "menu" else name)
	var is_ogg := ResourceLoader.exists(DIR + "music_%s.ogg" % file)
	var s := _load("music_%s.ogg" % file) if is_ogg else _load("music_%s.wav" % file)
	if s == null:
		return
	# Las pistas .ogg ya vienen preparadas para repetirse sin corte (el final se funde con el inicio).
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
		(s as AudioStreamOggVorbis).loop_offset = 0.0
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	if music_tween:
		music_tween.kill()
	music.stream = s
	music.volume_db = _music_db()
	music.play()


func _music_db() -> float:
	var base := MUSIC_DB + (WAV_COMP_DB if music.stream is AudioStreamWAV else 0.0)
	return base - (9.0 if ducked else 0.0)


func stop_music(fade: float = 0.4) -> void:
	current = ""
	if not music.playing:
		return
	if music_tween:
		music_tween.kill()
	music_tween = create_tween()
	music_tween.tween_property(music, "volume_db", -60.0, fade)
	music_tween.tween_callback(music.stop)


func duck(on: bool) -> void:
	ducked = on
	music.volume_db = _music_db()
