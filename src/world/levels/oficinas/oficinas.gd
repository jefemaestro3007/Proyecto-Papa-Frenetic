@tool
extends ZoneLevel
## Zona "Oficinas": edificio administrativo abandonado y medio destruido. Pasillos, puertas que
## se abren (algunas con llave), escaleras y ascensores de fondo, puertas al fondo hacia
## habitaciones y pasillos, huecos y derrumbes. Siempre se puede llegar a la salida y nunca hay
## atasco, pero el camino no es lineal. Toda la parte común vive en ZoneLevel.
## Controles propios: W al pie de una escalera sube, S arriba baja; W frente a un ascensor lo
## llama y adentro W/S eligen el piso (A/D para salir); W frente a una puerta al fondo entra.

enum State { FREE, STAIRS, CALLING, RIDING }

const NEXT_SEED_DELAY := 2.5
const GOAL_BONUS := 1000
## Duración de un tramo de escalera (rápido: es un juego frenético).
const STAIR_SECONDS := 0.45
const ENEMY_SALT := 0x0f1c

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

## Solo se ve la habitación o pasillo donde está el personaje (neblina; V la alterna).
@export var room_only_view := false
## Clic guía en el beat que suena desde la dirección hacia la que hay que ir.
var guide_enabled := true
var guide_volume_db := -4.0:
	set(value):
		guide_volume_db = value
		if _guide != null:
			_guide.volume_db = value
## Al llegar a la salida, pasar solo a la seed siguiente (nunca jugando desde el menú: ahí está YOU WIN).
var auto_next := true
## Salidas alcanzadas desde que empezó la escena (lo usa el test de integración).
var goals_reached := 0
## Llaves que se tienen (máscara de bits).
var keys_held := 0
## Último plan de la guía sonora y largos de plan por puerta (ver `_guide_plan_from`).
var _guide_plan := []
var _door_plan_lengths := {}

var _data: OficinasMapData
var _view: ChunkedView
var _live: InteriorLiveView
var _graph: OficinasGraphView
var _mask: VisionMask
var _guide: AudioStreamPlayer2D
var _elevators: Array[Elevator] = []
var _bot: OficinasBot
var _state := State.FREE
var _stair: OficinasMapData.Stair
var _stair_up := true
var _stair_time := 0.0
var _lift: Elevator
var _lift_floor := 0
var _lift_was_moving := false
var _lift_direction := 0
var _goal_done := false
var _goal_timer := 0.0


func _zone_params() -> Resource:
	return params


## Segunda zona: la canción del nivel dos.
func _zone_music() -> MusicTrack:
	return load(MUSIC + "industrial.tres")


func _zone_ensure_params() -> void:
	if params == null:
		params = OficinasParams.new()


func _zone_map_folder() -> String:
	return "oficinas"


func _zone_default_zoom() -> float:
	return 1.35


func _zone_help_text() -> String:
	return "A/D mover · Espacio saltar · J atacar · Shift dash · W/S escaleras, ascensor y puertas al fondo · Tab menú · F2 estilo · " \
			+ "V vista de habitación · G grafo"


func _parse_args() -> void:
	super()
	var args := OS.get_cmdline_user_args()
	if "--graph" in args:
		show_graph = true
	if "--room-view" in args:
		room_only_view = true


# --- Construcción --------------------------------------------------------------------

