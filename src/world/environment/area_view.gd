@tool
class_name AreaView
extends InteriorView
## Dibuja un área al fondo (habitación o pasillo): caja cerrada con pared, mobiliario detallado
## del tema, lámparas, marcas, puertas de salida y detalles propios de cada variante
## (escalera de incendios, tuberías de mantenimiento, derrumbe).

var _area: OficinasMapData.Area


func setup_area(area: OficinasMapData.Area, data: OficinasMapData, seed_value: int, style: ArtStyle) -> void:
	_area = area
	_data = data
	_seed = seed_value
	_style = style
	queue_redraw()


func _draw() -> void:
	if _area == null or _style == null:
		return
	var r := _area.rect
	draw_rect(r, _style.wall_paper)
	var wainscot := r.end.y - r.size.y * 0.32
	draw_rect(Rect2(r.position.x, wainscot, r.size.x, r.end.y - wainscot), _style.wall_paper.darkened(0.18))
	draw_line(Vector2(r.position.x, wainscot), Vector2(r.end.x, wainscot), _style.structure_dark, 3.0)
	if _style.bricks > 0.0:
		_draw_bricks(Rect2(r.position.x, wainscot, r.size.x, r.end.y - wainscot - 14.0))
	_draw_variant_back(r)
	for mark in _area.marks:
		if not MapMark.on_floor(mark.type):
			_draw_wall_mark(mark)
	for door in _area.doors:
		var rect := Rect2(door.x - OficinasMapData.DOOR_WIDTH * 0.5, r.end.y - OficinasMapData.DOOR_HEIGHT,
				OficinasMapData.DOOR_WIDTH, OficinasMapData.DOOR_HEIGHT)
		_draw_depth_door(rect, _area.kind, door.depth_door)
	for item in _area.furniture:
		if _is_wall_item(item.type):
			_draw_furniture(item)
	for lamp in _area.lamps:
		_draw_lamp(lamp)
	for item in _area.furniture:
		if not _is_wall_item(item.type):
			_draw_furniture(item)
	for solid in _area.solids:
		_box(solid, _style.structure, int(solid.position.x + solid.position.y))
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 6.0), _style.edge)
	for mark in _area.marks:
		if MapMark.on_floor(mark.type):
			_draw_floor_mark(mark)


## Detalles de fondo según la variante del área.
func _draw_variant_back(r: Rect2) -> void:
	var rng := _rng_for(int(r.position.y))
	match _area.theme:
		OficinasMapData.RoomTheme.FIRE_ESCAPE:
			# Tramos de escalera en zigzag que suben por el fondo.
			var flights := 4
			for k in flights:
				var y0 := r.end.y - k * r.size.y / flights
				var x0 := r.position.x + 240.0 + (k % 2) * (r.size.x - 640.0)
				var dir := 1.0 if k % 2 == 0 else -1.0
				var a := Vector2(x0, y0)
				var b := Vector2(x0 + dir * 400.0, y0 - r.size.y / flights)
				draw_line(a, b, Color(_style.structure_light, 0.5), 10.0)
				draw_line(a + Vector2(0.0, -60.0), b + Vector2(0.0, -60.0), Color(_style.structure_light, 0.4), 4.0)
		OficinasMapData.RoomTheme.MAINTENANCE:
			for k in 3:
				var y := r.position.y + 24.0 + k * 22.0
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), _style.structure_light.darkened(0.1 * k), 14.0)
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), _style.outline, 2.0)
		OficinasMapData.RoomTheme.COLLAPSED_HALL:
			for k in 3:
				var hole := Rect2(r.position.x + rng.randf_range(0.1, 0.8) * r.size.x, r.position.y, rng.randf_range(80.0, 160.0),
						rng.randf_range(60.0, 140.0))
				draw_rect(hole, _style.outline)
				_draw_hole_edge(PackedVector2Array([hole.position, hole.position + Vector2(hole.size.x * 0.5, hole.size.y),
						Vector2(hole.end.x, hole.position.y)]))
		OficinasMapData.RoomTheme.SERVER:
			draw_rect(r, Color(InteriorView.EXIT_GREEN, 0.05))
		OficinasMapData.RoomTheme.BATHROOM:
			# Azulejos.
			var y := r.position.y + 20.0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(_style.paper, 0.12), 2.0)
				y += 30.0
			var x := r.position.x
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(_style.paper, 0.12), 2.0)
				x += 30.0
