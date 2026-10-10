# Combate y papa caliente

Ataques, calor, enemigos y game feel **inspirados** en el prototipo `feature/gameplay-prototype`,
adaptados a este proyecto: nuestro movimiento no cambia, el ritmo usa el `Conductor` (nuestro
BPM, sin tocar los beats) y el combo de `RhythmTracker`, los impactos son nuestros estallidos y
todo se dibuja según el `ArtStyle`. Del prototipo **no** se trajo el Finisher (mantener y soltar
3 beats después).

Controles: **A/D** moverse, **Espacio** saltar, **W/S** arriba/abajo (escaleras, ascensores,
puertas al fondo; **S en el aire** = caída forzada / stomp), **J** o clic izquierdo atacar,
**Shift** (o **K**) dash. Las flechas funcionan como alternativa a WASD. Al terminar la partida:
**Enter** reintenta la misma seed y **N** pasa a la siguiente.

Todo tiene su pestaña en el menú de debug: **Combate** (`CombatParams`, presets en
`src/shared/resources/presets/combate/`) y, para dash y rebote, **Jugador** (`PlayerParams`).

## Papa caliente (calor)

`HeatMeter` (`src/features/combat/heat_meter.gd`), igual que en el prototipo:

| | |
|---|---|
| Calor | 0 a 100; sube solo 1 por segundo |
| PERFECTO / BIEN | −8 / −4 |
| FUERA | +10 |
| Al llegar a 100 | Se enciende una **mecha de 10 s** con cuenta atrás. Un acierto que enfríe por debajo de 100 la apaga, pero **no se recarga** |
| Mecha en 0 | La papa explota: **game over** |

Qué cuenta y cuánto pesa (todo ajustable en la pestaña Combate):

| Acción | Peso |
|---|---|
| Atacar, stomp, dash contra una papa | 1 (enfría o calienta) |
| Saltar, girar | 0,25 (`movement_heat_scale`) |
| Aterrizar, escaleras, ascensor, puertas | 0,25, solo enfrían |
| Tajo al aire fuera de ritmo | +5 sin romper el combo (castiga el spam) |
| Tocar una papa | +10 (embestidora ×1,5) |
| Papa frita de la tiradora | +5 |
| Caer al vacío | +15 |

**Tensión:** desde 50 de calor la cámara tiembla y se balancea, el HUD tiembla y una viñeta roja
late con el beat; durante la mecha todo es más fuerte.

**HUD** (`src/ui/hud/heat_hud.gd`): abajo a la derecha la papa bomba (`HeatPotato`, cinco dibujos,
uno cada 20 de calor) con el manómetro de presión incrustado (`HeatGauge`; con la mecha el cristal
se agrieta y sale vapor), y a su izquierda el indicador del dash (`DashKey`: un cuadrado sin fondo con una flecha rellena
hacia donde sale el dash; todo verde cuando está listo, rojo al usarlo, con el contorno que se
recarga de verde alrededor, y verde apagado en el aire). Desde 80 de calor la papa y el
manómetro entran en alarma (vibración y halos rojos que laten con el beat); aviso "SOBRE / CALENTAMIENTO" letra a letra y cuenta
atrás en display de segmentos (`OverheatAlert`, `MenacingText`, `SegmentFont`) y el panel de fin de partida. Los textos de juicio dicen la acción y el calor:
"STOMP ¡PERFECTO! +200 / −8 calor".

Para probar: "Game over al explotar" desactivado deja que la papa explote sin terminar la
partida, y los botones "Calor 0 / 90 / 100" saltan a ese calor.

## Estados de la partida

`ZoneLevel` (`Match`): **jugando**, **victoria** (llegar a la salida: final de la última azotea
o la salida de Oficinas) y **game over** (explotó la papa). Al terminar se congela el mundo y
aparece el panel con tiempo, calor, puntaje y mejor combo. Regenerar o reintentar reinicia calor,
mecha, puntaje y efectos.

## Ataques

