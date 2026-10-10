@tool
class_name ZoneLevel
extends Node2D
## Base de toda zona jugable: cielo, iluminación, jugador, ritmo, efectos de impacto,
## modos gráficos (ArtStyle), post-proceso, HUD y menú de debug.
## Cada zona implementa solo lo suyo sobrescribiendo los métodos `_zone_*`.
## En juego: A/D mover, Espacio saltar, J/clic atacar, Shift dash, S en el aire caída forzada (stomp),
## Tab/F1 menú de debug, Enter reintentar al terminar la partida,
## F2 cambia de estilo (Default / Pixel / Isaac), R/N/P seeds.

const SKY_SHADER := preload("res://src/world/environment/shaders/sky.gdshader")
const GRUNGE_SHADER := preload("res://src/world/environment/shaders/ruin_grunge.gdshader")
const POST_SHADER := preload("res://src/world/environment/shaders/frenetic_post.gdshader")
const PRESETS := "res://src/shared/resources/presets/"
const MUSIC := "res://src/shared/resources/music/"
const DEFAULT_LOOK := "rojo_frenetico"
const STYLES: Array[String] = ["default", "pixel", "isaac"]
const STOMP_CLOUD := "res://assets/textures/sprites/fx/stomp_nube.png"
## Botones de las pantallas YOU WIN / YOU LOOSE (coordenadas del PSD).
const RESULT_MENU_BUTTON := Rect2(438, 702, 278, 58)
const RESULT_RIGHT_BUTTON := Rect2(725, 700, 281, 60)

const FAR_SCROLL := Vector2(0.15, 0.08)
const NEAR_SCROLL := Vector2(0.4, 0.22)
## Aterrizajes más suaves que esto (saltitos) ni siquiera se juzgan.
const LAND_MIN_SPEED := 400.0
## Nombre de cada acción en los textos de juicio.
const ACTION_LABELS := {&"air_attack": "AÉREO ", &"slam": "STOMP ", &"dash": "DASH "}
## Acciones de combate: sus fallos siempre se anuncian con el calor que suman.
const COMBAT_ACTIONS: Array[StringName] = [&"attack", &"air_attack", &"slam", &"dash"]
## Movimientos intencionales: fallarlos calienta `movement_heat_scale` (aterrizar, escaleras,
## ascensores y puertas nunca castigan).
const MOVE_ACTIONS: Array[StringName] = [&"jump", &"turn"]

## Estado de la partida (del prototipo, adaptado): jugando, llegó a la salida o explotó la papa.
enum Match { PLAYING, VICTORY, GAME_OVER }

@export var sky: SkyParams
@export var lighting: LightingParams
@export var player_params: PlayerParams
@export var impact_fx: ImpactFxParams
@export var style: ArtStyle
## Combate y enemigos traídos del prototipo (pestaña "Combate").
@export var combat: CombatParams

@export_tool_button("Regenerar", "Reload") var regenerate_button := regenerate

## Recorrido automático (para capturas y pruebas); cada zona define cómo se mueve.
var autorun := false
## Acercamiento de la cámara: más alto = se ve menos del mapa, más grande.
var camera_zoom := 1.0:
	set(value):
		camera_zoom = clampf(value, 0.4, 2.5)
		if _camera != null:
			_camera.zoom = Vector2.ONE * camera_zoom

var _generated: Node2D
var _player: PlayerPrototype
var _camera: Camera2D
var _sky_material: ShaderMaterial
var _post: ShaderMaterial
var _world_light: CanvasModulate
var _tracker: RhythmTracker
var _combat: CombatController
var _hud: RhythmHud
var _heat_hud: HeatHud
## Pantalla de fin de partida (YOU WIN / YOU LOOSE del diseño), encima de todo.
var _result_layer: CanvasLayer
var _result: PsdScreen
var _heat: HeatMeter
var _feel: GameFeel
var _match := Match.PLAYING
## Segundos de juego desde el inicio (o el último reintento).
var _elapsed := 0.0
var _menu: DebugMenu
var _seed_text: Label
var _stats_text: Label
var _fx_rng := RandomNumberGenerator.new()
var _shock := 0.0
var _initial_tab := 0
var _style_name := "default"
var _hide_menu := false
var _style_signature := 0
var _skyline_views: Array[SkylineView] = []
var _grunge_materials: Array[ShaderMaterial] = []
var _sections := {}
var _music_text: Label
var _zoom_override := 0.0
## Falso mientras _ready arma la zona: los cambios de parámetros no regeneran a mitad de camino.
var _initialized := false


# --- Ganchos de cada zona ------------------------------------------------------------

## Parámetros del mapa de la zona (deben tener `seed` y emitir `changed`).
func _zone_params() -> Resource:
	return null


## Crea los parámetros por defecto si faltan.
func _zone_ensure_params() -> void:
	pass


## Construye el contenido de la zona dentro de `_generated`.
func _zone_generate() -> void:
	pass


## Controles propios de la pestaña Mapa (la semilla y los presets ya los pone la base).
func _zone_map_controls(_section: DebugSection) -> void:
	pass


## Carpeta de presets del mapa de la zona.
func _zone_map_folder() -> String:
	return "mapa"


func _zone_spawn() -> Vector2:
	return Vector2.ZERO


## Por debajo de esta Y el jugador reaparece.
func _zone_kill_y() -> float:
	return INF


func _zone_camera_target() -> Vector2:
	return _player.position


## Acercamiento inicial de la cámara en esta zona.
func _zone_default_zoom() -> float:
	return 1.0


## Se llama cuando cambia cualquier valor del estilo: redibujar lo estático.
func _zone_style_changed() -> void:
	pass


func _zone_autorun(_delta: float) -> void:
	pass


## Rectángulos sólidos con los que chocan las papas voladoras.
func _zone_solids() -> Array[Rect2]:
	return []


## Canción de la zona (`MusicTrack`): pone el tempo del Conductor.
func _zone_music() -> MusicTrack:
	return null


func _zone_help_text() -> String:
	return "A/D mover · Espacio saltar · J/clic atacar · Shift dash · S en el aire caída forzada · Tab menú · " \
			+ "F2 estilo · R/N/P seed"


# --- Ciclo de vida -------------------------------------------------------------------

