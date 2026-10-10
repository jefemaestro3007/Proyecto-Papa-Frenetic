@tool
class_name ChunkCanvas
extends Node2D
## Vista que puede dibujar solo un trozo del mapa (ver ChunkedView): los elementos cuyo ancla
## cae en su celda de la grilla y que pertenecen a su capa. Suelta (sin grilla) dibuja todo.

var _chunk := Vector2i(-1, -1)
var _layer := -1
var _origin := Vector2.ZERO
var _cell := Vector2.ONE
var _cells := Vector2i.ONE


## Asigna la celda y la capa que dibuja esta vista dentro de la grilla de una ChunkedView.
func set_chunk(chunk: Vector2i, layer: int, origin: Vector2, cell: Vector2, cells: Vector2i) -> void:
	_chunk = chunk
	_layer = layer
	_origin = origin
	_cell = cell
	_cells = cells


## Si el elemento anclado en `anchor` le toca a esta vista. Cada punto cae en exactamente una
## celda (los bordes de la grilla se extienden hacia afuera), así nada se dibuja dos veces.
func _owns(anchor: Vector2) -> bool:
	if _layer < 0:
		return true
	var x := clampi(floori((anchor.x - _origin.x) / _cell.x), 0, _cells.x - 1)
	var y := clampi(floori((anchor.y - _origin.y) / _cell.y), 0, _cells.y - 1)
	return x == _chunk.x and y == _chunk.y


## Si esta vista dibuja la capa `index`.
func _in_layer(index: int) -> bool:
	return _layer < 0 or _layer == index
