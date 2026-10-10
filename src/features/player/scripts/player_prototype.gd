class_name PlayerPrototype
extends CharacterBody2D
## Prototipo jugable del personaje: toda su configuración vive en `params` (PlayerParams).
## Emite sus acciones para que el sistema de ritmo las juzgue y aplique recompensas o castigos.
## Se dibuja con los sprites de `assets/textures/sprites/player/` (generados por
## `tools/scripts/build_player_sprites.gd`); si faltan, con el dibujo provisional.

signal jumped
signal turned(direction: float)
signal fast_fall_started
## `forced` = el aterrizaje venía de una caída forzada (su timing sí cuenta como intencional).
## `fall_height` = px desde el punto más alto del tramo aéreo hasta el suelo.
signal landed(impact_speed: float, forced: bool, fall_height: float)
## Dash iniciado (Shift, solo en el suelo) hacia `direction`.
signal dash_started(direction: float)

const SIZE := Vector2(44.0, 88.0)
const ATTACK_SECONDS := 0.16
## Duración de la animación de ataque con sprites (guardia → tajo → espalda); el golpe se juzga al pulsar.
const ATTACK_POSE_SECONDS := 0.3
## Fases del ataque en el suelo (fracción de la animación): hasta aquí guardia, luego el tajo,
## luego de espaldas cerrando el giro.
const ATTACK_SWING_FROM := 0.2
const ATTACK_BACK_FROM := 0.65
const SWING_EFFECT := "res://assets/textures/sprites/fx/ataque_swing.png"
const SPRITE_DIR := "res://assets/textures/sprites/player/"
## Los PNG están al doble de resolución (ver build_player_sprites.gd).
const SPRITE_SCALE := 0.5
const STOMP_ARROW := "res://assets/textures/sprites/fx/stomp_flecha.png"
const SPRITE_NAMES: Array[StringName] = [
	&"guardia", &"espalda", &"correr_0", &"correr_1", &"correr_2", &"correr_3",
	&"aire", &"aterrizaje", &"dash", &"ataque_aereo",
]
## Cuánto dura la pose de aterrizaje.
const LAND_POSE_SECONDS := 0.12
## Frames de correr por beat: el paso va al ritmo.
const RUN_FRAMES_PER_BEAT := 4
const RUN_MIN_SPEED := 40.0

var params := PlayerParams.new()
var facing := 1.0
## Movido por la zona (escaleras, ascensor): sin física ni colisión.
var scripted := false
## Agarre del piso (1 = normal). Menos resbala: cuesta arrancar y frenar (compras, piso mojado,
## carrito). Lo pone la zona en cada frame de física.
var traction := 1.0
## Multiplica la velocidad máxima (escarcha de un freezer, carrito). Lo pone la zona.
var speed_scale := 1.0

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
var _collision: CollisionShape2D
var _attack_left := 0.0
var _attack_air := false
var _attack_connected := false
var _invulnerable_left := 0.0
var _dash_left := 0.0
var _dash_direction := 1.0
var _dash_cooldown_left := 0.0
var _land_left := 0.0
var _sprites := {}
var _stomp_arrow: Texture2D
var _swing: Texture2D


func _ready() -> void:
	# Cápsula: en suelo plano es igual a un rectángulo, pero resbala de puntas y cornisas
	# en vez de quedarse apoyada en un vértice.
	var shape := CapsuleShape2D.new()
	shape.radius = SIZE.x * 0.5
	shape.height = SIZE.y
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position.y = -SIZE.y * 0.5
	add_child(_collision)
	for sprite_name in SPRITE_NAMES:
		var path := SPRITE_DIR + sprite_name + ".png"
		if ResourceLoader.exists(path):
			_sprites[sprite_name] = load(path)
	if ResourceLoader.exists(STOMP_ARROW):
		_stomp_arrow = load(STOMP_ARROW)
	if ResourceLoader.exists(SWING_EFFECT):
		_swing = load(SWING_EFFECT)


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


## Tajo visible del ataque (en el suelo hacia adelante, en el aire en arco amplio).
func play_attack(airborne: bool, connected: bool) -> void:
	_attack_left = ATTACK_POSE_SECONDS if not _sprites.is_empty() else ATTACK_SECONDS
	_attack_air = airborne
	_attack_connected = connected


