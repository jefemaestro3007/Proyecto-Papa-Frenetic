class_name MenacingText
extends Control

# Texto "amenazante" estilo manga (ゴゴゴ / ドドド): cada carácter queda fuera de la
# línea base (unos más arriba, otros más abajo), inclinado, y tiembla "a saltos"
# dentro de un área pequeña alrededor de su posición, como fotogramas de animé.
# La línea completa puede ir en diagonal y los caracteres pueden aparecer uno a uno.

const REVEAL_POP_SECONDS := 0.12
const REVEAL_POP_SCALE := 2.3

@export var text := "":
	set(value):
		text = value
		queue_redraw()
@export var font_size := 64
@export var fill_color := Color("d9963f")
@export var highlight_color := Color("ffe2a8")
@export var outline_color := Color("2a1208")
@export var outline_size := 16
# Desplazamiento vertical máximo de cada carácter respecto a la línea base.
@export var stagger := 18.0
@export var tilt_degrees := 9.0
# Ángulo de toda la línea de texto (negativo = sube hacia la derecha).
@export var line_angle_degrees := 0.0
# Radio del temblor y cuántas veces por segundo se recoloca cada carácter.
@export var jitter := 4.0
@export var jitter_rate := 20.0
@export var letter_spacing := 3.0
# Grosor e inclinación de la fuente para que se sienta desesperada.
@export var embolden := 1.1
@export var slant := 0.22
# Modo "display digital": dibuja cada carácter con segmentos (SegmentFont) en vez de la fuente.
@export var segment_mode := false
# Grosor del segmento relativo a la altura y halo luminoso tipo LED.
@export var segment_thickness_ratio := 0.11
@export var glow_color := Color(1.0, 0.1, 0.05, 0.22)

# Multiplicador del temblor (el HUD lo sube en cada beat).
var shake_strength := 1.0
# Escala general y opacidad (para aparecer/desaparecer).
var text_scale := 1.0
var opacity := 1.0
var _font: Font
var _jitter_offsets: Array[Vector2] = []
var _jitter_timer := 0.0
var _revealed_count := -1
var _reveal_ages: Array[float] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = _build_font()


# Fuente gruesa e inclinada a partir de la fuente por defecto; se puede sustituir
# por una fuente propia (con licencia declarada) asignando set_font().
func _build_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = ThemeDB.fallback_font
	variation.variation_embolden = embolden
	variation.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(-slant, 1.0), Vector2.ZERO)
	return variation


func set_font(font: Font) -> void:
	_font = font
	queue_redraw()


# -1 muestra todo; 0..n muestra los primeros n caracteres (cada nuevo entra con un golpe).
func set_revealed_count(count: int) -> void:
	if count < 0:
		_revealed_count = -1
		return
	_reveal_ages.resize(text.length())
	# Solo los caracteres recién revelados reinician su animación de entrada.
	var first_new := 0 if _revealed_count < 0 or count < _revealed_count else _revealed_count
	for index in range(first_new, mini(count, text.length())):
		_reveal_ages[index] = 0.0
	_revealed_count = count
	queue_redraw()


func get_revealed_count() -> int:
	return text.length() if _revealed_count < 0 else _revealed_count


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_jitter_timer -= delta
	if _jitter_timer <= 0.0:
		_jitter_timer = 1.0 / jitter_rate
		_refresh_jitter()
	for index in range(_reveal_ages.size()):
		_reveal_ages[index] += delta
	queue_redraw()


func _refresh_jitter() -> void:
	_jitter_offsets.resize(text.length())
	for index in range(text.length()):
		_jitter_offsets[index] = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * jitter * shake_strength


func _draw() -> void:
	if (_font == null and not segment_mode) or text.is_empty() or opacity <= 0.0:
		return
	var advances: Array[float] = []
	var total_width := 0.0
	for index in range(text.length()):
		var advance := SegmentFont.get_advance(text[index], float(font_size)) if segment_mode else _font.get_char_size(text.unicode_at(index), font_size).x
		advances.append(advance)
		total_width += advance + letter_spacing
	total_width -= letter_spacing

	var line_angle := deg_to_rad(line_angle_degrees)
	var center := size * 0.5
	var x := -total_width * 0.5
	var shown := get_revealed_count()
	for index in range(text.length()):
		var character := text[index]
		var advance: float = advances[index]
		if character != " " and index < shown:
			# Desfase fijo por carácter (siempre el mismo) + temblor a saltos.
			var local := Vector2(x + advance * 0.5, _hash(index, 1) * stagger) * text_scale
			var shake: Vector2 = _jitter_offsets[index] if index < _jitter_offsets.size() else Vector2.ZERO
			var char_scale := text_scale
			var alpha := opacity
			if index < _reveal_ages.size() and _revealed_count >= 0:
				var pop := clampf(_reveal_ages[index] / REVEAL_POP_SECONDS, 0.0, 1.0)
				char_scale *= lerpf(REVEAL_POP_SCALE, 1.0, 1.0 - pow(1.0 - pop, 3.0))
				alpha *= pop
			var tilt := line_angle + deg_to_rad(_hash(index, 2) * tilt_degrees)
			draw_set_transform(center + local.rotated(line_angle) + shake, tilt, Vector2.ONE * char_scale)
			if segment_mode:
				_draw_segment_char(character, alpha)
			else:
				var origin := Vector2(-advance * 0.5, float(font_size) * 0.35)
				draw_char_outline(_font, origin, character, font_size, outline_size, Color(outline_color, outline_color.a * alpha))
				draw_char(_font, origin, character, font_size, Color(fill_color, fill_color.a * alpha))
				# Brillo desplazado: da el aspecto metálico/dorado de las onomatopeyas.
				draw_char(_font, origin + Vector2(-1.5, -2.5), character, font_size, Color(highlight_color, 0.45 * alpha))
		x += advance + letter_spacing
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Valor pseudoaleatorio estable en [-1, 1] para cada carácter.
func _hash(index: int, channel: int) -> float:
	var value := sin(float(index) * 12.9898 + float(channel) * 78.233) * 43758.5453
	return (value - floorf(value)) * 2.0 - 1.0


# Carácter de segmentos: halo, contorno oscuro, relleno y un brillo interior.
func _draw_segment_char(character: String, alpha: float) -> void:
	var height := float(font_size)
	var thickness := height * segment_thickness_ratio
	SegmentFont.draw_glyph(self, character, Vector2.ZERO, height, thickness + outline_size * 1.3, Color(glow_color, glow_color.a * alpha), thickness)
	SegmentFont.draw_glyph(self, character, Vector2.ZERO, height, thickness + outline_size * 0.5, Color(outline_color, outline_color.a * alpha), thickness)
	SegmentFont.draw_glyph(self, character, Vector2.ZERO, height, thickness, Color(fill_color, fill_color.a * alpha))
	SegmentFont.draw_glyph(self, character, Vector2.ZERO, height, thickness * 0.35, Color(highlight_color, 0.55 * alpha), thickness)
