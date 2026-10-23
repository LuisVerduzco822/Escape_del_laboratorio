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

# Música más baja que los efectos: las pistas están normalizadas (-24 LUFS); las .wav antiguas son
# algo más fuertes y se compensan.
const MUSIC_DB := -4.5
const WAV_COMP_DB := -5.0
const SFX_DB := 1.0

var music: AudioStreamPlayer
var pool: Array = []
var cache := {}
var current := ""
var music_tween: Tween
var ducked := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_DB
	add_child(music)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
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


# Ataques y alertas (jefes, enemigos, avisos) suenan más bajo que el resto de efectos.
const ATTACK_DB := {"shoot": -7.0, "warn": -9.0, "phase": -7.0, "boom": -6.0, "select": -6.0, "tick": -3.0}
const MIN_GAP_MS := 40
var last_ms := {}


func sfx(name: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	var key := "shoot" if name == "pshoot" else name
	if not SFX_FILES.has(key):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_ms.get(name, -1000)) < MIN_GAP_MS:
		return   # evita apilar el mismo sonido decenas de veces (ráfagas de balas)
	last_ms[name] = now
	vol += float(ATTACK_DB.get(name, 0.0))
	var s := _load(SFX_FILES[key])
	if s == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = s
			p.volume_db = SFX_DB + vol
			p.pitch_scale = pitch
			p.play()
			return


func play_music(name: String) -> void:
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
