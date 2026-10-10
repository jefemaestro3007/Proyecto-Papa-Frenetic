# Tests

Todos corren headless con el binario de Godot 4.7. Salen con código 0 si pasan.

## Unitarios

```bash
godot --headless --path . --script res://tests/unit/test_azotea_generator.gd
godot --headless --path . --script res://tests/unit/test_presets.gd
godot --headless --path . --script res://tests/unit/test_controls.gd
godot --headless --path . --script res://tests/unit/test_oficinas_layout.gd
godot --headless --path . --script res://tests/unit/test_oficinas_generator.gd
godot --headless --path . --script res://tests/unit/test_heat_meter.gd
godot --headless --path . --script res://tests/unit/test_music.gd
```

| Test | Qué comprueba |
|---|---|
| `test_azotea_generator` | Determinismo, spawn sobre azotea, escalones saltables, siluetas válidas, detalles dentro de su azotea, ventanas del skyline dentro de su edificio (verificación independiente por muestreo). |
| `test_presets` | Todos los presets cargan con su tipo; exportar y volver a cargar conserva los valores. |
| `test_controls` | Mapa de controles: WASD + flechas, Espacio para saltar, J o clic izquierdo para atacar, Shift o K para el dash. |
| `test_oficinas_layout` | 1160 edificios (modos de final, tamaños extremos, configuraciones aleatorias): salida alcanzable, sin trampas desde ningún lugar, sin atascos por llaves (espacio de estados), determinismo, pasillos al fondo enlazados, llaves en lugares válidos, alternativas de ruta. |
| `test_oficinas_generator` | Áreas al fondo fuera del edificio y sin superponerse, cada puerta al fondo con su área, llaves en su habitación o en el edificio, escaleras dentro de su módulo, puertas coherentes con la topología. |
| `test_heat_meter` | Calor pasivo, enfriar/calentar por juicio y peso, mecha que no se recarga, explosión, modo sin game over. |
| `test_music` | Cada canción carga con su BPM medido y dura compases enteros; el Conductor toma su tempo, reinicia el reloj y apaga la música. |

## Integración: recorrido con física

```bash
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/oficinas_traversal.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/oficinas_traversal.tscn -- --extra=60
```

Instancia la zona Oficinas real y deja que `OficinasBot` la juegue con los controles del
jugador hasta la salida (escaleras, ascensores, puertas al fondo, llaves). `--cases=N` limita
los casos fijos y `--extra=N` agrega edificios aleatorios de estrés. Con `BOT_DEBUG=1` el bot
imprime sus decisiones.

Corre como escena (no con `--script`) porque necesita el autoload `Conductor`.
El bot solo recorre: el test desactiva el calor y los enemigos.

## Integración: partida con combate

```bash
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/combat_match.tscn
godot --headless --path . res://tests/test_scenes/rhythm_rewards.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/sfx.tscn
```

Juega la Azotea real: reparto de enemigos por tramo (`EnemyRoster`), calor pasivo, stomp que
derrota a la común y rebota sobre el tanque, dash a tiempo, papa frita, hitstop que congela la
acción sin desplazar los beats, game over al agotarse la mecha, reintento con Enter (misma seed)
y victoria al llegar al final de la última azotea.

`sfx` comprueba que los efectos de sonido cargan por grupo, que los WAV quedan recortados y qué
evento pide cada sonido (golpe, stomp, daño, fallo; aterrizar fuera de ritmo no suena).

## Capturas para revisar lo visual

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
    --write-movie /tmp/frames/f.png --quit-after 300 res://src/world/levels/oficinas/oficinas.tscn \
    -- --autorun --seed=4 --style=isaac --hide-menu
```
