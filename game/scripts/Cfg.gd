extends Node

const W := 480
const H := 270
const FLOOR_Y := 192.0
const MAX_HP := 4
const DEBUG_KEYS := false
# Cada nivel tiene 3 compuestos; con 5 niveles el antidoto necesita 15.
const ING_TOTAL := 15
# Las pruebas automáticas de recorrido lo apagan para no tener que saltar cada caja.
var boxes_enabled := true
const ENEMY_INTERVAL := 0.72   # menor = más enemigos (los intervalos de aparición se multiplican por esto)

# Opening cadence after the introduction; level 1 also waits for W/3 forward travel.
const START_DELAYS := {"fire": 0.35, "bat": 1.5, "spore": 3.5, "bolt": 7.0, "heal": 30.0, "horde": 12.0}
# Con los niveles más largos, la vida extra aparece más seguido durante el recorrido.
const HEAL_EVERY := 35.0

# Dificultad de los jefes (historia y finaltop): menos vida, ataques más lentos y más
# espaciados, y menos proyectiles por patrón. Sube/baja estos números para afinar.
const BOSS := {
	"speed": 0.86,     # multiplica la velocidad de proyectiles y ritmo de los ataques
	"rest_add": 0.45,  # segundos extra de descanso entre ataques
	"count": 0.8,      # multiplica la cantidad de proyectiles de cada patrón
}
# Vida máxima que tenían los jefes antes del reajuste: solo para validar partidas guardadas viejas.
const LEGACY_BOSS_HP := [880.0, 940.0, 920.0, 1000.0, 1100.0]

