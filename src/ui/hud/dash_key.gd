class_name DashKey
extends Control
## Indicador del dash junto a la papa: una tecla SHIFT dibujada con el trazo del juego. Verde cuando
## el dash está listo (y late con el beat), roja cuando no se puede usar: mientras se recarga se va
## llenando de verde de izquierda a derecha, y en el aire queda roja (el dash es solo en el suelo).

const READY := Color("3ddc5a")
const BLOCKED := Color("e3241b")
const KEY_HEIGHT := 46.0
const DEPTH := 7.0
const LABEL := "SHIFT"

var _ready_now := false
var _progress := 1.0
var _beat := 0.0
var _pop := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `cooldown_left` / `cooldown_total` en segundos; `airborne` = en el aire (no se puede dashear).
func set_state(cooldown_left: float, cooldown_total: float, airborne: bool) -> void:
	var was_ready := _ready_now
	_ready_now = cooldown_left <= 0.0 and not airborne
	_progress = 1.0 - cooldown_left / cooldown_total if cooldown_total > 0.0 else 1.0
	if _ready_now and not was_ready:
		_pop = 1.0


func on_beat(pulse: float) -> void:
	_beat = pulse


func _process(delta: float) -> void:
	_beat = maxf(_beat - delta * 5.0, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var press := DEPTH * 0.5 * (_beat if _ready_now else 0.0)
	var scale := 1.0 + 0.18 * ease(_pop, 0.5)
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * scale)
	var width := size.x
	var face := Rect2(-width * 0.5, -KEY_HEIGHT * 0.5 - DEPTH * 0.5 + press, width, KEY_HEIGHT)
	var base := Rect2(face.position.x, -KEY_HEIGHT * 0.5 + DEPTH * 0.5, width, KEY_HEIGHT)
	var color := READY if _ready_now else BLOCKED
	# Costado de la tecla (más oscuro) y cara.
	_rounded(base, color.darkened(0.55))
	_rounded(face, color)
	if not _ready_now and _progress > 0.0 and _progress < 1.0:
		# Recarga: el verde avanza sobre el rojo.
		var fill := Rect2(face.position, Vector2(face.size.x * _progress, face.size.y))
		_rounded(fill.grow(-3.0), READY.darkened(0.15))
	# Brillo arriba y contorno de tinta.
	draw_line(face.position + Vector2(10.0, 7.0), face.position + Vector2(face.size.x - 10.0, 7.0),
			Color(1.0, 1.0, 1.0, 0.45), 3.0)
	_rounded_outline(face.merge(base), FreneticPalette.INK, 4.0)
	_rounded_outline(face, FreneticPalette.INK, 3.0)
	var font := ThemeDB.fallback_font
	var font_size := 22
	var text_size := font.get_string_size(LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := face.get_center() + Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	draw_string_outline(font, at, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, FreneticPalette.INK)
	draw_string(font, at, LABEL, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, FreneticPalette.CREAM)
	draw_set_transform(Vector2.ZERO)


func _rounded(rect: Rect2, color: Color) -> void:
	var radius := minf(9.0, rect.size.y * 0.5)
	draw_rect(rect.grow_individual(-radius, 0.0, -radius, 0.0), color)
	draw_rect(rect.grow_individual(0.0, -radius, 0.0, -radius), color)
	for corner in [rect.position + Vector2(radius, radius), Vector2(rect.end.x - radius, rect.position.y + radius),
			Vector2(rect.position.x + radius, rect.end.y - radius), rect.end - Vector2(radius, radius)]:
		draw_circle(corner, radius, color)


func _rounded_outline(rect: Rect2, color: Color, width: float) -> void:
	var r := minf(9.0, rect.size.y * 0.5)
	var p := rect.position
	var e := rect.end
	draw_line(p + Vector2(r, 0.0), Vector2(e.x - r, p.y), color, width)
	draw_line(Vector2(p.x + r, e.y), e - Vector2(r, 0.0), color, width)
	draw_line(p + Vector2(0.0, r), Vector2(p.x, e.y - r), color, width)
	draw_line(Vector2(e.x, p.y + r), e - Vector2(0.0, r), color, width)
	draw_arc(p + Vector2(r, r), r, PI, PI * 1.5, 8, color, width)
	draw_arc(Vector2(e.x - r, p.y + r), r, PI * 1.5, TAU, 8, color, width)
	draw_arc(e - Vector2(r, r), r, 0.0, PI * 0.5, 8, color, width)
	draw_arc(Vector2(p.x + r, e.y - r), r, PI * 0.5, PI, 8, color, width)
