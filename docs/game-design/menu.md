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

## Flujo

```
START ──▶ NEW GAME ──▶ LEVEL SELECT ──▶ LOADING ──▶ nivel
  ▲          │ Esc          │ Esc                      │
  └──────────┴──────────────┘            YOU LOOSE / YOU WIN
```

| Pantalla | Botones | Qué hace |
|---|---|---|
| START (`inicio`) | START | Pasa a NEW GAME |
| NEW GAME (`nuevo_juego`) | NEW GAME | Pasa a LEVEL SELECT |
| LEVEL SELECT (`seleccion_nivel`, `_2`, `_3`) | ENTER de cada nivel desbloqueado | Juega el nivel desde su primer subnivel (1-1, 2-1…). El diseño cambia según hasta dónde se llegó: al empezar solo el nivel 1; al llegar a los edificios (2-1) queda desbloqueado el 2, también al volver al menú o reabrir el juego |
| LOADING (`cargando`) | — | Carga el nivel en segundo plano; las tres papas aparecen de izquierda a derecha (mínimo 1,5 s) |
| YOU LOOSE (`perdiste`) | BACK MENU · TRY AGAIN? | Al explotar la papa: volver al menú o reintentar con la misma seed |
| YOU WIN (`ganaste`) | BACK MENU · NEXT LEVEL | Al llegar a la salida: volver al menú o pasar al siguiente subnivel (1-1 → 1-2 → 2-1 → 2-2; después de 2-2, la misma zona con otra seed) |
| PAUSE (en juego, Esc) | BACK MENU · CONTINUE | Congela el juego y la canción. CONTINUE o Esc sigue donde iba; BACK MENU vuelve al menú principal. No tiene PSD: se dibuja en código (`PauseArt`) con los botones de YOU LOOSE / YOU WIN; si llega un diseño, se reemplaza por su PNG |

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
| 1-1 Tutorial | `azotea/azotea_tutorial.tscn` | La azotea del prototipo (14 azoteas) con los textos del tutorial | Se presentan de a uno: común → voladora → tiradora → embestidora | Nivel uno |
| 1-2 Carullazo | `azotea/azotea_prueba.tscn` | La misma azotea, 36 azoteas (unas 2,6 veces más larga) | Comunes, voladoras, tiradoras y embestidoras mezcladas desde el principio | Nivel uno |
| 2-1 Subida | `oficinas/oficinas_subida.tscn` | Torre de 13 pisos, de abajo hacia arriba (12 pisos de subida) con la neblina de habitación (la vista de la V) | Se presentan de a uno: común → tanque → embestidora → tiradora | Nivel dos (industrial) |
| 2-2 Bajada | `oficinas/oficinas_bajada.tscn` | Torre de 14 pisos y 10 módulos, de arriba hacia abajo, con el estilo Isaac | Comunes, tanques, embestidoras y tiradoras | Nivel dos (industrial) |

El tutorial (`TutorialHints`, solo en 1-1) muestra arriba al centro los movimientos básicos (A/D,
Espacio, clic/J) hasta que el jugador avanza un tramo, y cuando aparece la primera papa explica el
stomp (S en el aire), el ataque aéreo y el dash (Shift). Jugando desde el menú no se ve la línea de
ayuda de debug ni Oficinas cambia sola de seed al ganar.

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

**Pendiente (rendimiento):** 1-2 y las torres van más lentos que el prototipo porque la vista
estática del mapa (`RooftopView` / `InteriorView`) es un solo nodo que dibuja todo el mapa cada
frame; partirla en trozos por zona y capa permitiría que Godot descarte lo que está fuera de pantalla.
