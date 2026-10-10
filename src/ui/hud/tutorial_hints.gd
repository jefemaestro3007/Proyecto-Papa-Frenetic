class_name TutorialHints
extends Control
## Tutorial con la protagonista: en ciertos momentos el juego (y la canción) se pausa, ella aparece
## en el centro de la pantalla y habla en un globo de diálogo de una o más páginas. Espacio, Enter,
## J o clic terminan de escribir el texto, pasan de página y cierran. Una página puede poner el
## foco en la papa bomba del HUD (`focus`): se ilumina y se rodea con un anillo.
## Guiones (`ZoneLevel.tutorial`):
## - `azotea` (1-1): al empezar, la premisa (le pegaron una papa bomba: se calienta sola, golpear
##   papas al ritmo la enfría, si se llena explota; hay que salir de la ciudad) y los controles
##   básicos (moverse, saltar, golpear, golpear en el aire); con la primera papa, que golpearla
##   enfría la papa bomba.
## - `prueba` (1-2): al empezar, el stomp y el dash.
## - `edificio` (2-1): al empezar, escaleras y ascensores.
## Cada diálogo sale una sola vez por partida (reintentar no lo repite).

const PORTRAIT := "res://assets/textures/ui/protagonista_retrato.png"
const SPOT_SHADER := preload("res://src/ui/hud/tutorial_spot.gdshader")
const DIALOGS := {
	&"premisa": {
		"oscuro": true,
		"paginas": [
			{
				"texto": "¡Ay, no! Me pegaron una papa bomba y no se despega. Mientras más se calienta, menos le falta para explotar.",
				"foco": true,
			},
			{
				"texto": "Se calienta sola, y más si pierdo el ritmo. Lo único que la enfría es pelar papas zombi al ritmo del beat. Si llega al rojo… ¡BUM!",
				"foco": true,
			},
			{
				"texto": "Tengo que salir de esta ciudad antes de que explote. Así me muevo:",
				"teclas": [["A / D", "MOVERTE"], ["ESPACIO", "SALTAR"], ["CLIC / J", "GOLPEAR"],
						["CLIC / J EN EL AIRE", "GOLPE AÉREO"]],
			},
		],
	},
	&"primera_papa": {
		"oscuro": false,
		"paginas": [
			{
				"texto": "¡Una papa zombi! Pélala al ritmo y mira cómo se enfría mi papa bomba.",
				"teclas": [["CLIC / J", "GOLPEAR"]],
				"foco": true,
			},
		],
	},
	&"trucos": {
		"oscuro": true,
		"paginas": [
			{
				"texto": "Esta azotea es más larga y está llena de papas. Dos trucos para pelarlas antes de que la papa bomba explote:",
				"teclas": [["S EN EL AIRE", "STOMP"], ["SHIFT", "DASH"]],
			},
		],
	},
	&"edificio": {
		"oscuro": true,
		"paginas": [
			{
				"texto": "Este edificio se recorre por dentro, con escaleras y ascensores:",
				"teclas": [["W", "SUBIR"], ["S", "BAJAR"], ["A / D", "SALIR DEL ASCENSOR"]],
			},
		],
	},
}
const SCRIPTS := {
	&"azotea": [&"premisa", &"primera_papa"],
	&"prueba": [&"trucos"],
	&"edificio": [&"edificio"],
}
## Diálogos que salen al empezar (el resto espera a la primera papa).
const AT_START: Array[StringName] = [&"premisa", &"trucos", &"edificio"]
const START_DELAY := 0.4
## El diálogo de la primera papa sale cuando una queda a esta distancia del jugador.
const ENEMY_DISTANCE := 800.0
## Antes de esto no se pasa de página (para no saltarla sin querer con una tecla que venía apretada).
const MIN_SECONDS := 0.5
const TYPE_CHARS_PER_SECOND := 70.0
## Pausa breve al cerrar, para que la tecla que cerró no cuente como salto o golpe.
const RESUME_DELAY := 0.12
const INK := Color("120f0c")
const CREAM := Color("fff2cf")
const ACCENT := Color("c4161c")
const RING := Color("ffd23f")

var script_name := &""
## Lo que se ilumina en las páginas con foco (la papa bomba del HUD).
var focus: Control
var _pending: Array[StringName] = []
var _time := 0.0
var _current := &""
var _page := 0
var _open_time := 0.0
var _page_time := 0.0
var _closing := -1.0
var _backdrop: ColorRect
var _ring: Control
var _portrait: TextureRect
var _bubble: PanelContainer
var _text: Label
var _keys: HFlowContainer
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


func page() -> int:
	return _page


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