func _ready() -> void:
	_zone_ensure_params()
	if sky == null:
		sky = _load_preset("cielo", DEFAULT_LOOK, SkyParams.new())
	if lighting == null:
		lighting = _load_preset("iluminacion", DEFAULT_LOOK, LightingParams.new())
	if player_params == null:
		player_params = PlayerParams.new()
	if impact_fx == null:
		impact_fx = _load_preset("efectos", "base", ImpactFxParams.new())
	if style == null:
		style = _load_preset("estilo", "default", ArtStyle.new())
	if combat == null:
		combat = _load_preset("combate", "base", CombatParams.new())
	if not Engine.is_editor_hint():
		_parse_args()
		_build_runtime()
	regenerate()
	_initialized = true


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autorun":
			autorun = true
		elif arg.begins_with("--seed="):
			_zone_params().seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--set="):
			# --set=propiedad=valor: cualquier parámetro del mapa (útil para pruebas y capturas).
			var pair := arg.trim_prefix("--set=").split("=")
			if pair.size() == 2:
				_zone_params().set(pair[0], str_to_var(pair[1]))
		elif arg.begins_with("--debug-tab="):
			_initial_tab = arg.trim_prefix("--debug-tab=").to_int()
		elif arg.begins_with("--zoom="):
			_zoom_override = arg.trim_prefix("--zoom=").to_float()
		elif arg == "--hide-menu":
			_hide_menu = true
		elif arg.begins_with("--style="):
			apply_style(arg.trim_prefix("--style="))
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
	_fx_rng.seed = _zone_params().seed
	_generated = Node2D.new()
	_generated.name = "Generated"
	add_child(_generated)
	move_child(_generated, 0)
	_grunge_materials.clear()
	_skyline_views.clear()
	if _combat != null:
		_combat.clear()
		_combat.world = _generated
		_combat.style = style

	_zone_generate()
	_apply_skyline_colors()
	_style_signature = 0
	_apply_style_to_world()

	if _player != null:
		_reset_match()
		_respawn()
	if _seed_text != null:
		_seed_text.text = "Seed actual: %d" % _zone_params().seed


func _on_params_changed() -> void:
	if _initialized and is_node_ready():
		regenerate()


# --- Estilo --------------------------------------------------------------------------

## Carga un estilo por nombre (presets/estilo/<nombre>.tres) junto con su cielo e iluminación.
func apply_style(style_name: String) -> void:
	var path := PRESETS + "estilo/" + style_name + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("Estilo inexistente: " + style_name)
		return
	_style_name = style_name
	DebugSection.copy_into(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE), style)
	_on_style_loaded()


## Tras cargar un estilo: aplica sus presets de cielo e iluminación y refresca el menú.
func _on_style_loaded() -> void:
	for pair in [["cielo", style.sky_preset, sky], ["iluminacion", style.lighting_preset, lighting]]:
		var path: String = PRESETS + pair[0] + "/" + pair[1] + ".tres"
		if ResourceLoader.exists(path):
			DebugSection.copy_into(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE), pair[2])
	for section: DebugSection in _sections.values():
		section.refresh()


## Lo estático solo se actualiza cuando cambia algún valor del estilo.
func _apply_style_to_world() -> void:
	var signature := style.signature()
	if signature == _style_signature or _generated == null:
		return
	_style_signature = signature
	for material in _grunge_materials:
		material.set_shader_parameter("dirt", style.skyline_dirt)
	_zone_style_changed()


func _make_grunge() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRUNGE_SHADER
	return material


## Capa de skyline con parallax infinito; su color sigue a la paleta del cielo.
func _add_skyline_layer(layer: AzoteaMapData.SkylineData, scroll: Vector2) -> SkylineView:
	var parallax := Parallax2D.new()
	parallax.scroll_scale = scroll
	parallax.repeat_size = Vector2(layer.width, 0.0)
	parallax.repeat_times = 3
	var view := SkylineView.new()
	view.setup(layer, FreneticPalette.RUIN_FAR, FreneticPalette.WINDOW_FAR)
	var material := _make_grunge()
	_grunge_materials.append(material)
	view.material = material
	parallax.add_child(view)
	_generated.add_child(parallax)
	_skyline_views.append(view)
	return view


## La primera capa usa el color lejano y las demás el cercano.
func _apply_skyline_colors() -> void:
	if sky == null:
		return
	for i in _skyline_views.size():
		var color := sky.skyline_far_color() if i == 0 else sky.skyline_near_color()
		_skyline_views[i].set_colors(color, color.darkened(0.3 if i == 0 else 0.45))


static func _make_colliders(rects: Array[Rect2]) -> StaticBody2D:
	var body := StaticBody2D.new()
	for rect in rects:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		body.add_child(collision)
	return body


# --- Runtime -------------------------------------------------------------------------

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

	_combat = CombatController.new()
	_combat.params = combat
	_combat.bind_player(_player)
	_combat.tracker = _tracker
	_combat.hit_landed.connect(_on_hit_landed)
	_combat.player_hurt.connect(_on_player_hurt)
	_combat.player_bounced.connect(_on_player_bounced)
	_combat.whiffed.connect(_on_whiffed)
	_combat.projectile_hit.connect(_on_projectile_hit)
	_player.dash_started.connect(_on_dash_started)
	add_child(_combat)

	_heat = HeatMeter.new()
	_heat.params = combat
	_heat.overheat_started.connect(_on_overheat.bind(true))
	_heat.overheat_ended.connect(_on_overheat.bind(false))
	_heat.exploded.connect(_on_exploded)
	add_child(_heat)
	_feel = GameFeel.new()
	_feel.params = combat
	add_child(_feel)
	Conductor.beat.connect(_on_beat)

	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 6.0
	_camera.ignore_rotation = false
	add_child(_camera)
	camera_zoom = _zoom_override if _zoom_override > 0.0 else _zone_default_zoom()

	var post_layer := CanvasLayer.new()
	post_layer.layer = 50
	var post_rect := _full_screen_rect(POST_SHADER)
	_post = post_rect.material
	post_layer.add_child(post_rect)
	add_child(post_layer)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 60
	add_child(ui_layer)
	_heat_hud = HeatHud.new()
	ui_layer.add_child(_heat_hud)
	_hud = RhythmHud.new()
	_hud.tracker = _tracker
	ui_layer.add_child(_hud)
	var help := Label.new()
	help.text = _zone_help_text()
	help.position = Vector2(24.0, 18.0)
	help.add_theme_color_override("font_color", FreneticPalette.CREAM)
	help.add_theme_color_override("font_outline_color", FreneticPalette.INK)
	help.add_theme_constant_override("outline_size", 8)
	ui_layer.add_child(help)
	_menu = DebugMenu.new()
	ui_layer.add_child(_menu)
	_build_debug_menu()
	Conductor.play_track(_zone_music())


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Conductor.stop_music()