func _zone_generate() -> void:
	_data = OficinasGenerator.generate(params)
	_add_skyline_layer(_data.far, FAR_SCROLL)
	_add_skyline_layer(_data.near, NEAR_SCROLL)

	_view = ChunkedView.new()
	_view.build(func() -> InteriorView:
		var view := InteriorView.new()
		view.setup(_data, params.seed, style)
		return view, _data.bounds, InteriorView.LAYERS)
	_view.material = _make_grunge()
	_generated.add_child(_view)
	for area in _data.areas:
		var area_view := AreaView.new()
		area_view.setup_area(area, _data, params.seed, style)
		_generated.add_child(area_view)
		_generated.add_child(_make_colliders(area.solids))
	_live = InteriorLiveView.new()
	_live.setup(_data, style)
	_generated.add_child(_live)
	_generated.add_child(_make_colliders(_data.slabs + _data.sealed))
	_generated.add_child(_make_walls())

	_elevators.clear()
	for spec in _data.elevators:
		var elevator := Elevator.new()
		elevator.setup(spec, _data, style, params)
		_generated.add_child(elevator)
		_elevators.append(elevator)
	for spec in _data.wall_doors:
		var door := WallDoorNode.new()
		door.setup(spec, style)
		door.opener = _player
		door.has_key = func(key_id: int) -> bool: return keys_held & (1 << key_id) != 0
		_generated.add_child(door)
	keys_held = 0
	_guide_plan = []
	_door_plan_lengths.clear()
	for spec in _data.keys:
		var key := KeyPickup.new()
		key.key_id = spec.id
		key.position = spec.position
		key.collector = _player
		key.collected.connect(_on_key_collected)
		_generated.add_child(key)

	_graph = OficinasGraphView.new()
	_graph.setup(_data)
	_graph.visible = show_graph
	_generated.add_child(_graph)
	_mask = VisionMask.new()
	_mask.z_index = 40
	_generated.add_child(_mask)
	if _player != null:
		_player.z_index = 50
		if _player.scripted:
			_player.end_scripted(_data.spawn)
	_spawn_enemies()
	_bot = OficinasBot.new(_data)
	_state = State.FREE
	_goal_done = false
	_ensure_guide()



## Papas por módulo, deterministas por seed. Nunca en el módulo de inicio ni en el de la salida,
## ni donde hay escalera, ascensor o hueco. Cuanto más lejos del inicio (en pasos del grafo), más
## tipos: al principio solo comunes, después tanque, embestidora y tiradora (EnemyRoster).
func _spawn_enemies() -> void:
	if Engine.is_editor_hint() or combat.enemy_density <= 0.0:
		return
	var layout := _data.layout
	var distance := _graph_distances(layout.start)
	var farthest := 1
	for node: Vector2i in distance:
		farthest = maxi(farthest, distance[node])
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ ENEMY_SALT
	for node in layout.nodes():
		var chance := rng.randf()
		if node == layout.start or node == layout.end or not distance.has(node) \
				or layout.cell(node.x, node.y) != OficinasLayout.Cell.NORMAL or layout.has_stairs(node.x, node.y) \
				or chance > combat.enemy_density * 0.9:
			continue
		var progress := float(distance[node]) / farthest
		var type := _pick_enemy(EnemyRoster.OFICINAS, progress, rng)
		var rect := _data.module_rect(node.x, node.y)
		var left := rect.position.x + OficinasMapData.WALL + 30.0
		var right := rect.end.x - OficinasMapData.WALL - 30.0
		var x := rng.randf_range(lerpf(left, right, 0.35), right)
		spawn_enemy(EnemyRoster.make(type, combat, rng), Vector2(x, _data.surface_y(node.x)), left, right)


## Pasos del grafo desde `origin` hasta cada nodo alcanzable (con todas las llaves).
func _graph_distances(origin: Vector2i) -> Dictionary:
	var distance := {origin: 0}
	var queue: Array[Vector2i] = [origin]
	var head := 0
	while head < queue.size():
		var node: Vector2i = queue[head]
		head += 1
		for pair in _data.layout.successors(node):
			if not distance.has(pair[0]):
				distance[pair[0]] = distance[node] + 1
				queue.append(pair[0])
	return distance


func _zone_solids() -> Array[Rect2]:
	return _data.slabs + _data.walls + _data.sealed


## Muros con remate en cuña inclinada hacia el lado que tiene vacío encima: quien cae por un
## derrumbe resbala de vuelta al hueco en vez de quedarse en una cornisa fuera del grafo.
func _make_walls() -> StaticBody2D:
	var body := StaticBody2D.new()
	var layout := _data.layout
	for rect in _data.walls:
		var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
				Vector2(rect.position.x, rect.end.y)])
		var left := roundi(rect.get_center().x / _data.module_width) - 1
		var above := roundi((-rect.position.y + OficinasMapData.SLAB) / _data.floor_height)
		if left >= 0 and left + 1 < layout.modules and above < layout.floors:
			var cap := minf(40.0, rect.size.y * 0.5)
			if layout.is_void(above, left):
				points[0].y += cap
			elif layout.is_void(above, left + 1):
				points[1].y += cap
		var polygon := CollisionPolygon2D.new()
		polygon.polygon = points
		body.add_child(polygon)
	return body


