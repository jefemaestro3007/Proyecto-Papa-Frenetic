class_name SettingsRow
extends Control
## Una opción de la pantalla de configuración: nombre a la izquierda y su control a la derecha,
## dibujados con MenuStyle. Tipos: deslizador (valor numérico), ON/OFF, lista de opciones
## (◀ valor ▶) y teclas de una acción (dos casillas). Con el teclado: ←/→ cambian el valor (o la
## casilla de tecla), Enter/Espacio/J activa; con el mouse: clic o arrastre sobre el control.
## Para reasignar una tecla: Enter o clic en la casilla y apretar la tecla nueva (Esc cancela,
## Retroceso la borra).

signal value_changed
## Se pide reasignar o borrar una tecla (lo resuelve la pantalla con Settings).
signal key_chosen(action: StringName, slot: int, keycode: int)

enum Kind { SLIDER, TOGGLE, CHOICE, KEYS }

const HEIGHT := 58.0
const CONTROL_X := 500.0
const CONTROL_WIDTH := 400.0
const LABEL_SIZE := 30
const VALUE_SIZE := 26

var kind := Kind.SLIDER
var label := ""
## Texto de ayuda que se muestra abajo mientras la opción tiene el foco.
var help := ""
var getter: Callable
var setter: Callable
# Deslizador.
var min_value := 0.0
var max_value := 1.0
var step := 0.05
## Valor → texto (por defecto, porcentaje).
var format: Callable
# Lista de opciones.
var options: Array[String] = []
# Teclas.
var action := &""
var slot := 0
var waiting := false

var _hover := 0.0
var _dragging := false


static func slider(p_label: String, p_getter: Callable, p_setter: Callable, p_min := 0.0, p_max := 1.0,
		p_step := 0.05, p_format := Callable()) -> SettingsRow:
	var row: SettingsRow = SettingsRow.new()
	row.kind = Kind.SLIDER
	row.label = p_label
	row.getter = p_getter
	row.setter = p_setter
	row.min_value = p_min
	row.max_value = p_max
	row.step = p_step
	row.format = p_format if p_format.is_valid() else func(v: float) -> String: return "%d%%" % roundi(v * 100.0)
	return row


static func toggle(p_label: String, p_getter: Callable, p_setter: Callable) -> SettingsRow:
	var row: SettingsRow = SettingsRow.new()
	row.kind = Kind.TOGGLE
	row.label = p_label
	row.getter = p_getter
	row.setter = p_setter
	return row


## `p_getter` devuelve el índice elegido y `p_setter` lo recibe.
static func choice(p_label: String, p_options: Array[String], p_getter: Callable, p_setter: Callable) -> SettingsRow:
	var row: SettingsRow = SettingsRow.new()
	row.kind = Kind.CHOICE
	row.label = p_label
	row.options = p_options
	row.getter = p_getter
	row.setter = p_setter
	return row


## `p_getter` devuelve las teclas de la acción (Array[int]).
static func keys(p_label: String, p_action: StringName, p_getter: Callable) -> SettingsRow:
	var row: SettingsRow = SettingsRow.new()
	row.kind = Kind.KEYS
	row.label = p_label
	row.action = p_action
	row.getter = p_getter
	return row


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		if not waiting:
			grab_focus())
	focus_exited.connect(func() -> void:
		waiting = false
		_dragging = false)


func with_help(text: String) -> SettingsRow:
	help = text
	return self


func _process(delta: float) -> void:
	_hover = move_toward(_hover, 1.0 if has_focus() else 0.0, delta * 8.0)
	queue_redraw()


# --- Entrada -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Esperando la tecla nueva: la primera que se apriete es para esta acción.
	if not waiting:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		if event is InputEventMouseButton and event.pressed:
			waiting = false
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	waiting = false
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == KEY_ESCAPE:
		return
	if code == KEY_BACKSPACE or code == KEY_DELETE:
		key_chosen.emit(action, slot, KEY_NONE)
	elif GameSettings.can_bind(code):
		key_chosen.emit(action, slot, code)


