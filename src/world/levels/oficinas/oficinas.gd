@tool
extends ZoneLevel
## Zona "Oficinas": edificio administrativo abandonado y medio destruido. Pasillos, puertas,
## escaleras, ascensores, huecos y derrumbes; siempre se puede llegar a la salida y no hay
## trampas, pero el camino no es lineal. Toda la parte común vive en ZoneLevel.

const NEXT_SEED_DELAY := 2.5
const GOAL_BONUS := 1000

@export var params: OficinasParams:
	set(value):
		if params != null and params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		params = value
		if params != null:
			params.changed.connect(_on_params_changed)
		_on_params_changed()

## Muestra el grafo de recorrido encima del mapa (depuración).
@export var show_graph := false:
	set(value):
		show_graph = value
		if _graph != null:
			_graph.visible = value

## Al llegar a la salida, pasar solo a la seed siguiente.
var auto_next := true
## Salidas alcanzadas desde que empezó la escena (lo usa el test de integración).
var goals_reached := 0

var _data: OficinasMapData
var _view: InteriorView
var _live: InteriorLiveView
var _graph: OficinasGraphView
var _elevators: Array[Elevator] = []
var _bot: OficinasBot
var _goal_done := false
var _goal_timer := 0.0


func _zone_params() -> Resource:
	return params


func _zone_ensure_params() -> void:
	if params == null:
		params = OficinasParams.new()


func _zone_map_folder() -> String:
	return "oficinas"


func _zone_default_zoom() -> float:
	return 1.35


func _zone_help_text() -> String:
	return "←/→ mover · Espacio saltar · ↓ caída forzada · Tab menú · F2 estilo · R/N/P seed · G grafo"


func _parse_args() -> void:
	super()
	if "--graph" in OS.get_cmdline_user_args():
		show_graph = true


func _zone_generate() -> void:
	_data = OficinasGenerator.generate(params)
	_add_skyline_layer(_data.far, FAR_SCROLL)
	_add_skyline_layer(_data.near, NEAR_SCROLL)

	_view = InteriorView.new()
	_view.setup(_data, params.seed, style)
	_view.material = _make_grunge()
	_generated.add_child(_view)
	_live = InteriorLiveView.new()
	_live.setup(_data, style)
	_generated.add_child(_live)
	_generated.add_child(_make_colliders(_data.slabs + _data.sealed))
	_generated.add_child(_make_walls())
	_generated.add_child(_make_stairs())

	_elevators.clear()
	for spec in _data.elevators:
		var elevator := Elevator.new()
		elevator.setup(spec, style, params, _data.floor_height)
		elevator.rider = _player
		_generated.add_child(elevator)
		_elevators.append(elevator)

	_graph = OficinasGraphView.new()
	_graph.setup(_data)
	_graph.visible = show_graph
	_generated.add_child(_graph)
	_bot = OficinasBot.new(_data)
	_goal_done = false


## Muros con remate en cuña inclinada hacia el lado que tiene vacío encima: quien cae por
## ese hueco resbala de vuelta al hueco en vez de quedarse en una cornisa que no existe en el grafo.
func _make_walls() -> StaticBody2D:
	var body := StaticBody2D.new()
	var layout := _data.layout
	for rect in _data.walls:
		var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)])
		var left := roundi(rect.get_center().x / _data.module_width) - 1
		var below := roundi((-rect.position.y + OficinasMapData.SLAB) / _data.floor_height) - 1
		var above := below + 1
		if left >= 0 and left + 1 < layout.modules and above < layout.floors:
			var void_left := not _has_slab(above, left)
			var void_right := not _has_slab(above, left + 1)
			var cap := minf(40.0, rect.size.y * 0.5)
			if void_left:
				points[0].y += cap
			elif void_right:
				points[1].y += cap
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = points
		body.add_child(polygon)
	return body


## ¿Hay losa en el piso `f`, módulo `c`, junto a sus bordes? (Los huecos pequeños son centrales.)
func _has_slab(f: int, c: int) -> bool:
	var layout := _data.layout
	match layout.cell(f, c):
		OficinasLayout.Cell.NORMAL, OficinasLayout.Cell.STAIR_LOW, OficinasLayout.Cell.SEALED, OficinasLayout.Cell.GAP:
			return true
		OficinasLayout.Cell.SHAFT:
			return layout.elevator_at(f, c).low == f
	return false


## Rampas de un solo sentido: se suben caminando y se pueden atravesar desde abajo.
func _make_stairs() -> StaticBody2D:
	var body := StaticBody2D.new()
	for stair in _data.stairs:
		var polygon := CollisionPolygon2D.new()
		# Tramo plano sobre el rellano: el paso de la rampa a la losa no tiene esquina.
		var ahead := Vector2(signf(stair.high.x - stair.low.x) * 60.0, 0.0)
		polygon.polygon = PackedVector2Array([stair.low, stair.high, stair.high + ahead,
				stair.high + ahead + Vector2(0.0, 18.0), stair.high + Vector2(0.0, 18.0), stair.low + Vector2(0.0, 18.0)])
		polygon.one_way_collision = true
		body.add_child(polygon)
	return body