func _ensure_guide() -> void:
	if _guide != null or Engine.is_editor_hint():
		return
	_guide = AudioStreamPlayer2D.new()
	_guide.stream = ConductorClock._make_click()
	_guide.volume_db = guide_volume_db
	_guide.max_distance = 2600.0
	_guide.pitch_scale = 0.7
	add_child(_guide)
	Conductor.beat.connect(_on_guide_beat)


func _zone_style_changed() -> void:
	if _view == null:
		return
	_view.redraw()
	for child in _generated.get_children():
		if child is AreaView or child is WallDoorNode or child is Elevator:
			child.queue_redraw()
	var material := _view.material as ShaderMaterial
	material.set_shader_parameter("dirt", style.grime)
	material.set_shader_parameter("halftone_strength", style.halftone)


func _zone_spawn() -> Vector2:
	return _data.spawn


func _zone_kill_y() -> float:
	# Las áreas al fondo están debajo del edificio: ahí no se cae al vacío.
	if _player != null and _data.area_at(_player.position) >= 0:
		return INF
	return _data.surface_y(0) + 800.0


func _zone_camera_target() -> Vector2:
	return _player.position + Vector2(0.0, -150.0)


func _zone_autorun(delta: float) -> void:
	_bot.step(self, delta)


# --- Interacciones -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null:
		return
	# Escribiendo en un campo del menú (p. ej. el nombre de un preset): las teclas no son del juego.
	# Tampoco hay controles con la partida terminada.
	if not is_playing() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match _state:
		State.FREE:
			_update_free()
		State.STAIRS:
			_update_stairs(delta)
		State.CALLING:
			_update_calling()
		State.RIDING:
			_update_riding()
	_update_view()


## Área al fondo donde está el personaje (-1 = edificio).
func current_area() -> int:
	return _data.area_at(_player.position)


func current_state() -> State:
	return _state


func lift_in_use() -> Elevator:
	return _lift if _state in [State.CALLING, State.RIDING] else null


func data() -> OficinasMapData:
	return _data


func player() -> PlayerPrototype:
	return _player


func elevators() -> Array[Elevator]:
	return _elevators


func _update_free() -> void:
	if not _player.is_on_floor() or _player.scripted:
		return
	var up := Input.is_action_just_pressed("move_up")
	var down := Input.is_action_just_pressed("move_down")
	if not up and not down:
		return
	var feet := _player.global_position
	var area := current_area()
	if area >= 0:
		if up:
			for door in _data.areas[area].doors:
				if absf(feet.x - door.x) < OficinasMapData.INTERACT_RANGE:
					_exit_area(door)
					return
		return
	var node := _data.node_at(feet)
	if node.x < 0:
		return
	for stair in _data.stairs:
		if up and stair.floor == node.x and absf(feet.x - stair.foot.x) < OficinasMapData.INTERACT_RANGE:
			_start_stairs(stair, true)
			return
		if down and stair.floor + 1 == node.x and absf(feet.x - stair.top.x) < OficinasMapData.INTERACT_RANGE:
			_start_stairs(stair, false)
			return
	if not up:
		return
	for elevator in _elevators:
		if elevator.spec.column == node.y and elevator.spec.stops.has(node.x) \
				and absf(feet.x - elevator.door_x()) < OficinasMapData.INTERACT_RANGE:
			_state = State.CALLING
			_lift = elevator
			_lift_floor = node.x
			elevator.call_to(node.x)
			_tracker.register_move(&"lift", false)
			return
	for door in _data.depth_doors:
		if door.kind != OficinasLayout.Depth.NONE and door.floor == node.x \
				and absf(feet.x - door.rect.get_center().x) < OficinasMapData.INTERACT_RANGE:
			_enter_area(door)
			return


