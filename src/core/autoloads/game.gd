class_name GameFlow
extends Node
## Flujo del juego (autoload `Game`): lista de niveles y navegación entre el menú y las partidas.
## El menú abre en `menu_screen`; jugar un nivel pasa por la pantalla de carga del menú.

const MENU_SCENE := "res://src/ui/menus/main_menu.tscn"
## Niveles en orden. Para agregar uno: su nombre (el de la tarjeta del menú) y su escena.
const LEVELS: Array[Dictionary] = [
	{"nombre": "Carullazo", "escena": "res://src/world/levels/azotea/azotea.tscn"},
]

## Nivel en juego (-1 = se abrió una zona directo, sin pasar por el menú).
var level_index := -1
## Pantalla con la que abre el menú la próxima vez.
var menu_screen := &"inicio"


func has_next_level() -> bool:
	return level_index >= 0 and level_index + 1 < LEVELS.size()


## Abre el menú en una pantalla (`inicio`, `nuevo_juego`, `seleccion_nivel` o `cargando`).
func go_to_menu(screen: StringName = &"inicio") -> void:
	menu_screen = screen
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", MENU_SCENE)


## Juega un nivel pasando por la pantalla de carga.
func play(index: int) -> void:
	level_index = clampi(index, 0, LEVELS.size() - 1)
	go_to_menu(&"cargando")


func next_level() -> void:
	play(level_index + 1)


func level_scene() -> String:
	return LEVELS[maxi(level_index, 0)]["escena"]
