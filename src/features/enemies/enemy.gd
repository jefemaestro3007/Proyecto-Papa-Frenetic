class_name Enemy
extends Area2D
## Papa zombi: enemigo base (inspirado en el prototipo `feature/gameplay-prototype`).
## Persigue al jugador por su carril cuando comparte nivel, late con el beat, recibe golpes
## (las resistentes aguantan varios) y al morir sale despedida girando.
## El origen está en los pies. Las variantes heredan y sobrescriben `_move()` y el dibujo.

signal reached_player(enemy: Enemy)
signal defeated(enemy: Enemy)

const DEATH_SECONDS := 0.75
const DEATH_GRAVITY := 2600.0
const DEATH_LAUNCH := Vector2(620.0, 980.0)
const SURVIVED_HIT_PUSH := 70.0
const FACE_COLOR := Color("251d1a")
const CHEEK_COLOR := Color("d85b4b")
const SPRITE_DIR := "res://assets/textures/sprites/enemies/"
## Los PNG están al doble de resolución (ver tools/scripts/build_enemy_sprites.gd).
const SPRITE_SCALE := 0.5
## Cuánto dura la pose de herido tras un golpe que aguanta.
const HURT_POSE_SECONDS := 0.3
## Distancia al jugador desde la que se muestra la pose de ataque.
const ATTACK_POSE_DISTANCE := 150.0

## Texturas compartidas por todos los enemigos: "<tipo>_<pose>" → Texture2D (o null si falta).
static var _textures := {}

@export var move_speed := 170.0
@export var same_level_tolerance := 60.0
@export_range(1, 10) var max_health := 1
## Las resistentes no desaparecen al tocar al jugador.
@export var consumed_on_contact := true
@export var body_radius := 34.0
@export var body_color := Color("b77a42")
@export var enemy_type := &"normal"
## Multiplica el calor que suma tocar al jugador (la embestidora pega más fuerte).
@export var contact_heat_scale := 1.0
## Vestuario de la zona (`EnemyCostume`); vacío = sin vestuario. Solo cambia el dibujo.
@export var costume := &""

var active := true
var health := 1
var lane_left := 0.0
var lane_right := 1920.0
var target: Node2D
var style: ArtStyle
var facing := -1
var _dying := false
var _death_age := 0.0
var _death_velocity := Vector2.ZERO
var _spin_speed := 0.0
var _flash := 0.0
var _hurt_left := 0.0
## Parte de arriba del dibujo actual (sprite o papa): ahí van los avisos y la vida.
var _top_y := 0.0


func _ready() -> void:
	health = max_health
	var shape := CircleShape2D.new()
	shape.radius = body_radius
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -body_radius)
	add_child(collision)
	body_entered.connect(_on_body_entered)


func configure(player: Node2D, left: float, right: float, art_style: ArtStyle) -> void:
	target = player
	lane_left = minf(left, right)
	lane_right = maxf(left, right)
	style = art_style


## Centro del cuerpo (para apuntar ataques y efectos).
func body_center() -> Vector2:
	return global_position + Vector2(0.0, -body_radius)


func _physics_process(delta: float) -> void:
	if not active or target == null or not is_instance_valid(target):
		return
	# Mientras siga tocando al jugador se reporta: si era invulnerable, cuenta cuando deje de serlo.
	if overlaps_body(target):
		reached_player.emit(self)
		if not active:
			return
	_move(delta)


## Movimiento por defecto: persigue en horizontal solo si comparte nivel con el jugador.
func _move(delta: float) -> void:
	if not is_same_level_as_target():
		return
	var direction := signf(target.global_position.x - global_position.x)
	if direction != 0.0:
		facing = int(direction)
	position.x = clampf(position.x + direction * move_speed * delta, lane_left, lane_right)


## Se le puede pegar (ataque, stomp, dash). Los globos encendidos ya no.
func is_hittable() -> bool:
	return active


func is_same_level_as_target() -> bool:
	return absf(target.global_position.y - global_position.y) <= same_level_tolerance


