class_name ThrowerEnemy
extends Enemy
## Papa tiradora (del prototipo, estilo hermanos martillo): se queda en su puesto y lanza papas
## fritas en arco hacia el jugador AL RITMO, con las semicorcheas del Conductor. Un beat antes de
## cada tiempo fuerte elige un patrón y lo avisa (brazo en alto + un punto por lanzamiento); en el
## compás siguiente lo lanza: negra = 1, corcheas = 2, semicorcheas = 4 en ráfaga (los patrones
## rápidos son los que le dan más poder). No cambia el tempo: solo escucha `Conductor.subbeat`.

signal projectile_requested(origin: Vector2, velocity: Vector2)

## Posiciones (en semicorcheas desde el tiempo fuerte) de cada lanzamiento.
const PATTERNS := {
	&"negra": [0],
	&"corcheas": [0, 2],
	&"semicorcheas": [0, 1, 2, 3],
}

var throw_range := 1400.0
var flight_seconds := 0.8
## Separación horizontal entre los lanzamientos de una ráfaga.
var volley_spread := 45.0
## Compases entre ráfagas (1 = cada compás).
var bars_between_volleys := 1
## Probabilidad de cada patrón: negra, corcheas, semicorcheas.
var pattern_weights := PackedFloat32Array([0.5, 0.3, 0.2])
var rng := RandomNumberGenerator.new()
var current_pattern := &""

var _throws: Array = []
var _throws_done := 0
var _bars_since_volley := 0
var _hop := 0.0


func _init() -> void:
	enemy_type = &"thrower"
	move_speed = 0.0
	body_color = Color("a8794a")


func _ready() -> void:
	super()
	Conductor.subbeat.connect(_on_subbeat)


func _move(_delta: float) -> void:
	# No persigue: solo mira al jugador desde su puesto.
	var dx := target.global_position.x - global_position.x
	if absf(dx) > 2.0:
		facing = 1 if dx > 0.0 else -1


func _on_subbeat(index: int) -> void:
	if not active or target == null or not is_instance_valid(target) \
			or not is_physics_processing() or not can_process():
		return
	var per_bar := ConductorClock.SUBDIVISIONS * ConductorClock.BEATS_PER_BAR
	var in_bar := posmod(index, per_bar)
	if in_bar % ConductorClock.SUBDIVISIONS == 0:
		_hop = 1.0
	# Un beat antes del tiempo fuerte: elige y anuncia el patrón del compás siguiente.
	if in_bar == per_bar - ConductorClock.SUBDIVISIONS:
		_bars_since_volley += 1
		if _bars_since_volley >= bars_between_volleys and _player_in_range():
			_bars_since_volley = 0
			choose_pattern(PATTERNS.keys()[rng.rand_weighted(pattern_weights)])
		return
	if current_pattern != &"" and _throws.has(in_bar):
		_throw()
		_throws_done += 1
		if _throws_done >= _throws.size():
			current_pattern = &""


func choose_pattern(pattern: StringName) -> void:
	current_pattern = pattern
	_throws = PATTERNS.get(pattern, [0])
	_throws_done = 0


## Velocidad inicial para caer en `to` tras `flight_seconds`.
func throw_velocity(from: Vector2, to: Vector2) -> Vector2:
	var t := flight_seconds
	return Vector2((to.x - from.x) / t, (to.y - from.y) / t - 0.5 * PotatoProjectile.GRAVITY * t)


func _throw() -> void:
	var origin := global_position + Vector2(facing * 20.0, -body_radius * 2.0 - 16.0)
	var spread := (_throws_done - (_throws.size() - 1) * 0.5) * volley_spread
	var aim := target.global_position + Vector2(spread, -PlayerPrototype.SIZE.y * 0.5)
	projectile_requested.emit(origin, throw_velocity(origin, aim))
	scale = Vector2(0.85, 1.2)


func _player_in_range() -> bool:
	return global_position.distance_to(target.global_position) <= throw_range


func _update_visuals(delta: float) -> void:
	_hop = maxf(_hop - delta * 6.0, 0.0)


## Saltito al ritmo, solo visual.
func _draw_offset() -> Vector2:
	return Vector2(0.0, -10.0 * _hop)


func _draw_after_body(center: Vector2) -> void:
	if _dying:
		return
	# Gorro de chef.
	var hat := Rect2(center + Vector2(-18.0, -body_radius - 16.0), Vector2(36.0, 20.0))
	draw_circle(center + Vector2(0.0, -body_radius - 18.0), 14.0, Color("f4efe6"))
	draw_rect(hat, Color("f4efe6"))
	draw_rect(hat, _outline(), false, 2.0)
	# Brazo con papa frita: en alto mientras hay un patrón anunciado.
	var arm_up := current_pattern != &""
	var hand := center + Vector2(facing * 40.0, -48.0 if arm_up else -4.0)
	draw_line(center + Vector2(facing * 24.0, -8.0), hand, FACE_COLOR, 5.0)
	draw_rect(Rect2(hand + Vector2(-4.0, -14.0), Vector2(8.0, 20.0)), Color("f2c14e"))
	if arm_up:
		# Puntos de aviso: uno por lanzamiento del patrón anunciado.
		for i in _throws.size():
			var dot := center + Vector2((i - (_throws.size() - 1) * 0.5) * 14.0, -body_radius - 46.0)
			draw_circle(dot, 6.0, _outline())
			draw_circle(dot, 5.0, Color("ff5a4a"))
