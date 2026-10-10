@tool
extends Node2D
## Zona "Azotea": mapa de azoteas + fondo procedurales con estética "Rojo Frenético" y juego al ritmo.
## En el editor funciona como laboratorio: cambia los parámetros en el Inspector y se regenera.
## En juego: ←/→ mover, Espacio saltar, ↓ en el aire caída forzada, Tab/F1 menú de debug, R/N/P seeds.
## Saltar, girar y aterrizar en el beat suma combo; la caída forzada se premia o castiga según su timing.

const SKY_SHADER := preload("res://src/world/environment/shaders/sky.gdshader")
const GRUNGE_SHADER := preload("res://src/world/environment/shaders/ruin_grunge.gdshader")
const POST_SHADER := preload("res://src/world/environment/shaders/frenetic_post.gdshader")
const PRESETS := "res://src/shared/resources/presets/"
const DEFAULT_LOOK := "rojo_frenetico"

const FAR_SCROLL := Vector2(0.15, 0.08)
const NEAR_SCROLL := Vector2(0.4, 0.22)
const BURST_MIN_SPEED := 900.0
const LAND_MIN_SPEED := 400.0
const AUTORUN_EDGE := 70.0

@export var params: AzoteaParams:
	set(value):
		if params != null and params.changed.is_connected(_on_params_changed):
			params.changed.disconnect(_on_params_changed)
		params = value
		if params != null:
			params.changed.connect(_on_params_changed)
		_on_params_changed()

@export var sky: SkyParams
@export var lighting: LightingParams
@export var player_params: PlayerParams

@export_tool_button("Regenerar", "Reload") var regenerate_button := regenerate

## Recorrido automático (para capturas y pruebas): corre, salta en los bordes y fuerza caídas.
var autorun := false

var _data: AzoteaMapData
var _generated: Node2D
var _far_view: SkylineView
var _near_view: SkylineView
var _player: PlayerPrototype
var _camera: Camera2D
var _sky_material: ShaderMaterial
var _post: ShaderMaterial
var _world_light: CanvasModulate
var _tracker: RhythmTracker
var _hud: RhythmHud
var _menu: DebugMenu
var _seed_text: Label
var _stats_text: Label
var _fx_rng := RandomNumberGenerator.new()
var _shock := 0.0
var _autorun_cooldown := 0.0
var _initial_tab := 0


func _ready() -> void:
	if params == null:
		params = AzoteaParams.new()
	if sky == null:
		sky = _load_preset("cielo", DEFAULT_LOOK, SkyParams.new())
	if lighting == null:
		lighting = _load_preset("iluminacion", DEFAULT_LOOK, LightingParams.new())
	if player_params == null:
		player_params = PlayerParams.new()
	if not Engine.is_editor_hint():
		_parse_args()
		_build_runtime()
	regenerate()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autorun":
			autorun = true
		elif arg.begins_with("--seed="):
			params.seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--debug-tab="):
			_initial_tab = arg.trim_prefix("--debug-tab=").to_int()
		elif arg.begins_with("--look="):
			var look := arg.trim_prefix("--look=")
			sky = _load_preset("cielo", look, sky)
			lighting = _load_preset("iluminacion", look, lighting)


static func _load_preset(folder: String, preset_name: String, fallback: Resource) -> Resource:
	var path := PRESETS + folder + "/" + preset_name + ".tres"
	return load(path).duplicate() if ResourceLoader.exists(path) else fallback


func regenerate() -> void:
	if _generated != null:
		remove_child(_generated)
		_generated.free()
	_data = AzoteaGenerator.generate(params)
	_fx_rng.seed = params.seed

	_generated = Node2D.new()
	_generated.name = "Generated"
	add_child(_generated)
	move_child(_generated, 0)

	_far_view = _add_skyline_layer(_data.far, FAR_SCROLL, 0.25)
	_near_view = _add_skyline_layer(_data.near, NEAR_SCROLL, 0.45)
	_apply_skyline_colors()

	var roofs := RooftopView.new()
	roofs.setup(_data.roofs, params.seed)
	_generated.add_child(roofs)
	_generated.add_child(_make_colliders(_data.roofs))

	if _player != null:
		_respawn()
	if _seed_text != null:
		_seed_text.text = "Seed actual: %d" % params.seed


