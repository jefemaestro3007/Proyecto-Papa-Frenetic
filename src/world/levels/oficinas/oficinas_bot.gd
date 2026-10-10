class_name OficinasBot
extends RefCounted
## Recorre el edificio hasta la salida siguiendo el camino más corto del grafo, usando los
## controles reales del jugador. Sirve de recorrido automático y, sobre todo, de prueba de que
## la física coincide con el grafo (el test de integración lo usa en muchas seeds).
## Con la variable de entorno BOT_DEBUG imprime cada cambio de nodo y el siguiente paso.

const Cell := OficinasLayout.Cell
const Link := OficinasLayout.Link
const ARRIVE := 14.0
const GAP_JUMP_DISTANCE := 70.0
const STUCK_SECONDS := 10.0
const LIFT_LOOKAHEAD := 60.0
## Distancia mínima al borde de un hueco mientras se espera (la cápsula no debe sobresalir).
const EDGE_CLEARANCE := 30.0

var data: OficinasMapData
var layout: OficinasLayout
## Para depurar: qué está haciendo.
var status := ""

var _path := []
var _path_from := Vector2i(-9, -9)
var _intent := 0
## El último paso planeado fue un ascensor: mientras viaja, quedarse quieto en la cabina.
var _riding := false
var _since_progress := 0.0
var _last_node := Vector2i(-9, -9)


func _init(p_data: OficinasMapData) -> void:
	data = p_data
	layout = p_data.layout


func step(player: PlayerPrototype, elevators: Array[Elevator], delta: float) -> void:
	for action in ["ui_left", "ui_right", "ui_accept", "ui_down", "ui_up"]:
		Input.action_release(action)
	var feet := player.global_position
	var node := data.node_at(feet) if player.is_on_floor() else Vector2i(-1, -1)
	if OS.get_environment("BOT_TRACE") != "" and Engine.get_physics_frames() % 30 == 0:
		var lifts := ""
		for e in elevators:
			if absf(e.position.x + e.spec.width * 0.5 - feet.x) < data.module_width * 0.5:
				lifts += " [k%d y=%.0f %s]" % [e.spec.kind, e.position.y, e.spec.stop_ys]
		print("T%d feet=%v on_floor=%s node=%v %s%s" % [Engine.get_physics_frames(), feet.round(), player.is_on_floor(), node, status, lifts])
	if node.x < 0 or layout.is_void(node.x, node.y) or layout.is_sealed(node.x, node.y):
		# En el aire o en una rampa: mantener la intención. Viajando en ascensor: quieto.
		_press(0 if _riding else _intent)
		return
	_track_progress(node, delta, player)
	if node != _path_from:
		_path = layout.shortest_path(node, layout.end)
		_path_from = node
		if OS.get_environment("BOT_DEBUG") != "":
			print("BOT %v -> %s x=%d" % [node, str(_path[1]) if _path.size() > 1 else "fin", roundi(feet.x)])

	var target_x := data.goal.get_center().x
	var wants_fall := false
	var drop_gap := -1
	_riding = false
	if _path.size() > 1:
		var next: Vector2i = _path[1][0]
		var link: int = _path[1][1]
		match link:
			Link.WALK:
				target_x = _walk_target(node, next)
				status = "caminar a %v" % next
			Link.STAIRS:
				target_x = _stairs_target(node, feet)
				status = "escalera"
			Link.FALL:
				wants_fall = true
				if layout.cell(node.x, node.y) == Cell.GAP and next.y == node.y:
					target_x = _center(node.y)
					drop_gap = node.y
				else:
					target_x = _center(next.y)
				status = "caer a %v" % next
			Link.LIFT:
				target_x = _center(node.y)
				_riding = true
				status = "ascensor a %v" % next
	else:
		status = "salida"

	var dx := target_x - feet.x
	_intent = 0 if absf(dx) < ARRIVE else int(signf(dx))
	if _intent != 0 and not wants_fall and _must_wait_for_lift(node, feet, target_x, elevators):
		status += " (espera ascensor)"
		# Si estamos sobre otra plataforma, esperar en el borde de la losa (solo existe en el
		# piso más bajo de ese ascensor) para que no nos lleve.
		var on_pit := layout.cell(node.x, node.y) == Cell.SHAFT and layout.elevator_at(node.x, node.y).low == node.x
		if on_pit and node.y + _intent >= 0 and node.y + _intent < layout.modules:
			var boundary := (node.y + (1 if _intent > 0 else 0)) * data.module_width
			var spot := boundary - _intent * 8.0
			_intent = 0 if absf(spot - feet.x) < 4.0 else int(signf(spot - feet.x))
		else:
			var boundary := (floori(feet.x / data.module_width) + (1 if _intent > 0 else 0)) * data.module_width
			# Si la inercia nos dejó sobre el borde, retroceder un poco.
			_intent = -_intent if absf(boundary - feet.x) < EDGE_CLEARANCE else 0
	_press(_intent)
	if _intent != 0 and _gap_ahead(node, feet, drop_gap):
		Input.action_press("ui_accept")