func _zone_style_changed() -> void:
	if _view == null:
		return
	_view.queue_redraw()
	var material := _view.material as ShaderMaterial
	material.set_shader_parameter("dirt", style.grime)
	material.set_shader_parameter("halftone_strength", style.halftone)


func _zone_spawn() -> Vector2:
	return _data.spawn


func _zone_kill_y() -> float:
	return _data.surface_y(0) + 800.0


func _zone_camera_target() -> Vector2:
	return _player.position + Vector2(0.0, -160.0)


func _zone_autorun(delta: float) -> void:
	_bot.step(_player, _elevators, delta)


func _zone_map_controls(section: DebugSection) -> void:
	section.add_toggle(self, &"show_graph", "Mostrar grafo de recorrido (G)")
	section.add_toggle(self, &"auto_next", "Pasar a la seed siguiente al salir")
	section.add_group("Edificio")
	section.add_slider(params, &"floors", "Pisos", 2, 24, 1)
	section.add_slider(params, &"modules", "Módulos por piso", 3, 16, 1)
	section.add_slider(params, &"module_width", "Ancho de módulo (px)", 480, 1000, 10)
	section.add_slider(params, &"floor_height", "Altura de piso (px)", 360, 600, 10)
	section.add_group("Recorrido")
	section.add_text("Modo de final: 0 = arriba, 1 = abajo, 2 = distancia de pisos.")
	section.add_slider(params, &"end_mode", "Modo de final", 0, 2, 1)
	section.add_slider(params, &"start_floor", "Piso de inicio (modo distancia)", 0, 23, 1)
	section.add_slider(params, &"floor_distance", "Distancia de pisos (modo distancia)", -23, 23, 1)
	section.add_slider(params, &"min_transitions", "Cambios de piso mínimos", 0, 12, 1)
	section.add_slider(params, &"detour_chance", "Desvíos de la ruta", 0.0, 1.0, 0.01)
	section.add_slider(params, &"branches", "Rutas alternativas", 0, 8, 1)
	section.add_toggle(params, &"reach_everything", "Todo el edificio recorrible")
	section.add_group("Conexiones")
	section.add_slider(params, &"stairs_weight", "Peso escaleras", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_weight", "Peso ascensores", 0.0, 4.0, 0.05)
	section.add_slider(params, &"fall_weight", "Peso caídas", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_max_span", "Alcance máx. de ascensor (pisos)", 1, 12, 1)
	section.add_slider(params, &"collapse_max_depth", "Pisos por derrumbe", 1, 6, 1)
	section.add_group("Ascensores")
	section.add_slider(params, &"elevator_local_weight", "Peso local", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_express_weight", "Peso expreso", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_call_weight", "Peso a demanda", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_faulty_weight", "Peso averiado", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_wait_beats", "Espera en cada parada (beats)", 0.0, 16.0, 0.5)
	section.add_slider(params, &"elevator_beats_per_floor", "Beats por piso", 0.25, 8.0, 0.25)
	section.add_toggle(params, &"elevator_sync_to_beat", "Arrancar y frenar en el beat")
	section.add_group("Extras y daño")
	section.add_slider(params, &"extra_stairs", "Escaleras extra", 0.0, 0.5, 0.01)
	section.add_slider(params, &"extra_elevators", "Ascensores extra", 0.0, 0.5, 0.01)
	section.add_slider(params, &"gap_chance", "Huecos pequeños", 0.0, 0.5, 0.01)
	section.add_slider(params, &"collapse_chance", "Derrumbes", 0.0, 0.5, 0.01)
	section.add_slider(params, &"wall_open_weight", "Peso pasillo abierto", 0.0, 4.0, 0.05)
	section.add_slider(params, &"wall_door_weight", "Peso puerta", 0.0, 4.0, 0.05)
	section.add_slider(params, &"wall_blocked_weight", "Peso muro bloqueado", 0.0, 4.0, 0.05)
	section.add_group("Ambientación")
	section.add_slider(params, &"furniture_density", "Muebles", 0.0, 1.0, 0.01)
	section.add_slider(params, &"window_chance", "Ventanas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"wall_damage", "Paredes rotas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"marks_per_module", "Marcas por módulo", 0, 16, 1)
	section.add_slider(params, &"working_lamps", "Lámparas que funcionan", 0.0, 1.0, 0.01)
	section.add_slider(params, &"skyline_ruin", "Ruina del skyline", 0.0, 1.0, 0.01)


func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null:
		return
	if not _goal_done and _data.goal.has_point(_player.position + Vector2(0.0, -10.0)):
		_goal_done = true
		_goal_timer = 0.0
		goals_reached += 1
		_tracker.score += GOAL_BONUS
		_hud.banner("¡SALIDA!  +%d" % GOAL_BONUS)
	elif _goal_done and auto_next:
		_goal_timer += delta
		if _goal_timer > NEXT_SEED_DELAY:
			params.seed += 1
	if _menu.visible and _stats_text != null:
		_stats_text.text += "\nbot: %s · nodo %v" % [_bot.status, _data.node_at(_player.position)]


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_G:
		show_graph = not show_graph
