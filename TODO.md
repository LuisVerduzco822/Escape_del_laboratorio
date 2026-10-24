# Revisión de sonidos

Selección actualizada según escucha del usuario (24 de octubre de 2026). Esta lista reemplaza la selección anterior para estos eventos. **Súper** es el ataque de media barra (50); **ultra**, el de barra completa (100).

## Selección vigente

| Evento | FilmCow original | Duración preparada |
| --- | --- | --- |
| drone_move_6 | FilmCow Recorded SFX/vape sound 6.wav | 4.906 s |
| drone_move_3 | FilmCow Recorded SFX/vape sound 3.wav | 3.584 s |
| drone_move_1 | FilmCow Recorded SFX/vape sound 1.wav | 3.717 s |
| robot_step_9 | FilmCow Recorded SFX/metal hit with hammer 9.wav | 0.203 s |
| robot_step_8 | FilmCow Recorded SFX/metal hit with hammer 8.wav | 0.202 s |
| robot_step_3 | FilmCow Recorded SFX/metal hit with hammer 3.wav | 0.187 s |
| robot_step_2 | FilmCow Recorded SFX/metal hit with hammer 2.wav | 0.205 s |
| player_death_14 | FilmCow Recorded SFX/oof 14.wav | 0.423 s |
| player_death_9 | FilmCow Recorded SFX/oof 9.wav | 0.247 s |
| player_death_8 | FilmCow Recorded SFX/oof 8.wav | 0.384 s |
| player_death_6 | FilmCow Recorded SFX/oof 6.wav | 0.394 s |
| player_death_5 | FilmCow Recorded SFX/oof 5.wav | 0.305 s |
| player_hurt_3 | FilmCow Recorded SFX/body hit with grunt 3.wav | 0.214 s |
| player_hurt_2 | FilmCow Recorded SFX/body hit with grunt 2.wav | 0.213 s |
| player_hurt_1 | FilmCow Recorded SFX/body hit with grunt 1.wav | 0.221 s |
| elevator_open | FilmCow Recorded SFX/screen door open 1.wav | 0.457 s |
| ultra | FilmCow Designed SFX/deep sci fi stinger 8.wav | 1.333 s |
| parry | FilmCow Recorded SFX/metal hit floor small 4.wav | 0.354 s |
| dash | FilmCow Recorded SFX/swoosh 3.wav | 0.477 s |
| super | FilmCow Designed SFX/laser gun 1.wav | 0.938 s |
| death_robot | FilmCow Recorded SFX/metal sliding 5.wav | 0.656 s |
| death_drone | FilmCow Designed SFX/robot sick 2.wav | 1.898 s |
| death_bat | FilmCow Recorded SFX/sipping through empty straw 2.wav | 0.450 s |
| death_spore | FilmCow Recorded SFX/bubbles 1.wav | 0.480 s |
| death_fireball | FilmCow Recorded SFX/spray bottle 3.wav | 0.332 s |
| robot_shoot | FilmCow Designed SFX/laser gun 11.wav | 0.400 s |
| drone_shoot | FilmCow Designed SFX/laser gun 14.wav | 0.350 s |
| robot_charge | FilmCow Designed SFX/sci fi click 5.wav | 0.300 s |
| drone_charge | FilmCow Designed SFX/sci fi click 9.wav | 0.220 s |
| bat_flap | FilmCow Recorded SFX/swoosh 1.wav | 0.160 s |
| spore_land | FilmCow Recorded SFX/squishy and wet 3.wav | 1.142 s |
| spore_roll | FilmCow Recorded SFX/paper crunchy 3.wav | 0.821 s |

Los grupos `player_hurt`, `player_death`, `robot_step` y `drone_move` alternan todas sus variantes en el orden indicado en `AudioManager.VARIANTS`. Daño y muerte del jugador tienen eventos propios: los errores de interfaz y el fin por tiempo conservan sus sonidos anteriores. La muerte reproduce el oof al comenzar el colapso del jugador.

La espora no emite sonido durante la caída. Sí lo hace una vez al aterrizar y periódicamente mientras rueda. El acceso reproduce `screen door open 1` al comenzar a abrir las hojas; «screnn» se interpretó como el archivo local `screen`. El mismo acceso animado se reutiliza para las salidas de todos los niveles.

