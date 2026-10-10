class_name OficinasGenerator
extends RefCounted
## Convierte la topología (OficinasLayout) en geometría jugable y ambientación:
## losas, muros y dinteles, rampas de escalera, ascensores, habitaciones con tema,
## ventanas, daño en la pared del fondo, mobiliario, lámparas y marcas.
## La ambientación usa su propio RNG: cambiarla nunca altera el recorrido.

const Furniture := OficinasMapData.Furniture
const RoomTheme := OficinasMapData.RoomTheme
const Cell := OficinasLayout.Cell
const Wall := OficinasLayout.Wall

const DECOR_SALT := 0x0f1c1a5
## Margen del pie de la escalera respecto del borde del módulo.
const STAIR_FOOT := 60.0
const ELEVATOR_MARGIN := 30.0

const THEME_WEIGHTS := {
	RoomTheme.OFFICE: 1.0, RoomTheme.ARCHIVE: 0.5, RoomTheme.MEETING: 0.35, RoomTheme.COPY_ROOM: 0.3,
	RoomTheme.BREAK_ROOM: 0.25, RoomTheme.CORRIDOR: 0.6,
}
## Muebles de suelo por tema (se eligen al azar con repetición).
const THEME_FLOOR := {
	RoomTheme.OFFICE: [Furniture.Type.DESK, Furniture.Type.DESK, Furniture.Type.FILING_CABINET, Furniture.Type.PLANT,
			Furniture.Type.CHAIR, Furniture.Type.PAPER_STACK],
	RoomTheme.ARCHIVE: [Furniture.Type.SHELF, Furniture.Type.SHELF, Furniture.Type.BOXES, Furniture.Type.FILING_CABINET,
			Furniture.Type.PAPER_STACK, Furniture.Type.FALLEN_CABINET],
	RoomTheme.MEETING: [Furniture.Type.MEETING_TABLE, Furniture.Type.CHAIR, Furniture.Type.PLANT],
	RoomTheme.COPY_ROOM: [Furniture.Type.COPIER, Furniture.Type.BOXES, Furniture.Type.PAPER_STACK, Furniture.Type.SHELF],
	RoomTheme.BREAK_ROOM: [Furniture.Type.VENDING, Furniture.Type.WATER_COOLER, Furniture.Type.MEETING_TABLE,
			Furniture.Type.CHAIR],
	RoomTheme.CORRIDOR: [Furniture.Type.WATER_COOLER, Furniture.Type.PLANT, Furniture.Type.FALLEN_CABINET,
			Furniture.Type.BOXES],
}
const THEME_WALL := {
	RoomTheme.OFFICE: [Furniture.Type.NOTICE_BOARD, Furniture.Type.CLOCK],
	RoomTheme.ARCHIVE: [Furniture.Type.CLOCK],
	RoomTheme.MEETING: [Furniture.Type.WHITEBOARD, Furniture.Type.CLOCK],
	RoomTheme.COPY_ROOM: [Furniture.Type.NOTICE_BOARD],
	RoomTheme.BREAK_ROOM: [Furniture.Type.NOTICE_BOARD, Furniture.Type.CLOCK],
	RoomTheme.CORRIDOR: [Furniture.Type.NOTICE_BOARD, Furniture.Type.CLOCK],
}
## Tamaños (ancho, alto) de cada mueble.
const SIZES := {
	Furniture.Type.DESK: Vector2(150.0, 78.0), Furniture.Type.CHAIR: Vector2(46.0, 90.0),
	Furniture.Type.FILING_CABINET: Vector2(60.0, 130.0), Furniture.Type.SHELF: Vector2(110.0, 210.0),
	Furniture.Type.WATER_COOLER: Vector2(44.0, 120.0), Furniture.Type.PLANT: Vector2(50.0, 100.0),
	Furniture.Type.COPIER: Vector2(110.0, 100.0), Furniture.Type.VENDING: Vector2(90.0, 190.0),
	Furniture.Type.MEETING_TABLE: Vector2(240.0, 70.0), Furniture.Type.BOXES: Vector2(90.0, 80.0),
	Furniture.Type.PAPER_STACK: Vector2(50.0, 40.0), Furniture.Type.FALLEN_CABINET: Vector2(130.0, 60.0),
	Furniture.Type.WHITEBOARD: Vector2(200.0, 110.0), Furniture.Type.NOTICE_BOARD: Vector2(120.0, 90.0),
	Furniture.Type.CLOCK: Vector2(44.0, 44.0), Furniture.Type.EXIT_SIGN: Vector2(84.0, 30.0),
}
const MARK_WEIGHTS := {
	MapMark.Type.PAPERS: 0.3, MapMark.Type.CRACK: 0.16, MapMark.Type.STAIN: 0.16, MapMark.Type.BLOOD: 0.1,
	MapMark.Type.POSTER: 0.1, MapMark.Type.GRAFFITI: 0.06, MapMark.Type.RUBBLE: 0.08, MapMark.Type.BONES: 0.04,
}


