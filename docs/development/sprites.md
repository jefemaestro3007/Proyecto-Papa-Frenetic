# Sprites del jugador

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
| `guardia.png` | `guardia_izquierda`, `guardia_derecha` | Quieto y ataque en el suelo (con el tajo dibujado encima). De espaldas mirando a la izquierda, de frente mirando a la derecha |
| `ataque_aereo.png` | `ataque_aereo` | Ataque en el aire (trae su propio tajo) |

Todos los frames miran a la derecha y se espejan al mirar a la izquierda, salvo la guardia, que
tiene una pose propia para cada lado. La elección de pose está en `PlayerPrototype._pose()`
(`src/features/player/scripts/player_prototype.gd`); el latido, el giro a tiempo, el tambaleo, las
estelas y el parpadeo se siguen aplicando encima del sprite. Si faltan los PNG, el jugador se
dibuja con el rectángulo provisional.

Para agregar una pose: poner la imagen en `assets_src/sprites/player/`, sumarla a `SHEETS` en la
herramienta, agregar el nombre a `PlayerPrototype.SPRITE_NAMES` y elegirla en `_pose()`.

Pendientes (sin dibujo todavía): reposo sin espada, golpe recibido, caída forzada y escaleras /
ascensor.
