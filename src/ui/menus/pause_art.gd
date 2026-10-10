class_name PauseArt
extends Control
## Pantalla de pausa dibujada en código (no hay PSD de pausa): título y dos botones con la misma
## forma, colores y sombra que los de YOU LOOSE / YOU WIN, en coordenadas del diseño (1440×1024).
## Los botones clicables son MenuHotspot encima de estos rectángulos (ver ZoneLevel.pause).

## Mismos rectángulos que BACK MENU y TRY AGAIN? en las pantallas de fin de partida.
const MENU_BUTTON := Rect2(438, 702, 278, 58)
const CONTINUE_BUTTON := Rect2(725, 700, 281, 60)
const BROWN := Color("9a5f39")
const YELLOW := Color("f0be55")
const INK := Color("120f0c")
const CREAM := Color("fff2cf")
const TAG := Color("b5561c")


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var center := size.x * 0.5
	_text(font, "PAUSE", Vector2(center, 520.0), 150, CREAM, 18)
	# Etiqueta torcida como la "UnU!" de YOU LOOSE.
	draw_set_transform(Vector2(860.0, 560.0), deg_to_rad(6.0))
	draw_rect(Rect2(-46.0, -14.0, 100.0, 34.0), INK)
	draw_rect(Rect2(-50.0, -18.0, 100.0, 34.0), TAG)
	_text(font, "ZzZ", Vector2(0.0, 7.0), 20, CREAM, 0)
	draw_set_transform(Vector2.ZERO)
	_button(font, MENU_BUTTON, BROWN, "BACK MENU", CREAM)
	_button(font, CONTINUE_BUTTON, YELLOW, "CONTINUE", INK)
	_text(font, "Esc para continuar", Vector2(center, 820.0), 22, Color(CREAM, 0.7), 6)


func _button(font: Font, rect: Rect2, fill: Color, label: String, color: Color) -> void:
	draw_rect(Rect2(rect.position + Vector2(5.0, 5.0), rect.size), INK)
	draw_rect(rect, fill)
	draw_rect(rect, INK, false, 2.0)
	_text(font, label, rect.get_center() + Vector2(0.0, 7.0), 20, color, 0)


## Texto centrado en `at` (línea base), con contorno si `outline` > 0.
func _text(font: Font, text: String, at: Vector2, font_size: int, color: Color, outline: int) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := at - Vector2(width * 0.5, 0.0)
	if outline > 0:
		draw_string_outline(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, INK)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