func _build_debug_menu() -> void:
	var builders := {
		"Estilo": _build_style_section, "Mapa": _build_map_section, "Cielo": _build_sky_section,
		"Luz": _build_lighting_section, "Jugador": _build_player_section, "Efectos": _build_fx_section,
		"Ritmo": _build_rhythm_section, "Combate": _build_combat_section, "Sistema": _build_system_section,
	}
	for title in builders:
		var section := _menu.add_section(title)
		_sections[title] = section
		builders[title].call(section)
	_menu.get_node("Tabs").current_tab = _initial_tab
	# Entrando desde el menú principal el menú de debug arranca cerrado (Tab lo abre).
	_menu.visible = not _hide_menu and Game.level_index < 0


func _build_style_section(section: DebugSection) -> void:
	section.add_group("Modo")
	section.add_buttons([
		["Default", apply_style.bind("default")],
		["Pixel", apply_style.bind("pixel")],
		["Isaac", apply_style.bind("isaac")],
	])
	section.add_text("F2 alterna los modos. Cada modo trae su cielo e iluminación; los rasgos "
			+ "de cada uno se pueden mezclar libremente.")
	section.add_preset_bar(style, "estilo")
	section.preset_loaded.connect(func(_path: String) -> void: _on_style_loaded())

	section.add_group("Gráfico (Default)")
	section.add_slider(style, &"burst_lines", "Rayos detrás del sol", 0.0, 1.0, 0.01)
	section.add_slider(style, &"halftone", "Trama de semitono", 0.0, 1.0, 0.01)
	section.add_slider(style, &"fence_amount", "Azoteas con alambrado", 0.0, 1.0, 0.01)
	section.add_toggle(style, &"cable_flags", "Banderines en cables")
	section.add_toggle(style, &"hazard_stripes", "Franjas de peligro")
	section.add_slider(style, &"poster_amount", "Afiches", 0.0, 1.0, 0.01)
	section.add_slider(style, &"graffiti_amount", "Grafitis", 0.0, 1.0, 0.01)
	section.add_slider(style, &"aberration", "Aberración cromática", 0.0, 6.0, 0.1)

	section.add_group("Retro (Pixel)")
	section.add_slider(style, &"pixel_size", "Tamaño de pixel", 1, 12, 1)
	section.add_slider(style, &"color_levels", "Niveles de color (0 = libre)", 0, 32, 1)
	section.add_slider(style, &"dither", "Dithering", 0.0, 1.0, 0.01)
	section.add_slider(style, &"cel_shading", "Sombreado por caras", 0.0, 1.0, 0.01)
	section.add_toggle(style, &"rim_light", "Borde de luz")
	section.add_slider(style, &"scanlines", "Líneas de escaneo", 0.0, 1.0, 0.01)
	section.add_slider(style, &"crt_curvature", "Curvatura CRT", 0.0, 1.0, 0.01)

	section.add_group("Sótano (Isaac)")
	section.add_slider(style, &"wobble", "Trazo a mano (px)", 0, 10, 0.5)
	section.add_toggle(style, &"drop_shadows", "Sombras proyectadas")
	section.add_slider(style, &"flies", "Moscas", 0.0, 1.0, 0.01)
	section.add_slider(style, &"cobwebs", "Telarañas", 0.0, 1.0, 0.01)
	section.add_slider(style, &"bones_amount", "Huesos", 0.0, 1.0, 0.01)
	section.add_slider(style, &"spotlight", "Foco en el jugador", 0.0, 1.0, 0.01)
	section.add_slider(style, &"spotlight_radius", "Radio del foco", 0.1, 1.5, 0.01)
	section.add_slider(style, &"light_shaft", "Haz de luz", 0.0, 1.0, 0.01)

	section.add_group("Detalles comunes")
	section.add_slider(style, &"outline_width", "Contorno (px)", 0, 12, 0.5)
	section.add_toggle(style, &"facade_windows", "Ventanas en fachadas")
	section.add_slider(style, &"lit_windows", "Ventanas encendidas", 0.0, 1.0, 0.01)
	section.add_toggle(style, &"drainpipes", "Bajantes de agua")
	section.add_slider(style, &"bricks", "Ladrillos", 0.0, 1.0, 0.01)
	section.add_slider(style, &"fires", "Fuego en barriles", 0.0, 1.0, 0.01)
	section.add_slider(style, &"wall_unit_amount", "Aires en fachadas", 0.0, 1.0, 0.01)

	section.add_group("Marcas")
	section.add_slider(style, &"blood_amount", "Sangre", 0.0, 1.0, 0.01)
	section.add_slider(style, &"crack_amount", "Grietas", 0.0, 1.0, 0.01)
	section.add_slider(style, &"stain_amount", "Manchas", 0.0, 1.0, 0.01)
	section.add_slider(style, &"rubble_amount", "Escombros", 0.0, 1.0, 0.01)
	section.add_slider(style, &"grime", "Mugre en azoteas", 0.0, 1.0, 0.01)
	section.add_slider(style, &"skyline_dirt", "Mugre en skyline", 0.0, 1.0, 0.01)

	section.add_group("Colores")
	section.add_color(style, &"structure", "Estructura")
	section.add_color(style, &"structure_dark", "Estructura oscura")
	section.add_color(style, &"structure_light", "Estructura clara")
	section.add_color(style, &"edge", "Borde pisable")
	section.add_color(style, &"outline", "Contorno")
	section.add_color(style, &"accent", "Acento")
	section.add_color(style, &"blood", "Sangre")
	section.add_color(style, &"rock", "Roca")
	section.add_color(style, &"rock_light", "Brillo de roca")
	section.add_color(style, &"window_dark", "Ventana apagada")
	section.add_color(style, &"window_lit", "Ventana encendida")

	section.add_group("Post-proceso")
	section.add_slider(style, &"vignette", "Viñeta", 0.0, 1.0, 0.01)
	section.add_slider(style, &"vignette_softness", "Suavidad de viñeta", 0.0, 1.0, 0.01)
	section.add_slider(style, &"desaturate", "Desaturar", 0.0, 1.0, 0.01)
	section.add_color(style, &"tint", "Tinte")
	section.add_slider(style, &"grain", "Grano", 0.0, 0.3, 0.005)


