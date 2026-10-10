extends Node
## Configuración del jugador: buses de audio, teclas (con intercambio), dificultad y temblor sin
## acumularse, guardar/cargar, la pantalla con sus pestañas y teclado, y abrirla desde la pausa
## y desde START. Corre como escena (necesita los autoloads). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/settings.tscn

const LEVEL := "res://src/world/levels/azotea/azotea.tscn"
const TEMP_FILE := "user://test_configuracion.cfg"

var _failures := 0


func _ready() -> void:
	Settings.use_defaults()
	Conductor.params.metronome_enabled = false
	_test_audio()
	_test_bindings()
	_test_match()
	_test_file()
	await _test_screen()
	await _test_pause()
	await _test_menu()
	Settings.use_defaults()
	print("test_settings: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_audio() -> void:
	for bus in [GameSettings.MUSIC_BUS, GameSettings.SFX_BUS]:
		var index := AudioServer.get_bus_index(bus)
		_check(index > 0 and AudioServer.get_bus_send(index) == &"Master", "bus %s hacia Master" % bus)
	_check(Conductor._music.bus == GameSettings.MUSIC_BUS, "la música va al bus Musica")
	_check(Conductor._click.bus == GameSettings.SFX_BUS, "el metrónomo va al bus Efectos")
	Settings.music_volume = 0.5
	Settings.commit()
	var music := AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	_check(absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.5)) < 0.01, "volumen de música al 50 %")
	Settings.sfx_volume = 0.0
	Settings.muted = true
	Settings.commit()
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.SFX_BUS)), "efectos en 0 = silencio")
	_check(AudioServer.is_bus_mute(0), "silenciar todo apaga Master")
	Settings.use_defaults()
	_check(not AudioServer.is_bus_mute(0) and AudioServer.get_bus_volume_db(music) == 0.0, "valores por defecto")


func _test_bindings() -> void:
	var dash_keys: Array = Settings.bindings[&"dash"].duplicate()
	_check(dash_keys.has(KEY_K), "K es dash por defecto")
	var swapped := Settings.bind_key(&"jump", 0, KEY_K)
	_check(swapped == &"dash", "K se intercambia con dash")
	_check(_action_has_key(&"jump", KEY_K), "saltar con K en el InputMap")
	_check(_action_has_key(&"dash", KEY_SPACE), "dash se queda con Espacio")
	_check(not _action_has_key(&"dash", KEY_K), "dash ya no usa K")
	_check(_action_has_mouse(&"attack"), "el clic de atacar no se toca")
	Settings.clear_key(&"jump", 0)
	_check(not _action_has_key(&"jump", KEY_K), "borrar la tecla la saca del InputMap")
	_check(not GameSettings.can_bind(KEY_ESCAPE) and not GameSettings.can_bind(KEY_TAB), "Esc y Tab reservadas")
	Settings.use_defaults()
	_check(_action_has_key(&"jump", KEY_SPACE) and _action_has_key(&"dash", KEY_K), "teclas por defecto")


func _test_match() -> void:
	var combat := CombatParams.new()
	var rhythm := RhythmParams.new()
	var fuse := combat.fuse_seconds
	var passive := combat.passive_heating
	var good := rhythm.good_window
	Settings.difficulty = &"dificil"
	Settings.apply_to_match(combat, rhythm)
	Settings.apply_to_match(combat, rhythm)
	_check(is_equal_approx(combat.fuse_seconds, fuse * 0.7), "difícil: menos mecha, sin acumular")
	_check(is_equal_approx(combat.passive_heating, passive * 1.3), "difícil: más calor")
	_check(is_equal_approx(rhythm.good_window, good * 0.8), "difícil: ventanas más estrechas")
	Settings.difficulty = &"facil"
	Settings.apply_to_match(combat, rhythm)
	_check(is_equal_approx(combat.fuse_seconds, fuse * 1.5), "fácil: más mecha")
	Settings.difficulty = &"normal"
	Settings.screen_shake = 0.0
	Settings.input_offset_ms = 40
	Settings.apply_to_match(combat, rhythm)
	_check(is_equal_approx(combat.fuse_seconds, fuse) and is_equal_approx(rhythm.good_window, good),
			"normal vuelve a los valores del nivel")
	_check(combat.trauma_scale == 0.0 and combat.zoom_punch_scale == 0.0, "sin temblor")
	_check(is_equal_approx(rhythm.input_offset, 0.04), "latencia en segundos")
	Settings.use_defaults()


