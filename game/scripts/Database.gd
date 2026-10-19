extends Node

const CONFIG_FILE := "user://config.cfg"
const OFFLINE_SAVE := "user://offline_progress.cfg"
const DEFAULT_URL := "http://localhost:3000"
var timeout := 8.0

var base_url := DEFAULT_URL
var token := ""
var username := ""
var user_id := -1
var online := false
var offline_mode := false
var progress_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var c := ConfigFile.new()
	if c.load(CONFIG_FILE) == OK:
		base_url = str(c.get_value("server", "url", DEFAULT_URL))
	var env := OS.get_environment("ESCAPE_API_URL")
	if env != "":
		base_url = env


func set_url(url: String) -> void:
	url = url.strip_edges()
	if url == "":
		url = DEFAULT_URL
	if not url.begins_with("http://") and not url.begins_with("https://"):
		url = "http://" + url
	base_url = url.rstrip("/")
	var c := ConfigFile.new()
	c.load(CONFIG_FILE)
	c.set_value("server", "url", base_url)
	c.save(CONFIG_FILE)


func last_user() -> String:
	var c := ConfigFile.new()
	if c.load(CONFIG_FILE) == OK:
		return str(c.get_value("session", "last_user", ""))
	return ""


func _remember(name: String) -> void:
	var c := ConfigFile.new()
	c.load(CONFIG_FILE)
	c.set_value("session", "last_user", name)
	c.save(CONFIG_FILE)


func logged_in() -> bool:
	return token != ""


func can_play() -> bool:
	return offline_mode or logged_in()


func start_offline() -> void:
	offline_mode = true
	online = false
	token = ""
	username = "INVITADO"
	user_id = -1
	progress_cache = {}


