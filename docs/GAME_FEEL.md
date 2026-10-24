# Game feel: controles, impactos y vibración

[Volver al proyecto](../README.md) · [Evidencias de la práctica 5](PRACTICA5.md)

Los valores corresponden a la versión actual de [Player.gd](../game/scripts/Player.gd), [Fx.gd](../game/scripts/Fx.gd), [Boss.gd](../game/scripts/Boss.gd) y [Level.gd](../game/scripts/Level.gd). La resolución base es **480 × 270**; los píxeles de cámara se expresan en esa resolución.

## Input buffering

`BUFFER = 0.10 s`. Una pulsación de salto se conserva hasta poder ejecutarse. Se consume al saltar y caduca al agotarse la ventana. El salto doble disponible o un parry válido pueden consumirla inmediatamente: para demostrar el buffer de aterrizaje hay que haber gastado el salto aéreo.

Durante un dash, la pulsación puede esperar a que termine si sigue dentro de la ventana. Las entradas de jefe y otras situaciones que congelan al jugador cancelan el salto pendiente.

## Coyote time

`COYOTE = 0.09 s`. Al abandonar una superficie todavía se puede ejecutar el salto normal durante ese intervalo, conservando el salto aéreo. Después de la ventana, una nueva pulsación puede activar el salto doble si sigue disponible.

La tolerancia se reinicia en el suelo y se consume al saltar. Su funcionamiento es independiente del aspecto visual del personaje.

## Screenshake

`Fx.shake(amplitud, duración)` genera un desplazamiento aleatorio en cada eje, aplicado al `Camera2D.offset`. Si se superponen eventos, conserva la amplitud y la duración restante máximas. El desplazamiento vuelve a cero al terminar.

| Evento | Amplitud | Duración |
|---|---:|---:|
| Daño al jugador | 3 px | 0.25 s |
| Fin de la presentación del jefe | 3.5 px | 0.30 s |
| Súper | 2.5 px | 0.20 s |
| Ultra | 4 px | 0.60 s |
| Impacto de jefe | 5 px | 0.40 s |
| Cambio de fase | 4 px | 0.60 s |
| Inicio de ráfaga de viento | 1.5 px | 0.40 s |
| Disparo de ojos láser | 2 px | 0.30 s |
| Bomba al jefe | 3 px | 0.30 s |
| Derrota del jefe | 5 px | 0.80 s |
| Explosión final del jefe | 6 px | 0.35 s |

Saltar, aterrizar, el tajo de aterrizaje y romper cajas no activan screenshake. El aterrizaje fuerte se reconoce desde `HARD_LAND_V = 300 px/s` y produce polvo y sonido con volumen según velocidad. Así se conserva la lectura de las plataformas durante el movimiento normal.

## Vibración del mando

Las magnitudes de los motores van de 0 a 1.

| Respuesta | Motor débil | Motor fuerte | Duración |
|---|---:|---:|---:|
| Disparo normal o potenciado | 0.18 | 0.04 | 0.035 s |
| Daño, con amplitud de cámara de 3 px | 0.35 | 0.50 | 0.25 s |
| Impacto de 6 px o más | 0.70 | 1.00 | La del screenshake |

Los impactos usan `intensidad = clamp(amplitud / 6, 0, 1)`: el motor fuerte recibe esa intensidad y el débil recibe el 70%. El pulso de disparo no mueve la cámara. Un impacto cancela el pulso actual e impide que disparos posteriores sobrescriban su vibración; al terminar el impacto, los siguientes disparos vuelven a producir pulsos.

Se elige el mando activo; si el teclado tiene el control, se usa el primero conectado. La vibración termina al pausar, perder el foco, cambiar o desconectar el dispositivo, reiniciar efectos o salir. El efecto físico depende del soporte del mando y su controlador.

## Feedback visual, sonoro y de interfaz

| Acción | Respuesta |
|---|---|
| Daño | Impacto animado, sonido, flash rojo de 0.35 de opacidad durante 0.30 s, hitstop de 0.08 s, cámara y rumble; invulnerabilidad durante 1.5 s |
| Disparo | Fogonazo, proyectil con brillo y estela, sonido y pulso de mando |
| Enemigo vencido | Explosión azul para enemigos mecánicos o verde para orgánicos, partículas, puntos flotantes y monedas |
| Moneda | Sonido con variación aleatoria de tono entre 0.95 y 1.15, desaparición del objeto y actualización del contador; imán desde 260 px |
| Ingrediente | Partículas del color del compuesto, nombre flotante, sonido, contador del antídoto, energía y 25 monedas |
| Curación / potenciador | Texto flotante y respuesta sonora; indicador de duración para Disparo x3 |
| Salto doble | Vueltereta de 0.5 s, espada, estela y partículas bajo los pies; sonido de salto más agudo |
| Espada | Chispas e hitstop de 0.04 s contra enemigos, 0.05 s contra jefe; tajo de aterrizaje con partículas |
| Ultra | Flash blanco, hitstop de 0.18 s, anillo, daño, limpieza de peligros y vibración |
| Jefe vencido | Explosiones, puntos y monedas, flash blanco, hitstop de 0.35 s y aviso de K.O. |

`Fx.hitstop` reduce temporalmente `Engine.time_scale` a **0.05** y utiliza un temporizador que ignora esa escala para recuperarla. Un token evita que una pausa anterior interrumpa un impacto más reciente. `Fx.reset()` restaura el tiempo y limpia flashes, cámara y vibración.

La mezcla actual usa `MUSIC_DB = -7.5`, compensación de WAV de `-5.0` y `SFX_DB = -3.0`, además de ajustes por efecto. Los disparos y monedas tienen límites de repetición y voces para evitar saturación. Las pistas y sus créditos se describen en [Créditos](CREDITOS.md).

## Pruebas y límites de la evidencia

```bash
python3 game/tools/run_tests.py --jobs 3 screen_shake_test rumble_test combat_effects_test double_jump_test resource_lifecycle_test
```

- `screen_shake_test.gd`: eventos de cámara, rechazo de daño durante invulnerabilidad y ausencia de sacudida en movimiento normal.
- `rumble_test.gd`: prioridad de impactos sobre disparos, magnitudes, duración, selección de dispositivo, interrupciones y liberación de partículas. Simula dispositivos; no sustituye una prueba física del mando.
- `combat_effects_test.gd`: animaciones, coordenadas, vida de efectos y limpieza al eliminar actores y niveles.
- `double_jump_test.gd`: salto normal, salto aéreo, vueltereta y recuperación al aterrizar.
- `resource_lifecycle_test.gd`: cambios de escena repetidos, nodos huérfanos, efectos pendientes y cierre de audio.

El buffer y el coyote están implementados en el controlador; estas suites no contienen una prueba dedicada que mida sus dos ventanas. Para la demostración de entrega se deben grabar los casos descritos en [Práctica 5](PRACTICA5.md). Una captura estática no demuestra duración, vibración física ni audio.
