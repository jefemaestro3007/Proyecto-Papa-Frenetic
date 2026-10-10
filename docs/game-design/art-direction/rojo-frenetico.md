# Rojo Frenético — filosofía algorítmica de mapas y fondos

Primera zona que usa esta dirección: **Azotea** (`src/world/levels/azotea/`).

Referencia visual: MV de *YARARARA* (ABM feat. Kasane Teto). Se toma su lenguaje
gráfico (paleta, siluetas, ritmo), no sus personajes ni composiciones.

## Filosofía

**Una ciudad que ya se cayó y un pulso que no se detiene.** El mundo es un plano
de rojo saturado sobre el que se recortan ruinas y estructuras en tintas planas.
No hay degradados suaves ni iluminación realista: la profundidad sale de capas
de silueta que se mueven a distinta velocidad y de cuánto se oscurecen.

**El mapa y el fondo nacen del mismo campo.** Un único ruido sembrado define el
relieve de las azoteas jugables y la altura del skyline lejano. Por eso el fondo
no es decoración pegada: "rima" con el terreno. Misma seed, misma ciudad.

**El azar está en las ruinas, no en la forma.** Los edificios son rectángulos
honestos; lo generativo es cómo se rompen: techos dentados, esquinas colapsadas,
ventanas que faltan, antenas y tanques que sobreviven. El orden es la regla, el
daño es la variación.

**El ritmo es parte del arte.** El cielo late a tempo (viñeta pulsante), el grano
cambia a 24 fps como animación hecha a mano, y cada impacto dispara un estallido
amarillo con contorno negro, aberración cromática y bandas de glitch.

## Paleta

| Rol | Color | Uso |
|---|---|---|
| Cielo | `#dc1a22` / sombra `#8c0a17` | Plano de fondo, viñeta |
| Ruina lejana | `#a8141f` (ventanas `#7a0c18`) | Skyline al fondo |
| Ruina cercana | `#6e2a35` (ventanas `#3b1722`) | Skyline medio |
| Estructura jugable | `#2b2a45` / `#17162a` / `#45446a` | Azoteas, barandas |
| Crema | `#eee6dc` | Bordes pisables, personajes |
| Acento | `#ffd400` + tinta `#111018` | Peligro, impactos |
| Sangre | `#9e0f1b` | Salpicaduras |

Fuente de verdad en código: `src/world/generation/frenetic_palette.gd`.

## Cielo e iluminación

El cielo (`src/world/environment/shaders/sky.gdshader`) se controla con `SkyParams`
(`src/world/environment/sky_params.gd`): degradado, sol, estrellas, nubes, capas de
montañas, horizonte con agua, nieve/ceniza y 5 colores de paleta. El **pixel-art es
opcional** (`pixelate`): apagado, el cielo es suave a resolución completa.

- Las capas de skyline toman su color de la paleta del cielo (`land` → `horizon_glow`),
  así la ciudad siempre pertenece al cielo que tiene detrás.
- La iluminación del mundo es un `CanvasModulate`: luz ambiente, tinte del sol y
  destello en cada beat. El sol crece con el beat (`sun_beat_pulse`) y con el combo.
- Presets por sección en `src/shared/resources/presets/<sección>/` (`.tres`).

## Ritmo

El juego recompensa lo que sigue el tempo. `Conductor` (autoload) es el único reloj:
BPM, fase, pulso y juicio (`PERFECT` ±60 ms, `GOOD` ±130 ms). `RhythmTracker` lleva
combo, multiplicador y puntaje.

| Acción a tiempo | Recompensa |
|---|---|
| Saltar | Salto más alto (×1.18 / ×1.08) y chispa |
| Girar | Giro de 360° e impulso de velocidad |
| Aterrizar | Estallido y glitch mayores (nunca rompe combo) |
| Caída forzada (↓ en el aire) | A tiempo: estallido máximo y puntos ×2. Fuera: rompe combo y aturde |
| Combo | Sol más grande, más destello, multiplicador hasta ×4 |

Fallar una acción intencional (saltar/girar/caída forzada) rompe el combo, y 4 beats
sin acertar también. Todas las cifras son ajustables en el menú de debug.

## Menú de debug y presets

En juego, **Tab** (o F1) abre el menú de debug, con una pestaña por sección:
Mapa, Cielo, Luz, Jugador, Ritmo y Sistema. Cada slider tiene un campo numérico
editable y su rango en el tooltip.

Cada sección (menos Sistema) tiene su barra de presets: **Cargar** aplica un `.tres`
sobre la configuración en vivo y **Exportar sección** guarda la actual con un nombre.
Ejecutando desde el editor se exporta a `src/shared/resources/presets/<sección>/`
(para versionarlo); en un build exportado, a `user://presets/<sección>/`.

| Sección | Recurso | Carpeta de presets |
|---|---|---|
| Mapa | `AzoteaParams` | `mapa/` |
| Cielo | `SkyParams` | `cielo/` |
| Luz | `LightingParams` | `iluminacion/` |
| Jugador | `PlayerParams` | `jugador/` |
| Ritmo | `RhythmParams` (en `Conductor.params`) | `ritmo/` |

## Reglas de implementación

- Todo el azar sale de un `RandomNumberGenerator` sembrado; nada de `randf()` global.
- Estructura (azoteas, colisiones) en GDScript; detalle por píxel (grano, mugre,
  semitono, glitch) en shaders `canvas_item` (el renderer Compatibility no tiene compute).
- Todo lo que late lee `Conductor.pulse()`; nada usa `TIME` para el tempo.
- Las texturas de las siluetas se anclan a coordenadas locales para no "nadar" con el parallax.