func _start_stairs(stair: OficinasMapData.Stair, up: bool) -> void:
	_stair = stair
	_stair_up = up
	_stair_time = 0.0
	_state = State.STAIRS
	_player.begin_scripted()
	_player.facing = float(stair.dir) if up else float(-stair.dir)
	_tracker.register_move(&"stairs", false)


func _update_stairs(delta: float) -> void:
	_stair_time += delta
	var t := clampf(_stair_time / STAIR_SECONDS, 0.0, 1.0)
	var from := _stair.foot if _stair_up else _stair.top
	var to := _stair.top if _stair_up else _stair.foot
	_player.position = from.lerp(to, t) + Vector2(0.0, -2.0)
	if t >= 1.0:
		_player.end_scripted(to + Vector2(0.0, -2.0))
		_state = State.FREE


## Esperando la cabina: si se aleja, se cancela; al abrirse, entra.
func _update_calling() -> void:
	if absf(_player.global_position.x - _lift.door_x()) > OficinasMapData.INTERACT_RANGE * 1.6:
		_state = State.FREE
		_lift.close_doors()
		return
	if _lift.is_open_at(_lift_floor):
		_player.begin_scripted()
		_player.position = Vector2(_lift.door_x(), _lift.cabin_y - 2.0)
		_lift.riding = true
		_lift.close_doors()
		_lift_was_moving = false
		_lift_direction = 0
		_state = State.RIDING


## Adentro: W/S eligen hacia dónde (mantener sigue de piso en piso), A/D salen.
func _update_riding() -> void:
	_player.position = Vector2(_lift.door_x(), _lift.cabin_y - 2.0)
	if _lift.is_moving():
		_lift_was_moving = true
		return
	var held := 0
	if Input.is_action_pressed("move_up"):
		held = 1
	elif Input.is_action_pressed("move_down"):
		held = -1
	if _lift_was_moving:
		_lift_was_moving = false
		# Llegó: si se sigue manteniendo la misma dirección, continúa; si no, abre.
		if held != 0 and held == _lift_direction and _lift.spec.kind != OficinasLayout.Lift.EXPRESS:
			var next := _lift.next_stop(_lift.cabin_floor, held)
			if next >= 0:
				_lift.ride_to(next)
				return
		_lift.open_here()
	if held != 0:
		var target := _lift.next_stop(_lift.cabin_floor, held)
		if _lift.spec.kind == OficinasLayout.Lift.EXPRESS and target >= 0:
			target = _lift.spec.high if held > 0 else _lift.spec.low
		if target >= 0:
			_lift_direction = held
			_lift.ride_to(target)
			return
	var side := Input.get_axis("move_left", "move_right")
	if side != 0.0:
		if _lift.is_open_at(_lift.cabin_floor):
			_lift.riding = false
			_player.end_scripted(Vector2(_lift.door_x() + side * 20.0, _lift.cabin_y - 2.0))
			_state = State.FREE
		else:
			_lift.open_here()


func _enter_area(door: OficinasMapData.DepthDoorSpec) -> void:
	var area := _data.areas[door.area]
	var x := area.rect.position.x + 140.0
	for area_door in area.doors:
		if area_door.depth_door == door.id:
			x = area_door.x
	_teleport(Vector2(x, area.floor_y() - 2.0))
	_tracker.register_move(&"door", false)


func _exit_area(area_door: OficinasMapData.AreaDoor) -> void:
	var door := _data.depth_doors[area_door.depth_door]
	_teleport(Vector2(door.rect.get_center().x, _data.surface_y(door.floor) - 2.0))
	_tracker.register_move(&"door", false)


func _teleport(at: Vector2) -> void:
	_player.end_scripted(at)
	_camera.position = _zone_camera_target()
	_camera.reset_smoothing()


func _on_key_collected(key_id: int) -> void:
	keys_held |= 1 << key_id
	_tracker.score += 250
	_hud.banner("LLAVE")


# --- Vista ---------------------------------------------------------------------------

