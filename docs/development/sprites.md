# Sprites

Los dibujos originales están en `assets_src/sprites/player/` (Godot no los importa). La herramienta
`tools/scripts/build_player_sprites.gd` los convierte en un PNG por frame en
`assets/textures/sprites/player/`, que es lo que usa el juego.

```bash
godot --headless --path . --script res://tools/scripts/build_player_sprites.gd
godot --headless --path . --import
```

## Qué hace la herramienta

1. **Fondo:** si la imagen no tiene transparencia (p. ej. un JPG con el cuadriculado pintado),
   borra el fondo con un relleno desde los bordes que se detiene en el contorno negro, más los
   huecos encerrados que mezclan los tonos del cuadriculado, y las manchas sueltas de compresión.
   Funciona porque los dibujos tienen contorno negro cerrado; lo ideal igual es exportar PNG.
2. **Poses:** separa las poses de cada imagen por las columnas vacías, de izquierda a derecha.
3. **Tamaño:** escala todo a un tamaño común usando la **gorra roja** como referencia (aparece en
   todas las poses). La guardia de frente mide 128 px en pantalla (el personaje colisiona con
   44×88). Se guarda al doble de resolución y el jugador lo dibuja a 0,5.
4. **Ancla:** los pies quedan en el centro del borde inferior del PNG, alineados con el eje de la
   gorra.

## Mapa de poses

| Archivo original | Frames | Cuándo se usa |
|---|---|---|
| `salto_aterrizaje.png` | `aire`, `aterrizaje` | En el aire (salto, caída, caída forzada) · 0,12 s al aterrizar |
| `correr.jpg` | `correr_0`…`correr_3` | Corriendo; 4 frames por beat (el paso va al ritmo) |
| `dash.png` | `dash` | Durante el dash |
| `guardia.png` | `guardia`, `espalda` | `guardia` (de frente): quieto. `espalda`: final del ataque en el suelo |
| `assets_src/sprites/fx/ataque_swing.png` | `fx/ataque_swing` | Tajo del ataque en el suelo (lo genera la herramienta de enemigos y efectos) |
| `ataque_aereo.png` | `ataque_aereo` | Ataque en el aire (trae su propio tajo) |

Todos los frames miran a la derecha y se espejan al mirar a la izquierda (también la guardia).

**Ataque en el suelo** (0,3 s; el golpe se juzga al pulsar): guardia de frente → tajo
(`ataque_swing` delante del personaje, a la altura de la cintura) → de espaldas cerrando el giro →
vuelve a la guardia de frente. Las fases están en `ATTACK_SWING_FROM` y `ATTACK_BACK_FROM`. La elección de pose está en `PlayerPrototype._pose()`
(`src/features/player/scripts/player_prototype.gd`); el latido, el giro a tiempo, el tambaleo, las
estelas y el parpadeo se siguen aplicando encima del sprite. Si faltan los PNG, el jugador se
dibuja con el rectángulo provisional.

Para agregar una pose: poner la imagen en `assets_src/sprites/player/`, sumarla a `SHEETS` en la
herramienta, agregar el nombre a `PlayerPrototype.SPRITE_NAMES` y elegirla en `_pose()`.

Pendientes (sin dibujo todavía): reposo sin espada, golpe recibido, caída forzada y escaleras /
ascensor.

## Enemigos y efectos

`tools/scripts/build_enemy_sprites.gd` toma `assets_src/sprites/enemies/<enemigo>_<pose>.(png|webp)`
y `assets_src/sprites/fx/*` y genera `assets/textures/sprites/enemies/<tipo>_<pose>.png` y
`assets/textures/sprites/fx/*.png`.

```bash
godot --headless --path . --script res://tools/scripts/build_enemy_sprites.gd
godot --headless --path . --import
```

Las tres poses de cada enemigo vienen en el mismo lienzo: se recortan con el mismo rectángulo (no
saltan al cambiar de pose), con los pies abajo al centro del cuerpo de la pose base, y se escalan a
la altura que tienen en el juego (tabla `ENEMIES` de la herramienta).

| Enemigo | Archivos | `base` | `ataque` | `herido` |
|---|---|---|---|---|
| Común (`normal`) | `normal_*` (papa de foto) | Persigue o espera | Cerca del jugador (brazo estirado) | Golpe que aguanta o al morir |
| Tanque (`tank`) | `tanque_*` | Igual que la común | Cerca del jugador (palito) | Igual |
| Embestidora (`charger`) | `embestidora_*` (dos papas) | Merodea | Aviso "!" y carga | Golpe y aturdida tras la carga (con estrellas) |
| Tiradora (`thrower`) | `tiradora_*` (con cresta) | Esperando | Brazo en alto anunciando el patrón y lanzando | Golpe o al morir |
| Voladora (`flyer`) | `voladora_*` (pájaro) | Dormida o lejos | Despierta y cerca (pico abierto) | Golpe o al morir |

**Variaciones de color (experimento):** para diferenciar a las papas sin dibujar más sprites, la
herramienta recolorea los dibujos al generarlos (`-- --original` lo desactiva):

- **Tiradora:** cuerpo del color de la papa común y cresta roja (el corte va donde el borde
  izquierdo del dibujo salta hacia afuera; en la pose de herido está fijado a mano en
  `THROWER_NECK`).
- **Embestidora:** la papa de adelante en negro con su contorno y su cara en rojo; la de atrás roja.
- **Tanque:** negro con las líneas en rojo y un contorno rojo.
- **Voladora y común:** sin cambios.

Los dibujos miran a la izquierda y se espejan al mirar a la derecha. Llevan un contorno con el
color del estilo activo (las papas rojas se pierden contra el cielo rojo sin él), laten con el
beat y se iluminan al recibir un golpe. Los avisos de juego (el "!" y las estrellas de la
embestidora, los puntos del patrón de la tiradora, la vida del tanque) se dibujan encima. La pose
la elige `Enemy.sprite_pose()`, que cada variante redefine; si falta el PNG se dibuja la papa
provisional.

| Efecto | Cuándo |
|---|---|
| `stomp_flecha` | Durante la caída forzada, detrás del jugador, latiendo con el beat |
| `stomp_nube` | Al aterrizar la caída forzada (más grande si fue PERFECTO), encima del estallido de impacto (`ImpactSprite`) |
| `ataque_swing` | Segunda fase del ataque en el suelo del jugador |

## Interfaz: papa del calor

`assets_src/sprites/ui/papa_calor_1…5` (la misma herramienta de enemigos y efectos los genera en
`assets/textures/ui/`). Las cinco etapas se recortan con el mismo rectángulo para que se note
cómo se hincha la papa. `HeatPotato` (`src/ui/hud/heat_potato.gd`) muestra una por cada 20 de
calor, con el manómetro incrustado en el centro (se mueve con la papa: un solo sistema, la "papa
bomba"):

| Calor | Etapa | Además |
|---|---|---|
| 0–20, 20–40, 40–60, 60–80 | 1 a 4 | Late con el beat; golpe de escala al cambiar de etapa |
| 80–100 | 5 (agrietada) | Alarma: vibra y se tambalea cada vez más, halo rojo que late; el manómetro enciende su halo y enrojece el bisel |
| Mecha encendida | 5 | Vibración máxima, parpadeo y vapor |
