# Combate

Ataques y enemigos **inspirados** en el prototipo `feature/gameplay-prototype`, adaptados a
este proyecto: nuestro movimiento no cambia, el ritmo usa el `Conductor` y el combo de
`RhythmTracker`, los impactos son nuestros estallidos y todo se dibuja según el `ArtStyle`.
Del prototipo **no** se trae el sistema de "papa caliente" (calor, mecha, game over): fallar o
recibir un golpe rompe el combo y aturde.

Controles del juego: **A/D** moverse, **Espacio** saltar, **W/S** arriba/abajo (escaleras,
ascensores, puertas al fondo; **S en el aire** = caída forzada), **J** o clic izquierdo atacar.
Las flechas funcionan como alternativa a WASD.

Todo lo integrado desde el prototipo tiene su propia pestaña en el menú de debug:
**Combate** (`CombatParams`, presets en `src/shared/resources/presets/combate/`).

## Ataque (paso 1)

| | |
|---|---|
| Tecla | **J** o clic izquierdo |
| En el suelo | Golpea hacia adelante (alcance y alto configurables) |
| En el aire | Arco amplio adelante, arriba y abajo; nunca atrás |
| A tiempo (PERFECTO / BIEN) | Daña al enemigo más cercano al alcance, suma combo y puntos, estallido y glitch |
| Fuera de tiempo | La papa aguanta, el jugador rebota y se rompe el combo |
| Sin enemigo al alcance | Tajo al aire: no se juzga |

Código: `src/features/combat/combat_controller.gd`.

## Golpe recibido

Tocar a un enemigo (salvo durante la caída forzada, escaleras o ascensor, o tras otro golpe):
retroceso, aturdimiento, invulnerabilidad breve (parpadeo), "¡AUCH!" y se pierde el combo.

## Enemigos

| Tipo | Vida | Comportamiento | Estado |
|---|---|---|---|
| Papa zombi | 1 (configurable) | Persigue por su carril si comparte nivel; desaparece al tocarte | Paso 1 |

Base de todos: `src/features/enemies/enemy.gd` (`Enemy`): vida, golpe recibido, muerte
despedida girando, latido con el beat, contorno del estilo activo.

### Dónde aparecen

- **Azotea**: sobre las azoteas a partir de la segunda (la primera es zona segura), según
  "Cantidad de enemigos". Deterministas por seed.
