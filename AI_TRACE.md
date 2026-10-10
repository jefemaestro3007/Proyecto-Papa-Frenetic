# AI TRACE — feature/rhythm-combat

Registro del uso de IA en esta rama. Es append-only: las entradas no se editan ni se borran;
las correcciones se agregan como entradas nuevas.

## Nota de integridad (reconstrucción retrospectiva)

Este archivo se creó el 2026-10-10. En esta rama los
commits se hicieron inicialmente sin AI_TRACE; a pedido del mismo usuario se reconstruye aquí la trazabilidad antes de llevar la
rama a `develop`.

- **Timestamps:** no hay timestamps oficiales del evento/servidor. Las horas citadas son metadatos
  de commit de Git (`%cI`): solo indican cuándo se creó el commit, no cuándo se hizo el trabajo.
- **Participantes:** no se proporcionaron identificadores oficiales de participante ni TEAM_ID
  (N/A). Se cita el autor de Git tal como figura en el commit.
- **Prompts:** para los commits del otro agente (autor de Git `14mn0t4b0t`) no se tuvo acceso a
  su conversación. Lo que se sabe sale del historial de Git (mensajes, trailers `Co-Authored-By`,
  diffs) y de un resumen y una solicitud que el usuario pegó en la sesión del 2026-10-10. Donde el
  prompt no se conoce, se indica.
- **Participación de IA:** se marca como verificada solo cuando el commit lleva el trailer
  `Co-Authored-By` o el trabajo se hizo en la sesión que escribe este archivo.
- Equipo: Frenetic Studios. Rama base: `develop` en `5ece8ef` (merge de los PR #1 Azotea y #2
  Oficinas, que no se cubren aquí).

---

### Combate base: papa zombi y ataque al ritmo

Timestamp: N/A (commit de Git: 2026-10-10T04:21:37-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t <santicm248@gmail.com>)
Team: Frenetic Studios
AI: Claude
Prompt: No disponible (conversación del otro agente). Según el mensaje del commit: traer el ataque y la papa zombi del prototipo `feature/gameplay-prototype` adaptados a este proyecto.
Task: Ataque con J o clic juzgado contra el beat (suelo hacia adelante, aire en arco), papa zombi que persigue por su carril, golpe recibido con retroceso, pestaña "Combate" del menú de debug.
Type: CODE (AI_ASSISTED)
Files: `project.godot`, `src/features/combat/combat_controller.gd`, `src/features/combat/combat_params.gd`, `src/features/enemies/enemy.gd`, `src/features/player/scripts/player_prototype.gd`, `src/features/rhythm/rhythm_tracker.gd`, `src/shared/resources/presets/combate/base.tres`, `src/ui/hud/rhythm_hud.gd`, `src/world/levels/azotea/azotea.gd`, `src/world/levels/zone_level.gd`, `tests/unit/test_presets.gd` (+ archivos `.uid`)
Change: Ver diff del commit (533 líneas agregadas, 6 eliminadas).
Commit: `b37ca3b`
Notes: Reconstruido desde Git.

### Documentación del ataque y la papa zombi

