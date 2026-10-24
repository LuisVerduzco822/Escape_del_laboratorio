# Práctica 5 · Game feel y juice

[Volver al proyecto](../README.md) · [Parámetros completos](GAME_FEEL.md)

Esta página reúne la evidencia académica. La presentación general del juego, su instalación y galería están en el README.

## Implementación

| Requisito | Estado e implementación | Parámetro |
|---|---|---|
| Input buffering | Pulsación de salto almacenada hasta poder ejecutarse; se consume o caduca en `Player.gd` | 0.10 s |
| Coyote time | Salto normal tras abandonar una superficie, conservando el salto aéreo | 0.09 s |
| Screenshake | Desplazamiento real de `Camera2D.offset` en daño, especiales y eventos de jefes | Daño: 3 px / 0.25 s |
| Feedback | Impactos, partículas, flash, hitstop, sonido, textos y HUD; vibración del mando en disparos e impactos | Daño: hitstop 0.08 s; disparo: pulso de mando 0.035 s |
| Conservar funcionalidades | Se mantienen progreso local, conexión HTTP a PostgreSQL, registro de partidas, leaderboard y panel web | [Arquitectura y validación](DESARROLLO.md) |

El [README](../README.md#game-feel) resume los valores; [GAME_FEEL.md](GAME_FEEL.md) documenta los parámetros restantes y sus límites de verificación.

## Tres capturas de evidencia

### 1. Daño e impacto

![Flash rojo, impacto y pérdida de vida en las alcantarillas](media/capturas/03-dano.png)

La llamada real a `Player.hurt()` produce impacto animado, pérdida de un corazón y flash rojo. También activa hitstop, cámara y vibración; sus duraciones requieren video o prueba durante el juego.

### 2. Recolección de un ingrediente

![Pétalo Lunar recogido, nombre flotante y contador actualizado](media/capturas/02-recoleccion.png)

La recogida actualiza el antídoto a 1/15 y los compuestos del nivel a 1/3, da monedas y energía, y genera partículas, nombre flotante y sonido.

### 3. Combate y disparo potenciado

![Combate contra la Gárgola Viral con un patrón de proyectiles y Disparo x3](media/capturas/05-jefe-azotea.png)

Se observan el patrón de proyectiles, el objeto rosa susceptible de parry, la barra de vida del jefe y el indicador de duración del disparo mejorado.

Las tres son capturas nuevas de escenas preparadas en Godot, sin interfaces añadidas sobre la imagen. [Método y galería completa](CAPTURAS.md).

## Video de Classroom

**Pendiente de grabar y entregar por separado.** Las capturas no sustituyen el video.

Guion propuesto para una demostración corta:

1. **Buffer:** gastar el salto doble, pulsar salto justo antes de aterrizar y mostrar que el personaje salta al tocar el suelo. Repetir pulsando demasiado pronto para contrastar la caducidad.
2. **Coyote:** caminar fuera del borde y saltar dentro de los 90 ms; hacer después el salto doble para mostrar que el salto aéreo seguía disponible.
3. **Screenshake:** recibir un golpe y usar un súper o mostrar un impacto del jefe. Contrastar con el movimiento normal sin vibración de cámara.
4. **Feedback:** recoger un compuesto, disparar y vencer un enemigo. Mantener el audio del juego. Si se usa mando, explicar que el golpe interrumpe el pulso de disparo.
5. **Persistencia:** mostrar el guardado y, con sesión iniciada, el resultado en el ranking local.

## Verificación y entrega

- Código de los cuatro requisitos: implementado.
- Parámetros: en README y en la guía de game feel.
- Tres capturas: incluidas y enlazadas arriba.
- Comprobaciones del juego: 38 suites de regresión; detalle y límites en [Desarrollo](DESARROLLO.md).
- Repositorio: [Escape_del_laboratorio](https://github.com/LuisVerduzco822/Escape_del_laboratorio).
- Video: pendiente de Classroom.

Después de subir estos archivos al repositorio público, las capturas y la documentación quedan disponibles desde su página principal.
