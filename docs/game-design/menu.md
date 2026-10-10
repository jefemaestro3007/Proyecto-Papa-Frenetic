# Menú principal y pantallas de fin de partida

El juego abre en el menú (`src/ui/menus/main_menu.tscn`, escena principal del proyecto). Las
pantallas son los diseños del equipo (`assets_src/ui/menu/*.psd`), convertidos a PNG por
`tools/scripts/build_menu_screens.gd`:

```bash
godot --headless --path . --script res://tools/scripts/build_menu_screens.gd
godot --headless --path . --import
```

La herramienta compone las capas visibles de cada PSD (las de texto exportadas desde Figma no
siempre vienen en la imagen compuesta) e imprime cada capa con su rectángulo: de ahí salen las
coordenadas de los botones. Las tres papas de LOADING se exportan aparte para animarlas.

## Música

Todo el menú suena con `MenuSongStart.wav` (`src/shared/resources/music/menu.tres`, 190,5 BPM medido
del audio, primer beat a 0,03 s); marca el beat de la protagonista y de los botones. Al entrar a un
nivel suena la canción de la zona y al volver al menú vuelve la del menú. La canción no dura
compases enteros, pero el `Conductor` sigue su posición de reproducción.

## Flujo

```
START ──▶ NEW GAME ──▶ LEVEL SELECT ──▶ LOADING ──▶ nivel ──Esc──▶ PAUSE
  ▲  │       │ Esc          │ Esc                      │              │
  │  └─▶ SETTINGS           │            YOU LOOSE / YOU WIN       SETTINGS
  └──────────┴──────────────┘
```

| Pantalla | Botones | Qué hace |
|---|---|---|
| START (`inicio`) | START · SETTINGS | START pasa a NEW GAME; SETTINGS abre la configuración. Sobre el fondo de la azotea al atardecer (`inicio_fondo.png`, que cubre toda la ventana), la protagonista arriba vibra al ritmo de la música del menú (`StartScreenArt`); debajo, el título y START (capas del PSD exportadas aparte). SETTINGS va debajo de START, dibujado en código con la letra del diseño al 60 % del tamaño de START |
| SETTINGS (`configuracion`) | Pestañas · BACK · DEFAULTS | Configuración del jugador (ver abajo). BACK o Esc vuelve a donde se abrió |
| NEW GAME (`nuevo_juego`) | NEW GAME | Pasa a LEVEL SELECT |
| LEVEL SELECT (`seleccion_nivel`, `_2`, `_3`) | ENTER de cada nivel desbloqueado | Juega el nivel desde su primer subnivel (1-1, 2-1…). El diseño cambia según hasta dónde se llegó: al empezar solo el nivel 1; al llegar a los edificios (2-1) queda desbloqueado el 2, también al volver al menú o reabrir el juego |
| LOADING (`cargando`) | — | Carga el nivel en segundo plano; las tres papas aparecen de izquierda a derecha (mínimo 1,5 s). Al entrar a otro mundo con NEXT LEVEL se ve su imagen (`Game.WORLD_LOADING`) a pantalla completa durante 3 s: 1-2 → 2-1 muestra a la protagonista preocupada frente a la ciudad (`carga_mundo_2.png`) y 2-2 → 3-1, de brazos cruzados frente al edificio (`carga_mundo_3.png`; se verá cuando esté el nivel 3) |
| YOU LOOSE (`perdiste`) | BACK MENU · TRY AGAIN? | Al explotar la papa: volver al menú o reintentar con la misma seed |
| YOU WIN (`ganaste`) | BACK MENU · NEXT LEVEL | Al llegar a la salida: volver al menú o pasar al siguiente subnivel (1-1 → 1-2 → 2-1 → 2-2; después de 2-2, la misma zona con otra seed) |
| PAUSE (en juego, Esc) | BACK MENU · CONTINUE · SETTINGS | Congela el juego y la canción. CONTINUE o Esc sigue donde iba; BACK MENU vuelve al menú principal; SETTINGS abre la configuración sobre la partida pausada. No tiene PSD: se dibuja en código (`PauseArt`) con los botones de YOU LOOSE / YOU WIN; si llega un diseño, se reemplaza por su PNG |

