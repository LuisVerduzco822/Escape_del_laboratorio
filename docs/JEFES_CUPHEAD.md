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

## Repertorio ampliado (13 ataques más)
| Jefe | Ataques |
|---|---|
| Slime | `geyser` (columnas que avanzan hacia ti), `rollball` (bola enorme que cruza el piso), `lob` (gotas en arco) |
| Pulpo | `rising` (burbujas desde el piso), `eightarms` (espiral de ocho brazos), `pincer` (disparos desde los dos bordes) |
| Gárgola | `bombs` (bombas que estallan en esquirlas), `crescents` (cuchillas bajas y altas), `squall` (aguacero de plumas) |
| Marciano | `strike` (columnas de energía con un hueco), `clusters` (bombas de racimo) |
| Calavera | `graveyard` (huesos que brotan), `spirits` (fantasmas derribables), `rollball` |

Las secuencias por fase son más largas (10 a 19 ataques), así que cada pelea dura bastante más antes de repetirse.

## Fluidez
- Cada ataque empieza con una **anticipación elástica** (el jefe se agacha y se estira).
- Los saltos y picadas dejan **estela de movimiento**.
- Los cambios de fase dan un golpe elástico con destello.
- Mucha más vida: 1920 / 2040 / 2100 / 2280 / 2460 en la historia (al inicio eran 640 a 820), y 1500 / 1900 / 2550 / 3150 / 8100 en FINALTOP.

Pruebas: `game/tests/cuphead_attacks_test.gd`.
