# Arquitectura

Visión general del código del juego. Todo está en GDScript (Godot 4.7, renderer
GL Compatibility). Lo procedural es **determinista**: misma seed + mismos parámetros ⇒
mismo resultado.

## Mapa de módulos

```
src/
├── core/autoloads/conductor.gd        # Conductor: reloj musical global (BPM, beat, juicio)
├── core/autoloads/settings.gd         # Settings: configuración del jugador (audio, video, teclas, dificultad)
├── features/
│   ├── player/                        # PlayerPrototype + PlayerParams
│   ├── rhythm/                        # RhythmTracker (combo/puntaje) + RhythmParams + MusicTrack
│   ├── audio/                         # SfxPlayer + SoundEffect (efectos de sonido)
│   ├── combat/                        # CombatController, HeatMeter, GameFeel, ImpactBurst + params
│   └── enemies/                       # Enemy (común) + tanque, voladora, embestidora, tiradora, EnemyRoster
├── world/
│   ├── generation/                    # generadores puros (sin nodos)
│   │   ├── azotea_*.gd                # zona Azotea
│   │   ├── oficinas/                  # zona Oficinas (layout = topología, generator = geometría)
│   │   └── map_mark.gd, frenetic_palette.gd
│   ├── environment/                   # dibujo y ambiente
│   │   ├── styled_canvas.gd           # primitivas con ArtStyle (contorno, trazo a mano...)
│   │   ├── rooftop_view.gd, interior_view.gd, area_view.gd, skyline_view.gd
│   │   ├── *_live_view.gd, flies_view.gd, vision_mask.gd
│   │   ├── chunk_canvas.gd, chunked_view.gd, spatial_index.gd   # dibujar solo lo visible
│   │   ├── art_style.gd, sky_params.gd, lighting_params.gd
│   │   └── shaders/                   # sky, ruin_grunge, frenetic_post
│   ├── interactables/                 # Elevator, WallDoorNode, KeyPickup
│   └── levels/
│       ├── zone_level.gd              # ZoneLevel: base común de todas las zonas
│       ├── azotea/                    # escena + script de la zona
│       └── oficinas/                  # escena + script + bot + vista del grafo
├── ui/
│   ├── components/debug_section.gd    # pestaña del menú de debug (sliders, colores, presets)
│   ├── menus/debug_menu.gd            # menú de debug con pestañas
│   ├── menus/settings_screen.gd       # SETTINGS (SettingsRow, DrawnButton, MenuStyle)
│   └── hud/                           # RhythmHud (combo, compás, avisos) + HeatHud (manómetro, mecha, fin) + SystemMonitor
└── shared/resources/
    ├── presets/<sección>/             # presets .tres por sección del menú
    ├── music/                         # MusicTrack de cada canción
    └── sfx/                           # SoundEffect, agrupados por prefijo del nombre
```

## Capas de una zona

1. **Generador puro** (`AzoteaGenerator`, `OficinasLayout` + `OficinasGenerator`): recibe un
   `Resource` de parámetros y devuelve datos (rectángulos, polígonos, grafos). No crea nodos,
   así que se testea headless.
2. **Vistas** (`*View`): dibujan esos datos con `_draw()` según el `ArtStyle` activo. Lo
   estático se redibuja solo cuando cambia el estilo; lo animado vive en vistas "live".
3. **Interactuables** (`Elevator`, `WallDoorNode`, `KeyPickup`): nodos con estado de juego.
4. **Zona** (`ZoneLevel` + subclase): arma todo, maneja la cámara, el jugador, el ritmo, el
   post-proceso y el menú de debug. Cada zona solo implementa los ganchos `_zone_*`
   (generar, controles del mapa, spawn, cámara, recorrido automático).

## Rendimiento

El costo por frame depende de lo que se ve, no del tamaño del mapa:

- **Vistas estáticas** (`RooftopView`, `InteriorView`): `ChunkedView` las parte en una grilla de
  celdas de 2048 px × capas de dibujo. Cada trozo es una instancia de la vista que solo dibuja los
  elementos cuyo ancla cae en su celda (`ChunkCanvas._owns`) y de su capa (`_in_layer`); Godot
  descarta solo los trozos fuera de pantalla. Las capas conservan el orden de dibujo aunque un
  elemento cruce el borde de una celda. Para agregar un elemento a estas vistas: dibujarlo dentro
  del `if _in_layer(n)` que corresponda y filtrarlo con `_owns(ancla)`.
- **Vistas animadas** (balizas, fuego, lámparas, carteles, moscas): un `SpatialIndex` por celdas
  devuelve solo lo cercano a la pantalla (`SpatialIndex.screen_rect`).
- **Enemigos**: `CombatController` duerme (`PROCESS_MODE_DISABLED`) a las papas a más de
  `WAKE_MARGIN` de la pantalla y las despierta al acercarse.
- **Ascensores y puertas**: se redibujan solo cuando cambia lo que muestran (y al cambiar el estilo).