Los botones responden al mouse (se resaltan al pasar por encima) y al teclado: el primero toma el
foco, las flechas o el Tab cambian de botón y Enter, Espacio o J lo activan. Esc vuelve a la
pantalla anterior del menú. YOU WIN y YOU LOOSE se ven sobre el juego oscurecido.

## Niveles y subniveles

`Game` (`src/core/autoloads/game.gd`, autoload) guarda la lista de subniveles (`Game.LEVELS`: nivel,
nombre y escena) y la navegación. Cada tarjeta del menú entra por el primer subnivel de su nivel y
YOU WIN pasa al siguiente de la lista. Cada subnivel es una escena con sus parámetros de mapa y
las opciones de `ZoneLevel` del grupo "Subnivel" (`tutorial`, `start_style`, `enemy_types`,
`mixed_enemies`).

| Subnivel | Escena | Mapa | Enemigos | Música |
|---|---|---|---|---|
| 1-1 Tutorial | `azotea/azotea_tutorial.tscn` | La azotea del prototipo (14 azoteas) con el tutorial de la protagonista | Se presentan de a uno: común → voladora → tiradora → embestidora | Nivel uno |
| 1-2 Carullazo | `azotea/azotea_prueba.tscn` | La misma azotea, 36 azoteas (unas 2,6 veces más larga) | Comunes, voladoras, tiradoras y embestidoras mezcladas desde el principio | Nivel uno |
| 2-1 Subida | `oficinas/oficinas_subida.tscn` | Torre de 13 pisos, de abajo hacia arriba (12 pisos de subida) con la neblina de habitación (la vista de la V); la protagonista explica escaleras y ascensores | Se presentan de a uno: común → tanque → embestidora → tiradora | Nivel dos (industrial) |
| 2-2 Bajada | `oficinas/oficinas_bajada.tscn` | Torre de 14 pisos y 10 módulos, de arriba hacia abajo, con el estilo Isaac | Comunes, tanques, embestidoras y tiradoras | Nivel dos (industrial) |

El tutorial (`TutorialHints`) pausa el juego y la canción, y la protagonista (retrato
`assets/textures/ui/protagonista_retrato.png`) aparece en el centro y habla en un globo de diálogo
de una o más páginas; Espacio, Enter, J o clic terminan de escribir, pasan de página y cierran. Las
páginas con foco iluminan la papa bomba del HUD (el resto de la pantalla queda oscuro) y la rodean
con un anillo. Primero se cuenta la premisa y después los controles, de a poco: el guion lo elige
cada escena con `tutorial`:

| Guion | Subnivel | Cuándo | Qué dice |
|---|---|---|---|
| `azotea` | 1-1 | Al empezar, fondo oscuro, 3 páginas | Le pegaron una papa bomba (foco en la papa); se calienta sola y más si pierde el ritmo, solo la enfría pelar papas zombi al ritmo y si llega al rojo explota (foco); hay que salir de la ciudad: A/D moverse, Espacio saltar, clic/J golpear, clic/J en el aire golpe aéreo |
| `azotea` | 1-1 | Cuando se acerca la primera papa, sin fondo oscuro | Pelarla al ritmo enfría la papa bomba (foco) |
| `prueba` | 1-2 | Al empezar, fondo oscuro | Dos trucos para pelarlas antes de que explote: S en el aire stomp, Shift dash |
| `edificio` | 2-1 | Al empezar, fondo oscuro | W subir y S bajar por escaleras y ascensores, A/D salir del ascensor |

Cada diálogo sale una vez por partida: reintentar no lo repite. Jugando desde el menú no se ve la
línea de ayuda de debug ni Oficinas cambia sola de seed al ganar.

Abrir una zona directo (desde el editor o la línea de comandos) sigue funcionando como antes, con
el menú de debug abierto. `tests/test_scenes/campaign.tscn` verifica la lista, el largo, los pisos y
el sentido, la neblina, el estilo, los enemigos, la música y el tutorial de cada subnivel.

## Progreso y nivel 3

