# Proyecto Papa Frenetic

Videojuego desarrollado en **Godot 4**.

## Requisitos

- Godot 4.x

## Flujo de trabajo (GitFlow)

- `main`: versiones estables y publicadas.
- `develop`: integración de cambios.
- `feature/{funcionalidad}`: desarrollo de cada funcionalidad.

Las funcionalidades se crean a partir de `develop` y se integran de vuelta a
`develop` mediante pull request. `develop` se promueve a `main` en cada release.

## Estructura

```
src/
├── core/       # autoloads, eventos, interfaces y utilidades
├── features/   # módulos de gameplay (player, enemies, combat, ...)
├── world/      # niveles, entorno e interactuables
├── ui/         # menús, HUD, diálogos y componentes
├── shared/     # recursos, escenas, assets y temas compartidos
└── main/       # escena y script de entrada
tests/          # unit, integration y test_scenes
tools/          # scripts e importers
docs/           # documentación del proyecto
```

## Ejecución

```bash
godot --path .
```
