extends SceneTree
## Tests de AzoteaGenerator. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_azotea_generator.gd

const SEEDS := 300

var _failures := 0


func _initialize() -> void:
	_test_same_seed_same_map()
	_test_invariants_across_seeds()
	_test_details()
	_test_windows_inside_buildings()
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


func _test_details() -> void:
	var params := AzoteaParams.new()
	for s in range(1, 101):
		params.seed = s
		params.detail_density = 0.55
		var data := AzoteaGenerator.generate(params)
		var last_end := {}
		for prop in data.props:
			var roof := data.roofs[prop.roof_index]
			_check(prop.rect.position.x >= roof.position.x and prop.rect.end.x <= roof.end.x,
					"seed %d: objeto fuera de su azotea" % s)
			_check(is_equal_approx(prop.rect.end.y, roof.position.y), "seed %d: objeto no apoyado" % s)
			_check(prop.rect.position.x >= last_end.get(prop.roof_index, -INF),
					"seed %d: objetos solapados" % s)
			last_end[prop.roof_index] = prop.rect.end.x
		for mark in data.marks:
			var inside := false
			for roof in data.roofs:
				inside = inside or (mark.position.x >= roof.position.x and mark.position.x <= roof.end.x)
			_check(inside, "seed %d: marca fuera de las azoteas" % s)
		# Los detalles usan su propio RNG: la densidad no debe cambiar el trazado.
		params.detail_density = 1.0
		_check(AzoteaGenerator.generate(params).roofs == data.roofs,
				"seed %d: la densidad de detalles alteró las azoteas" % s)


func _test_windows_inside_buildings() -> void:
	var params := AzoteaParams.new()
	params.ruin = 1.0
	for s in range(1, 21):
		params.seed = s
		var data := AzoteaGenerator.generate(params)
		for layer in [data.far, data.near]:
			for window in layer.windows:
				var inside := false
				for outline in layer.buildings:
					if _sampled_inside(window, outline):
						inside = true
						break
				if not inside:
					_check(false, "seed %d: ventana fuera de su edificio en %v" % [s, window.position])
					break


## Verificación independiente del generador: muestrea una rejilla de 5x5 puntos de la ventana.
func _sampled_inside(rect: Rect2, polygon: PackedVector2Array) -> bool:
	for i in 5:
		for j in 5:
			var point := rect.position + rect.size * Vector2(i / 4.0, j / 4.0)
			if not Geometry2D.is_point_in_polygon(point, polygon):
				return false
	return true
