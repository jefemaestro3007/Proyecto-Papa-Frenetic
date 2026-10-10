class_name SpatialIndex
extends RefCounted
## Índice por celdas de una grilla: devuelve los elementos cercanos a un rectángulo sin recorrer
## todos. Lo usan las vistas que se redibujan cada frame para dibujar solo lo que está en
## pantalla, así su costo no crece con el tamaño del mapa.

const CELL := 1024.0
## Margen alrededor de la pantalla: lo que se dibuja algo lejos de su ancla (conos de luz,
## resplandores, moscas que orbitan) no aparece cortado en el borde.
const SCREEN_MARGIN := 400.0

## Celda → índices de los elementos anclados en ella.
var _cells := {}


func clear() -> void:
	_cells.clear()


func add(index: int, anchor: Vector2) -> void:
	var key := _key(anchor)
	if not _cells.has(key):
		_cells[key] = PackedInt32Array()
	_cells[key].append(index)


## Índices de los elementos anclados dentro de `rect` (o en sus celdas vecinas).
func query(rect: Rect2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var from := _key(rect.position)
	var to := _key(rect.end)
	# Rectángulo más grande que el índice (p. ej. en el editor): sale más barato recorrer todo.
	if (to.x - from.x + 1) * (to.y - from.y + 1) > _cells.size():
		for key: Vector2i in _cells:
			if key.x >= from.x and key.x <= to.x and key.y >= from.y and key.y <= to.y:
				out.append_array(_cells[key])
		return out
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var cell: Variant = _cells.get(Vector2i(x, y))
			if cell != null:
				out.append_array(cell)
	return out


## Lo que `item` muestra en pantalla, en sus coordenadas locales y con margen. En el editor
## (donde no hay cámara de juego) devuelve un rectángulo infinito: se dibuja todo.
static func screen_rect(item: CanvasItem, margin := SCREEN_MARGIN) -> Rect2:
	if Engine.is_editor_hint() or not item.is_inside_tree():
		return Rect2(-1e7, -1e7, 2e7, 2e7)
	var screen := Rect2(Vector2.ZERO, item.get_viewport_rect().size)
	return (item.get_global_transform_with_canvas().affine_inverse() * screen).grow(margin)


func _key(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))
