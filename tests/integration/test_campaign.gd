extends Node
## Campaña: niveles 1 y 2 con sus subniveles (lista de Game, escenas, largo, pisos y sentido,
## pausa con Esc, progreso que desbloquea niveles en LEVEL SELECT,
## neblina, estilo, enemigos, música, tutorial solo en 1-1, y que YOU WIN no se cierre solo).
## Corre como escena (necesita los autoloads). Ejecutar:
##   godot --headless --path . --fixed-fps 60 res://tests/test_scenes/campaign.tscn

const MUSIC_LEVEL_ONE := "res://src/shared/resources/music/nivel_uno.tres"
const MUSIC_LEVEL_TWO := "res://src/shared/resources/music/industrial.tres"
const AZOTEA_ONE := [&"normal", &"flyer", &"thrower", &"charger"]
const OFICINAS_TWO := [&"normal", &"tank", &"charger", &"thrower"]

var _failures := 0


func _ready() -> void:
	Conductor.params.metronome_enabled = false
	_test_level_list()
	var tutorial_end := await _test_tutorial()
	await _test_rooftop_trial(tutorial_end)
	await _test_tower(2, true)
	await _test_tower(3, false)
	await _test_win_stays()
	await _test_pause()
	await _test_progress()
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


## 1-1: azotea del prototipo con los textos del tutorial. Devuelve dónde termina el mapa.
func _test_tutorial() -> float:
	var level := await _open(0)
	var data: AzoteaMapData = level.get("_data")
	_check(level.tutorial, "1-1 es el tutorial")
	_check(_track(level) == MUSIC_LEVEL_ONE, "1-1 con la canción del nivel uno")
	var hints: TutorialHints = level.get("_tutorial")
	_check(hints != null, "1-1 muestra el tutorial")
	if hints != null:
		var player: PlayerPrototype = level.get("_player")
		var enemies: Array[Enemy] = []
		_check(hints.get("_step") == TutorialHints.Step.BASICS, "empieza con los movimientos básicos")
		var early := Enemy.new()
		early.position = player.position + Vector2(200.0, 0.0)
		enemies.append(early)
		hints.update(player, enemies, true)
		_check(hints.get("_step") == TutorialHints.Step.BASICS, "una papa cerca no tapa los básicos al empezar")
		enemies.clear()
		early.free()
		hints.set("_time", 10.0)
		player.position.x += TutorialHints.BASICS_DISTANCE + 100.0
		hints.update(player, enemies, true)
		_check(hints.get("_step") == TutorialHints.Step.WAIT_ENEMY, "los básicos se van al avanzar")
		var enemy := Enemy.new()
		enemy.position = player.position + Vector2(300.0, 0.0)
		enemies.append(enemy)
		hints.update(player, enemies, true)
		_check(hints.get("_step") == TutorialHints.Step.COMBAT, "la primera papa trae el texto de combate")
		enemy.free()
	var end := data.roofs[-1].end.x
	_close(level)
	return end


## 1-2: la misma azotea, 2–3 veces más larga, con los cuatro tipos mezclados.
func _test_rooftop_trial(tutorial_end: float) -> void:
	var level := await _open(1)
	var data: AzoteaMapData = level.get("_data")
	var length := data.roofs[-1].end.x
	_check(length >= tutorial_end * 2.0 and length <= tutorial_end * 3.2,
			"1-2 mide %.1f veces el tutorial" % (length / tutorial_end))
	_check(level.get("_tutorial") == null, "1-2 sin textos de tutorial")
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
	_check(level.get("_tutorial") == null, "%s sin textos de tutorial" % name)
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


func _open(index: int) -> ZoneLevel:
	Game.level_index = index
	var level: ZoneLevel = load(Game.LEVELS[index]["escena"]).instantiate()
	add_child(level)
	await _frames(3)
	return level


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
