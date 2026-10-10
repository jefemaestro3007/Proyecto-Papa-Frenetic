extends SceneTree
## Tests de la topología del edificio de oficinas. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_oficinas_layout.gd

const SEEDS := 60

var _failures := 0
var _fail_groups := {}
var _stats := {"layouts": 0, "repairs": 0, "isolated": 0, "nodes": 0, "with_choices": 0, "choice_cases": 0, "sealed": 0}


func _initialize() -> void:
	_test_determinism()
	for config in _configs():
		_test_config(config)
	for key in _fail_groups:
		printerr("  FALLO x%d: %s" % [_fail_groups[key], key])
	print("test_oficinas_layout: %s · %d edificios · reparaciones prom. %.1f · sellados prom. %.1f · aislados %.2f%% · con alternativas %d/%d" % [
		"OK" if _failures == 0 else "%d FALLOS" % _failures, _stats.layouts,
		float(_stats.repairs) / maxi(_stats.layouts, 1), float(_stats.sealed) / maxi(_stats.layouts, 1),
		100.0 * _stats.isolated / maxi(_stats.nodes, 1), _stats.with_choices, _stats.choice_cases])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		var key := message.get_slice(" seed=", 0) + " |" + message.get_slice(":", message.get_slice_count(":") - 1)
		_fail_groups[key] = _fail_groups.get(key, 0) + 1


func _configs() -> Array:
	var out := []
	for mode in [OficinasParams.EndMode.ARRIBA, OficinasParams.EndMode.ABAJO, OficinasParams.EndMode.DISTANCIA]:
		for shape in [Vector2i(8, 8), Vector2i(2, 3), Vector2i(16, 6), Vector2i(5, 12)]:
			var p := OficinasParams.new()
			p.end_mode = mode
			p.floors = shape.x
			p.modules = shape.y
			p.start_floor = shape.x / 3
			p.floor_distance = -2 if shape.x > 4 else 1
			out.append(p)
	# Casos extremos: mucho daño, muros casi todos bloqueados, sin ascensores, sin rutas extra.
	var harsh := OficinasParams.new()
	harsh.collapse_chance = 0.4
	harsh.gap_chance = 0.3
	harsh.wall_blocked_weight = 4.0
	harsh.wall_open_weight = 0.0
	out.append(harsh)
	var no_lifts := OficinasParams.new()
	no_lifts.elevator_weight = 0.0
	no_lifts.extra_elevators = 0.0
	no_lifts.branches = 0
	out.append(no_lifts)
	var only_lifts := OficinasParams.new()
	only_lifts.stairs_weight = 0.0
	only_lifts.fall_weight = 0.0
	only_lifts.extra_stairs = 0.0
	only_lifts.elevator_express_weight = 3.0
	out.append(only_lifts)
	var loose := OficinasParams.new()
	loose.reach_everything = false
	loose.collapse_chance = 0.25
	out.append(loose)
	return out


func _test_config(params: OficinasParams) -> void:
	var label := "pisos=%d módulos=%d modo=%d" % [params.floors, params.modules, params.end_mode]
	var expected := params.start_and_end_floor()
	for s in range(1, SEEDS + 1):
		params.seed = s
		var layout := OficinasLayout.build(params)
		_stats.layouts += 1
		_stats.repairs += layout.repairs
		var tag := "%s seed=%d" % [label, s]
		_check(layout.valid, "%s: inválido" % tag)
		if not layout.valid:
			continue
		_check(layout.start.x == expected.x and layout.end.x == expected.y, "%s: pisos de inicio/fin" % tag)
		_check(layout.reachable_from(layout.start).has(layout.end), "%s: salida inalcanzable" % tag)
		# Sin trampas en NINGÚN lugar del edificio (aunque se llegue con un salto potenciado).
		_check(layout.traps().is_empty(), "%s: trampas %s" % [tag, layout.traps()])
		for node in [layout.start, layout.end]:
			_check(layout.cell(node.x, node.y) == OficinasLayout.Cell.NORMAL, "%s: inicio/fin no normal" % tag)
		for c in layout.modules:
			_check(not layout.is_void(0, c), "%s: vacío en planta baja" % tag)
		var all_nodes := layout.nodes()
		_stats.nodes += all_nodes.size()
		_stats.isolated += layout.isolated().size()
		_stats.sealed += layout.sealed_count
		if params.reach_everything:
			_check(layout.isolated().is_empty(), "%s: zonas inalcanzables %s" % [tag, layout.isolated()])
		if params.branches > 0 and params.floors >= 4 and params.modules >= 5:
			_stats.choice_cases += 1
			if layout.useful_vertical_links() > layout.main_transitions:
				_stats.with_choices += 1


func _test_determinism() -> void:
	var params := OficinasParams.new()
	params.seed = 77
	var a := OficinasLayout.build(params)
	var b := OficinasLayout.build(params)
	_check(a.cells == b.cells and a.walls == b.walls and a.stair_dirs == b.stair_dirs,
			"misma seed => mismo edificio")
