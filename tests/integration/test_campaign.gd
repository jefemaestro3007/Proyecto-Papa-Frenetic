extends Node
## Campaña: niveles 1 y 2 con sus subniveles (lista de Game, escenas, largo, pisos y sentido,
## pausa con Esc, progreso que desbloquea niveles en LEVEL SELECT,
## neblina, estilo, enemigos, música, diálogos del tutorial en 1-1 y 2-1, y que YOU WIN no se cierre solo).
## Corre como escena (necesita los autoloads). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/campaign.tscn

const MUSIC_LEVEL_ONE := "res://src/shared/resources/music/nivel_uno.tres"
const MUSIC_LEVEL_TWO := "res://src/shared/resources/music/industrial.tres"
const AZOTEA_ONE := [&"normal", &"flyer", &"thrower", &"charger"]
const OFICINAS_TWO := [&"normal", &"tank", &"charger", &"thrower"]

var _failures := 0


func _ready() -> void:
	# Sin la configuración guardada del jugador (volúmenes, teclas, dificultad).
	Settings.use_defaults()
	Conductor.params.metronome_enabled = false
	_test_level_list()
	var tutorial_end := await _test_tutorial()
	await _test_rooftop_trial(tutorial_end)
	await _test_tower(2, true)
	await _test_tower(3, false)
	await _test_win_stays()
	await _test_pause()
	await _test_progress()
	await _test_danger()
	await _test_elevator_sync()
	Game.level_index = -1
	print("test_campaign: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _test_level_list() -> void:
	_check(Game.LEVELS.size() == 4, "4 subniveles")
	_check(Game.level_count() == 2, "2 niveles en el menú")
	_check(Game.first_sublevel(1) == 0 and Game.first_sublevel(2) == 2, "cada tarjeta entra por su primer subnivel")
	for i in Game.LEVELS.size():
		_check(ResourceLoader.exists(Game.LEVELS[i]["escena"]), "existe la escena de %s" % Game.LEVELS[i]["nombre"])
	Game.level_index = 0
	_check(Game.has_next_level(), "después de 1-1 viene 1-2")
	Game.level_index = 3
	_check(not Game.has_next_level(), "2-2 es el último")
	# Pantalla de carga propia de 1-2 → 2-1: solo llegando con NEXT LEVEL.
	Game.level_index = 2
	Game.arrived_by_next = true
	_check(ResourceLoader.exists(Game.loading_image()), "1-2 → 2-1 con su imagen de carga")
	Game.arrived_by_next = false
	_check(Game.loading_image().is_empty(), "entrando a 2-1 desde el menú, la carga normal")
	Game.level_index = 1
	Game.arrived_by_next = true
	_check(Game.loading_image().is_empty(), "1-1 → 1-2 con la carga normal")
	_check(Game.WORLD_LOADING.values().all(func(path: String) -> bool: return ResourceLoader.exists(path)),
			"existen las imágenes de carga de los mundos 2 y 3")
	Game.arrived_by_next = false


## 1-1: al empezar la protagonista cuenta la premisa (papa bomba, con el foco en la papa del HUD) y
## los controles básicos, sobre fondo oscuro y con el juego en pausa; con la primera papa, que
## golpearla enfría la papa bomba (sin fondo oscuro). 1-2: stomp y dash. 2-1: escaleras y
## ascensores. Devuelve dónde termina el mapa de 1-1.
func _test_tutorial() -> float:
	var level := await _open(0, true)
	var data: AzoteaMapData = level.get("_data")
	_check(level.tutorial == &"azotea", "1-1 tiene el tutorial de la azotea")
	_check(_track(level) == MUSIC_LEVEL_ONE, "1-1 con la canción del nivel uno")
	var hints: TutorialHints = level.get("_tutorial")
	_check(hints != null and hints.focus == level.get("_heat_hud").potato, "el foco del tutorial es la papa bomba del HUD")
	if hints != null:
		var player: PlayerPrototype = level.get("_player")
		await _frames(40)
		_check(hints.current() == &"premisa", "al empezar, la premisa de la papa bomba")
		_check(get_tree().paused and Conductor.is_paused(), "el diálogo pausa el juego y la canción")
		var spot: ShaderMaterial = hints.get("_backdrop").material
		_check(spot.get_shader_parameter("darkness") > 0.8, "la premisa va sobre fondo oscuro")
		_check(spot.get_shader_parameter("hole_radius") > 0.0, "la primera página ilumina la papa bomba")
		var beat := Conductor.beat_position()
		await _press(KEY_SPACE)
		_check(hints.is_open() and hints.page() == 0, "la primera tecla solo termina de escribir")
		await _frames(30)
		_check(Conductor.beat_position() == beat, "con el diálogo abierto no avanza el beat")
		await _press(KEY_SPACE)
		_check(hints.page() == 1, "la segunda tecla pasa de página")
		for page in [1, 2]:
			await _press(KEY_SPACE)
			await _frames(32)
			await _press(KEY_SPACE)
			if page == 1:
				_check(hints.page() == 2, "la tercera página son los controles")
				_check(spot.get_shader_parameter("hole_radius") == 0.0, "los controles van sin foco")
		await _frames(15)
		_check(not hints.is_open() and not get_tree().paused and not Conductor.is_paused(), "la última página cierra y sigue el juego")
		_check(player.is_on_floor(), "la tecla que cierra no hace saltar")
		var enemy := Enemy.new()
		enemy.position = player.position + Vector2(300.0, 0.0)
		var enemies: Array[Enemy] = [enemy]
		hints.update(player, enemies, true)
		_check(hints.current() == &"primera_papa", "la primera papa trae el diálogo de golpearla para enfriar")
		_check(spot != hints.get("_backdrop").material, "cada diálogo arma su fondo")
		_check(hints.get("_backdrop").material.get_shader_parameter("darkness") < 0.5, "el de la primera papa va sin fondo oscuro")
		hints.close()
		await _frames(15)
		hints.reset()
		await _frames(40)
		hints.update(player, enemies, true)
		_check(not hints.is_open(), "reintentar no repite los diálogos")
		enemy.free()
	var end := data.roofs[-1].end.x
	_close(level)
	for pair in [[1, &"trucos"], [2, &"edificio"]]:
		level = await _open(pair[0], true)
		hints = level.get("_tutorial")
		await _frames(40)
		_check(hints != null and hints.current() == pair[1], "%s: diálogo %s" % [Game.LEVELS[pair[0]]["nombre"], pair[1]])
		if hints != null:
			hints.close()
			await _frames(15)
		_close(level)
	return end


## 1-2: la misma azotea, 2–3 veces más larga, con los cuatro tipos mezclados.
func _test_rooftop_trial(tutorial_end: float) -> void:
	var level := await _open(1)
	var data: AzoteaMapData = level.get("_data")
	var length := data.roofs[-1].end.x
	_check(length >= tutorial_end * 2.0 and length <= tutorial_end * 3.2,
			"1-2 mide %.1f veces el tutorial" % (length / tutorial_end))
	_check(_scene_tutorial(1) == &"prueba", "1-2 con el tutorial de stomp y dash")
	_check(_track(level) == MUSIC_LEVEL_ONE, "1-2 sigue con la canción del nivel uno")
	var types := _enemy_types(level)
	_check(types.size() == AZOTEA_ONE.size() and types.all(func(t): return t in AZOTEA_ONE),
			"1-2 con normales, voladoras, tiradoras y chargers: %s" % [types])
	_close(level)


## 2-1 sube (al menos 12 pisos, con neblina) y 2-2 baja (más largo, estilo Isaac).
func _test_tower(index: int, up: bool) -> void:
	var level := await _open(index)
	var data: OficinasMapData = level.get("_data")
	var layout := data.layout
	var name: String = Game.LEVELS[index]["nombre"]
	var climb := layout.end.x - layout.start.x
	_check(climb >= 12 if up else climb <= -12, "%s recorre %d pisos" % [name, climb])
	_check(_scene_tutorial(index) == (&"edificio" if up else &""), "%s tutorial: %s" % [name, _scene_tutorial(index)])
	_check(_track(level) == MUSIC_LEVEL_TWO, "%s con la canción del nivel dos" % name)
	_check(level.room_only_view == up, "%s neblina de habitación: %s" % [name, level.room_only_view])
	_check((level.get("_style_name") == "isaac") == (not up), "%s estilo %s" % [name, level.get("_style_name")])
	var types := _enemy_types(level)
	_check(types.all(func(t): return t in OFICINAS_TWO) and types.size() >= 2,
			"%s con normales, tanques, chargers y tiradoras: %s" % [name, types])
	_close(level)


## En campaña, YOU WIN se queda en pantalla (antes Oficinas pasaba sola a otra seed a los 2.5 s).
func _test_win_stays() -> void:
	var level := await _open(2)
	var data: OficinasMapData = level.get("_data")
	var player: PlayerPrototype = level.get("_player")
	var seed: int = level.params.seed
	player.position = Vector2(data.goal.get_center().x, data.goal.end.y - 2.0)
	await _frames(5)
	_check(level.get("_match") == ZoneLevel.Match.VICTORY, "llegar a la salida gana")
	await _frames(240)
	_check(level.get("_result") != null and level.params.seed == seed, "YOU WIN sigue en pantalla")
	_close(level)


## Esc pausa (juego y canción congelados), Esc otra vez sigue.
func _test_pause() -> void:
	var level := await _open(0)
	var player: PlayerPrototype = level.get("_player")
	await _press_escape()
	_check(level.is_paused() and get_tree().paused and Conductor.is_paused(), "Esc pausa el juego y la canción")
	var beat := Conductor.beat_position()
	var position := player.position
	player.velocity = Vector2(400.0, 0.0)
	await _frames(30)
	_check(Conductor.beat_position() == beat and player.position == position, "en pausa no avanza nada")
	await _press_escape()
	_check(not level.is_paused() and not get_tree().paused and not Conductor.is_paused(), "Esc otra vez sigue")
	await _frames(30)
	_check(Conductor.beat_position() > beat, "el beat sigue después de la pausa")
	_close(level)


## Llegar a un nivel lo desbloquea en LEVEL SELECT (y se guarda); el 3 espera su escena.
func _test_progress() -> void:
	var real_path := Game.progress_path
	Game.progress_path = "user://test_progreso.cfg"
	DirAccess.remove_absolute(Game.progress_path)
	Game.load_progress()
	_check(Game.unlocked_level == 1 and Game.can_play(1) and not Game.can_play(2), "al empezar solo el nivel 1")
	_check(_menu_buttons() == 1, "LEVEL SELECT con un ENTER")
	Game.unlock(Game.LEVELS[Game.first_sublevel(2)]["nivel"])
	Game.load_progress()
	_check(Game.unlocked_level == 2 and Game.can_play(2), "llegar a los edificios desbloquea el nivel 2 y se guarda")
	_check(_menu_buttons() == 2, "LEVEL SELECT 2 con dos ENTER")
	Game.unlock(3)
	_check(not Game.can_play(3), "el nivel 3 no se puede jugar hasta que tenga escena")
	DirAccess.remove_absolute(Game.progress_path)
	Game.progress_path = real_path
	Game.load_progress()


## Botones ENTER de LEVEL SELECT (y que use el diseño de lo desbloqueado).
func _menu_buttons() -> int:
	Game.menu_screen = &"seleccion_nivel"
	var menu: MainMenu = load("res://src/ui/menus/main_menu.tscn").instantiate()
	add_child(menu)
	var screen: PsdScreen = menu.get("_screen")
	var track := Conductor.current_track()
	_check(track != null and track.resource_path == MainMenu.MENU_MUSIC, "el menú suena con su música")
	var expected: String = MainMenu.LEVEL_SELECT_SCREENS[Game.unlocked_level - 1]
	_check(menu.level_select_screen() == expected, "diseño %s" % expected)
	var count: int = screen.get("_buttons").size()
	remove_child(menu)
	menu.free()
	Game.menu_screen = &"inicio"
	return count


func _press_escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


## Desde 70 de calor sube el peligro (canción de peligro y glitch) hasta el máximo en 100.
func _test_danger() -> void:
	var level := await _open(0)
	var heat: HeatMeter = level.get("_heat")
	for pair in [[69.0, 0.0], [85.0, 0.5], [99.0, 29.0 / 30.0]]:
		heat.change(pair[0] - heat.heat)
		_check(is_equal_approx(level.danger_amount(), pair[1]), "calor %.0f → peligro %.2f (%.2f)" % [pair[0], pair[1], level.danger_amount()])
	heat.change(10.0)
	_check(heat.overheated and level.danger_amount() == 1.0, "con la mecha encendida el peligro es máximo")
	await _frames(2)
	_check(Conductor.get("_danger_target") == 1.0, "la zona le pasa el peligro al Conductor")
	level.finish_victory()
	_check(level.danger_amount() == 0.0, "al terminar la partida no hay peligro")
	_close(level)


## En el ascensor, el pasajero y la zona visible van con la cabina en cada frame (antes el pasajero
## iba un paso de física atrás y la máscara la seguía con retraso: quedaba fuera, en lo oscuro).
func _test_elevator_sync() -> void:
	var level := await _open(2)
	var lifts: Array = level.call("elevators")
	var lift: Elevator = lifts[0]
	var player: PlayerPrototype = level.call("player")
	player.begin_scripted()
	level.set("_lift", lift)
	level.set("_state", 3)  # State.RIDING
	lift.riding = true
	var start_y := lift.cabin_y
	lift.ride_to(lift.spec.high if lift.cabin_floor != lift.spec.high else lift.spec.low)
	var mask: VisionMask = level.get("_mask")
	var worst_player := 0.0
	var worst_mask := 0.0
	for _i in 120:
		await get_tree().process_frame
		worst_player = maxf(worst_player, player.position.distance_to(Vector2(lift.door_x(), lift.cabin_y - 2.0)))
		worst_mask = maxf(worst_mask, mask.get("_rect").position.distance_to(lift.cabin_rect().position))
	_check(absf(lift.cabin_y - start_y) > 100.0, "la cabina viajó (%.0f px)" % absf(lift.cabin_y - start_y))
	_check(worst_player < 0.5, "el pasajero va con la cabina (desfase máximo %.1f px)" % worst_player)
	_check(worst_mask < 0.5, "la zona visible va con la cabina (desfase máximo %.1f px)" % worst_mask)
	_close(level)


## Abre un subnivel; salvo `with_tutorial`, sin los diálogos (pausan el juego).
func _open(index: int, with_tutorial := false) -> ZoneLevel:
	Game.level_index = index
	var level: ZoneLevel = load(Game.LEVELS[index]["escena"]).instantiate()
	if not with_tutorial:
		level.tutorial = &""
	add_child(level)
	await _frames(3)
	return level


## Guion de tutorial configurado en la escena del subnivel.
func _scene_tutorial(index: int) -> StringName:
	var level: ZoneLevel = load(Game.LEVELS[index]["escena"]).instantiate()
	var value: StringName = level.tutorial
	level.free()
	return value


func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)


func _close(level: ZoneLevel) -> void:
	remove_child(level)
	level.free()


func _track(_level: ZoneLevel) -> String:
	var track := Conductor.current_track()
	return track.resource_path if track != null else ""


func _enemy_types(level: ZoneLevel) -> Array:
	var combat: CombatController = level.get("_combat")
	var types := {}
	for enemy in combat.enemies:
		types[enemy.enemy_type] = true
	return types.keys()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FALLO: " + message)
