extends RefCounted

# Source sprites remain unchanged; atlas regions match the individual source tiles.
const SHEETS := {
	"MainButtons": preload("res://assets/ui/gamepad/MainButtons_Tileset_noAA.png"),
	"RearButtons": preload("res://assets/ui/gamepad/RearButtons_Tileset_noAA.png"),
	"SpecialButtons": preload("res://assets/ui/gamepad/SpecialButtons_Tileset_noAA.png"),
	"Joystick": preload("res://assets/ui/gamepad/Joystick_Tileset_noAA.png"),
	"DirectionalInputs": preload("res://assets/ui/gamepad/DirectionalInputs_Tileset_noAA.png"),
}
const REGIONS := {
	"MainButtons19": Rect2(64, 16, 16, 16),
	"MainButtons21": Rect2(96, 16, 16, 16),
	"MainButtons25": Rect2(160, 16, 16, 16),
	"MainButtons27": Rect2(192, 16, 16, 16),
	"MainButtons31": Rect2(32, 32, 16, 16),
	"MainButtons33": Rect2(64, 32, 16, 16),
	"MainButtons35": Rect2(96, 32, 16, 16),
	"MainButtons37": Rect2(128, 32, 16, 16),
	"MainButtons41": Rect2(192, 32, 16, 16),
	"MainButtons43": Rect2(0, 48, 16, 16),
	"MainButtons45": Rect2(32, 48, 16, 16),
	"MainButtons47": Rect2(64, 48, 16, 16),
	"MainButtons49": Rect2(96, 48, 16, 16),
	"MainButtons51": Rect2(128, 48, 16, 16),
	"MainButtons53": Rect2(160, 48, 16, 16),
	"MainButtons55": Rect2(192, 48, 16, 16),
	"RearButtons5": Rect2(64, 0, 16, 16),
	"RearButtons7": Rect2(96, 0, 16, 16),
	"RearButtons11": Rect2(160, 0, 16, 16),
	"RearButtons13": Rect2(192, 0, 16, 16),
	"RearButtons31": Rect2(0, 32, 16, 16),
	"RearButtons33": Rect2(32, 32, 16, 16),
	"RearButtons39": Rect2(128, 32, 16, 16),
	"RearButtons41": Rect2(160, 32, 16, 16),
	"RearButtons47": Rect2(32, 48, 16, 16),
	"RearButtons49": Rect2(64, 48, 16, 16),
	"RearButtons57": Rect2(192, 48, 16, 16),
	"RearButtons59": Rect2(0, 64, 16, 16),
	"SpecialButtons5": Rect2(64, 0, 16, 16),
	"SpecialButtons7": Rect2(96, 0, 16, 16),
	"SpecialButtons9": Rect2(128, 0, 16, 16),
	"SpecialButtons11": Rect2(160, 0, 16, 16),
	"SpecialButtons43": Rect2(192, 32, 16, 16),
	"SpecialButtons45": Rect2(224, 32, 16, 16),
	"Joystick7": Rect2(96, 0, 16, 16),
	"Joystick8": Rect2(112, 0, 16, 16),
	"Joystick38": Rect2(256, 16, 16, 16),
	"Joystick39": Rect2(272, 16, 16, 16),
	"Joystick49": Rect2(96, 32, 16, 16),
	"Joystick50": Rect2(112, 32, 16, 16),
	"Joystick70": Rect2(96, 48, 16, 16),
	"Joystick71": Rect2(112, 48, 16, 16),
	"Joystick91": Rect2(96, 64, 16, 16),
	"Joystick92": Rect2(112, 64, 16, 16),
	"Joystick112": Rect2(96, 80, 16, 16),
	"Joystick113": Rect2(112, 80, 16, 16),
	"DirectionalInputs3": Rect2(32, 0, 16, 16),
	"DirectionalInputs4": Rect2(48, 0, 16, 16),
	"DirectionalInputs5": Rect2(64, 0, 16, 16),
	"DirectionalInputs6": Rect2(80, 0, 16, 16),
	"DirectionalInputs93": Rect2(112, 80, 16, 16),
	"DirectionalInputs95": Rect2(144, 80, 16, 16),
	"DirectionalInputs97": Rect2(176, 80, 16, 16),
	"DirectionalInputs99": Rect2(208, 80, 16, 16),
}
static var cache: Dictionary = {}


static func detect_family(name: String) -> String:
	var lower := name.to_lower()
	for token in ["playstation", "dualshock", "dualsense", "sony", "ps3", "ps4", "ps5"]:
		if token in lower:
			return "playstation"
	for token in ["nintendo", "switch", "joy-con", "joycon"]:
		if token in lower:
			return "nintendo"
	for token in ["xbox", "xinput", "microsoft"]:
		if token in lower:
			return "xbox"
	return "generic"


