extends SceneTree
## Tests de la geometría del edificio de oficinas. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_oficinas_generator.gd

var _failures := 0
var _stats := {"areas": 0, "rooms": 0, "corridors": 0, "themes": {}}


func _initialize() -> void:
	for s in range(1, 41):
		var params := OficinasParams.new()
		params.seed = s
		params.floors = 4 + s % 8
		params.modules = 4 + s % 7
		params.room_chance = 0.4
		_test(OficinasGenerator.generate(params), "seed=%d" % s)
	print("test_oficinas_generator: %s · %d áreas (%d habitaciones, %d pasillos) · %d temas distintos" % [
		"OK" if _failures == 0 else "%d FALLOS" % _failures, _stats.areas, _stats.rooms, _stats.corridors,
		_stats.themes.size()])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		if _failures < 20:
			printerr("  FALLO: ", message)


func _test(data: OficinasMapData, tag: String) -> void:
	var layout := data.layout
	# Áreas: fuera del edificio y sin superponerse entre sí.
	for i in data.areas.size():
		var area := data.areas[i]
		_stats.areas += 1
		_stats.themes[area.theme] = true
		if area.kind == OficinasLayout.Depth.ROOM:
			_stats.rooms += 1
		else:
			_stats.corridors += 1
		_check(not area.bounds.intersects(data.bounds), "%s: área %d dentro del edificio" % [tag, i])
		for j in range(i + 1, data.areas.size()):
			_check(not area.bounds.intersects(data.areas[j].bounds), "%s: áreas %d y %d superpuestas" % [tag, i, j])
		for door in area.doors:
			_check(door.x > area.rect.position.x and door.x < area.rect.end.x, "%s: puerta fuera del área" % tag)
	# Cada puerta al fondo activa tiene su área y la área la referencia.
	for spec in data.depth_doors:
		if spec.kind == OficinasLayout.Depth.NONE:
			continue
		_check(spec.area >= 0 and spec.area < data.areas.size(), "%s: puerta al fondo sin área" % tag)
		if spec.area >= 0:
			var found := false
			for door in data.areas[spec.area].doors:
				found = found or door.depth_door == spec.id
			_check(found, "%s: el área no lleva de vuelta a su puerta" % tag)
	# Llaves en su área o en el edificio.
	for key in data.keys:
		if key.area >= 0:
			_check(data.areas[key.area].rect.has_point(key.position), "%s: llave fuera de su habitación" % tag)
		else:
			_check(data.bounds.has_point(key.position), "%s: llave fuera del edificio" % tag)
	# Escaleras dentro de su módulo y puertas entre módulos coherentes con la topología.
	for stair in data.stairs:
		var left := stair.column * data.module_width
		_check(stair.foot.x > left and stair.foot.x < left + data.module_width, "%s: escalera fuera de módulo" % tag)
	var expected_doors := 0
	for f in layout.floors:
		for c in layout.modules - 1:
			if layout.wall(f, c) in [OficinasLayout.Wall.DOOR, OficinasLayout.Wall.LOCKED]:
				expected_doors += 1
	_check(data.wall_doors.size() == expected_doors, "%s: puertas entre módulos" % tag)
