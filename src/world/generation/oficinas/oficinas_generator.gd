class_name OficinasGenerator
extends RefCounted
## Convierte la topología (OficinasLayout) en geometría jugable y ambientación: losas, muros,
## puertas (comunes y con llave), escaleras y ascensores de fondo, puertas al fondo con sus
## áreas (habitaciones y pasillos detallados), llaves, ventanas, daño, mobiliario y marcas.
## La ambientación usa su propio RNG: cambiarla nunca altera el recorrido.

const Furniture := OficinasMapData.Furniture
const RoomTheme := OficinasMapData.RoomTheme
const Cell := OficinasLayout.Cell
const Wall := OficinasLayout.Wall
const Depth := OficinasLayout.Depth
const T := OficinasMapData.Furniture.Type

const DECOR_SALT := 0x0f1c1a5
## Fracción del ancho del módulo que ocupa una escalera de fondo.
const STAIR_RUN := 0.62
## Espacio libre de muebles alrededor de cada punto de interacción.
const KEEP_CLEAR := 95.0

const BUILDING_THEMES := {
	RoomTheme.OFFICE: 1.0, RoomTheme.OPEN_PLAN: 0.9, RoomTheme.ARCHIVE: 0.5, RoomTheme.MEETING: 0.4,
	RoomTheme.COPY_ROOM: 0.3, RoomTheme.BREAK_ROOM: 0.35, RoomTheme.RECEPTION: 0.25, RoomTheme.LOBBY: 0.2,
	RoomTheme.HALLWAY: 0.7, RoomTheme.CONSTRUCTION: 0.25,
}
const ROOM_THEMES := {
	RoomTheme.EXECUTIVE: 1.0, RoomTheme.SERVER: 0.8, RoomTheme.BATHROOM: 0.8, RoomTheme.STORAGE: 0.7,
	RoomTheme.JANITOR: 0.5, RoomTheme.RECORDS: 0.8, RoomTheme.SECURITY: 0.6, RoomTheme.KITCHEN: 0.6,
	RoomTheme.OFFICE: 0.5, RoomTheme.MEETING: 0.4,
}
const CORRIDOR_THEMES := {
	RoomTheme.SERVICE_HALL: 1.0, RoomTheme.MAINTENANCE: 0.8, RoomTheme.FIRE_ESCAPE: 0.8,
	RoomTheme.BACK_HALL: 0.8, RoomTheme.COLLAPSED_HALL: 0.6,
}
## Muebles de suelo por tema (se eligen al azar evitando repetir el anterior).
const FLOOR_ITEMS := {
	RoomTheme.OFFICE: [T.DESK, T.DESK, T.CHAIR, T.FILING_CABINET, T.PLANT, T.PAPER_STACK, T.TRASH_BIN, T.COAT_RACK],
	RoomTheme.OPEN_PLAN: [T.CUBICLE, T.CUBICLE, T.CHAIR, T.PLANT, T.COPIER, T.TRASH_BIN],
	RoomTheme.ARCHIVE: [T.SHELF, T.SHELF, T.FILING_CABINET, T.BOXES, T.PAPER_STACK, T.LADDER],
	RoomTheme.MEETING: [T.MEETING_TABLE, T.CHAIR, T.PLANT, T.CHAIR],
	RoomTheme.COPY_ROOM: [T.COPIER, T.BOXES, T.PAPER_STACK, T.SHELF, T.TRASH_BIN],
	RoomTheme.BREAK_ROOM: [T.VENDING, T.WATER_COOLER, T.FRIDGE, T.MEETING_TABLE, T.CHAIR, T.COUNTER],
	RoomTheme.RECEPTION: [T.COUNTER, T.SOFA, T.PLANT, T.BENCH, T.WATER_COOLER],
	RoomTheme.LOBBY: [T.COLUMN, T.BENCH, T.PLANT, T.SOFA, T.TRASH_BIN],
	RoomTheme.HALLWAY: [T.WATER_COOLER, T.PLANT, T.EXTINGUISHER, T.TRASH_BIN, T.BENCH, T.FALLEN_CABINET],
	RoomTheme.CONSTRUCTION: [T.SCAFFOLD, T.CONE, T.CONE, T.BOXES, T.LADDER, T.PIPES],
	RoomTheme.EXECUTIVE: [T.EXEC_DESK, T.CHAIR, T.SOFA, T.PLANT, T.SAFE, T.COAT_RACK, T.SHELF],
	RoomTheme.SERVER: [T.SERVER_RACK, T.SERVER_RACK, T.SERVER_RACK, T.CRT_STACK, T.FAN, T.BOXES],
	RoomTheme.BATHROOM: [T.TOILET_STALL, T.TOILET_STALL, T.TOILET_STALL, T.SINK, T.SINK, T.TRASH_BIN, T.MOP_BUCKET],
	RoomTheme.STORAGE: [T.BOXES, T.BOXES, T.SHELF, T.LADDER, T.FALLEN_CABINET, T.CONE],
	RoomTheme.JANITOR: [T.MOP_BUCKET, T.SHELF, T.PIPES, T.LADDER, T.TRASH_BIN, T.BOXES],
	RoomTheme.RECORDS: [T.FILING_CABINET, T.FILING_CABINET, T.FILING_CABINET, T.SHELF, T.PAPER_STACK, T.BOXES],
	RoomTheme.SECURITY: [T.DESK, T.CHAIR, T.LOCKER, T.LOCKER, T.CRT_STACK],
	RoomTheme.KITCHEN: [T.COUNTER, T.FRIDGE, T.MICROWAVE, T.SINK, T.MEETING_TABLE, T.CHAIR],
	RoomTheme.SERVICE_HALL: [T.PIPES, T.BOXES, T.TRASH_BIN, T.EXTINGUISHER, T.LOCKER],
	RoomTheme.MAINTENANCE: [T.PIPES, T.PIPES, T.LADDER, T.MOP_BUCKET, T.FAN],
	RoomTheme.FIRE_ESCAPE: [T.EXTINGUISHER, T.BENCH, T.CONE],
	RoomTheme.BACK_HALL: [T.FILING_CABINET, T.COAT_RACK, T.PLANT, T.BENCH],
	RoomTheme.COLLAPSED_HALL: [T.CONE, T.BOXES, T.FALLEN_CABINET, T.SCAFFOLD],
}
const WALL_ITEMS := {
	RoomTheme.OFFICE: [T.NOTICE_BOARD, T.CLOCK, T.PAINTING, T.BLINDS],
	RoomTheme.OPEN_PLAN: [T.CLOCK, T.NOTICE_BOARD],
	RoomTheme.ARCHIVE: [T.CLOCK],
	RoomTheme.MEETING: [T.WHITEBOARD, T.TV, T.PAINTING],
	RoomTheme.COPY_ROOM: [T.NOTICE_BOARD],
	RoomTheme.BREAK_ROOM: [T.CLOCK, T.NOTICE_BOARD, T.TV],
	RoomTheme.RECEPTION: [T.PAINTING, T.CLOCK, T.TV],
	RoomTheme.LOBBY: [T.PAINTING, T.CLOCK],
	RoomTheme.HALLWAY: [T.PAINTING, T.NOTICE_BOARD, T.CLOCK],
	RoomTheme.CONSTRUCTION: [T.NOTICE_BOARD],
	RoomTheme.EXECUTIVE: [T.PAINTING, T.PAINTING, T.CLOCK, T.BLINDS],
	RoomTheme.SERVER: [T.MONITOR_WALL],
	RoomTheme.BATHROOM: [T.MIRROR, T.MIRROR],
	RoomTheme.STORAGE: [T.NOTICE_BOARD],
	RoomTheme.JANITOR: [T.NOTICE_BOARD],
	RoomTheme.RECORDS: [T.CLOCK],
	RoomTheme.SECURITY: [T.MONITOR_WALL, T.NOTICE_BOARD],
	RoomTheme.KITCHEN: [T.CLOCK],
	RoomTheme.SERVICE_HALL: [T.NOTICE_BOARD],
	RoomTheme.MAINTENANCE: [T.NOTICE_BOARD],
	RoomTheme.FIRE_ESCAPE: [T.EXIT_SIGN],
	RoomTheme.BACK_HALL: [T.PAINTING, T.CLOCK],
	RoomTheme.COLLAPSED_HALL: [T.NOTICE_BOARD],
}
## Tamaños (ancho, alto); alto 0 = del suelo al techo.
const SIZES := {
	T.DESK: Vector2(150.0, 78.0), T.CHAIR: Vector2(46.0, 90.0), T.FILING_CABINET: Vector2(60.0, 130.0),
	T.SHELF: Vector2(110.0, 210.0), T.WATER_COOLER: Vector2(44.0, 120.0), T.PLANT: Vector2(50.0, 100.0),
	T.COPIER: Vector2(110.0, 100.0), T.VENDING: Vector2(90.0, 190.0), T.MEETING_TABLE: Vector2(240.0, 70.0),
	T.BOXES: Vector2(90.0, 80.0), T.PAPER_STACK: Vector2(50.0, 40.0), T.FALLEN_CABINET: Vector2(130.0, 60.0),
	T.WHITEBOARD: Vector2(200.0, 110.0), T.NOTICE_BOARD: Vector2(120.0, 90.0), T.CLOCK: Vector2(44.0, 44.0),
	T.EXIT_SIGN: Vector2(84.0, 30.0), T.CUBICLE: Vector2(170.0, 120.0), T.SOFA: Vector2(170.0, 70.0),
	T.COUNTER: Vector2(200.0, 95.0), T.COLUMN: Vector2(54.0, 0.0), T.BENCH: Vector2(130.0, 46.0),
	T.CONE: Vector2(34.0, 50.0), T.SCAFFOLD: Vector2(140.0, 230.0), T.EXTINGUISHER: Vector2(26.0, 56.0),
	T.PAINTING: Vector2(110.0, 80.0), T.TRASH_BIN: Vector2(36.0, 48.0), T.COAT_RACK: Vector2(40.0, 150.0),
	T.TV: Vector2(130.0, 76.0), T.SERVER_RACK: Vector2(70.0, 210.0), T.TOILET_STALL: Vector2(100.0, 190.0),
	T.SINK: Vector2(70.0, 90.0), T.MIRROR: Vector2(70.0, 90.0), T.SAFE: Vector2(70.0, 80.0),
	T.EXEC_DESK: Vector2(210.0, 84.0), T.LOCKER: Vector2(60.0, 180.0), T.MOP_BUCKET: Vector2(60.0, 110.0),
	T.PIPES: Vector2(160.0, 0.0), T.FRIDGE: Vector2(70.0, 170.0), T.MICROWAVE: Vector2(60.0, 40.0),
	T.MONITOR_WALL: Vector2(200.0, 110.0), T.CRT_STACK: Vector2(90.0, 120.0), T.BLINDS: Vector2(150.0, 110.0),
	T.FAN: Vector2(50.0, 110.0), T.LADDER: Vector2(50.0, 180.0),
}
const WALL_TYPES := [T.WHITEBOARD, T.NOTICE_BOARD, T.CLOCK, T.EXIT_SIGN, T.PAINTING, T.TV, T.MIRROR,
		T.MONITOR_WALL, T.BLINDS]