func _on_params_changed() -> void:
	if is_node_ready():
		regenerate()


func _add_skyline_layer(layer: AzoteaMapData.SkylineData, scroll: Vector2, dirt: float) -> SkylineView:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = scroll
	parallax.repeat_size = Vector2(layer.width, 0.0)
	parallax.repeat_times = 3
	var view := SkylineView.new()
	view.setup(layer, FreneticPalette.RUIN_FAR, FreneticPalette.WINDOW_FAR)
	var material := ShaderMaterial.new()
	material.shader = GRUNGE_SHADER
	material.set_shader_parameter("dirt", dirt)
	view.material = material
	parallax.add_child(view)
	_generated.add_child(parallax)
	return view


func _apply_skyline_colors() -> void:
	if sky == null or _far_view == null:
		return
	var far := sky.skyline_far_color()
	var near := sky.skyline_near_color()
	_far_view.set_colors(far, far.darkened(0.3))
	_near_view.set_colors(near, near.darkened(0.45))


func _make_colliders(roofs: Array[Rect2]) -> StaticBody2D:
	var body := StaticBody2D.new()
	for roof in roofs:
		var shape := RectangleShape2D.new()
		shape.size = roof.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = roof.get_center()
		body.add_child(collision)
	return body


func _build_runtime() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -100
	var sky_rect := _full_screen_rect(SKY_SHADER)
	_sky_material = sky_rect.material
	sky_layer.add_child(sky_rect)
	add_child(sky_layer)

	_world_light = CanvasModulate.new()
	add_child(_world_light)

	_tracker = RhythmTracker.new()
	_tracker.judged.connect(_on_judged)
	_tracker.combo_broken.connect(_on_combo_broken)
	add_child(_tracker)

	_player = PlayerPrototype.new()
	_player.params = player_params
	_player.jumped.connect(_on_player_jumped)
	_player.turned.connect(_on_player_turned)
	_player.landed.connect(_on_player_landed)
	add_child(_player)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	add_child(_camera)

	var post_layer := CanvasLayer.new()
	post_layer.layer = 50
	var post_rect := _full_screen_rect(POST_SHADER)
	_post = post_rect.material
	post_layer.add_child(post_rect)
	add_child(post_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 60
	add_child(ui_layer)
	_hud = RhythmHud.new()
	_hud.tracker = _tracker
	ui_layer.add_child(_hud)
	var help := Label.new()
	help.text = "←/→ mover · Espacio saltar · ↓ caída forzada · Tab menú de debug · R/N/P seed"
	help.position = Vector2(24.0, 18.0)
	help.add_theme_color_override("font_color", FreneticPalette.CREAM)
	help.add_theme_color_override("font_outline_color", FreneticPalette.INK)
	help.add_theme_constant_override("outline_size", 8)
	ui_layer.add_child(help)
	_menu = DebugMenu.new()
	ui_layer.add_child(_menu)
	_build_debug_menu()


func _build_debug_menu() -> void:
	_build_map_section(_menu.add_section("Mapa"))
	_build_sky_section(_menu.add_section("Cielo"))
	_build_lighting_section(_menu.add_section("Luz"))
	_build_player_section(_menu.add_section("Jugador"))
	_build_rhythm_section(_menu.add_section("Ritmo"))
	_build_system_section(_menu.add_section("Sistema"))
	_menu.get_node("Tabs").current_tab = _initial_tab


func _build_map_section(section: DebugSection) -> void:
	section.add_preset_bar(params, "mapa")
	section.add_group("Semilla")
	_seed_text = section.add_text("Seed actual: %d" % params.seed)
	section.add_buttons([
		["◀", func() -> void: params.seed = maxi(1, params.seed - 1)],
		["Aleatoria", func() -> void: params.seed = randi_range(1, 999999)],
		["▶", func() -> void: params.seed += 1],
	])
	section.add_slider(params, &"seed", "Seed", 1, 999999, 1)
	section.add_group("Azoteas")
	section.add_slider(params, &"roof_count", "Cantidad de azoteas", 3, 64, 1)
	section.add_slider(params, &"roof_width_min", "Ancho mínimo", 200, 2000, 10)
	section.add_slider(params, &"roof_width_max", "Ancho máximo", 200, 2000, 10)
	section.add_slider(params, &"gap_chance", "Probabilidad de hueco", 0.0, 1.0, 0.01)
	section.add_slider(params, &"gap_max", "Hueco máximo (px)", 0, 400, 10)
	section.add_slider(params, &"roof_base_y", "Altura base (px)", 400, 1000, 10)
	section.add_slider(params, &"roof_height_variation", "Relieve (px)", 0, 400, 10)
	section.add_slider(params, &"max_step", "Escalón máximo (px)", 0, 200, 10)
	section.add_group("Skyline")
	section.add_slider(params, &"ruin", "Ruina", 0.0, 1.0, 0.01)
	section.add_slider(params, &"broken_windows", "Ventanas rotas", 0.0, 1.0, 0.01)
	section.add_slider(params, &"skyline_width", "Ancho del skyline (px)", 1024, 8192, 256)


func _build_sky_section(section: DebugSection) -> void:
	section.add_preset_bar(sky, "cielo")
	section.add_group("Cielo")
	section.add_toggle(sky, &"pixelate", "Pixel-art")
	section.add_slider(sky, &"pixel_resolution", "Resolución", 64, 640, 1)
	section.add_slider(sky, &"star_density", "Densidad de estrellas", 0.0, 1.0, 0.01)
	section.add_slider(sky, &"cloud_coverage", "Nubes", 0.0, 1.0, 0.01)
	section.add_slider(sky, &"mountain_layers", "Capas de montañas", 0, 6, 1)
	section.add_slider(sky, &"sun_position", "Posición del sol", 0.0, 1.0, 0.01)
	section.add_slider(sky, &"sun_elevation", "Elevación del sol", 0.0, 1.0, 0.01)
	section.add_slider(sky, &"sun_size", "Tamaño del sol", 0, 64, 1)
	section.add_slider(sky, &"horizon_line", "Línea de horizonte", 0.2, 1.0, 0.01)
	section.add_slider(sky, &"dither_strength", "Dithering", 0.0, 1.0, 0.01)
	section.add_slider(sky, &"snowfall", "Nieve / ceniza", 0.0, 1.0, 0.01)
	section.add_group("Paleta")
	section.add_color(sky, &"sky_apex", "Cénit")
	section.add_color(sky, &"horizon_glow", "Resplandor del horizonte")
	section.add_color(sky, &"sun_color", "Sol")
	section.add_color(sky, &"water_color", "Agua")
	section.add_color(sky, &"land_color", "Tierra")


func _build_lighting_section(section: DebugSection) -> void:
	section.add_preset_bar(lighting, "iluminacion")
	section.add_group("Iluminación")
	section.add_slider(lighting, &"ambient", "Luz ambiente", 0.0, 1.0, 0.01)
	section.add_slider(lighting, &"sun_light", "Tinte del sol", 0.0, 1.0, 0.01)
	section.add_slider(lighting, &"beat_flash", "Destello en el beat", 0.0, 1.0, 0.01)
	section.add_slider(lighting, &"sun_beat_pulse", "Pulso del sol (BPM)", 0.0, 1.0, 0.01)
	section.add_slider(lighting, &"combo_flash", "Destello por combo", 0.0, 1.0, 0.01)


func _build_player_section(section: DebugSection) -> void:
	var p := player_params
	section.add_preset_bar(p, "jugador")
	section.add_group("Movimiento")
	section.add_slider(p, &"max_speed", "Velocidad máxima", 100, 1500, 10)
	section.add_slider(p, &"ground_accel", "Aceleración en suelo", 500, 10000, 100)
	section.add_slider(p, &"air_accel", "Aceleración en aire", 0, 10000, 100)
	section.add_group("Salto")
	section.add_slider(p, &"jump_force", "Fuerza de salto", 300, 2000, 10)
	section.add_slider(p, &"gravity", "Gravedad", 500, 6000, 50)
	section.add_slider(p, &"fall_gravity_multiplier", "Gravedad al caer (×)", 1.0, 3.0, 0.05)
	section.add_slider(p, &"jump_cut", "Corte al soltar salto (×)", 0.1, 1.0, 0.05)
	section.add_slider(p, &"coyote_time", "Coyote time (s)", 0.0, 0.3, 0.01)
	section.add_slider(p, &"jump_buffer", "Buffer de salto (s)", 0.0, 0.3, 0.01)
	section.add_group("Caída forzada (↓)")
	section.add_toggle(p, &"fast_fall_enabled", "Activada")
	section.add_slider(p, &"fast_fall_speed", "Velocidad de caída", 800, 5000, 50)
	section.add_slider(p, &"slam_points_multiplier", "Puntos si cae a tiempo (×)", 1.0, 5.0, 0.1)
	section.add_slider(p, &"stumble_time", "Aturdimiento si falla (s)", 0.0, 2.0, 0.05)
	section.add_slider(p, &"stumble_speed", "Velocidad aturdido (×)", 0.0, 1.0, 0.05)
	section.add_group("Recompensas de ritmo")
	section.add_slider(p, &"jump_boost_perfect", "Salto PERFECTO (×)", 1.0, 2.0, 0.01)
	section.add_slider(p, &"jump_boost_good", "Salto BIEN (×)", 1.0, 2.0, 0.01)
	section.add_slider(p, &"turn_boost_perfect", "Giro PERFECTO (×)", 1.0, 2.5, 0.05)
	section.add_slider(p, &"turn_boost_good", "Giro BIEN (×)", 1.0, 2.5, 0.05)
	section.add_slider(p, &"boost_time", "Duración del impulso (s)", 0.0, 2.0, 0.05)
	section.add_slider(p, &"spin_time", "Duración del giro (s)", 0.05, 1.0, 0.01)
	section.add_group("Visual")
	section.add_slider(p, &"beat_bounce", "Rebote al compás", 0.0, 0.4, 0.01)


func _build_rhythm_section(section: DebugSection) -> void:
	var r := Conductor.params
	section.add_preset_bar(r, "ritmo")
	section.add_group("Tempo")
	section.add_slider(r, &"bpm", "BPM", 60, 240, 1)
	section.add_toggle(r, &"metronome_enabled", "Metrónomo")
	section.add_slider(r, &"metronome_volume_db", "Volumen metrónomo (dB)", -40, 6, 1)
	section.add_slider(r, &"input_offset", "Latencia (s)", -0.2, 0.2, 0.005)
	section.add_group("Juicio")
	section.add_slider(r, &"perfect_window", "Ventana PERFECTO (s)", 0.01, 0.2, 0.005)
	section.add_slider(r, &"good_window", "Ventana BIEN (s)", 0.02, 0.3, 0.005)
	section.add_slider(r, &"combo_timeout_beats", "Beats para perder combo", 1, 16, 1)


func _build_system_section(section: DebugSection) -> void:
	section.add_group("Estado")
	_stats_text = section.add_text()
	section.add_group("Pruebas")
	section.add_toggle(self, &"autorun", "Recorrido automático")
	section.add_slider(Engine, &"time_scale", "Escala de tiempo", 0.1, 2.0, 0.05)
	section.add_buttons([
		["Respawn", _respawn],
		["Reiniciar puntaje", _tracker.reset],
	])


func _full_screen_rect(shader: Shader) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	return rect


func _respawn() -> void:
	_player.position = _data.spawn
	_player.reset_state()
	_camera.position = _camera_target()
	_camera.reset_smoothing()


func _camera_target() -> Vector2:
	return Vector2(_player.position.x + 260.0, minf(_player.position.y - 240.0, _data.kill_y - 900.0))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not autorun:
		return
	# Corre a la derecha, salta en los bordes y fuerza la caída al pasar el punto más alto.
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


func _process(delta: float) -> void:
	_apply_skyline_colors()
	if Engine.is_editor_hint():
		return
	if _player.position.y > _data.kill_y:
		_respawn()
	_camera.position = _camera_target()

	var pulse := Conductor.pulse()
	var heat := _tracker.heat()
	for uniform in SkyParams.SHADER_UNIFORMS:
		_sky_material.set_shader_parameter(uniform, sky.get(uniform))
	for uniform in LightingParams.SHADER_UNIFORMS:
		_sky_material.set_shader_parameter(uniform, lighting.get(uniform))
	_sky_material.set_shader_parameter("beat_pulse", pulse)
	_sky_material.set_shader_parameter("combo_heat", heat)
	_world_light.color = lighting.world_tint(sky, pulse, heat)

	_shock = move_toward(_shock, 0.0, delta * 2.5)
	_post.set_shader_parameter("shock", _shock)
	_camera.offset = Vector2(_fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0)) * _shock * 18.0

	if _menu.visible:
		_stats_text.text = "FPS %d · beat %d · combo %d (mejor %d) · %d pts\nposición %v" % [
			Engine.get_frames_per_second(), Conductor.beat_index(), _tracker.combo,
			_tracker.best_combo, _tracker.score, _player.position.round()]


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_TAB, KEY_F1:
			_menu.visible = not _menu.visible
		KEY_R:
			params.seed = randi_range(1, 999999)
		KEY_N:
			params.seed += 1
		KEY_P:
			params.seed = maxi(1, params.seed - 1)


