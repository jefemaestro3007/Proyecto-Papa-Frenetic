@tool
class_name StyledCanvas
extends Node2D
## Primitivas de dibujo que respetan un ArtStyle: contorno, trazo a mano, sombras
## proyectadas, sombreado por caras y borde de luz, más motivos reutilizables
## (sangre, grietas, escombros, afiches, grafitis, huesos, cajas, telarañas).
## Las vistas de cada zona heredan de aquí.

const WOBBLE_STEP := 18.0

var _style: ArtStyle


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
	var inner := rect.grow(-_style.outline_width * 0.5)
	if inner.size.x <= 2.0 or inner.size.y <= 2.0:
		return
	# Sombreado por caras: lado izquierdo iluminado, derecho en sombra.
	if _style.cel_shading > 0.0:
		var strip := clampf(inner.size.x * 0.2, 3.0, 26.0)
		draw_rect(Rect2(inner.position, Vector2(strip, inner.size.y)),
				Color(fill.lightened(0.35), _style.cel_shading * 0.8))
		draw_rect(Rect2(Vector2(inner.end.x - strip, inner.position.y), Vector2(strip, inner.size.y)),
				Color(fill.darkened(0.4), _style.cel_shading * 0.8))
	if _style.rim_light:
		var width := maxf(_style.outline_width * 0.5, 2.0)
		draw_line(inner.position + Vector2(0.0, width * 0.5), Vector2(inner.end.x, inner.position.y + width * 0.5),
				Color(_style.edge, 0.7), width)


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


## Telaraña en una esquina superior: se abre hacia abajo y hacia `dir` (1 = derecha, -1 = izquierda).
func _maybe_cobweb(corner: Vector2, dir: float, size: float, variant: int) -> void:
	if _style.cobwebs <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = variant
	if rng.randf() >= _style.cobwebs * 0.6:
		return
	var color := Color(_style.edge, 0.55)
	var spokes := PackedVector2Array()
	for k in 4:
		var t := (k / 3.0) * PI * 0.5
		spokes.append(corner + Vector2(sin(t) * dir, cos(t)) * size)
		draw_line(corner, spokes[k], color, 1.5)
	for ring in [0.4, 0.7, 1.0]:
		var arc := PackedVector2Array()
		for spoke in spokes:
			arc.append(corner.lerp(spoke, ring) + Vector2(0.0, size * 0.06))
		draw_polyline(arc, color, 1.5)


func _draw_crate(rect: Rect2, variant: int) -> void:
	_box(rect, _style.edge.darkened(0.35), variant)
	var inset := rect.grow(-6.0)
	draw_rect(inset, _style.structure_dark, false, 3.0)
	draw_line(inset.position, inset.end, _style.structure_dark, 3.0)


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


## Afiche pegado y torcido: papel, banda de color, "texto" y esquina rasgada.
func _draw_poster(center: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var half := Vector2(27.0, 38.0) * size
	draw_set_transform(center, rng.randf_range(-0.15, 0.15))
	var paper := Rect2(-half, half * 2.0)
	_box(paper, _style.edge, rng.randi())
	draw_rect(Rect2(paper.position + Vector2(6.0, 6.0), Vector2(paper.size.x - 12.0, paper.size.y * 0.3)),
			_style.accent if rng.randf() < 0.5 else _style.blood)
	for k in 3:
		draw_rect(Rect2(paper.position + Vector2(6.0, paper.size.y * (0.45 + k * 0.15)),
				Vector2((paper.size.x - 12.0) * rng.randf_range(0.5, 1.0), 5.0)), _style.structure_dark)
	_fill(PackedVector2Array([paper.end, paper.end - Vector2(18.0, 0.0), paper.end - Vector2(0.0, 22.0)]),
			_style.structure)
	draw_set_transform(Vector2.ZERO)


## Firma de grafiti: trazo grueso con contorno y chorreones.
func _draw_graffiti(origin: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var points := PackedVector2Array([origin])
	for k in rng.randi_range(7, 12):
		points.append(points[k] + Vector2(rng.randf_range(8.0, 22.0), rng.randf_range(-26.0, 26.0)) * size)
	var colors := [_style.accent, _style.edge, _style.blood.lightened(0.2)]
	var color: Color = colors[rng.randi() % colors.size()]
	draw_polyline(points, _style.outline, 12.0 * size + _style.outline_width)
	draw_polyline(points, color, 12.0 * size)
	for k in rng.randi_range(1, 3):
		var start := points[rng.randi_range(0, points.size() - 1)]
		draw_line(start, start + Vector2(0.0, rng.randf_range(20.0, 70.0)), color, 4.0)


## Calavera con huesos cruzados sobre el techo.
func _draw_bones(base: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var bone := _style.edge.lightened(0.15)
	var center := base + Vector2(rng.randf_range(-20.0, 20.0), -12.0 * size)
	for k in 2:
		var a := center + Vector2(-20.0, 8.0 if k == 0 else -2.0) * size
		var b := center + Vector2(20.0, -2.0 if k == 0 else 8.0) * size
		draw_line(a, b, _style.outline, 9.0 * size)
		draw_line(a, b, bone, 5.0 * size)
		for end in [a, b]:
			draw_circle(end, 4.0 * size, bone)
	_shape(_ellipse(center + Vector2(0.0, -10.0) * size, Vector2(11.0, 10.0) * size, 12), bone, rng.randi())
	for eye in [-4.0, 4.0]:
		draw_circle(center + Vector2(eye, -11.0) * size, 2.6 * size, _style.outline)