## Máscara: durante el viaje solo la cabina; en un área al fondo, solo el área; con vista de
## habitación, solo la habitación actual.
func _update_view() -> void:
	if _state == State.RIDING:
		_mask.show_only(_lift.cabin_rect())
		return
	# Dentro de un área al fondo siempre se ve solo el área (está "detrás" del edificio).
	var area := current_area()
	if area >= 0:
		_mask.show_only(_data.areas[area].rect.grow(30.0), true)
		return
	if not room_only_view:
		_mask.clear()
		return
	var f := roundi(-_player.position.y / _data.floor_height)
	var c := floori(_player.position.x / _data.module_width)
	var room := _data.room_at(f, c)
	if room != null:
		_mask.show_only(room.rect.grow(40.0))


# --- Guía sonora ---------------------------------------------------------------------

## En cada beat suena un clic desde el próximo punto importante del camino a la salida
## (escalera, ascensor, puerta, hueco o la salida misma): el paneo y el volumen dicen hacia dónde ir.
func _on_guide_beat(_index: int) -> void:
	if not guide_enabled or _guide == null or _data == null or _player == null:
		return
	var point := guide_point()
	if point == Vector2.INF:
		return
	_guide.global_position = point
	_guide.play()


## Siguiente punto importante del plan hacia la salida (o Vector2.INF si no hay plan).
func guide_point() -> Vector2:
	var area := current_area()
	if area >= 0:
		var doors := _data.areas[area].doors
		var best := doors[0]
		var best_length := INF
		for door in doors:
			var spec := _data.depth_doors[door.depth_door]
			var length := _door_plan_length(Vector2i(spec.floor, spec.module))
			if length > 0 and length < best_length:
				best = door
				best_length = length
		return Vector2(best.x, _data.areas[area].floor_y() - 60.0)
	var node := _data.node_at(_player.position)
	if node.x < 0:
		return Vector2.INF
	var plan := _guide_plan_from(node)
	for i in range(1, plan.size()):
		if plan[i][2] != OficinasLayout.Link.WALK or i == plan.size() - 1:
			var step: Vector2i = plan[i - 1][0]
			return Vector2(_data.module_center(step.y), _data.surface_y(step.x) - 60.0)
	return _data.goal.get_center()


## Largo del plan a la salida saliendo por la puerta de `node` (guardado por puerta y llaves).
func _door_plan_length(node: Vector2i) -> int:
	var key := Vector3i(node.x, node.y, keys_held)
	if not _door_plan_lengths.has(key):
		_door_plan_lengths[key] = _data.layout.plan(node, keys_held).size()
	return _door_plan_lengths[key]


## Plan hacia la salida desde `node`. Mientras el jugador siga sobre el último plan (mismo lugar y
## mismas llaves) se usa el resto de ese plan: buscar un camino nuevo en cada beat costaba
## milisegundos en los edificios grandes. Solo se vuelve a planear al salirse del camino.
func _guide_plan_from(node: Vector2i) -> Array:
	var mask := keys_held | _data.layout.keys_at(node)
	for i in _guide_plan.size():
		if _guide_plan[i][0] == node and _guide_plan[i][1] == mask:
			return _guide_plan.slice(i)
	_guide_plan = _data.layout.plan(node, keys_held)
	return _guide_plan


# --- Menú ----------------------------------------------------------------------------