func _gui_input(event: InputEvent) -> void:
	if waiting:
		return
	if event.is_action_pressed("ui_left", true):
		_nudge(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		_nudge(1)
		accept_event()
	elif event.is_action_pressed("ui_accept") or _is_key(event, KEY_J):
		_activate()
		accept_event()
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mouse.pressed and kind == Kind.SLIDER
		if mouse.pressed:
			_click(mouse.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_click(event.position)
		accept_event()


static func _is_key(event: InputEvent, keycode: Key) -> bool:
	var key := event as InputEventKey
	return key != null and key.pressed and not key.echo and key.physical_keycode == keycode


func _nudge(direction: int) -> void:
	match kind:
		Kind.SLIDER:
			_set_value(getter.call() + step * direction)
		Kind.TOGGLE:
			_set_value(direction > 0)
		Kind.CHOICE:
			_set_value(posmod(getter.call() + direction, options.size()))
		Kind.KEYS:
			slot = clampi(slot + direction, 0, GameSettings.SLOTS - 1)


func _activate() -> void:
	match kind:
		Kind.SLIDER:
			pass
		Kind.TOGGLE:
			_set_value(not getter.call())
		Kind.CHOICE:
			_nudge(1)
		Kind.KEYS:
			waiting = true


func _click(at: Vector2) -> void:
	var area := _control_rect()
	match kind:
		Kind.SLIDER:
			var track := _track_rect()
			var t := clampf((at.x - track.position.x) / track.size.x, 0.0, 1.0)
			_set_value(lerpf(min_value, max_value, t))
		Kind.TOGGLE:
			if area.has_point(at):
				_set_value(at.x < area.get_center().x)
		Kind.CHOICE:
			if area.has_point(at):
				_nudge(-1 if at.x < area.get_center().x else 1)
		Kind.KEYS:
			for i in GameSettings.SLOTS:
				if _key_rect(i).has_point(at):
					slot = i
					waiting = true


func _set_value(value: Variant) -> void:
	if kind == Kind.SLIDER:
		value = clampf(snappedf(value, step), min_value, max_value)
	if value == getter.call():
		return
	setter.call(value)
	value_changed.emit()


# --- Dibujo --------------------------------------------------------------------------

func _control_rect() -> Rect2:
	return Rect2(CONTROL_X, 8.0, CONTROL_WIDTH, HEIGHT - 16.0)


func _track_rect() -> Rect2:
	return Rect2(CONTROL_X, HEIGHT * 0.5 - 7.0, CONTROL_WIDTH - 110.0, 14.0)


func _key_rect(index: int) -> Rect2:
	var width := (CONTROL_WIDTH - 16.0) * 0.5
	return Rect2(CONTROL_X + index * (width + 16.0), 7.0, width, HEIGHT - 14.0)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if _hover > 0.0:
		draw_rect(rect, Color(MenuStyle.PANEL_LIGHT, _hover))
	MenuStyle.text_left(self, label, Rect2(24.0, 0.0, CONTROL_X - 40.0, size.y), LABEL_SIZE,
			MenuStyle.CREAM if has_focus() else Color(MenuStyle.CREAM, 0.8))
	match kind:
		Kind.SLIDER:
			_draw_slider()
		Kind.TOGGLE:
			_draw_toggle()
		Kind.CHOICE:
			_draw_choice()
		Kind.KEYS:
			_draw_keys()
	if kind != Kind.KEYS:
		MenuStyle.focus_ring(self, rect.grow(-2.0), _hover)


func _draw_slider() -> void:
	var track := _track_rect()
	var value: float = getter.call()
	var t := inverse_lerp(min_value, max_value, value)
	MenuStyle.box(self, track, MenuStyle.BROWN.darkened(0.35))
	if t > 0.0:
		draw_rect(Rect2(track.position, Vector2(track.size.x * t, track.size.y)), MenuStyle.YELLOW)
		draw_rect(Rect2(track.position, Vector2(track.size.x * t, track.size.y)), MenuStyle.INK, false, 2.0)
	var knob := Rect2(track.position.x + track.size.x * t - 11.0, track.get_center().y - 18.0, 22.0, 36.0)
	MenuStyle.box(self, knob, MenuStyle.CREAM)
	MenuStyle.text_in(self, format.call(value), Rect2(track.end.x + 10.0, 0.0, 100.0, size.y), VALUE_SIZE,
			MenuStyle.CREAM)


func _draw_toggle() -> void:
	var area := _control_rect()
	var on: bool = getter.call()
	var half := Vector2(area.size.x * 0.5 - 8.0, area.size.y)
	var left := Rect2(area.position, half)
	var right := Rect2(area.position + Vector2(area.size.x * 0.5 + 8.0, 0.0), half)
	MenuStyle.button(self, left, MenuStyle.YELLOW if on else MenuStyle.PANEL_LIGHT, "ON",
			MenuStyle.INK if on else Color(MenuStyle.CREAM, 0.5), VALUE_SIZE)
	MenuStyle.button(self, right, MenuStyle.BROWN if not on else MenuStyle.PANEL_LIGHT, "OFF",
			MenuStyle.CREAM if not on else Color(MenuStyle.CREAM, 0.5), VALUE_SIZE)


func _draw_choice() -> void:
	var area := _control_rect()
	var index: int = getter.call()
	MenuStyle.box(self, area, MenuStyle.BROWN)
	MenuStyle.text_in(self, options[clampi(index, 0, options.size() - 1)], area, VALUE_SIZE, MenuStyle.CREAM)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(area.get_center().x + side * (area.size.x * 0.5 - 18.0), area.get_center().y)
		var back := tip.x - side * 14.0
		draw_colored_polygon(PackedVector2Array([tip, Vector2(back, tip.y - 11.0), Vector2(back, tip.y + 11.0)]),
				MenuStyle.YELLOW)


func _draw_keys() -> void:
	var codes: Array = getter.call()
	for i in GameSettings.SLOTS:
		var rect := _key_rect(i)
		var active := has_focus() and i == slot
		if active and waiting:
			var blink := 0.6 + 0.4 * Conductor.pulse(8.0)
			MenuStyle.box(self, rect, MenuStyle.YELLOW.lerp(MenuStyle.CREAM, 1.0 - blink))
			MenuStyle.text_in(self, "PRESS A KEY", rect, VALUE_SIZE - 4, MenuStyle.INK)
		else:
			var code: int = codes[i]
			MenuStyle.box(self, rect, MenuStyle.CREAM if code != KEY_NONE else MenuStyle.PANEL_LIGHT)
			MenuStyle.text_in(self, GameSettings.key_name(code), rect, VALUE_SIZE,
					MenuStyle.INK if code != KEY_NONE else Color(MenuStyle.CREAM, 0.5))
		if active:
			MenuStyle.focus_ring(self, rect, _hover)
