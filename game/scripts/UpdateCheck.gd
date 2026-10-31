extends Node

# Aviso de versión nueva: al abrir el juego consulta los Releases de GitHub y, si hay una versión más reciente
# que la instalada, muestra un botón en el menú que abre la descarga (APK en Android, .exe en Windows...).
# No instala nada por sí solo: Android pide confirmación al abrir el archivo descargado.
# Si no hay internet o GitHub no responde, no pasa nada: el aviso simplemente no aparece.

signal found(info: Dictionary)

const REPO := "LuisVerduzco822/Escape_del_laboratorio"
const API := "https://api.github.com/repos/%s/releases?per_page=15"
const TAG_PATTERN := "^v?(\\d+)\\.(\\d+)\\.(\\d+)(?:-([0-9A-Za-z.-]+))?(?:\\+(\\d+))?$"

var request: HTTPRequest


# Versión visible instalada (la escribe el flujo de releases en project.godot; vacía en compilaciones de desarrollo).
static func installed_name() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


# Número de compilación instalado (0 si no se conoce).
static func installed_code() -> int:
	return int(ProjectSettings.get_setting("application/config/build_code", 0))


# "v1.0.0-alpha.2+5" -> {ok, core:[1,0,0], pre:["alpha","2"], code:5}
static func parse(tag: String) -> Dictionary:
	var re := RegEx.new()
	re.compile(TAG_PATTERN)
	var m := re.search(tag.strip_edges())
	if m == null:
		return {"ok": false}
	var pre: Array = []
	if m.get_string(4) != "":
		pre = Array(m.get_string(4).split("."))
	return {"ok": true, "core": [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3))], "pre": pre,
		"code": int(m.get_string(5)) if m.get_string(5) != "" else 0}


# Precedencia semántica: 1 si a es más nueva, -1 si es más vieja, 0 si son iguales.
# 1.0.0-alpha.1 < 1.0.0-alpha.2 < 1.0.0-beta.1 < 1.0.0-rc.1 < 1.0.0
static func compare(a: Dictionary, b: Dictionary) -> int:
	for i in 3:
		if a.core[i] != b.core[i]:
			return 1 if a.core[i] > b.core[i] else -1
	var pa: Array = a.pre
	var pb: Array = b.pre
	if pa.is_empty() and pb.is_empty():
		return 0
	if pa.is_empty():
		return 1
	if pb.is_empty():
		return -1
	for i in mini(pa.size(), pb.size()):
		var x := str(pa[i])
		var y := str(pb[i])
		if x == y:
			continue
		var xn := x.is_valid_int()
		var yn := y.is_valid_int()
		if xn and yn:
			return 1 if int(x) > int(y) else -1
		if xn != yn:
			return -1 if xn else 1   # los números van antes que el texto
		return 1 if x > y else -1
	if pa.size() == pb.size():
		return 0
	return 1 if pa.size() > pb.size() else -1


# ¿El release `tag` es más nuevo que lo instalado? Con la misma versión visible decide el número de compilación.
static func is_newer(tag: String, current_name: String, current_code: int) -> bool:
	var cand := parse(tag)
	var cur := parse(current_name)
	if not cand.ok or not cur.ok:
		return false
	var c := compare(cand, cur)
	if c != 0:
		return c > 0
	return current_code > 0 and cand.code > current_code


static func asset_url(release: Dictionary, platform: String) -> String:
	var suffix := {"Android": ".apk", "Windows": ".exe", "Linux": ".appimage"}.get(platform, "") as String
	if suffix != "":
		for asset in release.get("assets", []):
			if str(asset.get("name", "")).to_lower().ends_with(suffix) and str(asset.get("browser_download_url", "")).begins_with("https://"):
				return str(asset["browser_download_url"])
	return str(release.get("html_url", ""))


# Elige, de la lista de releases de GitHub, el más nuevo que supere lo instalado. {} si no hay.
static func newest(releases: Array, current_name: String, current_code: int, platform: String) -> Dictionary:
	var best := {}
	var best_parsed := {}
	for release in releases:
		if not release is Dictionary or release.get("draft", false):
			continue
		var tag := str(release.get("tag_name", ""))
		var parsed := parse(tag)
		if not parsed.ok:
			continue
		if not best.is_empty():
			var c := compare(parsed, best_parsed)
			if c < 0 or (c == 0 and parsed.code <= best_parsed.code):
				continue
		best = release
		best_parsed = parsed
	if best.is_empty() or not is_newer(str(best.tag_name), current_name, current_code):
		return {}
	var version := str(best.tag_name).trim_prefix("v").split("+")[0]
	return {"tag": str(best.tag_name), "name": version, "url": asset_url(best, platform), "page": str(best.get("html_url", "")), "prerelease": bool(best.get("prerelease", false))}


static func from_response(code: int, body: PackedByteArray, current_name: String, current_code: int, platform: String) -> Dictionary:
	if code != 200:
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Array:
		return {}
	return newest(json.data, current_name, current_code, platform)


func check() -> void:
	if installed_name() == "" or OS.has_feature("web"):
		return   # compilación de desarrollo: no hay versión que comparar
	request = HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(_done)
	if request.request(API % REPO, ["User-Agent: EscapeDelLaboratorio", "Accept: application/vnd.github+json"]) != OK:
		queue_free()


func _done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS:
		var info := from_response(code, body, installed_name(), installed_code(), OS.get_name())
		if not info.is_empty() and info.url != "":
			found.emit(info)
	queue_free()
