extends Node
## Recorre edificios reales con física: el bot juega con los controles del jugador hasta la
## salida. Verifica que lo que el grafo promete se pueda hacer de verdad. Corre como escena
## (necesita el autoload Conductor). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/oficinas_traversal.tscn
## Opcional: -- --cases=N limita la cantidad de casos; -- --extra=N agrega N edificios con
## tamaño, modo y conexiones aleatorios (prueba de estrés).

const SCENE := "res://src/world/levels/oficinas/oficinas.tscn"
## Tiempo de juego máximo por edificio.
const LIMIT_SECONDS := 420.0

var _cases := []
var _index := -1
var _level: Node
var _elapsed := 0.0
var _passed := 0
var _failed: Array[String] = []
var _times: Array[float] = []


func _ready() -> void:
	Conductor.params.metronome_enabled = false
	var limit := 1000
	var extra := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cases="):
			limit = arg.trim_prefix("--cases=").to_int()
		elif arg.begins_with("--extra="):
			extra = arg.trim_prefix("--extra=").to_int()
	_cases = _build_cases().slice(0, limit) + _random_cases(extra)
	_next_case()


func _build_cases() -> Array:
	var out := []
	for mode in [OficinasParams.EndMode.ARRIBA, OficinasParams.EndMode.ABAJO, OficinasParams.EndMode.DISTANCIA]:
		for s in range(1, 13):
			var p := OficinasParams.new()
			p.seed = s
			p.end_mode = mode
			p.floors = 6
			p.modules = 6
			p.start_floor = 1
			p.floor_distance = 3
			out.append(p)
	var lifts := OficinasParams.new()
	lifts.floors = 7
	lifts.stairs_weight = 0.0
	lifts.fall_weight = 0.0
	lifts.extra_stairs = 0.0
	var falls := OficinasParams.new()
	falls.end_mode = OficinasParams.EndMode.ABAJO
	falls.fall_weight = 3.0
	falls.collapse_chance = 0.2
	falls.gap_chance = 0.2
	var big := OficinasParams.new()
	big.floors = 12
	big.modules = 9
	big.branches = 4
	for s in range(1, 5):
		for base in [lifts, falls, big]:
			var p: OficinasParams = base.duplicate()
			p.seed = 100 + s
			out.append(p)
	return out


func _random_cases(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var out := []
	for i in count:
		var p := OficinasParams.new()
		p.seed = 1000 + i
		p.floors = rng.randi_range(3, 12)
		p.modules = rng.randi_range(4, 10)
		p.end_mode = rng.randi_range(0, 2) as OficinasParams.EndMode
		p.start_floor = rng.randi_range(0, p.floors - 1)
		p.floor_distance = rng.randi_range(-p.floors, p.floors)
		p.stairs_weight = rng.randf_range(0.0, 2.0)
		p.elevator_weight = rng.randf_range(0.0, 2.0)
		p.fall_weight = rng.randf_range(0.0, 2.0)
		p.collapse_chance = rng.randf_range(0.0, 0.2)
		p.gap_chance = rng.randf_range(0.0, 0.2)
		p.branches = rng.randi_range(0, 4)
		out.append(p)
	return out


func _next_case() -> void:
	if _level != null:
		_level.queue_free()
		_level = null
	_index += 1
	if _index >= _cases.size():
		_finish()
		return
	_elapsed = 0.0
	_level = load(SCENE).instantiate()
	_level.params = _cases[_index]
	_level.autorun = true
	_level.auto_next = false
	_level.set("_hide_menu", true)
	add_child(_level)


func _process(delta: float) -> void:
	if _level == null:
		return
	_elapsed += delta
	var p: OficinasParams = _cases[_index]
	if _level.goals_reached > 0:
		_passed += 1
		_times.append(_elapsed)
		_next_case()
	elif _elapsed > LIMIT_SECONDS:
		var player: Node2D = _level.get("_player")
		var bot: OficinasBot = _level.get("_bot")
		var data: OficinasMapData = _level.get("_data")
		_failed.append("seed=%d modo=%d pisos=%d módulos=%d → atascado en %v (nodo %v) · %s" % [
			p.seed, p.end_mode, p.floors, p.modules, player.position.round(), data.node_at(player.position),
			bot.status])
		_next_case()


func _finish() -> void:
	for line in _failed:
		printerr("  FALLO: ", line)
	var average := 0.0
	for t in _times:
		average += t
	average /= maxf(_times.size(), 1.0)
	print("test_oficinas_traversal: %s · %d/%d edificios completados · tiempo de juego prom. %.0f s" % [
		"OK" if _failed.is_empty() else "%d FALLOS" % _failed.size(), _passed, _cases.size(), average])
	get_tree().quit(0 if _failed.is_empty() else 1)
