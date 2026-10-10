@tool
class_name RooftopView
extends StyledCanvas
## Dibuja las azoteas jugables y sus detalles (objetos, marcas, cables) según un ArtStyle.
## Es estático: solo se redibuja al cambiar los datos o el estilo.

const Prop := AzoteaMapData.Prop
const Mark := AzoteaMapData.Mark

const LIP := 10.0
const RAIL_HEIGHT := 120.0
const RAIL_POST_SPACING := 110.0
const RAIL_THICKNESS := 12.0
const HAZARD_LENGTH := 160.0
const HAZARD_STRIPE := 22.0
const FACADE_DEPTH := 640.0
const FENCE_HEIGHT := 150.0
const BRICK := Vector2(46.0, 22.0)

var _data: AzoteaMapData
var _seed: int = 0


func setup(data: AzoteaMapData, seed: int, style: ArtStyle) -> void:
	_data = data
	_seed = seed
	_style = style
	queue_redraw()


func _draw() -> void:
	if _data == null or _style == null:
		return
	for cable in _data.cables:
		_draw_cable(cable)
	# La baranda va detrás de los objetos para que no los tape.
	for roof in _data.roofs:
		_draw_railing(roof)
	for prop in _data.props:
		_draw_prop(prop)
	for i in _data.roofs.size():
		_draw_block(_data.roofs[i], i)
	for mark in _data.marks:
		_draw_mark(mark)


# --- Estructura ----------------------------------------------------------------------

func _draw_block(roof: Rect2, index: int) -> void:
	var variant := _seed ^ (index * 7919)
	_box(roof, _style.structure, variant)
	var lip := Rect2(roof.position, Vector2(roof.size.x, LIP))
	draw_rect(lip, _style.edge)
	draw_rect(Rect2(roof.position + Vector2(0, LIP), Vector2(roof.size.x, 18.0)), _style.structure_dark)
	if _style.bricks > 0.0:
		_draw_bricks(roof)
	if _style.facade_windows:
		_draw_facade_windows(roof, variant)
	else:
		var x := roof.position.x + 40.0
		while x < roof.end.x - 20.0:
			draw_line(Vector2(x, roof.position.y + 60.0), Vector2(x, roof.position.y + 900.0),
					_style.structure_dark, 4.0)
			x += 180.0
	if _style.drainpipes:
		_draw_drainpipe(roof, variant)
	if _style.hazard_stripes:
		_draw_hazard(roof)


## Ladrillos trabados en la fachada, por debajo de las ventanas.
func _draw_bricks(roof: Rect2) -> void:
	var color := Color(_style.structure_dark, _style.bricks * 0.7)
	var left := roof.position.x + 8.0
	var right := roof.end.x - 8.0
	var row := 0
	var y := roof.position.y + 30.0
	while y < roof.position.y + FACADE_DEPTH + 60.0:
		draw_line(Vector2(left, y), Vector2(right, y), color, 2.0)
		var x := left + (BRICK.x * 0.5 if row % 2 == 1 else 0.0)
		while x < right:
			draw_line(Vector2(x, y), Vector2(x, y + BRICK.y), color, 2.0)
			x += BRICK.x
		y += BRICK.y
		row += 1


