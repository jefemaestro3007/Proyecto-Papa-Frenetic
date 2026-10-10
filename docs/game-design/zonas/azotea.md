# Zona Azotea

Recorrido de izquierda a derecha por azoteas en ruinas, con la ciudad de fondo. Escena:
`src/world/levels/azotea/azotea.tscn`.

```bash
godot --path . res://src/world/levels/azotea/azotea.tscn
```

## Controles

| Acción | Tecla |
|---|---|
| Mover / saltar | A/D (o ←/→) · Espacio |
| Atacar | J o clic izquierdo |
| Caída forzada (en el aire) | S (o ↓) |
| Menú de debug · cambiar estilo | Tab · F2 |
| Seed aleatoria / siguiente / anterior | R / N / P |

## Mapa

- **Azoteas** de ancho y altura variables con huecos; los escalones nunca superan la altura de
  salto. La primera azotea es una zona segura.
- **Skyline** en dos capas de parallax infinitas. Su perfil sale del mismo campo de ruido que
  el relieve de las azoteas, así fondo y mapa "riman". Las ventanas solo aparecen dentro de la
  silueta de cada edificio.
- **Detalles**: aires, tanques, antenas, ventilaciones, chimeneas, casetas, tragaluces,
  carteles, barriles con fuego, cajas, parabólicas, tuberías, cables con banderines, ventanas
  de fachada, bajantes, afiches, grafitis, aires de pared, grietas, manchas, sangre, escombros y
  huesos. Cada estilo decide qué fracción de cada marca se ve.

## Ritmo e impacto

- Saltar, girar y aterrizar en el beat suma combo y da recompensas (salto más alto, impulso).
- Solo "atacan" (rayos, escombros, glitch, temblor) las caídas forzadas y las que superan la
  altura configurable `hard_landing_height`. La caída forzada a tiempo da puntos extra; fuera
  de tiempo rompe el combo y aturde.

## Parámetros

Todos en la pestaña Mapa (`AzoteaParams`) y exportables como presets en `presets/mapa/`.
