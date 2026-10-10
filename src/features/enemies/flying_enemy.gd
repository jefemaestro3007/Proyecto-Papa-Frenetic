class_name FlyingEnemy
extends Enemy
## Papa voladora (del prototipo): persigue al jugador libremente cuando lo tiene cerca, pero choca
## con el escenario (no lo atraviesa). Si algo le tapa el paso, se desliza hacia el borde más
## cercano para rodearlo. Flota: su origen es el centro del cuerpo + `body_radius`.

var fly_speed := 150.0
var steering_acceleration := 520.0
## Solo despierta cuando el jugador está a esta distancia (si no, todas cruzarían el mapa).
var aggro_range := 1100.0
## A qué altura del jugador apunta (algo por encima del centro).
var target_offset := Vector2(0.0, -60.0)
var velocity := Vector2.ZERO

var _solids: Array[Rect2] = []
var _awake := false
var _wing_phase := 0.0
var _detour_direction := 0.0
var _detour_rect := Rect2()
var _home_y := 0.0


func _init() -> void:
	enemy_type = &"flyer"
	body_radius = 26.0
	body_color = Color("d7a46a")


## Rectángulos sólidos del mapa con los que choca.
func set_solids(solids: Array[Rect2]) -> void:
	_solids = solids


func _ready() -> void:
	super()
	_home_y = position.y


func _move(delta: float) -> void:
	if not _awake:
		_awake = global_position.distance_to(target.global_position) <= aggro_range
		position.y = _home_y + sin(_wing_phase * 0.15) * 10.0
		return
	var to_target := target.global_position + target_offset - global_position
	var desired := to_target.normalized() * fly_speed if to_target.length() > 4.0 else Vector2.ZERO
	if _detour_direction != 0.0:
		# Mientras rodea un obstáculo, prioriza el desplazamiento lateral.
		desired = Vector2(_detour_direction * fly_speed, 0.0)
	velocity = velocity.move_toward(desired, steering_acceleration * delta)
	if absf(velocity.x) > 1.0:
		facing = 1 if velocity.x > 0.0 else -1

	# Por ejes separados para deslizarse por las superficies.
	var next_x := position + Vector2(velocity.x * delta, 0.0)
	if _blocker(next_x).has_area():
		velocity.x = 0.0
	else:
		position = next_x
	var next_y := position + Vector2(0.0, velocity.y * delta)
	var blocker := _blocker(next_y)
	if blocker.has_area():
		velocity.y = 0.0
		if not _detour_rect.has_area():
			var left_gap := absf(position.x - blocker.position.x)
			var right_gap := absf(blocker.end.x - position.x)
			_detour_direction = -1.0 if left_gap < right_gap else 1.0
			_detour_rect = blocker
	else:
		position = next_y
	# Mantiene el desvío mientras siga pegada al obstáculo que la bloqueó.
	if _detour_rect.has_area():
		var center := body_center()
		var outside := center.x < _detour_rect.position.x - body_radius or center.x > _detour_rect.end.x + body_radius
		var gap := maxf(_detour_rect.position.y - center.y, center.y - _detour_rect.end.y)
		if outside or gap > body_radius + 12.0:
			_detour_rect = Rect2()
			_detour_direction = 0.0


func is_same_level_as_target() -> bool:
	return true


func _apply_survived_hit_push(direction: float) -> void:
	var pushed := position + Vector2(signf(direction) * SURVIVED_HIT_PUSH, 0.0)
	if not _blocker(pushed).has_area():
		position = pushed


## Obstáculo que tocaría el cuerpo con los pies en `feet`, o un Rect2 vacío.
func _blocker(feet: Vector2) -> Rect2:
	var center := feet + Vector2(0.0, -body_radius)
	for solid in _solids:
		if solid.grow(body_radius).has_point(center):
			return solid
	return Rect2()


func _update_visuals(delta: float) -> void:
	_wing_phase += delta * 18.0


func _draw_before_body(center: Vector2) -> void:
	if _dying:
		return
	var flap := sin(_wing_phase) * 0.5 + 0.5
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array([
			center + Vector2(side * body_radius * 0.6, -6.0),
			center + Vector2(side * (body_radius + 34.0), -18.0 - 22.0 * flap),
			center + Vector2(side * (body_radius + 18.0), 8.0 - 10.0 * flap),
		])
		draw_colored_polygon(wing, Color(0.92, 0.95, 1.0, 0.85))
		draw_polyline(wing + PackedVector2Array([wing[0]]), _outline(), 2.0)


## Despierta y cerca del jugador muestra la pose de ataque (pico abierto).
func sprite_pose() -> StringName:
	if _dying or _hurt_left > 0.0:
		return &"herido"
	if _awake and target != null and is_instance_valid(target) \
			and body_center().distance_to(target.global_position) < ATTACK_POSE_DISTANCE * 2.5:
		return &"ataque"
	return &"base"
