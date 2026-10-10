# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Fixed

- Ventanas del skyline que quedaban flotando sobre edificios derrumbados.

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
- Más detalle en la Azotea (barriles con fuego, cajas, parabólicas, tuberías, afiches,
  grafitis, aires de pared, huesos, bajantes) y rasgos por modo con controles propios:
  Gráfico (rayos, semitono, alambrados, banderines), Retro (cel shading, borde de luz,
  scanlines, CRT) y Sótano (moscas, telarañas, huesos, ladrillos).
- Zona **Oficinas** (`src/world/levels/oficinas/`): edificio abandonado generado con recorrido
  garantizado y no lineal (sin atascos, ni siquiera con llaves). Escaleras y ascensores de fondo
  (llamada ≤ 2 s, viaje ≤ 1,5 s, puertas en el beat), puertas que se abren y puertas con llave,
  habitaciones y pasillos al fondo detallados, modos de final arriba / abajo / distancia,
  vista solo de la habitación, guía sonora hacia la salida y bot de prueba con física.
- `ZoneLevel`: base común de las zonas; zoom de cámara configurable.
- Menú de debug por secciones (Tab/F1) con campos numéricos y exportación/carga de
  presets por sección (`src/shared/resources/presets/`).
- Dirección de arte en `docs/game-design/art-direction/rojo-frenetico.md`.
- Tests headless del generador y de los presets.
