@tool
class_name OficinasGraphView
extends Node2D
## Vista de depuración del grafo de recorrido: nodos (verde = llega a la salida),
## conexiones verticales por tipo (escalera amarilla, ascensor celeste, caída roja),
## y la ruta más corta de la entrada a la salida.

const STAIRS_COLOR := Color("ffd400")
const LIFT_COLOR := Color("4fd8ff")
const FALL_COLOR := Color("ff4a4a")
const PATH_COLOR := Color("3ddc84")

var _data: OficinasMapData


func setup(data: OficinasMapData) -> void:
	_data = data
	queue_redraw()


func _point(node: Vector2i) -> Vector2:
	return Vector2((node.y + 0.5) * _data.module_width, _data.surface_y(node.x) - 40.0)


func _draw() -> void:
	if _data == null:
		return
	var layout := _data.layout
	var good := layout.can_reach(layout.end)
	for node in layout.nodes():
		for pair in layout.successors(node):
			var link: int = pair[1]
			if link == OficinasLayout.Link.WALK:
				continue
			var color := STAIRS_COLOR if link == OficinasLayout.Link.STAIRS else (
					LIFT_COLOR if link == OficinasLayout.Link.LIFT else FALL_COLOR)
			_arrow(_point(node), _point(pair[0]), color)
	var path := layout.shortest_path(layout.start, layout.end)
	for i in range(1, path.size()):
		draw_line(_point(path[i - 1][0]) + Vector2(0.0, 12.0), _point(path[i][0]) + Vector2(0.0, 12.0), PATH_COLOR, 6.0)
	for node in layout.nodes():
		draw_circle(_point(node), 10.0, PATH_COLOR if good.has(node) else FALL_COLOR)
	draw_circle(_point(layout.start), 20.0, Color.WHITE)
	draw_circle(_point(layout.end), 20.0, PATH_COLOR)


func _arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 4.0)
	var dir := (to - from).normalized()
	var tip := to - dir * 12.0
	draw_colored_polygon(PackedVector2Array([to, tip + dir.orthogonal() * 9.0, tip - dir.orthogonal() * 9.0]), color)
