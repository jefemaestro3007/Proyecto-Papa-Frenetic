class_name MenuHotspot
extends Button
## Botón invisible sobre un botón dibujado en el diseño. Al pasar el mouse o con el foco del
## teclado dibuja un contorno crema con un leve rebote; J también lo activa (como atacar).

const HIGHLIGHT := Color("fff2cf")

var _hover := 0.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, empty)
	mouse_entered.connect(grab_focus)


func _gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_J:
		accept_event()
		pressed.emit()


func _process(delta: float) -> void:
	var target := 1.0 if has_focus() or is_hovered() else 0.0
	_hover = move_toward(_hover, target, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	if _hover <= 0.0:
		return
	var grow := 4.0 + 3.0 * _hover * (0.5 + 0.5 * Conductor.pulse(8.0))
	var rect := Rect2(Vector2.ZERO, size).grow(grow)
	draw_rect(rect.grow(3.0), Color(HIGHLIGHT, 0.18 * _hover), false, 8.0)
	draw_rect(rect, Color(HIGHLIGHT, _hover), false, 3.0)
