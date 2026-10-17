extends Node

# Explicit data only: save files cannot supply scripts or instantiate objects.
const VERSION := 1
const FIELDS := {
	"stats": ["hp", "super_meter", "ingredients", "play_time", "parries", "coins", "score", "combo", "combo_t", "streak", "best_streak", "hits_taken", "survive_acc", "current_level", "deaths"],
	"level": ["index", "st", "st_t", "age", "collect_t", "boss_t", "reached_boss", "ing_spawned", "cd", "horde_remaining", "horde_wait", "horde_p"],
	"player": ["position", "velocity", "facing", "aim", "invuln", "dash_t", "dash_cd", "dash_dir", "air_dash", "fire_cd", "coyote", "buffer", "drop_t", "on_platform", "weapon_power_t"],
	"boss": ["hp", "phase", "t", "last_attack"],
	"enemy": ["position", "kind", "hp", "speed", "dir", "pink", "age", "base_y", "wobble", "bound_l", "bound_r", "grounded"],
	"pickup": ["position", "kind", "idx", "col", "label", "age", "life", "base_y", "value", "vy", "landed", "fall"],
	"hazard": ["position", "vel", "accel", "pink", "radius", "col", "style", "age", "spin"],
	"zone": ["position", "size", "warn", "active", "col", "t", "struck"],
	"shot": ["position", "vel", "damage", "radius", "pierce", "kind", "age"],
}
const OPTIONAL_FIELDS := {"player": {"weapon_power_t": 0.0}}
const SCRIPTS := {
	"enemy": preload("res://scripts/Enemy.gd"),
	"pickup": preload("res://scripts/Pickup.gd"),
	"hazard": preload("res://scripts/Hazard.gd"),
	"zone": preload("res://scripts/Zone.gd"),
	"shot": preload("res://scripts/PlayerShot.gd"),
}
var error := ""

func path() -> String:
	if Database.offline_mode:
		return "user://resume_guest.save"
	return "user://resume_%s_user_%d.save" % [Database.base_url.sha256_text().substr(0, 16), Database.user_id]

func read_fields(node: Object, category: String) -> Dictionary:
	var result := {}
	for key in FIELDS[category]:
		var value: Variant = node.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

func write_fields(node: Object, category: String, state: Dictionary) -> void:
	for key in FIELDS[category]:
		if not state.has(key) and OPTIONAL_FIELDS.get(category, {}).has(key):
			node.set(key, OPTIONAL_FIELDS[category][key])
			continue
		node.set(key, state[key].duplicate(true) if state[key] is Array or state[key] is Dictionary else state[key])

func capture(level: Node, boss_checkpoint: bool = false) -> Dictionary:
	var actors := []
	for child in level.get_children():
		if child.is_queued_for_deletion():
			continue
		for category in SCRIPTS:
			if child.get_script() == SCRIPTS[category]:
				# A boss phase begins with no shots, enemies or hazards.
				if not boss_checkpoint or category == "pickup":
					actors.append({"type": category, "state": read_fields(child, category)})
	var result := {
		"version": VERSION, "stats": read_fields(GameManager, "stats"),
		"level": read_fields(level, "level"), "player": read_fields(level.player, "player"),
		"actors": actors, "boss": {}, "counters": Telemetry.counters.duplicate(true),
	}
	if boss_checkpoint:
		result.level.st = 3 # Level.S.BOSS
		result.level.st_t = 0.0
		result.boss = read_fields(level.boss, "boss")
		result.boss.rng_seed = level.boss.attack_rng.seed
		result.boss.rng_state = level.boss.attack_rng.state
	return result

func store(state: Dictionary) -> bool:
	error = ""
	var file := FileAccess.open(path() + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "No se pudo abrir el archivo de guardado."
		return false
	file.store_var(state, false)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK or DirAccess.rename_absolute(path() + ".tmp", path()) != OK:
		error = "No se pudo guardar. Tu partida sigue abierta."
		return false
	return true

func load_saved() -> Dictionary:
	if not FileAccess.file_exists(path()):
		return {}
	var file := FileAccess.open(path(), FileAccess.READ)
	if file == null or file.get_length() > 4 * 1024 * 1024:
		return {}
	var saved: Variant = file.get_var(false)
	return saved if valid(saved) else {}

func clear() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(path())

func _plain(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_NIL: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR2: return value.is_finite()
		TYPE_COLOR: return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a)
		TYPE_ARRAY:
			for item in value:
				if not _plain(item): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if (not key is String and not key is StringName) or not _plain(value[key]): return false
			return true
	return false

func _shape(state: Variant, category: String, sample: Object) -> bool:
	if not state is Dictionary: return false
	for key in FIELDS[category]:
		if not state.has(key) and OPTIONAL_FIELDS.get(category, {}).has(key):
			continue
		if not state.has(key) or typeof(state[key]) != typeof(sample.get(key)):
			return false
	return true

func valid(saved: Variant) -> bool:
	if not saved is Dictionary or not _plain(saved) or saved.get("version") != VERSION:
		return false
	for key in ["stats", "level", "player", "boss", "counters"]:
		if not saved.get(key) is Dictionary: return false
	if not saved.get("actors") is Array or saved.actors.size() > 512: return false
	# Level is loaded at runtime to avoid a preload cycle with this autoload.
	var samples := {"stats": GameManager, "level": load("res://scripts/Level.gd").new(), "player": load("res://scripts/Player.gd").new(), "boss": load("res://scripts/Boss.gd").new()}
	var ok := true
	for category in ["stats", "level", "player"]:
		ok = ok and _shape(saved[category], category, samples[category])
	if ok:
		ok = saved.level.index in [0, 1, 2] and saved.level.st in [0, 1, 3]
		ok = ok and saved.stats.current_level == saved.level.index and saved.level.reached_boss == (saved.level.st == 3)
		ok = ok and saved.stats.hp > 0 and saved.stats.hp <= Cfg.MAX_HP
		ok = ok and saved.stats.ingredients.size() == 9 and saved.level.ing_spawned.size() == 3
		for flag in saved.stats.ingredients + saved.level.ing_spawned:
			ok = ok and flag is bool
		for key in ["fire", "bat", "spore", "bolt", "heal", "horde"]:
			ok = ok and saved.level.cd.has(key) and (saved.level.cd[key] is float or saved.level.cd[key] is int)
		if saved.level.st == 3:
			ok = ok and _shape(saved.boss, "boss", samples.boss) and typeof(saved.boss.get("rng_state")) == TYPE_INT and typeof(saved.boss.get("rng_seed")) == TYPE_INT
			if ok: ok = saved.boss.phase in [1, 2, 3] and saved.boss.hp > 0.0 and saved.boss.hp <= Cfg.LEVELS[saved.level.index].boss_hp
		else:
			ok = ok and saved.boss.is_empty()
	for category in ["level", "player", "boss"]:
		samples[category].free()
	for actor in saved.actors:
		if not actor is Dictionary or not SCRIPTS.has(actor.get("type")): return false
		var sample: Node = SCRIPTS[actor.type].new()
		var actor_ok := _shape(actor.get("state"), actor.type, sample)
		sample.free()
		if not actor_ok: return false
		if actor.type == "pickup" and (actor.state.idx < 0 or actor.state.idx >= 9): return false
	for value in saved.counters.values():
		if not value is int or value < 0: return false
	return ok