## Bajante de agua con codo bajo el borde y abrazaderas.
func _draw_drainpipe(roof: Rect2, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant + 31
	if roof.size.x < 300.0 or rng.randf() < 0.3:
		return
	var x := roof.position.x + 34.0 if rng.randf() < 0.5 else roof.end.x - 46.0
	var top := roof.position.y + LIP + 18.0
	var bottom := roof.position.y + FACADE_DEPTH + 120.0
	_box(Rect2(x, top, 12.0, bottom - top), _style.structure_light, variant + 1)
	var y := top + 90.0
	while y < bottom:
		_box(Rect2(x - 4.0, y, 20.0, 8.0), _style.structure_dark, variant + int(y))
		y += 130.0


func _draw_facade_windows(roof: Rect2, variant: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	const CELL := Vector2(80.0, 76.0)
	const SIZE := Vector2(30.0, 40.0)
	var cols := int((roof.size.x - 60.0) / CELL.x)
	var margin := (roof.size.x - cols * CELL.x) * 0.5
	for r in int(FACADE_DEPTH / CELL.y):
		for c in cols:
			if rng.randf() < 0.18:
				continue
			var rect := Rect2(roof.position + Vector2(margin + c * CELL.x + (CELL.x - SIZE.x) * 0.5,
					60.0 + r * CELL.y), SIZE)
			var lit := rng.randf() < _style.lit_windows
			draw_rect(rect, _style.window_lit if lit else _style.window_dark)
			if _style.outline_width > 0.0:
				draw_rect(rect, _style.outline, false, maxf(_style.outline_width * 0.5, 1.0))


func _draw_railing(roof: Rect2) -> void:
	# Algunas azoteas llevan alambrado en lugar de baranda (decidido por azotea, estable).
	if _style.fence_amount > 0.0 and fposmod(sin(roof.position.x * 12.9898) * 43758.5453, 1.0) < _style.fence_amount:
		_draw_fence(roof)
		return
	var y0 := roof.position.y
	var left := roof.position.x + 24.0
	var right := roof.end.x - 24.0
	if right - left < RAIL_POST_SPACING:
		return
	var i := 0
	for rail_y in [y0 - RAIL_HEIGHT, y0 - RAIL_HEIGHT * 0.62, y0 - RAIL_HEIGHT * 0.3]:
		_box(Rect2(left, rail_y, right - left, RAIL_THICKNESS), _style.structure_light, _seed + i)
		i += 1
	var x := left
	while x <= right:
		_box(Rect2(x - 7.0, y0 - RAIL_HEIGHT - 6.0, 14.0, RAIL_HEIGHT + 6.0), _style.structure, _seed + int(x))
		_maybe_cobweb(Vector2(x + 7.0, y0 - RAIL_HEIGHT + 6.0), 1.0, 26.0, int(x) ^ _seed)
		x += RAIL_POST_SPACING


## Alambrado: postes, travesaño y malla de rombos recortada al panel.
func _draw_fence(roof: Rect2) -> void:
	var y0 := roof.position.y
	var panel := Rect2(roof.position.x + 24.0, y0 - FENCE_HEIGHT, roof.size.x - 48.0, FENCE_HEIGHT)
	var panel_points := _rect_points(panel)
	var mesh := Color(_style.structure_light, 0.85)
	var x := panel.position.x - FENCE_HEIGHT
	while x < panel.end.x:
		for line in [PackedVector2Array([Vector2(x, y0), Vector2(x + FENCE_HEIGHT, y0 - FENCE_HEIGHT)]),
				PackedVector2Array([Vector2(x, y0 - FENCE_HEIGHT), Vector2(x + FENCE_HEIGHT, y0)])]:
			for clipped in Geometry2D.intersect_polyline_with_polygon(line, panel_points):
				draw_polyline(clipped, mesh, 2.0)
		x += 22.0
	_box(Rect2(panel.position.x, panel.position.y - 6.0, panel.size.x, 10.0), _style.structure_light, _seed + 3)
	var post := panel.position.x
	while post <= panel.end.x:
		_box(Rect2(post - 6.0, panel.position.y - 6.0, 12.0, FENCE_HEIGHT + 6.0), _style.structure, _seed + int(post))
		post += 170.0


## Franjas de peligro en ambos extremos de la azotea (avisan del borde).
func _draw_hazard(roof: Rect2) -> void:
	var y := roof.position.y + LIP + 18.0
	var h := 26.0
	for side in [roof.position.x, roof.end.x - HAZARD_LENGTH]:
		var band := Rect2(side, y, HAZARD_LENGTH, h)
		draw_rect(band, _style.accent)
		var x: float = side - h
		while x < side + HAZARD_LENGTH:
			var stripe := PackedVector2Array([
				Vector2(x + h, y), Vector2(x + h + HAZARD_STRIPE, y),
				Vector2(x + HAZARD_STRIPE, y + h), Vector2(x, y + h)])
			for clipped in Geometry2D.intersect_polygons(stripe, _rect_points(band)):
				draw_colored_polygon(clipped, _style.outline)
			x += HAZARD_STRIPE * 2.0
		draw_rect(band, _style.outline, false, 3.0)


func _draw_cable(cable: AzoteaMapData.Cable) -> void:
	for end in [[cable.from, cable.from_base_y], [cable.to, cable.to_base_y]]:
		var top: Vector2 = end[0]
		_box(Rect2(top.x - 4.0, top.y, 8.0, end[1] - top.y), _style.structure, int(top.x))
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(cable.from.lerp(cable.to, t) + Vector2(0.0, 4.0 * cable.sag * t * (1.0 - t)))
	draw_polyline(points, _style.outline, maxf(_style.outline_width * 0.75, 2.0), true)
	if _style.cable_flags:
		var colors := [_style.accent, _style.edge, _style.blood]
		for i in range(1, points.size() - 1):
			var p := points[i]
			var flag := PackedVector2Array([p + Vector2(-8.0, 0.0), p + Vector2(8.0, 0.0), p + Vector2(0.0, 20.0)])
			_shape(flag, colors[i % colors.size()], i, true)


# --- Objetos -------------------------------------------------------------------------

func _draw_prop(prop: Prop) -> void:
	var r := prop.rect
	var rng := RandomNumberGenerator.new()
	rng.seed = prop.variant
	_draw_prop_body(prop, r, rng)
	_maybe_cobweb(r.position, 1.0, minf(30.0, r.size.x * 0.5), prop.variant + 5)


func _draw_prop_body(prop: Prop, r: Rect2, rng: RandomNumberGenerator) -> void:
	match prop.type:
		Prop.Type.AC_UNIT:
			_box(r, _style.structure_light, prop.variant)
			var fan := Vector2(r.position.x + r.size.x * 0.3, r.get_center().y)
			var radius := r.size.y * 0.32
			_shape(_ellipse(fan, Vector2(radius, radius)), _style.structure_dark, prop.variant + 1)
			for k in 3:
				var angle := TAU * k / 3.0 + rng.randf()
				draw_line(fan, fan + Vector2.from_angle(angle) * radius * 0.85, _style.structure_light, 4.0)
			for k in 4:
				var x := r.position.x + r.size.x * (0.6 + k * 0.09)
				draw_line(Vector2(x, r.position.y + 10.0), Vector2(x, r.end.y - 10.0), _style.structure_dark, 3.0)
		Prop.Type.WATER_TANK:
			var leg_h := r.size.y * 0.3
			for x in [r.position.x + 10.0, r.end.x - 18.0]:
				_box(Rect2(x, r.end.y - leg_h, 8.0, leg_h), _style.structure_dark, prop.variant + int(x))
			var body := Rect2(r.position + Vector2(0.0, r.size.y * 0.15), Vector2(r.size.x, r.size.y * 0.55))
			_box(body, _style.structure_light, prop.variant)
			for k in 3:
				var y := body.position.y + body.size.y * (0.25 + k * 0.25)
				draw_line(Vector2(body.position.x, y), Vector2(body.end.x, y), _style.structure_dark, 3.0)
			_shape(PackedVector2Array([Vector2(r.position.x - 6.0, body.position.y),
					Vector2(r.get_center().x, r.position.y), Vector2(r.end.x + 6.0, body.position.y)]),
					_style.structure, prop.variant + 2)
		Prop.Type.ANTENNA:
			var cx := r.get_center().x
			_box(Rect2(cx - 3.0, r.position.y, 6.0, r.size.y), _style.structure_dark, prop.variant)
			for k in rng.randi_range(2, 4):
				var y := r.position.y + 20.0 + k * 26.0
				var w := 26.0 - k * 4.0
				draw_line(Vector2(cx - w, y), Vector2(cx + w, y), _style.structure_dark, 4.0)
		Prop.Type.VENT:
			_box(Rect2(r.position.x + r.size.x * 0.25, r.position.y + 10.0, r.size.x * 0.5, r.size.y - 10.0),
					_style.structure_light, prop.variant)
			_box(Rect2(r.position.x, r.position.y, r.size.x, 14.0), _style.structure, prop.variant + 1)
		Prop.Type.CHIMNEY:
			_box(r, _style.structure_dark, prop.variant)
			var y := r.position.y + 14.0
			while y < r.end.y - 4.0:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), _style.structure, 2.0)
				y += 16.0
			_box(Rect2(r.position.x - 5.0, r.position.y, r.size.x + 10.0, 12.0), _style.structure, prop.variant + 1)
		Prop.Type.STAIR_HUT:
			_box(r, _style.structure_light, prop.variant)
			_box(Rect2(r.position.x - 8.0, r.position.y, r.size.x + 16.0, 14.0), _style.structure, prop.variant + 1)
			var door := Rect2(r.position.x + r.size.x * 0.55, r.position.y + 34.0, 38.0, r.size.y - 34.0)
			_box(door, _style.structure_dark, prop.variant + 2)
			draw_circle(door.position + Vector2(30.0, door.size.y * 0.55), 3.0, _style.edge)
		Prop.Type.SKYLIGHT:
			var glass := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x + 14.0, r.position.y),
					Vector2(r.end.x - 14.0, r.position.y), Vector2(r.end.x, r.end.y)])
			_shape(glass, _style.window_dark, prop.variant)
			draw_line(Vector2(r.position.x + 22.0, r.position.y + 6.0), Vector2(r.position.x + 40.0, r.position.y + 6.0),
					_style.window_lit, 3.0)
		Prop.Type.BARREL:
			_box(r, _style.blood.darkened(0.2), prop.variant)
			for k in 2:
				var y := r.position.y + r.size.y * (0.3 + k * 0.35)
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), _style.outline, 3.0)
			draw_rect(Rect2(r.position.x + 4.0, r.position.y - 4.0, r.size.x - 8.0, 6.0), _style.outline)
		Prop.Type.CRATES:
			var size := minf(r.size.x, r.size.y * 0.5 + 25.0)
			var x := r.position.x
			while x + size <= r.end.x + 0.5:
				var stack := rng.randi_range(1, maxi(1, int(r.size.y / size)))
				for k in stack:
					_draw_crate(Rect2(x, r.end.y - size * (k + 1), size, size), prop.variant + k + int(x))
				x += size
		Prop.Type.SATELLITE_DISH:
			var base := Vector2(r.get_center().x, r.end.y)
			_box(Rect2(base.x - 4.0, r.position.y + r.size.y * 0.45, 8.0, r.size.y * 0.55), _style.structure_dark,
					prop.variant)
			var dish_center := Vector2(base.x, r.position.y + r.size.y * 0.4)
			var dish := PackedVector2Array()
			for k in 9:
				var angle := lerpf(-2.4, 0.75, k / 8.0)
				dish.append(dish_center + Vector2(cos(angle), sin(angle)) * r.size.x * 0.5)
			_shape(dish, _style.edge, prop.variant + 1)
			draw_line(dish_center, dish_center + Vector2(-14.0, -18.0), _style.outline, 3.0)
		Prop.Type.PIPE_RUN:
			var pipe := Rect2(r.position.x, r.position.y + 6.0, r.size.x, r.size.y * 0.45)
			for x in [r.position.x + 20.0, r.end.x - 34.0]:
				_box(Rect2(x, pipe.end.y, 14.0, r.end.y - pipe.end.y), _style.structure_dark, prop.variant + int(x))
			_box(pipe, _style.structure_light, prop.variant)
			var valve := Vector2(r.position.x + r.size.x * rng.randf_range(0.3, 0.7), pipe.position.y)
			_box(Rect2(valve.x - 3.0, valve.y - 16.0, 6.0, 16.0), _style.structure_dark, prop.variant + 2)
			draw_line(valve + Vector2(-12.0, -16.0), valve + Vector2(12.0, -16.0), _style.blood, 5.0)
		Prop.Type.BILLBOARD:
			var panel := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.55))
			for x in [r.position.x + r.size.x * 0.2, r.position.x + r.size.x * 0.75]:
				_box(Rect2(x, panel.end.y, 10.0, r.size.y - panel.size.y), _style.structure_dark, prop.variant + int(x))
			_box(panel, _style.edge, prop.variant)
			var inner := panel.grow(-12.0)
			_box(inner, _style.structure, prop.variant + 1)
			# "Texto" del cartel: barras gruesas, como afiche rasgado.
			for k in 3:
				var bar_w := inner.size.x * rng.randf_range(0.4, 0.85)
				draw_rect(Rect2(inner.position + Vector2(14.0, 14.0 + k * inner.size.y * 0.28), Vector2(bar_w, 14.0)),
						_style.accent if k == 0 else _style.edge)


