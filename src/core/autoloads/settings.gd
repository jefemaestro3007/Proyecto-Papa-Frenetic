class_name GameSettings
extends Node
## Configuración del jugador (autoload `Settings`): audio, video, controles, juego, dificultad y
## opciones de desarrollador (menú de debug en la campaña y monitor del sistema).
## Se guarda en `user://configuracion.cfg` y se aplica al cambiar: los volúmenes van a los buses
## de audio, el video a la ventana, las teclas al InputMap y lo de la partida (estilo, temblor,
## latencia, dificultad) a la zona que esté abierta, que escucha `changed`.
## Los tests llaman `use_defaults()` para no depender de lo que el jugador haya guardado.

signal changed

const FILE := "user://configuracion.cfg"
const MUSIC_BUS := AudioBuses.MUSIC
const SFX_BUS := AudioBuses.SFX
## Acciones que se pueden reasignar, en el orden del menú: [acción, nombre].
const ACTIONS := [
	[&"move_left", "Move left"], [&"move_right", "Move right"],
	[&"move_up", "Up / use"], [&"move_down", "Down / stomp"],
	[&"jump", "Jump"], [&"attack", "Attack"], [&"dash", "Dash"],
]
## Teclas por acción en el menú (principal y alternativa).
const SLOTS := 2
## Teclas que no se pueden asignar: Esc pausa y Tab/F1 abren el menú de debug.
const RESERVED_KEYS: Array[int] = [KEY_ESCAPE, KEY_TAB, KEY_F1]
const FPS_LIMITS: Array[int] = [0, 30, 60, 120, 144, 240]
## Estilos gráficos: "" respeta el del nivel.
const STYLES: Array[String] = ["", "default", "pixel", "isaac"]
## La última es la personalizada: usa los multiplicadores de `custom_difficulty`.
const DIFFICULTIES: Array[StringName] = [&"facil", &"normal", &"dificil", &"personalizada"]
## Multiplicadores de cada dificultad sobre los valores del nivel:
## `heat` = calor que suma todo (pasivo, fallos, golpes); `fuse` = segundos de mecha;
## `windows` = ventanas de PERFECTO/BIEN; `enemy_speed` = velocidad de las papas;
## `enemies` = cantidad de papas (se nota al empezar o reintentar el nivel).
const DIFFICULTY := {
	&"facil": {"heat": 0.7, "fuse": 1.5, "windows": 1.25, "enemy_speed": 0.85, "enemies": 0.7},
	&"normal": {"heat": 1.0, "fuse": 1.0, "windows": 1.0, "enemy_speed": 1.0, "enemies": 1.0},
	&"dificil": {"heat": 1.3, "fuse": 0.7, "windows": 0.8, "enemy_speed": 1.15, "enemies": 1.3},
}
## Rango de cada multiplicador en la dificultad personalizada.
const CUSTOM_RANGES := {
	"heat": Vector2(0.25, 2.0), "fuse": Vector2(0.5, 3.0), "windows": Vector2(0.5, 2.0),
	"enemy_speed": Vector2(0.5, 2.0), "enemies": Vector2(0.0, 2.5),
}
## Monitor del sistema: apagado, solo FPS o completo.
enum Monitor { OFF, FPS, FULL }
const HEAT_PROPERTIES: Array[StringName] = [&"passive_heating", &"miss_heating", &"slam_miss_heat",
		&"contact_heat", &"projectile_heat", &"fall_heat", &"whiff_heat"]
const ENEMY_SPEED_PROPERTIES: Array[StringName] = [&"potato_speed", &"tank_speed", &"flyer_speed",
		&"charger_speed"]
const SHAKE_PROPERTIES: Array[StringName] = [&"trauma_scale", &"tension_shake_scale", &"zoom_punch_scale"]
const WINDOW_PROPERTIES: Array[StringName] = [&"perfect_window", &"good_window"]
## Metadato con los valores del nivel antes de aplicar dificultad y temblor (así no se acumulan).
const BASE_META := &"settings_base"