func _center(column: int) -> float:
	return (column + 0.5) * data.module_width


## Al entrar a una escalera por el lado del pie, quedarse antes del pie (si no, ya se sube).
func _walk_target(node: Vector2i, next: Vector2i) -> float:
	if layout.cell(next.x, next.y) == Cell.STAIR_LOW:
		var d := layout.stair_dirs[layout.index(next.x, next.y)]
		if signi(next.y - node.y) == d:
			return _foot_x(next) - d * 40.0
	return _center(next.y)


func _foot_x(node: Vector2i) -> float:
	var d := layout.stair_dirs[layout.index(node.x, node.y)]
	return node.y * data.module_width + (OficinasGenerator.STAIR_FOOT if d > 0 else data.module_width - OficinasGenerator.STAIR_FOOT)


## Para subir hay que tomar la rampa desde su pie: si estamos del lado alto, primero retroceder.
func _stairs_target(node: Vector2i, feet: Vector2) -> float:
	var d := layout.stair_dirs[layout.index(node.x, node.y)]
	var foot_x := _foot_x(node)
	if (feet.x - foot_x) * d > -10.0:
		if absf(feet.x - (foot_x - d * 40.0)) < ARRIVE:
			return feet.x + d * 400.0
		return foot_x - d * 40.0
	return feet.x + d * 400.0


## No entrar al hueco de un ascensor si la plataforma no está en este piso, salvo que caer
## sea justamente el plan (un ascensor a demanda que quedó abajo). Solo cuenta un hueco que
## el destino obliga a cruzar o a ocupar, y solo cuando ya estamos cerca de su borde.
func _must_wait_for_lift(node: Vector2i, feet: Vector2, target_x: float, elevators: Array[Elevator]) -> bool:
	var column := -1
	var c := floori(feet.x / data.module_width)
	var last := clampi(floori(target_x / data.module_width), 0, layout.modules - 1)
	while true:
		if c != node.y and c >= 0 and c < layout.modules and layout.cell(node.x, c) == Cell.SHAFT:
			column = c
			break
		if c == last:
			break
		c += _intent
	if column < 0:
		return false
	# El hueco tiene losa en este piso (es su parada más baja): se puede entrar sin esperar.
	if layout.elevator_at(node.x, column).low == node.x:
		return false
	# Si estamos sobre una plataforma sin losa debajo, esperar no sirve (nos llevaría):
	# entrar igual; caer en el otro hueco lleva al mismo ascensor.
	if layout.cell(node.x, node.y) == Cell.SHAFT and layout.elevator_at(node.x, node.y).low != node.x:
		return false
	var boundary := (column if _intent > 0 else column + 1) * data.module_width
	if absf(boundary - feet.x) > LIFT_LOOKAHEAD:
		return false
	var surface := data.surface_y(node.x)
	for elevator in elevators:
		# Puede haber varios ascensores en la misma columna, en tramos de pisos distintos.
		if elevator.spec.column != column or surface > elevator.spec.shaft_bottom + 1.0 \
				or surface < elevator.spec.stop_ys[elevator.spec.stop_ys.size() - 1] - 1.0:
			continue
		if absf(elevator.position.y - surface) < 6.0:
			return false
		var below := elevator.position.y > surface
		return not (elevator.spec.kind == OficinasLayout.Lift.CALL and below)
	return false


## Hay un hueco pequeño adelante en este piso: saltarlo al llegar a su borde (salvo el hueco
## por el que justamente se planea caer).
func _gap_ahead(node: Vector2i, feet: Vector2, drop_gap: int) -> bool:
	for c in [node.y, node.y + _intent]:
		if c == drop_gap or c < 0 or c >= layout.modules or layout.cell(node.x, c) != Cell.GAP:
			continue
		var center := _center(c)
		var edge := center - _intent * OficinasMapData.GAP_WIDTH * 0.5
		var distance := (edge - feet.x) * _intent
		if distance > 0.0 and distance < GAP_JUMP_DISTANCE:
			return true
	return false


func _press(direction: int) -> void:
	if direction < 0:
		Input.action_press("ui_left")
	elif direction > 0:
		Input.action_press("ui_right")


## Si no hay progreso en un rato, un salto suele destrabar (p. ej. contra un borde).
func _track_progress(node: Vector2i, delta: float, player: PlayerPrototype) -> void:
	if node != _last_node:
		_last_node = node
		_since_progress = 0.0
		return
	_since_progress += delta
	if _since_progress > STUCK_SECONDS and player.is_on_floor():
		Input.action_press("ui_accept")
		_since_progress = STUCK_SECONDS * 0.5
