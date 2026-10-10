extends SceneTree
## Medidor de calor (papa caliente): calor pasivo, enfriar/calentar por juicio, mecha que no se
## recarga, explosión y modo sin game over. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_heat_meter.gd

var _failures := 0


func _initialize() -> void:
	_test_passive_and_judgments()
	_test_movement_cannot_sustain()
	_test_fuse_does_not_refill()
	_test_explodes_and_no_game_over()
	_test_disabled()
	print("test_heat_meter: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _meter() -> HeatMeter:
	var meter := HeatMeter.new()
	meter.params = CombatParams.new()
	meter.reset()
	return meter


func _test_passive_and_judgments() -> void:
	var meter := _meter()
	meter.advance(10.0)
	_check(is_equal_approx(meter.heat, 10.0), "calor pasivo 1/s: %f" % meter.heat)
	meter.apply_judgment(ConductorClock.Judgment.PERFECT)
	_check(is_equal_approx(meter.heat, 2.0), "PERFECTO enfría 8: %f" % meter.heat)
	meter.apply_judgment(ConductorClock.Judgment.GOOD)
	_check(is_equal_approx(meter.heat, 0.0), "no baja de 0: %f" % meter.heat)
	meter.apply_judgment(ConductorClock.Judgment.MISS)
	_check(is_equal_approx(meter.heat, 10.0), "FUERA calienta 10: %f" % meter.heat)
	meter.apply_judgment(ConductorClock.Judgment.MISS, 0.25)
	_check(is_equal_approx(meter.heat, 12.5), "moverse pesa 0.25: %f" % meter.heat)
	meter.apply_judgment(ConductorClock.Judgment.MISS, 1.0, false)
	_check(is_equal_approx(meter.heat, 12.5), "acciones que solo enfrían no calientan: %f" % meter.heat)
	meter.change(50.0)
	_check(is_equal_approx(meter.intensity(), (62.5 - 50.0) / 50.0), "intensidad desde 50: %f" % meter.intensity())
	meter.free()


## Solo moviéndose a tiempo (todo PERFECTO, a cualquier ritmo) el calor igual sube.
func _test_movement_cannot_sustain() -> void:
	var meter := _meter()
	meter.change(50.0)
	for second in 60:
		for i in 6:
			meter.advance(1.0 / 6.0)
			meter.cool_movement(ConductorClock.Judgment.PERFECT)
	var floor_rate := meter.params.passive_heating * (1.0 - meter.params.movement_cooling_share)
	_check(meter.heat >= 50.0 + 60.0 * floor_rate - 2.5,
			"moverse a tiempo no salva: %f tras 60 s" % meter.heat)
	_check(meter.heat < 50.0 + 60.0, "pero frena el calor: %f" % meter.heat)
	var before := meter.heat
	meter.advance(2.0)
	var cooled := meter.cool_movement(ConductorClock.Judgment.PERFECT)
	_check(is_equal_approx(cooled, -meter.params.movement_cooling_perfect), "un movimiento enfría lo suyo: %f" % cooled)
	_check(meter.cool_movement(ConductorClock.Judgment.MISS) == 0.0, "fallar no enfría")
	_check(meter.heat > before, "con tope: %f → %f" % [before, meter.heat])
	meter.free()


func _test_fuse_does_not_refill() -> void:
	var meter := _meter()
	meter.change(100.0)
	_check(meter.overheated, "a 100 se enciende la mecha")
	meter.advance(3.0)
	_check(is_equal_approx(meter.fuse_left, 7.0), "la mecha se consume: %f" % meter.fuse_left)
	meter.apply_judgment(ConductorClock.Judgment.PERFECT)
	_check(not meter.overheated, "un acierto la apaga")
	meter.change(100.0)
	_check(meter.overheated and is_equal_approx(meter.fuse_left, 7.0), "no se recarga: %f" % meter.fuse_left)
	# El tiempo que sobra tras llegar a 100 ya quema la mecha.
	var other := _meter()
	other.change(95.0)
	other.advance(7.0)
	_check(other.overheated and is_equal_approx(other.fuse_left, 8.0), "sobrante quema mecha: %f" % other.fuse_left)
	meter.free()
	other.free()


func _test_explodes_and_no_game_over() -> void:
	var meter := _meter()
	var exploded := [0]
	meter.exploded.connect(func() -> void: exploded[0] += 1)
	meter.change(100.0)
	meter.advance(11.0)
	_check(exploded[0] == 1 and meter.finished, "explota al agotarse la mecha")
	meter.change(-50.0)
	_check(is_equal_approx(meter.heat, 100.0), "terminada, ya no cambia")
	meter.params.game_over_enabled = false
	meter.reset()
	meter.change(100.0)
	meter.advance(11.0)
	_check(exploded[0] == 2 and not meter.finished and meter.heat == 0.0, "sin game over el calor reinicia")
	meter.free()


func _test_disabled() -> void:
	var meter := _meter()
	meter.params.heat_enabled = false
	meter.advance(50.0)
	meter.apply_judgment(ConductorClock.Judgment.MISS)
	_check(meter.heat == 0.0, "desactivado no cambia")
	meter.free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)