## Golpe recibido: retroceso, aturdimiento e invulnerabilidad breve.
func hurt(from_x: float, knockback: Vector2, invulnerable_seconds: float) -> void:
	stumble()
	var side := signf(position.x - from_x)
	if side == 0.0:
		side = -facing
	velocity = Vector2(side * knockback.x, -knockback.y)
	_invulnerable_left = invulnerable_seconds
	_fast_falling = false


## Rebote contra una papa que aguanta (stomp o dash contra un tanque): sin daño ni aturdimiento.
func recoil(from_x: float) -> void:
	var side := signf(position.x - from_x)
	if side == 0.0:
		side = -facing
	_dash_left = 0.0
	_fast_falling = false
	velocity = Vector2(side * params.recoil_x, -params.recoil_y)
	_invulnerable_left = maxf(_invulnerable_left, params.recoil_invulnerable)


## Roce de un proyectil: solo un instante de invulnerabilidad (parpadeo), sin empuje.
func graze(invulnerable_seconds: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left, invulnerable_seconds)


func is_dashing() -> bool:
	return _dash_left > 0.0


func cancel_dash() -> void:
	_dash_left = 0.0


## Segundos hasta poder volver a usar el dash (0 = listo).
func dash_cooldown_left() -> float:
	return _dash_cooldown_left


## Durante la caída forzada, el dash, el viaje guiado o tras un golpe, los enemigos no dañan
## (el contacto del stomp y el dash lo resuelve el combate).
func is_invulnerable() -> bool:
	return scripted or _invulnerable_left > 0.0 or _fast_falling or is_dashing()


func reset_state() -> void:
	velocity = Vector2.ZERO
	traction = 1.0
	speed_scale = 1.0
	_fast_falling = false
	_spin_left = 0.0
	_boost_left = 0.0
	_stumble_left = 0.0
	_buffer_left = 0.0
	_invulnerable_left = 0.0
	_dash_left = 0.0
	_dash_cooldown_left = 0.0


## La zona toma el control (escaleras, ascensor): sin física ni colisión hasta `end_scripted`.
func begin_scripted() -> void:
	scripted = true
	velocity = Vector2.ZERO
	_fast_falling = false
	_dash_left = 0.0
	_collision.disabled = true


func end_scripted(at: Vector2) -> void:
	position = at
	scripted = false
	velocity = Vector2.ZERO
	_collision.disabled = false
	_was_on_floor = true
	_air_top_y = at.y


func is_fast_falling() -> bool:
	return _fast_falling


func _physics_process(delta: float) -> void:
	if scripted:
		return
	var blocked := _text_field_focused()
	var fall_speed := velocity.y
	var on_floor := is_on_floor()

	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	if params.dash_enabled and not blocked and on_floor and not is_dashing() \
			and _dash_cooldown_left <= 0.0 and Input.is_action_just_pressed("dash"):
		_start_dash()
	if is_dashing():
		_process_dash(delta)
		return

	_coyote_left = params.coyote_time if on_floor else maxf(_coyote_left - delta, 0.0)
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	# Solo Espacio salta: W y S quedan libres para escaleras, puertas y ascensores.
	if not blocked and Input.is_action_just_pressed("jump"):
		_buffer_left = maxf(params.jump_buffer, delta)

	if not on_floor:
		var gravity := params.gravity * (params.fall_gravity_multiplier if velocity.y > 0.0 else 1.0)
		velocity.y += gravity * delta
		var jump_held := Input.is_action_pressed("jump")
		# Salto variable: soltar mientras sube recorta el impulso una sola vez.
		if velocity.y < 0.0 and not jump_held and not _jump_cut_done:
			velocity.y *= params.jump_cut
			_jump_cut_done = true
		if params.fast_fall_enabled and not blocked and not _fast_falling \
				and Input.is_action_just_pressed("move_down"):
			_fast_falling = true
			velocity.y = maxf(velocity.y, params.fast_fall_speed)
			fast_fall_started.emit()

	if _buffer_left > 0.0 and _coyote_left > 0.0:
		_buffer_left = 0.0
		_coyote_left = 0.0
		velocity.y = -params.jump_force
		_jump_cut_done = false
		jumped.emit()

	var direction := 0.0 if blocked else Input.get_axis("move_left", "move_right")
	if direction != 0.0 and signf(direction) != facing:
		facing = signf(direction)
		turned.emit(facing)

	_boost_left = maxf(_boost_left - delta, 0.0)
	_stumble_left = maxf(_stumble_left - delta, 0.0)
	var speed := params.max_speed * speed_scale
	if _stumble_left > 0.0:
		speed *= params.stumble_speed
	elif _boost_left > 0.0:
		speed *= _boost
	var accel := params.ground_accel * traction if on_floor else params.air_accel
	velocity.x = move_toward(velocity.x, direction * speed, accel * delta)
	move_and_slide()

	if not is_on_floor():
		_air_top_y = position.y if _was_on_floor else minf(_air_top_y, position.y)
	elif not _was_on_floor:
		var forced := _fast_falling
		_fast_falling = false
		_land_left = LAND_POSE_SECONDS
		landed.emit(fall_speed, forced, position.y - _air_top_y)
	_was_on_floor = is_on_floor()


