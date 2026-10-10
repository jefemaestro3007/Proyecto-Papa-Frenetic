# Flujo de ramas (GitFlow)

Este documento define las reglas de ramificación y merge del proyecto.
Cualquier aporte debe seguir este flujo.

## Ramas permanentes

### `main`

- Contiene **solo versiones estables y publicables**.
- **Prohibido** commitear directamente. Solo recibe merges desde `develop`
  (o desde `hotfix/*` cuando se habiliten).
- Cada merge a `main` se etiqueta con una versión semántica: `vMAYOR.MENOR.PARCHE`.
- Debe estar siempre desplegable/jugable.

### `develop`

- Rama de **integración**. Es la base de todo el desarrollo.
- Debe **compilar e importar en Godot sin errores** en todo momento.
- Recibe merges de las ramas `feature/*`.
- Es la rama de la que nacen nuevas `feature/*`.

## Ramas temporales

### `feature/<nombre-corto>`

- Rama de trabajo para **una sola funcionalidad o cambio**.
- Nace **siempre** desde `develop` actualizado.
- Nombre en minúsculas y `kebab-case`: `feature/player-movement`,
  `feature/asset-structure`.
- Vida corta: se integra a `develop` y se elimina.
- Una feature no debe mezclar temas no relacionados.

## Ciclo de vida de una feature

```bash
# 1. Actualizar develop
git checkout develop
git pull

# 2. Crear la rama de trabajo
git checkout -b feature/mi-funcionalidad

# 3. Desarrollar y commitear
git add -A
git commit -m "feat(scope): descripción"

# 4. Integrar a develop (vía Pull Request en el remoto)
git checkout develop
git merge --no-ff feature/mi-funcionalidad

# 5. Eliminar la rama ya integrada
git branch -d feature/mi-funcionalidad
```

## Convención de commits

Se usa **Conventional Commits**:

```
<tipo>(<ámbito>): <descripción en imperativo>
```

| Tipo       | Uso                                        |
|------------|--------------------------------------------|
| `feat`     | Nueva funcionalidad                        |
| `fix`      | Corrección de bug                          |
| `refactor` | Cambio de código sin alterar comportamiento |
| `docs`     | Documentación                              |
| `test`     | Tests                                      |
| `chore`    | Mantenimiento, configs, dependencias       |
| `ci`       | Integración continua                       |
| `perf`     | Mejora de rendimiento                      |

Ejemplos: `feat(combat): hitboxes por arma`, `fix(ui): menú no pausa el juego`.

## Pull Requests

- Toda integración a `develop` o `main` se hace vía **Pull Request**.
- El PR debe:
  - Apuntar de `feature/*` → `develop` (o `develop` → `main` en releases).
  - Describir qué cambia, por qué y cómo probarlo.
  - Pasar CI en verde.
  - Recibir **al menos 1 revisión aprobada**.
- No se hace merge con conflictos sin resolver.

## Reglas de merge

- `feature/*` → `develop`: **`merge --no-ff`** (conserva la historia de la
  feature y crea un commit de merge).
- `develop` → `main`: **`merge --no-ff`** al publicar.
- Nunca `rebase` de ramas ya pusheadas/compartidas.
- Tras el merge, eliminar la rama temporal.

## Releases y versionado

- El proyecto usa **Versionado Semántico** (`MAYOR.MENOR.PARCHE`).
- Al cerrar una release:
  1. Actualizar `CHANGELOG.md`.
  2. Merge `develop` → `main`.
  3. Etiquetar: `git tag -a v0.1.0 -m "Release v0.1.0"`.
  4. Subir la etiqueta: `git push origin v0.1.0`.
- Las versiones del `project.godot` (`application/config/version`) y la
  etiqueta Git deben coincidir.

## Ramas protegidas

En el remoto, `main` y `develop` deben configurarse como ramas protegidas:

- Sin push directo.
- Requerir Pull Request + revisión.
- Requerir checks de CI en verde.

## Notas

- Las ramas `release/*` y `hotfix/*` del GitFlow clásico **no se usan por
  ahora**. Si el proyecto lo requiere más adelante, se documentarán aquí.
- Ante cualquier duda: la fuente de verdad es `develop`; `main` es solo lo
  publicado.
