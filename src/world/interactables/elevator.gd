class_name Elevator
extends AnimatableBody2D
## Plataforma de ascensor. Es de un solo sentido (se atraviesa desde abajo), así nunca aplasta.
## El movimiento se mide en beats del Conductor y depende del tipo:
## - LOCAL: sube y baja solo, parando en cada piso.
## - EXPRESS: igual pero solo para en los extremos.
## - CALL: espera quieto; al subirse alguien viaja al otro extremo (y no vuelve a salir hasta
##   que esa persona se baje y suba de nuevo); vacío, vuelve a su base.
## - FAULTY: local con tirones y temblor.

const THICKNESS := 24.0
const CABIN_HEIGHT := 200.0
const CALL_IDLE_BEATS := 6.0
const RIDER_TOLERANCE := 10.0

var spec: OficinasMapData.ElevatorSpec
var style: ArtStyle
## Quien puede viajar (el jugador); lo usan los ascensores a demanda.
var rider: CharacterBody2D
var wait_beats := 4.0
var beats_per_floor := 1.5
var sync_to_beat := true
var floor_height := 420.0

var _legs := []
var _cycle := 1.0
var _clock := 0.0
var _call_at := 0
var _call_to := 0
var _call_start := -1.0
var _call_pending := -1.0
var _call_idle := 0.0
## Tras llegar con alguien encima, no vuelve a salir hasta que se baje y se vuelva a subir.
var _needs_reboard := false
var _speed := 0.0


func setup(p_spec: OficinasMapData.ElevatorSpec, p_style: ArtStyle, params: OficinasParams,
		p_floor_height: float) -> void:
	spec = p_spec
	style = p_style
	wait_beats = params.elevator_wait_beats
	beats_per_floor = params.elevator_beats_per_floor
	sync_to_beat = params.elevator_sync_to_beat
	floor_height = p_floor_height
	sync_to_physics = true
	var shape := RectangleShape2D.new()
	shape.size = Vector2(spec.width, THICKNESS)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = shape.size * 0.5
	collision.one_way_collision = true
	add_child(collision)
	position = Vector2(spec.x, spec.stop_ys[0])
	_build_legs()


## Recorrido de ida y vuelta por las paradas como tramos [desde, hasta, espera, viaje].
func _build_legs() -> void:
	var order := range(spec.stop_ys.size())
	for i in range(spec.stop_ys.size() - 2, 0, -1):
		order.append(i)
	_legs.clear()
	_cycle = 0.0
	for i in order.size():
		var from: float = spec.stop_ys[order[i]]
		var to: float = spec.stop_ys[order[(i + 1) % order.size()]]
		var travel := _travel_beats(from, to)
		_legs.append([from, to, wait_beats, travel])
		_cycle += wait_beats + travel
	_cycle = maxf(_cycle, 0.001)


func _travel_beats(from: float, to: float) -> float:
	var beats := beats_per_floor * absf(to - from) / floor_height
	# Sincronizado: cada viaje dura beats enteros, así también llega en el beat.
	return maxf(1.0, roundf(beats)) if sync_to_beat else maxf(beats, 0.25)


func _beats() -> float:
	return Conductor.beat_position() + spec.phase if sync_to_beat else _clock


func is_moving() -> bool:
	return absf(_speed) > 1.0 or _call_start >= 0.0


func _physics_process(delta: float) -> void:
	_clock += delta * Conductor.params.bpm / 60.0
	var y: float
	if spec.kind == OficinasLayout.Lift.CALL:
		y = _call_y(delta)
	else:
		y = _cycle_y(_beats())
	if spec.kind == OficinasLayout.Lift.FAULTY and absf(y - position.y) > 0.5:
		y += sin(_clock * 40.0) * 2.0
	# No usar constant_linear_velocity: se le sumaría a quien viaja encima.
	_speed = (y - position.y) / maxf(delta, 0.0001)
	position.y = y
	queue_redraw()


