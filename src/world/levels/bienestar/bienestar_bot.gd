class_name BienestarBot
extends RefCounted
## Recorrido automático de Bienestar U con los controles del jugador (para `--autorun`, capturas y
## el test de recorrido). En el supermercado corre a la derecha saltando obstáculos; en el centro
## comercial va a la escalera mecánica más cercana que sube de su piso, la toma (dando pasos a
## tiempo si va a contramano) y en el último piso va a la salida. Espera las cortinas cerradas,
## salta huecos y obstáculos, y golpea a las papas que tiene al alcance.

const LOOK_AHEAD := 190.0
const JUMP_HEIGHT := 200.0
const STUCK_SECONDS := 1.5
## Frames que se mantiene apretado el salto (soltarlo mientras sube lo corta).
const JUMP_HOLD := 24

var status := ""
var _data: BienestarMapData
var _params: BienestarParams
var _target_escalator: BienestarMapData.Escalator
var _last_x := 0.0
var _stuck := 0.0
var _tap_frames := 0
## Frames que le quedan al salto apretado (negativo: frames que debe estar suelto antes de otro).
var _jump_frames := 0
var _want_jump := false


func _init(data: BienestarMapData, params: BienestarParams) -> void:
	_data = data
	_params = params


func step(zone: Node, delta: float) -> void:
	var player: PlayerPrototype = zone.player()
	var world: BienestarWorld = zone.world()
	for action in ["move_left", "move_right", "attack", "move_down"]:
		Input.action_release(action)
	_want_jump = false
	_update_jump()
	if _tap_frames > 0:
		_tap_frames -= 1
		if _tap_frames == 0:
			Input.action_release("move_up")
		return
	Input.action_release("move_up")
	if zone.is_riding_escalator():
		status = "escalera"
		# A contramano: un paso por beat, cerca del tiempo.
		if absf(Conductor.offset_to_beat()) < 0.04:
			Input.action_press("move_up")
			_tap_frames = 1
		return
	if player.scripted:
		return
	if zone._combat.has_target() and Engine.get_physics_frames() % 2 == 0:
		Input.action_press("attack")
	var feet := player.global_position
	var f := _data.floor_at(feet)
	var target_x := _data.goal.get_center().x
	if _data.mall and f >= 0 and f < _data.floors.size() - 1:
		_target_escalator = _nearest_escalator(f, feet.x)
		target_x = _target_escalator.foot.x
		status = "a la escalera del piso %d" % f
		if absf(feet.x - target_x) < 24.0 and player.is_on_floor():
			Input.action_press("move_up")
			_tap_frames = 2
			return
	else:
		status = "a la salida"
	var direction := signf(target_x - feet.x)
	if absf(target_x - feet.x) < 12.0:
		direction = 0.0
	# Cortina cerrada (o casi) adelante: espera.
	for i in _data.shutters.size():
		var shutter := _data.shutters[i]
		if shutter.floor == f and direction != 0.0 and (shutter.x - feet.x) * direction > 0.0 \
				and absf(shutter.x - feet.x) < 160.0 and world.shutter_gap(i) < BienestarWorld.WALK_GAP + 20.0:
			status = "esperando la cortina"
			direction = 0.0
	if direction > 0.0:
		Input.action_press("move_right")
	elif direction < 0.0:
		Input.action_press("move_left")
	if direction != 0.0 and player.is_on_floor() and _blocked_ahead(world, feet, direction, f):
		_jump()
	# Atascado: salta igual.
	if direction != 0.0 and absf(feet.x - _last_x) < 1.0:
		_stuck += delta
		if _stuck > STUCK_SECONDS and player.is_on_floor():
			_jump()
			_stuck = 0.0
	else:
		_stuck = 0.0
	_last_x = feet.x


## Empieza un salto completo (si el anterior ya se soltó).
func _jump() -> void:
	if _jump_frames == 0:
		Input.action_press("jump")
		_jump_frames = JUMP_HOLD


## Mantiene el salto apretado mientras sube y lo suelta un frame antes de permitir otro.
func _update_jump() -> void:
	if _jump_frames > 0:
		_jump_frames -= 1
		if _jump_frames == 0:
			Input.action_release("jump")
			_jump_frames = -2
	elif _jump_frames < 0:
		_jump_frames += 1


## Escalera de este piso más cercana a `x`.
func _nearest_escalator(f: int, x: float) -> BienestarMapData.Escalator:
	var best: BienestarMapData.Escalator = null
	for escalator in _data.escalators:
		if escalator.floor == f and (best == null or absf(escalator.foot.x - x) < absf(best.foot.x - x)):
			best = escalator
	return best


## Algo para saltar justo adelante: un sólido bajo, escombros de un rack o un hueco del atrio.
func _blocked_ahead(world: BienestarWorld, feet: Vector2, direction: float, f: int) -> bool:
	var probe := Rect2(feet.x + (0.0 if direction > 0.0 else -LOOK_AHEAD), feet.y - JUMP_HEIGHT, LOOK_AHEAD, JUMP_HEIGHT - 4.0)
	for solid in _data.solids:
		if solid.intersects(probe) and solid.size.y < 300.0:
			return true
	for i in _data.racks.size():
		if world.rack_down[i]:
			var rack := _data.racks[i]
			var pile := Rect2(rack.rect.position.x + 20.0, _data.surface_y(rack.floor) - BienestarWorld.DEBRIS_HEIGHT,
					rack.rect.size.x - 40.0, BienestarWorld.DEBRIS_HEIGHT)
			if pile.intersects(probe):
				return true
	if f >= 0:
		var ahead := feet.x + direction * 70.0
		if _data.floors[f].has_hole(ahead):
			return true
	return false
