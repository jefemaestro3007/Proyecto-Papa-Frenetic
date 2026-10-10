class_name OficinasBot
extends RefCounted
## Recorre el edificio hasta la salida siguiendo el plan del espacio de estados (lugar × llaves),
## usando los controles reales del jugador: camina, salta huecos, usa escaleras (W/S), llama y
## maneja ascensores, entra y sale por puertas al fondo y recoge llaves (también dentro de
## habitaciones). Es el recorrido automático y, sobre todo, la prueba de que la física coincide
## con el grafo. Con la variable de entorno BOT_DEBUG imprime cada decisión nueva.

const Cell := OficinasLayout.Cell
const Link := OficinasLayout.Link
const ARRIVE := 14.0
const GAP_JUMP_DISTANCE := 70.0
const STUCK_SECONDS := 10.0

var data: OficinasMapData
var layout: OficinasLayout
## Para depurar: qué está haciendo.
var status := ""

var _intent := 0
var _lift_target := -1
var _exit_node := Vector2i(-1, -1)
var _since_progress := 0.0
var _last_node := Vector2i(-9, -9)
var _last_status := ""


func _init(p_data: OficinasMapData) -> void:
	data = p_data
	layout = p_data.layout


func step(level, delta: float) -> void:
	for action in ["move_left", "move_right", "jump", "move_down", "move_up"]:
		Input.action_release(action)
	var player: PlayerPrototype = level.player()
	var feet := player.global_position
	match level.current_state():
		0:  # FREE
			pass
		2:  # CALLING: quieto frente a la puerta
			status = "esperando ascensor"
			return
		3:  # RIDING
			_ride(level.lift_in_use())
			return
		_:
			return
	if not player.is_on_floor():
		_press(_intent)
		return
	var area: int = level.current_area()
	if area >= 0:
		_in_area(level, area, feet)
		return
	var node := data.node_at(feet)
	if node.x < 0:
		_press(_intent)
		return
	_track_progress(node, delta)
	var keys: int = level.keys_held
	var target_x := data.goal.get_center().x
	var action := ""
	var drop_gap := -1
	var wants_fall := false

	var pending := _pending_key(node, keys)
	if pending != null:
		if pending.door >= 0:
			target_x = data.depth_doors[pending.door].rect.get_center().x
			action = "up"
			_exit_node = node
			status = "entrar a buscar llave %d" % pending.id
		else:
			target_x = data.keys[_key_index(pending.id)].position.x
			status = "recoger llave %d" % pending.id
	else:
		var plan := layout.plan(node, keys)
		if plan.size() > 1:
			var next: Vector2i = plan[1][0]
			match plan[1][2]:
				Link.WALK:
					target_x = data.module_center(next.y)
					status = "caminar a %v" % next
				Link.STAIRS:
					var stair := _stair_between(node, next)
					if next.x > node.x:
						target_x = stair.foot.x
						action = "up"
					else:
						target_x = stair.top.x
						action = "down"
					status = "escalera a %v" % next
				Link.LIFT:
					target_x = data.module_center(node.y)
					action = "up"
					_lift_target = next.x
					status = "ascensor a %v" % next
				Link.FALL:
					wants_fall = true
					if layout.cell(node.x, node.y) == Cell.GAP and next.y == node.y:
						target_x = data.module_center(node.y)
						drop_gap = node.y
					else:
						target_x = data.module_center(next.y)
					status = "caer a %v" % next
				Link.DEPTH:
					target_x = data.module_center(node.y)
					action = "up"
					_exit_node = next
					status = "pasillo al fondo a %v" % next
		else:
			status = "salida"
	_debug()
	var dx := target_x - feet.x
	_intent = 0 if absf(dx) < ARRIVE else int(signf(dx))
	_press(_intent)
	if _intent == 0 and action != "":
		_tap("move_up" if action == "up" else "move_down")
	# Al caer a propósito no se salta el hueco planeado; los demás sí.
	if _intent != 0 and _gap_ahead(node, feet, drop_gap if wants_fall else -1):
		Input.action_press("jump")