# --- Marcas --------------------------------------------------------------------------

func _draw_mark(mark: Mark) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mark.variant
	match mark.type:
		Mark.Type.BLOOD:
			if mark.weight < _style.blood_amount:
				_draw_splatter(mark.position, 30.0 * mark.size, rng)
		Mark.Type.CRACK:
			if mark.weight < _style.crack_amount:
				_draw_crack(mark.position, 90.0 * mark.size, rng)
		Mark.Type.STAIN:
			if mark.weight < _style.stain_amount:
				var radius := Vector2(70.0, 34.0) * mark.size
				_fill(_ellipse(mark.position, radius, 16, 0.25, rng), Color(_style.structure_dark, 0.55))
				_fill(_ellipse(mark.position + Vector2(0.0, radius.y), Vector2(radius.x * 0.2, radius.y * 2.0), 10,
						0.2, rng), Color(_style.structure_dark, 0.4))
		Mark.Type.RUBBLE:
			if mark.weight < _style.rubble_amount:
				_draw_rubble(mark.position, mark.size, rng)
		Mark.Type.POSTER:
			if mark.weight < _style.poster_amount:
				_draw_poster(mark.position, mark.size, rng)
		Mark.Type.GRAFFITI:
			if mark.weight < _style.graffiti_amount:
				_draw_graffiti(mark.position, mark.size, rng)
		Mark.Type.WALL_UNIT:
			if mark.weight < _style.wall_unit_amount:
				var unit := Rect2(mark.position - Vector2(32.0, 22.0), Vector2(64.0, 44.0))
				_shape(PackedVector2Array([unit.position + Vector2(8.0, unit.size.y),
						unit.end, unit.end + Vector2(-8.0, 14.0)]), _style.structure_dark, mark.variant + 1)
				_box(unit, _style.structure_light, mark.variant)
				for k in 4:
					var x := unit.position.x + 12.0 + k * 10.0
					draw_line(Vector2(x, unit.position.y + 8.0), Vector2(x, unit.end.y - 8.0), _style.structure_dark, 3.0)
		Mark.Type.BONES:
			if mark.weight < _style.bones_amount:
				_draw_bones(mark.position, mark.size, rng)