func _build_map_section(section: DebugSection) -> void:
	var map := _zone_params()
	section.add_preset_bar(map, _zone_map_folder())
	section.add_group("Semilla")
	_seed_text = section.add_text("Seed actual: %d" % map.seed)
	section.add_buttons([
		["◀", func() -> void: map.seed = maxi(1, map.seed - 1)],
		["Aleatoria", func() -> void: map.seed = randi_range(1, 999999)],
		["▶", func() -> void: map.seed += 1],
	])
	section.add_slider(map, &"seed", "Seed", 1, 999999, 1)
	_zone_map_controls(section)


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
	section.add_group("Caídas")
	section.add_slider(p, &"hard_landing_height", "Altura para atacar (px)", 0, 2000, 10)
	section.add_group("Caída forzada (S en el aire)")
	section.add_toggle(p, &"fast_fall_enabled", "Activada")
	section.add_slider(p, &"fast_fall_speed", "Velocidad de caída", 800, 5000, 50)
	section.add_slider(p, &"slam_points_multiplier", "Puntos si cae a tiempo (×)", 1.0, 5.0, 0.1)
	section.add_slider(p, &"stumble_time", "Aturdimiento si falla (s)", 0.0, 2.0, 0.05)
	section.add_slider(p, &"stumble_speed", "Velocidad aturdido (×)", 0.0, 1.0, 0.05)
	section.add_group("Dash (Shift, solo en el suelo)")
	section.add_toggle(p, &"dash_enabled", "Activado")
	section.add_slider(p, &"dash_speed", "Velocidad", 400, 4000, 10)
	section.add_slider(p, &"dash_duration", "Duración (s)", 0.05, 0.5, 0.01)
	section.add_slider(p, &"dash_cooldown", "Espera (s)", 0.0, 15.0, 0.1)
	section.add_group("Rebote (contra papas que aguantan)")
	section.add_slider(p, &"recoil_x", "Rebote horizontal", 0, 1500, 10)
	section.add_slider(p, &"recoil_y", "Rebote vertical", 0, 1500, 10)
	section.add_slider(p, &"recoil_invulnerable", "Invulnerable tras rebotar (s)", 0.0, 2.0, 0.05)
	section.add_group("Recompensas de ritmo")
	section.add_slider(p, &"jump_boost_perfect", "Salto PERFECTO (×)", 1.0, 2.0, 0.01)
	section.add_slider(p, &"jump_boost_good", "Salto BIEN (×)", 1.0, 2.0, 0.01)
	section.add_slider(p, &"turn_boost_perfect", "Giro PERFECTO (×)", 1.0, 2.5, 0.05)
	section.add_slider(p, &"turn_boost_good", "Giro BIEN (×)", 1.0, 2.5, 0.05)
	section.add_slider(p, &"boost_time", "Duración del impulso (s)", 0.0, 2.0, 0.05)
	section.add_slider(p, &"spin_time", "Duración del giro (s)", 0.05, 1.0, 0.01)
	section.add_group("Visual")
	section.add_slider(p, &"beat_bounce", "Rebote al compás", 0.0, 0.4, 0.01)


func _build_fx_section(section: DebugSection) -> void:
	var fx := impact_fx
	section.add_preset_bar(fx, "efectos")
	section.add_group("Intensidad por caída")
	section.add_slider(fx, &"hard_landing_perfect", "Caída alta PERFECTO", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"hard_landing_good", "Caída alta BIEN", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"hard_landing_miss", "Caída alta fuera de tiempo", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"slam_perfect", "Caída forzada PERFECTO", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"slam_good", "Caída forzada BIEN", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"slam_miss", "Caída forzada fallida", 0.0, 4.0, 0.05)
	section.add_slider(fx, &"jump_spark", "Chispa de salto a tiempo", 0.0, 2.0, 0.05)
	section.add_group("Rayos")
	section.add_slider(fx, &"ray_count_min", "Cantidad mínima", 0, 48, 1)
	section.add_slider(fx, &"ray_count_max", "Cantidad máxima", 0, 48, 1)
	section.add_slider(fx, &"ray_length_min", "Largo mínimo (px)", 10, 600, 5)
	section.add_slider(fx, &"ray_length_max", "Largo máximo (px)", 10, 600, 5)
	section.add_slider(fx, &"ray_width_min", "Grosor mínimo (px)", 2, 80, 1)
	section.add_slider(fx, &"ray_width_max", "Grosor máximo (px)", 2, 80, 1)
	section.add_slider(fx, &"spread_degrees", "Apertura (°)", 10, 360, 1)
	section.add_slider(fx, &"jaggedness", "Dentado (px)", 0, 40, 1)
	section.add_slider(fx, &"ray_lifetime", "Duración (s)", 0.0, 1.0, 0.01)
	section.add_slider(fx, &"scale_start", "Escala inicial", 0.1, 3.0, 0.05)
	section.add_slider(fx, &"scale_end", "Escala final", 0.1, 3.0, 0.05)
	section.add_slider(fx, &"outline_width", "Contorno (px)", 0, 12, 0.5)
	section.add_color(fx, &"fill_color", "Relleno")
	section.add_color(fx, &"outline_color", "Contorno")
	section.add_group("Escombros")
	section.add_slider(fx, &"debris_count", "Cantidad", 0, 120, 1)
	section.add_slider(fx, &"debris_speed_min", "Velocidad mínima", 0, 2000, 10)
	section.add_slider(fx, &"debris_speed_max", "Velocidad máxima", 0, 2000, 10)
	section.add_slider(fx, &"debris_gravity", "Gravedad", 0, 6000, 50)
	section.add_slider(fx, &"debris_size_min", "Tamaño mínimo (px)", 1, 40, 1)
	section.add_slider(fx, &"debris_size_max", "Tamaño máximo (px)", 1, 40, 1)
	section.add_slider(fx, &"debris_lifetime", "Duración (s)", 0.05, 3.0, 0.05)
	section.add_color(fx, &"debris_color", "Color principal")
	section.add_color(fx, &"debris_color_alt", "Color secundario")
	section.add_group("Pantalla")
	section.add_slider(fx, &"screen_shake", "Temblor de cámara (px)", 0, 60, 1)
	section.add_slider(fx, &"glitch_strength", "Glitch", 0.0, 2.0, 0.05)
	section.add_buttons([["Probar impacto", func() -> void: _impact(impact_fx.slam_perfect)]])


