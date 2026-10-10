class_name AzoteaMapData
extends RefCounted
## Resultado puro de AzoteaGenerator: geometría de juego (azoteas), detalles decorativos
## (objetos, marcas, cables) y fondo (skyline). No sabe nada de cómo se dibuja: eso es del ArtStyle.

## Cada azotea es el rectángulo sólido del edificio; `position.y` es la superficie pisable.
var roofs: Array[Rect2] = []
var spawn: Vector2 = Vector2.ZERO
## Y por debajo de la cual se considera caída al vacío.
var kill_y: float = 0.0
var props: Array[Prop] = []
var marks: Array[MapMark] = []
var cables: Array[Cable] = []
var far: SkylineData = SkylineData.new()
var near: SkylineData = SkylineData.new()


class SkylineData:
	extends RefCounted
	var buildings: Array[PackedVector2Array] = []
	var windows: Array[Rect2] = []
	var width: float = 0.0


## Objeto apoyado sobre una azotea. `rect` va de la base (sobre el techo) hacia arriba.
class Prop:
	extends RefCounted
	enum Type {
		AC_UNIT, WATER_TANK, ANTENNA, VENT, CHIMNEY, STAIR_HUT, SKYLIGHT, BILLBOARD,
		BARREL, CRATES, SATELLITE_DISH, PIPE_RUN,
	}
	var type: Type
	var rect: Rect2
	## Semilla propia para variaciones de dibujo deterministas.
	var variant: int
	var roof_index: int

	func _init(p_type: Type, p_rect: Rect2, p_variant: int, p_roof_index: int) -> void:
		type = p_type
		rect = p_rect
		variant = p_variant
		roof_index = p_roof_index


## Cable colgado entre postes de dos azoteas vecinas.
class Cable:
	extends RefCounted
	var from: Vector2
	var to: Vector2
	var sag: float
	var from_base_y: float
	var to_base_y: float

	func _init(p_from: Vector2, p_to: Vector2, p_sag: float, p_from_base_y: float, p_to_base_y: float) -> void:
		from = p_from
		to = p_to
		sag = p_sag
		from_base_y = p_from_base_y
		to_base_y = p_to_base_y
