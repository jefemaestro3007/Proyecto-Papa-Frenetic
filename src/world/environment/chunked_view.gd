@tool
class_name ChunkedView
extends Node2D
## Divide una vista estática grande en trozos para que Godot descarte los que quedan fuera de
## pantalla: el costo de dibujo depende de lo visible, no del tamaño del mapa. Arma una grilla de
## celdas sobre el área del mapa y, por cada capa y celda, una instancia de la vista que solo
## dibuja sus elementos (ChunkCanvas). Las capas van en orden, así lo que cruza el borde de una
## celda (un hueco de ascensor de varios pisos) queda detrás de las capas siguientes igual que
## cuando todo era una sola vista. El material se pone en este nodo y lo heredan los trozos.

const CELL := Vector2(2048.0, 2048.0)

var views: Array[ChunkCanvas] = []


## `factory` crea y configura una vista (ChunkCanvas) sin grilla; `bounds` es el área del mapa.
func build(factory: Callable, bounds: Rect2, layers: int, cell := CELL) -> void:
	for view in views:
		view.free()
	views.clear()
	var cells := Vector2i(maxi(1, ceili(bounds.size.x / cell.x)), maxi(1, ceili(bounds.size.y / cell.y)))
	for layer in layers:
		for y in cells.y:
			for x in cells.x:
				var view: ChunkCanvas = factory.call()
				view.set_chunk(Vector2i(x, y), layer, bounds.position, cell, cells)
				view.use_parent_material = true
				add_child(view)
				views.append(view)


## Redibuja todos los trozos (al cambiar el estilo).
func redraw() -> void:
	for view in views:
		view.queue_redraw()