func _zone_map_controls(section: DebugSection) -> void:
	section.add_toggle(self, &"show_graph", "Mostrar grafo de recorrido (G)")
	section.add_toggle(self, &"room_only_view", "Ver solo la habitación actual (V)")
	section.add_toggle(self, &"guide_enabled", "Guía sonora hacia la salida")
	section.add_slider(self, &"guide_volume_db", "Volumen de la guía (dB)", -30, 6, 1)
	section.add_toggle(self, &"auto_next", "Pasar a la seed siguiente al salir")
	section.add_group("Edificio")
	section.add_slider(params, &"floors", "Pisos", 2, 24, 1)
	section.add_slider(params, &"modules", "Módulos por piso", 3, 16, 1)
	section.add_slider(params, &"module_width", "Ancho de módulo (px)", 520, 1000, 10)
	section.add_slider(params, &"floor_height", "Altura de piso (px)", 360, 600, 10)
	section.add_slider(params, &"realism", "Realismo (núcleos, plantas, daño por zonas)", 0.0, 1.0, 0.01)
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
	section.add_slider(params, &"corridor_weight", "Peso pasillos al fondo", 0.0, 4.0, 0.05)
	section.add_slider(params, &"corridor_max_floors", "Pisos que cruza un pasillo", 0, 2, 1)
	section.add_slider(params, &"elevator_max_span", "Alcance máx. de ascensor (pisos)", 1, 12, 1)
	section.add_slider(params, &"collapse_max_depth", "Pisos por derrumbe", 1, 6, 1)
	section.add_group("Ascensores")
	section.add_slider(params, &"elevator_local_weight", "Peso local", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_express_weight", "Peso expreso", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_call_weight", "Peso de servicio", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_faulty_weight", "Peso averiado", 0.0, 4.0, 0.05)
	section.add_slider(params, &"elevator_call_seconds", "Llegada máx. al llamar (s)", 0.2, 2.0, 0.05)
	section.add_slider(params, &"elevator_trip_seconds", "Viaje máx. (s)", 0.3, 1.5, 0.05)
	section.add_toggle(params, &"elevator_sync_to_beat", "Puertas en el beat")
	section.add_group("Habitaciones, puertas y llaves")
	section.add_slider(params, &"room_chance", "Habitaciones al fondo", 0.0, 1.0, 0.01)
	section.add_slider(params, &"locked_doors", "Puertas con llave", 0, 3, 1)
	section.add_slider(params, &"key_in_room_chance", "Llaves dentro de habitaciones", 0.0, 1.0, 0.01)
	section.add_slider(params, &"wall_open_weight", "Peso pasillo abierto", 0.0, 4.0, 0.05)
	section.add_slider(params, &"wall_door_weight", "Peso puerta", 0.0, 4.0, 0.05)
	section.add_slider(params, &"wall_blocked_weight", "Peso muro bloqueado", 0.0, 4.0, 0.05)
	section.add_group("Extras y daño")
	section.add_slider(params, &"extra_stairs", "Escaleras extra", 0.0, 0.5, 0.01)
	section.add_slider(params, &"extra_elevators", "Ascensores extra", 0.0, 0.5, 0.01)
	section.add_slider(params, &"gap_chance", "Huecos pequeños", 0.0, 0.5, 0.01)
	section.add_slider(params, &"collapse_chance", "Derrumbes", 0.0, 0.5, 0.01)
	section.add_group("Ambientación")
	section.add_slider(params, &"furniture_density", "Muebles", 0.0, 1.0, 0.01)
	section.add_slider(params, &"window_chance", "Ventanas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"wall_damage", "Paredes rotas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"marks_per_module", "Marcas por módulo", 0, 16, 1)
	section.add_slider(params, &"working_lamps", "Lámparas que funcionan", 0.0, 1.0, 0.01)
	section.add_slider(params, &"skyline_ruin", "Ruina del skyline", 0.0, 1.0, 0.01)


# --- Salida --------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null:
		return
	if not _goal_done and current_area() < 0 and _data.goal.has_point(_player.position + Vector2(0.0, -10.0)):
		_goal_done = true
		_goal_timer = 0.0
		goals_reached += 1
		_tracker.score += GOAL_BONUS
		_hud.banner("¡SALIDA!  +%d" % GOAL_BONUS)
		finish_victory()
	elif _goal_done and auto_next and not Game.in_campaign():
		_goal_timer += delta
		if _goal_timer > NEXT_SEED_DELAY:
			params.seed += 1
	if _menu.visible and _stats_text != null:
		_stats_text.text += "\nbot: %s · nodo %v · área %d · llaves %d" % [_bot.status,
				_data.node_at(_player.position), current_area(), keys_held]


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_G:
			show_graph = not show_graph
		KEY_V:
			room_only_view = not room_only_view
