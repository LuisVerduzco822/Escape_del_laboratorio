# Jugabilidad

[Volver al proyecto](../README.md) · [Controles](CONTROLES.md)

## Una cura, cinco zonas

La historia alterna exploración y combate. Cada zona contiene tres ingredientes. Recógelos y elimina a los enemigos restantes para abrir la compuerta de la arena; al cruzarla, comienza la presentación del jefe. Al reunir el tercer compuesto dejan de aparecer enemigos nuevos y el HUD indica cuántos quedan. El jugador espera mientras se acomoda la cámara y recupera el control cuando termina la entrada. Después de cada K.O. aparece una salida en una plataforma baja: acércate y pulsa salto cuando veas ENTRAR. La compuerta se abre y da paso al siguiente nivel. La última salida lleva a la fabricación del antídoto; FINALTOP avanza automáticamente entre combates.

| Zona | Recorrido horizontal | Jefe | Vida en Historia | Límite de combate |
|---|---:|---|---:|---:|
| El laboratorio | 4,660 px | Gelatina Mutante | 640 | 4:00 |
| Las alcantarillas | 5,220 px | Pulpo Tóxico | 680 | 4:10 |
| La azotea | 5,840 px | Gárgola Viral | 700 | 4:20 |
| La pista | 5,840 px | El Marciano | 760 | 4:30 |
| Las ruinas | 6,200 px | La Calavera | 820 | 5:00 |

Valores base de [Cfg.gd](../game/scripts/Cfg.gd). El ajuste `time_mult` multiplica los límites. La cámara sigue al jugador durante el recorrido y se fija en la arena durante el jefe. Puedes regresar por un compuesto olvidado antes de cruzar la compuerta.

## Movimiento y combate

- **Salto doble:** la segunda pulsación en el aire inicia una vueltereta de 0.5 s y un ataque de espada. Aterrizar después de la vuelta produce un tajo; el dash cancela ese tajo.
- **Dash:** impulso de 0.18 s, recarga de 0.45 s e inmunidad al daño durante el impulso. Permite un uso en el aire antes de tocar el suelo.
- **Parry:** pulsa salto en el aire cerca de un objeto rosa. El rebote devuelve movilidad y carga energía. Los objetos rosas permiten parry sin dañar por contacto.
- **Súper y ultra:** 50 de energía lanzan un proyectil perforante; con 100 se activa el ultra, que daña enemigos y jefe y elimina peligros. Durante la recolección también concede cinco segundos sin nuevas amenazas.
- **Cajas:** las azules se rompen a disparos y la espada atraviesa las cajas. Las negras son obstáculos resistentes. Las cajas superiores caen cuando pierden su soporte.
- **Enemigos:** bolas de fuego, murciélagos, esporas, robots y drones. Dejan monedas y efectos de impacto o explosión según su tipo.

El [buffer y el coyote time](GAME_FEEL.md) complementan el movimiento. No requieren una acción adicional del jugador.

## Cinco jefes, tres fases

Entre ataques, los jefes cambian de posición y vuelven a orientarse hacia el jugador. Los patrones se eligen según fase y distancia, con variedad y sin repetir inmediatamente el mismo ataque. A menos de 120 px se favorecen patrones cercanos; desde 260 px, ataques a distancia. El intervalo intermedio mezcla ambos.

| Jefe | Poder propio |
|---|---|
| Gelatina Mutante | Proyectiles de baba que dejan charcos y ralentizan al jugador |
| Pulpo Tóxico | Tinta que mancha la pantalla y se desvanece |
| Gárgola Viral | Ráfagas hacia una pared de espinas; el dash permite escapar del empuje |
| El Marciano | Rayo tractor; el dash rompe la abducción |
| La Calavera | Ojos láser que apuntan y después disparan, más rápidos en fases altas |

Las arenas ofrecen ayudas alternadas: **Disparo x3** durante 10 s y **Bomba viral** de 110 de daño. En Historia, la primera aparece a los 3 s y las siguientes cada 11 s de combate activo; caducan a los 12 s y solo hay una disponible a la vez. Las pausas y las transiciones de fase conservan la duración del disparo mejorado.

Los corazones de Historia aparecen a mitad de las fases 1 y 2 si quedan dos vidas o menos, y uno garantizado al comenzar la fase 3. Hay que recogerlos; no se almacenan con la salud completa. El guardado conserva las ayudas y los hitos de aparición.

## FINALTOP

Se desbloquea al terminar la historia. Encadena las cinco arenas sin recorridos de recolección. El reloj cuenta durante el combate; gana el menor tiempo. Una derrota reinicia el jefe y suma 15 s al reloj.

La vida de los jefes pasa a **800 / 1,000 / 1,350 / 1,700 / 4,500**. Las ayudas llegan a los 3 s y después cada 10 s; la bomba inflige 140 de daño. No se permite guardar en este modo y no se modifica el guardado de Historia.

## Tutorial

**TUTORIAL** abre el nivel 0, Protocolo de evacuación. Enseña movimiento, salto, apuntado, disparo, fijar posición, dash, parry, súper, ultra y recogida de compuestos mediante ejercicios dentro del laboratorio. No recibes daño ni registras una partida. Se puede omitir con T, View/Select o el botón OMITIR.

Al terminar, omitir o salir, se vuelve al menú si existe una partida guardada; si no, comienza Historia. El tutorial no sobrescribe esa partida y no permite guardar.

## Guardar, continuar y reintentar

**PAUSA → GUARDAR Y SALIR** guarda y vuelve al menú. **CONTINUAR** muestra una cuenta atrás de tres segundos antes de devolver el control.

- **En el recorrido:** restaura posición, movimiento, estadísticas, objetos, enemigos, peligros, temporizadores y oleadas pendientes.
- **Contra un jefe:** se guarda un checkpoint al comenzar cada fase. Guardar durante un ataque conserva ese inicio de fase; vida, recursos, tiempo y estado del jefe se restauran juntos. La secuencia aleatoria de ataques se conserva.
- **Tras una derrota:** REINTENTAR reinicia el combate completo desde la fase 1, con la vida del jefe y del jugador al máximo. Conserva ingredientes y derrotas; renueva el tiempo y reinicia las ayudas.
- **Invitados:** guardado local; no se sincronizan ni se suben sus resultados al ranking.
- **Cuentas:** el estado detallado también es local y se separa por servidor y usuario. El progreso entre niveles se envía a PostgreSQL.

Una nueva partida reemplaza el guardado de Historia. Al completar la campaña se elimina ese punto de continuación. Para limpiar una instalación anterior, consulta [esta guía](LIMPIAR_JUEGO_ANTERIOR.md).

## Puntuación

| Acción | Puntos |
|---|---:|
| Enemigo: fuego / murciélago / espora / robot / dron | 100 / 150 / 200 / 250 / 220 |
| Parry | 250 |
| Moneda | 10 |
| Ingrediente | 25 monedas |
| Tiempo sobrevivido | 2 por segundo |
| Fase superada | 1,000 |
| Jefe derrotado | 5,000 + 20 por segundo restante |

Los enemigos rosas duplican sus puntos. El combo sube el multiplicador de x1 a x5: aumenta cada cinco enemigos y se pierde al recibir daño o tras cuatro segundos sin vencer a ninguno. También se registra la mayor racha sin daño.
