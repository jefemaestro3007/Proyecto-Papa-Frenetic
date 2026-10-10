class_name Elevator
extends Node2D
## Ascensor de fondo, cerrado. Se llama con W frente a su puerta: la cabina llega (como mucho
## en `call_seconds`) y las puertas se abren en el beat. Adentro, W/S eligen hacia dónde ir
## (mantener sigue de piso en piso; el expreso va directo al otro extremo). El viaje completo
## dura como mucho `trip_seconds`. El personaje viaja como pasajero (lo mueve la zona).
## Tipos: local, expreso, de servicio (tarda más en llegar) y averiado (sacudidas, luz que falla).

signal arrived(floor: int)

const DOOR_WIDTH := 130.0
const DOOR_HEIGHT := 200.0
const CABIN_WIDTH := 150.0
const CABIN_HEIGHT := 220.0
const OPEN_SECONDS := 0.18

var spec: OficinasMapData.ElevatorSpec
var style: ArtStyle
var data: OficinasMapData
var call_seconds := 1.2
var trip_seconds := 1.2
var sync_to_beat := true

## Piso donde está (o hacia donde va) la cabina.
var cabin_floor := 0
## Y de la superficie de la cabina (para dibujarla y mover al pasajero).
var cabin_y := 0.0
var riding := false

var _from_y := 0.0
var _to_y := 0.0
var _move_time := 0.0
var _move_duration := 0.0
var _open_floor := -1
var _open_amount := 0.0
var _open_at_beat := -1
var _pending_open := -1
## Lo que se vio en el último dibujo (para redibujar solo si cambia).
var _look := []


func setup(p_spec: OficinasMapData.ElevatorSpec, p_data: OficinasMapData, p_style: ArtStyle, params: OficinasParams) -> void:
	spec = p_spec
	data = p_data
	style = p_style
	call_seconds = params.elevator_call_seconds
	trip_seconds = params.elevator_trip_seconds
	sync_to_beat = params.elevator_sync_to_beat
	cabin_floor = spec.stops[0]
	cabin_y = data.surface_y(cabin_floor)
	_from_y = cabin_y
	_to_y = cabin_y


func is_moving() -> bool:
	return _move_time < _move_duration


func is_open_at(floor: int) -> bool:
	return _open_floor == floor and _open_amount > 0.9


func door_x() -> float:
	return spec.x


## Siguiente parada en la dirección dada (o -1). El expreso va al otro extremo.
func next_stop(from_floor: int, direction: int) -> int:
	var best := -1
	for stop in spec.stops:
		if direction > 0 and stop > from_floor and (best < 0 or stop < best):
			best = stop
		elif direction < 0 and stop < from_floor and (best < 0 or stop > best):
			best = stop
	return best


## Llamada desde un piso: la cabina viene (si no está) y abre las puertas en el beat.
func call_to(floor: int) -> void:
	if not spec.stops.has(floor):
		return
	if cabin_floor == floor and not is_moving():
		_schedule_open(floor)
		return
	_close()
	var floors := absi(floor - cabin_floor)
	var duration := minf(call_seconds, 0.25 + floors * 0.2)
	if spec.kind == OficinasLayout.Lift.CALL:
		duration = call_seconds
	_move(floor, duration)
	_pending_open = floor


## Viaje con pasajero hacia `floor`; dura lo proporcional dentro de `trip_seconds`.
func ride_to(floor: int) -> float:
	_close()
	var span := maxi(1, spec.high - spec.low)
	var duration := maxf(0.25, trip_seconds * absi(floor - cabin_floor) / span)
	_move(floor, duration)
	_pending_open = -1
	return duration


func open_here() -> void:
	_schedule_open(cabin_floor)


func close_doors() -> void:
	_close()


func _move(floor: int, duration: float) -> void:
	_from_y = cabin_y
	_to_y = data.surface_y(floor)
	cabin_floor = floor
	_move_time = 0.0
	_move_duration = duration


func _schedule_open(floor: int) -> void:
	# Ya pedida para este piso: no reprogramar (si no, nunca llegaría el beat).
	if _open_floor == floor:
		return
	_open_floor = floor
	_open_at_beat = Conductor.beat_index() + 1 if sync_to_beat else -1


func _close() -> void:
	_open_floor = -1
	_open_at_beat = -1


