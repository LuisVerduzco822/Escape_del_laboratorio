extends SceneTree

# Aviso de versión nueva: comparación de versiones, elección del release y del archivo según la plataforma.
const UpdateCheck := preload("res://scripts/UpdateCheck.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)


func rel(tag: String, prerelease: bool = false, draft: bool = false) -> Dictionary:
	var base := "https://github.com/x/y/releases/download/" + tag + "/"
	return {"tag_name": tag, "prerelease": prerelease, "draft": draft, "html_url": "https://github.com/x/y/releases/tag/" + tag,
		"assets": [{"name": "Escape-android-universal-1.apk", "browser_download_url": base + "a.apk"},
			{"name": "Escape-windows-x86_64-1.exe", "browser_download_url": base + "w.exe"},
			{"name": "SHA256SUMS.txt", "browser_download_url": base + "s.txt"}]}


func _run() -> void:
	var p := UpdateCheck.parse("v1.0.0-alpha.2+5")
	check(p.ok and p.core == [1, 0, 0] and p.pre == ["alpha", "2"] and p.code == 5, "Tag with pre-release and build code is parsed")
	check(UpdateCheck.parse("v2.3.4").code == 0 and UpdateCheck.parse("2.3.4").ok, "Plain versions parse, with or without the leading v")
	check(not UpdateCheck.parse("practica-6").ok and not UpdateCheck.parse("v1.0").ok, "Tags that are not versions are ignored")
	var order := ["1.0.0-alpha.1", "1.0.0-alpha.2", "1.0.0-alpha.10", "1.0.0-beta.1", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.1.0", "2.0.0"]
	var sorted := true
	for i in order.size() - 1:
		sorted = sorted and UpdateCheck.compare(UpdateCheck.parse(order[i]), UpdateCheck.parse(order[i + 1])) == -1 and UpdateCheck.compare(UpdateCheck.parse(order[i + 1]), UpdateCheck.parse(order[i])) == 1
	check(sorted, "Versions order alpha < beta < rc < stable, numerically (alpha.2 < alpha.10)")
	check(UpdateCheck.compare(UpdateCheck.parse("1.0.0+3"), UpdateCheck.parse("1.0.0+9")) == 0, "Build code does not change the version precedence")
	check(UpdateCheck.is_newer("v1.0.0-alpha.2+2", "1.0.0-alpha.1", 1), "A higher alpha is an update")
	check(not UpdateCheck.is_newer("v1.0.0-alpha.1+1", "1.0.0-alpha.1", 1), "The same release is not an update")
	check(not UpdateCheck.is_newer("v1.0.0-alpha.1+1", "1.0.0-beta.1", 2), "An older release is never offered")
	check(UpdateCheck.is_newer("v1.0.0-alpha.1+4", "1.0.0-alpha.1", 3), "Same version name but a higher build code is an update")
	check(not UpdateCheck.is_newer("v1.0.0-alpha.1+4", "1.0.0-alpha.1", 0), "Same name with an unknown installed code is not an update")
	check(not UpdateCheck.is_newer("v9.0.0", "", 0), "Development builds (no version) never show an update")
	# Elección del release
	var list := [rel("v1.0.0-alpha.1+1", true), rel("v1.0.0-beta.1+3", true), rel("v1.0.0-alpha.2+2", true), rel("v2.0.0+9", false, true), rel("practica-6")]
	var best := UpdateCheck.newest(list, "1.0.0-alpha.1", 1, "Android")
	check(best.tag == "v1.0.0-beta.1+3" and best.name == "1.0.0-beta.1" and best.prerelease, "The newest published release wins (drafts and non-version tags are skipped)")
	check(best.url.ends_with("a.apk"), "Android is sent straight to the APK")
	check(UpdateCheck.newest(list, "1.0.0-alpha.1", 1, "Windows").url.ends_with("w.exe"), "Windows is sent to the .exe")
	check(UpdateCheck.newest(list, "1.0.0-alpha.1", 1, "macOS").url == best.page, "Other platforms are sent to the release page")
	check(UpdateCheck.newest(list, "1.0.0-beta.1", 3, "Android").is_empty(), "Nothing is offered when already on the newest version")
	check(UpdateCheck.newest([], "1.0.0", 1, "Android").is_empty(), "An empty list offers nothing")
	# Respuesta HTTP
	var body := JSON.stringify([rel("v1.0.0+4")]).to_utf8_buffer()
	check(UpdateCheck.from_response(200, body, "1.0.0-rc.1", 3, "Android").name == "1.0.0", "A valid GitHub response yields the update")
	check(UpdateCheck.from_response(403, body, "1.0.0-rc.1", 3, "Android").is_empty(), "A rate-limit or error response is silently ignored")
	check(UpdateCheck.from_response(200, "no es json".to_utf8_buffer(), "1.0.0", 1, "Android").is_empty() and UpdateCheck.from_response(200, "{}".to_utf8_buffer(), "1.0.0", 1, "Android").is_empty(), "Malformed responses are silently ignored")
	print("Update check failures: %d" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
