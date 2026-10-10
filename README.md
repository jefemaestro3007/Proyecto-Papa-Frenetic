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
assets/         # media importada compartida (textures, audio, fonts, models)
├── textures/   # sprites, tilesets, ui, vfx
├── audio/      # music, sfx, ambience
├── fonts/
└── models/
assets_src/     # fuentes editables (.blend, .psd, .aseprite); Godot las ignora
src/
├── core/       # autoloads, eventos, interfaces y utilidades
├── features/   # módulos de gameplay (player, enemies, combat, ...)
├── world/      # niveles, entorno e interactuables
├── ui/         # menús, HUD, diálogos y componentes
├── shared/     # recursos (.tres), escenas y temas compartidos
└── main/       # escena y script de entrada
tests/          # unit, integration y test_scenes
tools/          # scripts e importers
docs/           # documentación del proyecto
```

> Los binarios (`assets/`, `assets_src/`) se versionan con **Git LFS**.
> `assets_src/` queda fuera de Godot gracias a su archivo `.gdignore`.

## Ejecución

```bash
godot --path .
```