## Aplica un golpe. Devuelve true si lo derrota.
func receive_hit(direction: float, strong: bool, damage := 1) -> bool:
	if not active:
		return false
	health -= damage
	if health <= 0:
		defeat(direction, strong)
		return true
	_flash = 1.0
	_hurt_left = HURT_POSE_SECONDS
	scale = Vector2(1.3, 0.75)
	_apply_survived_hit_push(direction)
	return false


## Retroceso al aguantar un golpe (por defecto, por su carril).
func _apply_survived_hit_push(direction: float) -> void:
	position.x = clampf(position.x + signf(direction) * SURVIVED_HIT_PUSH, lane_left, lane_right)


func defeat(direction := 0.0, strong := false) -> void:
	if not active:
		return
	active = false
	health = 0
	defeated.emit(self)
	_dying = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	var side := signf(direction)
	if side == 0.0:
		side = 1.0
	var launch := 1.35 if strong else 1.0
	_death_velocity = Vector2(side * DEATH_LAUNCH.x, -DEATH_LAUNCH.y) * launch
	_spin_speed = side * (15.0 if strong else 9.0)
	_flash = 1.0
	scale = Vector2(1.4, 0.65)
	z_index = 45


func _process(delta: float) -> void:
	if _dying:
		_death_age += delta
		_death_velocity.y += DEATH_GRAVITY * delta
		position += _death_velocity * delta
		rotation += _spin_speed * delta
		modulate.a = clampf(1.0 - (_death_age - DEATH_SECONDS * 0.55) / (DEATH_SECONDS * 0.45), 0.0, 1.0)
		if _death_age >= DEATH_SECONDS:
			queue_free()
	scale = scale.lerp(Vector2.ONE, minf(1.0, delta * 12.0))
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_update_visuals(delta)
	queue_redraw()


## Animación propia de cada variante.
func _update_visuals(_delta: float) -> void:
	pass


func _draw() -> void:
	if not active and not _dying:
		return
	# Latido con el beat (pivote en los pies).
	var pulse := 0.0 if _dying else Conductor.pulse(8.0)
	var squash := Vector2(1.0 + 0.1 * pulse, 1.0 - 0.12 * pulse)
	draw_set_transform(_draw_offset(), 0.0, squash)
	var center := Vector2(0.0, -body_radius)
	var texture := sprite_texture(sprite_pose())
	_top_y = -texture.get_height() * SPRITE_SCALE if texture != null else -body_radius * 2.0
	_top_y *= 1.0 + EnemyCostume.top_extra(costume)
	if texture != null:
		# Los dibujos miran a la izquierda: se espejan al mirar a la derecha. El golpe ilumina.
		var size := texture.get_size() * SPRITE_SCALE
		draw_set_transform(_draw_offset(), 0.0, squash * Vector2(-1.0 if facing > 0 else 1.0, 1.0))
		var rect := Rect2(Vector2(-size.x * 0.5, -size.y), size)
		_draw_costume(rect, EnemyCostume.Layer.BACK)
		# Contorno con el color del estilo: separa las papas rojas del cielo rojo.
		var width := clampf(_outline_width() * 0.8, 2.0, 5.0)
		for i in 8:
			draw_texture_rect(texture, Rect2(rect.position + Vector2.from_angle(TAU * i / 8.0) * width, rect.size),
					false, Color(_outline(), 0.9))
		draw_texture_rect(texture, rect, false,
				Color(1.0 + _flash, 1.0 + _flash, 1.0 + _flash))
		_draw_costume(rect, EnemyCostume.Layer.FRONT)
		draw_set_transform(_draw_offset(), 0.0, squash)
	else:
		var rect := Rect2(center - Vector2(body_radius * 1.1, body_radius), Vector2(body_radius * 2.2, body_radius * 2.0))
		_draw_costume(rect, EnemyCostume.Layer.BACK)
		_draw_before_body(center)
		_draw_potato(center, body_radius, _body_color())
		_draw_after_body(center)
		_draw_costume(rect, EnemyCostume.Layer.FRONT)
		if _flash > 0.0:
			draw_circle(center, body_radius + 2.0, Color(1.0, 1.0, 1.0, _flash))
	if not _dying:
		_draw_indicators(center)
		if max_health > 1:
			_draw_health_pips(center)
	draw_set_transform(Vector2.ZERO)


