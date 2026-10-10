class_name PlayerPrototype
extends CharacterBody2D
## Prototipo jugable del personaje: toda su configuración vive en `params` (PlayerParams).
## Emite sus acciones para que el sistema de ritmo las juzgue y aplique recompensas o castigos.

signal jumped
signal turned(direction: float)
signal fast_fall_started
## `forced` = el aterrizaje venía de una caída forzada (su timing sí cuenta como intencional).
## `fall_height` = px desde el punto más alto del tramo aéreo hasta el suelo.
signal landed(impact_speed: float, forced: bool, fall_height: float)

const SIZE := Vector2(44.0, 88.0)

var params := PlayerParams.new()
var facing := 1.0

var _was_on_floor := true
var _air_top_y := 0.0
var _coyote_left := 0.0
var _buffer_left := 0.0
var _fast_falling := false
var _jump_cut_done := true
var _spin_left := 0.0
var _boost := 1.0
var _boost_left := 0.0
var _stumble_left := 0.0


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position.y = -SIZE.y * 0.5
	add_child(collision)


## Multiplica el impulso del salto en curso (llamar dentro de `jumped`).
func boost_jump(multiplier: float) -> void:
	velocity.y *= multiplier


## Giro completo con impulso de velocidad temporal (recompensa por girar a tiempo).
func spin(speed_boost: float) -> void:
	_spin_left = params.spin_time
	_boost = speed_boost
	_boost_left = params.boost_time


## Aturdimiento breve (castigo): menos velocidad y el cuerpo tambalea.
func stumble() -> void:
	_stumble_left = params.stumble_time
	_boost_left = 0.0


func reset_state() -> void:
	velocity = Vector2.ZERO
	_fast_falling = false
	_spin_left = 0.0
	_boost_left = 0.0
	_stumble_left = 0.0
	_buffer_left = 0.0


func is_fast_falling() -> bool:
	return _fast_falling


func _physics_process(delta: float) -> void:
	var blocked := _text_field_focused()
	var fall_speed := velocity.y
	var on_floor := is_on_floor()

	_coyote_left = params.coyote_time if on_floor else maxf(_coyote_left - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	if not blocked and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_up")):
		_buffer_left = maxf(params.jump_buffer, delta)

	if not on_floor:
		var gravity := params.gravity * (params.fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y += gravity * delta
		var jump_held := Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")
		# Salto variable: soltar mientras sube recorta el impulso una sola vez.
		if velocity.y < 0.0 and not jump_held and not _jump_cut_done:
			velocity.y *= params.jump_cut
			_jump_cut_done = true
		if params.fast_fall_enabled and not blocked and not _fast_falling \
				and Input.is_action_just_pressed("ui_down"):
			_fast_falling = true
			velocity.y = maxf(velocity.y, params.fast_fall_speed)
			fast_fall_started.emit()

	if _buffer_left > 0.0 and _coyote_left > 0.0:
		_buffer_left = 0.0
		_coyote_left = 0.0
		velocity.y = -params.jump_force
		_jump_cut_done = false
		jumped.emit()

	var direction := 0.0 if blocked else Input.get_axis("ui_left", "ui_right")
	if direction != 0.0 and signf(direction) != facing:
		facing = signf(direction)
		turned.emit(facing)

	_boost_left = maxf(_boost_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)
	var speed := params.max_speed
	if _stumble_left > 0.0:
		speed *= params.stumble_speed
	elif _boost_left > 0.0:
		speed *= _boost
	var accel := params.ground_accel if on_floor else params.air_accel
	velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	move_and_slide()

	if not is_on_floor():
		_air_top_y = position.y if _was_on_floor else minf(_air_top_y, position.y)
	elif not _was_on_floor:
		var forced := _fast_falling
		_fast_falling = false
		landed.emit(fall_speed, forced, position.y - _air_top_y)
	_was_on_floor = is_on_floor()


func _process(delta: float) -> void:
	_spin_left = maxf(_spin_left - delta, 0.0)
	queue_redraw()


func _text_field_focused() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _draw() -> void:
	var pulse := Conductor.pulse(9.0) if is_on_floor() else 0.0
	var squash := Vector2(1.0 + params.beat_bounce * pulse, 1.0 - params.beat_bounce * pulse)
	if _fast_falling:
		squash = Vector2(0.8, 1.25)
	var angle := 0.0
	if _spin_left > 0.0:
		angle = (1.0 - _spin_left / params.spin_time) * TAU * facing
	elif _stumble_left > 0.0:
		angle = sin(_stumble_left * 40.0) * 0.25
	var pivot := Vector2(0.0, -SIZE.y * 0.5)

	if _fast_falling:
		# Estelas de velocidad sobre el personaje.
		for i in 3:
			var x := (i - 1) * 14.0
			draw_line(Vector2(x, -SIZE.y - 20.0), Vector2(x, -SIZE.y - 90.0 - i * 20.0),
					FreneticPalette.CREAM, 5.0)

	draw_set_transform_matrix(Transform2D(0.0, squash, 0.0, Vector2.ZERO)
			* Transform2D(angle, pivot) * Transform2D(0.0, -pivot))
	var body := Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y)
	draw_rect(body, FreneticPalette.CREAM)
	draw_rect(Rect2(body.position, Vector2(SIZE.x, 22.0)), FreneticPalette.SKY)
	draw_rect(Rect2(body.position.x + (SIZE.x if facing > 0.0 else -14.0), body.position.y + 14.0,
			14.0, 8.0), FreneticPalette.SKY)
	var look := 6.0 * facing
	var eye := 6.0 if _stumble_left <= 0.0 else 3.0
	draw_circle(Vector2(look - 8.0, -SIZE.y + 36.0), eye, FreneticPalette.INK)
	draw_circle(Vector2(look + 8.0, -SIZE.y + 36.0), eye, FreneticPalette.INK)
	draw_rect(body, FreneticPalette.INK, false, 4.0)
