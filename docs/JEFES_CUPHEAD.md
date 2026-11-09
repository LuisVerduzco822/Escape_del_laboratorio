# Jefes estilo Cuphead

## Reloj sin límite
Ya no hay tope de tiempo por jefe (antes eran ~20 minutos en total). El **RELOJ** del HUD corre desde que empieza la partida hasta que se forma el antídoto, y esa marca es la que va al ranking de tiempo.

## Coreografías
En la historia cada jefe sigue una **secuencia fija por fase** (`Boss.SCRIPT`), así que los patrones se aprenden. En FINALTOP los ataques siguen saliendo al azar. Nunca se repite el mismo ataque dos veces seguidas, y la posición en la secuencia se guarda en la partida.

## Ataques nuevos
| Jefe | Ataques nuevos | Cómo se esquivan |
|---|---|---|
| Slime | **Salto gigante** (`hop`): salta en arco hasta tu columna marcada y al caer lanza ondas | salir de la columna roja y saltar las ondas |
| Slime | **Marea de baba** (`tsunami`): olas bajas desde los bordes, alternadas | saltarlas; la rosa se puede parry |
| Pulpo | **Burbujas de tinta** (`bubbles`): cortina de burbujas ondulantes | colarse entre ellas; las rosas, parry |
| Pulpo | **Cerco** (`closing`): un aro de tinta se cierra sobre ti | salir por el hueco |
| Gárgola | **Tormenta de plumas** (`featherstorm`): abanico que frena y vuelve como bumerán | moverse; hay que esquivarlas dos veces |
| Gárgola | **Picada** (`swoop`): cruza la pantalla en curva y roza el piso en la columna marcada | salir de la columna |
| Marciano | **Platillos** (`saucers`): naves ondulantes que disparan un rayo vertical | derribarlas o moverse |
| Marciano | **Órbita** (`orbit`): esferas giran y salen una por una | mirar el orden de disparo |
| Calavera | **Jaula de huesos** (`bonecage`): filas con un hueco que se desplaza | seguir el hueco |
| Calavera | **Barrido láser** (`lasersweep`): los ojos barren el piso como tijeras | saltar el rayo al pasar |

## Fluidez
- Cada ataque empieza con una **anticipación elástica** (el jefe se agacha y se estira).
- Los saltos y picadas dejan **estela de movimiento**.
- Los cambios de fase dan un golpe elástico con destello.
- Más vida: 960 / 1020 / 1050 / 1140 / 1230 en la historia (antes 640 a 820), y 1000 / 1250 / 1700 / 2100 / 5400 en FINALTOP.

Pruebas: `game/tests/cuphead_attacks_test.gd`.
