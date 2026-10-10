@tool
extends ZoneLevel
## Zona "Bienestar U" (nivel 3): supermercado (3-1) o centro comercial (3-2) en perspectiva de un
## punto (ver docs/game-design/art-direction/perspectiva-de-oferta.md). Las papas son las vestidas
## (cliente, reponedor, promotora, globos, guardia). Mecánicas en BienestarWorld.
## Controles propios: W junto a un carrito se monta (S o W se baja); W al pie de una escalera
## mecánica sube y S arriba baja (a contramano se avanza lento: W/S a tiempo dan pasos).

enum State { FREE, ESCALATOR }

const ENEMY_SALT := 0xb13e
const FLYER_HEIGHT := 220.0
const INTERACT_RANGE := 70.0
## Lejos de la entrada no aparecen papas al empezar.
const SAFE_START := 800.0
## Orden en que se presentan las papas vestidas en cada tienda.
const SUPERMARKET_ORDER: Array[StringName] = [&"normal", &"charger", &"thrower", &"flyer", &"tank"]
const MALL_ORDER: Array[StringName] = [&"normal", &"flyer", &"tank", &"thrower", &"charger"]
const GOAL_BONUS := 1000

@export var params: BienestarParams:
	set(value):
		if params != null and params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		params = value
		if params != null:
			params.changed.connect(_on_params_changed)
		_on_params_changed()

var _data: BienestarMapData
var _world: BienestarWorld
var _depth_back: StoreDepthView
var _depth_front: StoreDepthView
var _fixtures: StoreFixturesView
## Planos estáticos a profundidad fija (pared, frentes de góndolas y freezers), en trozos.
var _backdrops: Array[ChunkedView] = []
var _bot: BienestarBot
var _state := State.FREE
var _ride: BienestarMapData.Escalator
var _ride_up := true
var _ride_t := 0.0
var _goal_done := false
## Salidas alcanzadas (lo usa el test de recorrido).
var goals_reached := 0
## Para capturas y pruebas: empezar en otra x (`--start-x=`) y otro piso (`--start-floor=`).
var _start_x := -1.0
var _start_floor := 0


func _zone_params() -> Resource:
	return params


func _zone_ensure_params() -> void:
	if params == null:
		params = BienestarParams.new()


## Tercera zona: la canción del centro comercial.
func _zone_music() -> MusicTrack:
	return load(MUSIC + "centro_comercial.tres")


func _zone_map_folder() -> String:
	return "bienestar"


func _zone_default_zoom() -> float:
	return 1.0


func _zone_help_text() -> String:
	return "A/D mover · Espacio saltar · J atacar · Shift dash · W carrito / subir escalera · S bajar · Tab menú · F2 estilo"


# --- Construcción --------------------------------------------------------------------

func _zone_generate() -> void:
	_data = BienestarGenerator.generate(params)
	_world = BienestarWorld.new()
	_world.name = "Mecanicas"
	_generated.add_child(_world)
	if _player != null:
		_world.setup(_data, params, combat, _player)
		_world.enemies = func() -> Array[Enemy]: return _combat.enemies
		_world.hurt.connect(_on_world_hurt)
		_world.cooled.connect(_on_cooled)
		_world.rack_collapsed.connect(_on_rack_collapsed)
	# De atrás hacia adelante: pared del fondo, piso/techo/costados, frentes de góndolas y freezers,
	# lo animado del fondo (freezers abiertos, escaleras, losas, carteles) y el plano jugable.
	var live := _world if _player != null else null
	_backdrops.clear()
	_add_backdrop(_data.depth, StoreBackdrop.Kind.WALL, -30)
	_depth_back = StoreDepthView.new()
	_depth_back.setup(_data, live, params, style, StoreDepthView.Pass.BACK)
	_depth_back.z_index = -26
	_generated.add_child(_depth_back)
	if not _data.gondolas.is_empty():
		_add_backdrop(StoreDepthView.GONDOLA_FRONT, StoreBackdrop.Kind.GONDOLAS, -25)
	if not _data.freezers.is_empty():
		_add_backdrop(StoreDepthView.FREEZER_DEPTH.x, StoreBackdrop.Kind.FREEZERS, -24)
	_depth_front = StoreDepthView.new()
	_depth_front.setup(_data, live, params, style, StoreDepthView.Pass.FRONT)
	_depth_front.z_index = -22
	_generated.add_child(_depth_front)
	_fixtures = StoreFixturesView.new()
	_fixtures.setup(_data, _world if _player != null else null, params, style)
	_generated.add_child(_fixtures)
	_generated.add_child(_make_colliders(_data.slabs + _data.solids))
	if _player != null:
		_player.z_index = 50
		if _player.scripted:
			_player.end_scripted(_data.spawn)
		_combat.ram_threshold = params.cart_ram_speed
	_state = State.FREE
	_goal_done = false
	_bot = BienestarBot.new(_data, params)
	_spawn_enemies()