func _on_player_jumped() -> void:
	var judgment := _tracker.register(&"jump")
	match judgment:
		ConductorClock.Judgment.PERFECT:
			_player.boost_jump(player_params.jump_boost_perfect)
			_spawn_burst(0.6)
		ConductorClock.Judgment.GOOD:
			_player.boost_jump(player_params.jump_boost_good)
			_spawn_burst(0.45)


func _on_player_turned(_direction: float) -> void:
	match _tracker.register(&"turn"):
		ConductorClock.Judgment.PERFECT:
			_player.spin(player_params.turn_boost_perfect)
		ConductorClock.Judgment.GOOD:
			_player.spin(player_params.turn_boost_good)


func _on_player_landed(impact_speed: float, forced: bool) -> void:
	if forced:
		_on_slam()
		return
	if impact_speed < LAND_MIN_SPEED:
		return
	match _tracker.register(&"land", false):
		ConductorClock.Judgment.PERFECT:
			_spawn_burst(1.6)
			_shock = maxf(_shock, 0.8)
		ConductorClock.Judgment.GOOD:
			_spawn_burst(1.15)
			_shock = maxf(_shock, 0.45)
		_:
			if impact_speed >= BURST_MIN_SPEED:
				_spawn_burst(0.7)
				_shock = maxf(_shock, 0.2)


