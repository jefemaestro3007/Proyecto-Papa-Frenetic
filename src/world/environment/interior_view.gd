@tool
class_name InteriorView
extends StyledCanvas
## Dibuja el edificio de oficinas según un ArtStyle: pared del fondo (con ventanas y boquetes
## por donde se ve la ciudad), marcas y objetos de pared, huecos de ascensor, escaleras,
## mobiliario, losas, muros, puertas, bordes rotos, módulos sellados y la salida.
## Es estático: solo se redibuja al cambiar los datos o el estilo.

const Furniture := OficinasMapData.Furniture
const EXIT_GREEN := Color("3ddc84")
const STEP_HEIGHT := 24.0
const RAIL_HEIGHT := 90.0

var _data: OficinasMapData
var _seed := 0


func setup(data: OficinasMapData, seed_value: int, style: ArtStyle) -> void:
	_data = data
	_seed = seed_value
	_style = style
	queue_redraw()


func _draw() -> void:
	if _data == null or _style == null:
		return
	var layout := _data.layout
	for f in layout.floors:
		for c in layout.modules:
			if not layout.is_sealed(f, c):
				_draw_back_wall(f, c)
	for mark in _data.marks:
		if not MapMark.on_floor(mark.type):
			_draw_wall_mark(mark)
	for spec in _data.elevators:
		_draw_shaft(spec)
	for item in _data.furniture:
		if _is_wall_item(item.type):
			_draw_furniture(item)
	for lamp in _data.lamps:
		_draw_lamp(lamp)
	_draw_exit()
	for stair in _data.stairs:
		_draw_stair(stair)
	for item in _data.furniture:
		if not _is_wall_item(item.type):
			_draw_furniture(item)
	for slab in _data.slabs:
		_draw_slab(slab)
	for wall_rect in _data.walls:
		_box(wall_rect, _style.structure, int(wall_rect.position.x * 7.0 + wall_rect.position.y))
	for opening in _data.door_openings:
		_draw_door_frame(opening)
	for edge in _data.broken_edges:
		_draw_broken_edge(edge)
	for rect in _data.sealed:
		_draw_sealed(rect)
	for mark in _data.marks:
		if MapMark.on_floor(mark.type):
			_draw_floor_mark(mark)


static func _is_wall_item(type: Furniture.Type) -> bool:
	return type in [Furniture.Type.WHITEBOARD, Furniture.Type.NOTICE_BOARD, Furniture.Type.CLOCK,
			Furniture.Type.EXIT_SIGN]


# --- Pared del fondo -----------------------------------------------------------------

## La pared se arma en franjas alrededor de las ventanas y luego se le restan los boquetes,
## así lo que queda vacío deja ver el cielo y el skyline de verdad.
func _draw_back_wall(f: int, c: int) -> void:
	var rect := _data.module_rect(f, c)
	var windows: Array[Rect2] = []
	for window in _data.windows:
		if window.get_center().x > rect.position.x and window.get_center().x < rect.end.x \
				and window.get_center().y > rect.position.y and window.get_center().y < rect.end.y:
			windows.append(window)
	var holes: Array[PackedVector2Array] = []
	for hole in _data.wall_holes:
		if hole[0].x >= rect.position.x - 1.0 and hole[0].x <= rect.end.x and absf(hole[0].y - rect.position.y) < 2.0:
			holes.append(hole)

	var pieces: Array[Rect2] = []
	if windows.is_empty():
		pieces.append(rect)
	else:
		var band_top := windows[0].position.y
		var band_bottom := windows[0].end.y
		pieces.append(Rect2(rect.position, Vector2(rect.size.x, band_top - rect.position.y)))
		pieces.append(Rect2(rect.position.x, band_bottom, rect.size.x, rect.end.y - band_bottom))
		windows.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
		var x := rect.position.x
		for window in windows:
			pieces.append(Rect2(x, band_top, window.position.x - x, band_bottom - band_top))
			x = window.end.x
		pieces.append(Rect2(x, band_top, rect.end.x - x, band_bottom - band_top))

	var wainscot_y := rect.end.y - rect.size.y * 0.32
	for piece in pieces:
		if piece.size.x <= 0.5 or piece.size.y <= 0.5:
			continue
		for poly in _subtract(_rect_points(piece), holes):
			_fill(poly, _style.wall_paper)
		var lower := piece.intersection(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y))
		if lower.size.x > 0.5 and lower.size.y > 0.5:
			for poly in _subtract(_rect_points(lower), holes):
				_fill(poly, _style.wall_paper.darkened(0.18))
	draw_line(Vector2(rect.position.x, wainscot_y), Vector2(rect.end.x, wainscot_y), _style.structure_dark, 3.0)
	draw_rect(Rect2(rect.position.x, rect.end.y - 14.0, rect.size.x, 14.0), _style.structure_dark)
	if _style.bricks > 0.0:
		_draw_bricks(Rect2(rect.position.x, wainscot_y, rect.size.x, rect.end.y - wainscot_y - 14.0))
	for window in windows:
		_draw_window(window, f * 131 + c)
	for hole in holes:
		_draw_hole_edge(hole)