# Audio (0..1, lineal).
var master_volume := 1.0
var music_volume := 1.0
var sfx_volume := 1.0
var muted := false
# Video.
var fullscreen := false
var vsync := true
## 0 = sin límite.
var fps_limit := 0
# Juego.
var style := ""
## Temblor de cámara y zoom de los golpes (0..1).
var screen_shake := 1.0
## Corrección de latencia del ritmo en milisegundos (positivo = se juzga más tarde).
var input_offset_ms := 0
# Dificultad.
var difficulty := &"normal"
var custom_difficulty := {}
# Desarrollador.
## En la campaña habilita el menú de debug (Tab/F1), F2, R/N/P y la línea de ayuda.
var developer_mode := false
var monitor := Monitor.OFF
## Acción → teclas (keycodes físicos, 0 = vacía), `SLOTS` por acción.
var bindings := {}

var _default_bindings := {}
var _persist := true
var _monitor_layer: CanvasLayer
var _monitor: SystemMonitor


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	for pair in ACTIONS:
		_default_bindings[pair[0]] = _keys_in_input_map(pair[0])
	bindings = _default_bindings.duplicate(true)
	custom_difficulty = DIFFICULTY[&"normal"].duplicate()
	_monitor_layer = CanvasLayer.new()
	_monitor_layer.layer = 120
	add_child(_monitor_layer)
	_monitor = SystemMonitor.new()
	_monitor_layer.add_child(_monitor)
	load_settings()
	apply()


## Valores por defecto sin leer ni escribir el archivo (para los tests).
func use_defaults() -> void:
	_persist = false
	_reset_values()
	apply()


## Vuelve todo a los valores por defecto y lo guarda.
func reset() -> void:
	_reset_values()
	commit()


## Aplica, guarda y avisa. Lo llama el menú después de cambiar un valor.
func commit() -> void:
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	_apply_audio()
	_apply_video()
	_apply_bindings()
	if _monitor != null:
		_monitor.mode = monitor


## Multiplicadores de la dificultad elegida (la personalizada usa los suyos).
func difficulty_factors() -> Dictionary:
	if difficulty == &"personalizada":
		return custom_difficulty
	return DIFFICULTY.get(difficulty, DIFFICULTY[&"normal"])


# --- Audio ---------------------------------------------------------------------------

func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func _apply_audio() -> void:
	_set_bus_volume(&"Master", 0.0 if muted else master_volume)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


static func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(index, linear <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.001)))


# --- Video ---------------------------------------------------------------------------

func _apply_video() -> void:
	Engine.max_fps = fps_limit
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


# --- Controles -----------------------------------------------------------------------

static func _keys_in_input_map(action: StringName) -> Array[int]:
	var keys: Array[int] = []
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key != null and keys.size() < SLOTS:
			keys.append(key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode)
	while keys.size() < SLOTS:
		keys.append(KEY_NONE)
	return keys


## Cambia el InputMap: las teclas de cada acción son las de `bindings` (el mouse no se toca).
func _apply_bindings() -> void:
	for action: StringName in bindings:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				InputMap.action_erase_event(action, event)
		for keycode: int in bindings[action]:
			if keycode != KEY_NONE:
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)


## Asigna una tecla a una acción. Si otra acción la usaba, intercambian: la otra se queda con la
## tecla que tenía esta. Devuelve la acción con la que se intercambió (o &"").
func bind_key(action: StringName, slot: int, keycode: int) -> StringName:
	var previous: int = bindings[action][slot]
	var swapped := &""
	for other: StringName in bindings:
		var keys: Array = bindings[other]
		for i in keys.size():
			if keys[i] == keycode and not (other == action and i == slot):
				keys[i] = previous
				swapped = other
	bindings[action][slot] = keycode
	commit()
	return swapped


func clear_key(action: StringName, slot: int) -> void:
	bindings[action][slot] = KEY_NONE
	commit()


static func can_bind(keycode: int) -> bool:
	return keycode != KEY_NONE and not RESERVED_KEYS.has(keycode)