func _build_rhythm_section(section: DebugSection) -> void:
	var r := Conductor.params
	section.add_preset_bar(r, "ritmo")
	section.add_group("Música")
	_music_text = section.add_text()
	section.add_toggle(r, &"music_enabled", "Música")
	section.add_slider(r, &"music_volume_db", "Volumen música (dB)", -40, 6, 1)
	var songs := [["Zona", func() -> void: Conductor.play_track(_zone_music())]]
	for track in _music_tracks():
		songs.append([track.title.get_slice(" (", 0), Conductor.play_track.bind(track)])
	section.add_buttons(songs)
	section.add_buttons([["Sin música", Conductor.stop_music], ["Reiniciar canción", Conductor.restart]])
	section.add_group("Tempo")
	section.add_slider(r, &"bpm", "BPM", 60, 240, 1)
	section.add_toggle(r, &"metronome_enabled", "Metrónomo")
	section.add_toggle(r, &"metronome_over_music", "Metrónomo sobre la música")
	section.add_slider(r, &"metronome_volume_db", "Volumen metrónomo (dB)", -40, 6, 1)
	section.add_slider(r, &"input_offset", "Latencia (s)", -0.2, 0.2, 0.005)
	section.add_group("Juicio")
	section.add_slider(r, &"perfect_window", "Ventana PERFECTO (s)", 0.01, 0.2, 0.005)
	section.add_slider(r, &"good_window", "Ventana BIEN (s)", 0.02, 0.3, 0.005)
	section.add_slider(r, &"combo_timeout_beats", "Beats para perder combo", 1, 16, 1)


static func _music_tracks() -> Array[MusicTrack]:
	var out: Array[MusicTrack] = []
	for file in ResourceLoader.list_directory(MUSIC):
		if file.ends_with(".tres"):
			var track := load(MUSIC + file) as MusicTrack
			if track != null:
				out.append(track)
	return out


## Todo lo integrado desde el prototipo `feature/gameplay-prototype`, separado del resto.
func _build_combat_section(section: DebugSection) -> void:
	section.add_text("Combate, calor y enemigos traídos del prototipo (feature/gameplay-prototype). " \
			+ "Atacar: J o clic izquierdo · Dash: Shift.")
	section.add_preset_bar(combat, "combate")
	section.add_group("Calor (papa caliente)")
	section.add_toggle(combat, &"heat_enabled", "Calor activado")
	section.add_toggle(combat, &"game_over_enabled", "Game over al explotar")
	section.add_slider(combat, &"passive_heating", "Calor pasivo (por segundo)", 0.0, 10.0, 0.1)
	section.add_slider(combat, &"perfect_cooling", "Enfría PERFECTO", 0.0, 30.0, 0.5)
	section.add_slider(combat, &"good_cooling", "Enfría BIEN", 0.0, 30.0, 0.5)
	section.add_slider(combat, &"miss_heating", "Calienta FUERA", 0.0, 40.0, 0.5)
	section.add_slider(combat, &"movement_heat_scale", "Fallar salto o giro (× fallo)", 0.0, 1.0, 0.05)
	section.add_slider(combat, &"movement_cooling_perfect", "Moverse PERFECTO enfría", 0.0, 5.0, 0.1)
	section.add_slider(combat, &"movement_cooling_good", "Moverse BIEN enfría", 0.0, 5.0, 0.1)
	section.add_slider(combat, &"movement_cooling_share", "Tope: parte del calor pasivo", 0.0, 0.95, 0.05)
	section.add_slider(combat, &"slam_miss_heat", "Caída forzada fuera de ritmo", 0.0, 40.0, 0.5)
	section.add_slider(combat, &"whiff_heat", "Tajo al aire fuera de ritmo", 0.0, 20.0, 0.5)
	section.add_slider(combat, &"contact_heat", "Tocar una papa", 0.0, 40.0, 0.5)
	section.add_slider(combat, &"projectile_heat", "Papa frita", 0.0, 40.0, 0.5)
	section.add_slider(combat, &"fall_heat", "Caer al vacío", 0.0, 40.0, 0.5)
	section.add_slider(combat, &"intensity_threshold", "Tensión desde (calor)", 0.0, 100.0, 1)
	section.add_slider(combat, &"fuse_seconds", "Mecha (s)", 1.0, 30.0, 0.5)
	section.add_buttons([
		["Calor 0", func() -> void: _heat.change(-HeatMeter.MAX_HEAT)],
		["Calor 90", func() -> void: _heat.change(90.0 - _heat.heat)],
		["Calor 100", func() -> void: _heat.change(HeatMeter.MAX_HEAT)],
	])
	section.add_group("Ataque")
	section.add_slider(combat, &"ground_reach", "Alcance en el suelo (px)", 40, 400, 5)
	section.add_slider(combat, &"ground_height", "Alto del alcance (px)", 40, 300, 5)
	section.add_slider(combat, &"air_radius", "Radio del ataque aéreo (px)", 40, 400, 5)
	section.add_slider(combat, &"miss_recoil", "Rebote al fallar el ritmo", 0, 1200, 10)
	section.add_slider(combat, &"stomp_radius", "Radio del stomp (px)", 40, 400, 5)
	section.add_group("Golpe recibido")
	section.add_slider(combat, &"hurt_invulnerable", "Invulnerable tras el golpe (s)", 0.0, 3.0, 0.05)
	section.add_slider(combat, &"hurt_knockback_x", "Retroceso horizontal", 0, 1500, 10)
	section.add_slider(combat, &"hurt_knockback_y", "Retroceso vertical", 0, 1500, 10)
	section.add_group("Sensación")
	section.add_toggle(combat, &"hitstop_enabled", "Hitstop (congela un instante)")
	section.add_slider(combat, &"hitstop_scale", "Duración del hitstop (×)", 0.0, 3.0, 0.05)
	section.add_slider(combat, &"zoom_punch_scale", "Zoom de impacto (×)", 0.0, 3.0, 0.05)
	section.add_slider(combat, &"trauma_scale", "Temblor por golpes (×)", 0.0, 3.0, 0.05)
	section.add_slider(combat, &"tension_shake_scale", "Temblor por calor (×)", 0.0, 3.0, 0.05)
	section.add_group("Enemigos (se aplican al regenerar: R/N/P)")
	section.add_text("Al inicio de cada zona solo hay papas comunes; luego aparece un tipo nuevo por tramo.\n" \
			+ "Azotea: común → voladora → tiradora → embestidora. Oficinas: común → tanque → embestidora → tiradora.")
	section.add_slider(combat, &"enemy_density", "Cantidad de enemigos", 0.0, 1.0, 0.01)
	section.add_slider(combat, &"same_level_tolerance", "Distancia de 'mismo nivel' (px)", 10, 200, 5)
	section.add_slider(combat, &"potato_speed", "Común: velocidad", 0, 600, 5)
	section.add_slider(combat, &"potato_health", "Común: vida", 1, 10, 1)
	section.add_slider(combat, &"tank_speed", "Tanque: velocidad", 0, 600, 5)
	section.add_slider(combat, &"tank_health", "Tanque: vida", 1, 10, 1)
	section.add_slider(combat, &"flyer_speed", "Voladora: velocidad", 0, 600, 5)
	section.add_slider(combat, &"charger_speed", "Embestidora: velocidad de carga", 200, 2500, 10)
	section.add_slider(combat, &"charger_recover", "Embestidora: aturdida (s)", 0.2, 3.0, 0.05)
	section.add_slider(combat, &"thrower_bars_between", "Tiradora: compases entre ráfagas", 1, 8, 1)
	section.add_slider(combat, &"thrower_eighths", "Tiradora: peso corcheas (negra = 1)", 0.0, 3.0, 0.05)
	section.add_slider(combat, &"thrower_sixteenths", "Tiradora: peso semicorcheas", 0.0, 3.0, 0.05)


