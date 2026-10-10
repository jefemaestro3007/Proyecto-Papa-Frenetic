@tool
class_name SkylineView
extends Node2D
## Dibuja una capa de skyline generada (siluetas + ventanas). Se redibuja solo al asignar datos.

var body_color: Color = FreneticPalette.RUIN_FAR
var window_color: Color = FreneticPalette.WINDOW_FAR
var _data: AzoteaMapData.SkylineData


func setup(data: AzoteaMapData.SkylineData, body: Color, windows: Color) -> void:
	_data = data
	body_color = body
	window_color = windows
	queue_redraw()


## Recolorea sin regenerar; solo redibuja si el color cambió.
func set_colors(body: Color, windows: Color) -> void:
	if body == body_color and windows == window_color:
		return
	body_color = body
	window_color = windows
	queue_redraw()


func _draw() -> void:
	if _data == null:
		return
	for outline in _data.buildings:
		draw_colored_polygon(outline, body_color)
	for rect in _data.windows:
		draw_rect(rect, window_color)
