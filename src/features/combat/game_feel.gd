class_name GameFeel
extends Node
## "Jugo" de los golpes (del prototipo): hitstop, zoom de impacto, temblor por trauma y la tensión
## del calor (temblor y balanceo continuos de la cámara desde el umbral de intensidad).
## La zona decide cuándo; este nodo calcula cómo se mueve la cámara y congela el tiempo.
## El hitstop lo aplica el Conductor (`set_hitstop`), que lo compensa: los beats no se mueven.

const HITSTOP_TIME_SCALE := 0.05
const MAX_SHAKE := 42.0
const TRAUMA_DECAY := 1.7
const ZOOM_DECAY := 9.0
## Temblor por calor (50 % más fuerte que el del prototipo: el calor alto tiene que notarse).
const TENSION_SHAKE := 13.5
const TENSION_JITTER := 5.25
const TENSION_SWAY_DEGREES := 1.95
## Durante la mecha todo se mueve más.
const OVERHEAT_MULTIPLIER := 1.7

var params := CombatParams.new()
var rng := RandomNumberGenerator.new()

var _trauma := 0.0
var _zoom_kick := 0.0
var _intensity := 0.0
var _overheated := false
var _beat_kick := 0.0
var _time := 0.0
var _hitstop_serial := 0
var _in_hitstop := false
var _offset := Vector2.ZERO
var _rotation := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	_end_hitstop()


func _process(delta: float) -> void:
	# Tiempo real: el temblor sigue vivo durante el hitstop.
	var real := delta / maxf(Engine.time_scale, 0.001)
	_time += real
	_trauma = maxf(_trauma - TRAUMA_DECAY * real, 0.0)
	_zoom_kick = move_toward(_zoom_kick, 0.0, _zoom_kick * ZOOM_DECAY * real + 0.0005)
	_beat_kick = maxf(_beat_kick - real * 6.0, 0.0)
	var power := _trauma * _trauma
	_offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * MAX_SHAKE * power
	var tension := tension_strength()
	_rotation = 0.0
	if tension > 0.0:
		var t := _time
		var sway := Vector2(sin(t * 7.3) + 0.5 * sin(t * 17.1), cos(t * 6.1) + 0.5 * sin(t * 13.7)) * TENSION_SHAKE
		var jitter := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * TENSION_JITTER
		_offset += (sway + jitter) * tension * (1.0 + 0.8 * _beat_kick)
		_rotation = sin(t * 1.9) * deg_to_rad(TENSION_SWAY_DEGREES) * tension


## Desplazamiento de cámara a sumar este frame.
func camera_offset() -> Vector2:
	return _offset


func camera_rotation() -> float:
	return _rotation


## Multiplicador del zoom de cámara (1 = sin golpe).
func zoom_factor() -> float:
	return 1.0 + _zoom_kick


## Intensidad 0-1 del calor (desde el umbral de tensión) y si la mecha está encendida.
func set_intensity(intensity: float, overheated: bool) -> void:
	_intensity = clampf(intensity, 0.0, 1.0)
	_overheated = overheated


func tension_strength() -> float:
	return _intensity * (OVERHEAT_MULTIPLIER if _overheated else 1.0) * params.tension_shake_scale


## Cada beat da un empujón extra al temblor cuando hay tensión.
func on_beat(strength: float) -> void:
	if _intensity > 0.0:
		_beat_kick = clampf(strength, 0.0, 2.0)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * params.trauma_scale, 0.0, 1.0)


func zoom_punch(amount: float) -> void:
	_zoom_kick = maxf(_zoom_kick, amount * params.zoom_punch_scale)


func hitstop(seconds: float) -> void:
	var duration := seconds * params.hitstop_scale
	if not params.hitstop_enabled or duration <= 0.0 or not is_inside_tree():
		return
	_hitstop_serial += 1
	var serial := _hitstop_serial
	_in_hitstop = true
	Conductor.set_hitstop(HITSTOP_TIME_SCALE)
	await get_tree().create_timer(duration, true, false, true).timeout
	if serial == _hitstop_serial:
		_end_hitstop()


## Golpe a un enemigo: trauma, zoom y hitstop según fuerza (PERFECTO pega más).
func hit(perfect: bool, defeated: bool) -> void:
	if defeated:
		add_trauma(0.55 if perfect else 0.38)
		zoom_punch(0.07 if perfect else 0.035)
		hitstop(0.09 if perfect else 0.05)
	else:
		# Papa que aguanta: chispazo seco, menos pausa.
		add_trauma(0.32 if perfect else 0.22)
		zoom_punch(0.02)
		hitstop(0.05 if perfect else 0.035)


func hurt() -> void:
	add_trauma(0.6)
	hitstop(0.06)


func explosion() -> void:
	_end_hitstop()
	add_trauma(1.0)
	zoom_punch(0.18)


func reset() -> void:
	_end_hitstop()
	_trauma = 0.0
	_zoom_kick = 0.0
	_intensity = 0.0
	_overheated = false
	_beat_kick = 0.0


func _end_hitstop() -> void:
	_hitstop_serial += 1
	if _in_hitstop:
		_in_hitstop = false
		Conductor.set_hitstop(1.0)