func _build_system_section(section: DebugSection) -> void:
	section.add_group("Estado")
	_stats_text = section.add_text()
	section.add_group("Cámara")
	section.add_slider(self, &"camera_zoom", "Zoom (más = se ve menos)", 0.4, 2.5, 0.05)
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
	_player.position = _zone_spawn()
	_player.reset_state()
	_camera.position = _zone_camera_target()
	_camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not autorun or not is_playing():
		return
	_zone_autorun(delta)


func _process(delta: float) -> void:
	_apply_skyline_colors()
	_apply_style_to_world()
	if Engine.is_editor_hint():
		return
	if _player.position.y > _zone_kill_y():
		_respawn()
		_fell_into_void()
	_camera.position = _zone_camera_target()
	_update_heat(delta)

	var pulse := Conductor.pulse()
	var heat := _tracker.heat()
	for uniform in SkyParams.SHADER_UNIFORMS:
		_sky_material.set_shader_parameter(uniform, sky.get(uniform))
	for uniform in LightingParams.SHADER_UNIFORMS:
		_sky_material.set_shader_parameter(uniform, lighting.get(uniform))
	for uniform in ArtStyle.SKY_UNIFORMS:
		_sky_material.set_shader_parameter(uniform, style.get(uniform))
	_sky_material.set_shader_parameter("beat_pulse", pulse)
	_sky_material.set_shader_parameter("combo_heat", heat)
	_world_light.color = lighting.world_tint(sky, pulse, heat)

	_shock = move_toward(_shock, 0.0, delta * 2.5)
	for uniform in ArtStyle.POST_UNIFORMS:
		_post.set_shader_parameter(uniform, style.get(uniform))
	_post.set_shader_parameter("shock", _shock)
	_post.set_shader_parameter("spotlight_center",
			_player_screen_position() / get_viewport().get_visible_rect().size)
	_camera.offset = Vector2(_fx_rng.randf_range(-1.0, 1.0), _fx_rng.randf_range(-1.0, 1.0)) \
			* _shock * impact_fx.screen_shake + _feel.camera_offset()
	_camera.rotation = _feel.camera_rotation()
	_camera.zoom = Vector2.ONE * camera_zoom * _feel.zoom_factor()

	if _menu.visible:
		var track := Conductor.current_track()
		_music_text.text = "Sonando: %s · %.0f BPM" % [
			track.title if track != null and Conductor.is_music_playing() else "nada (metrónomo)",
			Conductor.params.bpm]
		_stats_text.text = "FPS %d · beat %d · combo %d (mejor %d) · %d pts\nposición %v · calor %.0f%s · %s" % [
			Engine.get_frames_per_second(), Conductor.beat_index(), _tracker.combo,
			_tracker.best_combo, _tracker.score, _player.position.round(), _heat.heat,
			" · mecha %.1f s" % _heat.fuse_left if _heat.overheated else "", Match.keys()[_match]]


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var map := _zone_params()
	match key.keycode:
		KEY_TAB, KEY_F1:
			_menu.visible = not _menu.visible
		KEY_F2:
			apply_style(STYLES[(STYLES.find(_style_name) + 1) % STYLES.size()])
		KEY_R:
			map.seed = randi_range(1, 999999)
		KEY_N:
			map.seed += 1
		KEY_P:
			map.seed = maxi(1, map.seed - 1)
		KEY_ENTER, KEY_KP_ENTER:
			# Fin de partida: reintentar la misma seed.
			if not is_playing():
				regenerate()
				Conductor.restart()


# --- Partida: calor, game over y victoria --------------------------------------------

func is_playing() -> bool:
	return _match == Match.PLAYING


## Vuelve a empezar la partida (al regenerar o reintentar): calor, mecha, puntaje y efectos.
func _reset_match() -> void:
	_match = Match.PLAYING
	_elapsed = 0.0
	_heat.reset()
	_feel.reset()
	_heat_hud.reset()
	_hide_result()
	_tracker.reset()
	_combat.active = true
	_player.visible = true
	_player.process_mode = Node.PROCESS_MODE_INHERIT


