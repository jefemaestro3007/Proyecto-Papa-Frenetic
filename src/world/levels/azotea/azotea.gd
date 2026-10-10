@tool
extends ZoneLevel
## Zona "Azotea": azoteas en ruinas recorridas de izquierda a derecha, con skyline de fondo.
## Toda la parte común (ritmo, jugador, estilos, menú de debug) vive en ZoneLevel.
## Solo "atacan" (estallido, glitch, temblor) las caídas forzadas y las que superan
## `player_params.hard_landing_height`.

const AUTORUN_EDGE := 70.0

@export var params: AzoteaParams:
	set(value):
		if params != null and params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		params = value
		if params != null:
			params.changed.connect(_on_params_changed)
		_on_params_changed()

var _data: AzoteaMapData
var _roofs_view: RooftopView
var _live: LiveDetailsView
var _autorun_cooldown := 0.0


func _zone_params() -> Resource:
	return params


func _zone_ensure_params() -> void:
	if params == null:
		params = AzoteaParams.new()


func _zone_generate() -> void:
	_data = AzoteaGenerator.generate(params)
	_add_skyline_layer(_data.far, FAR_SCROLL)
	_add_skyline_layer(_data.near, NEAR_SCROLL)

	_roofs_view = RooftopView.new()
	_roofs_view.setup(_data, params.seed, style)
	_roofs_view.material = _make_grunge()
	_generated.add_child(_roofs_view)
	_live = LiveDetailsView.new()
	_live.setup(_data, style)
	_generated.add_child(_live)
	_generated.add_child(_make_colliders(_data.roofs))


func _zone_style_changed() -> void:
	if _roofs_view == null:
		return
	_roofs_view.queue_redraw()
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
	Input.action_press("ui_right")
	Input.action_release("ui_down")
	if _player.velocity.y > 0.0:
		Input.action_release("ui_accept")
		if _player.velocity.y > 300.0 and not _player.is_fast_falling() and _fx_rng.randf() < 0.05:
			Input.action_press("ui_down")
	_autorun_cooldown -= delta
	if _autorun_cooldown > 0.0 or not _player.is_on_floor():
		return
	Input.action_release("ui_accept")
	var x := _player.position.x
	for roof in _data.roofs:
		if x > roof.end.x - AUTORUN_EDGE and x < roof.end.x:
			Input.action_press("ui_accept")
			_autorun_cooldown = 0.3
			return
