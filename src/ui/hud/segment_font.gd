class_name SegmentFont

# Fuente "display digital" de 14 segmentos dibujada con polígonos (sin archivos de
# fuente externos). Cada segmento tiene los extremos en punta, como un reloj LED.
#
#  ── A ──        H  I  J  : diagonales/vertical superiores
# |\  |  /|       G1 G2    : medio izquierdo / derecho
# F H I J B       K  L  M  : diagonales/vertical inferiores
# |  \|/  |
#  G1─ ─G2
# |  /|\  |
# E K L M C
# |/  |  \|
#  ── D ──

# Proporción ancho/alto de cada carácter.
const CHAR_ASPECT := 0.58
const SEGMENTS := {
	"A": [Vector2(0, 0), Vector2(1, 0)],
	"B": [Vector2(1, 0), Vector2(1, 0.5)],
	"C": [Vector2(1, 0.5), Vector2(1, 1)],
	"D": [Vector2(0, 1), Vector2(1, 1)],
	"E": [Vector2(0, 0.5), Vector2(0, 1)],
	"F": [Vector2(0, 0), Vector2(0, 0.5)],
	"G1": [Vector2(0, 0.5), Vector2(0.5, 0.5)],
	"G2": [Vector2(0.5, 0.5), Vector2(1, 0.5)],
	"H": [Vector2(0, 0), Vector2(0.5, 0.5)],
	"I": [Vector2(0.5, 0), Vector2(0.5, 0.5)],
	"J": [Vector2(1, 0), Vector2(0.5, 0.5)],
	"K": [Vector2(0.5, 0.5), Vector2(0, 1)],
	"L": [Vector2(0.5, 0.5), Vector2(0.5, 1)],
	"M": [Vector2(0.5, 0.5), Vector2(1, 1)],
}
const GLYPHS := {
	"0": ["A", "B", "C", "D", "E", "F"],
	"1": ["B", "C"],
	"2": ["A", "B", "G1", "G2", "E", "D"],
	"3": ["A", "B", "G2", "C", "D"],
	"4": ["F", "G1", "G2", "B", "C"],
	"5": ["A", "F", "G1", "G2", "C", "D"],
	"6": ["A", "F", "E", "D", "C", "G1", "G2"],
	"7": ["A", "B", "C"],
	"8": ["A", "B", "C", "D", "E", "F", "G1", "G2"],
	"9": ["A", "B", "C", "D", "F", "G1", "G2"],
	"A": ["A", "B", "C", "E", "F", "G1", "G2"],
	"B": ["A", "B", "C", "D", "G2", "I", "L"],
	"C": ["A", "D", "E", "F"],
	"D": ["A", "B", "C", "D", "I", "L"],
	"E": ["A", "D", "E", "F", "G1"],
	"F": ["A", "E", "F", "G1"],
	"G": ["A", "C", "D", "E", "F", "G2"],
	"H": ["B", "C", "E", "F", "G1", "G2"],
	"I": ["A", "D", "I", "L"],
	"J": ["B", "C", "D", "E"],
	"K": ["E", "F", "G1", "J", "M"],
	"L": ["D", "E", "F"],
	"M": ["B", "C", "E", "F", "H", "J"],
	"N": ["B", "C", "E", "F", "H", "M"],
	"O": ["A", "B", "C", "D", "E", "F"],
	"P": ["A", "B", "E", "F", "G1", "G2"],
	"Q": ["A", "B", "C", "D", "E", "F", "M"],
	"R": ["A", "B", "E", "F", "G1", "G2", "M"],
	"S": ["A", "F", "G1", "G2", "C", "D"],
	"T": ["A", "I", "L"],
	"U": ["B", "C", "D", "E", "F"],
	"V": ["E", "F", "K", "J"],
	"W": ["B", "C", "E", "F", "K", "M"],
	"X": ["H", "J", "K", "M"],
	"Y": ["H", "J", "L"],
	"Z": ["A", "D", "J", "K"],
	"-": ["G1", "G2"],
}


static func has_glyph(character: String) -> bool:
	return GLYPHS.has(character.to_upper()) or character == "." or character == ":"


# Ancho que ocupa un carácter de la altura dada.
static func get_advance(character: String, height: float) -> float:
	match character:
		" ":
			return height * 0.4
		".", ":":
			return height * 0.22
		_:
			return height * CHAR_ASPECT


# Dibuja un carácter centrado en `center`. `thickness` es el grosor del segmento.
# `base_thickness` es el grosor del relleno: los trazos más gruesos (contorno, halo)
# se alargan en consecuencia para envolver los extremos del relleno.
static func draw_glyph(canvas: CanvasItem, character: String, center: Vector2, height: float, thickness: float, color: Color, base_thickness := -1.0) -> void:
	var base := thickness if base_thickness <= 0.0 else base_thickness
	var width := height * CHAR_ASPECT
	var top_left := center - Vector2(width, height) * 0.5
	if character == "." or character == ":":
		var dot := base * 1.1 + (thickness - base)
		var dots: Array = [1.0] if character == "." else [0.3, 0.75]
		for dot_y: float in dots:
			var dot_center := Vector2(center.x, top_left.y + height * dot_y - dot * 0.5)
			canvas.draw_rect(Rect2(dot_center - Vector2(dot, dot) * 0.5, Vector2(dot, dot)), color)
		return
	for segment_name: String in GLYPHS.get(character.to_upper(), []):
		var endpoints: Array = SEGMENTS[segment_name]
		var start: Vector2 = top_left + (endpoints[0] as Vector2) * Vector2(width, height)
		var finish: Vector2 = top_left + (endpoints[1] as Vector2) * Vector2(width, height)
		_draw_segment(canvas, start, finish, thickness, base, color)


# Segmento con extremos en punta (hexágono), separado un poco de sus vecinos.
static func _draw_segment(canvas: CanvasItem, start: Vector2, finish: Vector2, thickness: float, base_thickness: float, color: Color) -> void:
	var direction := (finish - start).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var gap := base_thickness * 0.28 - (thickness - base_thickness) * 0.5
	var a := start + direction * gap
	var b := finish - direction * gap
	var half := thickness * 0.5
	if a.distance_to(b) < base_thickness:
		return
	var points := PackedVector2Array([
		a,
		a + direction * half + normal * half,
		b - direction * half + normal * half,
		b,
		b - direction * half - normal * half,
		a + direction * half - normal * half,
	])
	canvas.draw_colored_polygon(points, color)