static func key_name(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "—"
	return OS.get_keycode_string(DisplayServer.keyboard_get_label_from_physical(keycode)
			if DisplayServer.get_name() != "headless" else keycode)


# --- Partida -------------------------------------------------------------------------

## Aplica dificultad, temblor y latencia a los parámetros de una partida. Guarda en cada
## recurso sus valores originales la primera vez, así cambiar de opción no acumula.
func apply_to_match(combat: CombatParams, rhythm: RhythmParams) -> void:
	var factors := difficulty_factors()
	var base := _base_values(combat, HEAT_PROPERTIES + ENEMY_SPEED_PROPERTIES + SHAKE_PROPERTIES
			+ [&"fuse_seconds", &"enemy_density"])
	for property in HEAT_PROPERTIES:
		combat.set(property, base[property] * factors["heat"])
	for property in ENEMY_SPEED_PROPERTIES:
		combat.set(property, base[property] * factors["enemy_speed"])
	for property in SHAKE_PROPERTIES:
		combat.set(property, base[property] * screen_shake)
	combat.fuse_seconds = base[&"fuse_seconds"] * factors["fuse"]
	combat.enemy_density = base[&"enemy_density"] * factors["enemies"]
	var rhythm_base := _base_values(rhythm, WINDOW_PROPERTIES)
	for property in WINDOW_PROPERTIES:
		rhythm.set(property, rhythm_base[property] * factors["windows"])
	rhythm.input_offset = input_offset_ms / 1000.0


static func _base_values(resource: Resource, properties: Array) -> Dictionary:
	if not resource.has_meta(BASE_META):
		var base := {}
		for property in properties:
			base[property] = resource.get(property)
		resource.set_meta(BASE_META, base)
	return resource.get_meta(BASE_META)


# --- Archivo -------------------------------------------------------------------------

func _reset_values() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	muted = false
	fullscreen = false
	vsync = true
	fps_limit = 0
	style = ""
	screen_shake = 1.0
	input_offset_ms = 0
	difficulty = &"normal"
	custom_difficulty = DIFFICULTY[&"normal"].duplicate()
	developer_mode = false
	monitor = Monitor.OFF
	bindings = _default_bindings.duplicate(true)


func save_settings(path := FILE) -> void:
	if not _persist and path == FILE:
		return
	var file := ConfigFile.new()
	file.set_value("audio", "master", master_volume)
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("audio", "muted", muted)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("video", "vsync", vsync)
	file.set_value("video", "fps_limit", fps_limit)
	file.set_value("game", "style", style)
	file.set_value("game", "screen_shake", screen_shake)
	file.set_value("game", "input_offset_ms", input_offset_ms)
	file.set_value("game", "difficulty", String(difficulty))
	file.set_value("game", "custom_difficulty", custom_difficulty)
	file.set_value("developer", "enabled", developer_mode)
	file.set_value("developer", "monitor", monitor)
	for action: StringName in bindings:
		file.set_value("controls", action, bindings[action])
	file.save(path)


func load_settings(path := FILE) -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	master_volume = clampf(file.get_value("audio", "master", master_volume), 0.0, 1.0)
	music_volume = clampf(file.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(file.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
	muted = file.get_value("audio", "muted", muted)
	fullscreen = file.get_value("video", "fullscreen", fullscreen)
	vsync = file.get_value("video", "vsync", vsync)
	fps_limit = file.get_value("video", "fps_limit", fps_limit)
	var saved_style: String = file.get_value("game", "style", style)
	style = saved_style if STYLES.has(saved_style) else ""
	screen_shake = clampf(file.get_value("game", "screen_shake", screen_shake), 0.0, 1.0)
	input_offset_ms = clampi(file.get_value("game", "input_offset_ms", input_offset_ms), -200, 200)
	var saved_difficulty := StringName(file.get_value("game", "difficulty", String(difficulty)))
	difficulty = saved_difficulty if DIFFICULTIES.has(saved_difficulty) else &"normal"
	var saved_custom: Variant = file.get_value("game", "custom_difficulty", {})
	if saved_custom is Dictionary:
		for factor: String in CUSTOM_RANGES:
			var limits: Vector2 = CUSTOM_RANGES[factor]
			custom_difficulty[factor] = clampf(saved_custom.get(factor, 1.0), limits.x, limits.y)
	developer_mode = file.get_value("developer", "enabled", developer_mode)
	monitor = clampi(file.get_value("developer", "monitor", monitor), Monitor.OFF, Monitor.FULL)
	for action: StringName in bindings:
		var keys: Variant = file.get_value("controls", action, null)
		if keys is Array and keys.size() == SLOTS:
			bindings[action] = Array(keys, TYPE_INT, &"", null)
