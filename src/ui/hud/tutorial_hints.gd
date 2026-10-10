class_name TutorialHints
extends Control
## Textos del tutorial (solo nivel 1-1), arriba al centro y sin placa de fondo:
## 1) al empezar, los movimientos básicos; se van cuando el jugador ya avanzó un tramo;
## 2) cuando aparece la primera papa, el combate en el aire y el dash.
## Las teclas van en recuadros de solo contorno, como el indicador del dash.

enum Step { BASICS, WAIT_ENEMY, COMBAT, DONE }

const BASICS := {
	"titulo": "TUTORIAL",
	"teclas": [["A / D", "MOVERSE"], ["ESPACIO", "SALTAR"], ["CLIC / J", "GOLPEAR"]],
	"pie": "¡Golpea al ritmo del beat!",
}
const COMBAT := {
	"titulo": "¡PAPA ZOMBI!",
	"teclas": [["S EN EL AIRE", "STOMP"], ["CLIC / J EN EL AIRE", "ATAQUE AÉREO"], ["SHIFT", "DASH"]],
	"pie": "¡Aplástalas cayendo con S!",
}
## Los básicos se van al avanzar esto desde el inicio; antes de este mínimo en pantalla no los
## reemplaza nada (ni la primera papa, que puede estar cerca del inicio).
const BASICS_DISTANCE := 1300.0
const BASICS_MIN_SECONDS := 6.0
## El texto de combate sale cuando una papa queda a esta distancia del jugador.
const ENEMY_DISTANCE := 800.0
const COMBAT_SECONDS := 10.0
const FADE_SPEED := 3.0
const TOP_MARGIN := 96.0

var _step := Step.BASICS
var _time := 0.0
var _start_x := NAN
var _card: VBoxContainer
var _target_alpha := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset()


## Vuelve al primer texto (al reintentar).
func reset() -> void:
	_step = Step.BASICS
	_time = 0.0
	_start_x = NAN
	_show(BASICS)


## Avanza el tutorial según dónde está el jugador y las papas vivas.
func update(player: PlayerPrototype, enemies: Array[Enemy], playing: bool) -> void:
	var delta := get_process_delta_time()
	_time += delta
	if is_nan(_start_x):
		_start_x = player.position.x
	match _step:
		Step.BASICS:
			if _time >= BASICS_MIN_SECONDS and absf(player.position.x - _start_x) > BASICS_DISTANCE:
				_step = Step.WAIT_ENEMY
				_target_alpha = 0.0
			if _time >= BASICS_MIN_SECONDS and _enemy_near(player, enemies):
				_start_combat()
		Step.WAIT_ENEMY:
			if _enemy_near(player, enemies):
				_start_combat()
		Step.COMBAT:
			if _time > COMBAT_SECONDS:
				_step = Step.DONE
				_target_alpha = 0.0
	if _card == null:
		return
	var alpha := _target_alpha if playing else 0.0
	_card.modulate.a = move_toward(_card.modulate.a, alpha, delta * FADE_SPEED)
	_card.scale = Vector2.ONE * (1.0 + 0.025 * Conductor.pulse(10.0))
	_card.pivot_offset = _card.size * 0.5
	_card.position = Vector2((size.x - _card.size.x) * 0.5, TOP_MARGIN)


func _enemy_near(player: PlayerPrototype, enemies: Array[Enemy]) -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.position.distance_to(player.position) < ENEMY_DISTANCE:
			return true
	return false


func _start_combat() -> void:
	_step = Step.COMBAT
	_time = 0.0
	_show(COMBAT)


func _show(content: Dictionary) -> void:
	if _card != null:
		_card.queue_free()
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_theme_constant_override("separation", 14)
	_card.modulate.a = 0.0
	add_child(_card)
	var title := _label(content["titulo"], 46, FreneticPalette.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	_card.add_child(row)
	for pair: Array in content["teclas"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 12)
		item.add_child(_key(pair[0]))
		item.add_child(_label(pair[1], 30, FreneticPalette.CREAM))
		row.add_child(item)
	var footer := _label(content["pie"], 24, FreneticPalette.CREAM.darkened(0.1))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(footer)
	_target_alpha = 1.0


## Tecla: texto dentro de un recuadro de solo contorno.
func _key(text: String) -> PanelContainer:
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_border_width_all(3)
	frame.border_color = FreneticPalette.YELLOW
	frame.set_corner_radius_all(6)
	frame.content_margin_left = 12.0
	frame.content_margin_right = 12.0
	frame.content_margin_top = 2.0
	frame.content_margin_bottom = 2.0
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", frame)
	panel.add_child(_label(text, 26, FreneticPalette.YELLOW))
	return panel


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", FreneticPalette.INK)
	label.add_theme_constant_override("outline_size", 10)
	return label