## Dash horizontal hacia donde se apunta (o mira): sin gravedad ni control mientras dura.
func _start_dash() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0 and signf(direction) != facing:
		facing = signf(direction)
	_dash_direction = facing
	_dash_left = params.dash_duration
	_dash_cooldown_left = params.dash_cooldown
	_fast_falling = false
	_stumble_left = 0.0
	velocity = Vector2(_dash_direction * params.dash_speed, 0.0)
	dash_started.emit(_dash_direction)


func _process_dash(delta: float) -> void:
	velocity = Vector2(_dash_direction * params.dash_speed, 0.0)
	move_and_slide()
	_dash_left = maxf(_dash_left - delta, 0.0)
	if not is_dashing():
		# Conserva impulso al salir del dash.
		velocity.x = _dash_direction * params.max_speed
	_was_on_floor = is_on_floor()
	if not _was_on_floor:
		_air_top_y = position.y


func _process(delta: float) -> void:
	_spin_left = maxf(_spin_left - delta, 0.0)
	_attack_left = maxf(_attack_left - delta, 0.0)
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	_land_left = maxf(_land_left - delta, 0.0)
	queue_redraw()


func _text_field_focused() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


func _draw() -> void:
	var pulse := Conductor.pulse(9.0) if is_on_floor() else 0.0
	var squash := Vector2(1.0 + params.beat_bounce * pulse, 1.0 - params.beat_bounce * pulse)
	if _fast_falling:
		squash = Vector2(0.8, 1.25)
	if is_dashing():
		# El sprite del dash ya viene estirado; el dibujo provisional se estira a mano.
		squash = Vector2.ONE if _sprites.has(&"dash") else Vector2(1.35, 0.78)
		# Estelas horizontales detrás del dash.
		for i in 3:
			var y := -SIZE.y * (0.25 + 0.25 * i)
			var back := -_dash_direction
			draw_line(Vector2(back * SIZE.x * 0.6, y), Vector2(back * (SIZE.x * 1.6 + 30.0 * i), y),
					FreneticPalette.CREAM, 6.0)
	var angle := 0.0
	if _spin_left > 0.0:
		angle = (1.0 - _spin_left / params.spin_time) * TAU * facing
	elif _stumble_left > 0.0:
		angle = sin(_stumble_left * 40.0) * 0.25
	var pivot := Vector2(0.0, -SIZE.y * 0.5)

	if _fast_falling:
		if _stomp_arrow != null:
			# Flecha del stomp (dibujo del equipo) sobre el personaje, latiendo con el beat.
			var arrow := _stomp_arrow.get_size() * SPRITE_SCALE * (1.0 + 0.15 * Conductor.pulse(8.0))
			draw_texture_rect(_stomp_arrow, Rect2(Vector2(-arrow.x * 0.5, -SIZE.y - arrow.y * 0.55), arrow), false,
					Color(1.0, 1.0, 1.0, 0.85))
		else:
			# Estelas de velocidad sobre el personaje.
			for i in 3:
				var x := (i - 1) * 14.0
				draw_line(Vector2(x, -SIZE.y - 20.0), Vector2(x, -SIZE.y - 90.0 - i * 20.0),
						FreneticPalette.CREAM, 5.0)

	var pose := _pose()
	# Con sprites, los tajos son dibujos del equipo (el aéreo viene en su pose, el del suelo es un efecto).
	if _attack_left > 0.0 and _sprites.is_empty():
		_draw_slash()
	# Parpadeo mientras es invulnerable tras un golpe.
	if _invulnerable_left > 0.0 and fmod(_invulnerable_left, 0.12) < 0.06:
		return

	var body_transform := Transform2D(0.0, squash, 0.0, Vector2.ZERO) \
			* Transform2D(angle, pivot) * Transform2D(0.0, -pivot)
	var texture: Texture2D = _sprites.get(pose)
	if texture != null:
		# Los sprites miran a la derecha y se espejan al mirar a la izquierda.
		var mirror := Transform2D(0.0, Vector2(-1.0 if facing < 0.0 else 1.0, 1.0), 0.0, Vector2.ZERO)
		draw_set_transform_matrix(body_transform * mirror)
		var size := texture.get_size() * SPRITE_SCALE
		draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false)
		if _swing != null and _attack_phase() == 1:
			# Tajo del ataque en el suelo, delante del personaje y a la altura de la cintura.
			var swing := _swing.get_size() * SPRITE_SCALE
			draw_texture_rect(_swing, Rect2(Vector2(-SIZE.x * 0.1, -SIZE.y - swing.y * 0.6), swing), false)
		draw_set_transform(Vector2.ZERO)
		return

	draw_set_transform_matrix(body_transform)
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


