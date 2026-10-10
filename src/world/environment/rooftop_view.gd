@tool
class_name RooftopView
extends Node2D
## Dibuja las azoteas jugables: bloque, borde, baranda, franjas de peligro y salpicaduras.

const LIP := 10.0
const RAIL_HEIGHT := 120.0
const RAIL_POST_SPACING := 110.0
const RAIL_THICKNESS := 12.0
const HAZARD_LENGTH := 160.0
const HAZARD_STRIPE := 22.0

var _roofs: Array[Rect2] = []
var _seed: int = 0


func setup(roofs: Array[Rect2], seed: int) -> void:
	_roofs = roofs
	_seed = seed
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0x5eed
	for roof in _roofs:
		_draw_railing(roof)
	for roof in _roofs:
		_draw_block(roof)
		_draw_hazard(roof)
		_draw_splatter(roof, rng)


func _draw_block(roof: Rect2) -> void:
	draw_rect(roof, FreneticPalette.NAVY)
	# Cara superior y sombra bajo el borde.
	draw_rect(Rect2(roof.position, Vector2(roof.size.x, LIP)), FreneticPalette.CREAM)
	draw_rect(Rect2(roof.position + Vector2(0, LIP), Vector2(roof.size.x, 18.0)), FreneticPalette.NAVY_DARK)
	# Paneles de fachada.
	var x := roof.position.x + 40.0
	while x < roof.end.x - 20.0:
		draw_line(Vector2(x, roof.position.y + 60.0), Vector2(x, roof.position.y + 900.0),
				FreneticPalette.NAVY_DARK, 4.0)
		x += 180.0
	draw_rect(roof, FreneticPalette.INK, false, 4.0)


func _draw_railing(roof: Rect2) -> void:
	var y0 := roof.position.y
	var left := roof.position.x + 24.0
	var right := roof.end.x - 24.0
	if right - left < RAIL_POST_SPACING:
		return
	for rail_y in [y0 - RAIL_HEIGHT, y0 - RAIL_HEIGHT * 0.62, y0 - RAIL_HEIGHT * 0.3]:
		var r := Rect2(left, rail_y, right - left, RAIL_THICKNESS)
		draw_rect(r, FreneticPalette.NAVY_LIGHT)
		draw_rect(r, FreneticPalette.INK, false, 3.0)
	var x := left
	while x <= right:
		var post := Rect2(x - 7.0, y0 - RAIL_HEIGHT - 6.0, 14.0, RAIL_HEIGHT + 6.0)
		draw_rect(post, FreneticPalette.NAVY)
		draw_rect(post, FreneticPalette.INK, false, 3.0)
		x += RAIL_POST_SPACING


## Franjas amarillo/negro en ambos extremos de la azotea (avisan del borde).
func _draw_hazard(roof: Rect2) -> void:
	var y := roof.position.y + LIP + 18.0
	var h := 26.0
	for side in [roof.position.x, roof.end.x - HAZARD_LENGTH]:
		var band := Rect2(side, y, HAZARD_LENGTH, h)
		draw_rect(band, FreneticPalette.YELLOW)
		var band_poly := PackedVector2Array([band.position, Vector2(band.end.x, band.position.y),
				band.end, Vector2(band.position.x, band.end.y)])
		var x: float = side - h
		while x < side + HAZARD_LENGTH:
			var stripe := PackedVector2Array([
				Vector2(x + h, y), Vector2(x + h + HAZARD_STRIPE, y),
				Vector2(x + HAZARD_STRIPE, y + h), Vector2(x, y + h)])
			for clipped in Geometry2D.intersect_polygons(stripe, band_poly):
				draw_colored_polygon(clipped, FreneticPalette.INK)
			x += HAZARD_STRIPE * 2.0
		draw_rect(band, FreneticPalette.INK, false, 3.0)


## Salpicaduras: un núcleo, gotas satélite y chorreones verticales por la fachada.
func _draw_splatter(roof: Rect2, rng: RandomNumberGenerator) -> void:
	var count := rng.randi_range(0, 2)
	for i in count:
		var center := Vector2(rng.randf_range(roof.position.x + 200.0, roof.end.x - 200.0),
				roof.position.y + rng.randf_range(120.0, 380.0))
		var size := rng.randf_range(18.0, 42.0)
		draw_circle(center, size, FreneticPalette.BLOOD)
		for d in rng.randi_range(6, 14):
			var angle := rng.randf() * TAU
			var dist := size * rng.randf_range(1.1, 2.6)
			draw_circle(center + Vector2.from_angle(angle) * dist, rng.randf_range(3.0, size * 0.35),
					FreneticPalette.BLOOD)
		for d in rng.randi_range(2, 5):
			var dx := rng.randf_range(-size, size) * 0.7
			var length := rng.randf_range(40.0, 220.0)
			var width := rng.randf_range(4.0, 10.0)
			var start := center + Vector2(dx, 0.0)
			draw_line(start, start + Vector2(0.0, length), FreneticPalette.BLOOD, width)
			draw_circle(start + Vector2(0.0, length), width * 0.8, FreneticPalette.BLOOD)