| Ataque | Input | Juicio | A tiempo | Fuera de tiempo |
|---|---|---|---|---|
| Normal | J/clic en el suelo | Al pulsar | Daña a la papa más cercana adelante | Rebota y rompe el combo |
| Aéreo | J/clic en el aire | Al pulsar | Arco adelante, arriba y abajo; nunca atrás | Igual |
| Tajo al aire | J/clic sin papa al alcance | — | Nada | +5 de calor, no rompe el combo |
| Stomp | S en el aire | Al aterrizar | Golpea a las papas cerca de los pies; si alguna aguanta, **rebota** sobre ella | Si había una papa, lo empuja |
| Dash | Shift en el suelo (espera 5 s) | Al iniciarlo; cuenta por cada papa que atraviesa | La golpea; si aguanta (tanque), el dash se corta y **rebota** | Choca y lo empuja |

Durante el dash, la caída forzada, escaleras, ascensor y un instante tras recibir un golpe o
rebotar, tocar una papa no hace daño. Código: `src/features/combat/combat_controller.gd`.

## Enemigos

Base: `src/features/enemies/enemy.gd` (`Enemy`): vida, golpe recibido, muerte despedida girando,
latido con el beat, contorno del estilo activo. Las variantes solo cambian movimiento y dibujo,
así que se pueden reemplazar por modelos animados más adelante.

| Tipo | Vida | Contacto | Comportamiento |
|---|---|---|---|
| Común (`Enemy`) | 1 | +10, desaparece | Persigue por su carril si comparte nivel |
| Tanque (`TankEnemy`) | 3 | +10, sigue | Grande y lento, casco de olla |
| Voladora (`FlyingEnemy`) | 1 | +10, desaparece | Despierta al acercarte; vuela hacia ti chocando con el escenario y rodeándolo |
| Embestidora (`ChargerEnemy`) | 1 | +15, sigue | Te ve en su nivel, avisa (roja + "!") y carga por su carril; después queda aturdida (estrellas): la mejor ventana para golpearla |
| Tiradora (`ThrowerEnemy`) | 1 | +10, desaparece | Fija. Lanza papas fritas en arco **al ritmo**: un beat antes del tiempo fuerte levanta el brazo y muestra un punto por lanzamiento; en el compás siguiente tira negra (1), corcheas (2) o semicorcheas (4). Los patrones rápidos son los que le dan más poder |

Las semicorcheas salen de `Conductor.subbeat` (4 por beat); no cambian el tempo.

### Dónde aparecen

`EnemyRoster` (`src/features/enemies/enemy_roster.gd`): al inicio de cada zona solo papas comunes
y, desde el 20 % del recorrido, un tipo nuevo por tramo (la mitad de las papas de un tramo son
del tipo recién presentado). Todo es determinista por seed.

- **Azotea** (abierta): común → voladora → tiradora → embestidora. La primera azotea es zona
  segura; el avance es el índice de la azotea.
- **Oficinas** (cerrada): común → tanque → embestidora → tiradora. Una papa por módulo como
  máximo, nunca en el inicio, la salida, escaleras, ascensores ni huecos; el avance es la
  distancia en el grafo desde el inicio.

"Cantidad de enemigos" (`enemy_density`) controla cuántas hay.

## Game feel

`GameFeel` (`src/features/combat/game_feel.gd`) y nuestro `ImpactBurst`:

- **Hitstop:** congela la acción un instante en cada golpe (más en PERFECTO). Lo aplica el
  `Conductor` (`set_hitstop`), que lo compensa: **los beats no se mueven**.
- **Zoom de impacto** y **temblor por trauma** en golpes, daño, caídas fuertes y explosión.
- **Partículas:** el mismo estallido de las caídas (rayos + escombros) adaptado a cada caso:
  golpe a una papa (con sus colores, anillo si muere), daño (sangre del estilo), dash (estela),
  papa frita y la explosión final. Toma el contorno y la grilla de pixel del estilo activo
  (Default, Pixel, Isaac).
