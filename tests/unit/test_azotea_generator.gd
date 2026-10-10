extends SceneTree
## Tests de AzoteaGenerator. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_azotea_generator.gd

const SEEDS := 300

var _failures := 0


func _initialize() -> void:
	_test_same_seed_same_map()
	_test_invariants_across_seeds()
	print("test_azotea_generator: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLO: ", message)


func _test_same_seed_same_map() -> void:
	var params := AzoteaParams.new()
	params.seed = 4242
	var a := AzoteaGenerator.generate(params)
	var b := AzoteaGenerator.generate(params)
	_check(a.roofs == b.roofs, "misma seed => mismas azoteas")
	_check(a.far.buildings == b.far.buildings, "misma seed => mismo skyline lejano")
	_check(a.near.windows == b.near.windows, "misma seed => mismas ventanas")


func _test_invariants_across_seeds() -> void:
	var params := AzoteaParams.new()
	for s in range(1, SEEDS + 1):
		params.seed = s
		var data := AzoteaGenerator.generate(params)
		var first := data.roofs[0]
		_check(data.spawn.x > first.position.x and data.spawn.x < first.end.x,
				"seed %d: spawn fuera de la primera azotea" % s)
		for i in range(1, data.roofs.size()):
			var step := data.roofs[i - 1].position.y - data.roofs[i].position.y
			_check(step <= params.max_step + 0.01, "seed %d: escalón %.0f > max_step" % [s, step])
		for layer in [data.far, data.near]:
			for outline in layer.buildings:
				if Geometry2D.triangulate_polygon(outline).is_empty():
					_check(false, "seed %d: silueta no triangulable" % s)
