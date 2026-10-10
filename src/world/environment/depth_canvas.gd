@tool
class_name DepthCanvas
extends StyledCanvas
## Dibujo en perspectiva de un punto ("Perspectiva de Oferta", nivel 3): el plano jugable es la boca
## de una caja y todo lo de atrás converge en un único punto de fuga, que es el centro de la
## pantalla. Un punto con profundidad `d` (0 = plano jugable, 1 = punto de fuga) se dibuja en
## `vp + (p − vp)·(1 − d)`. Los prismas muestran el costado que mira al centro y el techo si están
## por debajo del ojo. Depende de la cámara: se redibuja cada frame, solo lo que está en pantalla.

const PRODUCT_COLORS: Array[Color] = [Color("ffd400"), Color("4fb3c9"), Color("8fbf4d"), Color("ef6657"),
		Color("eee6dc"), Color("c98bdb"), Color("f29b38"), Color("d8433a")]

## Punto de fuga y lo visible (en coordenadas locales) del frame actual.
var vp := Vector2.ZERO
var screen := Rect2()
# Lote de cuadriláteros (con color por vértice) que se manda en una sola llamada (`_flush`).
var _batch_points := PackedVector2Array()
var _batch_colors := PackedColorArray()
var _batch_indices := PackedInt32Array()


func _process(_delta: float) -> void:
	queue_redraw()


## Actualiza el punto de fuga y el rectángulo visible. Llamar al empezar `_draw`.
func _begin_frame() -> void:
	screen = SpatialIndex.screen_rect(self, 120.0)
	if screen.size.x > 1e6:
		# En el editor no hay cámara: se usa una vista fija sobre el origen.
		screen = Rect2(-200.0, -900.0, 2400.0, 1200.0)
	vp = screen.get_center()


## Proyección de `point` a la profundidad `d`.
func _p(point: Vector2, d: float) -> Vector2:
	return vp + (point - vp) * (1.0 - d)


## Rango de x del plano jugable que alcanza a verse a la profundidad `d` (más ancho cuanto más
## al fondo).
func _x_range(d: float) -> Vector2:
	var half := screen.size.x * 0.5 / maxf(1.0 - d, 0.05)
	return Vector2(vp.x - half, vp.x + half)


## Cuadrilátero relleno. La proyección de una cara plana es convexa; si no lo es (o no tiene área)
## es porque se ve de canto, y se omite.
func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	var c0 := (b - a).cross(c - b)
	var c1 := (c - b).cross(d - c)
	var c2 := (d - c).cross(a - d)
	var c3 := (a - d).cross(b - a)
	if absf(c0 + c1 + c2 + c3) < 2.0:
		return
	var positive := c0 > 0.0
	for cross: float in [c1, c2, c3]:
		if absf(cross) > 0.01 and (cross > 0.0) != positive:
			return
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)


## Agrega un cuadrilátero al lote: muchos (baldosas, tubos) cuestan una sola llamada de dibujo.
## Se dibujan todos juntos al llamar `_flush`, así que el orden entre lotes lo decide quien llama.
func _batch_quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	if absf((c - a).cross(d - b)) < 1.0:
		return
	var base := _batch_points.size()
	_batch_points.append_array([a, b, c, d])
	_batch_colors.append_array([color, color, color, color])
	_batch_indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


func _flush() -> void:
	if _batch_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _batch_indices, _batch_points, _batch_colors)
	_batch_points.clear()
	_batch_colors.clear()
	_batch_indices.clear()


func _quad_outline(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, width: float) -> void:
	draw_polyline(PackedVector2Array([a, b, c, d, a]), color, width, true)


## Prisma con el frente `rect` en la profundidad `d0` y el fondo en `d1`. Dibuja el costado que se
## ve y el techo (o la base) si corresponde, y devuelve el frente proyectado para que quien llama
## lo decore. `side`/`top` son los colores de esas caras; el frente se pinta con `front`.
func _prism(rect: Rect2, d0: float, d1: float, front: Color, side: Color, top: Color, outline := true,
		draw_front := true, variant := 0) -> PackedVector2Array:
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)
	var ink := _style.outline
	var width := maxf(_style.outline_width * 0.6, 1.5)
	if rect.end.x < vp.x:
		_face(_p(tr, d0), _p(tr, d1), _p(br, d1), _p(br, d0), side, ink, width, outline)
	elif rect.position.x > vp.x:
		_face(_p(tl, d0), _p(tl, d1), _p(bl, d1), _p(bl, d0), side, ink, width, outline)
	if rect.position.y > vp.y:
		_face(_p(tl, d0), _p(tr, d0), _p(tr, d1), _p(tl, d1), top, ink, width, outline)
	elif rect.end.y < vp.y:
		_face(_p(bl, d0), _p(br, d0), _p(br, d1), _p(bl, d1), side.darkened(0.2), ink, width, outline)
	var face := PackedVector2Array([_p(tl, d0), _p(tr, d0), _p(br, d0), _p(bl, d0)])
	if draw_front:
		_styled_front(rect, d0, front, variant if variant != 0 else int(rect.position.x * 13.0 + rect.position.y * 7.0), outline)
	return face