func _add_backdrop(depth: float, kind: StoreBackdrop.Kind, z: int) -> void:
	var plane := DepthPlane.new(depth)
	plane.z_index = z
	var view := ChunkedView.new()
	view.build(func() -> StoreBackdrop:
		var backdrop := StoreBackdrop.new()
		backdrop.setup(_data, params, style, kind)
		return backdrop, _data.bounds, 1)
	plane.add_child(view)
	_generated.add_child(plane)
	_backdrops.append(view)


## Papas vestidas por los carriles de cada piso, deterministas por seed; al principio solo
## clientes y después un tipo nuevo por tramo (EnemyRoster). Lejos de la entrada y la salida.
func _spawn_enemies() -> void:
	if Engine.is_editor_hint() or combat.enemy_density <= 0.0 or _player == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ ENEMY_SALT
	var order := MALL_ORDER if _data.mall else SUPERMARKET_ORDER
	var width := _data.floors[0].right
	for lane in _data.lanes:
		var f := int(lane.x)
		var left := lane.y
		var right := lane.z
		if f == 0:
			left = maxf(left, _data.spawn.x + SAFE_START)
		if _data.goal.has_area() and f == _data.floors.size() - 1:
			right = minf(right, _data.goal.position.x - 200.0)
		if right - left < 300.0:
			continue
		var count := floori((right - left) / 700.0 * combat.enemy_density * 2.0 + rng.randf())
		for k in count:
			var x := rng.randf_range(left + 60.0, right - 60.0)
			var progress := (f + x / width) / _data.floors.size()
			var type := _pick_enemy(order, progress, rng)
			var enemy := EnemyRoster.make(type, combat, rng, true)
			var y := _data.surface_y(f) - (FLYER_HEIGHT if type == &"flyer" else 0.0)
			spawn_enemy(enemy, Vector2(x, y), left, right)


func _zone_solids() -> Array[Rect2]:
	return _data.slabs + _data.solids


func _zone_style_changed() -> void:
	if _fixtures != null:
		for view in _backdrops:
			view.redraw()


func _zone_spawn() -> Vector2:
	if _start_x >= 0.0:
		return Vector2(_start_x, _data.surface_y(_start_floor) - 2.0)
	return _data.spawn


func _parse_args() -> void:
	super()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--start-x="):
			_start_x = arg.trim_prefix("--start-x=").to_float()
		elif arg.begins_with("--start-floor="):
			_start_floor = arg.trim_prefix("--start-floor=").to_int()


func _zone_kill_y() -> float:
	return _data.surface_y(0) + 1500.0


func _zone_camera_target() -> Vector2:
	# El ojo bien arriba del jugador: se ve el piso alejándose y el techo completo.
	return _player.position + Vector2(0.0, -330.0)


func _zone_traction() -> float:
	return _world.traction() if _world != null and _world.player != null else 1.0


func _zone_autorun(delta: float) -> void:
	_bot.step(self, delta)


# --- Interacciones -----------------------------------------------------------------------

func data() -> BienestarMapData:
	return _data


func world() -> BienestarWorld:
	return _world


func player() -> PlayerPrototype:
	return _player


func current_state() -> State:
	return _state


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null or _world == null:
		return
	_combat.ram_speed = absf(_player.velocity.x) if _world.riding else 0.0
	if not is_playing() or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	match _state:
		State.FREE:
			_update_free()
		State.ESCALATOR:
			_update_escalator(delta)


