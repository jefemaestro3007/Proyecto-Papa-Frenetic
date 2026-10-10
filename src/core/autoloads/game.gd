class_name GameFlow
extends Node
## Flujo del juego (autoload `Game`): lista de subniveles y navegación entre el menú y las partidas.
## El menú abre en `menu_screen`; jugar un subnivel pasa por la pantalla de carga del menú.

const MENU_SCENE := "res://src/ui/menus/main_menu.tscn"
const PROGRESS_FILE := "user://progreso.cfg"
## Subniveles en orden de juego. `nivel` es la tarjeta del menú que lo abre (entra por el primero
## de cada nivel); al ganar, YOU WIN pasa al siguiente de la lista.
const LEVELS: Array[Dictionary] = [
	{"nivel": 1, "nombre": "1-1 Tutorial", "escena": "res://src/world/levels/azotea/azotea_tutorial.tscn"},
	{"nivel": 1, "nombre": "1-2 Carullazo", "escena": "res://src/world/levels/azotea/azotea_prueba.tscn"},
	{"nivel": 2, "nombre": "2-1 Subida", "escena": "res://src/world/levels/oficinas/oficinas_subida.tscn"},
	{"nivel": 2, "nombre": "2-2 Bajada", "escena": "res://src/world/levels/oficinas/oficinas_bajada.tscn"},
	{"nivel": 3, "nombre": "3-1 Supermercado", "escena": "res://src/world/levels/bienestar/supermercado.tscn"},
	{"nivel": 3, "nombre": "3-2 Centro comercial", "escena": "res://src/world/levels/bienestar/centro_comercial.tscn"},
]

## Subnivel en juego (-1 = se abrió una zona directo, sin pasar por el menú).
var level_index := -1
## Pantalla con la que abre el menú la próxima vez.
var menu_screen := &"inicio"
## Nivel más alto al que se llegó (se guarda entre partidas): la selección de nivel deja entrar a
## todos hasta ese.
var unlocked_level := 1
## Archivo del progreso (los tests usan otro para no tocar el del jugador).
var progress_path := PROGRESS_FILE


func _ready() -> void:
	load_progress()


## Se está jugando desde el menú (y no una zona abierta directo para probar).
func in_campaign() -> bool:
	return level_index >= 0


func has_next_level() -> bool:
	return in_campaign() and level_index + 1 < LEVELS.size()


## Cantidad de niveles con escena (tarjetas del menú que se pueden jugar).
func level_count() -> int:
	return LEVELS[-1]["nivel"]


## Se puede entrar al nivel desde el menú: ya se llegó a él y tiene subniveles.
func can_play(level: int) -> bool:
	return level <= unlocked_level and has_sublevels(level)


func has_sublevels(level: int) -> bool:
	return LEVELS.any(func(entry: Dictionary) -> bool: return entry["nivel"] == level)


## Marca que se llegó a un nivel y lo guarda.
func unlock(level: int) -> void:
	if level <= unlocked_level:
		return
	unlocked_level = level
	var file := ConfigFile.new()
	file.set_value("progreso", "nivel", unlocked_level)
	file.save(progress_path)


func load_progress() -> void:
	var file := ConfigFile.new()
	unlocked_level = maxi(1, file.get_value("progreso", "nivel", 1)) if file.load(progress_path) == OK else 1


## Primer subnivel de un nivel (1, 2…).
func first_sublevel(level: int) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["nivel"] == level:
			return i
	return 0


## Abre el menú en una pantalla (`inicio`, `nuevo_juego`, `seleccion_nivel` o `cargando`).
func go_to_menu(screen: StringName = &"inicio") -> void:
	menu_screen = screen
	get_tree().paused = false
	Conductor.set_paused(false)
	get_tree().call_deferred("change_scene_to_file", MENU_SCENE)


## Juega un subnivel pasando por la pantalla de carga; llegar a él desbloquea su nivel.
func play(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	unlock(LEVELS[level_index]["nivel"])
	go_to_menu(&"cargando")


## Juega un nivel desde su primer subnivel.
func play_level(level: int) -> void:
	play(first_sublevel(level))


func next_level() -> void:
	play(level_index + 1)


func level_scene() -> String:
	return LEVELS[maxi(level_index, 0)]["escena"]
