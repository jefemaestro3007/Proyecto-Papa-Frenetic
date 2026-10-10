@tool
class_name RooftopView
extends Node2D
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
const WOBBLE_STEP := 18.0
const FACADE_DEPTH := 640.0

var _data: AzoteaMapData
var _seed: int = 0
var _style: ArtStyle


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


# --- Primitivas con trazo del estilo -------------------------------------------------

## Polígono con contorno; con `wobble` > 0 los bordes se vuelven irregulares (a mano).
func _shape(points: PackedVector2Array, fill: Color, variant: int, outline := true) -> void:
	var poly := _wobbled(points, variant) if _style.wobble > 0.0 else points
	if _style.drop_shadows:
		var shadow := poly.duplicate()
		for i in shadow.size():
			shadow[i] += Vector2(6.0, 6.0)
		_fill(shadow, Color(_style.outline, 0.35))
	_fill(poly, fill)
	if outline and _style.outline_width > 0.0:
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed, _style.outline, _style.outline_width, true)


func _box(rect: Rect2, fill: Color, variant: int, outline := true) -> void:
	_shape(_rect_points(rect), fill, variant, outline)


func _fill(poly: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(poly).is_empty():
		return
	draw_colored_polygon(poly, color)


static func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)])


## Subdivide cada lado y desplaza los puntos de forma determinista según `variant`.
func _wobbled(points: PackedVector2Array, variant: int) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	var out := PackedVector2Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var steps := maxi(1, int(a.distance_to(b) / WOBBLE_STEP))
		var normal := (b - a).normalized().orthogonal()
		for k in steps:
			var p := a.lerp(b, float(k) / steps)
			out.append(p + normal * rng.randf_range(-_style.wobble, _style.wobble))
	return out


func _ellipse(center: Vector2, radius: Vector2, segments := 14, jitter := 0.0,
		rng: RandomNumberGenerator = null) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var angle := TAU * i / segments
		var r := 1.0 + (rng.randf_range(-jitter, jitter) if rng != null else 0.0)
		pts.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y) * r)
	return pts


# --- Estructura ----------------------------------------------------------------------

func _draw_block(roof: Rect2, index: int) -> void:
	var variant := _seed ^ (index * 7919)
	_box(roof, _style.structure, variant)
	var lip := Rect2(roof.position, Vector2(roof.size.x, LIP))
	draw_rect(lip, _style.edge)
	draw_rect(Rect2(roof.position + Vector2(0, LIP), Vector2(roof.size.x, 18.0)), _style.structure_dark)
	if _style.facade_windows:
		_draw_facade_windows(roof, variant)
	else:
		var x := roof.position.x + 40.0
		while x < roof.end.x - 20.0:
			draw_line(Vector2(x, roof.position.y + 60.0), Vector2(x, roof.position.y + 900.0),
					_style.structure_dark, 4.0)
			x += 180.0
	if _style.hazard_stripes:
		_draw_hazard(roof)


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
		x += RAIL_POST_SPACING


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


# --- Objetos -------------------------------------------------------------------------

func _draw_prop(prop: Prop) -> void:
	var r := prop.rect
	var rng := RandomNumberGenerator.new()
	rng.seed = prop.variant
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


## Salpicadura: núcleo, gotas satélite y chorreones verticales.
func _draw_splatter(center: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	_fill(_ellipse(center, Vector2(size, size * 0.9), 14, 0.2, rng), _style.blood)
	for d in rng.randi_range(6, 14):
		var dist := size * rng.randf_range(1.1, 2.6)
		draw_circle(center + Vector2.from_angle(rng.randf() * TAU) * dist, rng.randf_range(3.0, size * 0.35),
				_style.blood)
	for d in rng.randi_range(2, 5):
		var start := center + Vector2(rng.randf_range(-size, size) * 0.7, 0.0)
		var length := rng.randf_range(40.0, 220.0)
		var width := rng.randf_range(4.0, 10.0)
		draw_line(start, start + Vector2(0.0, length), _style.blood, width)
		draw_circle(start + Vector2(0.0, length), width * 0.8, _style.blood)


## Grieta en zigzag con una rama.
func _draw_crack(origin: Vector2, length: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array([origin])
	var direction := Vector2.from_angle(rng.randf_range(0.3, PI - 0.3))
	var segments := rng.randi_range(4, 7)
	for i in segments:
		direction = direction.rotated(rng.randf_range(-0.7, 0.7))
		points.append(points[points.size() - 1] + direction * length / segments)
	var width := maxf(_style.outline_width * 0.6, 2.0)
	draw_polyline(points, _style.structure_dark, width + 2.0)
	draw_polyline(points, _style.outline, width)
	var fork := points[rng.randi_range(1, points.size() - 2)]
	draw_line(fork, fork + direction.rotated(rng.randf_range(0.6, 1.2)) * length * 0.3, _style.outline, width)


## Montón de rocas sobre el techo, con brillo arriba a la izquierda.
func _draw_rubble(base: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(3, 6):
		var radius := rng.randf_range(10.0, 26.0) * size
		var center := base + Vector2(rng.randf_range(-40.0, 40.0) * size, -radius * 0.7)
		var rock := _ellipse(center, Vector2(radius * 1.15, radius), 9, 0.22, rng)
		_shape(rock, _style.rock, rng.randi())
		_fill(_ellipse(center + Vector2(-radius * 0.3, -radius * 0.35), Vector2(radius * 0.35, radius * 0.22), 8),
				_style.rock_light)
