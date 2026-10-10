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
| LEVEL SELECT (`seleccion_nivel`) | ENTER de la tarjeta del nivel 1 | Juega el nivel 1 (Azotea, "Carullazo"); los niveles 2 y 3 están bloqueados en el diseño |
| LOADING (`cargando`) | — | Carga el nivel en segundo plano; las tres papas aparecen de izquierda a derecha (mínimo 1,5 s) |
| YOU LOOSE (`perdiste`) | BACK MENU · TRY AGAIN? | Al explotar la papa: volver al menú o reintentar con la misma seed |
| YOU WIN (`ganaste`) | BACK MENU · NEXT LEVEL | Al llegar a la salida: volver al menú o pasar al siguiente nivel (mientras haya uno solo, la misma zona con otra seed) |

Los botones responden al mouse (se resaltan al pasar por encima) y al teclado: el primero toma el
foco, las flechas o el Tab cambian de botón y Enter, Espacio o J lo activan. Esc vuelve a la
pantalla anterior del menú. YOU WIN y YOU LOOSE se ven sobre el juego oscurecido.

## Niveles

`Game` (`src/core/autoloads/game.gd`, autoload) guarda la lista de niveles y la navegación. Para
agregar un nivel: sumarlo a `Game.LEVELS` (nombre y escena) y su botón ENTER a
`MainMenu.LEVEL_ENTER_BUTTONS` cuando el diseño tenga su tarjeta desbloqueada. Abrir una zona
directo (desde el editor o la línea de comandos) sigue funcionando como antes, con el menú de
debug abierto.
