# Arquitectura

Visión general del código del juego. Todo está en GDScript (Godot 4.7, renderer
GL Compatibility). Lo procedural es **determinista**: misma seed + mismos parámetros ⇒
mismo resultado.

## Mapa de módulos

```
src/
├── core/autoloads/conductor.gd        # Conductor: reloj musical global (BPM, beat, juicio)
├── features/
│   ├── player/                        # PlayerPrototype + PlayerParams
│   ├── rhythm/                        # RhythmTracker (combo/puntaje) + RhythmParams
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
│   └── hud/                           # RhythmHud (combo, compás, avisos) + HeatHud (manómetro, mecha, fin)
└── shared/resources/presets/<sección>/ # presets .tres por sección del menú
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

## Ritmo

`Conductor` (autoload) es la única fuente del tempo. Todo lo que late (cielo, luces, puertas,
ascensores, guía sonora) lee `Conductor.pulse()` / `beat_index()` o su señal `beat`.
`RhythmTracker` juzga acciones (`PERFECT` / `GOOD` / `MISS`) y lleva combo y puntaje.
Las semicorcheas (`subbeat`) marcan los patrones rápidos de la tiradora. El hitstop se pide con
`Conductor.set_hitstop()`: congela la acción sin desplazar los beats.

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