static func _subtract(poly: PackedVector2Array, holes: Array[PackedVector2Array]) -> Array:
	var result := [poly]
	for hole in holes:
		var next := []
		for piece in result:
			for clipped in Geometry2D.clip_polygons(piece, hole):
				if not Geometry2D.is_polygon_clockwise(clipped):
					next.append(clipped)
		result = next
	return result


func _draw_bricks(area: Rect2) -> void:
	var color := Color(_style.structure_dark, _style.bricks * 0.6)
	var row := 0
	var y := area.position.y
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), color, 2.0)
		var x := area.position.x + (23.0 if row % 2 == 1 else 0.0)
		while x < area.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + 22.0, area.end.y)), color, 2.0)
			x += 46.0
		y += 22.0
		row += 1


func _draw_window(window: Rect2, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ variant
	var width := maxf(_style.outline_width, 3.0)
	draw_rect(window, Color(_style.window_lit, 0.06))
	draw_line(Vector2(window.get_center().x, window.position.y), Vector2(window.get_center().x, window.end.y),
			_style.structure_dark, width)
	draw_line(Vector2(window.position.x, window.get_center().y), Vector2(window.end.x, window.get_center().y),
			_style.structure_dark, width)
	# Vidrios rotos que quedan en las esquinas.
	for corner in [window.position, Vector2(window.end.x, window.position.y), window.end, Vector2(window.position.x, window.end.y)]:
		if rng.randf() < 0.5:
			var toward: Vector2 = (window.get_center() - corner).normalized()
			var shard := PackedVector2Array([corner, corner + Vector2(toward.x, 0.0) * rng.randf_range(20.0, 50.0),
					corner + Vector2(0.0, toward.y) * rng.randf_range(20.0, 50.0)])
			_fill(shard, Color(_style.window_dark, 0.7))
	draw_rect(window, _style.outline, false, width)
	draw_rect(Rect2(window.position.x - 8.0, window.end.y, window.size.x + 16.0, 10.0), _style.structure_light)


func _draw_hole_edge(hole: PackedVector2Array) -> void:
	draw_polyline(hole, _style.structure_dark, 10.0)
	draw_polyline(hole, _style.outline, maxf(_style.outline_width, 2.0))
	for i in range(1, hole.size() - 1, 2):
		var p := hole[i]
		draw_line(p, p + Vector2(sin(i * 3.1) * 16.0, -18.0), _style.structure_light, 3.0)


# --- Marcas y objetos de pared -------------------------------------------------------

func _draw_wall_mark(mark: MapMark) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mark.variant
	match mark.type:
		MapMark.Type.CRACK:
			if mark.weight < _style.crack_amount:
				_draw_crack(mark.position, 80.0 * mark.size, rng)
		MapMark.Type.STAIN:
			if mark.weight < _style.stain_amount:
				var radius := Vector2(60.0, 40.0) * mark.size
				_fill(_ellipse(mark.position, radius, 16, 0.25, rng), Color(_style.structure_dark, 0.45))
				_fill(_ellipse(mark.position + Vector2(0.0, radius.y), Vector2(radius.x * 0.18, radius.y * 1.8), 10,
						0.2, rng), Color(_style.structure_dark, 0.35))
		MapMark.Type.BLOOD:
			if mark.weight < _style.blood_amount:
				_draw_splatter(mark.position, 24.0 * mark.size, rng)
		MapMark.Type.POSTER:
			if mark.weight < _style.poster_amount:
				_draw_poster(mark.position, mark.size * 0.8, rng)
		MapMark.Type.GRAFFITI:
			if mark.weight < _style.graffiti_amount:
				_draw_graffiti(mark.position, mark.size * 0.8, rng)


func _draw_floor_mark(mark: MapMark) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mark.variant
	match mark.type:
		MapMark.Type.PAPERS:
			for i in rng.randi_range(3, 7):
				var center := mark.position + Vector2(rng.randf_range(-50.0, 50.0), -3.0 - rng.randf() * 4.0)
				draw_set_transform(center, rng.randf_range(-0.4, 0.4))
				draw_rect(Rect2(-13.0, -3.0, 26.0, 5.0), _style.paper)
				draw_rect(Rect2(-13.0, -3.0, 26.0, 5.0), _style.outline, false, 1.5)
				draw_set_transform(Vector2.ZERO)
		MapMark.Type.RUBBLE:
			if mark.weight < _style.rubble_amount:
				_draw_rubble(mark.position, mark.size * 0.8, rng)
		MapMark.Type.BONES:
			if mark.weight < _style.bones_amount:
				_draw_bones(mark.position, mark.size, rng)


# --- Ascensores y escaleras ----------------------------------------------------------

func _draw_shaft(spec: OficinasMapData.ElevatorSpec) -> void:
	var shaft := Rect2(spec.x - 10.0, spec.shaft_top, spec.width + 20.0, spec.shaft_bottom - spec.shaft_top)
	draw_rect(shaft, _style.structure_dark.darkened(0.3))
	for x in [shaft.position.x + 14.0, shaft.end.x - 14.0]:
		draw_line(Vector2(x, shaft.position.y), Vector2(x, shaft.end.y), _style.structure_light, 6.0)
		draw_line(Vector2(x, shaft.position.y), Vector2(x, shaft.end.y), _style.outline, 2.0)
	# Puertas abiertas del ascensor en cada parada, con su indicador encima.
	for y in spec.stop_ys:
		var door := Rect2(spec.x + spec.width * 0.2, y - 190.0, spec.width * 0.6, 190.0)
		draw_rect(Rect2(door.position.x - 12.0, door.position.y - 12.0, door.size.x + 24.0, door.size.y + 12.0),
				_style.structure_light, false, 8.0)
		draw_rect(Rect2(door.get_center().x - 30.0, door.position.y - 44.0, 60.0, 20.0), _style.outline)
	if spec.kind == OficinasLayout.Lift.FAULTY:
		_draw_crack(Vector2(shaft.get_center().x, shaft.position.y + 40.0), 120.0, _rng_for(spec.column))


func _rng_for(value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ value
	return rng


## Escalera: perfil de escalones macizo bajo la rampa y pasamanos paralelo.
func _draw_stair(stair: OficinasMapData.Stair) -> void:
	var dir := signf(stair.high.x - stair.low.x)
	var rise := stair.low.y - stair.high.y
	var steps := maxi(4, roundi(rise / STEP_HEIGHT))
	var run := absf(stair.high.x - stair.low.x)
	# Zanca: peldaños arriba y una banda paralela debajo; el hueco de abajo queda libre
	# (la rampa es de un solo sentido y se puede pasar por debajo).
	var profile := PackedVector2Array([stair.low])
	for i in steps:
		var x0 := stair.low.x + dir * run * i / steps
		var x1 := stair.low.x + dir * run * (i + 1) / steps
		var y := stair.low.y - rise * (i + 1) / steps
		profile.append(Vector2(x0, y))
		profile.append(Vector2(x1, y))
	profile.append(stair.high + Vector2(0.0, 46.0))
	profile.append(stair.low + Vector2(dir * 70.0, 0.0))
	_shape(profile, _style.structure_light, stair.floor * 37 + stair.column)
	for i in steps:
		var x := stair.low.x + dir * run * i / steps
		var y := stair.low.y - rise * (i + 1) / steps
		draw_line(Vector2(x, y), Vector2(x + dir * run / steps, y), _style.edge, 3.0)
	var rail_from := stair.low + Vector2(0.0, -RAIL_HEIGHT)
	var rail_to := stair.high + Vector2(0.0, -RAIL_HEIGHT)
	draw_line(rail_from, rail_to, _style.outline, 8.0)
	draw_line(rail_from, rail_to, _style.structure_light, 4.0)
	for i in range(0, steps + 1, 3):
		var t := float(i) / steps
		var base := stair.low.lerp(stair.high, t)
		draw_line(base, base + Vector2(0.0, -RAIL_HEIGHT), _style.outline, 3.0)


# --- Estructura ----------------------------------------------------------------------

func _draw_slab(slab: Rect2) -> void:
	_box(slab, _style.floor_color, int(slab.position.x * 3.0 + slab.position.y))
	draw_rect(Rect2(slab.position, Vector2(slab.size.x, 6.0)), _style.edge)


func _draw_door_frame(opening: Rect2) -> void:
	var frame := Rect2(opening.position.x - 10.0, opening.position.y, opening.size.x + 20.0, opening.size.y)
	draw_rect(frame, _style.structure_light, false, 6.0)
	# Hoja de la puerta abierta, en escorzo contra el marco.
	var leaf := PackedVector2Array([frame.position + Vector2(frame.size.x, 0.0),
			frame.position + Vector2(frame.size.x + 34.0, 14.0), frame.end + Vector2(34.0, -2.0), frame.end])
	_shape(leaf, _style.furniture, int(opening.position.x))


func _draw_broken_edge(point: Vector2) -> void:
	var rng := _rng_for(int(point.x * 13.0 + point.y))
	var teeth := PackedVector2Array([point + Vector2(-14.0, 0.0)])
	for i in 4:
		teeth.append(point + Vector2(rng.randf_range(-16.0, 16.0), 8.0 + i * 7.0))
	teeth.append(point + Vector2(14.0, OficinasMapData.SLAB))
	_fill(teeth, _style.structure_dark)
	for i in rng.randi_range(2, 4):
		var start := point + Vector2(0.0, 8.0 + i * 6.0)
		var bend := start + Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(6.0, 30.0))
		draw_polyline(PackedVector2Array([start, bend, bend + Vector2(rng.randf_range(-12.0, 12.0), 14.0)]),
				_style.structure_light, 3.0)


func _draw_sealed(rect: Rect2) -> void:
	_box(rect, _style.structure_dark, int(rect.position.x + rect.position.y))
	var rng := _rng_for(int(rect.position.x * 3.0 + rect.position.y))
	for i in 6:
		var base := Vector2(rect.position.x + rect.size.x * (i + 0.5) / 6.0, rect.end.y)
		_draw_rubble(base, rng.randf_range(1.4, 2.2), rng)
	for i in 3:
		var y := rect.position.y + rect.size.y * (0.2 + i * 0.22)
		var plank := PackedVector2Array([Vector2(rect.position.x, y), Vector2(rect.end.x, y + rng.randf_range(-30.0, 30.0)),
				Vector2(rect.end.x, y + 30.0), Vector2(rect.position.x, y + 26.0)])
		_shape(plank, _style.furniture.darkened(0.2), rng.randi())


func _draw_exit() -> void:
	var goal := _data.goal
	var door := Rect2(goal.position.x + 20.0, goal.end.y - OficinasMapData.DOOR_HEIGHT, goal.size.x - 40.0,
			OficinasMapData.DOOR_HEIGHT)
	draw_rect(door, Color(EXIT_GREEN, 0.18))
	draw_rect(door, _style.structure_light, false, 10.0)
	draw_rect(Rect2(door.position.x, door.end.y - 10.0, door.size.x, 10.0), EXIT_GREEN)
	var start := _data.spawn
	var entrance := Rect2(start.x - 120.0, start.y - OficinasMapData.DOOR_HEIGHT, 90.0, OficinasMapData.DOOR_HEIGHT)
	draw_rect(entrance, _style.structure_dark)
	draw_rect(entrance, _style.structure_light, false, 8.0)


func _draw_lamp(lamp: OficinasMapData.Lamp) -> void:
	var p := lamp.position
	if lamp.working:
		draw_line(p, p + Vector2(0.0, 20.0), _style.outline, 3.0)
		_box(Rect2(p.x - 70.0, p.y + 20.0, 140.0, 14.0), _style.furniture, lamp.variant)
		draw_rect(Rect2(p.x - 60.0, p.y + 32.0, 120.0, 5.0), _style.window_lit)
	else:
		# Lámpara caída colgando de una sola cadena.
		draw_line(p + Vector2(-60.0, 0.0), p + Vector2(-60.0, 50.0), _style.outline, 3.0)
		draw_set_transform(p + Vector2(-60.0, 50.0), 0.9)
		_box(Rect2(0.0, -7.0, 140.0, 14.0), _style.furniture_dark, lamp.variant)
		draw_set_transform(Vector2.ZERO)


# --- Mobiliario ----------------------------------------------------------------------

func _draw_furniture(item: Furniture) -> void:
	var r := item.rect
	var rng := RandomNumberGenerator.new()
	rng.seed = item.variant
	var body := _style.furniture
	var dark := _style.furniture_dark
	match item.type:
		Furniture.Type.DESK:
			_box(Rect2(r.position.x, r.position.y + 10.0, r.size.x, 14.0), body, item.variant)
			_box(Rect2(r.position.x + 8.0, r.position.y + 24.0, 12.0, r.size.y - 24.0), dark, item.variant + 1)
			_box(Rect2(r.end.x - 60.0, r.position.y + 24.0, 52.0, r.size.y - 24.0), dark, item.variant + 2)
			draw_line(Vector2(r.end.x - 52.0, r.position.y + 48.0), Vector2(r.end.x - 16.0, r.position.y + 48.0), body, 3.0)
			if rng.randf() < 0.7:
				var screen := Rect2(r.position.x + 30.0, r.position.y - 46.0, 62.0, 52.0)
				_box(screen, body, item.variant + 3)
				draw_rect(screen.grow(-8.0), _style.window_lit if rng.randf() < 0.15 else _style.window_dark)
			if rng.randf() < 0.6:
				for k in rng.randi_range(2, 5):
					draw_rect(Rect2(r.position.x + 100.0, r.position.y + 6.0 - k * 4.0, 34.0, 4.0), _style.paper)
		Furniture.Type.CHAIR:
			_box(Rect2(r.position.x + 4.0, r.position.y + 50.0, r.size.x - 8.0, 10.0), body, item.variant)
			_box(Rect2(r.position.x + 4.0, r.position.y, 12.0, 56.0), body, item.variant + 1)
			draw_line(Vector2(r.get_center().x, r.position.y + 60.0), Vector2(r.get_center().x, r.end.y - 10.0), dark, 5.0)
			draw_line(Vector2(r.position.x, r.end.y - 6.0), Vector2(r.end.x, r.end.y - 6.0), dark, 5.0)
		Furniture.Type.FILING_CABINET:
			_box(r, body, item.variant)
			var drawers := 4
			var open := rng.randi_range(-1, drawers - 1)
			for k in drawers:
				var drawer := Rect2(r.position.x + 6.0, r.position.y + 6.0 + k * (r.size.y - 12.0) / drawers,
						r.size.x - 12.0, (r.size.y - 12.0) / drawers - 4.0)
				if k == open:
					_box(Rect2(drawer.position.x - 22.0, drawer.position.y, drawer.size.x + 22.0, drawer.size.y), dark,
							item.variant + k)
					for p in 3:
						draw_rect(Rect2(drawer.position.x - 16.0 + p * 10.0, drawer.position.y - 8.0, 8.0, 10.0), _style.paper)
				else:
					draw_rect(drawer, dark, false, 2.0)
					draw_rect(Rect2(drawer.get_center().x - 8.0, drawer.get_center().y - 2.0, 16.0, 4.0), _style.edge)
		Furniture.Type.SHELF:
			_box(r, dark, item.variant)
			var shelves := 4
			var binder_colors := [_style.accent, _style.blood, _style.paper, body]
			for k in shelves:
				var y := r.position.y + (k + 1) * r.size.y / shelves
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), body, 6.0)
				var x := r.position.x + 8.0
				while x < r.end.x - 14.0:
					if rng.randf() < 0.8:
						var h := rng.randf_range(24.0, r.size.y / shelves - 10.0)
						var binder: Color = binder_colors[rng.randi() % binder_colors.size()]
						draw_rect(Rect2(x, y - 3.0 - h, 10.0, h), binder)
						draw_rect(Rect2(x, y - 3.0 - h, 10.0, h), _style.outline, false, 1.5)
					x += 12.0
		Furniture.Type.WATER_COOLER:
			_box(Rect2(r.position.x, r.position.y + 40.0, r.size.x, r.size.y - 40.0), body, item.variant)
			_shape(_ellipse(Vector2(r.get_center().x, r.position.y + 22.0), Vector2(r.size.x * 0.42, 22.0), 12),
					Color(_style.window_lit.lerp(Color("6ec8ff"), 0.6), 0.75), item.variant + 1)
		Furniture.Type.PLANT:
			var pot := Rect2(r.position.x + 8.0, r.end.y - 40.0, r.size.x - 16.0, 40.0)
			for k in rng.randi_range(4, 7):
				var tip := Vector2(r.get_center().x + rng.randf_range(-30.0, 30.0), r.position.y + rng.randf_range(0.0, 40.0))
				var droop := tip + Vector2(signf(tip.x - r.get_center().x) * 14.0, 26.0)
				draw_polyline(PackedVector2Array([Vector2(r.get_center().x, pot.position.y), tip, droop]),
						_style.structure_dark.lerp(Color("6b5a2a"), 0.5), 4.0)
			_box(pot, _style.blood.darkened(0.3), item.variant)
		Furniture.Type.COPIER:
			_box(Rect2(r.position.x, r.position.y + 20.0, r.size.x, r.size.y - 20.0), body, item.variant)
			_box(Rect2(r.position.x + 6.0, r.position.y + 6.0, r.size.x - 30.0, 16.0), dark, item.variant + 1)
			draw_rect(Rect2(r.end.x - 20.0, r.position.y + 30.0, 8.0, 8.0), _style.accent)
			draw_rect(Rect2(r.position.x - 18.0, r.position.y + 52.0, 22.0, 4.0), _style.paper)
		Furniture.Type.VENDING:
			_box(r, _style.blood.darkened(0.15), item.variant)
			var glass := Rect2(r.position.x + 10.0, r.position.y + 14.0, r.size.x * 0.62, r.size.y * 0.7)
			draw_rect(glass, _style.window_dark)
			for row in 4:
				for col in 3:
					if rng.randf() < 0.6:
						draw_rect(Rect2(glass.position.x + 6.0 + col * 16.0, glass.position.y + 8.0 + row * 30.0, 11.0, 16.0),
								[_style.accent, _style.paper, _style.edge][rng.randi() % 3])
			draw_rect(glass, _style.outline, false, 2.0)
			draw_rect(Rect2(r.end.x - 24.0, r.position.y + 50.0, 10.0, 30.0), _style.outline)
		Furniture.Type.MEETING_TABLE:
			_box(Rect2(r.position.x, r.position.y + 10.0, r.size.x, 14.0), body, item.variant)
			for x in [r.position.x + 20.0, r.end.x - 32.0]:
				_box(Rect2(x, r.position.y + 24.0, 12.0, r.size.y - 24.0), dark, item.variant + int(x))
		Furniture.Type.BOXES:
			var size := r.size.y * 0.5
			var x := r.position.x
			while x + size <= r.end.x + 0.5:
				for k in rng.randi_range(1, 2):
					var crate := Rect2(x, r.end.y - size * (k + 1), size, size)
					_box(crate, _style.paper.darkened(0.35), item.variant + k + int(x))
					draw_line(Vector2(crate.position.x, crate.position.y + 8.0), Vector2(crate.end.x, crate.position.y + 8.0),
							_style.structure_dark, 3.0)
				x += size
		Furniture.Type.PAPER_STACK:
			for k in rng.randi_range(4, 9):
				draw_rect(Rect2(r.position.x + rng.randf_range(-4.0, 4.0), r.end.y - (k + 1) * 4.5, r.size.x, 4.0),
						_style.paper.darkened(rng.randf() * 0.15))
		Furniture.Type.FALLEN_CABINET:
			_box(r, body, item.variant)
			for k in 3:
				var x := r.position.x + 8.0 + k * (r.size.x - 16.0) / 3.0
				draw_rect(Rect2(x, r.position.y + 6.0, (r.size.x - 16.0) / 3.0 - 4.0, r.size.y - 12.0), dark, false, 2.0)
		Furniture.Type.WHITEBOARD:
			_box(r, _style.paper, item.variant)
			for k in rng.randi_range(2, 4):
				var a := r.position + Vector2(rng.randf_range(14.0, r.size.x - 40.0), rng.randf_range(14.0, r.size.y - 14.0))
				draw_line(a, a + Vector2(rng.randf_range(20.0, 60.0), rng.randf_range(-10.0, 10.0)),
						_style.blood if k % 2 == 0 else _style.structure_dark, 3.0)
		Furniture.Type.NOTICE_BOARD:
			_box(r, _style.furniture.lerp(Color("8a6a3a"), 0.4), item.variant)
			for k in rng.randi_range(3, 6):
				var memo := Rect2(r.position + Vector2(rng.randf_range(8.0, r.size.x - 34.0), rng.randf_range(8.0, r.size.y - 34.0)),
						Vector2(26.0, 26.0))
				draw_rect(memo, _style.paper)
				draw_circle(memo.position + Vector2(13.0, 3.0), 3.0, _style.blood)
		Furniture.Type.CLOCK:
			var center := r.get_center()
			_shape(_ellipse(center, r.size * 0.5, 16), _style.paper, item.variant)
			draw_line(center, center + Vector2.from_angle(rng.randf() * TAU) * r.size.x * 0.32, _style.outline, 3.0)
			draw_line(center, center + Vector2.from_angle(rng.randf() * TAU) * r.size.x * 0.22, _style.outline, 4.0)
		Furniture.Type.EXIT_SIGN:
			_box(r, _style.outline, item.variant)
			var glyph := r.grow(-6.0)
			draw_rect(Rect2(glyph.position, Vector2(glyph.size.x * 0.35, glyph.size.y)), EXIT_GREEN)
			draw_line(Vector2(glyph.position.x + glyph.size.x * 0.5, glyph.get_center().y),
					Vector2(glyph.end.x, glyph.get_center().y), EXIT_GREEN, 4.0)
	_maybe_cobweb(r.position, 1.0, minf(26.0, r.size.x * 0.4), item.variant + 9)