Timestamp: N/A (commit de Git: 2026-10-10T04:21:37-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: Claude
Prompt: No disponible.
Task: Documentar el ataque y la papa zombi.
Type: DOCS (AI_ASSISTED)
Files: `docs/README.md`, `docs/game-design/combate.md`
Change: Nuevo `combate.md` y su enlace en el índice.
Commit: `995df84`
Notes: Reconstruido desde Git.

### Controles con WASD

Timestamp: N/A (commit de Git: 2026-10-10T04:27:51-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: Claude
Prompt: No disponible.
Task: Pasar los controles a WASD (flechas como alternativa), Espacio para saltar, W/S para escaleras, ascensores y puertas; test del mapa de controles.
Type: CODE (AI_ASSISTED) / TESTING
Files: `project.godot`, `src/features/combat/combat_controller.gd`, `src/features/player/scripts/player_prototype.gd`, `src/world/environment/interior_view.gd`, `src/world/generation/oficinas/oficinas_layout.gd`, `src/world/interactables/elevator.gd`, `src/world/levels/azotea/azotea.gd`, `src/world/levels/oficinas/oficinas.gd`, `src/world/levels/oficinas/oficinas_bot.gd`, `src/world/levels/zone_level.gd`, `tests/unit/test_controls.gd`
Change: Acciones de entrada nuevas en `project.godot` y adaptación de los usos; nuevo `test_controls`.
Commit: `4bf7c01`
Notes: Reconstruido desde Git.

### Documentación de los controles WASD

Timestamp: N/A (commit de Git: 2026-10-10T04:27:51-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: Claude
Prompt: No disponible.
Task: Actualizar la documentación a los controles WASD.
Type: DOCS (AI_ASSISTED)
Files: `README.md`, `docs/development/testing.md`, `docs/game-design/art-direction/rojo-frenetico.md`, `docs/game-design/combate.md`, `docs/game-design/zonas/azotea.md`, `docs/game-design/zonas/oficinas.md`
Change: Tablas y textos de controles.
Commit: `82bc73a`
Notes: Reconstruido desde Git.

### Conductor: semicorcheas y compensación de hitstop

Timestamp: N/A (commit de Git: 2026-10-10T04:43:58-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: Claude
Prompt: Parcialmente conocido. La solicitud que el usuario pegó en la sesión del 2026-10-10 pedía integrar el sistema de calor, el dash, el rebote, los enemigos, el game feel (tiempo, zoom de impacto, partículas), los estados de partida y la introducción progresiva de enemigos desde `feature/gameplay-prototype`, usando el BPM propio y patrones rápidos para algunos enemigos. Quién la escribió y a qué agente se le dio no está verificado.
Task: Señal `subbeat` (4 por beat) para patrones rápidos y compensación del hitstop en el reloj.
Type: CODE (AI_ASSISTED)
Files: `src/core/autoloads/conductor.gd`
Change: `subbeat`, `SUBDIVISIONS`, `hitstop_scale` dividiendo el delta.
Commit: `93e1c60`
Notes: La compensación de este commit tenía un error (ver la entrada de `8186597`).

### Medidor de calor (papa caliente)

Timestamp: N/A (commit de Git: 2026-10-10T04:45:18-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: Claude
Prompt: La misma solicitud de la entrada anterior (parcialmente conocida).
Task: `HeatMeter` como en el prototipo: calor 0-100, +1/s, PERFECTO −8, BIEN −4, FUERA +10, mecha de 10 s que no se recarga, explosión; parámetros en el grupo "Calor" de `CombatParams`.
Type: CODE (AI_ASSISTED)
Files: `src/features/combat/combat_params.gd`, `src/features/combat/heat_meter.gd` (+ `.uid`)
Change: Medidor nuevo, todavía sin conectar al juego.
Commit: `7ea86d7`
Notes: Según el resumen pegado por el usuario, el otro agente se detuvo aquí por límite de uso.

### UID de test_controls

Timestamp: N/A (commit de Git: 2026-10-10T04:51:51-05:00)
Participant: N/A (autor de Git: 14mn0t4b0t)
Team: Frenetic Studios
AI: No verificada (el commit no lleva trailer `Co-Authored-By`)
Prompt: No disponible.
Task: Agregar el `.uid` generado por Godot para `test_controls.gd`.
Type: PROCESS
Files: `tests/unit/test_controls.gd.uid`
Change: Un archivo de 1 línea.
Commit: `2045929`
Notes: Se incluye para que el registro de la rama quede completo; no se afirma participación de IA.

---

Las entradas siguientes corresponden a la sesión de trabajo del 2026-10-10 que escribe este
archivo (participación de IA verificada).

### Retomar el trabajo en feature/rhythm-combat

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: El usuario pegó la solicitud original y el resumen del otro agente, y pidió terminar su trabajo en la rama haciendo pull de rhythm-combat. Luego aclaró que el contenido de esta rama es más relevante que el del prototipo y que se trajeran solo los cambios pedidos.
Task: Cambiar a la rama y decidir el alcance.
Type: PROCESS
Files: N/A
Change: Se guardó en un stash el cambio sin commitear de `AI_TRACE.md` en `feature/gameplay-prototype` ("gameplay-prototype: AI_TRACE push entry (pendiente)") y se creó la rama local que sigue a `origin/feature/rhythm-combat`. Decisiones del usuario: reparto de enemigos Azotea (abierta) / Oficinas (cerrada), sin Finisher ("no modifiquen los beats") y commits sin AI_TRACE (decisión revisada en la última entrada).
Commit: N/A
Notes: Sin push, PR ni merge.

### Arreglo del hitstop que desplazaba el beat

Timestamp: N/A (commit de Git: 2026-10-10T05:25:58-05:00)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Mismo encargo ("si puedes arreglar algún bug o mejorarlo mejor").
Task: El test de integración detectó que, al empezar un hitstop, el beat avanzaba de más (~1 tiempo): `Engine.time_scale` cambiaba a mitad de frame y el reloj dividía un delta ya escalado por la escala nueva.
Type: DEBUGGING / CODE (AI)
Files: `src/core/autoloads/conductor.gd`
Change: `Conductor.set_hitstop()`: el cambio de escala se aplica después de consumir el delta del frame.
Commit: `8186597`
Notes: Verificado con `test_combat_match`.

### Dash y rebote

Timestamp: N/A (commit de Git: 2026-10-10T05:25:59-05:00)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "el dash también intégralo, el rebote está bien".
Task: Dash con Shift o K, solo en el suelo y con espera; rebote contra papas que aguantan; roce de proyectiles.
Type: CODE (AI) / TESTING
Files: `project.godot`, `src/features/player/resources/player_params.gd`, `src/features/player/scripts/player_prototype.gd`, `src/features/rhythm/rhythm_tracker.gd`, `tests/unit/test_controls.gd`
Change: Acción `dash`, `recoil()`, `graze()`, `RhythmTracker.register_judgment()`.
Commit: `a3f3823`
Notes: Basado en el dash de `feature/gameplay-prototype`.

### Tipos de enemigo y reparto por tramo

Timestamp: N/A (commit de Git: 2026-10-10T05:25:59-05:00)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "todos los tipos de enemigos están bien, impleméntalos"; "la idea de un tipo de enemigo al inicio y después los demás también"; "lo de los patrones rápidos es para darle a algunos enemigos más poder".
Task: Tanque, voladora, embestidora y tiradora (negras, corcheas y semicorcheas sobre `Conductor.subbeat`), proyectil y `EnemyRoster`.
Type: CODE (AI)
Files: `src/features/combat/combat_params.gd`, `src/features/enemies/{enemy,tank_enemy,flying_enemy,charger_enemy,thrower_enemy,potato_projectile,enemy_roster}.gd` (+ `.uid`)
Change: Variantes adaptadas de `feature/gameplay-prototype` sobre la base `Enemy`; reparto Azotea común → voladora → tiradora → embestidora y Oficinas común → tanque → embestidora → tiradora.
Commit: `aae5b5f`
Notes: El reparto por mapa no estaba en el repo: lo eligió el usuario entre las opciones propuestas.

### Papa caliente en juego, estados de partida, HUD y game feel

Timestamp: N/A (commit de Git: 2026-10-10T05:25:59-05:00)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Integrar el calor como en el prototipo, los estados de partida adaptados, el game feel (tiempo, zoom de impacto) y mejorar nuestras partículas para los otros escenarios.
Task: Conectar `HeatMeter` al juego; HUD de calor del prototipo; victoria, game over y reintento; stomp y dash contra papas; `GameFeel`; `ImpactBurst` adaptable; enemigos en Oficinas; tests y documentación.
Type: CODE (AI) / UX / TESTING / DOCS
Files: `CHANGELOG.md`, `README.md`, `docs/architecture/overview.md`, `docs/development/testing.md`, `docs/game-design/combate.md`, `src/features/combat/{combat_controller,game_feel,impact_burst}.gd`, `src/ui/hud/{heat_gauge,heat_hud,menacing_text,overheat_alert,segment_font,rhythm_hud}.gd`, `src/world/levels/{zone_level,azotea/azotea,oficinas/oficinas}.gd`, `tests/integration/{test_combat_match,test_oficinas_traversal}.gd`, `tests/test_scenes/combat_match.tscn`, `tests/unit/test_heat_meter.gd` (+ `.uid`)
Change: Ver diff del commit. También arregla los HUD con tamaño 0 (el indicador de compás no se veía).
Commit: `66acc4f`
Notes: `heat_gauge.gd`, `menacing_text.gd`, `overheat_alert.gd` y `segment_font.gd` se copiaron de `feature/gameplay-prototype` (trabajo con IA registrado en el AI_TRACE de esa rama, commit `a531fdc`). Pruebas: 6 unitarios + `test_combat_match` + `test_oficinas_traversal` (48/48) en verde; capturas revisadas en los estilos Default, Isaac y Pixel.

### Consultas de estado y creación de este archivo

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "Dame los comandos para probarlo"; revisar si la rama está actualizada y pusheada respecto a develop; "¿Cuál es el estado de AI trace del repositorio?"; "Haz la 1" (crear AI_TRACE.md en esta rama con una reconstrucción retrospectiva).
Task: Dar los comandos de prueba, comparar con `origin/develop` y reconstruir la trazabilidad de la rama.
Type: PROCESS / DOCS
Files: `AI_TRACE.md`
Change: Se comprobó que `develop` solo tiene los PR #1 y #2, que la rama tiene 11 commits que no están en `develop` y que 4 de ellos (`8186597`..`66acc4f`) no estaban pusheados. Se creó este archivo.
Commit: PENDING (se commitea junto con este archivo; el hash no puede ir dentro de su propio commit)
Notes: Sin push, PR ni merge.

---

Las entradas siguientes, hasta "Push de feature/rhythm-combat", se copiaron del AI_TRACE de
`origin/feature/rhythm-combat`. Describen commits (`44518ac`, `b7a32ac`, `d776a78`, `71a08eb`,
`560262d`) que **no están en esta rama**: siguen en `origin/feature/rhythm-combat` y en la etiqueta
local `respaldo-rhythm-combat`.

### Guardar la versión antes de los arreglos del merge

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Hacer un commit de lo que hay y guardarlo como "la versión merge de las 6.22 AM antes de Santiago".
Task: Commitear el estado actual y marcarlo.
Type: PROCESS
Files: `project.godot` (formato guardado por el editor de Godot: solo quita líneas en blanco entre acciones de entrada)
Change: Commit `44518ac` y etiqueta anotada local `merge-6.22am-antes-santiago`. `node_2d.tscn` (escena vacía sin trackear) quedó fuera.
Commit: `44518ac`
Notes: Sin push de la etiqueta ni de la rama.

### Arreglos del merge: moverse no da puntos y espera del stomp

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: El enfriamiento de la papa debe venir principalmente de los enemigos, no de moverse: eliminar los puntos del movimiento (moverse a los lados, saltar, stomp sin golpear nada) como en la versión anterior, donde el stomp solo daba puntos si golpeaba algo; y agregar al stomp una espera de unos dos segundos porque se podía encadenar muy rápido.
Task: Que solo el combate se juzgue y agregar la espera del stomp.
Type: CODE (AI) / DEBUGGING / TESTING / DOCS
Files: `src/world/levels/zone_level.gd`, `src/world/levels/oficinas/oficinas.gd`, `src/features/combat/combat_controller.gd`, `src/features/combat/combat_params.gd`, `src/features/player/scripts/player_prototype.gd`, `src/features/player/resources/player_params.gd`, `src/ui/hud/heat_hud.gd`, `tests/integration/test_combat_match.gd`, `README.md`, `CHANGELOG.md`, `docs/game-design/combate.md`, `docs/game-design/zonas/azotea.md`, `docs/game-design/art-direction/rojo-frenetico.md`, `AI_TRACE.md`
Change: Saltar, girar, aterrizar, escaleras, ascensor y puertas ya no pasan por `RhythmTracker` (sin puntos, combo ni calor); saltar, girar y caer a tiempo conservan solo el impulso, el giro y el tamaño del estallido. El stomp se juzga solo si cae sobre papas (`CombatController.stomp_targets()`). Se quitó `movement_heat_scale`. Caída forzada con espera de 2 s desde que empieza (`PlayerParams.fast_fall_cooldown`), indicador "STOMP" en el HUD y slider en la pestaña Jugador. El test de partida verifica que moverse no da puntos y que el calor solo sube por el pasivo, y también la espera del stomp.
Commit: PENDING (se commitea junto con esta entrada; el hash no puede ir dentro de su propio commit)
Notes: La espera cuenta desde que empieza la caída forzada para cortar también la cadena de rebotes sobre un tanque. Pruebas: 6 unitarios + `test_combat_match` + `test_oficinas_traversal` (48/48) en verde.

### Repaso de BPM, ventanas de juicio y calor; versión de las 6:42

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Repasar los valores de BPM, el umbral para un golpe perfecto y uno bueno, y el calor que se suma o se quita al acertar o fallar un golpe; hacer el commit de lo nuevo como "versión de las 6 y 42 después de arreglar el sistema de puntos".
Task: Revisión de valores (sin cambiarlos) y marca de versión.
Type: PROCESS / DESIGN
Files: `AI_TRACE.md`
Change: Se reportaron al usuario los valores vigentes (`RhythmParams`: 170 BPM, PERFECTO ±0,06 s, BIEN ±0,13 s; `CombatParams`: PERFECTO −8, BIEN −4, FUERA +10, pasivo +1/s) con un análisis de su efecto. No se modificó ningún valor. Etiqueta anotada local `v6.42am-despues-arreglo-puntos` sobre este commit.
Commit: PENDING (se commitea junto con esta entrada)
Notes: Los cambios de código de esta versión ya estaban en `b7a32ac`; este commit solo agrega la entrada. Sin push.

### Ventana BIEN más estrecha (±130 ms → ±90 ms)

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "Hazlo" (aplicar la propuesta de bajar la ventana BIEN a ±90 ms).
Task: Que golpear sin seguir el ritmo no enfríe la papa.
Type: DESIGN / CODE (AI)
Files: `src/features/rhythm/rhythm_params.gd`, `docs/game-design/combate.md`, `docs/game-design/art-direction/rojo-frenetico.md`, `CHANGELOG.md`, `AI_TRACE.md`
Change: `RhythmParams.good_window` 0,13 → 0,09 s. PERFECTO sigue en ±0,06 s y el preset "permisivo" no cambia (±0,18 s). A 170 BPM, golpear al azar pasa de −1,7 a +1,5 de calor promedio por golpe (34 % PERFECTO, 17 % BIEN, 49 % FUERA).
Commit: PENDING (se commitea junto con esta entrada)
Notes: Pruebas: `test_presets`, `test_heat_meter`, `test_combat_match`, `test_oficinas_traversal` (48/48) en verde. Sin push.

### Controles W/Espacio, persecución por plataforma y voladoras más rápidas

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Intercambiar Espacio y W (W para saltar, Espacio para interactuar con ascensores, escaleras y objetos); que los enemigos no rastreen al jugador desde todo el mapa y queden pegados al borde de su plataforma (al menos las embestidoras), sino solo cuando está en su plataforma; que voladoras y tiradoras detecten desde lejos; subir un poco la velocidad de las voladoras.
Task: Remapear controles y cambiar la detección de los enemigos.
Type: CODE (AI) / UX / DEBUGGING / TESTING / DOCS
Files: `project.godot`, `tests/unit/test_controls.gd`, `src/world/levels/oficinas/oficinas.gd`, `src/world/levels/oficinas/oficinas_bot.gd`, `src/world/levels/zone_level.gd`, `src/features/player/scripts/player_prototype.gd`, `src/features/enemies/{enemy,charger_enemy,flying_enemy,enemy_roster}.gd`, `src/features/combat/combat_params.gd`, `tests/integration/test_combat_match.gd`, `README.md`, `CHANGELOG.md`, `docs/development/testing.md`, `docs/game-design/combate.md`, `docs/game-design/zonas/{azotea,oficinas}.md`, `AI_TRACE.md`
Change: Acción `jump` = W/↑ y nueva acción `interact` = Espacio; se eliminó `move_up`. En Oficinas, Espacio sube escaleras (y baja desde arriba; S también baja), llama al ascensor y entra o sale de las áreas al fondo; en la cabina, W sube y S baja. El bot del test usa las acciones nuevas. `Enemy.is_target_on_lane()`: común, tanque y embestidora solo persiguen o cargan si el jugador está en su carril (±60 px); si no, patrullan. Voladora: 210 de velocidad (antes 150), aceleración 680 y detección a 1800 px (antes 1100). Nuevos sliders "Voladora: detecta desde" y "Tiradora: tira desde" (sigue en 1400 px).
Commit: PENDING (se commitea junto con esta entrada)
Notes: El test de recorrido encontró un bug del remapeo: si el pie de una escalera coincidía con lo alto de otra, Espacio podía bajar en vez de subir; ahora subir tiene prioridad. Sin push.

### Push de feature/rhythm-combat

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "haz git push de la rama".
Task: Subir la rama al remoto.
Type: PROCESS
Files: N/A (solo esta entrada)
Change: `git push origin feature/rhythm-combat` llevó el remoto de `2045929` a `560262d` (10 commits). Sin force push, sin PR ni merge, y sin cambios en `develop`/`main`. Las etiquetas locales `merge-6.22am-antes-santiago` y `v6.42am-despues-arreglo-puntos` no se subieron.
Commit: PENDING (esta entrada queda sin commitear hasta el próximo commit)
Notes: N/A

### Rama feature/sprites desde feature/rhythm-combat-restored

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "Borra esta rama y haz una nueva con base en develop, empezaremos a trabajar en los sprites". Al avisarle que feature/rhythm-combat no estaba mergeada en develop: "Solo guarda el AI_TRACE aparte; del resto haz un feature/sprites desde el develop actual sin mergear con rhythm-combat". Después: "Mejor olvida esta rama y mejor haz la copia desde rhythm-combat-restored".
Task: Crear la rama de sprites y conservar el registro de IA.
Type: PROCESS
Files: `AI_TRACE.md`
Change: Primero se creó `feature/sprites` desde `origin/develop` (`6a0385c`), con un commit local `0bc5ca4` que solo traía este archivo. Después, a pedido del usuario, esa rama se borró sin subirse y se volvió a crear `feature/sprites` desde `origin/feature/rhythm-combat-restored` (`f61baa3`). Se borró la rama local `feature/rhythm-combat`, con la etiqueta local de respaldo `respaldo-rhythm-combat` en `560262d`; `origin/feature/rhythm-combat` no se tocó. El `develop` local se actualizó a `origin/develop`. Se agregaron arriba las entradas posteriores a `f61baa3`.
Commit: PENDING (se commitea junto con esta entrada)
Notes: `feature/rhythm-combat-restored` no tiene los arreglos posteriores a `f61baa3` (puntos solo por combate, espera del stomp, ventana BIEN ±90 ms, W/Espacio, persecución por plataforma). Al cambiar de rama se descartaron los 4 `.wav` de develop que aparecían modificados solo por Git LFS (su contenido estaba en el commit `10fa959`) y se borraron sus `.wav.import`, que Godot había generado. Sin push.

### Sprites del jugador

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "No los traigas" (no traer a esta rama los arreglos de feature/rhythm-combat). "Te acabo de subir los sprites de las acciones del personaje, necesito que los incluyas en las acciones del jugador". Mapa de poses confirmado por el usuario: imagen 1 = aire / aterrizaje; imagen 2 = correr; imagen 3 = dash; imagen 4 = de espaldas mirando a la izquierda y de frente mirando a la derecha; imagen 5 = ataque aéreo; recortar el cuadriculado del correr automáticamente.
Task: Integrar los sprites del personaje.
Type: CODE (AI) / ART PIPELINE / DOCS
Files: `assets_src/sprites/player/*` (5 dibujos originales del equipo, sin modificar), `assets/textures/sprites/player/*.png` (+ `.import`), `tools/scripts/build_player_sprites.gd`, `src/features/player/scripts/player_prototype.gd`, `docs/development/sprites.md`, `docs/README.md`, `CHANGELOG.md`, `AI_TRACE.md`
Change: Herramienta que quita el fondo de cuadriculado pintado (relleno desde los bordes que se detiene en el contorno negro, huecos con los tonos del cuadriculado y manchas sueltas), separa las poses, las escala con la gorra roja como referencia y ancla los pies. `PlayerPrototype._pose()` elige la pose: dash, ataque aéreo, aire, aterrizaje (0,12 s), correr (4 frames por beat) o guardia según hacia dónde mira; el ataque en el suelo usa la guardia con el tajo dibujado. Si faltan los PNG, se dibuja el rectángulo provisional.
Commit: PENDING (se commitea junto con esta entrada)
Notes: Los dibujos son del equipo; la IA solo los procesó. Se revisó el resultado en capturas: los frames quedaron limpios sobre fondo oscuro, y el juego se probó quieto en ambas direcciones, corriendo, atacando y en el aire. La guardia (espada en alto) se usa también como pose de reposo porque no hay una pose de reposo dibujada. Pruebas: `test_controls`, `test_presets`, `test_combat_match` y `test_oficinas_traversal` (12 casos) en verde. Sin push.

### Sprites de enemigos y del stomp

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "Estos son los nuevos sprites de enemigos y el ataque stomp": personaje 1 (base, golpeando, siendo golpeado) = papa normal; personaje 2 con las mismas acciones = tanque; voladora = papa voladora; tirador ("recibiendo daño", "disparando") = papa tiradora; charger = embestidora; ataque hacia abajo = stomp; nube = efecto de impacto. Al confirmar los grupos, el usuario corrigió que las dos papas juntas son la embestidora y la papa con cresta es la tiradora; las poses se eligieron por el gesto (brazo o palito = ataque/disparo).
Task: Integrar los sprites de enemigos y del stomp.
Type: CODE (AI) / ART PIPELINE / DOCS
Files: `assets_src/sprites/enemies/*` y `assets_src/sprites/fx/*` (dibujos originales del equipo, sin modificar), `assets/textures/sprites/{enemies,fx}/*.png` (+ `.import`), `tools/scripts/build_enemy_sprites.gd`, `src/features/enemies/{enemy,charger_enemy,thrower_enemy,flying_enemy}.gd`, `src/features/combat/impact_sprite.gd`, `src/features/player/scripts/player_prototype.gd`, `src/world/levels/zone_level.gd`, `docs/development/sprites.md`, `docs/README.md`, `CHANGELOG.md`, `AI_TRACE.md`
Change: Herramienta que recorta las tres poses de cada enemigo con el mismo rectángulo, ancla los pies y escala por tipo. `Enemy` dibuja el sprite de la pose (`sprite_pose()`: base, ataque cerca del jugador, herido al recibir un golpe o al morir), espejado según hacia dónde mira, con contorno del color del estilo, latido y destello al golpe; los avisos de juego pasan a `_draw_indicators()` y se ubican sobre el sprite. Embestidora: ataque en aviso y carga, herida aturdida. Tiradora: ataque con el patrón anunciado. Voladora: ataque despierta y cerca. Flecha del stomp durante la caída forzada y nube (`ImpactSprite`) al aterrizar.
Commit: PENDING (se commitea junto con esta entrada)
Notes: Las dos tandas de imágenes subidas eran idénticas; se usó una. Se agregó el contorno porque sin él las papas rojas se perdían contra el cielo rojo del estilo Default (visto en capturas). La nube del stomp se suma al estallido de rayos que ya existía, no lo reemplaza. Pruebas: `test_presets`, `test_heat_meter`, `test_combat_match` en verde; recorrido automático de Oficinas sin errores. Sin push.

### Experimento: variaciones de color de los enemigos

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Experimento para ahorrar trabajo en los sprites: cambiar tonalidad y colores. Tiradora del color de la papa normal con la protuberancia roja; embestidora roja con la papa de adelante ("el muro") negra; tanque más diferenciado, negro y rojo (negro con contorno rojo o rojo con contorno negro); la voladora casi sin cambios.
Task: Recolorear los sprites de enemigos al generarlos.
Type: CODE (AI) / ART PIPELINE / DOCS
Files: `tools/scripts/build_enemy_sprites.gd`, `assets/textures/sprites/enemies/{thrower,charger,tank}_*.png`, `docs/development/sprites.md`, `AI_TRACE.md`
Change: Recoloreo en la herramienta, sobre los dibujos originales (no se modifican; `-- --original` lo desactiva). Tiradora: el rojo bajo el cuello pasa al color medio de la piel de la papa común conservando la textura, con un degradado; la cresta queda roja. El cuello se detecta por el salto del borde izquierdo del dibujo y en la pose de herido se fija a mano (36 %). Embestidora: relleno de la papa de adelante desde su interior hasta el contorno (con las líneas engrosadas 20 px para cerrar huecos del trazo a mano y sin pasar del 60 % del ancho) en negro, y sus líneas en rojo. Tanque: negro, líneas rojas y contorno rojo de 16 px.
Commit: PENDING (sin commitear: el usuario todavía no decidió si se queda)
Notes: Iteraciones revisadas en capturas: (1) el cuello de la tiradora se detectó mal por los dedos de la cresta; (2) el cuerpo oscurecido se confundía con las líneas y terminaba rojo; (3) el relleno de la embestidora se escapaba por huecos del contorno. Las tres se corrigieron y el resultado se revisó en el juego con los estilos Default e Isaac. `test_combat_match` en verde.

### Animación del ataque en el suelo y guardia espejada

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Cambio de planes en el ataque: primero la guardia de frente mirando a la derecha, después el efecto de ataque básico que se subió (tajo morado) y, para terminar el balanceo, el personaje de espaldas, que al siguiente frame vuelve a quedar de frente (como un giro). Al mirar a la izquierda ya no se usa el sprite de espaldas: se espeja el de frente.
Task: Animar el ataque en el suelo y espejar la guardia.
Type: CODE (AI) / ART PIPELINE / DOCS
Files: `assets_src/sprites/fx/ataque_swing.png` (dibujo del equipo), `assets/textures/sprites/fx/ataque_swing.png` (+ `.import`), `assets/textures/sprites/player/{guardia,espalda}.png` (+ `.import`; reemplazan a `guardia_derecha` y `guardia_izquierda`), `tools/scripts/build_player_sprites.gd`, `tools/scripts/build_enemy_sprites.gd`, `src/features/player/scripts/player_prototype.gd`, `docs/development/sprites.md`, `AI_TRACE.md`
Change: Ataque en el suelo de 0,3 s en tres fases (`_attack_phase()`): guardia de frente, guardia con el tajo delante a la altura de la cintura, y de espaldas; después vuelve a la guardia. El golpe se sigue juzgando al pulsar. Todas las poses se espejan al mirar a la izquierda. Frames renombrados a `guardia` y `espalda`. El tajo procedural solo se dibuja si faltan los sprites. La herramienta de efectos borra manchas sueltas (el dibujo del tajo traía un punto suelto que agrandaba el recorte).
Commit: PENDING (sin commitear junto con el experimento de colores, a la espera del usuario)
Notes: Se revisó en capturas las tres fases hacia ambos lados; el tajo se agrandó (96 px) y se subió a la cintura tras verlo a la altura de las rodillas. `test_combat_match` y `test_presets` en verde.

### Papa caliente en el HUD junto al manómetro

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Usar las cinco papas subidas como guía visual de la papa caliente, una por cada intervalo de 20 de calor (0-20 la primera, 20-40 la segunda...), integrada con el barómetro; hacer un poco más chica esa interfaz, que sea agradable y transmita la urgencia de enfriar la papa; hacer más llamativo el barómetro, por ejemplo que se ponga rojo por encima de 80 o que la papa vibre junto a él.
Task: Rediseñar el HUD del calor.
Type: UX / CODE (AI) / ART PIPELINE / DOCS
Files: `assets_src/sprites/ui/papa_calor_{1..5}` (dibujos del equipo), `assets/textures/ui/papa_calor_{1..5}.png` (+ `.import`), `tools/scripts/build_enemy_sprites.gd`, `src/ui/hud/heat_potato.gd` (nuevo), `src/ui/hud/heat_hud.gd`, `src/ui/hud/heat_gauge.gd`, `docs/development/sprites.md`, `docs/game-design/combate.md`, `CHANGELOG.md`, `AI_TRACE.md`
Change: La herramienta genera las cinco etapas con el mismo recorte (se conserva cómo se hincha la papa). `HeatPotato`: etapa según el calor, latido con el beat, golpe de escala al cambiar de etapa; desde 80 vibra, se tambalea y tiene halo rojo; con la mecha, vibración máxima, parpadeo y vapor. Manómetro al 50 % (antes 60 %) con alarma desde el 80 %: halo rojo que late y bisel enrojecido. Placa oscura detrás de ambos cuyo borde late en rojo durante la alarma.
Commit: PENDING (se commitea junto con esta entrada)
Notes: En la primera captura el halo rojo casi no se veía sobre el escenario rojo; por eso se agregaron la placa oscura y el borde que late, y se reforzaron los halos. Revisado en capturas con calor 10, 30, 50, 70, 90 y con la mecha. `test_combat_match` en verde.

### Campo AI de este archivo

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: "Solo pon Claude en [IA] en AI_TRACE, tampoco queremos promoción allí"; "haz el ajuste ya".
Task: Dejar el campo `AI:` de todas las entradas en "Claude".
Type: PROCESS / DOCS
Files: `AI_TRACE.md`
Change: Las 25 entradas que nombraban modelo o versión pasan a `AI: Claude`. La entrada de `2045929` conserva "No verificada", porque no consta uso de IA. Es la única edición de entradas anteriores, hecha a pedido del usuario; el resto del contenido no cambió.
Commit: PENDING (se commitea junto con esta entrada)
Notes: N/A

### Papa bomba: manómetro incrustado y tecla SHIFT

Timestamp: N/A (timestamp oficial no disponible)
Participant: N/A (usuario de Git: Andrés Valencia)
Team: Frenetic Studios
AI: Claude
Prompt: Quitar el cuadro negro semitransparente que encierra el texto, la papa y el barómetro ("se ve muy como IA"); quitar el texto "DASH listo" y poner un indicador al lado de la papa, como la tecla Shift, verde cuando está listo y roja cuando no; poner el barómetro encima de la papa, integrado, como una papa bomba a punto de explotar.
Task: Rediseñar el HUD del calor y del dash.
Type: UX / CODE (AI) / DOCS
Files: `src/ui/hud/heat_hud.gd`, `src/ui/hud/heat_potato.gd`, `src/ui/hud/heat_gauge.gd`, `src/ui/hud/dash_key.gd` (nuevo), `src/world/levels/zone_level.gd`, `docs/game-design/combate.md`, `docs/development/sprites.md`, `CHANGELOG.md`, `AI_TRACE.md`
Change: Sin placa ni texto del dash. El manómetro (escala 0,34) es hijo de la papa, centrado en su panza, con una sombra que lo hunde, y sigue su latido, vibración, tambaleo y golpe de etapa. La papa es más grande (240×250). `DashKey`: tecla SHIFT dibujada con contorno de tinta, verde y latiendo con el beat cuando el dash está listo, roja en espera o en el aire, y llenándose de verde de izquierda a derecha al recargar. `update_dash` recibe también la espera total.
Commit: PENDING (se commitea junto con esta entrada)
Notes: Revisado en capturas con calor 10, 50 (justo después de un dash), 70, 90 (en el aire) y con la mecha. `test_combat_match` en verde.
