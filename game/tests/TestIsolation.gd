extends RefCounted


static func active() -> bool:
	var data := OS.get_data_dir().replace("\\", "/")
	if data.begins_with("/tmp/escape-controls-"):
		return true
	# run_tests.py supplies a new, disposable APPDATA directory on Windows.
	return data.get_file().begins_with("escape-controls-") and data.ends_with(".save-check") and data == OS.get_environment("APPDATA").replace("\\", "/")