func _process(delta: float) -> void:
	if is_moving():
		_move_time += delta
		var p := clampf(_move_time / _move_duration, 0.0, 1.0)
		cabin_y = lerpf(_from_y, _to_y, p * p * (3.0 - 2.0 * p))
		if spec.kind == OficinasLayout.Lift.FAULTY and p < 1.0:
			cabin_y += sin(_move_time * 70.0) * 3.0
		if p >= 1.0:
			cabin_y = _to_y
			arrived.emit(cabin_floor)
			if _pending_open >= 0:
				_schedule_open(_pending_open)
				_pending_open = -1
	var opening := _open_floor >= 0 and (_open_at_beat < 0 or Conductor.beat_index() >= _open_at_beat)
	_open_amount = move_toward(_open_amount, 1.0 if opening else 0.0, delta / OPEN_SECONDS)
	# Dibuja todas sus paradas (de punta a punta del edificio): solo se redibuja si cambió algo.
	var look := [cabin_floor, is_moving(), _open_floor, _open_amount, riding, cabin_y if riding else 0.0,
			_faulty_dark()]
	if look != _look:
		_look = look
		queue_redraw()


## La luz del averiado falla un rato cada 1,7 s.
func _faulty_dark() -> bool:
	return spec.kind == OficinasLayout.Lift.FAULTY and fmod(Time.get_ticks_msec() / 1000.0, 1.7) < 0.15


func _draw() -> void:
	if style == null or spec == null:
		return
	var outline := maxf(style.outline_width * 0.7, 2.0)
	var faulty_dark := _faulty_dark()
	for stop in spec.stops:
		var floor_y := data.surface_y(stop)
		var door := Rect2(spec.x - DOOR_WIDTH * 0.5, floor_y - DOOR_HEIGHT, DOOR_WIDTH, DOOR_HEIGHT)
		var open := _open_amount if stop == _open_floor else 0.0
		draw_rect(door.grow(12.0), style.structure_light)
		draw_rect(door, style.window_lit.darkened(0.5) if not faulty_dark else style.outline)
		var half := door.size.x * 0.5 * (1.0 - open)
		for side in [0, 1]:
			var panel := Rect2(door.position.x if side == 0 else door.end.x - half, door.position.y, half, door.size.y)
			if panel.size.x > 0.5:
				draw_rect(panel, style.furniture.lightened(0.15))
				draw_rect(panel, style.outline, false, outline * 0.6)
		draw_rect(door.grow(12.0), style.outline, false, outline)
		# Indicador: encendido si la cabina está en ese piso; botón de llamada al costado.
		var light := Rect2(spec.x - 26.0, door.position.y - 40.0, 52.0, 20.0)
		var here := cabin_floor == stop and not is_moving()
		draw_rect(light, style.outline)
		draw_rect(light.grow(-4.0), _kind_color() if here else style.structure_dark)
		draw_rect(Rect2(door.end.x + 18.0, floor_y - 110.0, 12.0, 22.0), style.structure_dark)
		draw_circle(Vector2(door.end.x + 24.0, floor_y - 99.0), 4.0, _kind_color())
	if riding:
		# Cabina cerrada alrededor del pasajero.
		var cabin := Rect2(spec.x - CABIN_WIDTH * 0.5, cabin_y - CABIN_HEIGHT, CABIN_WIDTH, CABIN_HEIGHT)
		draw_rect(cabin.grow(10.0), style.structure_light)
		draw_rect(cabin, style.wall_paper.darkened(0.25) if not faulty_dark else style.outline)
		draw_rect(Rect2(cabin.position.x, cabin.end.y - 8.0, cabin.size.x, 8.0), style.edge)
		draw_rect(Rect2(cabin.get_center().x - 30.0, cabin.position.y + 6.0, 60.0, 6.0), style.window_lit)
		draw_rect(cabin.grow(10.0), style.outline, false, outline)


func cabin_rect() -> Rect2:
	return Rect2(spec.x - CABIN_WIDTH * 0.5, cabin_y - CABIN_HEIGHT, CABIN_WIDTH, CABIN_HEIGHT).grow(14.0)


func _kind_color() -> Color:
	match spec.kind:
		OficinasLayout.Lift.EXPRESS:
			return style.blood.lightened(0.3)
		OficinasLayout.Lift.CALL:
			return InteriorView.EXIT_GREEN
		OficinasLayout.Lift.FAULTY:
			return Color("ff8a1a")
	return style.accent
