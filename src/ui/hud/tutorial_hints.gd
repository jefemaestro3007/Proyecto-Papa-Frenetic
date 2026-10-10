class_name TutorialHints
extends Control
## Tutorial con la protagonista: en ciertos momentos el juego (y la canción) se pausa, ella aparece
## en el centro de la pantalla y explica los controles en un globo de diálogo. Espacio, Enter, J
## o clic terminan de escribir el texto y luego cierran el diálogo.
## Guiones (`ZoneLevel.tutorial`):
## - `azotea` (1-1): al empezar, lo básico (moverse, saltar, golpear) sobre fondo oscuro; cuando
##   se acerca la primera papa, el combate (stomp, ataque aéreo, dash) sin fondo oscuro.
## - `edificio` (2-1): al empezar, escaleras y ascensores.
## Cada diálogo sale una sola vez por partida (reintentar no lo repite).

const PORTRAIT := "res://assets/textures/ui/protagonista_retrato.png"
const DIALOGS := {
	&"basicos": {
		"oscuro": true,
		"texto": "¡Ey! Las papas zombi se tomaron la ciudad y me toca sacarlas a golpes. Lo básico:",
		"teclas": [["A / D", "MOVERTE"], ["ESPACIO", "SALTAR"], ["CLIC / J", "GOLPEAR"]],
		"pie": "Todo pega más fuerte si lo haces al ritmo del beat.",
	},
	&"combate": {
		"oscuro": false,
		"texto": "¡Cuidado! Esas papas son enemigas. Con esto les ganas:",
		"teclas": [["S EN EL AIRE", "STOMP"], ["CLIC / J EN EL AIRE", "ATAQUE AÉREO"], ["SHIFT", "DASH"]],
		"pie": "El stomp las aplasta desde arriba y el dash las atraviesa.",
	},
	&"edificio": {
		"oscuro": true,
		"texto": "Este edificio se recorre por dentro, con escaleras y ascensores:",
		"teclas": [["W", "SUBIR"], ["S", "BAJAR"], ["A / D", "SALIR DEL ASCENSOR"]],
		"pie": "Frente a un ascensor, W lo llama; adentro, W y S eligen el piso.",
	},
}
const SCRIPTS := {
	&"azotea": [&"basicos", &"combate"],
	&"edificio": [&"edificio"],
}
## Diálogos que salen al empezar (el resto espera a la primera papa).
const AT_START: Array[StringName] = [&"basicos", &"edificio"]
const START_DELAY := 0.4
## El diálogo de combate sale cuando una papa queda a esta distancia del jugador.
const ENEMY_DISTANCE := 800.0
## Antes de esto no se cierra (para no saltarlo sin querer con una tecla que venía apretada).
const MIN_SECONDS := 0.5
const TYPE_CHARS_PER_SECOND := 70.0
## Pausa breve al cerrar, para que la tecla que cerró no cuente como salto o golpe.
const RESUME_DELAY := 0.12
const INK := Color("120f0c")
const CREAM := Color("fff2cf")
const ACCENT := Color("c4161c")

var script_name := &""
var _pending: Array[StringName] = []
var _time := 0.0
var _current := &""
var _open_time := 0.0
var _closing := -1.0
var _backdrop: ColorRect
var _portrait: TextureRect
var _bubble: PanelContainer
var _text: Label
var _keys: HFlowContainer
var _footer: Label
var _prompt: Label


func _init(tutorial_script: StringName = &"") -> void:
	script_name = tutorial_script


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pending.assign(SCRIPTS.get(script_name, []))


## Al reintentar: los diálogos ya vistos no se repiten.
func reset() -> void:
	_time = 0.0


func is_open() -> bool:
	return _current != &""


func current() -> StringName:
	return _current


## Lo llama la zona cada frame mientras se juega: abre el próximo diálogo cuando corresponde.
func update(player: PlayerPrototype, enemies: Array[Enemy], playing: bool) -> void:
	if is_open() or not playing or _pending.is_empty():
		return
	_time += get_process_delta_time()
	var next := _pending[0]
	if next in AT_START:
		if _time >= START_DELAY:
			open(next)
	elif _enemy_near(player, enemies):
		open(next)


func _enemy_near(player: PlayerPrototype, enemies: Array[Enemy]) -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.active and enemy.position.distance_to(player.position) < ENEMY_DISTANCE:
			return true
	return false


## Pausa el juego y muestra un diálogo.
func open(dialog: StringName) -> void:
	_pending.erase(dialog)
	_current = dialog
	_open_time = 0.0
	_closing = -1.0
	get_tree().paused = true
	Conductor.set_paused(true)
	_build(DIALOGS[dialog])


