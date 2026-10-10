class_name SystemMonitor
extends Control
## Monitor del sistema arriba a la derecha (lo crea `Settings`, así se ve en el menú y en los
## niveles). Modo FPS: cuadros por segundo y tiempo por frame. Modo completo: además proceso y
## física, draw calls, nodos, objetos de física, memoria, latencia de audio, ventana y el beat.
## Los números se refrescan 4 veces por segundo; el peor frame es el del último medio segundo.

const REFRESH := 0.25
const FONT_SIZE := 22
const LINE := 24.0
const MARGIN := 16.0
const GOOD := Color("8fe388")
const WARN := Color("f0be55")
const BAD := Color("ff6b4a")

var mode := GameSettings.Monitor.OFF:
	set(value):
		mode = value
		visible = mode != GameSettings.Monitor.OFF
		_refresh()

var _lines: Array[String] = []
var _fps := 0.0
var _last_usec := 0
var _since_refresh := 0.0
var _frame_sum := 0.0
var _frame_count := 0
var _frame_worst := 0.0
var _avg_ms := 0.0
var _worst_ms := 0.0


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec > 0:
		var ms := (now - _last_usec) / 1000.0
		_frame_sum += ms
		_frame_count += 1
		_frame_worst = maxf(_frame_worst, ms)
	_last_usec = now
	if not visible:
		return
	_since_refresh += get_process_delta_time()
	if _since_refresh >= REFRESH:
		_since_refresh = 0.0
		_avg_ms = _frame_sum / maxi(_frame_count, 1)
		_worst_ms = _frame_worst
		_frame_sum = 0.0
		_frame_count = 0
		_frame_worst = 0.0
		_refresh()
		queue_redraw()


## Texto de cada línea (también lo leen los tests).
func lines() -> Array[String]:
	return _lines


func _refresh() -> void:
	_fps = Engine.get_frames_per_second()
	_lines.clear()
	if mode == GameSettings.Monitor.OFF:
		return
	_lines.append("FPS %d   %.1f ms (peor %.1f)" % [roundi(_fps), _avg_ms, _worst_ms])
	if mode != GameSettings.Monitor.FULL:
		return
	var p := Performance
	_lines.append("Proceso %.2f ms   Física %.2f ms" % [p.get_monitor(p.TIME_PROCESS) * 1000.0,
			p.get_monitor(p.TIME_PHYSICS_PROCESS) * 1000.0])
	_lines.append("Draw calls %d   Objetos %d" % [p.get_monitor(p.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			p.get_monitor(p.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	_lines.append("Nodos %d   Huérfanos %d" % [p.get_monitor(p.OBJECT_NODE_COUNT),
			p.get_monitor(p.OBJECT_ORPHAN_NODE_COUNT)])
	_lines.append("Física 2D activos %d" % p.get_monitor(p.PHYSICS_2D_ACTIVE_OBJECTS))
	_lines.append("Memoria %.0f MB   Video %.0f MB" % [p.get_monitor(p.MEMORY_STATIC) / 1048576.0,
			p.get_monitor(p.RENDER_VIDEO_MEM_USED) / 1048576.0])
	_lines.append("Audio latencia %.0f ms" % (p.get_monitor(p.AUDIO_OUTPUT_LATENCY) * 1000.0))
	var window := get_viewport_rect().size
	_lines.append("Ventana %dx%d   VSync %s   Límite %s" % [window.x, window.y,
			"sí" if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED else "no", "—" if Engine.max_fps == 0 else str(Engine.max_fps)])
	_lines.append("BPM %.0f   Beat %d" % [Conductor._bpm, Conductor.beat_index()])


func _draw() -> void:
	if _lines.is_empty():
		return
	var font := MenuStyle.font()
	var width := 0.0
	for line in _lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	var panel := Rect2(size.x - width - MARGIN * 2.0 - 12.0, MARGIN, width + 24.0, _lines.size() * LINE + 14.0)
	draw_rect(panel, Color(MenuStyle.INK, 0.72))
	draw_rect(panel, Color(MenuStyle.CREAM, 0.25), false, 2.0)
	for i in _lines.size():
		var color := MenuStyle.CREAM
		if i == 0:
			color = GOOD if _fps >= 55.0 else (WARN if _fps >= 30.0 else BAD)
		var baseline := panel.position.y + 7.0 + LINE * i + font.get_ascent(FONT_SIZE)
		draw_string_outline(font, Vector2(panel.position.x + 12.0, baseline), _lines[i], HORIZONTAL_ALIGNMENT_LEFT,
				-1, FONT_SIZE, 4, MenuStyle.INK)
		draw_string(font, Vector2(panel.position.x + 12.0, baseline), _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
				FONT_SIZE, color)