## Pose del sprite según el estado. El ataque en el suelo es guardia → tajo → espalda.
func _pose() -> StringName:
	if is_dashing():
		return &"dash"
	if _attack_left > 0.0 and _attack_air:
		return &"ataque_aereo"
	if _attack_phase() == 2:
		return &"espalda"
	if _attack_phase() >= 0:
		return &"guardia"
	if not scripted and not is_on_floor():
		return &"aire"
	if _land_left > 0.0:
		return &"aterrizaje"
	if absf(velocity.x) > RUN_MIN_SPEED and not scripted:
		return StringName("correr_%d" % posmod(floori(Conductor.beat_position() * RUN_FRAMES_PER_BEAT), 4))
	return &"guardia"


## Fase del ataque en el suelo: -1 sin ataque, 0 guardia, 1 tajo, 2 de espaldas (cierra el giro;
## al terminar vuelve a la guardia de frente).
func _attack_phase() -> int:
	if _attack_left <= 0.0 or _attack_air:
		return -1
	var t := 1.0 - _attack_left / ATTACK_POSE_SECONDS
	if t < ATTACK_SWING_FROM:
		return 0
	return 1 if t < ATTACK_BACK_FROM else 2


func _draw_slash() -> void:
	var t := 1.0 - _attack_left / ATTACK_SECONDS
	var center := Vector2(facing * 20.0, -SIZE.y * 0.55)
	var color := FreneticPalette.YELLOW if _attack_connected else FreneticPalette.CREAM
	var radius := 92.0 if _attack_air else 78.0
	var span := PI * (1.25 if _attack_air else 0.85)
	# De arriba hacia abajo del lado al que mira (en pantalla el ángulo crece en sentido horario).
	var base := 0.0 if facing > 0.0 else PI
	var start := base - span * 0.5 * facing
	var sweep := span * minf(t * 1.6, 1.0)
	var points := PackedVector2Array()
	for i in 12:
		var angle := start + facing * sweep * i / 11.0
		points.append(center + Vector2.from_angle(angle) * radius)
	draw_polyline(points, FreneticPalette.INK, 16.0 * (1.0 - t) + 6.0)
	draw_polyline(points, Color(color, 1.0 - t * 0.6), 10.0 * (1.0 - t) + 3.0)
