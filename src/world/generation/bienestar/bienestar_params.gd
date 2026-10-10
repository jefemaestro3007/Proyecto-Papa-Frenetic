@tool
class_name BienestarParams
extends Resource
## Parámetros de Bienestar U (nivel 3): supermercado o centro comercial. Misma seed + mismos
## parámetros => misma tienda. Ver docs/game-design/art-direction/perspectiva-de-oferta.md.

enum Mode { SUPERMARKET, MALL }

@export var seed: int = 1:
	set(value):
		seed = value
		emit_changed()

@export_group("Tienda")
## Supermercado (un piso largo) o centro comercial (varios pisos con escaleras mecánicas).
@export_enum("Supermercado", "Centro comercial") var mode: int = 0:
	set(value):
		mode = value
		emit_changed()
## Secciones de la tienda (en el centro comercial, por piso).
@export_range(3, 24) var sections: int = 8:
	set(value):
		sections = value
		emit_changed()
## Pisos del centro comercial.
@export_range(2, 5) var floors: int = 3:
	set(value):
		floors = value
		emit_changed()
## Alto de cada piso del centro comercial (px).
@export_range(420.0, 700.0) var floor_height: float = 520.0:
	set(value):
		floor_height = value
		emit_changed()
## Alto del techo del supermercado (px).
@export_range(500.0, 1000.0) var ceiling_height: float = 720.0:
	set(value):
		ceiling_height = value
		emit_changed()

@export_group("Secciones del supermercado")
## Pasillos de góndolas con racks.
@export_range(0.0, 4.0) var aisle_weight: float = 1.4:
	set(value):
		aisle_weight = value
		emit_changed()
## Congelados.
@export_range(0.0, 4.0) var freezer_weight: float = 1.0:
	set(value):
		freezer_weight = value
		emit_changed()
## Frutas y verduras.
@export_range(0.0, 4.0) var produce_weight: float = 0.8:
	set(value):
		produce_weight = value
		emit_changed()
## Piso mojado.
@export_range(0.0, 4.0) var wet_weight: float = 0.6:
	set(value):
		wet_weight = value
		emit_changed()
## Pasillo largo con carritos.
@export_range(0.0, 4.0) var cart_weight: float = 0.7:
	set(value):
		cart_weight = value
		emit_changed()
## Cajas con cinta antes de la salida.
@export_range(1, 8) var checkouts: int = 4:
	set(value):
		checkouts = value
		emit_changed()
## Probabilidad de rack sobre cada tramo libre de un pasillo.
@export_range(0.0, 1.0) var rack_chance: float = 0.7:
	set(value):
		rack_chance = value
		emit_changed()
## Charcos sueltos en otras secciones.
@export_range(0.0, 1.0) var spill_chance: float = 0.25:
	set(value):
		spill_chance = value
		emit_changed()

@export_group("Centro comercial")
## Escaleras mecánicas entre cada par de pisos.
@export_range(1, 3) var escalators_per_floor: int = 2:
	set(value):
		escalators_per_floor = value
		emit_changed()
## Cortinas metálicas que cruzan el pasillo, por sección.
@export_range(0.0, 1.0) var shutter_chance: float = 0.45:
	set(value):
		shutter_chance = value
		emit_changed()
## Huecos del atrio (se cae al piso de abajo), por sección.
@export_range(0.0, 1.0) var hole_chance: float = 0.3:
	set(value):
		hole_chance = value
		emit_changed()
## Patio de comidas con freidoras en el último piso.
@export var food_court: bool = true:
	set(value):
		food_court = value
		emit_changed()

@export_group("Ambientación")
## Productos en góndolas y estantes.
@export_range(0.0, 1.0) var product_density: float = 0.8:
	set(value):
		product_density = value
		emit_changed()
## Carteles colgantes (precios, ofertas).
@export_range(0.0, 1.0) var sign_density: float = 0.6:
	set(value):
		sign_density = value
		emit_changed()
## Daño: góndolas volcadas, cajas rotas, luces muertas.
@export_range(0.0, 1.0) var ruin: float = 0.35:
	set(value):
		ruin = value
		emit_changed()
## Profundidad de la pared del fondo (0 = plano jugable, 1 = punto de fuga).
@export_range(0.15, 0.7) var depth: float = 0.45:
	set(value):
		depth = value
		emit_changed()

@export_group("Mecánicas")
## Beats debajo o encima de un rack antes de que se derrumbe.
@export_range(2, 16) var rack_collapse_beats: int = 6:
	set(value):
		rack_collapse_beats = value
		emit_changed()
## Calor que enfría por segundo frente a un freezer abierto...
@export_range(0.0, 30.0) var freezer_cooling: float = 6.0:
	set(value):
		freezer_cooling = value
		emit_changed()
## ...y como mucho esto por freezer (después se vacía).
@export_range(0.0, 100.0) var freezer_cap: float = 18.0:
	set(value):
		freezer_cap = value
		emit_changed()
## Velocidad del jugador con la escarcha.
@export_range(0.2, 1.0) var freezer_slow: float = 0.7:
	set(value):
		freezer_slow = value
		emit_changed()
## Agarre sobre el piso mojado.
@export_range(0.02, 1.0) var wet_traction: float = 0.12:
	set(value):
		wet_traction = value
		emit_changed()
## Lo que avanza una cinta de caja en cada beat (px).
@export_range(0.0, 600.0) var belt_step: float = 150.0:
	set(value):
		belt_step = value
		emit_changed()
## Velocidad máxima en carrito (× la normal).
@export_range(1.0, 3.0) var cart_speed_scale: float = 1.7:
	set(value):
		cart_speed_scale = value
		emit_changed()
## Desde esta velocidad el carrito atropella papas.
@export_range(100.0, 1500.0) var cart_ram_speed: float = 500.0:
	set(value):
		cart_ram_speed = value
		emit_changed()
## Compases entre cambios de sentido de una escalera mecánica.
@export_range(1, 16) var escalator_bars: int = 4:
	set(value):
		escalator_bars = value
		emit_changed()
## Lo que tarda el viaje a favor.
@export_range(0.4, 4.0) var escalator_seconds: float = 1.3:
	set(value):
		escalator_seconds = value
		emit_changed()
## A contramano se avanza esta fracción...
@export_range(0.05, 1.0) var escalator_against: float = 0.25:
	set(value):
		escalator_against = value
		emit_changed()
## ...más esto por cada paso (W/S) a tiempo.
@export_range(0.0, 0.5) var escalator_step: float = 0.14:
	set(value):
		escalator_step = value
		emit_changed()
## Cortina: beats abierta...
@export_range(2, 32) var shutter_open_beats: int = 8:
	set(value):
		shutter_open_beats = value
		emit_changed()
## ...bajando...
@export_range(2, 32) var shutter_lower_beats: int = 8:
	set(value):
		shutter_lower_beats = value
		emit_changed()
## ...y cerrada antes de volver a subir.
@export_range(1, 32) var shutter_closed_beats: int = 4:
	set(value):
		shutter_closed_beats = value
		emit_changed()
## Calor de una salpicadura de aceite.
@export_range(0.0, 40.0) var fryer_heat: float = 6.0:
	set(value):
		fryer_heat = value
		emit_changed()
## Las freidoras salpican cada tantos beats.
@export_range(1, 8) var fryer_every: int = 2:
	set(value):
		fryer_every = value
		emit_changed()


func is_mall() -> bool:
	return mode == Mode.MALL