`Game.unlocked_level` es el nivel más alto al que se llegó; se guarda en `user://progreso.cfg`.
Entrar a un subnivel (desde el menú o con NEXT LEVEL) desbloquea su nivel. LEVEL SELECT usa el
diseño `seleccion_nivel` (solo nivel 1), `seleccion_nivel_2` o `seleccion_nivel_3` (PSD en
`assets_src/ui/menu/`) y pone ENTER solo en los niveles desbloqueados que tienen escena.

Para conectar el nivel 3 basta con agregar sus subniveles a `Game.LEVELS` con `"nivel": 3`: el
botón ENTER de la tercera tarjeta (`MainMenu.LEVEL_ENTER_BUTTONS`) y el diseño con las tres
tarjetas ya están listos. Al ganar 2-2, NEXT LEVEL pasará solo a 3-1 y lo desbloqueará. Para
empezar de cero, borrar `progreso.cfg` de la carpeta de datos del juego (en Windows,
`%APPDATA%Godotpp_userdata<proyecto>`).

## Configuración (SETTINGS)

No hay PSD: `SettingsScreen` la dibuja en código con `MenuStyle` (colores, botones con sombra,
etiqueta torcida y la letra **Jersey 20** de los diseños, en `assets/fonts/jersey20/`, licencia
OFL). `PauseArt` usa el mismo estilo. Se maneja con el teclado (↑/↓ entre opciones, ←/→ cambian el
valor, Enter/Espacio/J activa, Q/E cambian de pestaña, Esc vuelve) y con el mouse (clic, arrastre
en los deslizadores). Abajo se lee la ayuda de la opción con foco; DEFAULTS restablece solo la
pestaña actual.

| Pestaña | Opciones |
|---|---|
| AUDIO | Volumen general, música y efectos (0–100 %), silenciar todo. Van a los buses `Master`, `Musica` y `Efectos` (el metrónomo y la guía sonora son efectos) |
| VIDEO | Pantalla completa, VSync, límite de FPS (sin límite, 30, 60, 120, 144, 240) |
| CONTROLS | Dos teclas por acción (mover, arriba/usar, abajo/stomp, saltar, atacar, dash). Enter o clic en una casilla y apretar la tecla nueva; Esc cancela, Retroceso la borra. Si la tecla ya era de otra acción, intercambian. Esc, Tab y F1 no se pueden asignar. El clic de atacar se mantiene |
| GAME | Estilo gráfico ("Level's own" respeta el de cada nivel, o Default / Pixel / Isaac para todos), temblor de cámara (0–100 %), corrección de latencia del ritmo (±200 ms) |
| DIFFICULTY | Easy / Normal / Hard (tabla abajo) o Custom, con un deslizador por multiplicador (calor 25–200 %, mecha 50–300 %, ventanas 50–200 %, velocidad 50–200 %, cantidad de papas 0–250 %). Se aplica al instante, también en medio de un nivel; la cantidad de papas, al empezar o reintentar |
| DEVELOPER | Modo developer: en la campaña habilita el menú de debug (Tab/F1), F2 (estilo), R/N/P (seed), G/V en las oficinas y la línea de ayuda; sin él esas teclas no hacen nada (al abrir una zona directo siempre funcionan). Monitor del sistema: Off, FPS (FPS y tiempo por frame) o Full (además proceso y física, draw calls, nodos, objetos de física, memoria, latencia de audio, ventana, BPM y beat), arriba a la derecha en todas las pantallas |

| Dificultad | Calor que se suma | Mecha | Ventanas PERFECTO/BIEN | Velocidad de las papas | Cantidad de papas |
|---|---|---|---|---|---|
| Easy | ×0,7 | ×1,5 | ×1,25 | ×0,85 | ×0,7 |
| Normal | ×1 | ×1 | ×1 | ×1 | ×1 |
| Hard | ×1,3 | ×0,7 | ×0,8 | ×1,15 | ×1,3 |

Los multiplicadores están en `GameSettings.DIFFICULTY` y se aplican sobre los valores de cada
nivel (no se acumulan al cambiar de opción). `Settings` (autoload, `src/core/autoloads/settings.gd`)
guarda todo en `user://configuracion.cfg` y la zona lo vuelve a aplicar cada vez que cambia. Los
tests llaman `Settings.use_defaults()` para no depender de la configuración guardada.
`tests/test_scenes/settings.tscn` lo verifica.