func _update_heat(delta: float) -> void:
	if is_playing():
		_elapsed += delta
		_heat.advance(delta)
	var intensity := _heat.intensity() if combat.heat_enabled and is_playing() else 0.0
	var overheated := _heat.overheated and is_playing()
	_heat_hud.visible = combat.heat_enabled or not is_playing()
	_heat_hud.set_heat(_heat.heat)
	_heat_hud.update_fuse(_heat.fuse_left)
	_heat_hud.set_intensity(intensity, overheated)
	_feel.set_intensity(intensity, overheated)
	_heat_hud.update_dash(player_params.dash_enabled and is_playing(), _player.dash_cooldown_left(), player_params.dash_cooldown,
			not _player.is_on_floor(), _player.facing)


## Suma (o resta) calor durante la partida y lo anuncia sobre el jugador.
func _add_heat(amount: float, text := "") -> void:
	if not is_playing() or not combat.heat_enabled or amount == 0.0:
		return
	_heat.change(amount)
	var at := _player_screen_position()
	if not text.is_empty():
		_hud.say(text, at, FreneticPalette.SKY.lightened(0.3))
	_hud.say_heat(amount, at + Vector2(0.0, 44.0))


func _fell_into_void() -> void:
	_add_heat(combat.fall_heat, "¡AL VACÍO!")


func _on_overheat(fuse_left: float, started: bool) -> void:
	if is_playing():
		_heat_hud.show_overheat(started, fuse_left)


func _on_beat(index: int) -> void:
	var accented := index % ConductorClock.BEATS_PER_BAR == 0
	if is_playing():
		_feel.on_beat(1.0 if accented else 0.7)
		_heat_hud.on_beat(accented)


## La mecha llegó a 0: la papa explota. Sin game over (pruebas) solo hay explosión y el calor
## vuelve a empezar.
func _on_exploded() -> void:
	_explosion_at(_player.position + Vector2(0.0, -PlayerPrototype.SIZE.y * 0.5))
	_heat_hud.show_overheat(false, 0.0)
	if not combat.game_over_enabled:
		_hud.say("¡BUM! (sin game over)", _player_screen_position(), FreneticPalette.YELLOW)
		return
	_match = Match.GAME_OVER
	_end_match()
	_player.visible = false
	_show_result(false)


## Llamar desde la zona al llegar a la salida.
func finish_victory() -> void:
	if not is_playing():
		return
	_match = Match.VICTORY
	_end_match()
	_heat_hud.show_overheat(false, 0.0)
	_show_result(true)


## Pantalla del diseño al terminar: YOU LOOSE (volver al menú o reintentar con la misma seed) o
## YOU WIN (volver al menú o pasar al siguiente nivel; si no hay otro, la misma zona con otra seed).
## Las coordenadas de los botones son las de las capas de los PSD.
func _show_result(won: bool) -> void:
	_hide_result()
	if _result_layer == null:
		_result_layer = CanvasLayer.new()
		_result_layer.layer = 70
		add_child(_result_layer)
	_result = PsdScreen.new("ganaste" if won else "perdiste", Color(PsdScreen.BACKDROP, 0.82))
	_result.add_button(RESULT_RIGHT_BUTTON, &"siguiente" if won else &"reintentar")
	_result.add_button(RESULT_MENU_BUTTON, &"menu")
	_result.action.connect(_on_result_action)
	_result_layer.add_child(_result)
	_result.focus_first()


func _hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null


func _on_result_action(action_name: StringName) -> void:
	match action_name:
		&"menu":
			Game.go_to_menu()
		&"reintentar":
			regenerate()
			Conductor.restart()
		&"siguiente":
			if Game.has_next_level():
				Game.next_level()
			else:
				_zone_params().seed += 1
				Conductor.restart()


## Congela el mundo (jugador, enemigos, proyectiles) al terminar la partida.
func _end_match() -> void:
	_combat.active = false
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_generated.process_mode = Node.PROCESS_MODE_DISABLED
	_feel.set_intensity(0.0, false)


# --- Ritmo y recompensas -------------------------------------------------------------

func _on_player_jumped() -> void:
	var judgment := _tracker.register_move(&"jump")
	match judgment:
		ConductorClock.Judgment.PERFECT:
			_player.boost_jump(player_params.jump_boost_perfect)
			_spawn_burst(impact_fx.jump_spark)
		ConductorClock.Judgment.GOOD:
			_player.boost_jump(player_params.jump_boost_good)
			_spawn_burst(impact_fx.jump_spark * 0.75)


func _on_player_turned(_direction: float) -> void:
	match _tracker.register_move(&"turn"):
		ConductorClock.Judgment.PERFECT:
			_player.spin(player_params.turn_boost_perfect)
		ConductorClock.Judgment.GOOD:
			_player.spin(player_params.turn_boost_good)


func _on_player_landed(impact_speed: float, forced: bool, fall_height: float) -> void:
	if forced:
		_on_slam()
		return
	var attacks := fall_height >= player_params.hard_landing_height
	if impact_speed < LAND_MIN_SPEED and not attacks:
		return
	# Aterrizar a tiempo siempre suma, pero solo una caída alta produce el ataque.
	var judgment := _tracker.register_move(&"land", false)
	if not attacks:
		return
	match judgment:
		ConductorClock.Judgment.PERFECT:
			_impact(impact_fx.hard_landing_perfect)
		ConductorClock.Judgment.GOOD:
			_impact(impact_fx.hard_landing_good)
		_:
			_impact(impact_fx.hard_landing_miss)


## Aterrizaje de caída forzada: es el stomp, golpea a las papas cerca de los pies con su juicio.
## Con papas debajo cuenta como golpe; sin papas es un movimiento. Fallada castiga fuerte
## (`slam_miss_heat`) para que no se abuse de ella.
func _on_slam() -> void:
	var judgment := Conductor.judge()
	if _combat.stomp(judgment):
		_tracker.register_judgment(&"slam", judgment, true, player_params.slam_points_multiplier)
	else:
		_tracker.register_move_judgment(&"slam", judgment)
	_stomp_cloud(1.6 if judgment == ConductorClock.Judgment.PERFECT else 1.3)
	match judgment:
		ConductorClock.Judgment.PERFECT:
			_impact(impact_fx.slam_perfect)
		ConductorClock.Judgment.GOOD:
			_impact(impact_fx.slam_good)
		_:
			_player.stumble()
			_impact(impact_fx.slam_miss)


## Nube del stomp (sprite del equipo) a los pies del jugador.
func _stomp_cloud(strength: float) -> void:
	if not ResourceLoader.exists(STOMP_CLOUD):
		return
	var cloud := ImpactSprite.new(load(STOMP_CLOUD), strength)
	cloud.position = _player.position + Vector2(0.0, 6.0)
	cloud.z_index = 55
	add_child(cloud)


