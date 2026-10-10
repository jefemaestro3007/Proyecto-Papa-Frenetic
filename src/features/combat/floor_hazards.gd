class_name FloorHazards
extends Node2D
## Peligros del piso que dejan las papas de Bienestar U, con duración en beats:
## - Compras desparramadas (cliente): el piso resbala (`traction_at`).
## - Fuego (muestras en llamas de la promotora): pisarlo hace arder al jugador (`on_fire`).
## También dibuja las llamas sobre el jugador mientras arde. Son pocos y viven poco: se recorren
## todos en cada frame.

enum Kind { SPILL, FIRE }

const SPILL_WIDTH := 150.0
const FIRE_WIDTH := 110.0
const FIRE_HEIGHT := 56.0
## Beats en los que se desvanecen al final.
const FADE_BEATS := 1.5
const PRODUCTS: Array[Color] = [Color("e7b765"), Color("d8433a"), FreneticPalette.CREAM, Color("4fb3c9"),
		Color("8fbf4d")]

var style: ArtStyle
## Jugador al que se le dibujan las llamas mientras arde (`burning`).
var player: Node2D
var burning := false

## Cada peligro: {kind, rect, until (beat), seed}.
var _patches: Array[Dictionary] = []


func _init() -> void:
	z_index = 4


## Compras en el piso con los pies de la papa en `feet` (coordenadas globales, como todo lo que
## recibe este nodo).
func add_spill(feet: Vector2, beats: float) -> void:
	feet = to_local(feet)
	_add(Kind.SPILL, Rect2(feet.x - SPILL_WIDTH * 0.5, feet.y - 16.0, SPILL_WIDTH, 22.0), beats)


## Fuego sobre el piso en `feet`.
func add_fire(feet: Vector2, beats: float) -> void:
	if beats <= 0.0:
		return
	feet = to_local(feet)
	_add(Kind.FIRE, Rect2(feet.x - FIRE_WIDTH * 0.5, feet.y - FIRE_HEIGHT, FIRE_WIDTH, FIRE_HEIGHT + 6.0), beats)


func _add(kind: Kind, rect: Rect2, beats: float) -> void:
	_patches.append({"kind": kind, "rect": rect, "until": Conductor.beat_position() + beats,
			"seed": int(rect.position.x * 7.0 + rect.position.y * 13.0)})


## Tracción del piso en `feet` (1 = normal); `slip` es la de las compras.
func traction_at(feet: Vector2, slip: float) -> float:
	feet = to_local(feet)
	for patch in _patches:
		if patch["kind"] == Kind.SPILL and patch["rect"].has_point(feet):
			return slip
	return 1.0


func on_fire(feet: Vector2) -> bool:
	feet = to_local(feet)
	for patch in _patches:
		if patch["kind"] == Kind.FIRE and patch["rect"].has_point(feet + Vector2(0.0, -2.0)):
			return true
	return false


func count(kind: Kind) -> int:
	return _patches.filter(func(patch: Dictionary) -> bool: return patch["kind"] == kind).size()


func clear() -> void:
	_patches.clear()
	burning = false
	queue_redraw()


func _process(_delta: float) -> void:
	var now := Conductor.beat_position()
	_patches = _patches.filter(func(patch: Dictionary) -> bool: return patch["until"] > now)
	if not _patches.is_empty() or burning:
		queue_redraw()


func _draw() -> void:
	var now := Conductor.beat_position()
	var ink := style.outline if style != null else FreneticPalette.INK
	for patch in _patches:
		var alpha := clampf((patch["until"] - now) / FADE_BEATS, 0.0, 1.0)
		if patch["kind"] == Kind.SPILL:
			_draw_spill(patch, alpha, ink)
		else:
			_draw_fire(patch["rect"], alpha, patch["seed"], ink)
	if burning and is_instance_valid(player):
		var feet := to_local(player.global_position)
		_draw_fire(Rect2(feet.x - 30.0, feet.y - PlayerPrototype.SIZE.y - 10.0, 60.0, PlayerPrototype.SIZE.y), 0.85,
				7, ink)