## Frente de un prisma con los rasgos del estilo, como `StyledCanvas._box`: trazo a mano (el
## temblor se calcula sobre el rectángulo sin proyectar, así no tiembla al moverse la cámara),
## sombra proyectada, sombreado por caras y borde de luz.
func _styled_front(rect: Rect2, d: float, fill: Color, variant: int, outline := true) -> void:
	var points := _rect_points(rect)
	if _style.wobble > 0.0:
		points = _wobbled(points, variant)
	for i in points.size():
		points[i] = _p(points[i], d)
	var scale := 1.0 - d
	if _style.drop_shadows:
		var shadow := points.duplicate()
		for i in shadow.size():
			shadow[i] += Vector2(6.0, 6.0) * scale
		_fill(shadow, Color(_style.outline, 0.35))
	_fill(points, fill)
	if outline and _style.outline_width > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, _style.outline, maxf(_style.outline_width * scale, 1.0), true)
	var inner := Rect2(_p(rect.position, d), rect.size * scale).grow(-_style.outline_width * 0.5 * scale)
	if inner.size.x <= 2.0 or inner.size.y <= 2.0:
		return
	if _style.cel_shading > 0.0:
		var strip := clampf(inner.size.x * 0.2, 3.0, 26.0)
		draw_rect(Rect2(inner.position, Vector2(strip, inner.size.y)), Color(fill.lightened(0.35), _style.cel_shading * 0.8))
		draw_rect(Rect2(Vector2(inner.end.x - strip, inner.position.y), Vector2(strip, inner.size.y)),
				Color(fill.darkened(0.4), _style.cel_shading * 0.8))
	if _style.rim_light:
		var width := maxf(_style.outline_width * 0.5, 2.0)
		draw_line(inner.position + Vector2(0.0, width * 0.5), Vector2(inner.end.x, inner.position.y + width * 0.5),
				Color(_style.edge, 0.7), width)


func _face(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color, ink: Color, width: float, outline: bool) -> void:
	_quad(a, b, c, d, color)
	if outline and _style.outline_width > 0.0:
		_quad_outline(a, b, c, d, ink, width)


## Rectángulo `rect` del frente de un prisma ya proyectado (`face` = tl, tr, br, bl) en coordenadas
## normalizadas (0..1): para decorar el frente sin recalcular la proyección.
static func _sub(face: PackedVector2Array, u0: float, v0: float, u1: float, v1: float) -> PackedVector2Array:
	var top0 := face[0].lerp(face[1], u0)
	var top1 := face[0].lerp(face[1], u1)
	var bottom0 := face[3].lerp(face[2], u0)
	var bottom1 := face[3].lerp(face[2], u1)
	return PackedVector2Array([top0.lerp(bottom0, v0), top1.lerp(bottom1, v0), top1.lerp(bottom1, v1),
			top0.lerp(bottom0, v1)])


func _fill_sub(face: PackedVector2Array, u0: float, v0: float, u1: float, v1: float, color: Color) -> void:
	var q := _sub(face, u0, v0, u1, v1)
	_quad(q[0], q[1], q[2], q[3], color)


## Texto centrado en `at` con un tamaño escalado por la profundidad.
func _text(label: String, at: Vector2, size: float, color: Color, outline := 0) -> void:
	var font := MenuStyle.font()
	var px := maxi(int(size), 6)
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := at + Vector2(-width * 0.5, font.get_ascent(px) * 0.5 - 2.0)
	if outline > 0:
		draw_string_outline(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, _style.outline)
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


static func _product_color(seed: int) -> Color:
	return PRODUCT_COLORS[posmod(seed, PRODUCT_COLORS.size())]


static func _hash(a: int, b: int) -> int:
	return absi((a * 73856093) ^ (b * 19349663))
