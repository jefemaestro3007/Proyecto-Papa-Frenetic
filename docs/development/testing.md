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
godot --headless --path . --script res://tests/unit/test_bienestar_generator.gd
```

| Test | Qué comprueba |
|---|---|
| `test_azotea_generator` | Determinismo, spawn sobre azotea, escalones saltables, siluetas válidas, detalles dentro de su azotea, ventanas del skyline dentro de su edificio (verificación independiente por muestreo). |
| `test_presets` | Todos los presets cargan con su tipo; exportar y volver a cargar conserva los valores. |
| `test_controls` | Mapa de controles: WASD + flechas, Espacio para saltar, J o clic izquierdo para atacar, Shift o K para el dash. |
| `test_oficinas_layout` | 1160 edificios (modos de final, tamaños extremos, configuraciones aleatorias): salida alcanzable, sin trampas desde ningún lugar, sin atascos por llaves (espacio de estados), determinismo, pasillos al fondo enlazados, llaves en lugares válidos, alternativas de ruta. |
| `test_oficinas_generator` | Áreas al fondo fuera del edificio y sin superponerse, cada puerta al fondo con su área, llaves en su habitación o en el edificio, escaleras dentro de su módulo, puertas coherentes con la topología. |
| `test_heat_meter` | Calor pasivo, enfriar/calentar por juicio y peso, mecha que no se recarga, explosión, modo sin game over. |
| `test_bienestar_generator` | 300 tiendas (supermercado y centro comercial, tamaños variados): determinismo, obstáculos saltables con lugar para aterrizar, racks a 180 px sin sólidos debajo, escaleras mecánicas en cada piso lejos de huecos y cortinas y que cambian de sentido, huecos saltables, entrada abajo y salida arriba, congelados, cajas, carritos y freidoras presentes. |
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

```bash
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_traversal.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_traversal.tscn -- --extra=20
```

Lo mismo en Bienestar U con `BienestarBot`: salta pallets, mostradores y escombros, toma
escaleras mecánicas (a favor o a contramano, con pasos a tiempo), espera cortinas cerradas y salta
huecos del atrio. Incluye las dos tiendas de la campaña y casos exigentes (racks por todos lados,
cinco pisos con una sola escalera, cortinas y huecos en todas las secciones).

Corre como escena (no con `--script`) porque necesita el autoload `Conductor`.
El bot solo recorre: el test desactiva el calor y los enemigos.

## Integración: partida con combate

```bash
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/combat_match.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/campaign.tscn
godot --headless --path . res://tests/test_scenes/rhythm_rewards.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/sfx.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/settings.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_enemies.tscn
godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_mechanics.tscn
```

Juega la Azotea real: reparto de enemigos por tramo (`EnemyRoster`), calor pasivo, stomp que
derrota a la común y rebota sobre el tanque, dash a tiempo, papa frita, hitstop que congela la
acción sin desplazar los beats, game over al agotarse la mecha, reintento con Enter (misma seed)
y victoria al llegar al final de la última azotea.

`bienestar_enemies` juega las papas vestidas de Bienestar U en la Azotea (sin papas al azar ni
calor pasivo): el cliente deja compras que resbalan, la muestra en llamas quema el impacto más
un calor por beat y deja fuego que enciende al pisarlo, el reponedor lanza el carrito antes de
cargar, los globos se arman cerca y su explosión alcanza al jugador y a otras papas, y el guardia
empuja hacia otra papa o, solo, cobra más calor.

`bienestar_mechanics` prueba cada mecánica del nivel 3 en tiendas reales: el rack se derrumba a
los beats justos (golpea y deja al jugador sobre los escombros) o al instante con un stomp sobre la
papa de abajo; el freezer abierto enfría, frena y se agota; el piso mojado resbala; la cinta lleva
en el beat; el carrito se monta, acelera, atropella sin dañar y se deja; la escalera mecánica a favor
tarda lo configurado y a contramano más; la cortina cerrada bloquea, vuelve a abrir y en dash se
pasa por debajo; la freidora calienta.

`sfx` comprueba que los efectos de sonido cargan por grupo, que los WAV quedan recortados y qué
evento pide cada sonido (golpe, stomp, daño, fallo; aterrizar fuera de ritmo no suena).

## Rendimiento

```bash
godot --path . --quit-after 6000 res://tests/test_scenes/benchmark.tscn -- --scene=azotea --frames=1200
godot --path . --quit-after 6000 res://tests/test_scenes/benchmark.tscn -- --scene=oficinas --set=floors=24 --set=modules=16 --idle
godot --path . --quit-after 6000 res://tests/test_scenes/benchmark.tscn -- --scene=supermercado --set=sections=24
godot --path . --quit-after 6000 res://tests/test_scenes/benchmark.tscn -- --scene=centro_comercial --set=sections=20 --set=floors=5
```

Con ventana (headless no dibuja), sin vsync ni límite de FPS. Abre la zona (o `--scene=menu`) con
el recorrido automático y el calor apagado, y reporta el tiempo por frame (promedio, p95, p99,
máximo), proceso, física, draw calls, nodos y memoria. `--idle` deja al jugador quieto y
`--set=propiedad=valor` cambia el mapa: comparar un mapa chico con uno grande muestra si algo
escala con el tamaño (no debería).

`settings` comprueba la configuración del jugador: buses de audio, teclas (con intercambio y el
clic de atacar intacto), dificultad y temblor sin acumularse, guardar y cargar, la pantalla
(pestañas, teclado, reasignar una tecla, DEFAULTS, Custom con sus deslizadores), abrirla desde la
pausa y desde START, el modo developer en la campaña (Tab y N bloqueadas sin él) y el monitor del
sistema.
Los tests de integración empiezan con `Settings.use_defaults()`: no leen ni escriben la
configuración guardada del jugador.

## Capturas para revisar lo visual

Papas vestidas de Bienestar U (sin vestir, vestidas, atacando y usando su habilidad):

```bash
godot --path . --quit-after 600 res://tests/test_scenes/costume_preview.tscn -- --out=/tmp/vestuarios.png
```

```bash
xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1920x1080 --fixed-fps 30 \
    --write-movie /tmp/frames/f.png --quit-after 300 res://src/world/levels/oficinas/oficinas.tscn \
    -- --autorun --seed=4 --style=isaac --hide-menu
```
