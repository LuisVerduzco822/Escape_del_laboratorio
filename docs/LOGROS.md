# Logros, corazones y dificultad de los jefes

## Logros (31)
Se guardan por jugador en `user://achievements.cfg` y se ven en **LOGROS** (menú principal). Al desbloquear uno aparece un letrero arriba de la pantalla. El modo práctica (tutorial) y los trucos de pruebas no los otorgan.

| Por nivel (1 a 5) | Condición |
|---|---|
| INTACTO | Pasar el nivel al primer intento sin recibir ningún golpe |
| AL LIMITE | Pasar el nivel al primer intento terminando con una sola vida |
| SIN CAIDAS | Pasar el nivel al primer intento, sin ser derrotado |
| CAZADOR | Derrotar al jefe del nivel |

Cada logro tiene su emoji (PNG en `game/assets/icons/ach/`, generados con `game/tools/make_ach_icons.py` a partir de Noto Color Emoji, SIL OFL 1.1).

Generales: PRIMER PARRY, MAESTRO DEL PARRY (50), INTOCABLE (jefe sin golpes), RELAMPAGO (jefe en menos de 2:30), COLECCIONISTA (150 monedas), PERFECCION (INTACTO en los 5 niveles), ANTIDOTO, SIN DERROTAS, CONTRARRELOJ (menos de 45 min), FINALTOP y FINALTOP LIMPIO.

«Primer intento» significa que en ese nivel no hubo derrotas ni reinicios; un nivel retomado con CONTINUAR no cuenta.

## Corazones en las peleas con jefe
Cada `Cfg.BOSS_HEARTS.every[jefe]` segundos de combate sale un corazón si falta vida (máximo `max[jefe]` por pelea), además de los que ya caían al llegar a la mitad de cada fase. Van de cada 11 s (jefe 1) a cada 19 s (jefe 5). En FINALTOP cae uno cada 16 s si quedan 3 vidas o menos.

## Dificultad progresiva
`Cfg.BOSS_CURVE` ajusta velocidad, descanso y cantidad de proyectiles por jefe: el jefe 1 es el más amable y el 5 es muy difícil. Además `Cfg.PHASE_REST = [1.0, 0.8, 0.52]` reduce el descanso entre ataques en cada fase, así que en la fase final los ataques salen mucho más seguidos.

Pruebas: `game/tests/achievements_test.gd`.

## Fluidez
- La física corre al mismo ritmo que la pantalla (60 a 144 Hz, `GameManager.tune_for_display`) y se fuerza el vsync, para que el movimiento no vaya a tirones en pantallas de 90/120/144 Hz.
- Las imágenes se alinean a píxeles (`snap_2d_transforms_to_pixel`), así que los sprites ya no tiemblan al moverse la cámara.
- El frenazo de los golpes (`Fx.hitstop`) es corto y suave (antes dejaba el juego casi congelado unos milisegundos).

## Más dificultad en las fases de los jefes
`Cfg.PHASE_REST = [1.0, 0.72, 0.45]` (descanso entre ataques), `Cfg.PHASE_COUNT = [1.0, 1.12, 1.25]` (proyectiles por patrón), velocidad +20% por fase y `Cfg.PHASE_COMBO = [0, 0.15, 0.3]`: probabilidad de encadenar el siguiente ataque casi sin pausa.