Se mantienen disparos normales del jugador, disparos y cargas de robot/dron, aleteo de murciélago, muerte de espora y demás eventos no sustituidos por el usuario. Las elecciones anteriores que permanecen están en `selection.json`; la selección regenerable actual está en `enemy_selection.json`.

## Preparación y mezcla

- Script: `game/tools/prepare_enemy_audio.py`; requiere los originales locales, ffmpeg y numpy. Las muestras elegidas por el usuario conservan el tramo activo completo, sin los límites cortos de la selección inicial. Se recortan silencios al 2.5 % del pico y se aplican fundidos breves.
- WAV mono de 16 bits a 44.1 kHz; paso alto 75 Hz y paso bajo 12 kHz; objetivo -20 dBFS RMS con techo -3 dBFS. El techo puede impedir alcanzar el objetivo RMS; los valores reales están en el manifiesto.
- Buses de Godot creados al arrancar: `Music → Master`, `Movement → SFX → Master`, `SFX → Master`. SFX: paso alto 65 Hz, compresor -22 dB, 3:1, ataque 2 ms, recuperación 120 ms y compensación +3 dB. Master: limitador con techo -1.5 dBFS, sin ganancia previa y recuperación 120 ms.
- Ganancia base SFX -3 dB; música -7.5 dB más compensación WAV. Movimiento atenuado por evento y separado en cuatro voces; doce voces para combate. Muertes, daño, parry, avisos y apertura pueden reemplazar la voz de combate más antigua.
- Entidades fuera de cámara silenciosas y atenuación por distancia hasta -10 dB. Separación mínima de 120 ms para movimiento y 40 ms para otros eventos.

## Verificación pendiente de escucha

- [ ] Escuchar súper y ultra con música, comprobar inicio y cola. Se conserva el tramo activo del stinger 8.
- [ ] Comprobar que las tres variantes de daño y cinco de muerte se entiendan y mantengan volumen parecido; el golpe mortal reproduce daño seguido de oof.
- [ ] Revisar repetición de muertes por especie y pasos metálicos; ajustar `ENTITY_DB` si sobresalen o se pierden.
- [ ] Escuchar las tres variantes vape del dron con varios drones presentes: comprobar que las colas no se amontonen.
- [ ] Revisar sincronía de puerta, parry, aterrizaje y rodadura.
- [ ] Comprobar que la compresión no produzca bombeo y que las alertas destaquen con muertes masivas; verificar con auriculares y altavoces pequeños.

Prueba automatizada: `game/tests/enemy_audio_test.gd` comprueba recursos, variantes, buses, filtros, prioridad de voces y aterrizaje único. Las pruebas no certifican el resultado perceptivo de la mezcla.

## Procedencia

FilmCow Royalty Free SFX Library, Jason Steele. Licencia original en `game/assets/audio/filmcow/LICENSE.pdf`. Designed = FilmCow Designed SFX; recorded = FilmCow Recorded SFX. Las fuentes exactas y métricas están en los manifiestos JSON. GunsPack local contiene únicamente imágenes, no audio.


## Ajuste de sonidos repetitivos

- Disparos del jugador normales y potenciados: 5 dB menos que antes, intervalo sonoro compartido mínimo de 120 ms y máximo dos colas simultáneas. La frecuencia real de proyectiles no cambia.
- Monedas: 7 dB menos, mínimo 180 ms entre avisos y una sola voz simultánea. Se omiten avisos redundantes de una recogida masiva; se conserva el valor de todas las monedas y no se reproducen avisos atrasados.
- Estos límites no afectan muertes, daño ni alertas. La prueba de audio comprueba agrupación de monedas, límites compartidos de disparos y que el daño se siga reproduciendo.
- [ ] Escuchar disparo sostenido mientras se recogen monedas y mueren enemigos; comprobar que las muertes y los avisos destaquen sin perder feedback de disparo/recogida.

Muerte del murciélago: reducida de 2.43 s a 0.45 s, conservando el inicio y un fundido final de 30 ms para evitar un corte brusco. El límite también está en el script de preparación.
