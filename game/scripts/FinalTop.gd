extends "res://scripts/Level.gd"

# Modo FINALTOP: solo jefes. Cada nivel aporta su arena y su jefe, uno tras otro, con el reloj
# corriendo. Gana quien termine en el menor tiempo.
#   - El reloj cuenta solo mientras se pelea (no en las entradas ni en las pantallas de KO).
#   - Cada derrota se reintenta en el mismo jefe, con todas las vidas, y suma una penalización.
#   - El último jefe tiene muchísima vida (Cfg.FINALTOP.boss_hp) y suelta corazones cada tanto.
#   - No usa ni borra la partida guardada de la historia.

var heart_t := 0.0
var heart_turn := 0


func level_data() -> Dictionary:
	var d: Dictionary = Cfg.LEVELS[index].duplicate(true)
	d["boss_hp"] = float(Cfg.FINALTOP["boss_hp"][index])
	d["boss_time"] = 99999.0
	d["boss_powerups"] = Cfg.FINALTOP["powerups"].duplicate(true)
	return d


func _ready() -> void:
	is_finaltop = true
	start_phase = "boss"
	super._ready()


# Sin límite de tiempo por jefe: el reto es el reloj global.
func boss_left() -> float:
	return 99999.0


func counts_play_time() -> bool:
	return st == S.BOSS and is_instance_valid(boss) and boss.st in [Boss.St.FIGHT, Boss.St.PHASE]


func _boss_phase(delta: float) -> void:
	super._boss_phase(delta)
	if not can_use_powerups():
		return
	heart_t += delta
	if heart_t < float(Cfg.FINALTOP["heart_every"]) or GameManager.hp > 2:
		return
	for child in get_children():
		if child.get_script() == Pickup and child.kind == "boss_heart" and not child.is_queued_for_deletion():
			return
	heart_t = 0.0
	var spots := [120.0, 300.0, 210.0]
	var pk := Pickup.new()
	pk.kind = "boss_heart"
	pk.position = Vector2(arena_x + spots[heart_turn % spots.size()], Cfg.FLOOR_Y - 14.0)
	pk.life = 20.0
	add_child(pk)
	heart_turn += 1
	Fx.burst(self, pk.position, Color(1.0, 0.35, 0.5), 10, 55.0, 0.5, 2.0)
	AudioManager.sfx("pickup", -6.0)
