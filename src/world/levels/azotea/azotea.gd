@tool
extends ZoneLevel
## Zona "Azotea": azoteas en ruinas recorridas de izquierda a derecha, con skyline de fondo.
## Toda la parte común (ritmo, jugador, estilos, menú de debug) vive en ZoneLevel.
## Solo "atacan" (estallido, glitch, temblor) las caídas forzadas y las que superan
## `player_params.hard_landing_height`.

const AUTORUN_EDGE := 70.0
const ENEMY_SALT := 0x5e11
## Altura sobre la azotea a la que flotan las papas voladoras.
const FLYER_HEIGHT := 220.0
## Distancia al final de la última azotea que cuenta como salida.
const GOAL_MARGIN := 220.0

@export var params: AzoteaParams:
	set(value):
		if params != null and params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		params = value
		if params != null:
			params.changed.connect(_on_params_changed)
		_on_params_changed()

var _data: AzoteaMapData
var _roofs_view: ChunkedView
var _live: LiveDetailsView
var _autorun_cooldown := 0.0


func _zone_params() -> Resource:
	return params


## Primera zona: la canción del nivel uno.
func _zone_music() -> MusicTrack:
	return load(MUSIC + "nivel_uno.tres")


func _zone_ensure_params() -> void:
	if params == null:
		params = AzoteaParams.new()


func _zone_generate() -> void:
	_data = AzoteaGenerator.generate(params)
	_add_skyline_layer(_data.far, FAR_SCROLL)
	_add_skyline_layer(_data.near, NEAR_SCROLL)

	_roofs_view = ChunkedView.new()
	_roofs_view.build(func() -> RooftopView:
		var view := RooftopView.new()
		view.setup(_data, params.seed, style)
		return view, _map_bounds(), RooftopView.LAYERS)
	_roofs_view.material = _make_grunge()
	_generated.add_child(_roofs_view)
	_live = LiveDetailsView.new()
	_live.setup(_data, style)
	_generated.add_child(_live)
	_generated.add_child(_make_colliders(_data.roofs))
	_spawn_enemies()


## Papas zombi sobre las azoteas (la primera es zona segura). Deterministas por seed.
## Al principio solo papas comunes; cada tramo del recorrido presenta un tipo nuevo (EnemyRoster).
func _spawn_enemies() -> void:
	if Engine.is_editor_hint() or combat.enemy_density <= 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = params.seed ^ ENEMY_SALT
	var last := _data.roofs.size() - 1
	for i in range(1, _data.roofs.size()):
		var roof := _data.roofs[i]
		var progress := float(i) / maxf(last, 1)
		var count := floori(roof.size.x / 650.0 * combat.enemy_density * 2.0 + rng.randf())
		for k in count:
			var type := _pick_enemy(EnemyRoster.AZOTEA, progress, rng)
			var enemy := EnemyRoster.make(type, combat, rng)
			var x := rng.randf_range(roof.position.x + 80.0, roof.end.x - 80.0)
			var y := roof.position.y - (FLYER_HEIGHT if type == &"flyer" else 0.0)
			spawn_enemy(enemy, Vector2(x, y), roof.position.x + 30.0, roof.end.x - 30.0)


## Área que ocupan las azoteas (para partir su dibujo en trozos).
func _map_bounds() -> Rect2:
	var bounds := _data.roofs[0]
	for roof in _data.roofs:
		bounds = bounds.merge(roof)
	return bounds


func _zone_solids() -> Array[Rect2]:
	return _data.roofs



func _zone_style_changed() -> void:
	if _roofs_view == null:
		return
	_roofs_view.redraw()
	var roof_material := _roofs_view.material as ShaderMaterial
	roof_material.set_shader_parameter("dirt", style.grime)
	roof_material.set_shader_parameter("halftone_strength", style.halftone)


func _zone_spawn() -> Vector2:
	return _data.spawn


func _zone_kill_y() -> float:
	return _data.kill_y


func _zone_camera_target() -> Vector2:
	return Vector2(_player.position.x + 260.0, minf(_player.position.y - 240.0, _data.kill_y - 900.0))


func _zone_map_controls(section: DebugSection) -> void:
	section.add_group("Azoteas")
	section.add_slider(params, &"roof_count", "Cantidad de azoteas", 3, 64, 1)
	section.add_slider(params, &"roof_width_min", "Ancho mínimo", 200, 2000, 10)
	section.add_slider(params, &"roof_width_max", "Ancho máximo", 200, 2000, 10)
	section.add_slider(params, &"gap_chance", "Probabilidad de hueco", 0.0, 1.0, 0.01)
	section.add_slider(params, &"gap_max", "Hueco máximo (px)", 0, 400, 10)
	section.add_slider(params, &"roof_base_y", "Altura base (px)", 400, 1000, 10)
	section.add_slider(params, &"roof_height_variation", "Relieve (px)", 0, 400, 10)
	section.add_slider(params, &"max_step", "Escalón máximo (px)", 0, 200, 10)
	section.add_group("Detalles")
	section.add_slider(params, &"detail_density", "Densidad de objetos", 0.0, 1.0, 0.01)
	section.add_slider(params, &"marks_per_roof", "Marcas por azotea", 0, 32, 1)
	section.add_slider(params, &"cable_chance", "Probabilidad de cable", 0.0, 1.0, 0.01)
	section.add_group("Skyline")
	section.add_slider(params, &"ruin", "Ruina", 0.0, 1.0, 0.01)
	section.add_slider(params, &"broken_windows", "Ventanas rotas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"skyline_width", "Ancho del skyline (px)", 1024, 8192, 256)


## Corre a la derecha, salta en los bordes y fuerza la caída al pasar el punto más alto.
func _zone_autorun(delta: float) -> void:
	Input.action_release("attack")
	# Golpea a la papa que tenga al alcance (toques en frames alternos).
	if _combat.has_target() and Engine.get_physics_frames() % 2 == 0:
		Input.action_press("attack")
	Input.action_press("move_right")
	Input.action_release("move_down")
	if _player.velocity.y > 0.0:
		Input.action_release("jump")
		if _player.velocity.y > 300.0 and not _player.is_fast_falling() and _fx_rng.randf() < 0.05:
			Input.action_press("move_down")
	_autorun_cooldown -= delta
	if _autorun_cooldown > 0.0 or not _player.is_on_floor():
		return
	Input.action_release("jump")
	var x := _player.position.x
	for roof in _data.roofs:
		if x > roof.end.x - AUTORUN_EDGE and x < roof.end.x:
			Input.action_press("jump")
			_autorun_cooldown = 0.3
			return


## Salida: llegar al final de la última azotea gana la partida.
func _process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint() or _data == null or not is_playing() or not _player.is_on_floor():
		return
	var last := _data.roofs[-1]
	if _player.position.x >= last.end.x - GOAL_MARGIN and absf(_player.position.y - last.position.y) < 20.0:
		finish_victory()
