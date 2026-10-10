# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/)
y este proyecto adhiere a [Versionado Semántico](https://semver.org/lang/es/).

## [Unreleased]

### Changed

- Rendimiento independiente del tamaño del mapa: las vistas estáticas se dibujan en trozos
  (`ChunkedView`) y Godot descarta los que están fuera de pantalla; las vistas animadas
  (balizas, fuego, lámparas, carteles, moscas) solo dibujan lo cercano (`SpatialIndex`); las
  papas lejos de la pantalla duermen; ascensores y puertas se redibujan solo al cambiar. Azotea
  de 64 azoteas: 33,5 → 4,7 ms por frame; Oficinas 24×16: 54,8 → 3,9 ms.
- Recompensas: golpear papas es la fuente principal (sube el combo, enfría −8/−4 y da puntos
  con multiplicador). Moverse a tiempo solo mantiene el combo, da 10/5 puntos y enfría poco con
  tope (75 % del calor pasivo): solo moviéndose no se sobrevive. Saltar o girar fuera de ritmo
  calienta y rompe el combo; la caída forzada fallada suma +20.

### Fixed

- Tirones en Oficinas: la guía sonora buscaba el camino a la salida en cada beat (15 ms en
  edificios grandes); ahora sigue el plan guardado y solo replanea al salirse de él. El bot de
  recorrido guarda sus planes y las búsquedas en anchura usan un cursor en lugar de `pop_front()`.
- En Oficinas, YOU WIN se cerraba solo a los 2,5 s porque la zona pasaba a otra seed.
- Ventanas del skyline que quedaban flotando sobre edificios derrumbados.
- HUD de ritmo con tamaño 0: el indicador de compás y los anuncios no se veían bien.
- El hitstop desplazaba el beat ~1 tiempo al empezar (cambiaba la escala a mitad de frame);
  ahora lo aplica el `Conductor`.

### Added

- Niveles 1 y 2 con subniveles: 1-1 tutorial (textos de movimientos básicos y, con la primera papa,
  de stomp, ataque aéreo y dash), 1-2 la azotea unas 2,6 veces más larga con los cuatro tipos
  mezclados, 2-1 torre de 13 pisos hacia arriba con neblina de habitación y 2-2 torre de 14 pisos
  hacia abajo con estilo Isaac. YOU WIN pasa al subnivel siguiente.
- Menú de pausa con Esc (CONTINUE / BACK MENU) que también detiene la canción y el beat.
- Progreso guardado: llegar a un nivel lo desbloquea en LEVEL SELECT (diseños con 1, 2 y 3
  tarjetas); la tercera ya tiene su botón para cuando se agregue el nivel 3.
- Test `test_campaign`; `test_oficinas_traversal` recorre también los edificios de 2-1 y 2-2.
- Efectos de sonido (`SfxPlayer`, `SoundEffect`): golpe a una papa, stomp, daño recibido y fallo
  de ritmo, con variantes al azar; WAV recortados al importar. Volumen en la pestaña Ritmo. Test
  `test_sfx`.
- Menú principal con las pantallas del equipo (START, NEW GAME, LEVEL SELECT, LOADING) como escena
  de inicio; el nivel 1 es la Azotea. YOU LOOSE y YOU WIN reemplazan el panel de texto del fin de
  partida (menú, reintentar, siguiente nivel). Herramienta `build_menu_screens.gd` que convierte los
  PSD.
- HUD del calor: papa bomba en 5 etapas (dibujos del equipo) con el manómetro incrustado y alarma
  desde 80 de calor (vibración, halos rojos); indicador del dash: cuadrado con flecha, verde listo,
  rojo recargándose.
- Sprites del jugador (guardia, correr al ritmo, aire, aterrizaje, dash, ataque aéreo) y la
  herramienta `tools/scripts/build_player_sprites.gd` que los recorta, escala y ancla.
- Sprites de los cinco enemigos (base, ataque, herido) con contorno del estilo, y la flecha y la
  nube del stomp; herramienta `tools/scripts/build_enemy_sprites.gd`.
- Música real en las zonas: `MusicTrack` (canción, BPM y primer beat medidos del audio) y el
  `Conductor` sigue la posición de reproducción para que los beats caigan sobre la música.
  Azotea: nivel uno (177 BPM); Oficinas: industrial (175 BPM). Controles en la pestaña Ritmo.
- Tests `test_music` y `test_rhythm_rewards`.
- Papa caliente (`HeatMeter`, `HeatHud`): calor que sube con el tiempo y al fallar el ritmo,
  mecha de 10 s que no se recarga, explosión y game over; manómetro, aviso de
  sobrecalentamiento con cuenta atrás, viñeta roja y temblor de tensión.
- Estados de la partida: victoria al llegar a la salida (Azotea y Oficinas), game over,
  reintento con la misma seed (Enter).
- Dash (Shift) juzgado por ritmo, stomp que golpea a las papas y rebote contra las que aguantan.
- Enemigos tanque, voladora, embestidora y tiradora (patrones de negras, corcheas y
  semicorcheas al ritmo); se presentan de a uno por tramo en cada zona (`EnemyRoster`).
- Game feel (`GameFeel`): hitstop sin desplazar los beats, zoom de impacto, temblor; los
  estallidos de impacto se adaptan a golpes, daño, dash y explosión según el estilo.
- Tests `test_heat_meter` y `test_combat_match`.
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