`tests/test_scenes/benchmark.tscn` mide el tiempo por frame (ver `docs/development/testing.md`).

## Ritmo

`Conductor` (autoload) es la única fuente del tempo. Todo lo que late (cielo, luces, puertas,
ascensores, guía sonora) lee `Conductor.pulse()` / `beat_index()` o su señal `beat`.
`RhythmTracker` juzga acciones (`PERFECT` / `GOOD` / `MISS`) y lleva combo y puntaje.
Las semicorcheas (`subbeat`) marcan los patrones rápidos de la tiradora. El hitstop se pide con
`Conductor.set_hitstop()`: congela la acción sin desplazar los beats.

### Música

Cada zona elige su canción (`_zone_music()`, un `MusicTrack` en `src/shared/resources/music/`
con el audio, el BPM y el primer beat). `Conductor.play_track()` la reproduce en bucle y pone su
tempo; desde entonces el reloj sigue la posición de reproducción del audio (corrige suave y
nunca hacia atrás), así los beats del juego caen sobre la música. El hitstop no frena la música;
el BPM y la escala de tiempo de debug sí (cambian la velocidad y el tono). En headless no suena
nada pero el tempo es el de la canción, así los tests juegan igual.

| Zona | Canción | BPM |
|---|---|---|
| Azotea | `nivel_uno` (DirtyLoveSongLevelOne.wav, 65 compases) | 177 |
| Oficinas | `industrial` (SecondLevelIndustrial.wav, 21 compases) | 175 |
| (futura) | `centro_comercial` (NivelTresCentroComercial.wav, 22 compases) | 140 |

El BPM se midió analizando el audio y todas empiezan en el beat (`first_beat` = 0). Pestaña
Ritmo → Música: cambiar de canción, volumen, reiniciarla, y "Metrónomo sobre la música" para
comprobar la sincronía de oído. `MenuSongStart.wav` (≈191 BPM) queda para el menú.

### Efectos de sonido

`ZoneLevel` crea un `SfxPlayer` que carga los `SoundEffect` de `src/shared/resources/sfx/` y los
agrupa por el prefijo del nombre (`hurt_grave.tres` → `hurt`). `play(grupo)` toca una variante al
azar sin repetir la anterior, con un pool de reproductores para que se superpongan. Para sumar
una variante basta con otro `.tres` con el mismo prefijo. Los WAV se importan con `edit/trim`:
sin silencio al inicio (el retraso se nota en un juego de ritmo) ni la cola muda de 3 s.

| Grupo | Cuándo suena | Variantes |
|---|---|---|
| `hit` | Golpe que entra a una papa (ataque, aéreo, dash o stomp) | UserDealsDamageOne, WeCanWeBeHeroesUserDealsDamageTwo |
| `stomp` | Cada aterrizaje de caída forzada | FloorStampOne, FloorStampTwo |
| `hurt` | El jugador recibe daño: tocar una papa o una papa frita | DamageVocaloidGrave, DamageVocaloidUh |
| `miss` | Cualquier acción fuera de ritmo (MISS), salvo aterrizar | ErrorSoundEffect |

Pestaña Ritmo → Efectos: activarlos y volumen general; el volumen y la variación de tono de cada
sonido están en su `.tres`. En headless no suenan, pero `SfxPlayer.history` registra lo pedido.

## Combate y partida

`ZoneLevel` arma `CombatController` (ataque, stomp, dash, contacto, proyectiles), `HeatMeter`
(papa caliente), `GameFeel` (hitstop, zoom, temblor) y `HeatHud`, y lleva el estado de la
partida (jugando / victoria / game over). Cada zona pone sus enemigos con `EnemyRoster` y llama
`finish_victory()` al llegar a la salida. Detalle en `docs/game-design/combate.md`.

## Estilos gráficos

`ArtStyle` define trazo, colores, marcas y post-proceso; los tres modos (Default, Pixel,
Isaac) son presets en `presets/estilo/`, cada uno con su cielo e iluminación. El mapa es el
mismo en todos los modos. Detalle en `docs/game-design/art-direction/rojo-frenetico.md`.

## Menú de debug y presets

Tab/F1 abre el menú (pestañas Estilo, Mapa, Cielo, Luz, Jugador, Efectos, Ritmo, Combate, Sistema).
Cada pestaña enlaza sliders con campo numérico a propiedades de un `Resource` y puede
exportar/cargar presets `.tres` (en el editor se guardan en `src/shared/resources/presets/`).

## Argumentos útiles de línea de comandos

Se pasan después de `--`: `--seed=N`, `--style=default|pixel|isaac`, `--set=propiedad=valor`
(cualquier parámetro del mapa), `--zoom=1.5`, `--autorun`, `--hide-menu`, `--debug-tab=N`,
y en Oficinas `--graph` y `--room-view`.

## Decisiones

Ver `docs/architecture/decisions/`.