func _update_free() -> void:
	if _player.scripted:
		return
	var up := Input.is_action_just_pressed("move_up")
	var down := Input.is_action_just_pressed("move_down")
	if not _player.is_on_floor() or (not up and not down):
		return
	if _world.riding:
		if down or up:
			_world.dismount()
		return
	var feet := _player.global_position
	for escalator in _data.escalators:
		if up and absf(feet.y - escalator.foot.y) < 12.0 and absf(feet.x - escalator.foot.x) < INTERACT_RANGE:
			_board(escalator, true)
			return
		if down and absf(feet.y - escalator.top.y) < 12.0 and absf(feet.x - escalator.top.x) < INTERACT_RANGE:
			_board(escalator, false)
			return
	if up:
		_world.try_mount()


func _board(escalator: BienestarMapData.Escalator, up: bool) -> void:
	_ride = escalator
	_ride_up = up
	_ride_t = 0.0
	_state = State.ESCALATOR
	_player.begin_scripted()
	var dir := signf(escalator.top.x - escalator.foot.x)
	_player.facing = dir if up else -dir
	_tracker.register_move(&"stairs", false)


## Viaje: a favor es rápido; a contramano se avanza lento y cada W/S a tiempo da un paso.
func _update_escalator(delta: float) -> void:
	var bar := floori(Conductor.beat_position() / ConductorClock.BEATS_PER_BAR)
	var with := _ride.going_up(bar, params.escalator_bars) == _ride_up
	var speed := 1.0 / params.escalator_seconds
	if not with:
		speed *= params.escalator_against
		var step := Input.is_action_just_pressed("move_up" if _ride_up else "move_down")
		if step and _tracker.register_move(&"stairs", false) != ConductorClock.Judgment.MISS:
			_ride_t += params.escalator_step
	_ride_t = minf(_ride_t + speed * delta, 1.0)
	var from := _ride.foot if _ride_up else _ride.top
	var to := _ride.top if _ride_up else _ride.foot
	_player.position = from.lerp(to, _ride_t) + Vector2(0.0, -2.0)
	if _ride_t >= 1.0:
		_player.end_scripted(to + Vector2(0.0, -2.0))
		_state = State.FREE


func is_riding_escalator() -> bool:
	return _state == State.ESCALATOR


## Aterrizaje: un stomp sobre la viga de un rack lo tira en el acto (sobre las papas de abajo).
func _on_player_landed(impact_speed: float, forced: bool, fall_height: float) -> void:
	super(impact_speed, forced, fall_height)
	if forced and _world != null:
		var rack := _world.rack_under(_player.global_position)
		if rack >= 0:
			_world.collapse(rack)


func _on_world_hurt(heat: float, text: String) -> void:
	_hurt_fx()
	_sfx.play(&"hurt")
	_tracker.break_combo(&"hit")
	_add_heat(heat, text)


func _on_cooled(amount: float, first: bool) -> void:
	if not is_playing() or not combat.heat_enabled:
		return
	_heat.change(amount)
	if first:
		_hud.say("¡FRESQUITO!", _player_screen_position(), Color("bfe6ef"))


func _on_rack_collapsed(index: int) -> void:
	var rack := _data.racks[index]
	_burst(Vector2(rack.rect.get_center().x, _data.surface_y(rack.floor) - 40.0), 1.4, {
		"spread": 180.0, "angle": -PI * 0.5, "fill": FreneticPalette.YELLOW, "debris": Color("c9955b"),
		"debris_alt": Color("f29b38"),
	})
	_shock = maxf(_shock, 0.5)
	_feel.add_trauma(0.5)
	_sfx.play(&"hit")


# --- Menú ----------------------------------------------------------------------------

