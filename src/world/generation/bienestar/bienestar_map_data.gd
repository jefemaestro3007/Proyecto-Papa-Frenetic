class_name BienestarMapData
extends RefCounted
## Resultado puro de BienestarGenerator: geometría de juego (pisos, sólidos, plataformas), los
## elementos con mecánica (racks, freezers, cintas, carritos, escaleras mecánicas, cortinas,
## freidoras, piso mojado) y la decoración en profundidad (góndolas del fondo, locales, carteles).
## No sabe cómo se dibuja. El piso `f` tiene su superficie en `floors[f].y` (y crece hacia abajo).

## Tipos de sección (deciden qué hay en cada tramo de un piso).
enum Section { ENTRANCE, AISLES, FREEZERS, PRODUCE, WET, CARTS, CHECKOUTS, EXIT, STORES, FOOD_COURT }

var mall := false
var floors: Array[Floor] = []
## Sólidos rectangulares (pallets, mostradores, islas, freezers horizontales, muros de los extremos)
## y, en paralelo, qué es cada uno (para dibujarlo).
var solids: Array[Rect2] = []
var blocks: Array[Block] = []
## Losas de los pisos (con los huecos del atrio ya recortados).
var slabs: Array[Rect2] = []
var racks: Array[Rack] = []
var freezers: Array[Freezer] = []
var belts: Array[Belt] = []
## Piso mojado: rectángulo de la superficie (alto 24 px, apoyado en el piso).
var wet: Array[Rect2] = []
## Carriles donde se pueden montar carritos (posición de los pies del carrito estacionado).
var carts: Array[Vector2] = []
var escalators: Array[Escalator] = []
var shutters: Array[Shutter] = []
var fryers: Array[Fryer] = []
## Decoración jugable-neutra en el plano de juego (sin colisión): exhibidores, plantas, carteles de pie.
var props: Array[Prop] = []
var gondolas: Array[Gondola] = []
var stores: Array[Store] = []
var signs: Array[HangingSign] = []
## Tramos del techo por donde se ve el cielo (x inicial, x final) por piso: Vector3(piso, x0, x1).
var skylights: Array[Vector3] = []
var sections: Array[SectionSpan] = []
## Marcas que cada estilo muestra en su medida (MapMark.weight): en la pared del fondo (grietas,
## manchas, sangre, afiches, grafitis; en coordenadas del plano de la pared) y en el piso del plano
## jugable (papeles, escombros, huesos, charcos de sangre).
var wall_marks: Array[MapMark] = []
var floor_marks: Array[MapMark] = []
## Carriles de las papas: Vector3(piso, izquierda, derecha).
var lanes: Array[Vector3] = []
var spawn := Vector2.ZERO
## Llegar acá gana la partida.
var goal := Rect2()
var bounds := Rect2()
## Profundidad de la pared del fondo (ver BienestarParams.depth).
var depth := 0.45


class Floor:
	extends RefCounted
	var y: float
	var ceiling: float
	var left: float
	var right: float
	## Huecos del atrio en la losa de este piso: Vector2(x0, x1).
	var holes: Array[Vector2] = []

	func _init(p_y: float, p_ceiling: float, p_left: float, p_right: float) -> void:
		y = p_y
		ceiling = p_ceiling
		left = p_left
		right = p_right

	func has_hole(x: float) -> bool:
		for hole in holes:
			if x > hole.x and x < hole.y:
				return true
		return false


## Sólido con su tipo: la colisión es exactamente `rect` (el frente del prisma que se dibuja).
class Block:
	extends RefCounted
	enum Kind { WALL, PALLET, STAND, CHEST_FREEZER, COUNTER, PLANTER, FRYER, DEBRIS }
	var kind: Kind
	var rect: Rect2
	var variant: int

	func _init(p_kind: Kind, p_rect: Rect2, p_variant: int) -> void:
		kind = p_kind
		rect = p_rect
		variant = p_variant


class SectionSpan:
	extends RefCounted
	var type: Section
	var floor: int
	var x0: float
	var x1: float

	func _init(p_type: Section, p_floor: int, p_x0: float, p_x1: float) -> void:
		type = p_type
		floor = p_floor
		x0 = p_x0
		x1 = p_x1


## Rack de bodega sobre el pasillo: dos parantes y una viga (plataforma de un solo sentido) cargada
## de cajas. Estar debajo o encima suma beats; al llegar al límite se derrumba.
class Rack:
	extends RefCounted
	var floor: int
	## De parante a parante; `rect.position.y` es la cara de arriba de la viga.
	var rect: Rect2
	var variant: int

	func _init(p_floor: int, p_rect: Rect2, p_variant: int) -> void:
		floor = p_floor
		rect = p_rect
		variant = p_variant


## Freezer vertical contra el fondo: puertas de vidrio que abren y cierran con el beat.
class Freezer:
	extends RefCounted
	var floor: int
	var rect: Rect2
	## Beat (dentro de un ciclo de 4) en que abre; cierra 2 beats después.
	var phase: int
	var variant: int

	func _init(p_floor: int, p_rect: Rect2, p_phase: int, p_variant: int) -> void:
		floor = p_floor
		rect = p_rect
		phase = p_phase
		variant = p_variant


