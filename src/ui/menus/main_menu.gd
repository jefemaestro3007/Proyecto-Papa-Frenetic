class_name MainMenu
extends Control
## Menú principal (escena de inicio del juego), con las pantallas del diseño:
## START → NEW GAME → LEVEL SELECT → LOADING → nivel. Esc vuelve a la pantalla anterior.
## Las coordenadas de los botones son las de las capas de cada PSD (ver build_menu_screens.gd).

const START_BUTTON := Rect2(682, 715, 84, 36)
const NEW_GAME_BUTTON := Rect2(539, 484, 359, 57)
const LEVEL_ENTER_BUTTONS: Array[Rect2] = [Rect2(155, 639, 319, 56)]
const BACK := {&"nuevo_juego": &"inicio", &"seleccion_nivel": &"nuevo_juego"}
## La carga dura al menos esto, para que se vean las tres papas.
const LOADING_MIN_SECONDS := 1.5

var _screen: PsdScreen
var _current := &""
var _loading_phases: Array[TextureRect] = []
var _loading_time := 0.0
var _loading_path := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	show_screen(Game.menu_screen)


func show_screen(screen_name: StringName) -> void:
	if _screen != null:
		_screen.queue_free()
	_current = screen_name
	_loading_phases.clear()
	set_process(false)
	match screen_name:
		&"nuevo_juego":
			_screen = PsdScreen.new("nuevo_juego")
			_screen.add_button(NEW_GAME_BUTTON, &"nuevo_juego")
		&"seleccion_nivel":
			_screen = PsdScreen.new("seleccion_nivel")
			for i in mini(LEVEL_ENTER_BUTTONS.size(), Game.LEVELS.size()):
				_screen.add_button(LEVEL_ENTER_BUTTONS[i], StringName("nivel_%d" % i))
		&"cargando":
			_screen = PsdScreen.new("cargando")
			for i in 3:
				var phase := _screen.add_layer("cargando_fase_%d" % (i + 1))
				phase.modulate.a = 0.0
				_loading_phases.append(phase)
			_start_loading()
		_:
			_current = &"inicio"
			_screen = PsdScreen.new("inicio")
			_screen.add_button(START_BUTTON, &"start")
	_screen.action.connect(_on_action)
	add_child(_screen)
	_screen.focus_first()


func _on_action(action_name: StringName) -> void:
	match action_name:
		&"start":
			show_screen(&"nuevo_juego")
		&"nuevo_juego":
			show_screen(&"seleccion_nivel")
		_:
			if String(action_name).begins_with("nivel_"):
				Game.play(String(action_name).trim_prefix("nivel_").to_int())


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE and BACK.has(_current):
		show_screen(BACK[_current])


# --- Carga --------------------------------------------------------------------------

func _start_loading() -> void:
	_loading_path = Game.level_scene()
	_loading_time = 0.0
	ResourceLoader.load_threaded_request(_loading_path)
	set_process(true)


## Las papas aparecen de izquierda a derecha según avanza la carga (y el tiempo mínimo).
func _process(delta: float) -> void:
	_loading_time += delta
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	var loaded: float = progress[0] if not progress.is_empty() else 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		loaded = 1.0
	var shown := minf(loaded, _loading_time / LOADING_MIN_SECONDS)
	for i in _loading_phases.size():
		var target := 1.0 if shown >= (i + 1) / 3.0 - 0.001 else 0.0
		_loading_phases[i].modulate.a = move_toward(_loading_phases[i].modulate.a, target, delta * 6.0)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("No se pudo cargar " + _loading_path)
		set_process(false)
		show_screen(&"seleccion_nivel")
	elif status == ResourceLoader.THREAD_LOAD_LOADED and _loading_time >= LOADING_MIN_SECONDS + 0.2:
		set_process(false)
		get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_loading_path))