const MARK_WEIGHTS := {
	MapMark.Type.PAPERS: 0.3, MapMark.Type.CRACK: 0.16, MapMark.Type.STAIN: 0.16, MapMark.Type.BLOOD: 0.1,
	MapMark.Type.POSTER: 0.1, MapMark.Type.GRAFFITI: 0.06, MapMark.Type.RUBBLE: 0.08, MapMark.Type.BONES: 0.04,
}


static func is_wall_item(type: Furniture.Type) -> bool:
	return type in WALL_TYPES


static func generate(params: OficinasParams) -> OficinasMapData:
	var data := OficinasMapData.new()
	var layout := OficinasLayout.build(params)
	data.layout = layout
	data.floor_height = params.floor_height
	data.module_width = maxf(params.module_width, 520.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ DECOR_SALT
	_build_structure(data)
	_build_stairs(data)
	_build_elevators(data)
	_build_rooms(data, params, rng)
	_build_depth_doors_and_areas(data, params, rng)
	_build_keys(data, rng)
	_build_back_walls(data, params, rng)
	_build_furniture(data, params, rng)
	_build_marks(data, params, rng)

	var w := data.module_width
	data.spawn = Vector2(w * 0.3, data.surface_y(layout.start.x) - 2.0)
	var exit_x := layout.end.y * w
	data.goal = Rect2(exit_x + w * 0.6, data.surface_y(layout.end.x) - 220.0, w * 0.4 - OficinasMapData.WALL, 220.0)
	data.bounds = Rect2(-OficinasMapData.WALL, data.surface_y(layout.floors) - OficinasMapData.SLAB,
			layout.modules * w + OficinasMapData.WALL * 2.0, layout.floors * data.floor_height + 400.0)

	var field := FastNoiseLite.new()
	field.seed = params.seed
	field.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	field.frequency = 0.0007
	data.far = AzoteaGenerator.build_skyline(rng, field, 4096.0, params.skyline_ruin, 0.4,
			690.0, Vector2(160.0, 470.0), Vector2(90.0, 240.0), 0.0)
	data.near = AzoteaGenerator.build_skyline(rng, field, 4096.0, params.skyline_ruin, 0.4,
			760.0, Vector2(90.0, 330.0), Vector2(140.0, 320.0), 5000.0)
	return data


# --- Estructura --------------------------------------------------------------------

static func _build_structure(data: OficinasMapData) -> void:
	var layout := data.layout
	var w := data.module_width
	var slab := OficinasMapData.SLAB
	for f in layout.floors:
		var y := data.surface_y(f)
		var thickness := OficinasMapData.FOUNDATION if f == 0 else slab
		for c in layout.modules:
			var x := c * w
			match layout.cell(f, c):
				Cell.NORMAL, Cell.SHAFT, Cell.SEALED:
					data.slabs.append(Rect2(x, y, w, thickness))
				Cell.GAP:
					var side := (w - OficinasMapData.GAP_WIDTH) * 0.5
					data.slabs.append(Rect2(x, y, side, thickness))
					data.slabs.append(Rect2(x + w - side, y, side, thickness))
					data.broken_edges.append(Vector2(x + side, y))
					data.broken_edges.append(Vector2(x + w - side, y))
				Cell.COLLAPSE:
					data.broken_edges.append(Vector2(x, y))
					data.broken_edges.append(Vector2(x + w, y))
			if layout.cell(f, c) == Cell.SEALED:
				data.sealed.append(data.module_rect(f, c))
	var top := data.surface_y(layout.floors)
	data.slabs.append(Rect2(-OficinasMapData.WALL, top - slab * 2.0, layout.modules * w + OficinasMapData.WALL * 2.0,
			slab * 3.0))
	var height := -top + OficinasMapData.FOUNDATION
	data.walls.append(Rect2(-OficinasMapData.WALL, top, OficinasMapData.WALL, height))
	data.walls.append(Rect2(layout.modules * w, top, OficinasMapData.WALL, height))
	for f in layout.floors:
		for c in layout.modules - 1:
			var x := (c + 1) * w - OficinasMapData.WALL * 0.5
			var ceiling := data.ceiling_y(f)
			var floor_y := data.surface_y(f)
			match layout.wall(f, c):
				Wall.DOOR, Wall.LOCKED:
					data.walls.append(Rect2(x, ceiling, OficinasMapData.WALL,
							floor_y - OficinasMapData.DOOR_HEIGHT - ceiling))
					var door := OficinasMapData.WallDoor.new()
					door.floor = f
					door.boundary = c
					door.rect = Rect2(x, floor_y - OficinasMapData.DOOR_HEIGHT, OficinasMapData.WALL,
							OficinasMapData.DOOR_HEIGHT)
					door.key = layout.lock_key(f, c) if layout.wall(f, c) == Wall.LOCKED else -1
					data.wall_doors.append(door)
				Wall.BLOCKED:
					data.walls.append(Rect2(x, ceiling, OficinasMapData.WALL, floor_y - ceiling))
	data.solids.append_array(data.slabs)
	data.solids.append_array(data.walls)
	data.solids.append_array(data.sealed)


static func _build_stairs(data: OficinasMapData) -> void:
	var layout := data.layout
	var run := data.module_width * STAIR_RUN
	for f in layout.floors - 1:
		for c in layout.modules:
			var d := layout.stairs_from(f, c)
			if d == 0:
				continue
			var center := data.module_center(c)
			data.stairs.append(OficinasMapData.Stair.new(f, c, d,
					Vector2(center - d * run * 0.5, data.surface_y(f)),
					Vector2(center + d * run * 0.5, data.surface_y(f + 1))))


static func _build_elevators(data: OficinasMapData) -> void:
	for i in data.layout.elevators.size():
		var shaft := data.layout.elevators[i]
		var spec := OficinasMapData.ElevatorSpec.new()
		spec.id = i
		spec.column = shaft.column
		spec.kind = shaft.kind
		spec.low = shaft.low
		spec.high = shaft.high
		spec.stops = shaft.stops()
		spec.x = data.module_center(shaft.column)
		spec.shaft = Rect2(spec.x - 85.0, data.ceiling_y(shaft.high), 170.0,
				data.surface_y(shaft.low) - data.ceiling_y(shaft.high))
		data.elevators.append(spec)


# --- Ambientación ------------------------------------------------------------------

## Módulos unidos por muros abiertos forman una habitación. El tema evita repetir el de la
## habitación vecina y, con realismo, tiende a repetir el del piso de abajo (plantas coherentes).
static func _build_rooms(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	for f in layout.floors:
		var first := 0
		var previous := -1
		for c in layout.modules:
			if c < layout.modules - 1 and layout.wall(f, c) == Wall.OPEN:
				continue
			var room := OficinasMapData.Room.new()
			room.floor = f
			room.first = first
			room.last = c
			var below := data.room_at(f - 1, first) if f > 0 else null
			var theme: int = -1
			if below != null and below.theme != previous and rng.randf() < params.realism * 0.5:
				theme = below.theme
			elif c - first >= 2 and rng.randf() < 0.5:
				theme = RoomTheme.HALLWAY if previous != RoomTheme.HALLWAY else RoomTheme.LOBBY
			else:
				theme = _pick_theme(rng, BUILDING_THEMES, previous)
			room.theme = theme
			room.rect = Rect2(first * data.module_width, data.ceiling_y(f), (c - first + 1) * data.module_width,
					data.surface_y(f) - data.ceiling_y(f))
			data.rooms.append(room)
			previous = theme
			first = c + 1


static func _pick_theme(rng: RandomNumberGenerator, weights: Dictionary, avoid: int) -> int:
	var options := weights.duplicate()
	if options.size() > 1 and options.has(avoid):
		options.erase(avoid)
	return _weighted(rng, options)


## Puertas al fondo y sus áreas: cada habitación tiene un área propia; cada par de puertas de
## pasillo comparte un área con una puerta en cada extremo.
static func _build_depth_doors_and_areas(data: OficinasMapData, params: OficinasParams,
		rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var area_y := OficinasMapData.FOUNDATION + 1500.0
	var previous_theme := -1
	for i in layout.depth_doors.size():
		var door := layout.depth_doors[i]
		var spec := OficinasMapData.DepthDoorSpec.new()
		spec.id = i
		spec.floor = door.floor
		spec.module = door.module
		spec.kind = door.kind
		spec.area = -1
		var center := data.module_center(door.module)
		spec.rect = Rect2(center - OficinasMapData.DOOR_WIDTH * 0.5, data.surface_y(door.floor) - OficinasMapData.DOOR_HEIGHT,
				OficinasMapData.DOOR_WIDTH, OficinasMapData.DOOR_HEIGHT)
		data.depth_doors.append(spec)
	for i in layout.depth_doors.size():
		var door := layout.depth_doors[i]
		var spec := data.depth_doors[i]
		if door.kind == Depth.NONE or spec.area >= 0:
			continue
		var area := OficinasMapData.Area.new()
		area.kind = door.kind
		var height := data.floor_height - OficinasMapData.SLAB
		var width: float
		if door.kind == Depth.ROOM:
			area.theme = _pick_theme(rng, ROOM_THEMES, previous_theme)
			width = data.module_width * rng.randf_range(1.3, 2.1)
		else:
			area.theme = _pick_theme(rng, CORRIDOR_THEMES, previous_theme)
			width = data.module_width * rng.randf_range(2.6, 4.6)
			if area.theme == RoomTheme.MAINTENANCE:
				height *= 0.75
		previous_theme = area.theme
		area.rect = Rect2(0.0, area_y, width, height)
		area.bounds = area.rect.grow(OficinasMapData.WALL + OficinasMapData.SLAB)
		area.doors.append(OficinasMapData.AreaDoor.new(140.0, i))
		spec.area = data.areas.size()
		if door.kind == Depth.CORRIDOR and door.partner >= 0:
			area.doors.append(OficinasMapData.AreaDoor.new(width - 140.0, door.partner))
			data.depth_doors[door.partner].area = data.areas.size()
		_build_area_shell(area)
		_furnish_area(area, params, rng)
		data.areas.append(area)
		area_y += height + OficinasMapData.AREA_GAP


static func _build_area_shell(area: OficinasMapData.Area) -> void:
	var r := area.rect
	var slab := OficinasMapData.SLAB
	var wall := OficinasMapData.WALL
	area.solids.append(Rect2(r.position.x - wall, r.end.y, r.size.x + wall * 2.0, slab * 2.0))
	area.solids.append(Rect2(r.position.x - wall, r.position.y - slab, r.size.x + wall * 2.0, slab))
	area.solids.append(Rect2(r.position.x - wall, r.position.y - slab, wall, r.size.y + slab * 3.0))
	area.solids.append(Rect2(r.end.x, r.position.y - slab, wall, r.size.y + slab * 3.0))


## Interior detallado: muebles de suelo y de pared según el tema, lámparas y muchas marcas.
static func _furnish_area(area: OficinasMapData.Area, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var r := area.rect
	var floor_y := r.end.y
	var clear: Array[float] = []
	for door in area.doors:
		clear.append(door.x)
	clear.append(r.end.x - 120.0)
	area.furniture = _fill_floor(rng, area.theme, r.position.x + 30.0, r.end.x - 30.0, floor_y,
			clampf(params.furniture_density + 0.2, 0.0, 1.0), clear, r.size.y)
	var wall_count := rng.randi_range(2, 3)
	for k in wall_count:
		var options: Array = WALL_ITEMS[area.theme]
		var type: Furniture.Type = options[rng.randi() % options.size()]
		var size: Vector2 = SIZES[type]
		var x := r.position.x + r.size.x * (k + 0.5) / wall_count - size.x * 0.5
		area.furniture.append(Furniture.new(type, Rect2(x, floor_y - 240.0 - size.y * 0.5, size.x, size.y), rng.randi()))
	var lamp_count := maxi(1, int(r.size.x / 420.0))
	for k in lamp_count:
		area.lamps.append(OficinasMapData.Lamp.new(Vector2(r.position.x + r.size.x * (k + 0.5) / lamp_count, r.position.y),
				rng.randf() < params.working_lamps + 0.2, rng.randi()))
	var mark_count := rng.randi_range(params.marks_per_module, params.marks_per_module * 2 + 2)
	if area.theme == RoomTheme.COLLAPSED_HALL:
		mark_count += 6
	for k in mark_count:
		var type: MapMark.Type = _weighted(rng, MARK_WEIGHTS)
		if area.theme == RoomTheme.COLLAPSED_HALL and rng.randf() < 0.5:
			type = MapMark.Type.RUBBLE
		var x := rng.randf_range(r.position.x + 30.0, r.end.x - 30.0)
		var y := floor_y if MapMark.on_floor(type) else rng.randf_range(r.position.y + 40.0, floor_y - 60.0)
		area.marks.append(MapMark.new(type, Vector2(x, y), rng.randf_range(0.6, 1.2), rng.randf(), rng.randi()))


## Llena un tramo de suelo con muebles del tema, dejando libres los puntos de interacción y
## sin repetir el mismo mueble dos veces seguidas.
static func _fill_floor(rng: RandomNumberGenerator, theme: int, left: float, right: float, floor_y: float,
		density: float, clear: Array[float], ceiling_height: float) -> Array[Furniture]:
	var out: Array[Furniture] = []
	var options: Array = FLOOR_ITEMS[theme]
	var previous := -1
	var x := left
	while x < right:
		if rng.randf() >= density:
			x += rng.randf_range(40.0, 110.0)
			continue
		var type: Furniture.Type = options[rng.randi() % options.size()]
		if type == previous and options.size() > 1:
			type = options[(options.find(type) + 1 + rng.randi() % (options.size() - 1)) % options.size()]
		var size: Vector2 = SIZES[type]
		if size.y <= 0.0:
			size.y = ceiling_height
		if x + size.x > right:
			break
		var blocked := false
		for point in clear:
			if x < point + KEEP_CLEAR and x + size.x > point - KEEP_CLEAR:
				x = point + KEEP_CLEAR
				blocked = true
				break
		if blocked:
			continue
		out.append(Furniture.new(type, Rect2(x, floor_y - size.y, size.x, size.y), rng.randi()))
		previous = type
		x += size.x + rng.randf_range(16.0, 60.0)
	return out


static func _build_keys(data: OficinasMapData, rng: RandomNumberGenerator) -> void:
	for key in data.layout.keys:
		var spec := OficinasMapData.KeySpec.new()
		spec.id = key.id
		if key.door >= 0:
			var area_index := data.depth_doors[key.door].area
			var area := data.areas[area_index]
			spec.area = area_index
			spec.position = Vector2(area.rect.end.x - 120.0, area.rect.end.y - 40.0)
		else:
			spec.area = -1
			spec.position = Vector2(data.module_center(key.node.y) + rng.randf_range(-150.0, 150.0),
					data.surface_y(key.node.x) - 40.0)
		data.keys.append(spec)


## Puntos de interacción de un módulo (pie/llegada de escaleras, ascensor, puerta al fondo).
static func _interaction_points(data: OficinasMapData, f: int, c: int) -> Array[float]:
	var points: Array[float] = []
	for stair in data.stairs:
		if stair.column == c and stair.floor == f:
			points.append(stair.foot.x)
		if stair.column == c and stair.floor + 1 == f:
			points.append(stair.top.x)
	if data.layout.cell(f, c) == Cell.SHAFT:
		points.append(data.module_center(c))
	if data.layout.depth_door_at(f, c) != null and data.layout.depth_door_at(f, c).kind != Depth.NONE:
		points.append(data.module_center(c))
	return points


static func _build_back_walls(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		for c in layout.modules:
			var rect := data.module_rect(f, c)
			if layout.cell(f, c) == Cell.SEALED:
				continue
			var busy := layout.cell(f, c) == Cell.SHAFT or layout.has_stairs(f, c) \
					or (layout.depth_door_at(f, c) != null and layout.depth_door_at(f, c).kind != Depth.NONE)
			if not busy and rng.randf() < params.window_chance:
				var count := 1 if rng.randf() < 0.6 else 2
				var win_w := minf(rng.randf_range(150.0, 230.0), (w - 80.0) / count - 30.0)
				var win_h := minf(150.0, rect.size.y - 140.0)
				for k in count:
					var cx := rect.position.x + w * (k + 1) / (count + 1)
					data.windows.append(Rect2(cx - win_w * 0.5, rect.position.y + 50.0, win_w, win_h))
			var heavy := layout.cell(f, c) == Cell.COLLAPSE
			if not busy and (heavy or rng.randf() < params.wall_damage):
				data.wall_holes.append(_hole(rect, rng, 0.55 if heavy else 0.3))
			data.lamps.append(OficinasMapData.Lamp.new(Vector2(rect.get_center().x, rect.position.y),
					rng.randf() < params.working_lamps, rng.randi()))


static func _hole(rect: Rect2, rng: RandomNumberGenerator, size: float) -> PackedVector2Array:
	var width := rect.size.x * rng.randf_range(size * 0.6, size)
	var left := rect.position.x + rng.randf_range(0.0, rect.size.x - width)
	var depth := rect.size.y * rng.randf_range(size * 0.5, size)
	var points := PackedVector2Array([Vector2(left, rect.position.y - 1.0)])
	var steps := 7
	for i in range(1, steps):
		var t := float(i) / steps
		var bulge := sin(t * PI) * depth * rng.randf_range(0.6, 1.0)
		points.append(Vector2(left + width * t + rng.randf_range(-12.0, 12.0), rect.position.y + bulge))
	points.append(Vector2(left + width, rect.position.y - 1.0))
	return points


static func _build_furniture(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		var floor_y := data.surface_y(f)
		for c in layout.modules:
			var kind := layout.cell(f, c)
			if kind == Cell.COLLAPSE or kind == Cell.SEALED:
				continue
			var room := data.room_at(f, c)
			var theme: int = room.theme if room != null else RoomTheme.HALLWAY
			var clear := _interaction_points(data, f, c)
			if kind == Cell.GAP:
				clear.append(data.module_center(c))
			var height := data.surface_y(f) - data.ceiling_y(f)
			data.furniture.append_array(_fill_floor(rng, theme, c * w + 36.0, (c + 1) * w - 36.0, floor_y,
					params.furniture_density, clear, height))
			if clear.is_empty() and rng.randf() < params.furniture_density * 0.7:
				var options: Array = WALL_ITEMS[theme]
				var type: Furniture.Type = options[rng.randi() % options.size()]
				var size: Vector2 = SIZES[type]
				var rect := Rect2(c * w + rng.randf_range(40.0, w - 40.0 - size.x), floor_y - 260.0 - size.y * 0.5,
						size.x, size.y)
				if not _overlaps_window(data, rect):
					data.furniture.append(Furniture.new(type, rect, rng.randi()))
	for door in data.wall_doors:
		if door.key < 0 and rng.randf() < 0.35:
			var size: Vector2 = SIZES[T.EXIT_SIGN]
			data.furniture.append(Furniture.new(T.EXIT_SIGN,
					Rect2(door.rect.get_center().x - size.x * 0.5, door.rect.position.y - size.y - 12.0, size.x, size.y),
					rng.randi()))
	var sign_size: Vector2 = SIZES[T.EXIT_SIGN]
	data.furniture.append(Furniture.new(T.EXIT_SIGN,
			Rect2((layout.end.y + 1) * w - sign_size.x - 40.0,
			data.surface_y(layout.end.x) - OficinasMapData.DOOR_HEIGHT - sign_size.y - 20.0, sign_size.x, sign_size.y), -1))


static func _overlaps_window(data: OficinasMapData, rect: Rect2) -> bool:
	for window in data.windows:
		if window.grow(16.0).intersects(rect):
			return true
	return false


static func _build_marks(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	for f in layout.floors:
		for c in layout.modules:
			if not layout.is_node(f, c):
				continue
			var rect := data.module_rect(f, c)
			for i in rng.randi_range(params.marks_per_module / 2, params.marks_per_module):
				var type: MapMark.Type = _weighted(rng, MARK_WEIGHTS)
				var x := rng.randf_range(rect.position.x + 30.0, rect.end.x - 30.0)
				var y := rect.end.y if MapMark.on_floor(type) else rng.randf_range(rect.position.y + 40.0, rect.end.y - 60.0)
				data.marks.append(MapMark.new(type, Vector2(x, y), rng.randf_range(0.6, 1.2), rng.randf(), rng.randi()))


static func _weighted(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total := 0.0
	for key in weights:
		total += weights[key]
	var roll := rng.randf() * total
	for key in weights:
		roll -= weights[key]
		if roll <= 0.0:
			return key
	return weights.keys().back()
