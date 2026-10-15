extends Node

const DIR := "res://assets/audio/"
const SFX_FILES := {
	"shoot": "sfx_shoot.wav", "jump": "sfx_jump.wav", "dash": "sfx_dash.wav",
	"hurt": "sfx_hit.wav", "coin": "sfx_coin.wav", "parry": "sfx_parry.wav",
	"super": "sfx_super.wav", "ultra": "sfx_ultra.wav", "tick": "sfx_tick.wav",
	"boom": "sfx_boom.wav", "ko": "sfx_ko.wav", "warn": "sfx_warn.wav",
	"select": "sfx_select.wav", "confirm": "sfx_confirm.wav", "craft": "sfx_craft.wav",
	"pause": "sfx_pause.wav", "phase": "sfx_phase.wav", "pickup": "sfx_pickup.wav",
	"gameover": "sfx_gameover.wav", "victory": "sfx_victory.wav",
}

var music: AudioStreamPlayer
var pool: Array = []
var cache := {}
var current := ""
var music_tween: Tween
var ducked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	add_child(music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = -4.0
		add_child(p)
		pool.append(p)


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


func sfx(name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	if not SFX_FILES.has(name):
		return
	var s := _load(SFX_FILES[name])
	if s == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = s
			p.volume_db = -4.0 + vol
			p.pitch_scale = pitch
			p.play()
			return


func play_music(name: String) -> void:
	if name == current and music.playing:
		return
	current = name
	var s := _load("music_%s.wav" % name)
	if s == null:
		return
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2
	if music_tween:
		music_tween.kill()
	music.stream = s
	music.volume_db = -9.0 if not ducked else -18.0
	music.play()


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
	music.volume_db = -18.0 if on else -9.0