static func generate(params: OficinasParams) -> OficinasMapData:
	var data := OficinasMapData.new()
	var layout := OficinasLayout.build(params)
	data.layout = layout
	data.floor_height = params.floor_height
	# La escalera necesita un recorrido mayor que la altura para no superar ~45°.
	data.module_width = maxf(params.module_width, params.floor_height * 1.05 + STAIR_FOOT + 20.0)

	_build_structure(data)
	_build_stairs(data)
	_build_elevators(data, params)

	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ DECOR_SALT
	_build_rooms(data, rng)
	_build_back_walls(data, params, rng)
	_build_furniture(data, params, rng)
	_build_marks(data, params, rng)

	var w := data.module_width
	data.spawn = Vector2(w * 0.4, data.surface_y(layout.start.x) - 2.0)
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
				Cell.NORMAL, Cell.STAIR_LOW, Cell.SEALED:
					data.slabs.append(Rect2(x, y, w, thickness))
				Cell.SHAFT:
					if f == layout.elevator_at(f, c).low:
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
	# Techo del último piso y fachadas laterales.
	var top := data.surface_y(layout.floors)
	data.slabs.append(Rect2(-OficinasMapData.WALL, top - slab * 2.0, layout.modules * w + OficinasMapData.WALL * 2.0,
			slab * 3.0))
	var height := -top + OficinasMapData.FOUNDATION
	data.walls.append(Rect2(-OficinasMapData.WALL, top, OficinasMapData.WALL, height))
	data.walls.append(Rect2(layout.modules * w, top, OficinasMapData.WALL, height))
	# Muros entre módulos: dintel sobre las puertas, muro completo si está bloqueado.
	for f in layout.floors:
		for c in layout.modules - 1:
			var x := (c + 1) * w - OficinasMapData.WALL * 0.5
			var ceiling := data.ceiling_y(f)
			var floor_y := data.surface_y(f)
			match layout.wall(f, c):
				Wall.DOOR:
					data.walls.append(Rect2(x, ceiling, OficinasMapData.WALL,
							floor_y - OficinasMapData.DOOR_HEIGHT - ceiling))
					data.door_openings.append(Rect2(x, floor_y - OficinasMapData.DOOR_HEIGHT,
							OficinasMapData.WALL, OficinasMapData.DOOR_HEIGHT))
				Wall.BLOCKED:
					data.walls.append(Rect2(x, ceiling, OficinasMapData.WALL, floor_y - ceiling))
	data.solids.append_array(data.slabs)
	data.solids.append_array(data.walls)
	data.solids.append_array(data.sealed)


static func _build_stairs(data: OficinasMapData) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		for c in layout.modules:
			if layout.cell(f, c) != Cell.STAIR_LOW:
				continue
			var d := layout.stair_dirs[layout.index(f, c)]
			var low_x := c * w + (STAIR_FOOT if d > 0 else w - STAIR_FOOT)
			var high_x := c * w + (w if d > 0 else 0.0)
			data.stairs.append(OficinasMapData.Stair.new(Vector2(low_x, data.surface_y(f)),
					Vector2(high_x, data.surface_y(f + 1)), f, c))


static func _build_elevators(data: OficinasMapData, params: OficinasParams) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ 0xe1e7
	for elevator in data.layout.elevators:
		var spec := OficinasMapData.ElevatorSpec.new()
		spec.column = elevator.column
		spec.kind = elevator.kind
		spec.x = elevator.column * data.module_width + ELEVATOR_MARGIN
		spec.width = data.module_width - ELEVATOR_MARGIN * 2.0
		for stop in elevator.stops():
			spec.stop_ys.append(data.surface_y(stop))
		spec.shaft_top = data.ceiling_y(elevator.high)
		spec.shaft_bottom = data.surface_y(elevator.low)
		# Desfase en beats enteros: con sincronía, todos arrancan en un beat.
		spec.phase = float(rng.randi_range(0, 15))
		data.elevators.append(spec)


# --- Ambientación ------------------------------------------------------------------