static func button_label(index: int, family: String) -> String:
	var faces: Array = ["A", "B", "X", "Y"]
	if family == "playstation":
		faces = ["CRUZ", "CIRCULO", "CUADRADO", "TRIANGULO"]
	elif family == "nintendo":
		faces = ["B", "A", "Y", "X"]
	elif family == "generic":
		faces = ["BOTON INFERIOR", "BOTON DERECHO", "BOTON IZQUIERDO", "BOTON SUPERIOR"]
	if index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
		return faces[index]
	if index == JOY_BUTTON_START:
		return "OPTIONS" if family == "playstation" else ("+" if family == "nintendo" else "START")
	if index == JOY_BUTTON_BACK:
		return "SHARE/CREATE" if family == "playstation" else ("-" if family == "nintendo" else "VIEW/SELECT")
	if index == JOY_BUTTON_LEFT_SHOULDER:
		return "L1" if family == "playstation" else ("L" if family == "nintendo" else "LB")
	if index == JOY_BUTTON_RIGHT_SHOULDER:
		return "R1" if family == "playstation" else ("R" if family == "nintendo" else "RB")
	return {JOY_BUTTON_LEFT_STICK: "L3 / CLIC SI", JOY_BUTTON_RIGHT_STICK: "R3 / CLIC SD", JOY_BUTTON_DPAD_LEFT: "DPAD IZQ", JOY_BUTTON_DPAD_RIGHT: "DPAD DER", JOY_BUTTON_DPAD_UP: "DPAD ARR", JOY_BUTTON_DPAD_DOWN: "DPAD ABA"}.get(index, "BOTON %d" % index)


static func direction(event: InputEventJoypadMotion) -> String:
	return ("IZQ" if event.axis_value < 0 else "DER") if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_RIGHT_X] else ("ARR" if event.axis_value < 0 else "ABA")


static func label(event: InputEvent, family: String) -> String:
	if event is InputEventJoypadButton:
		return button_label(event.button_index, family)
	if event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			var left: bool = event.axis == JOY_AXIS_TRIGGER_LEFT
			return ("L2" if left else "R2") if family == "playstation" else (("ZL" if left else "ZR") if family == "nintendo" else ("LT" if left else "RT"))
		return ("SI " if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "SD ") + direction(event)
	return ""


static func texture(event: InputEvent, family: String) -> Texture2D:
	var group := ""
	var number := 0
	if event is InputEventJoypadButton:
		var index: int = event.button_index
		if index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			group = "MainButtons"
			var faces: Array = [21, 27, 33, 37]
			if family == "playstation":
				faces = [43, 51, 47, 55]
			elif family == "nintendo":
				faces = [25, 19, 35, 31]
			elif family == "generic":
				group = "DirectionalInputs"
				faces = [5, 4, 6, 3]
			number = faces[index]
		elif index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			group = "RearButtons"
			var left: bool = index == JOY_BUTTON_LEFT_SHOULDER
			number = (11 if left else 13) if family == "playstation" else ((57 if left else 59) if family == "nintendo" else (39 if left else 41))
		elif index in [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
			group = "Joystick"
			number = 38 if index == JOY_BUTTON_LEFT_STICK else 39
		elif index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_LEFT]:
			group = "DirectionalInputs"
			number = {JOY_BUTTON_DPAD_UP: 93, JOY_BUTTON_DPAD_DOWN: 95, JOY_BUTTON_DPAD_RIGHT: 97, JOY_BUTTON_DPAD_LEFT: 99}[index]
		elif index in [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]:
			group = "SpecialButtons"
			if index == JOY_BUTTON_GUIDE:
				number = 11
			elif family == "nintendo":
				number = 45 if index == JOY_BUTTON_START else 43
			else:
				number = 7 if index == JOY_BUTTON_START else (9 if family == "playstation" else 5)
	elif event is InputEventJoypadMotion:
		if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			group = "RearButtons"
			var left: bool = event.axis == JOY_AXIS_TRIGGER_LEFT
			number = (5 if left else 7) if family == "playstation" else ((47 if left else 49) if family == "nintendo" else (31 if left else 33))
		else:
			group = "Joystick"
			var left: bool = event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
			var base: int = {"ARR": 49, "DER": 70, "ABA": 91, "IZQ": 112}[direction(event)]
			number = base if left else base + 1
	if group.is_empty():
		return null
	var key := group + str(number)
	if not cache.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEETS[group]
		atlas.region = REGIONS[key]
		cache[key] = atlas
	return cache[key]
