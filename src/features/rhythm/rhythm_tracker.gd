class_name RhythmTracker
extends Node
## Juzga acciones contra el Conductor y lleva combo y puntaje.
## Seguir el ritmo suma; fallar una acción intencional rompe el combo.

signal judged(action: StringName, judgment: int, combo: int, points: int)
signal combo_broken(action: StringName, lost_combo: int)

const POINTS := {ConductorClock.Judgment.PERFECT: 100, ConductorClock.Judgment.GOOD: 50}

var combo := 0
var best_combo := 0
var score := 0
var _last_hit_beat := 0


func _ready() -> void:
	Conductor.beat.connect(_on_beat)


## Registra una acción. `can_break` = false para acciones no del todo intencionales
## (p. ej. aterrizar normal): pueden premiar pero nunca castigar.
func register(action: StringName, can_break: bool = true,
		points_scale: float = 1.0) -> ConductorClock.Judgment:
	return register_judgment(action, Conductor.judge(), can_break, points_scale)


## Como `register`, pero con un juicio ya tomado (p. ej. el dash se juzga al iniciarlo y
## cuenta recién cuando atraviesa a una papa).
func register_judgment(action: StringName, judgment: ConductorClock.Judgment, can_break: bool = true,
		points_scale: float = 1.0) -> ConductorClock.Judgment:
	var points := 0
	if judgment == ConductorClock.Judgment.MISS:
		if can_break and combo > 0:
			var lost := combo
			combo = 0
			combo_broken.emit(action, lost)
	else:
		combo += 1
		best_combo = maxi(best_combo, combo)
		points = roundi(POINTS[judgment] * multiplier() * points_scale)
		score += points
		_last_hit_beat = Conductor.beat_index()
	judged.emit(action, judgment, combo, points)
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


func _on_beat(index: int) -> void:
	if combo > 0 and index - _last_hit_beat > Conductor.params.combo_timeout_beats:
		combo = 0
