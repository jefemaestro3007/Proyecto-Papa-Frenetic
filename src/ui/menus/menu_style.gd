class_name MenuStyle
extends RefCounted
## Colores, fuente y dibujos comunes de las pantallas del menú hechas en código (pausa,
## configuración): copian el diseño de los PSD (botones café y amarillo con sombra negra,
## etiqueta torcida, texto crema con contorno). La fuente es Jersey 20, la de los diseños.

const FONT_PATH := "res://assets/fonts/jersey20/Jersey20-Regular.ttf"
const BROWN := Color("9a5f39")
const YELLOW := Color("f0be55")
const INK := Color("120f0c")
const CREAM := Color("fff2cf")
const TAG := Color("b5561c")
## Panel oscuro sobre el fondo gris del menú.
const PANEL := Color("2c2723")
const PANEL_LIGHT := Color("3a332d")
const SHADOW := Vector2(5.0, 5.0)

static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else ThemeDB.fallback_font
	return _font


## Texto centrado en `at` (línea base), con contorno si `outline` > 0.
static func text(item: CanvasItem, label: String, at: Vector2, size: int, color: Color, outline := 0) -> void:
	var width := font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var origin := at - Vector2(width * 0.5, 0.0)
	if outline > 0:
		item.draw_string_outline(font(), origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	item.draw_string(font(), origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto alineado a la izquierda, centrado en vertical dentro de `rect`.
static func text_left(item: CanvasItem, label: String, rect: Rect2, size: int, color: Color) -> void:
	var baseline := rect.position.y + (rect.size.y + font().get_ascent(size) - font().get_descent(size)) * 0.5
	item.draw_string(font(), Vector2(rect.position.x, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Texto centrado en un rectángulo.
static func text_in(item: CanvasItem, label: String, rect: Rect2, size: int, color: Color) -> void:
	var baseline := rect.position.y + (rect.size.y + font().get_ascent(size) - font().get_descent(size)) * 0.5
	text(item, label, Vector2(rect.get_center().x, baseline), size, color)


## Caja con sombra negra desplazada y borde, como los botones del diseño.
static func box(item: CanvasItem, rect: Rect2, fill: Color, border := 2.0) -> void:
	item.draw_rect(Rect2(rect.position + SHADOW, rect.size), INK)
	item.draw_rect(rect, fill)
	item.draw_rect(rect, INK, false, border)


## Botón del diseño: caja con sombra y su texto.
static func button(item: CanvasItem, rect: Rect2, fill: Color, label: String, color: Color, size := 24) -> void:
	box(item, rect, fill)
	text_in(item, label, rect, size, color)


## Etiqueta torcida (como la "UnU!" de YOU LOOSE).
static func tag(item: CanvasItem, at: Vector2, label: String, degrees := 6.0) -> void:
	var width := font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 28.0
	item.draw_set_transform(at, deg_to_rad(degrees))
	box(item, Rect2(-width * 0.5, -18.0, width, 34.0), TAG)
	text_in(item, label, Rect2(-width * 0.5, -18.0, width, 34.0), 24, CREAM)
	item.draw_set_transform(Vector2.ZERO)


## Contorno de foco: crema con halo que late con el beat (igual que MenuHotspot).
static func focus_ring(item: CanvasItem, rect: Rect2, amount: float) -> void:
	if amount <= 0.0:
		return
	var grow := 4.0 + 3.0 * amount * (0.5 + 0.5 * Conductor.pulse(8.0))
	var ring := rect.grow(grow)
	item.draw_rect(ring.grow(3.0), Color(CREAM, 0.18 * amount), false, 8.0)
	item.draw_rect(ring, Color(CREAM, amount), false, 3.0)