## Cierra el diálogo y, tras una pausa breve, sigue el juego.
func close() -> void:
	if not is_open() or _closing >= 0.0:
		return
	_closing = 0.0


func _finish_close() -> void:
	for child in get_children():
		child.queue_free()
	_current = &""
	_closing = -1.0
	get_tree().paused = false
	Conductor.set_paused(false)


func _input(event: InputEvent) -> void:
	if not is_open() or _closing >= 0.0:
		return
	var key := event as InputEventKey
	var mouse := event as InputEventMouseButton
	var advance := (key != null and key.pressed and not key.echo
			and key.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_J]) \
			or (mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT)
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _text.visible_ratio < 1.0:
		_text.visible_ratio = 1.0
	elif _open_time >= MIN_SECONDS:
		close()


func _process(delta: float) -> void:
	if not is_open():
		return
	_open_time += delta
	if _closing >= 0.0:
		_closing += delta
		modulate.a = 1.0 - _closing / RESUME_DELAY
		if _closing >= RESUME_DELAY:
			modulate.a = 1.0
			_finish_close()
		return
	var characters := maxi(_text.get_total_character_count(), 1)
	_text.visible_ratio = minf(1.0, _text.visible_ratio + delta * TYPE_CHARS_PER_SECOND / characters)
	var typed := _text.visible_ratio >= 1.0
	_keys.modulate.a = move_toward(_keys.modulate.a, 1.0 if typed else 0.0, delta * 5.0)
	_footer.modulate.a = _keys.modulate.a
	_prompt.visible = typed and fmod(_open_time, 0.8) < 0.55
	_layout()


## Protagonista arriba al centro (entra subiendo) y el globo debajo, montado sobre su busto.
func _layout() -> void:
	var screen := size
	var enter := 1.0 - pow(1.0 - minf(_open_time / 0.3, 1.0), 3.0)
	var side := screen.y * 0.52
	var bob := sin(_open_time * 2.6) * screen.y * 0.006
	_portrait.size = Vector2(side, side)
	_portrait.position = Vector2((screen.x - side) * 0.5, screen.y * 0.04 + (1.0 - enter) * screen.y * 0.3 + bob)
	_portrait.modulate.a = enter
	var width := minf(screen.x * 0.8, 1100.0)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0.0)
	_bubble.position = Vector2((screen.x - width) * 0.5, _portrait.position.y + side * 0.86)
	_bubble.pivot_offset = Vector2(width * 0.5, 0.0)
	_bubble.scale = Vector2.ONE * (0.85 + 0.15 * enter)


func _build(content: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.0, 0.0, 0.0, 0.9 if content["oscuro"] else 0.25)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_portrait = TextureRect.new()
	if ResourceLoader.exists(PORTRAIT):
		_portrait.texture = load(PORTRAIT)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	var frame := StyleBoxFlat.new()
	frame.bg_color = CREAM
	frame.border_color = INK
	frame.set_border_width_all(4)
	frame.set_corner_radius_all(18)
	frame.content_margin_left = 34.0
	frame.content_margin_right = 34.0
	frame.content_margin_top = 22.0
	frame.content_margin_bottom = 22.0
	frame.shadow_color = Color(INK, 0.6)
	frame.shadow_offset = Vector2(6.0, 6.0)
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", frame)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_bubble.add_child(column)
	_text = _label(content["texto"], 30, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.visible_ratio = 0.0
	column.add_child(_text)
	_keys = HFlowContainer.new()
	_keys.alignment = FlowContainer.ALIGNMENT_CENTER
	_keys.add_theme_constant_override("h_separation", 30)
	_keys.add_theme_constant_override("v_separation", 10)
	_keys.modulate.a = 0.0
	column.add_child(_keys)
	for pair: Array in content["teclas"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 10)
		item.add_child(_key(pair[0]))
		item.add_child(_label(pair[1], 26, INK))
		_keys.add_child(item)
	_footer = _label(content["pie"], 22, INK.lightened(0.3))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_footer.modulate.a = 0.0
	column.add_child(_footer)
	_prompt = _label("ESPACIO / CLIC  ▶", 18, ACCENT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt.visible = false
	column.add_child(_prompt)
	_layout()


## Tecla: texto dentro de un recuadro de solo contorno.
func _key(text: String) -> PanelContainer:
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_border_width_all(3)
	frame.border_color = ACCENT
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 10.0
	frame.content_margin_right = 10.0
	frame.content_margin_top = 1.0
	frame.content_margin_bottom = 1.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame)
	panel.add_child(_label(text, 24, ACCENT))
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