## Pausa el juego y muestra un diálogo desde su primera página.
func open(dialog: StringName) -> void:
	_pending.erase(dialog)
	_current = dialog
	_open_time = 0.0
	_closing = -1.0
	get_tree().paused = true
	Conductor.set_paused(true)
	_build(DIALOGS[dialog])
	_show_page(0)


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
	elif _page_time >= MIN_SECONDS:
		if _page + 1 < _pages().size():
			_show_page(_page + 1)
		else:
			close()


func _process(delta: float) -> void:
	if not is_open():
		return
	_open_time += delta
	_page_time += delta
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
	_prompt.visible = typed
	_layout()


func _pages() -> Array:
	return DIALOGS[_current]["paginas"]


func _focused() -> bool:
	return _pages()[_page].get("foco", false) and focus != null and is_instance_valid(focus)


## Protagonista arriba y el globo debajo, montado sobre su busto. Con foco en la papa bomba (abajo
## a la derecha) los dos se corren a la izquierda para no taparla.
func _layout() -> void:
	var screen := size
	var enter := 1.0 - pow(1.0 - minf(_open_time / 0.3, 1.0), 3.0)
	var focused := _focused()
	var center_x := screen.x * (0.43 if focused else 0.5)
	var side := screen.y * 0.52
	var bob := sin(_open_time * 2.6) * screen.y * 0.006
	_portrait.size = Vector2(side, side)
	_portrait.position = Vector2(center_x - side * 0.5, screen.y * 0.04 + (1.0 - enter) * screen.y * 0.3 + bob)
	_portrait.modulate.a = enter
	var width := minf(screen.x * (0.66 if focused else 0.8), 1100.0)
	_bubble.custom_minimum_size.x = width
	_bubble.size = Vector2(width, 0.0)
	_bubble.position = Vector2(center_x - width * 0.5, _portrait.position.y + side * 0.86)
	_bubble.pivot_offset = Vector2(width * 0.5, 0.0)
	_bubble.scale = Vector2.ONE * (0.85 + 0.15 * enter)
	var material := _backdrop.material as ShaderMaterial
	material.set_shader_parameter("size_px", screen)
	if focused:
		var target := focus.get_global_rect()
		material.set_shader_parameter("hole_center", target.get_center() - get_global_rect().position)
		material.set_shader_parameter("hole_radius", maxf(target.size.x, target.size.y) * 0.46)
	else:
		material.set_shader_parameter("hole_radius", 0.0)
	_ring.queue_redraw()


## Anillo que late alrededor de lo que tiene el foco.
func _draw_ring() -> void:
	if not is_open() or not _focused():
		return
	var target := focus.get_global_rect()
	var center := target.get_center() - get_global_rect().position
	var radius := maxf(target.size.x, target.size.y) * 0.46 + 6.0 + 6.0 * absf(sin(_open_time * 4.0))
	_ring.draw_arc(center, radius, 0.0, TAU, 64, Color(RING, 0.9), 5.0, true)
	_ring.draw_arc(center, radius + 12.0, 0.0, TAU, 64, Color(RING, 0.35), 3.0, true)


func _build(content: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spot := ShaderMaterial.new()
	spot.shader = SPOT_SHADER
	spot.set_shader_parameter("darkness", 0.9 if content["oscuro"] else 0.25)
	_backdrop.material = spot
	add_child(_backdrop)
	_ring = Control.new()
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(PORTRAIT):
		_portrait.texture = load(PORTRAIT)
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
	_text = _label("", 30, INK)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text)
	_keys = HFlowContainer.new()
	_keys.alignment = FlowContainer.ALIGNMENT_CENTER
	_keys.add_theme_constant_override("h_separation", 30)
	_keys.add_theme_constant_override("v_separation", 10)
	column.add_child(_keys)
	_prompt = _label("", 18, ACCENT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_prompt)


## Llena el globo con una página: el texto vuelve a escribirse y las teclas aparecen al terminar.
func _show_page(index: int) -> void:
	_page = index
	_page_time = 0.0
	var content: Dictionary = _pages()[index]
	_text.text = content["texto"]
	_text.visible_ratio = 0.0
	for child in _keys.get_children():
		child.queue_free()
	for pair: Array in content.get("teclas", []):
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 10)
		item.add_child(_key(pair[0]))
		item.add_child(_label(pair[1], 26, INK))
		_keys.add_child(item)
	_keys.visible = not content.get("teclas", []).is_empty()
	_keys.modulate.a = 0.0
	var last := index + 1 >= _pages().size()
	_prompt.text = "ESPACIO / CLIC  ▶" if last else "ESPACIO / CLIC  ▶  (%d/%d)" % [index + 1, _pages().size()]
	_prompt.visible = false
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