## Aterrizaje de caída forzada: es intencional, así que se premia fuerte o se castiga.
func _on_slam() -> void:
	match _tracker.register(&"slam", true, player_params.slam_points_multiplier):
		ConductorClock.Judgment.PERFECT:
			_spawn_burst(2.1)
			_shock = 1.0
		ConductorClock.Judgment.GOOD:
			_spawn_burst(1.5)
			_shock = maxf(_shock, 0.6)
		_:
			_player.stumble()
			_spawn_burst(0.5)
			_shock = maxf(_shock, 0.15)


func _spawn_burst(strength: float) -> void:
	var burst := ImpactBurst.new(_fx_rng, strength)
	burst.position = _player.position
	add_child(burst)


func _on_judged(action: StringName, judgment: int, _combo: int, points: int) -> void:
	# Los fallos de caída forzada siempre se anuncian (son el castigo visible).
	if judgment != ConductorClock.Judgment.MISS or action == &"slam":
		_hud.popup(judgment, _player_screen_position(), points)


## Otros fallos solo se anuncian cuando rompen un combo: girar libremente no llena la pantalla.
func _on_combo_broken(action: StringName, _lost_combo: int) -> void:
	if action != &"slam":
		_hud.popup(ConductorClock.Judgment.MISS, _player_screen_position(), 0)


func _player_screen_position() -> Vector2:
	return get_viewport().get_canvas_transform() * _player.global_position
