# 0001 — Generación procedural nativa en Godot

**Estado:** aceptada

## Contexto

La referencia de arte algorítmico disponible (skill `algorithmic-art`) trabaja con p5.js en
un visor HTML. Los mapas necesitan además datos de juego (colisiones, rutas) y deben poder
generarse por seed en tiempo de ejecución.

## Decisión

- La generación se hace en **GDScript**, con un único `RandomNumberGenerator` sembrado por
  generador (nunca `randf()` global ni `Array.shuffle()`).
- La estructura (mapas, colisiones, grafos) se calcula en GDScript; el detalle por píxel
  (cielo, mugre, semitono, post-proceso) va en shaders `canvas_item`. El renderer
  Compatibility no tiene compute shaders.
- p5.js queda como herramienta opcional de bocetos, nunca como fuente de assets finales.
- Los generadores son puros (sin nodos) para poder testearlos headless.

## Consecuencias

Mapas reproducibles por seed, editables en vivo desde el menú de debug y verificables con
tests automáticos.
