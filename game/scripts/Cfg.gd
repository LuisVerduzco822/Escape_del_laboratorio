extends Node

const W := 480
const H := 270
const FLOOR_Y := 192.0
const MAX_HP := 4
const DEBUG_KEYS := false

# Shared opening cadence for every level, counted after its introduction.
const START_DELAYS := {"fire": 0.35, "bat": 1.5, "spore": 3.5, "bolt": 7.0, "heal": 50.0, "horde": 12.0}
const BOSS_POWERUPS := {
	"first_delay": 4.0, "interval": 14.0, "pickup_life": 12.0,
	"sequence": ["overcharge", "boss_bomb"],
	"boost_duration": 10.0, "boost_damage": 3.0, "boost_fire_rate": 0.075,
	"bomb_damage": 110.0,
}

var time_mult := 1.0

const LEVELS := [
	{
		"tag": "NIVEL 1",
		"name": "EL LABORATORIO",
		"music": "lab",
		"boss_music": "boss1",
		"collect_time": 200.0,
		"ing_times": [20.0, 92.0, 160.0],
		"boss_name": "GELATINA MUTANTE",
		"boss_hp": 880.0,
		"boss_time": 240.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 1920.0,
		"arena_x": 1440.0,
		"ingredient_spots": [Vector2(352, 56), Vector2(856, 44), Vector2(1280, 48)],
		"platforms": [
			# First ascent: wide steps introduce jumping between heights.
			[140, 150, 96], [250, 108, 80], [320, 70, 64], [438, 126, 88],
			# Second ascent: shorter ledges and a high compound.
			[600, 150, 76], [710, 104, 60], [824, 58, 64], [942, 116, 60],
			# Third ascent: narrow steps, followed by the sealed passage.
			[1080, 150, 64], [1160, 106, 52], [1254, 62, 52], [1340, 126, 64],
			# Boss arena retains room to dodge on the ground.
			[1484, 146, 84], [1638, 146, 84], [1792, 146, 84],
		],
		"spawn": {"fire": [3.2, 1.7], "bat": [6.0, 3.2], "spore": [], "bolt": 0.0},
		"tint": Color(0.45, 0.85, 1.0),
		"story": "Los tanques se rompieron y el virus escapo.\nBusca los ingredientes del antidoto\nantes de que la Gelatina Mutante\nte alcance.",
		"ingredients": [
			["PETALO LUNAR", Color(0.78, 0.82, 1.0)],
			["HONGO CIAN", Color(0.3, 0.9, 1.0)],
			["SAVIA VERDE", Color(0.4, 1.0, 0.5)],
		],
	},
	{
		"tag": "NIVEL 2",
		"name": "LAS ALCANTARILLAS",
		"music": "sewer",
		"boss_music": "boss2",
		"collect_time": 200.0,
		"ing_times": [20.0, 94.0, 162.0],
		"boss_name": "PULPO TOXICO",
		"boss_hp": 940.0,
		"boss_time": 250.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 2160.0,
		"arena_x": 1680.0,
		"ingredient_spots": [Vector2(360, 64), Vector2(976, 50), Vector2(1490, 60)],
		"platforms": [
			# Sewer pipes: staggered stairs, then a high maintenance walkway.
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64], [1056, 126, 72],
			# Narrow pipe tops lead to the last compound and the pressure gate.
			[1200, 152, 56], [1286, 110, 60], [1370, 74, 52], [1462, 74, 56], [1560, 132, 72],
			[1708, 150, 72], [1884, 112, 72], [2060, 150, 72],
		],
		"spawn": {"fire": [2.8, 1.5], "bat": [5.0, 2.8], "spore": [6.5, 3.2], "bolt": 0.0},
		"tint": Color(0.55, 1.0, 0.5),
		"story": "El virus corre por las tuberias.\nAqui abajo crecen las raices y\nlas escamas que faltan.\nCuidado con el Pulpo Toxico.",
		"ingredients": [
			["RAIZ ACIDA", Color(0.8, 1.0, 0.2)],
			["ESCAMA PLATEADA", Color(0.85, 0.9, 0.97)],
			["MUSGO DORADO", Color(1.0, 0.8, 0.25)],
		],
	},
	{
		"tag": "NIVEL 3",
		"name": "LA AZOTEA",
		"music": "roof",
		"boss_music": "boss3",
		"collect_time": 200.0,
		"ing_times": [20.0, 96.0, 164.0],
		"boss_name": "GARGOLA VIRAL",
		"boss_hp": 920.0,
		"boss_time": 260.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 2400.0,
		"arena_x": 1920.0,
		"ingredient_spots": [Vector2(398, 52), Vector2(1060, 30), Vector2(1700, 44)],
		"platforms": [
			# Rooftop equipment: longer gaps and progressively narrower ledges.
			[140, 150, 72], [246, 108, 60], [370, 66, 56], [510, 126, 64],
			[730, 152, 64], [828, 110, 52], [918, 68, 48], [1032, 44, 56], [1188, 120, 52],
			[1350, 152, 56], [1444, 110, 50], [1540, 66, 48], [1672, 58, 56], [1810, 126, 64],
			[1976, 150, 66], [2090, 116, 66], [2210, 150, 66], [2316, 116, 66],
		],
		"spawn": {"fire": [2.4, 1.2], "bat": [4.2, 2.2], "spore": [5.0, 2.6], "bolt": 11.0},
		"tint": Color(0.7, 0.8, 0.9),
		"story": "Ultima parada: la azotea.\nLos ultimos ingredientes estan aqui,\ncustodiados por la Gargola Viral.\nTodo termina esta noche.",
		"ingredients": [
			["PLUMA DE GARGOLA", Color(0.72, 0.5, 1.0)],
			["CRISTAL ESTELAR", Color(0.5, 0.9, 1.0)],
			["CENIZA ROJA", Color(1.0, 0.35, 0.3)],
		],
	},
]

func collect_time(i: int) -> float:
	return LEVELS[i]["collect_time"] * time_mult

func boss_time(i: int) -> float:
	return LEVELS[i]["boss_time"] * time_mult
