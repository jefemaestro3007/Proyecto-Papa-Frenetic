@tool
class_name OficinasParams
extends Resource
## Parámetros del edificio de oficinas abandonado. Misma seed + mismos parámetros => mismo edificio.
## Sección "Mapa" del menú de debug en la zona Oficinas (presets en `presets/oficinas/`).

enum EndMode { ARRIBA, ABAJO, DISTANCIA }

@export var seed: int = 1:
	set(value):
		seed = value
		emit_changed()

@export_group("Edificio")
@export_range(2, 24) var floors: int = 8:
	set(value):
		floors = value
		emit_changed()
## Módulos (habitaciones o tramos de pasillo) por piso.
@export_range(3, 16) var modules: int = 8:
	set(value):
		modules = value
		emit_changed()
@export_range(480.0, 1000.0) var module_width: float = 640.0:
	set(value):
		module_width = value
		emit_changed()
@export_range(360.0, 600.0) var floor_height: float = 420.0:
	set(value):
		floor_height = value
		emit_changed()

@export_group("Recorrido")
## ARRIBA: se empieza abajo y se sale arriba. ABAJO: al revés.
## DISTANCIA: se empieza en `start_floor` y se sale `floor_distance` pisos más arriba (o abajo si es negativo).
@export var end_mode: EndMode = EndMode.ARRIBA:
	set(value):
		end_mode = value
		emit_changed()
@export_range(0, 23) var start_floor: int = 2:
	set(value):
		start_floor = value
		emit_changed()
@export_range(-23, 23) var floor_distance: int = 3:
	set(value):
		floor_distance = value
		emit_changed()
## Probabilidad de que la ruta principal vaya en sentido contrario un tramo (desvío).
@export_range(0.0, 1.0) var detour_chance: float = 0.3:
	set(value):
		detour_chance = value
		emit_changed()
## Cambios de piso mínimos en la ruta principal (aunque la salida quede cerca).
@export_range(0, 12) var min_transitions: int = 3:
	set(value):
		min_transitions = value
		emit_changed()
## Rutas alternativas que parten de la principal y también llegan a la salida.
@export_range(0, 8) var branches: int = 2:
	set(value):
		branches = value
		emit_changed()
## Qué tan "edificio real" es: núcleos de escaleras y ascensores alineados, plantas que se
## repiten piso a piso y daño concentrado en zonas (0 = todo al azar).
@export_range(0.0, 1.0) var realism: float = 0.7:
	set(value):
		realism = value
		emit_changed()
## Conectar zonas aisladas para que todo el edificio se pueda recorrer.
@export var reach_everything: bool = true:
	set(value):
		reach_everything = value
		emit_changed()

@export_group("Conexiones (pesos en rutas)")
@export_range(0.0, 4.0) var stairs_weight: float = 1.0:
	set(value):
		stairs_weight = value
		emit_changed()
@export_range(0.0, 4.0) var elevator_weight: float = 0.9:
	set(value):
		elevator_weight = value
		emit_changed()
## Bajar cayendo por huecos o derrumbes.
@export_range(0.0, 4.0) var fall_weight: float = 0.6:
	set(value):
		fall_weight = value
		emit_changed()
## Pasillos al fondo que unen dos puertas (atajos, también entre pisos).
@export_range(0.0, 4.0) var corridor_weight: float = 0.5:
	set(value):
		corridor_weight = value
		emit_changed()
@export_range(0, 2) var corridor_max_floors: int = 2:
	set(value):
		corridor_max_floors = value
		emit_changed()
@export_range(1, 12) var elevator_max_span: int = 5:
	set(value):
		elevator_max_span = value
		emit_changed()
## Pisos que puede atravesar un derrumbe en cadena.
@export_range(1, 6) var collapse_max_depth: int = 2:
	set(value):
		collapse_max_depth = value
		emit_changed()

@export_group("Ascensores")
## Pesos de cada tipo: local (para en cada piso), expreso (solo extremos), de servicio
## (para en cada piso, más lento en llegar) y averiado (local con sacudidas y luces que fallan).
@export_range(0.0, 4.0) var elevator_local_weight: float = 1.0:
	set(value):
		elevator_local_weight = value
		emit_changed()