# Modo FINALTOP: solo jefes, uno tras otro, con el reloj corriendo. Gana el menor tiempo.
const FINALTOP := {
	"name": "FINALTOP",
	"boss_hp": [800.0, 1000.0, 1350.0, 1700.0, 4500.0],   # la calavera (último jefe) tiene muchísima vida
	"death_penalty": 15.0,               # segundos que suma cada derrota
	"heart_every": 26.0,                 # un corazón cada tanto si quedan 2 vidas o menos
	"powerups": {
		"first_delay": 3.0, "interval": 10.0, "pickup_life": 12.0,
		"sequence": ["overcharge", "boss_bomb"],
		"boost_duration": 10.0, "boost_damage": 3.0, "boost_fire_rate": 0.075,
		"bomb_damage": 140.0,
	},
}
const BOSS_POWERUPS := {
	"first_delay": 3.0, "interval": 11.0, "pickup_life": 12.0,
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
		"collect_time": 300.0,
		"ing_times": [30.0, 138.0, 241.0],
		"boss_name": "GELATINA MUTANTE",
		"boss_hp": 640.0,
		"boss_time": 240.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 4660.0,
		"arena_x": 4180.0,
		"ingredient_spots": [Vector2(856, 44), Vector2(1692, 56), Vector2(4020, 48)],
		"platforms": [
			# Recorrido ampliado: se repite un tramo antes del último compuesto (x 2110 a 3510).
			[140, 150, 96], [250, 108, 80], [320, 70, 64], [438, 126, 88],
			[600, 150, 76], [710, 104, 60], [824, 58, 64], [942, 116, 60],
			[1080, 150, 64], [1160, 106, 52], [1254, 62, 52], [1340, 126, 64],
			[1480, 150, 96], [1590, 108, 80], [1660, 70, 64], [1778, 126, 88],
			[1940, 150, 76], [2050, 104, 60], [2110, 104, 60], [2224, 58, 64],
			[2342, 116, 60], [2480, 150, 64], [2560, 106, 52], [2654, 62, 52],
			[2740, 126, 64], [2880, 150, 96], [2990, 108, 80], [3060, 70, 64],
			[3178, 126, 88], [3340, 150, 76], [3450, 104, 60], [3564, 58, 64],
			[3682, 116, 60], [3820, 150, 64], [3900, 106, 52], [3994, 62, 52],
			[4080, 126, 64], [4224, 146, 84], [4378, 146, 84], [4532, 146, 84],
		],
		"boxes": [
			[269, ["b"]], [483, ["k", "k"]], [763, ["b", "b"]], [785, ["k"]],
			[1071, ["b"]], [1293, ["b"]], [1515, ["b", "k"]], [1537, ["k", "b"]],
			[1801, ["b", "b"]], [2024, ["b"]], [2264, ["k", "b"]], [2475, ["k", "b"]],
			[2691, ["k"]], [3005, ["k"]], [3027, ["k"]], [3257, ["b", "k"]],
			[3526, ["k"]], [3709, ["b", "b"]],
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
		"collect_time": 290.0,
		"ing_times": [29.0, 138.0, 237.0],
		"boss_name": "PULPO TOXICO",
		"boss_hp": 680.0,
		"boss_time": 250.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 5220.0,
		"arena_x": 4740.0,
		"ingredient_spots": [Vector2(976, 50), Vector2(1920, 64), Vector2(4550, 60)],
		"platforms": [
			# Recorrido ampliado: se repite un tramo antes del último compuesto (x 2414 a 3914).
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64],
			[1056, 126, 72], [1200, 152, 56], [1286, 110, 60], [1370, 74, 52],
			[1462, 74, 56], [1560, 132, 72], [1704, 152, 96], [1818, 114, 76],
			[1890, 78, 60], [2006, 132, 80], [2220, 150, 80], [2334, 108, 64],
			[2444, 64, 64], [2556, 126, 72], [2700, 152, 56], [2786, 110, 60],
			[2870, 74, 52], [2962, 74, 56], [3060, 132, 72], [3204, 152, 96],
			[3318, 114, 76], [3390, 78, 60], [3506, 132, 80], [3720, 150, 80],
			[3834, 108, 64], [3914, 64, 60], [4004, 64, 64], [4116, 126, 72],
			[4260, 152, 56], [4346, 110, 60], [4430, 74, 52], [4522, 74, 56],
			[4620, 132, 72], [4768, 150, 72], [4944, 112, 72], [5120, 150, 72],
		],
		"boxes": [
			[297, ["k", "b"]], [605, ["b", "k"]], [903, ["k"]], [925, ["b"]],
			[1149, ["b"]], [1384, ["k"]], [1406, ["k", "b"]], [1669, ["k"]],
			[1900, ["b", "b"]], [2123, ["k"]], [2347, ["k"]], [2601, ["b", "b"]],
			[2872, ["k", "b"]], [2894, ["k"]], [3171, ["k"]], [3477, ["k"]],
			[3741, ["k", "k"]], [3763, ["b", "b"]], [3972, ["b", "k"]], [4213, ["k"]],
			[4235, ["k", "k"]], [4497, ["k", "b"]],
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
		"collect_time": 290.0,
		"ing_times": [29.0, 137.0, 234.0],
		"boss_name": "GARGOLA VIRAL",
		"boss_hp": 700.0,
		"boss_time": 260.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 5840.0,
		"arena_x": 5360.0,
		"ingredient_spots": [Vector2(1060, 30), Vector2(2238, 52), Vector2(5140, 44)],
		"platforms": [
			# Recorrido ampliado: se repite un tramo antes del último compuesto (x 2858 a 4458).
			[140, 150, 72], [246, 108, 60], [370, 66, 56], [510, 126, 64],
			[730, 152, 64], [828, 110, 52], [918, 68, 48], [1032, 44, 56],
			[1188, 120, 52], [1350, 152, 56], [1444, 110, 50], [1540, 66, 48],
			[1672, 58, 56], [1810, 126, 64], [1980, 150, 72], [2086, 108, 60],
			[2210, 66, 56], [2350, 126, 64], [2570, 152, 64], [2668, 110, 52],
			[2758, 68, 48], [2950, 152, 56], [3044, 110, 50], [3140, 66, 48],
			[3272, 58, 56], [3410, 126, 64], [3580, 150, 72], [3686, 108, 60],
			[3810, 66, 56], [3950, 126, 64], [4170, 152, 64], [4268, 110, 52],
			[4358, 68, 48], [4472, 44, 56], [4628, 120, 52], [4790, 152, 56],
			[4884, 110, 50], [4980, 66, 48], [5112, 58, 56], [5250, 126, 64],
			[5416, 150, 66], [5530, 116, 66], [5650, 150, 66], [5756, 116, 66],
		],
		"boxes": [
			[269, ["k", "k"]], [580, ["k", "k"]], [848, ["b"]], [1166, ["k"]],
			[1494, ["k", "k"]], [1711, ["k", "k"]], [1939, ["b", "b"]], [1961, ["k"]],
			[2178, ["b", "b"]], [2476, ["k", "b"]], [2780, ["k"]], [3072, ["k", "k"]],
			[3094, ["k"]], [3349, ["b"]], [3371, ["b"]], [3695, ["b"]],
			[3907, ["b"]], [3929, ["k"]], [4174, ["b"]], [4456, ["b", "k"]],
			[4694, ["k", "b"]], [4984, ["b", "b"]],
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
	{
		"tag": "NIVEL 4",
		"name": "LA PISTA",
		"music": "roof",
		"boss_music": "boss3",
		"collect_time": 290.0,
		"ing_times": [29.0, 137.0, 234.0],
		"boss_name": "EL MARCIANO",
		"boss_hp": 760.0,
		"boss_time": 270.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 5840.0,
		"arena_x": 5360.0,
		"ingredient_spots": [Vector2(884, 50), Vector2(2760, 30), Vector2(5000, 44)],
		"platforms": [
			# Recorrido ampliado: se repite un tramo antes del último compuesto (x 3050 a 4650).
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64],
			[1056, 126, 72], [1200, 152, 56], [1286, 110, 60], [1370, 74, 52],
			[1462, 74, 56], [1560, 132, 72], [1840, 150, 72], [1946, 108, 60],
			[2070, 66, 56], [2210, 126, 64], [2430, 152, 64], [2528, 110, 52],
			[2618, 68, 48], [2732, 44, 56], [2888, 120, 52], [3062, 74, 56],
			[3160, 132, 72], [3440, 150, 72], [3546, 108, 60], [3670, 66, 56],
			[3810, 126, 64], [4030, 152, 64], [4128, 110, 52], [4218, 68, 48],
			[4332, 44, 56], [4488, 120, 52], [4650, 152, 56], [4744, 110, 50],
			[4840, 66, 48], [4972, 58, 56], [5110, 126, 64], [5416, 150, 66],
			[5530, 116, 66], [5650, 150, 66], [5756, 116, 66],
		],
		"boxes": [
			[305, ["b"]], [530, ["k", "k"]], [731, ["b", "b"]], [987, ["k", "b"]],
			[1009, ["k"]], [1235, ["b", "b"]], [1416, ["k"]], [1438, ["k"]],
			[1741, ["b"]], [2059, ["k", "k"]], [2375, ["k", "b"]], [2567, ["b"]],
			[2895, ["b", "b"]], [3137, ["k", "b"]], [3442, ["k", "b"]], [3747, ["k"]],
			[3927, ["b"]], [3949, ["b"]], [4183, ["b", "k"]], [4442, ["k"]],
			[4635, ["b"]], [4836, ["b", "k"]], [5030, ["k", "k"]], [5052, ["b", "b"]],
		],
		"spawn": {"fire": [2.2, 1.1], "bat": [4.0, 2.1], "spore": [4.8, 2.4], "bolt": 10.0},
		"tint": Color(1.0, 0.7, 0.45),
		"story": "Un helicoptero aterriza en la pista.\nEl virus no fue un accidente:\nun Marciano lo trajo a la Tierra.\nDetenlo antes de que escape.",
		"ingredients": [
			["NUCLEO ALIENIGENA", Color(0.5, 1.0, 0.55)],
			["ANTENA ESTELAR", Color(1.0, 0.8, 0.35)],
			["POLVO DE METEORITO", Color(1.0, 0.55, 0.35)],
		],
	},
	{
		"tag": "NIVEL 5",
		"name": "LAS RUINAS",
		"music": "background",
		"boss_music": "boss2",
		"collect_time": 320.0,
		"ing_times": [28.0, 153.0, 264.0],
		"boss_name": "LA CALAVERA",
		"boss_hp": 820.0,
		"boss_time": 300.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 6200.0,
		"arena_x": 5720.0,
		"ingredient_spots": [Vector2(884, 50), Vector2(2760, 30), Vector2(5448, 64)],
		"platforms": [
			# Recorrido ampliado: se repite un tramo antes del último compuesto (x 3288 a 4888).
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64],
			[1056, 126, 72], [1200, 152, 56], [1286, 110, 60], [1370, 74, 52],
			[1462, 74, 56], [1560, 132, 72], [1840, 150, 72], [1946, 108, 60],
			[2070, 66, 56], [2210, 126, 64], [2430, 152, 64], [2528, 110, 52],
			[2618, 68, 48], [2732, 44, 56], [2888, 120, 52], [3050, 152, 56],
			[3144, 110, 50], [3240, 66, 48], [3440, 150, 72], [3546, 108, 60],
			[3670, 66, 56], [3810, 126, 64], [4030, 152, 64], [4128, 110, 52],
			[4218, 68, 48], [4332, 44, 56], [4488, 120, 52], [4650, 152, 56],
			[4744, 110, 50], [4840, 66, 48], [4972, 58, 56], [5110, 126, 64],
			[5220, 150, 72], [5320, 112, 60], [5420, 78, 56], [5540, 128, 64],
			[5640, 152, 60], [5776, 150, 66], [5890, 116, 66], [6010, 150, 66],
			[6116, 116, 66],
		],
		"boxes": [
			[261, ["k", "b"]], [489, ["b"]], [511, ["k"]], [685, ["k", "b"]],
			[707, ["k"]], [896, ["b", "b"]], [1081, ["k", "b"]], [1351, ["b", "k"]],
			[1564, ["b", "b"]], [1853, ["b"]], [1875, ["b", "k"]], [2190, ["k"]],
			[2212, ["k", "b"]], [2413, ["k", "b"]], [2435, ["b"]], [2623, ["b"]],
			[2844, ["k", "b"]], [2866, ["k", "k"]], [3154, ["k", "b"]], [3357, ["k", "b"]],
			[3572, ["k", "b"]], [3594, ["b", "b"]], [3772, ["k"]], [3794, ["b", "b"]],
			[3985, ["k"]], [4007, ["k"]], [4239, ["k"]], [4552, ["k", "k"]],
			[4862, ["b"]], [4884, ["b"]], [5060, ["k", "b"]], [5354, ["b", "b"]],
			[5528, ["b", "b"]], [5550, ["b", "k"]],
		],
		"spawn": {"fire": [2.0, 1.0], "bat": [3.8, 2.0], "spore": [4.6, 2.3], "bolt": 9.0},
		"tint": Color(1.0, 0.5, 0.4),
		"story": "La ciudad arde en ruinas.\nEl virus nacio de algo mas antiguo:\nuna Calavera gigante que despierta\nentre los escombros. Detenla.",
		"ingredients": [
			["HUESO ANTIGUO", Color(0.95, 0.93, 0.8)],
			["CENIZA ARDIENTE", Color(1.0, 0.55, 0.25)],
			["LLAMA VERDE", Color(0.5, 1.0, 0.45)],
		],
	},
]

func collect_time(i: int) -> float:
	return LEVELS[i]["collect_time"] * time_mult

func boss_time(i: int) -> float:
	return LEVELS[i]["boss_time"] * time_mult
