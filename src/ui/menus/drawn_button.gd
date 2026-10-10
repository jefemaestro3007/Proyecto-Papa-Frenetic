class_name DrawnButton
extends MenuHotspot
## Botón dibujado en código con el estilo del diseño (caja café o amarilla con sombra y texto),
## para las pantallas que no tienen PSD. `selected` lo pinta de amarillo (pestaña activa).

var label := ""
var fill := MenuStyle.BROWN
var label_color := MenuStyle.CREAM
var font_size := 24
var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _init(p_label := "", p_fill := MenuStyle.BROWN, p_label_color := MenuStyle.CREAM) -> void:
	super()
	label = p_label
	fill = p_fill
	label_color = p_label_color


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if selected:
		MenuStyle.button(self, rect, MenuStyle.YELLOW, label, MenuStyle.INK, font_size)
	else:
		MenuStyle.button(self, rect, fill, label, label_color, font_size)
	super()
