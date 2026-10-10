# Tests

Todos corren headless con el binario de Godot 4.7. Salen con código 0 si pasan.

## Unitarios

```bash
godot --headless --path . --script res://tests/unit/test_azotea_generator.gd
godot --headless --path . --script res://tests/unit/test_presets.gd
godot --headless --path . --script res://tests/unit/test_controls.gd
godot --headless --path . --script res://tests/unit/test_oficinas_layout.gd
godot --headless --path . --script res://tests/unit/test_oficinas_generator.gd
```

| Test | Qué comprueba |
|---|---|
| `test_azotea_generator` | Determinismo, spawn sobre azotea, escalones saltables, siluetas válidas, detalles dentro de su azotea, ventanas del skyline dentro de su edificio (verificación independiente por muestreo). |
| `test_presets` | Todos los presets cargan con su tipo; exportar y volver a cargar conserva los valores. |
| `test_controls` | Mapa de controles: WASD + flechas, Espacio para saltar, J o clic izquierdo para atacar. |
| `test_oficinas_layout` | 1160 edificios (modos de final, tamaños extremos, configuraciones aleatorias): salida alcanzable, sin trampas desde ningún lugar, sin atascos por llaves (espacio de estados), determinismo, pasillos al fondo enlazados, llaves en lugares válidos, alternativas de ruta. |
| `test_oficinas_generator` | Áreas al fondo fuera del edificio y sin superponerse, cada puerta al fondo con su área, llaves en su habitación o en el edificio, escaleras dentro de su módulo, puertas coherentes con la topología. |

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

## Capturas para revisar lo visual

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
    --write-movie /tmp/frames/f.png --quit-after 300 res://src/world/levels/oficinas/oficinas.tscn \
    -- --autorun --seed=4 --style=isaac --hide-menu
```
