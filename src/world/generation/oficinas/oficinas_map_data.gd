class_name OficinasMapData
extends RefCounted
## Geometría y ambientación del edificio de oficinas, derivadas de un OficinasLayout.
## Coordenadas: el piso f tiene su superficie en y = -f * floor_height; el módulo c empieza en x = c * module_width.

enum RoomTheme { OFFICE, ARCHIVE, MEETING, COPY_ROOM, BREAK_ROOM, CORRIDOR }

const SLAB := 32.0
const WALL := 24.0
const DOOR_HEIGHT := 200.0
const GAP_WIDTH := 170.0
const FOUNDATION := 400.0

var layout: OficinasLayout
var module_width: float
var floor_height: float

## Todo lo sólido (losas, muros, dinteles, fachadas, módulos sellados).
var solids: Array[Rect2] = []
var slabs: Array[Rect2] = []
var walls: Array[Rect2] = []
var stairs: Array[Stair] = []
var elevators: Array[ElevatorSpec] = []
var rooms: Array[Room] = []
var windows: Array[Rect2] = []
## Agujeros de la pared del fondo (polígonos que tocan el borde superior del módulo).
var wall_holes: Array[PackedVector2Array] = []
var furniture: Array[Furniture] = []
var lamps: Array[Lamp] = []
var marks: Array[MapMark] = []
## Bordes rotos de losa (huecos y derrumbes) para dibujar hierros y escombros.
var broken_edges: Array[Vector2] = []
var door_openings: Array[Rect2] = []
var sealed: Array[Rect2] = []
var spawn := Vector2.ZERO
var goal := Rect2()
var bounds := Rect2()
var far := AzoteaMapData.SkylineData.new()
var near := AzoteaMapData.SkylineData.new()


func surface_y(f: int) -> float:
	return -f * floor_height


## Cara inferior de la losa del piso de arriba.
func ceiling_y(f: int) -> float:
	return surface_y(f + 1) + SLAB


func module_rect(f: int, c: int) -> Rect2:
	return Rect2(c * module_width, ceiling_y(f), module_width, surface_y(f) - ceiling_y(f))


## Nodo (piso, módulo) en el que está parado un punto de los pies, o (-1, -1).
func node_at(feet: Vector2) -> Vector2i:
	var f := roundi(-feet.y / floor_height)
	var c := floori(feet.x / module_width)
	if f < 0 or f >= layout.floors or c < 0 or c >= layout.modules:
		return Vector2i(-1, -1)
	if absf(feet.y - surface_y(f)) > 12.0:
		return Vector2i(-1, -1)
	return Vector2i(f, c)


class Stair:
	extends RefCounted
	var low: Vector2
	var high: Vector2
	var floor: int
	var column: int

	func _init(p_low: Vector2, p_high: Vector2, p_floor: int, p_column: int) -> void:
		low = p_low
		high = p_high
		floor = p_floor
		column = p_column


class ElevatorSpec:
	extends RefCounted
	var column: int
	var kind: OficinasLayout.Lift
	var x: float
	var width: float
	## Superficies de las paradas, de abajo hacia arriba.
	var stop_ys := PackedFloat32Array()
	var shaft_top: float
	var shaft_bottom: float
	var phase: float


class Room:
	extends RefCounted
	var floor: int
	var first: int
	var last: int
	var theme: RoomTheme
	var rect: Rect2


class Furniture:
	extends RefCounted
	enum Type {
		DESK, CHAIR, FILING_CABINET, SHELF, WATER_COOLER, PLANT, COPIER, VENDING, MEETING_TABLE,
		WHITEBOARD, NOTICE_BOARD, CLOCK, BOXES, PAPER_STACK, FALLEN_CABINET, EXIT_SIGN,
	}
	var type: Type
	var rect: Rect2
	var variant: int

	func _init(p_type: Type, p_rect: Rect2, p_variant: int) -> void:
		type = p_type
		rect = p_rect
		variant = p_variant


class Lamp:
	extends RefCounted
	var position: Vector2
	var working: bool
	var variant: int

	func _init(p_position: Vector2, p_working: bool, p_variant: int) -> void:
		position = p_position
		working = p_working
		variant = p_variant
