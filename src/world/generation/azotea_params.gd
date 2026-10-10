@tool
class_name AzoteaParams
extends Resource
## Parámetros de generación de la ciudad en ruinas. Misma seed + mismos parámetros => mismo mapa.

@export var seed: int = 1:
	set(value):
		seed = value
		emit_changed()

@export_group("Azoteas (mapa)")
@export_range(3, 64) var roof_count: int = 14:
	set(value):
		roof_count = value
		emit_changed()
@export_range(200.0, 2000.0) var roof_width_min: float = 520.0:
	set(value):
		roof_width_min = value
		emit_changed()
@export_range(200.0, 2000.0) var roof_width_max: float = 1100.0:
	set(value):
		roof_width_max = value
		emit_changed()
@export_range(0.0, 1.0) var gap_chance: float = 0.6:
	set(value):
		gap_chance = value
		emit_changed()
@export_range(0.0, 400.0) var gap_max: float = 240.0:
	set(value):
		gap_max = value
		emit_changed()
@export var roof_base_y: float = 780.0:
	set(value):
		roof_base_y = value
		emit_changed()
@export_range(0.0, 400.0) var roof_height_variation: float = 180.0:
	set(value):
		roof_height_variation = value
		emit_changed()
## Escalón máximo entre azoteas; debe ser menor que la altura de salto.
@export_range(0.0, 200.0) var max_step: float = 120.0:
	set(value):
		max_step = value
		emit_changed()

@export_group("Skyline (fondo)")
@export_range(1024, 8192) var skyline_width: int = 4096:
	set(value):
		skyline_width = value
		emit_changed()
## Cuánto se "derrumban" los techos de los edificios del fondo.
@export_range(0.0, 1.0) var ruin: float = 0.55:
	set(value):
		ruin = value
		emit_changed()
## Probabilidad de que una ventana esté rota/oscura.
@export_range(0.0, 1.0) var broken_windows: float = 0.4:
	set(value):
		broken_windows = value
		emit_changed()
