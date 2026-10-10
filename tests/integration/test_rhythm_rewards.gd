extends Node
## Verifica cómo se recompensa cada tipo de acción (`RhythmTracker`). Corre como escena
## (necesita el autoload Conductor). Ejecutar:
##   godot --headless --path . res://tests/test_scenes/rhythm_rewards.tscn

const PERFECT := ConductorClock.Judgment.PERFECT
const GOOD := ConductorClock.Judgment.GOOD
const MISS := ConductorClock.Judgment.MISS

var _failures := 0


func _ready() -> void:
	# Sin la configuración guardada del jugador (volúmenes, teclas, dificultad).
	Settings.use_defaults()
	var tracker := RhythmTracker.new()
	add_child(tracker)
	var timeout := Conductor.params.combo_timeout_beats
	var beat := Conductor.beat_index()

	tracker.register_judgment(&"attack", PERFECT)
	tracker.register_judgment(&"attack", GOOD)
	_check(tracker.combo == 2 and tracker.score == 150, "los golpes suben el combo: %d, %d pts" % [tracker.combo, tracker.score])
	tracker.register_move_judgment(&"jump", PERFECT)
	tracker.register_move_judgment(&"turn", GOOD)
	_check(tracker.combo == 2, "moverse no suma al combo: %d" % tracker.combo)
	_check(tracker.score == 165, "moverse da pocos puntos fijos: %d" % tracker.score)

	# Moverse a tiempo mantiene vivo el combo más allá del límite de inactividad.
	for i in range(1, timeout * 3):
		if i % 2 == 0:
			tracker.register_move_judgment(&"jump", PERFECT)
			tracker.set("_last_kept_beat", beat + i)
		tracker._on_beat(beat + i)
	_check(tracker.combo == 2, "moverse a tiempo mantiene el combo: %d" % tracker.combo)
	var last: int = tracker.get("_last_kept_beat")
	tracker._on_beat(last + timeout + 1)
	_check(tracker.combo == 0, "sin acciones a tiempo el combo vence")

	tracker.register_judgment(&"attack", PERFECT)
	tracker.register_move_judgment(&"land", MISS, false)
	_check(tracker.combo == 1, "aterrizar fuera de ritmo no castiga")
	tracker.register_move_judgment(&"jump", MISS)
	_check(tracker.combo == 0, "saltar fuera de ritmo rompe el combo")

	print("test_rhythm_rewards: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)