## Caja registradora con cinta: el mostrador es sólido y su cara de arriba es la cinta.
class Belt:
	extends RefCounted
	var floor: int
	var rect: Rect2
	## Hacia dónde lleva la cinta (+1 derecha).
	var direction: float

	func _init(p_floor: int, p_rect: Rect2, p_direction: float) -> void:
		floor = p_floor
		rect = p_rect
		direction = p_direction


## Escalera mecánica de fondo entre el piso `floor` (pie) y el de arriba (cima).
class Escalator:
	extends RefCounted
	var floor: int
	var foot: Vector2
	var top: Vector2
	## Sentido inicial (+1 sube) y desfase en compases del cambio de sentido.
	var start_up: bool
	var phase_bars: int

	func _init(p_floor: int, p_foot: Vector2, p_top: Vector2, p_start_up: bool, p_phase_bars: int) -> void:
		floor = p_floor
		foot = p_foot
		top = p_top
		start_up = p_start_up
		phase_bars = p_phase_bars

	## Si sube en el compás `bar` (cambia cada `bars` compases).
	func going_up(bar: int, bars: int) -> bool:
		var flips := floori(float(bar + phase_bars) / maxi(bars, 1))
		return start_up == (posmod(flips, 2) == 0)


## Cortina metálica que cruza el pasillo: ciclo abierta → bajando → cerrada → sube (en beats).
class Shutter:
	extends RefCounted
	var floor: int
	var x: float
	var width: float
	## Desfase del ciclo en beats.
	var phase: int
	## Nombre del local que cierra.
	var store: String

	func _init(p_floor: int, p_x: float, p_width: float, p_phase: int, p_store: String) -> void:
		floor = p_floor
		x = p_x
		width = p_width
		phase = p_phase
		store = p_store


## Mostrador de freidoras del patio de comidas: sólido, salpica aceite alrededor cada N beats.
class Fryer:
	extends RefCounted
	var floor: int
	var rect: Rect2
	var phase: int

	func _init(p_floor: int, p_rect: Rect2, p_phase: int) -> void:
		floor = p_floor
		rect = p_rect
		phase = p_phase


## Objeto decorativo apoyado en el piso, sin colisión.
class Prop:
	extends RefCounted
	enum Type { DISPLAY, PLANT, STANDEE, BIN, BENCH, KIOSK, TABLE, SCALE, CART_CORRAL, MOP_BUCKET, PRICE_STAND }
	var type: Type
	var rect: Rect2
	var variant: int

	func _init(p_type: Type, p_rect: Rect2, p_variant: int) -> void:
		type = p_type
		rect = p_rect
		variant = p_variant


## Góndola del fondo: cabecera en el plano `front` (profundidad) que se aleja hasta la pared.
class Gondola:
	extends RefCounted
	var floor: int
	## Ancho de la cabecera (x0, x1) en el plano jugable y alto.
	var x0: float
	var x1: float
	var height: float
	## Número de pasillo y rubro (para el cartel colgante).
	var aisle: int
	var category: String
	## Volcada por la ruina (se dibuja inclinada y con productos en el piso).
	var fallen: bool
	var variant: int

	func _init(p_floor: int, p_x0: float, p_x1: float, p_height: float, p_aisle: int, p_category: String,
			p_fallen: bool, p_variant: int) -> void:
		floor = p_floor
		x0 = p_x0
		x1 = p_x1
		height = p_height
		aisle = p_aisle
		category = p_category
		fallen = p_fallen
		variant = p_variant


## Local del centro comercial en la pared del fondo.
class Store:
	extends RefCounted
	var floor: int
	var x0: float
	var x1: float
	var name: String
	var color: Color
	## Cortina metálica baja (local cerrado).
	var closed: bool
	var variant: int

	func _init(p_floor: int, p_x0: float, p_x1: float, p_name: String, p_color: Color, p_closed: bool,
			p_variant: int) -> void:
		floor = p_floor
		x0 = p_x0
		x1 = p_x1
		name = p_name
		color = p_color
		closed = p_closed
		variant = p_variant


## Cartel colgado del techo: precio, número de pasillo u OFERTA (prisma que gira en cada beat).
class HangingSign:
	extends RefCounted
	enum Type { PRICE, AISLE, OFFER, EXIT }
	var type: Type
	var position: Vector2
	var text: String
	var variant: int

	func _init(p_type: Type, p_position: Vector2, p_text: String, p_variant: int) -> void:
		type = p_type
		position = p_position
		text = p_text
		variant = p_variant


## Superficie (y) del piso `f`.
func surface_y(f: int) -> float:
	return floors[clampi(f, 0, floors.size() - 1)].y


## Piso cuyo tramo contiene a `point` (los pies), o -1.
func floor_at(point: Vector2) -> int:
	for f in range(floors.size() - 1, -1, -1):
		var floor := floors[f]
		if point.y <= floor.y + 30.0 and point.y > floor.ceiling and point.x >= floor.left and point.x <= floor.right:
			return f
	return -1


## Sección del piso `f` que contiene la x, o null.
func section_at(f: int, x: float) -> SectionSpan:
	for span in sections:
		if span.floor == f and x >= span.x0 and x < span.x1:
			return span
	return null
