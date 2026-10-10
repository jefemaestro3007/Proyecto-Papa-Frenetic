class_name DashKey
extends Control
## Indicador del dash junto a la papa: un cuadrado sin fondo (solo el contorno) con una flecha
## rellena que apunta hacia donde sale el dash. Todo verde cuando se puede usar (late con el beat);
## al usarlo se pone rojo y el contorno se va recargando de verde alrededor hasta estar listo.
## En el aire (el dash es solo en el suelo) queda verde pero apagado.

const READY := Color("3ddc5a")
const BLOCKED := Color("e3241b")
const LINE := 6.0
## Contorno de tinta por fuera de las líneas de color, para que se lean sobre cualquier fondo.
const INK_LINE := 3.0

var _cooldown := false
var _airborne := false
var _progress := 1.0
var _facing := 1.0
var _beat := 0.0
var _pop := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `cooldown_left` / `cooldown_total` en segundos; `facing` = hacia dónde saldría el dash.
func set_state(cooldown_left: float, cooldown_total: float, airborne: bool, facing: float) -> void:
	var was_cooldown := _cooldown
	_cooldown = cooldown_left > 0.0
	_airborne = airborne
	_facing = signf(facing) if facing != 0.0 else 1.0
	_progress = 1.0 - cooldown_left / cooldown_total if cooldown_total > 0.0 else 1.0
	if was_cooldown and not _cooldown:
		_pop = 1.0


func on_beat(pulse: float) -> void:
	_beat = pulse


func _process(delta: float) -> void:
	_beat = maxf(_beat - delta * 5.0, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var ready := not _cooldown
	var bounce := 1.0 + (0.06 * _beat if ready and not _airborne else 0.0) + 0.2 * ease(_pop, 0.5)
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * bounce)
	var half := minf(size.x, size.y) * 0.5 - LINE
	var square := _square(half)
	var color := READY if ready else BLOCKED
	if ready and _airborne:
		color = Color(READY.darkened(0.35), 0.75)
	# Contorno: tinta por fuera, el color encima y, en recarga, el verde avanzando alrededor.
	draw_polyline(square, FreneticPalette.INK, LINE + INK_LINE * 2.0, true)
	draw_polyline(square, color, LINE, true)
	if _cooldown and _progress > 0.0:
		draw_polyline(_partial(square, _progress), READY, LINE, true)
	# Flecha rellena hacia donde sale el dash.
	var arrow := _arrow(half * 0.62)
	draw_colored_polygon(arrow, color)
	var closed := arrow.duplicate()
	closed.append(arrow[0])
	draw_polyline(closed, FreneticPalette.INK, INK_LINE, true)
	draw_set_transform(Vector2.ZERO)


## Cuadrado cerrado empezando arriba a la izquierda, en sentido horario.
func _square(half: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half),
			Vector2(-half, half), Vector2(-half, -half)])


## Tramo inicial del contorno que representa `fraction` del perímetro.
func _partial(points: PackedVector2Array, fraction: float) -> PackedVector2Array:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var remaining := total * clampf(fraction, 0.0, 1.0)
	var out := PackedVector2Array([points[0]])
	for i in points.size() - 1:
		var length := points[i].distance_to(points[i + 1])
		if remaining >= length:
			out.append(points[i + 1])
			remaining -= length
		else:
			out.append(points[i].lerp(points[i + 1], remaining / length))
			break
	return out


## Flecha horizontal (cuerpo + punta) que apunta hacia `_facing`.
func _arrow(reach: float) -> PackedVector2Array:
	var shaft := reach * 0.28
	var head := reach * 0.62
	var neck := reach * 0.15
	var points := PackedVector2Array([
		Vector2(-reach, -shaft), Vector2(neck, -shaft), Vector2(neck, -head),
		Vector2(reach, 0.0), Vector2(neck, head), Vector2(neck, shaft), Vector2(-reach, shaft),
	])
	for i in points.size():
		points[i].x *= _facing
	return points
