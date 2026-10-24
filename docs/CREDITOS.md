# Créditos y licencias

[Volver al proyecto](../README.md)


- Íconos de mando: **Gamepad Inputs UI**, de **Gimicko / GoncaloMCOliveira**, CC0 1.0 Universal.
  [Página proporcionada por el autor del proyecto](https://gimicko.itch.io/gamepad-inputs-ui) ·
  [Página publicada del pack](https://goncalomcoliveira.itch.io/gamepad-inputs-ui).
  Los cinco tilesets utilizados están en `game/assets/ui/gamepad/`, junto con `CREDITS.txt`;
  el juego usa sus regiones sin anti-aliasing. Se omitió el material del pack que no se utiliza. La atribución también aparece en Controles → Mecánicas.
- Lanzallamas (`game/assets/weapons/Flamethrower.png`): Player 24 (MainMenuMaster), [2D Pixel Art Weapon Pack – Melee & Modern Arsenal](https://mainmenumaster.itch.io/weapons-axe-blade-pipe-chainsaw-flamethrowerorb). Recurso proporcionado por el autor del proyecto; la página del pack no especifica una licencia.
- Fondos, sprite de bola de fuego y fuente Press Start 2P (SIL OFL 1.1): proporcionados por el autor.
- Pack Modern Interiors Free v2.2 (personaje Adam): uso no comercial.
- Capas de parallax, jefes, partículas procedurales y música: generados para este proyecto.
- Compuertas: **Kenney**, Pixel Platformer Industrial Expansion, CC0 1.0 Universal. Los avisos originales se conservan junto al recurso y en los créditos del juego.
- Sonidos seleccionados: **FilmCow Royalty Free SFX Library**, Jason Steele. Se conservan sus condiciones en [la licencia incluida](../game/assets/audio/filmcow/LICENSE.pdf). Es una licencia propia; no se presentan estos sonidos como CC0 ni como obra del equipo.
- Efectos animados: **Battle Effects**, de **pimen**, [fuente](https://pimen.itch.io/pixel-battle-effects),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). `Effect 2 - Sprite Sheet.png` se copia sin modificar
  como `game/assets/effects/pimen/hit.png`; se seleccionan sus cuatro cuadros activos y se ajustan escala/velocidad.
  Atribución y enlace de licencia en el menú **CRÉDITOS** y junto al PNG. Conservar estos avisos al distribuir.
- Explosiones: **Explosions - Pixel Art**, de **Aim studios**, [fuente](https://aim-studios.itch.io/explosions-pixel-art),
  [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). Tres PNG originales, renombrados,
  en `game/assets/effects/aim_studios/`; se ajustan escala/velocidad. Crédito voluntario en el juego y en
  `game/assets/effects/CREDITS.txt`. Las licencias de recursos no cambian la licencia del código.

### Selección de efectos de combate

- Robots, drones y bolas de fuego: explosión azul compacta. Murciélagos y esporas: explosión verde orgánica.
- Daño no letal a enemigos y golpes aceptados por el jugador: destello dorado corto; la invulnerabilidad evita repetirlo.
- Jefes: explosiones escalonadas y una explosión final grande; el cuerpo permanece opaco y desaparece
  de golpe a mitad de esa explosión.
- Animaciones compartidas, filtro nearest y máximo de 32 efectos simultáneos (el remate del jefe siempre se muestra).
  Los efectos pertenecen al nivel: sobreviven al enemigo y se eliminan al terminar o cambiar de nivel.

## Música

| Zona | Pista |
|---|---|
| Menú y acceso | Containment Lockdown |
| Laboratorio | Sector Lockdown |
| Alcantarillas | Iron Gate Assault |
| Azotea | Hardened Core |
| Pista | Point of Impact |
| Ruinas | Cinders of the Spire |

Las pistas OGG se prepararon con bucles y volumen normalizado. La canción de cada nivel continúa durante su combate de jefe. Los ajustes de mezcla están documentados en [Game feel](GAME_FEEL.md).