## Dentro de un área: recoger la llave si está acá, después salir por la puerta que lleva
## al lugar planeado (o a la que deje más cerca de la salida).
func _in_area(level, area_index: int, feet: Vector2) -> void:
	var area := data.areas[area_index]
	var keys: int = level.keys_held
	var target_x := area.doors[0].x
	for key in data.keys:
		if key.area == area_index and keys & (1 << key.id) == 0:
			target_x = key.position.x
			status = "llave en habitación"
			_walk_and(feet, target_x, "")
			return
	var best := INF
	for door in area.doors:
		var spec := data.depth_doors[door.depth_door]
		var node := Vector2i(spec.floor, spec.module)
		var length := 0.0 if node == _exit_node else float(layout.plan(node, keys).size())
		if length < best and (length > 0.0 or node == _exit_node):
			best = length
			target_x = door.x
	status = "salir del área"
	_debug()
	_walk_and(feet, target_x, "up")


func _walk_and(feet: Vector2, target_x: float, action: String) -> void:
	var dx := target_x - feet.x
	_intent = 0 if absf(dx) < ARRIVE else int(signf(dx))
	_press(_intent)
	if _intent == 0 and action != "":
		_tap("move_up")


## En la cabina: W/S hasta el piso planeado; ahí, salir hacia donde sigue el plan.
func _ride(lift: Elevator) -> void:
	if lift == null:
		return
	if lift.is_moving():
		if _lift_target >= 0 and lift.cabin_floor != _lift_target:
			Input.action_press("move_up" if _lift_target > lift.cabin_floor else "move_down")
		return
	if _lift_target >= 0 and lift.cabin_floor != _lift_target:
		Input.action_press("move_up" if _lift_target > lift.cabin_floor else "move_down")
		status = "viajando a piso %d" % _lift_target
		return
	status = "bajando del ascensor"
	var exit := 1
	var plan := layout.plan(Vector2i(lift.cabin_floor, lift.spec.column), 0)
	if plan.size() > 1 and plan[1][0].x == lift.cabin_floor:
		exit = signi(plan[1][0].y - lift.spec.column)
		if exit == 0:
			exit = 1
	_press(exit)


func _pending_key(node: Vector2i, keys: int) -> OficinasLayout.KeyItem:
	for key in layout.keys:
		if key.node == node and keys & (1 << key.id) == 0:
			return key
	return null


func _key_index(key_id: int) -> int:
	for i in data.keys.size():
		if data.keys[i].id == key_id:
			return i
	return 0


func _stair_between(a: Vector2i, b: Vector2i) -> OficinasMapData.Stair:
	var low := mini(a.x, b.x)
	for stair in data.stairs:
		if stair.floor == low and stair.column == a.y:
			return stair
	return data.stairs[0]


## Hay un hueco pequeño adelante en este piso: saltarlo al llegar a su borde (salvo el hueco
## por el que justamente se planea caer).
func _gap_ahead(node: Vector2i, feet: Vector2, drop_gap: int) -> bool:
	for c in [node.y, node.y + _intent]:
		if c == drop_gap or c < 0 or c >= layout.modules or layout.cell(node.x, c) != Cell.GAP:
			continue
		var center := data.module_center(c)
		var edge := center - _intent * OficinasMapData.GAP_WIDTH * 0.5
		var distance := (edge - feet.x) * _intent
		if distance > 0.0 and distance < GAP_JUMP_DISTANCE:
			return true
	return false


## Toca una tecla en frames alternos: así cada toque es una pulsación nueva (como una persona).
func _tap(action: String) -> void:
	if Engine.get_physics_frames() % 2 == 0:
		Input.action_press(action)


func _press(direction: int) -> void:
	if direction < 0:
		Input.action_press("move_left")
	elif direction > 0:
		Input.action_press("move_right")


func _track_progress(node: Vector2i, delta: float) -> void:
	if node != _last_node:
		_last_node = node
		_since_progress = 0.0
		return
	_since_progress += delta
	if _since_progress > STUCK_SECONDS:
		Input.action_press("jump")
		_since_progress = STUCK_SECONDS * 0.5


func _debug() -> void:
	if status != _last_status:
		_last_status = status
		if OS.get_environment("BOT_DEBUG") != "":
			print("BOT ", status)