## Agrupa módulos unidos por muros abiertos en una misma habitación con un tema.
static func _build_rooms(data: OficinasMapData, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	for f in layout.floors:
		var first := 0
		for c in layout.modules:
			var closes := c == layout.modules - 1 or layout.wall(f, c) != Wall.OPEN
			if not closes:
				continue
			var room := OficinasMapData.Room.new()
			room.floor = f
			room.first = first
			room.last = c
			# Los tramos largos sin muros tienden a ser pasillos.
			room.theme = RoomTheme.CORRIDOR if c - first >= 2 and rng.randf() < 0.6 else _weighted(rng, THEME_WEIGHTS)
			room.rect = Rect2(first * data.module_width, data.ceiling_y(f), (c - first + 1) * data.module_width,
					data.surface_y(f) - data.ceiling_y(f))
			data.rooms.append(room)
			first = c + 1


static func _theme_at(data: OficinasMapData, f: int, c: int) -> RoomTheme:
	for room in data.rooms:
		if room.floor == f and c >= room.first and c <= room.last:
			return room.theme
	return RoomTheme.CORRIDOR


static func _build_back_walls(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		for c in layout.modules:
			var rect := data.module_rect(f, c)
			var heavy := layout.cell(f, c) == Cell.COLLAPSE
			if layout.cell(f, c) == Cell.SEALED:
				continue
			if rng.randf() < params.window_chance:
				var count := 1 if rng.randf() < 0.6 else 2
				var win_w := minf(rng.randf_range(150.0, 230.0), (w - 80.0) / count - 30.0)
				var win_h := minf(150.0, rect.size.y - 140.0)
				for k in count:
					var cx := rect.position.x + w * (k + 1) / (count + 1)
					data.windows.append(Rect2(cx - win_w * 0.5, rect.position.y + 50.0, win_w, win_h))
			if heavy or rng.randf() < params.wall_damage:
				data.wall_holes.append(_hole(rect, rng, 0.55 if heavy else 0.3))
			var working := rng.randf() < params.working_lamps
			if layout.cell(f, c) != Cell.STAIR_VOID:
				data.lamps.append(OficinasMapData.Lamp.new(Vector2(rect.get_center().x, rect.position.y), working,
						rng.randi()))


## Agujero dentado que nace del borde superior del módulo (así la pared queda como polígono simple).
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


## Muebles en el suelo (sin solaparse ni invadir escaleras, huecos o ascensores) y en la pared.
static func _build_furniture(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		var floor_y := data.surface_y(f)
		for c in layout.modules:
			var kind := layout.cell(f, c)
			var theme := _theme_at(data, f, c)
			var left := c * w + 40.0
			var right := (c + 1) * w - 40.0
			match kind:
				Cell.STAIR_VOID, Cell.COLLAPSE, Cell.SEALED, Cell.SHAFT:
					continue
				Cell.STAIR_LOW:
					# Solo bajo la parte alta de la rampa, donde no estorba al subir.
					var d := layout.stair_dirs[layout.index(f, c)]
					if d > 0:
						left = c * w + w * 0.55
					else:
						right = c * w + w * 0.45
			var x := left
			while x < right:
				if rng.randf() >= params.furniture_density:
					x += rng.randf_range(50.0, 130.0)
					continue
				var options: Array = THEME_FLOOR[theme]
				var type: Furniture.Type = options[rng.randi() % options.size()]
				var size: Vector2 = SIZES[type]
				if x + size.x > right:
					break
				# En módulos con hueco, nada sobre la abertura.
				if kind == Cell.GAP:
					var gap_left := c * w + (w - OficinasMapData.GAP_WIDTH) * 0.5 - 20.0
					var gap_right := gap_left + OficinasMapData.GAP_WIDTH + 40.0
					if x + size.x > gap_left and x < gap_right:
						x = gap_right
						continue
				data.furniture.append(Furniture.new(type, Rect2(x, floor_y - size.y, size.x, size.y), rng.randi()))
				x += size.x + rng.randf_range(20.0, 70.0)
			# Un objeto de pared por módulo, entre ventanas.
			if rng.randf() < params.furniture_density * 0.7:
				var wall_options: Array = THEME_WALL[theme]
				var wall_type: Furniture.Type = wall_options[rng.randi() % wall_options.size()]
				var wall_size: Vector2 = SIZES[wall_type]
				var wx := c * w + rng.randf_range(40.0, w - 40.0 - wall_size.x)
				var wall_rect := Rect2(wx, floor_y - 260.0 - wall_size.y * 0.5, wall_size.x, wall_size.y)
				if not _overlaps_window(data, wall_rect):
					data.furniture.append(Furniture.new(wall_type, wall_rect, rng.randi()))
	# Carteles de salida sobre las puertas y la salida final.
	for opening in data.door_openings:
		if rng.randf() < 0.35:
			var size: Vector2 = SIZES[Furniture.Type.EXIT_SIGN]
			data.furniture.append(Furniture.new(Furniture.Type.EXIT_SIGN,
					Rect2(opening.get_center().x - size.x * 0.5, opening.position.y - size.y - 12.0, size.x, size.y),
					rng.randi()))
	var goal_sign: Vector2 = SIZES[Furniture.Type.EXIT_SIGN]
	var exit_x := (layout.end.y + 1) * w - goal_sign.x - 40.0
	data.furniture.append(Furniture.new(Furniture.Type.EXIT_SIGN,
			Rect2(exit_x, data.surface_y(layout.end.x) - OficinasMapData.DOOR_HEIGHT - goal_sign.y - 20.0,
			goal_sign.x, goal_sign.y), -1))


static func _overlaps_window(data: OficinasMapData, rect: Rect2) -> bool:
	for window in data.windows:
		if window.grow(16.0).intersects(rect):
			return true
	return false


static func _build_marks(data: OficinasMapData, params: OficinasParams, rng: RandomNumberGenerator) -> void:
	var layout := data.layout
	var w := data.module_width
	for f in layout.floors:
		for c in layout.modules:
			if layout.is_void(f, c) or layout.is_sealed(f, c):
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
