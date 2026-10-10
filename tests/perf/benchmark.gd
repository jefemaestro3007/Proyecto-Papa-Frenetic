extends Node
## Benchmark de rendimiento: abre una escena real, la deja correr (con recorrido automático en las
## zonas) y reporta tiempo por frame (promedio, p95, p99, máximo), tiempo de proceso/física,
## draw calls, nodos y memoria. Sin vsync ni límite de FPS, para medir el costo real. Ejecutar
## con ventana (headless no dibuja):
##   godot --path . --quit-after 6000 res://tests/test_scenes/benchmark.tscn -- --scene=azotea --frames=1200
## `--idle` deja al jugador quieto (sin recorrido automático); `--set=propiedad=valor` cambia el mapa.

const SCENES := {
	"azotea": "res://src/world/levels/azotea/azotea.tscn",
	"oficinas": "res://src/world/levels/oficinas/oficinas.tscn",
	"supermercado": "res://src/world/levels/bienestar/supermercado.tscn",
	"centro_comercial": "res://src/world/levels/bienestar/centro_comercial.tscn",
	"menu": "res://src/ui/menus/main_menu.tscn",
}
const WARMUP := 120

var _frames := 1200
var _scene := "azotea"
var _idle := false
var _times: PackedFloat64Array = []
var _proc: PackedFloat64Array = []
var _physics: PackedFloat64Array = []
var _draws: PackedFloat64Array = []
var _last := 0
var _count := 0
var _node: Node


func _ready() -> void:
	# Sin la configuración guardada del jugador (volúmenes, teclas, dificultad).
	Settings.use_defaults()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="):
			_scene = arg.get_slice("=", 1)
		elif arg.begins_with("--frames="):
			_frames = arg.get_slice("=", 1).to_int()
		elif arg == "--idle":
			_idle = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Conductor.params.metronome_enabled = false
	var start := Time.get_ticks_usec()
	_node = load(SCENES[_scene]).instantiate()
	if _node is ZoneLevel:
		_node.autorun = not _idle
		_node.set("_hide_menu", true)
		if _node.combat == null:
			_node.combat = CombatParams.new()
		_node.combat.heat_enabled = false
	add_child(_node)
	print("benchmark %s: carga %.1f ms" % [_scene, (Time.get_ticks_usec() - start) / 1000.0])
	_last = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	_count += 1
	if _count > WARMUP:
		_times.append((now - _last) / 1000.0)
		_proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_last = now
	if _count >= WARMUP + _frames:
		_report()
		get_tree().quit()


func _report() -> void:
	var sorted := _times.duplicate()
	sorted.sort()
	var n := sorted.size()
	print("frames: %d  promedio %.2f ms (%.0f FPS)  p95 %.2f  p99 %.2f  máx %.2f" % [
		n, _mean(_times), 1000.0 / _mean(_times), sorted[int(n * 0.95)], sorted[int(n * 0.99)], sorted[n - 1]])
	print("proceso %.2f ms  física %.2f ms  draw calls %.0f (máx %.0f)" % [
		_mean(_proc), _mean(_physics), _mean(_draws), _max(_draws)])
	print("nodos %d  objetos %d  memoria %.1f MB  video %.1f MB" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])


func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for v in values:
		total += v
	return total / maxi(values.size(), 1)


func _max(values: PackedFloat64Array) -> float:
	var best := 0.0
	for v in values:
		best = maxf(best, v)
	return best