## Accesorios del vestuario en el espacio del dibujo (cara a la izquierda). Al morir sale despedido
## con la papa, igual que el sprite.
func _draw_costume(rect: Rect2, layer: EnemyCostume.Layer) -> void:
	if costume != &"":
		EnemyCostume.draw(self, costume, rect, layer)


## Pose del sprite: herido al recibir un golpe o al morir, ataque cerca del jugador, base si no.
## Las variantes la cambian según su comportamiento (carga, lanzamiento...).
func sprite_pose() -> StringName:
	if _dying or _hurt_left > 0.0:
		return &"herido"
	if target != null and is_instance_valid(target) \
			and body_center().distance_to(target.global_position) < ATTACK_POSE_DISTANCE + body_radius:
		return &"ataque"
	return &"base"


## Textura de esta papa para una pose (null si no hay sprite: se dibuja la papa provisional).
func sprite_texture(pose: StringName) -> Texture2D:
	var key := "%s_%s" % [enemy_type, pose]
	if not _textures.has(key):
		var path := SPRITE_DIR + key + ".png"
		_textures[key] = load(path) if ResourceLoader.exists(path) else null
	return _textures[key]


## Avisos de juego que se dibujan encima del sprite o de la papa provisional ("!", estrellas...).
func _draw_indicators(_center: Vector2) -> void:
	pass


func _draw_offset() -> Vector2:
	return Vector2.ZERO


func _body_color() -> Color:
	return body_color


func _draw_before_body(_center: Vector2) -> void:
	pass


func _draw_after_body(_center: Vector2) -> void:
	pass


func _outline() -> Color:
	return style.outline if style != null else FACE_COLOR


func _outline_width() -> float:
	return maxf(style.outline_width * 0.75, 2.0) if style != null else 3.0


func _draw_potato(center: Vector2, radius: float, color: Color) -> void:
	var k := radius / 34.0
	# Papa algo irregular: elipse con bultos.
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		var bump := 1.0 + 0.06 * sin(angle * 3.0 + 1.3)
		points.append(center + Vector2(cos(angle) * radius * 1.05, sin(angle) * radius * 0.95) * bump)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, _outline(), _outline_width())
	for spot in [Vector2(-14.0, 14.0), Vector2(16.0, 6.0), Vector2(2.0, -22.0)]:
		draw_circle(center + spot * k, 3.0 * k, color.darkened(0.3))
	if _dying:
		for eye_x: float in [-11.0, 11.0]:
			var eye := center + Vector2(eye_x, -6.0) * k
			draw_line(eye + Vector2(-5.0, -5.0) * k, eye + Vector2(5.0, 5.0) * k, FACE_COLOR, 3.0)
			draw_line(eye + Vector2(-5.0, 5.0) * k, eye + Vector2(5.0, -5.0) * k, FACE_COLOR, 3.0)
		draw_circle(center + Vector2(0.0, 12.0) * k, 6.0 * k, FACE_COLOR)
	else:
		var look := Vector2(3.0 * facing, 0.0) * k
		draw_circle(center + Vector2(-11.0, -6.0) * k + look, 4.0 * k, FACE_COLOR)
		draw_circle(center + Vector2(11.0, -6.0) * k + look, 4.0 * k, FACE_COLOR)
		draw_line(center + Vector2(-10.0, 10.0) * k, center + Vector2(10.0, 10.0) * k, FACE_COLOR, 3.0)
	draw_circle(center + Vector2(-26.0, 2.0) * k, 6.0 * k, CHEEK_COLOR)
	draw_circle(center + Vector2(26.0, 2.0) * k, 6.0 * k, CHEEK_COLOR)


func _draw_health_pips(center: Vector2) -> void:
	for i in max_health:
		var pip := Vector2(center.x + (i - (max_health - 1) * 0.5) * 18.0, _top_y - 14.0)
		draw_circle(pip, 7.0, Color(0.1, 0.08, 0.06, 0.85))
		if i < health:
			draw_circle(pip, 5.0, Color("ef6657"))


func _on_body_entered(body: Node2D) -> void:
	if active and body == target:
		reached_player.emit(self)
