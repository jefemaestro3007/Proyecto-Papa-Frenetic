extends SceneTree
## Verifica el mapa de controles del juego (WASD + flechas, Espacio, J/clic). Ejecutar:
##   godot --headless --path . --script res://tests/unit/test_controls.gd

const EXPECTED := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"attack": [KEY_J],
}

var _failures := 0


func _initialize() -> void:
	for action in EXPECTED:
		if not InputMap.has_action(action):
			_fail("falta la acción %s" % action)
			continue
		for keycode in EXPECTED[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event) and not _has_physical(action, keycode):
				_fail("%s no tiene la tecla %s" % [action, OS.get_keycode_string(keycode)])
	var click := false
	for event in InputMap.action_get_events("attack"):
		click = click or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT)
	if not click:
		_fail("attack no tiene clic izquierdo")
	print("test_controls: %s" % ("OK" if _failures == 0 else "%d FALLOS" % _failures))
	quit(1 if _failures > 0 else 0)


func _has_physical(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _fail(message: String) -> void:
	_failures += 1
	printerr("  FALLO: ", message)