func _cycle_y(t: float) -> float:
	var local := fposmod(t, _cycle)
	for leg in _legs:
		if local < leg[2]:
			return leg[0]
		local -= leg[2]
		if local < leg[3]:
			var p: float = local / leg[3]
			if spec.kind == OficinasLayout.Lift.FAULTY:
				# Avance a tirones: acelera y se frena varias veces por tramo.
				p = clampf(p + 0.07 * sin(p * PI * 7.0), 0.0, 1.0)
			return lerpf(leg[0], leg[1], smoothstep(0.0, 1.0, p))
		local -= leg[3]
	return _legs[0][0]


func _call_y(delta: float) -> float:
	var beats := _beats()
	var stops := spec.stop_ys
	if _call_start >= 0.0:
		var travel := _travel_beats(stops[_call_at], stops[_call_to])
		var p := (beats - _call_start) / travel
		if p >= 1.0:
			_call_start = -1.0
			_call_at = _call_to
			_call_idle = 0.0
			_needs_reboard = _rider_on()
			return stops[_call_at]
		return lerpf(stops[_call_at], stops[_call_to], smoothstep(0.0, 1.0, p))
	if _needs_reboard:
		if not _rider_on():
			_needs_reboard = false
		return stops[_call_at]
	if _rider_on():
		_call_idle = 0.0
		if _call_pending < 0.0:
			_call_pending = ceilf(beats) if sync_to_beat else beats + 0.5
		if beats >= _call_pending:
			_depart(1 - _call_at if stops.size() == 2 else (0 if _call_at > 0 else stops.size() - 1), beats)
	else:
		_call_pending = -1.0
		_call_idle += delta * Conductor.params.bpm / 60.0
		if _call_at != 0 and _call_idle > CALL_IDLE_BEATS:
			_depart(0, beats)
	return stops[_call_at]


func _depart(target: int, beats: float) -> void:
	_call_to = target
	_call_start = beats
	_call_pending = -1.0


func _rider_on() -> bool:
	if rider == null or not rider.is_on_floor():
		return false
	var feet := rider.global_position
	return absf(feet.y - global_position.y) < RIDER_TOLERANCE and feet.x > global_position.x \
			and feet.x < global_position.x + spec.width


func _draw() -> void:
	if style == null:
		return
	var w := spec.width
	var outline := maxf(style.outline_width, 2.0)
	# Cable hasta lo alto del hueco.
	draw_line(Vector2(w * 0.5, -CABIN_HEIGHT), Vector2(w * 0.5, spec.shaft_top - position.y), style.outline, 4.0)
	# Cabina: postes y viga superior (sin colisión), luego la plataforma.
	for x in [6.0, w - 18.0]:
		draw_rect(Rect2(x, -CABIN_HEIGHT, 12.0, CABIN_HEIGHT), style.structure_light)
		draw_rect(Rect2(x, -CABIN_HEIGHT, 12.0, CABIN_HEIGHT), style.outline, false, outline * 0.5)
	draw_rect(Rect2(0.0, -CABIN_HEIGHT - 16.0, w, 18.0), style.structure_light)
	draw_rect(Rect2(0.0, -CABIN_HEIGHT - 16.0, w, 18.0), style.outline, false, outline)
	draw_rect(Rect2(0.0, 0.0, w, THICKNESS), style.structure_light)
	draw_rect(Rect2(0.0, 0.0, w, 6.0), style.edge)
	draw_rect(Rect2(0.0, 0.0, w, THICKNESS), style.outline, false, outline)
	# Luz indicadora: color según el tipo; late con el beat mientras viaja.
	var light := _kind_color()
	var glow := Conductor.pulse(6.0) if is_moving() else 0.3
	if spec.kind == OficinasLayout.Lift.FAULTY and fmod(_clock, 1.7) < 0.2:
		glow = 0.0
	draw_circle(Vector2(w * 0.5, -CABIN_HEIGHT - 7.0), 7.0, light.lerp(Color.WHITE, glow * 0.6))
	draw_circle(Vector2(w * 0.5, -CABIN_HEIGHT - 7.0), 16.0 * glow, Color(light, 0.3 * glow))


func _kind_color() -> Color:
	match spec.kind:
		OficinasLayout.Lift.EXPRESS:
			return style.blood.lightened(0.3)
		OficinasLayout.Lift.CALL:
			return InteriorView.EXIT_GREEN
		OficinasLayout.Lift.FAULTY:
			return Color("ff8a1a")
	return style.accent