## Ataque de caída: estallido + glitch y temblor proporcionales a la intensidad.
func _impact(strength: float) -> void:
	_spawn_burst(strength)
	_shock = maxf(_shock, impact_fx.shock_for(strength))
	if strength >= 1.0:
		_feel.add_trauma(0.25 * strength)
		_feel.zoom_punch(0.015 * strength)


## Coloca un enemigo en su carril (solo en juego, no en el editor).
func spawn_enemy(enemy: Enemy, feet: Vector2, lane_left: float, lane_right: float) -> void:
	if _combat == null or _player == null:
		enemy.free()
		return
	enemy.position = feet
	enemy.configure(_player, lane_left, lane_right, style)
	if enemy is FlyingEnemy:
		enemy.set_solids(_zone_solids())
	_generated.add_child(enemy)
	_combat.register_enemy(enemy)


## Golpe a una papa: estallido con sus colores, glitch, hitstop, zoom y temblor.
func _on_hit_landed(enemy: Enemy, judgment: int, defeated: bool) -> void:
	var perfect := judgment == ConductorClock.Judgment.PERFECT
	var strength := (0.9 if perfect else 0.6) * (1.0 if defeated else 0.6)
	var direction := signf(enemy.global_position.x - _player.global_position.x)
	_burst(enemy.body_center(), strength, {
		"angle": -PI * 0.5 + direction * 0.5,
		"fill": impact_fx.fill_color if perfect else FreneticPalette.CREAM,
		"debris": enemy.body_color,
		"debris_alt": Color("f0cf86") if defeated else Color(0.85, 0.88, 0.95),
		"ring": Color(1.0, 1.0, 1.0, 0.9) if defeated else Color.TRANSPARENT,
	})
	_shock = maxf(_shock, impact_fx.shock_for(strength) * 0.6)
	_feel.hit(perfect, defeated)


func _on_player_hurt(enemy: Enemy) -> void:
	_hurt_fx()
	_add_heat(combat.contact_heat * enemy.contact_heat_scale, "¡AUCH!")


## Stomp o dash fuera de ritmo contra una papa: rebota (el calor ya lo puso el juicio).
func _on_player_bounced(_enemy: Enemy) -> void:
	_hurt_fx()


func _hurt_fx() -> void:
	_burst(_player.position + Vector2(0.0, -PlayerPrototype.SIZE.y * 0.5), 0.6, {
		"spread": 300.0, "fill": style.blood.lightened(0.2), "debris": style.blood,
		"debris_alt": Color("ef6657"), "ring": Color("ef6657"),
	})
	_shock = maxf(_shock, 0.35)
	_feel.hurt()


## Tajo al aire: a tiempo no pasa nada; fuera de tiempo calienta un poco sin romper el combo.
func _on_whiffed(judgment: int) -> void:
	if judgment == ConductorClock.Judgment.MISS:
		_add_heat(combat.whiff_heat)


func _on_projectile_hit(at: Vector2) -> void:
	_burst(at, 0.35, {"spread": 360.0, "fill": Color("f2c14e"), "debris": Color("f2c14e"),
			"debris_alt": Color("d98e2b")})
	_feel.add_trauma(0.22)
	_add_heat(combat.projectile_heat, "¡PAPA FRITA!")


func _on_dash_started(direction: float) -> void:
	_burst(_player.position + Vector2(-direction * 30.0, -10.0), 0.35, {
		"angle": PI if direction > 0.0 else 0.0, "spread": 60.0,
		"fill": FreneticPalette.CREAM, "debris": FreneticPalette.CREAM,
	})
	_feel.add_trauma(0.2)


## La papa explota: estallido enorme en todas direcciones, glitch y sacudida máxima.
func _explosion_at(at: Vector2) -> void:
	_burst(at, 2.6, {
		"spread": 360.0, "fill": Color("ff7a2f"), "debris": Color("f0cf86"),
		"debris_alt": FreneticPalette.INK, "ring": Color(1.0, 0.95, 0.7),
	})
	_shock = 1.0
	_feel.explosion()


func _burst(at: Vector2, strength: float, look: Dictionary) -> void:
	look["style"] = style
	var burst := ImpactBurst.new(_fx_rng, strength, impact_fx, look)
	burst.position = at
	burst.z_index = 60
	add_child(burst)


func _spawn_burst(strength: float) -> void:
	if strength <= 0.0:
		return
	var burst := ImpactBurst.new(_fx_rng, strength, impact_fx)
	burst.position = _player.position
	add_child(burst)


func _on_judged(action: StringName, judgment: int, _combo: int, points: int, hit: bool) -> void:
	var heat := 0.0
	if is_playing() and combat.heat_enabled:
		var before := _heat.heat
		if judgment == ConductorClock.Judgment.MISS and action == &"slam":
			_heat.change(combat.slam_miss_heat)
		elif hit:
			# Golpes: la fuente principal para enfriar (y fallarlos calienta de lleno).
			_heat.apply_judgment(judgment)
		elif judgment != ConductorClock.Judgment.MISS:
			# Movimientos a tiempo: enfrían poco y con tope, nunca más que el calor pasivo.
			_heat.cool_movement(judgment)
		elif action in MOVE_ACTIONS:
			_heat.apply_judgment(judgment, combat.movement_heat_scale)
		heat = _heat.heat - before
	# Los fallos de combate siempre se anuncian (son el castigo visible).
	if judgment != ConductorClock.Judgment.MISS or action in COMBAT_ACTIONS:
		_hud.popup(judgment, _player_screen_position(), points, ACTION_LABELS.get(action, ""),
				heat if action in COMBAT_ACTIONS else 0.0)


## Otros fallos solo se anuncian cuando rompen un combo: girar libremente no llena la pantalla.
func _on_combo_broken(action: StringName, _lost_combo: int) -> void:
	# Los fallos de combate y los golpes recibidos ya tienen su propio aviso.
	if not action in COMBAT_ACTIONS and action != &"hit":
		_hud.popup(ConductorClock.Judgment.MISS, _player_screen_position(), 0)


func _player_screen_position() -> Vector2:
	return get_viewport().get_canvas_transform() * _player.global_position
