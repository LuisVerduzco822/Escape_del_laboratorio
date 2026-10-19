extends Node

const W := 480
const H := 270
const FLOOR_Y := 192.0
const MAX_HP := 4
const DEBUG_KEYS := false
# Cada nivel tiene 3 compuestos; con 4 niveles el antidoto necesita 12.
const ING_TOTAL := 12

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
const LEGACY_BOSS_HP := [880.0, 940.0, 920.0, 1000.0]

# Modo FINALTOP: solo jefes, uno tras otro, con el reloj corriendo. Gana el menor tiempo.
const FINALTOP := {
	"name": "FINALTOP",
	"boss_hp": [520.0, 600.0, 900.0, 2800.0],   # el marciano (último jefe) tiene muchísima vida
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
		"collect_time": 200.0,
		"ing_times": [20.0, 92.0, 160.0],
		"boss_name": "GELATINA MUTANTE",
		"boss_hp": 640.0,
		"boss_time": 240.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 3260.0,
		"arena_x": 2780.0,
		"ingredient_spots": [Vector2(856, 44), Vector2(1692, 56), Vector2(2620, 48)],
		"platforms": [
			# Primer tramo: los saltos de siempre.
			[140, 150, 96], [250, 108, 80], [320, 70, 64], [438, 126, 88],
			[600, 150, 76], [710, 104, 60], [824, 58, 64], [942, 116, 60],
			[1080, 150, 64], [1160, 106, 52], [1254, 62, 52], [1340, 126, 64],
			# Segundo tramo: mismo ritmo de saltos, para alargar el camino hacia el jefe.
			[1480, 150, 96], [1590, 108, 80], [1660, 70, 64], [1778, 126, 88],
			[1940, 150, 76], [2050, 104, 60], [2164, 58, 64], [2282, 116, 60],
			[2420, 150, 64], [2500, 106, 52], [2594, 62, 52], [2680, 126, 64],
			# La arena del jefe conserva espacio para esquivar en el suelo.
			[2824, 146, 84], [2978, 146, 84], [3132, 146, 84],
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
		"boss_hp": 680.0,
		"boss_time": 250.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 3720.0,
		"arena_x": 3240.0,
		"ingredient_spots": [Vector2(976, 50), Vector2(1920, 64), Vector2(3050, 60)],
		"platforms": [
			# Primer tramo: los saltos de siempre.
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64],
			[1056, 126, 72], [1200, 152, 56], [1286, 110, 60], [1370, 74, 52],
			[1462, 74, 56], [1560, 132, 72],
			# Segundo tramo: mismo ritmo de saltos, para alargar el camino hacia el jefe.
			[1704, 152, 96], [1818, 114, 76], [1890, 78, 60], [2006, 132, 80],
			[2220, 150, 80], [2334, 108, 64], [2414, 64, 60], [2504, 64, 64],
			[2616, 126, 72], [2760, 152, 56], [2846, 110, 60], [2930, 74, 52],
			[3022, 74, 56], [3120, 132, 72],
			# La arena del jefe conserva espacio para esquivar en el suelo.
			[3268, 150, 72], [3444, 112, 72], [3620, 150, 72],
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
		"boss_hp": 700.0,
		"boss_time": 260.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 4240.0,
		"arena_x": 3760.0,
		"ingredient_spots": [Vector2(1060, 30), Vector2(2238, 52), Vector2(3540, 44)],
		"platforms": [
			# Primer tramo: los saltos de siempre.
			[140, 150, 72], [246, 108, 60], [370, 66, 56], [510, 126, 64],
			[730, 152, 64], [828, 110, 52], [918, 68, 48], [1032, 44, 56],
			[1188, 120, 52], [1350, 152, 56], [1444, 110, 50], [1540, 66, 48],
			[1672, 58, 56], [1810, 126, 64],
			# Segundo tramo: mismo ritmo de saltos, para alargar el camino hacia el jefe.
			[1980, 150, 72], [2086, 108, 60], [2210, 66, 56], [2350, 126, 64],
			[2570, 152, 64], [2668, 110, 52], [2758, 68, 48], [2872, 44, 56],
			[3028, 120, 52], [3190, 152, 56], [3284, 110, 50], [3380, 66, 48],
			[3512, 58, 56], [3650, 126, 64],
			# La arena del jefe conserva espacio para esquivar en el suelo.
			[3816, 150, 66], [3930, 116, 66], [4050, 150, 66], [4156, 116, 66],
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
		"collect_time": 200.0,
		"ing_times": [20.0, 96.0, 164.0],
		"boss_name": "EL MARCIANO",
		"boss_hp": 760.0,
		"boss_time": 270.0,
		"boss_powerups": BOSS_POWERUPS,
		"world_width": 4240.0,
		"arena_x": 3760.0,
		"ingredient_spots": [Vector2(884, 50), Vector2(2760, 30), Vector2(3400, 44)],
		"platforms": [
			# Primer tramo: saltos del laboratorio y las alcantarillas.
			[144, 152, 96], [258, 114, 76], [330, 78, 60], [446, 132, 80],
			[660, 150, 80], [774, 108, 64], [854, 64, 60], [944, 64, 64],
			[1056, 126, 72], [1200, 152, 56], [1286, 110, 60], [1370, 74, 52],
			[1462, 74, 56], [1560, 132, 72],
			# Segundo tramo: los saltos finos de la azotea.
			[1840, 150, 72], [1946, 108, 60], [2070, 66, 56], [2210, 126, 64],
			[2430, 152, 64], [2528, 110, 52], [2618, 68, 48], [2732, 44, 56],
			[2888, 120, 52], [3050, 152, 56], [3144, 110, 50], [3240, 66, 48],
			[3372, 58, 56], [3510, 126, 64],
			# La arena del jefe conserva espacio para esquivar en el suelo.
			[3816, 150, 66], [3930, 116, 66], [4050, 150, 66], [4156, 116, 66],
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
]

func collect_time(i: int) -> float:
	return LEVELS[i]["collect_time"] * time_mult

func boss_time(i: int) -> float:
	return LEVELS[i]["boss_time"] * time_mult
