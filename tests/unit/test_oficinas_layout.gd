extends SceneTree
## Tests de la topología del edificio de oficinas. Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_oficinas_layout.gd

const SEEDS := 60

var _failures := 0
var _fail_groups := {}
var _stats := {"layouts": 0, "repairs": 0, "isolated": 0, "nodes": 0, "with_choices": 0, "choice_cases": 0, "sealed": 0, "keys": 0, "corridors": 0}


func _initialize() -> void:
	_test_determinism()
	for config in _configs():
		_test_config(config)
	_test_random_configs(200)
	for key in _fail_groups:
		printerr("  FALLO x%d: %s" % [_fail_groups[key], key])
	print("test_oficinas_layout: %s · %d edificios · reparaciones prom. %.1f · sellados prom. %.1f · aislados %.2f%% · con alternativas %d/%d" % [
		"OK" if _failures == 0 else "%d FALLOS" % _failures, _stats.layouts,
		float(_stats.repairs) / maxi(_stats.layouts, 1), float(_stats.sealed) / maxi(_stats.layouts, 1),
		100.0 * _stats.isolated / maxi(_stats.nodes, 1), _stats.with_choices, _stats.choice_cases])
	print("  llaves por edificio %.2f · pasillos al fondo por edificio %.2f" % [
		float(_stats.keys) / maxi(_stats.layouts, 1), float(_stats.corridors) / maxi(_stats.layouts, 1)])
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
		# Con llaves: ningún estado (lugar × llaves) alcanzable se queda sin salida.
		_check(layout.state_traps().is_empty(), "%s: atasco por llaves" % tag)
		_check_depth_and_keys(layout, tag)
		_stats.keys += layout.keys.size()
		_stats.corridors += layout.depth_doors.filter(func(d) -> bool: return d.kind == OficinasLayout.Depth.CORRIDOR).size() / 2
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


## Configuraciones aleatorias (tamaño, modo, pesos, daño): todas deben ser válidas y sin trampas.
func _test_random_configs(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in count:
		var p := OficinasParams.new()
		p.seed = 1000 + i
		p.floors = rng.randi_range(2, 14)
		p.modules = rng.randi_range(3, 12)
		p.end_mode = rng.randi_range(0, 2) as OficinasParams.EndMode
		p.start_floor = rng.randi_range(0, p.floors - 1)
		p.floor_distance = rng.randi_range(-p.floors, p.floors)
		p.stairs_weight = rng.randf_range(0.0, 2.0)
		p.elevator_weight = rng.randf_range(0.0, 2.0)
		p.fall_weight = rng.randf_range(0.0, 2.0)
		p.collapse_chance = rng.randf_range(0.0, 0.3)
		p.gap_chance = rng.randf_range(0.0, 0.3)
		p.wall_blocked_weight = rng.randf_range(0.0, 3.0)
		p.branches = rng.randi_range(0, 4)
		var layout := OficinasLayout.build(p)
		_stats.layouts += 1
		var tag := "aleatoria seed=%d" % p.seed
		_check(layout.valid, "%s: inválido" % tag)
		_check(layout.reachable_from(layout.start).has(layout.end), "%s: salida inalcanzable" % tag)
		_check(layout.traps().is_empty(), "%s: trampas" % tag)
		_check(layout.state_traps().is_empty(), "%s: atasco por llaves" % tag)
		_check_depth_and_keys(layout, tag)


## Pasillos al fondo enlazados en ambos sentidos; llaves en nodos válidos y, si están en una
## habitación, esa habitación existe en su módulo.
func _check_depth_and_keys(layout: OficinasLayout, tag: String) -> void:
	for i in layout.depth_doors.size():
		var door: OficinasLayout.DepthDoor = layout.depth_doors[i]
		if door.kind == OficinasLayout.Depth.CORRIDOR:
			_check(door.partner >= 0 and layout.depth_doors[door.partner].partner == i, "%s: pasillo mal enlazado" % tag)
		if door.kind != OficinasLayout.Depth.NONE:
			_check(layout.depth_at[layout.index(door.floor, door.module)] == i, "%s: puerta al fondo perdida" % tag)
	for key in layout.keys:
		_check(layout.is_node(key.node.x, key.node.y), "%s: llave fuera del mapa" % tag)
		if key.door >= 0:
			var room: OficinasLayout.DepthDoor = layout.depth_doors[key.door]
			_check(room.kind == OficinasLayout.Depth.ROOM and Vector2i(room.floor, room.module) == key.node,
					"%s: habitación de la llave" % tag)


func _test_determinism() -> void:
	var params := OficinasParams.new()
	params.seed = 77
	var a := OficinasLayout.build(params)
	var b := OficinasLayout.build(params)
	_check(a.cells == b.cells and a.walls == b.walls and a.stair_up == b.stair_up and a.depth_at == b.depth_at
			and a.wall_key == b.wall_key, "misma seed => mismo edificio")
