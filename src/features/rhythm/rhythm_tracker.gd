class_name RhythmTracker
extends Node
## Juzga acciones contra el Conductor y lleva combo y puntaje.
## Dos tipos de acción:
## - Golpes (atacar, stomp o dash contra una papa): a tiempo suben el combo y dan puntos con
##   multiplicador. Son la fuente principal de todo.
## - Movimientos (saltar, girar, aterrizar, escaleras, puertas, caer sin papa debajo): a tiempo
##   solo mantienen vivo el combo (no suman) y dan pocos puntos fijos; como el jugador siempre
##   puede moverse, moverse bien evita perderlo por inactividad.
## Fallar una acción intencional (de cualquier tipo) rompe el combo.

## `hit` = true para golpes, false para movimientos.
signal judged(action: StringName, judgment: int, combo: int, points: int, hit: bool)
signal combo_broken(action: StringName, lost_combo: int)

const POINTS := {ConductorClock.Judgment.PERFECT: 100, ConductorClock.Judgment.GOOD: 50}
const MOVE_POINTS := {ConductorClock.Judgment.PERFECT: 10, ConductorClock.Judgment.GOOD: 5}

var combo := 0
var best_combo := 0
var score := 0
## Último beat con una acción a tiempo (golpe o movimiento): el combo vence desde ahí.
var _last_kept_beat := 0


func _ready() -> void:
	Conductor.beat.connect(_on_beat)


## Registra un golpe a una papa. `can_break` = false para acciones que pueden premiar pero nunca
## castigar.
func register(action: StringName, can_break: bool = true,
		points_scale: float = 1.0) -> ConductorClock.Judgment:
	return register_judgment(action, Conductor.judge(), can_break, points_scale)


## Como `register`, pero con un juicio ya tomado (p. ej. el dash se juzga al iniciarlo y
## cuenta recién cuando atraviesa a una papa).
func register_judgment(action: StringName, judgment: ConductorClock.Judgment, can_break: bool = true,
		points_scale: float = 1.0) -> ConductorClock.Judgment:
	return _register(action, judgment, can_break, points_scale, true)


## Registra un movimiento: a tiempo mantiene el combo sin sumar.
func register_move(action: StringName, can_break: bool = true) -> ConductorClock.Judgment:
	return register_move_judgment(action, Conductor.judge(), can_break)


func register_move_judgment(action: StringName, judgment: ConductorClock.Judgment,
		can_break: bool = true) -> ConductorClock.Judgment:
	return _register(action, judgment, can_break, 1.0, false)


func _register(action: StringName, judgment: ConductorClock.Judgment, can_break: bool,
		points_scale: float, hit: bool) -> ConductorClock.Judgment:
	var points := 0
	if judgment == ConductorClock.Judgment.MISS:
		if can_break:
			break_combo(action)
	else:
		_last_kept_beat = Conductor.beat_index()
		if hit:
			combo += 1
			best_combo = maxi(best_combo, combo)
			points = roundi(POINTS[judgment] * multiplier() * points_scale)
		else:
			points = MOVE_POINTS[judgment]
		score += points
	judged.emit(action, judgment, combo, points, hit)
	return judgment


## Pierde el combo por un motivo ajeno a una acción juzgada (p. ej. recibir un golpe).
func break_combo(action: StringName) -> void:
	if combo > 0:
		var lost := combo
		combo = 0
		combo_broken.emit(action, lost)


func multiplier() -> int:
	return 1 + mini(combo / 8, 3)


## 0..1 según qué tan "encendido" está el combo; lo usan sol, luz y efectos.
func heat() -> float:
	return clampf(combo / 24.0, 0.0, 1.0)


func reset() -> void:
	combo = 0
	best_combo = 0
	score = 0
	_last_kept_beat = Conductor.beat_index()


func _on_beat(index: int) -> void:
	if combo > 0 and index - _last_kept_beat > Conductor.params.combo_timeout_beats:
		combo = 0
