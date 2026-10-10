extends Node
## Recorre tiendas reales de Bienestar U con física: el bot juega con los controles del jugador
## hasta la salida (saltando pallets, cajas y escombros de racks, tomando escaleras mecánicas a
## favor o a contramano, esperando cortinas y saltando huecos del atrio). Verifica que toda tienda
## generada se pueda terminar. Corre como escena (necesita el autoload Conductor). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/bienestar_traversal.tscn
## Opcional: -- --cases=N limita la cantidad de casos; -- --extra=N agrega N tiendas aleatorias.

const SCENE := "res://src/world/levels/bienestar/supermercado.tscn"
const CAMPAIGN_SCENES: Array[String] = [
	"res://src/world/levels/bienestar/supermercado.tscn",
	"res://src/world/levels/bienestar/centro_comercial.tscn",
]
## Tiempo de juego máximo por tienda.
const LIMIT_SECONDS := 300.0

var _cases := []
var _index := -1
var _level: Node
var _elapsed := 0.0
var _passed := 0
var _failed: Array[String] = []
var _times: Array[float] = []


func _ready() -> void:
	Settings.use_defaults()
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
	# Las de la campaña (3-1 y 3-2), tal cual están en sus escenas.
	for path in CAMPAIGN_SCENES:
		var level: Node = load(path).instantiate()
		out.append(level.params.duplicate())
		level.free()
	for mode in [BienestarParams.Mode.SUPERMARKET, BienestarParams.Mode.MALL]:
		for s in range(1, 9):
			var p := BienestarParams.new()
			p.seed = s
			p.mode = mode
			out.append(p)
	# Casos exigentes: muchos racks y charcos; una sola escalera por piso y muchos pisos; cortinas
	# y huecos por todos lados.
	var racks := BienestarParams.new()
	racks.rack_chance = 1.0
	racks.wet_weight = 3.0
	racks.sections = 12
	var tall := BienestarParams.new()
	tall.mode = BienestarParams.Mode.MALL
	tall.floors = 5
	tall.escalators_per_floor = 1
	var closed := BienestarParams.new()
	closed.mode = BienestarParams.Mode.MALL
	closed.shutter_chance = 1.0
	closed.hole_chance = 1.0
	for s in range(1, 4):
		for base in [racks, tall, closed]:
			var p: BienestarParams = base.duplicate()
			p.seed = 100 + s
			out.append(p)
	return out


func _random_cases(count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2025
	var out := []
	for i in count:
		var p := BienestarParams.new()
		p.seed = 1000 + i
		p.mode = rng.randi_range(0, 1)
		p.sections = rng.randi_range(3, 12)
		p.floors = rng.randi_range(2, 5)
		p.escalators_per_floor = rng.randi_range(1, 3)
		p.rack_chance = rng.randf()
		p.shutter_chance = rng.randf()
		p.hole_chance = rng.randf()
		p.checkouts = rng.randi_range(1, 8)
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
	# El bot solo recorre: sin calor (la papa explotaría) ni enemigos.
	var combat := CombatParams.new()
	combat.heat_enabled = false
	combat.enemy_density = 0.0
	_level.combat = combat
	_level.autorun = true
	_level.set("_hide_menu", true)
	add_child(_level)


func _process(delta: float) -> void:
	if _level == null:
		return
	_elapsed += delta
	var p: BienestarParams = _cases[_index]
	if _level.goals_reached > 0:
		_passed += 1
		_times.append(_elapsed)
		_next_case()
	elif _elapsed > LIMIT_SECONDS:
		var player: Node2D = _level.get("_player")
		var bot: BienestarBot = _level.get("_bot")
		var data: BienestarMapData = _level.get("_data")
		_failed.append("seed=%d modo=%d secciones=%d pisos=%d → atascado en %v (piso %d) · %s" % [
			p.seed, p.mode, p.sections, p.floors, player.position.round(), data.floor_at(player.position), bot.status])
		_next_case()


func _finish() -> void:
	for line in _failed:
		printerr("  FALLO: ", line)
	var average := 0.0
	for t in _times:
		average += t
	average /= maxf(_times.size(), 1.0)
	print("test_bienestar_traversal: %s · %d/%d tiendas completadas · tiempo de juego prom. %.0f s" % [
		"OK" if _failed.is_empty() else "%d FALLOS" % _failed.size(), _passed, _cases.size(), average])
	get_tree().quit(0 if _failed.is_empty() else 1)
