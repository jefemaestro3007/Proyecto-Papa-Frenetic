class_name OficinasMapData
extends RefCounted
## Geometría y ambientación del edificio de oficinas, derivadas de un OficinasLayout.
## Coordenadas: el piso f tiene su superficie en y = -f * floor_height; el módulo c empieza en
## x = c * module_width. Las áreas al fondo (habitaciones y pasillos) se ubican bajo el edificio,
## lejos de la vista, cada una en su propia franja.

enum RoomTheme {
	# Módulos del edificio.
	OFFICE, OPEN_PLAN, ARCHIVE, MEETING, COPY_ROOM, BREAK_ROOM, RECEPTION, LOBBY, HALLWAY, CONSTRUCTION,
	# Habitaciones al fondo.
	EXECUTIVE, SERVER, BATHROOM, STORAGE, JANITOR, RECORDS, SECURITY, KITCHEN,
	# Pasillos al fondo.
	SERVICE_HALL, MAINTENANCE, FIRE_ESCAPE, BACK_HALL, COLLAPSED_HALL,
}

const SLAB := 32.0
const WALL := 24.0
const DOOR_HEIGHT := 200.0
const DOOR_WIDTH := 110.0
const GAP_WIDTH := 170.0
const FOUNDATION := 400.0
## Distancia horizontal a la que se puede usar una escalera, ascensor o puerta al fondo.
const INTERACT_RANGE := 70.0
const AREA_GAP := 600.0

var layout: OficinasLayout
var module_width: float
var floor_height: float

var solids: Array[Rect2] = []
var slabs: Array[Rect2] = []
var walls: Array[Rect2] = []
var wall_doors: Array[WallDoor] = []
var stairs: Array[Stair] = []
var elevators: Array[ElevatorSpec] = []
var depth_doors: Array[DepthDoorSpec] = []
var areas: Array[Area] = []
var keys: Array[KeySpec] = []
var rooms: Array[Room] = []
var windows: Array[Rect2] = []
## Agujeros de la pared del fondo (polígonos que tocan el borde superior del módulo).
var wall_holes: Array[PackedVector2Array] = []
var furniture: Array[Furniture] = []
var lamps: Array[Lamp] = []
var marks: Array[MapMark] = []
var broken_edges: Array[Vector2] = []
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


func module_center(c: int) -> float:
	return (c + 0.5) * module_width


## Nodo (piso, módulo) en el que está parado un punto de los pies, o (-1, -1) (también si está
## dentro de un área al fondo).
func node_at(feet: Vector2) -> Vector2i:
	var f := roundi(-feet.y / floor_height)
	var c := floori(feet.x / module_width)
	if f < 0 or f >= layout.floors or c < 0 or c >= layout.modules:
		return Vector2i(-1, -1)
	if absf(feet.y - surface_y(f)) > 12.0:
		return Vector2i(-1, -1)
	return Vector2i(f, c)


## Área al fondo que contiene el punto, o -1 (edificio).
func area_at(point: Vector2) -> int:
	for i in areas.size():
		if areas[i].bounds.has_point(point):
			return i
	return -1


func room_at(f: int, c: int) -> Room:
	for room in rooms:
		if room.floor == f and c >= room.first and c <= room.last:
			return room
	return null


class Stair:
	extends RefCounted
	var floor: int
	var column: int
	var dir: int
	## Pie (piso de abajo) y llegada (piso de arriba).
	var foot: Vector2
	var top: Vector2

	func _init(p_floor: int, p_column: int, p_dir: int, p_foot: Vector2, p_top: Vector2) -> void:
		floor = p_floor
		column = p_column
		dir = p_dir
		foot = p_foot
		top = p_top


class ElevatorSpec:
	extends RefCounted
	var id: int
	var column: int
	var kind: OficinasLayout.Lift
	var low: int
	var high: int
	var stops := PackedInt32Array()
	var x: float
	var shaft: Rect2


class WallDoor:
	extends RefCounted
	var floor: int
	var boundary: int
	var rect: Rect2
	## Llave que la abre (o -1 si es una puerta común).
	var key: int


class DepthDoorSpec:
	extends RefCounted
	var id: int
	var floor: int
	var module: int
	var kind: OficinasLayout.Depth
	var rect: Rect2
	var area: int


class Area:
	extends RefCounted
	var kind: OficinasLayout.Depth
	var theme: RoomTheme
	## Interior: el piso está en rect.end.y.
	var rect: Rect2
	## Rect con muros y losas, para saber si alguien está adentro.
	var bounds: Rect2
	var doors: Array[AreaDoor] = []
	var furniture: Array[Furniture] = []
	var lamps: Array[Lamp] = []
	var marks: Array[MapMark] = []
	var solids: Array[Rect2] = []

	func floor_y() -> float:
		return rect.end.y


class AreaDoor:
	extends RefCounted
	var x: float
	## Puerta al fondo del edificio a la que lleva.
	var depth_door: int

	func _init(p_x: float, p_depth_door: int) -> void:
		x = p_x
		depth_door = p_depth_door


class KeySpec:
	extends RefCounted
	var id: int
	var position: Vector2
	## Área al fondo donde está, o -1 (edificio).
	var area: int


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
		CUBICLE, SOFA, COUNTER, COLUMN, BENCH, CONE, SCAFFOLD, EXTINGUISHER, PAINTING, TRASH_BIN,
		COAT_RACK, TV, SERVER_RACK, TOILET_STALL, SINK, MIRROR, SAFE, EXEC_DESK, LOCKER, MOP_BUCKET,
		PIPES, FRIDGE, MICROWAVE, MONITOR_WALL, CRT_STACK, BLINDS, FAN, LADDER,
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