## Charco (leche y jugo) con productos tirados encima.
func _draw_spill(patch: Dictionary, alpha: float, ink: Color) -> void:
	var rect: Rect2 = patch["rect"]
	var rng := RandomNumberGenerator.new()
	rng.seed = patch["seed"]
	var floor_y := rect.end.y - 6.0
	var puddle := PackedVector2Array()
	for i in 18:
		var angle := TAU * i / 18.0
		var wobble := 1.0 + 0.18 * sin(angle * 3.0 + rng.randf() * 6.0)
		puddle.append(Vector2(rect.get_center().x + cos(angle) * rect.size.x * 0.5 * wobble,
				floor_y + sin(angle) * 10.0 * wobble))
	draw_colored_polygon(puddle, Color(FreneticPalette.CREAM, 0.75 * alpha))
	draw_polyline(puddle + PackedVector2Array([puddle[0]]), Color(ink, 0.6 * alpha), 2.0, true)
	# Brillo que late con el beat: se nota que resbala.
	var shine := 0.35 + 0.4 * Conductor.pulse(6.0)
	draw_line(Vector2(rect.position.x + rect.size.x * 0.3, floor_y - 2.0),
			Vector2(rect.position.x + rect.size.x * 0.5, floor_y - 3.0), Color(1.0, 1.0, 1.0, shine * alpha), 3.0)
	# La bolsa vacía tirada de costado y los productos rodando (latas, frutas, cajas).
	var bag_at := Vector2(rect.position.x + rect.size.x * (0.15 + 0.2 * rng.randf()), floor_y)
	var bag := PackedVector2Array([bag_at + Vector2(-14.0, 0.0), bag_at + Vector2(-16.0, -20.0),
			bag_at + Vector2(14.0, -24.0), bag_at + Vector2(20.0, 0.0)])
	draw_colored_polygon(bag, Color(FreneticPalette.CREAM, alpha))
	draw_polyline(bag + PackedVector2Array([bag[0]]), Color(ink, alpha), 2.0, true)
	for i in 6:
		var x := rect.position.x + rect.size.x * (0.35 + 0.6 * rng.randf())
		var color := PRODUCTS[rng.randi_range(0, PRODUCTS.size() - 1)]
		var size := Vector2(rng.randf_range(16.0, 26.0), rng.randf_range(14.0, 22.0))
		var item := Rect2(Vector2(x - size.x * 0.5, floor_y - size.y + 3.0), size)
		match i % 3:
			0:
				draw_circle(item.get_center(), size.y * 0.5, Color(color, alpha))
				draw_arc(item.get_center(), size.y * 0.5, 0.0, TAU, 14, Color(ink, alpha), 2.0, true)
				draw_line(item.get_center() + Vector2(0.0, -size.y * 0.5), item.get_center() + Vector2(3.0, -size.y * 0.75),
						Color(ink, alpha), 2.0)
			1:
				draw_rect(item, Color(color, alpha))
				draw_rect(Rect2(item.position + Vector2(0.0, size.y * 0.35), Vector2(size.x, size.y * 0.3)),
						Color(FreneticPalette.CREAM, alpha))
				draw_rect(item, Color(ink, alpha), false, 2.0)
			_:
				var can := Rect2(item.position, Vector2(size.y * 0.75, size.y))
				draw_rect(can, Color(color, alpha))
				draw_line(can.position + Vector2(0.0, 3.0), can.position + Vector2(can.size.x, 3.0), Color(ink, alpha), 2.0)
				draw_rect(can, Color(ink, alpha), false, 2.0)


## Llamas que suben y bajan con el beat (amarillo dentro de naranja, contorno de tinta).
func _draw_fire(rect: Rect2, alpha: float, seed: int, ink: Color) -> void:
	var tongues := maxi(3, int(rect.size.x / 22.0))
	var pulse := Conductor.pulse(5.0)
	var flicker := Time.get_ticks_msec() / 70
	for i in tongues:
		var x := rect.position.x + rect.size.x * (i + 0.5) / tongues
		var jitter := float((seed * 31 + i * 17 + flicker) % 7) / 7.0
		var height := rect.size.y * (0.55 + 0.3 * jitter + 0.25 * pulse)
		var half := rect.size.x / tongues * 0.7
		var base := rect.end.y - 6.0
		var outer := PackedVector2Array([Vector2(x - half, base), Vector2(x - half * 0.4, base - height * 0.55),
				Vector2(x, base - height), Vector2(x + half * 0.4, base - height * 0.55), Vector2(x + half, base)])
		draw_colored_polygon(outer, Color("ff7a2f", alpha))
		draw_polyline(outer, Color(ink, alpha), 2.0, true)
		var inner := PackedVector2Array([Vector2(x - half * 0.5, base), Vector2(x, base - height * 0.55),
				Vector2(x + half * 0.5, base)])
		draw_colored_polygon(inner, Color(FreneticPalette.YELLOW, alpha))
