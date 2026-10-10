# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Added

- Zona **Azotea** (`src/world/levels/azotea/`): azoteas jugables con colisión y skyline
  en ruinas con parallax, generados desde una seed (`AzoteaGenerator`, `AzoteaParams`).
- Cielo procedural configurable (`SkyParams`): sol, estrellas, nubes, montañas, agua,
  nieve y paleta; pixel-art opcional. Presets "Rojo Frenético" y "Noche Frenética".
- Iluminación dinámica del mundo (`LightingParams`): ambiente, tinte del sol, destello por beat.
- Sistema de ritmo: autoload `Conductor` (BPM, metrónomo, juicio, `RhythmParams`) y
  `RhythmTracker` (combo y puntaje) con HUD.
- Prototipo de jugador (`PlayerPrototype`, `PlayerParams`): coyote time, buffer y corte
  de salto, caída forzada juzgada por ritmo (premio o aturdimiento), recompensas por
  saltar, girar y aterrizar a tiempo.
- Solo atacan las caídas forzadas o desde una altura configurable; partículas del
  impacto (rayos, escombros, temblor, glitch) configurables en `ImpactFxParams`, con
  presets "base", "brutal" y "sutil".
- Detalles de la Azotea: objetos sobre los techos, cables, ventanas de fachada, grietas,
  manchas, escombros y balizas que laten con el beat.
- Modos gráficos Default, Pixel e Isaac (`ArtStyle`): trazo, marcas, colores y
  post-proceso (pixelado, paleta reducida, viñeta, foco, haz de luz). F2 los alterna.
- Menú de debug por secciones (Tab/F1) con campos numéricos y exportación/carga de
  presets por sección (`src/shared/resources/presets/`).
- Dirección de arte en `docs/game-design/art-direction/rojo-frenetico.md`.
- Tests headless del generador y de los presets.