func request(method: int, path: String, body: Variant = null, auth: bool = true) -> Dictionary:
	if offline_mode:
		return {"ok": false, "status": 0, "data": {}, "error": "Disponible solo al iniciar sesión"}
	var req := HTTPRequest.new()
	req.timeout = timeout
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(base_url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		online = false
		return {"ok": false, "status": 0, "data": {}, "error": "No se pudo conectar con el servidor"}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		online = false
		return {"ok": false, "status": 0, "data": {}, "error": "No se pudo conectar con el servidor"}
	online = true
	var code := int(res[1])
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	var data: Variant = parsed if parsed != null else {}
	var ok := code >= 200 and code < 300
	var msg := ""
	if not ok:
		msg = str(data.get("error", "Error del servidor (%d)" % code)) if data is Dictionary else "Error del servidor (%d)" % code
	return {"ok": ok, "status": code, "data": data, "error": msg}


func health() -> bool:
	var r := await request(HTTPClient.METHOD_GET, "/api/health", null, false)
	return r["ok"]


func validate(name: String, password: String) -> String:
	var rx := RegEx.new()
	rx.compile("^[A-Za-z0-9_]{3,16}$")
	if rx.search(name) == null:
		return "Usuario: 3 a 16 letras, números o _"
	if password.length() < 6 or password.length() > 32:
		return "Contraseña: 6 a 32 caracteres"
	return ""


func register(name: String, password: String) -> Dictionary:
	name = name.strip_edges()
	var err := validate(name, password)
	if err != "":
		return {"ok": false, "msg": err}
	var r := await request(HTTPClient.METHOD_POST, "/api/register", {"username": name, "password": password}, false)
	if r["ok"]:
		return {"ok": true, "msg": str(r["data"].get("message", "Cuenta creada"))}
	return {"ok": false, "msg": r["error"]}


func login(name: String, password: String) -> Dictionary:
	name = name.strip_edges()
	if name == "" or password == "":
		return {"ok": false, "msg": "Escribe usuario y contraseña"}
	var r := await request(HTTPClient.METHOD_POST, "/api/login", {"username": name, "password": password}, false)
	if not r["ok"]:
		return {"ok": false, "msg": r["error"]}
	token = str(r["data"]["token"])
	username = str(r["data"]["user"]["username"])
	user_id = int(r["data"]["user"]["id"])
	offline_mode = false
	_remember(username)
	progress_cache = {}
	return {"ok": true, "msg": "Bienvenido, " + username}


func logout() -> void:
	if token != "":
		await request(HTTPClient.METHOD_POST, "/api/logout")
	token = ""
	username = ""
	user_id = -1
	progress_cache = {}
	offline_mode = false


func refresh_progress() -> void:
	if offline_mode:
		progress_cache = {}
		var save := ConfigFile.new()
		if save.load(OFFLINE_SAVE) == OK:
			var saved: Variant = save.get_value("game", "progress", {})
			if saved is Dictionary and _valid_offline_progress(saved):
				progress_cache = saved
		return
	var r := await request(HTTPClient.METHOD_GET, "/api/progress")
	if not r["ok"]:
		return
	var p: Variant = r["data"].get("progress")
	if p == null:
		progress_cache = {}
		return
	var flags := []
	for ch in str(p["ingredients"]):
		flags.append(ch == "1")
	progress_cache = {
		"level_done": int(p["level_done"]),
		"ingredients": flags,
		"play_time": float(p["play_time"]),
		"parries": int(p["parries"]),
		"deaths": int(p["deaths"]),
		"coins": int(p["coins"]),
		"score": int(p["score"]),
	}


func load_progress() -> Dictionary:
	return progress_cache


func _valid_offline_progress(saved: Dictionary) -> bool:
	if typeof(saved.get("level_done")) != TYPE_INT:
		return false
	if saved["level_done"] < 1 or saved["level_done"] > 2:
		return false
	var flags: Variant = saved.get("ingredients")
	if not flags is Array or flags.size() != 9:
		return false
	for flag in flags:
		if typeof(flag) != TYPE_BOOL:
			return false
	for key in ["play_time", "parries", "deaths", "coins", "score"]:
		var value: Variant = saved.get(key)
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		if not is_finite(float(value)) or value < 0:
			return false
	return true


func save_progress(level_done: int, ingredients: Array, play_time: float, parries: int, deaths: int, coins: int, score: int) -> void:
	if offline_mode:
		progress_cache = {"level_done": level_done, "ingredients": ingredients.duplicate(), "play_time": play_time, "parries": parries, "deaths": deaths, "coins": coins, "score": score}
		var save := ConfigFile.new()
		save.set_value("game", "progress", progress_cache)
		if save.save(OFFLINE_SAVE) != OK:
			push_warning("No se pudo guardar el progreso offline")
		return
	var flags := ""
	for v in ingredients:
		flags += "1" if v else "0"
	var body := {"level_done": level_done, "ingredients": flags, "play_time": play_time, "parries": parries, "deaths": deaths, "coins": coins, "score": score}
	var r := await request(HTTPClient.METHOD_PUT, "/api/progress", body)
	if r["ok"]:
		await refresh_progress()


func clear_progress() -> void:
	progress_cache = {}
	if offline_mode:
		if FileAccess.file_exists(OFFLINE_SAVE):
			if DirAccess.remove_absolute(OFFLINE_SAVE) != OK:
				push_warning("No se pudo borrar el progreso offline")
		return
	await request(HTTPClient.METHOD_DELETE, "/api/progress")


func leaderboard(kind: String = "score", limit: int = 8, scope: String = "all", mode: String = "story") -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "/api/leaderboard?type=%s&scope=%s&limit=%d&mode=%s" % [kind, scope, limit, mode], null, false)
	if not r["ok"]:
		return {"ok": false, "entries": [], "error": r["error"]}
	return {"ok": true, "entries": r["data"].get("entries", []), "error": ""}


func my_stats() -> Dictionary:
	var r := await request(HTTPClient.METHOD_GET, "/api/me")
	if not r["ok"]:
		return {}
	return r["data"].get("stats", {})