func _test_file() -> void:
	Settings.master_volume = 0.3
	Settings.difficulty = &"dificil"
	Settings.style = "pixel"
	Settings.bindings[&"attack"][1] = KEY_L
	Settings.save_settings(TEMP_FILE)
	Settings.use_defaults()
	Settings.load_settings(TEMP_FILE)
	_check(is_equal_approx(Settings.master_volume, 0.3), "se carga el volumen")
	_check(Settings.difficulty == &"dificil" and Settings.style == "pixel", "se carga dificultad y estilo")
	_check(Settings.bindings[&"attack"][1] == KEY_L, "se cargan las teclas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_FILE))
	Settings.use_defaults()


func _test_screen() -> void:
	var screen := SettingsScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var counts := {"AUDIO": 4, "VIDEO": 3, "CONTROLS": GameSettings.ACTIONS.size(), "GAME": 3, "DIFFICULTY": 1}
	for i in SettingsScreen.TABS.size():
		screen.show_tab(i)
		_check(screen.rows().size() == counts[SettingsScreen.TABS[i]], "filas de %s" % SettingsScreen.TABS[i])
	screen.show_tab(0)
	screen.focus_first()
	await get_tree().process_frame
	var master := screen.first_row()
	_check(master.has_focus(), "el foco empieza en la primera opción")
	_check(not screen.focused_help().is_empty(), "la opción con foco muestra su ayuda")
	_press(&"ui_left")
	_check(is_equal_approx(Settings.master_volume, 0.95), "← baja el volumen: %f" % Settings.master_volume)
	_press(&"ui_right")
	_press(&"ui_right")
	_check(is_equal_approx(Settings.master_volume, 1.0), "→ sube y no pasa del 100 %")
	# Q/E cambian de pestaña.
	_key(KEY_E)
	await get_tree().process_frame
	_check(screen.tab == 1, "E pasa a VIDEO")
	_key(KEY_Q)
	_key(KEY_Q)
	await get_tree().process_frame
	_check(screen.tab == SettingsScreen.TABS.size() - 1, "Q da la vuelta a DIFFICULTY")
	_press(&"ui_right")
	_check(Settings.difficulty == &"dificil", "→ en dificultad pasa a Hard")
	# Reasignar una tecla desde la pantalla.
	screen.show_tab(SettingsScreen.TABS.find("CONTROLS"))
	screen.focus_first()
	await get_tree().process_frame
	_press(&"ui_accept")
	_check(screen.first_row().waiting, "Enter espera la tecla nueva")
	_key(KEY_Z)
	_check(Settings.bindings[&"move_left"][0] == KEY_Z and _action_has_key(&"move_left", KEY_Z),
			"la tecla nueva queda asignada")
	_press(&"ui_accept")
	_key(KEY_ESCAPE)
	_check(not screen.first_row().waiting and Settings.bindings[&"move_left"][0] == KEY_Z, "Esc cancela")
	# DEFAULTS restablece solo la pestaña actual.
	screen._reset_tab()
	_check(Settings.bindings[&"move_left"][0] == KEY_A, "DEFAULTS vuelve las teclas")
	_check(Settings.difficulty == &"dificil", "DEFAULTS no toca otras pestañas")
	var backs := []
	screen.action.connect(func(name: StringName) -> void: backs.append(name))
	_key(KEY_ESCAPE)
	_check(backs == [&"volver"], "Esc vuelve")
	screen.queue_free()
	Settings.use_defaults()
	await get_tree().process_frame


func _test_pause() -> void:
	Settings.difficulty = &"dificil"
	var combat := CombatParams.new()
	var fuse := combat.fuse_seconds
	var level: ZoneLevel = load(LEVEL).instantiate()
	level.combat = combat
	level.set("_hide_menu", true)
	add_child(level)
	await get_tree().process_frame
	_check(is_equal_approx(level.combat.fuse_seconds, fuse * 0.7), "la zona aplica la dificultad")
	Settings.difficulty = &"normal"
	Settings.style = "pixel"
	Settings.commit()
	_check(is_equal_approx(level.combat.fuse_seconds, fuse), "cambiarla en juego se aplica al instante")
	_check(level.get("_style_name") == "pixel", "el estilo de la configuración reemplaza al del nivel")
	Settings.style = ""
	Settings.commit()
	_check(level.get("_style_name") == "default", "\"Level's own\" vuelve al estilo del nivel")
	level.pause()
	var layer: CanvasLayer = level.get("_pause_layer")
	_screen_of(layer).action.emit(&"configuracion")
	await get_tree().process_frame
	_check(_screen_of(layer) is SettingsScreen, "SETTINGS abre la configuración en la pausa")
	_check(get_tree().paused, "la partida sigue en pausa")
	_screen_of(layer).action.emit(&"volver")
	await get_tree().process_frame
	var back := _screen_of(layer)
	_check(back != null and not back is SettingsScreen, "BACK vuelve a la pausa")
	level.resume()
	level.queue_free()
	Settings.use_defaults()
	await get_tree().process_frame


func _test_menu() -> void:
	var menu: MainMenu = load("res://src/ui/menus/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	menu.get("_screen").action.emit(&"configuracion")
	await get_tree().process_frame
	_check(menu.get("_screen") is SettingsScreen, "START → SETTINGS")
	menu.get("_screen").action.emit(&"volver")
	await get_tree().process_frame
	_check(menu.get("_current") == &"inicio", "BACK vuelve a START")
	menu.queue_free()
	await get_tree().process_frame


func _screen_of(layer: CanvasLayer) -> PsdScreen:
	for child in layer.get_children():
		if child is PsdScreen and not child.is_queued_for_deletion():
			return child
	return null


func _action_has_key(action: StringName, keycode: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _action_has_mouse(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return true
	return false


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		event.keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures += 1
		print("  FALLO: ", label)