@export_range(0.0, 4.0) var elevator_express_weight: float = 0.6:
	set(value):
		elevator_express_weight = value
		emit_changed()
@export_range(0.0, 4.0) var elevator_call_weight: float = 0.8:
	set(value):
		elevator_call_weight = value
		emit_changed()
@export_range(0.0, 4.0) var elevator_faulty_weight: float = 0.5:
	set(value):
		elevator_faulty_weight = value
		emit_changed()
## Tiempo máximo que tarda en llegar la cabina al llamarla.
@export_range(0.2, 2.0) var elevator_call_seconds: float = 1.2:
	set(value):
		elevator_call_seconds = value
		emit_changed()
## Duración máxima de un viaje completo (de un extremo al otro).
@export_range(0.3, 1.5) var elevator_trip_seconds: float = 1.2:
	set(value):
		elevator_trip_seconds = value
		emit_changed()
## Las puertas se abren en el beat (como mucho espera un beat).
@export var elevator_sync_to_beat: bool = true:
	set(value):
		elevator_sync_to_beat = value
		emit_changed()

@export_group("Extras y daño")
## Probabilidades por módulo libre (fuera de las rutas).
@export_range(0.0, 0.5) var extra_stairs: float = 0.06:
	set(value):
		extra_stairs = value
		emit_changed()
@export_range(0.0, 0.5) var extra_elevators: float = 0.02:
	set(value):
		extra_elevators = value
		emit_changed()
## Huecos pequeños: se pueden saltar o usar para bajar.
@export_range(0.0, 0.5) var gap_chance: float = 0.06:
	set(value):
		gap_chance = value
		emit_changed()
## Derrumbes: el suelo no existe, obligan a caer.
@export_range(0.0, 0.5) var collapse_chance: float = 0.05:
	set(value):
		collapse_chance = value
		emit_changed()
## Pesos de los muros entre módulos fuera de las rutas.
@export_range(0.0, 4.0) var wall_open_weight: float = 1.0:
	set(value):
		wall_open_weight = value
		emit_changed()
@export_range(0.0, 4.0) var wall_door_weight: float = 1.4:
	set(value):
		wall_door_weight = value
		emit_changed()
@export_range(0.0, 4.0) var wall_blocked_weight: float = 0.6:
	set(value):
		wall_blocked_weight = value
		emit_changed()

@export_group("Habitaciones, puertas y llaves")
## Probabilidad por módulo libre de tener una habitación al fondo (sin salida).
@export_range(0.0, 1.0) var room_chance: float = 0.25:
	set(value):
		room_chance = value
		emit_changed()
## Puertas con llave (cada una con su llave, como máximo 3).
@export_range(0, 3) var locked_doors: int = 2:
	set(value):
		locked_doors = value
		emit_changed()
## Probabilidad de que una llave esté dentro de una habitación (si no, en el piso).
@export_range(0.0, 1.0) var key_in_room_chance: float = 0.6:
	set(value):
		key_in_room_chance = value
		emit_changed()

@export_group("Ambientación")
@export_range(0.0, 1.0) var furniture_density: float = 0.7:
	set(value):
		furniture_density = value
		emit_changed()
@export_range(0.0, 1.0) var window_chance: float = 0.45:
	set(value):
		window_chance = value
		emit_changed()
## Paredes del fondo rotas que dejan ver la ciudad.
@export_range(0.0, 1.0) var wall_damage: float = 0.25:
	set(value):
		wall_damage = value
		emit_changed()
@export_range(0, 16) var marks_per_module: int = 5:
	set(value):
		marks_per_module = value
		emit_changed()
## Lámparas de techo que todavía funcionan (parpadean con el beat).
@export_range(0.0, 1.0) var working_lamps: float = 0.5:
	set(value):
		working_lamps = value
		emit_changed()
@export_range(0.0, 1.0) var skyline_ruin: float = 0.55:
	set(value):
		skyline_ruin = value
		emit_changed()


## Piso de inicio y de salida según el modo.
func start_and_end_floor() -> Vector2i:
	match end_mode:
		EndMode.ABAJO:
			return Vector2i(floors - 1, 0)
		EndMode.DISTANCIA:
			var start := clampi(start_floor, 0, floors - 1)
			return Vector2i(start, clampi(start + floor_distance, 0, floors - 1))
	return Vector2i(0, floors - 1)