func _zone_map_controls(section: DebugSection) -> void:
	section.add_group("Tienda")
	section.add_text("Modo: 0 = supermercado, 1 = centro comercial.")
	section.add_slider(params, &"mode", "Modo", 0, 1, 1)
	section.add_slider(params, &"sections", "Secciones (por piso)", 3, 24, 1)
	section.add_slider(params, &"floors", "Pisos (centro comercial)", 2, 5, 1)
	section.add_slider(params, &"floor_height", "Alto de piso (px)", 420, 700, 10)
	section.add_slider(params, &"ceiling_height", "Alto del techo (supermercado)", 500, 1000, 10)
	section.add_slider(params, &"depth", "Profundidad del fondo", 0.15, 0.7, 0.01)
	section.add_group("Supermercado")
	section.add_slider(params, &"aisle_weight", "Peso pasillos", 0.0, 4.0, 0.05)
	section.add_slider(params, &"freezer_weight", "Peso congelados", 0.0, 4.0, 0.05)
	section.add_slider(params, &"produce_weight", "Peso frutas y verduras", 0.0, 4.0, 0.05)
	section.add_slider(params, &"wet_weight", "Peso piso mojado", 0.0, 4.0, 0.05)
	section.add_slider(params, &"cart_weight", "Peso carritos", 0.0, 4.0, 0.05)
	section.add_slider(params, &"checkouts", "Cajas", 1, 8, 1)
	section.add_slider(params, &"rack_chance", "Racks", 0.0, 1.0, 0.01)
	section.add_slider(params, &"spill_chance", "Charcos sueltos", 0.0, 1.0, 0.01)
	section.add_group("Centro comercial")
	section.add_slider(params, &"escalators_per_floor", "Escaleras mecánicas por piso", 1, 3, 1)
	section.add_slider(params, &"shutter_chance", "Cortinas metálicas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"hole_chance", "Huecos del atrio", 0.0, 1.0, 0.01)
	section.add_toggle(params, &"food_court", "Patio de comidas")
	section.add_group("Ambientación")
	section.add_slider(params, &"product_density", "Productos", 0.0, 1.0, 0.01)
	section.add_slider(params, &"sign_density", "Carteles", 0.0, 1.0, 0.01)
	section.add_slider(params, &"ruin", "Ruina", 0.0, 1.0, 0.01)
	section.add_group("Mecánicas")
	section.add_slider(params, &"rack_collapse_beats", "Rack: beats hasta derrumbarse", 2, 16, 1)
	section.add_slider(params, &"freezer_cooling", "Freezer: enfría por segundo", 0.0, 30.0, 0.5)
	section.add_slider(params, &"freezer_cap", "Freezer: tope por freezer", 0.0, 100.0, 1)
	section.add_slider(params, &"freezer_slow", "Freezer: velocidad con escarcha", 0.2, 1.0, 0.05)
	section.add_slider(params, &"wet_traction", "Piso mojado: agarre", 0.02, 1.0, 0.01)
	section.add_slider(params, &"belt_step", "Cinta: avance por beat (px)", 0, 600, 10)
	section.add_slider(params, &"cart_speed_scale", "Carrito: velocidad (×)", 1.0, 3.0, 0.05)
	section.add_slider(params, &"cart_ram_speed", "Carrito: atropella desde", 100, 1500, 10)
	section.add_slider(params, &"escalator_bars", "Escalera: compases por sentido", 1, 16, 1)
	section.add_slider(params, &"escalator_seconds", "Escalera: viaje a favor (s)", 0.4, 4.0, 0.05)
	section.add_slider(params, &"escalator_against", "Escalera: a contramano (×)", 0.05, 1.0, 0.05)
	section.add_slider(params, &"escalator_step", "Escalera: paso a tiempo", 0.0, 0.5, 0.01)
	section.add_slider(params, &"shutter_open_beats", "Cortina: abierta (beats)", 2, 32, 1)
	section.add_slider(params, &"shutter_lower_beats", "Cortina: bajando (beats)", 2, 32, 1)
	section.add_slider(params, &"shutter_closed_beats", "Cortina: cerrada (beats)", 1, 32, 1)
	section.add_slider(params, &"fryer_heat", "Freidora: calor", 0.0, 40.0, 0.5)
	section.add_slider(params, &"fryer_every", "Freidora: cada (beats)", 1, 8, 1)


# --- Salida --------------------------------------------------------------------------

func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null:
		return
	if not _goal_done and _data.goal.has_point(_player.position + Vector2(0.0, -10.0)):
		_goal_done = true
		goals_reached += 1
		_tracker.score += GOAL_BONUS
		_hud.banner("¡SALIDA!  +%d" % GOAL_BONUS)
		finish_victory()
	if _menu.visible and _stats_text != null and _bot != null:
		_stats_text.text += "\nbot: %s · piso %d · carrito %s" % [_bot.status, _data.floor_at(_player.position),
				"sí" if _world.riding else "no"]
