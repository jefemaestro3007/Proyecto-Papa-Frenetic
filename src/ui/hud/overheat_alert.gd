class_name OverheatAlert
extends Control

# Secuencia de aviso al encenderse la mecha (papa a 100):
#   1. INTRO: "SOBRE / CALENTAMIENTO" aparece letra a letra en dos diagonales
#      que cruzan la pantalla.
#   2. VANISH: la palabra se desvanece (toda la secuencia dura ~2 s).
#   3. TIMER: la cuenta atrás aparece grande, centrada y algo arriba.
# Todo el texto es MenacingText en modo display digital (segmentos) y rojo alarma:
# desalineado y temblando, más fuerte en cada beat.

const MenacingTextScript = preload("res://src/ui/hud/menacing_text.gd")

const LINE_TOP := "SOBRE"
const LINE_BOTTOM := "CALENTAMIENTO"
# Tiempos de la secuencia completa (~2 s).
const CHAR_INTERVAL := 0.05
const HOLD_SECONDS := 0.45
const VANISH_SECONDS := 0.45
const TIMER_POP_SECONDS := 0.2
# Con poca mecha restante, la secuencia se acelera para no tapar el temporizador.
const SHORT_FUSE_SECONDS := 5.0
const SHORT_SEQUENCE_SPEED := 2.0
# Rojo alarma para letras y números, con contorno granate y halo tipo LED.
const ALARM_RED := Color("ff1e12")
const ALARM_OUTLINE := Color("2b0000")
const ALARM_HIGHLIGHT := Color("ffb4a8")
const ALARM_GLOW := Color(1.0, 0.08, 0.03, 0.28)

enum Phase { HIDDEN, INTRO, VANISH, TIMER }

var phase := Phase.HIDDEN
var line_top: MenacingText
var line_bottom: MenacingText
var timer_label: MenacingText
var _phase_time := 0.0
var _speed := 1.0
var _beat_pulse := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line_top = _make_text(LINE_TOP, 150, -34.0)
	line_top.stagger = 18.0
	line_bottom = _make_text(LINE_BOTTOM, 132, -27.0)
	line_bottom.stagger = 16.0
	timer_label = _make_text("10.0", 230, 0.0)
	timer_label.outline_size = 26
	timer_label.stagger = 10.0
	timer_label.tilt_degrees = 4.0
	timer_label.jitter = 8.0
	timer_label.letter_spacing = 34.0
	stop()


func _make_text(content: String, size_px: int, angle: float) -> MenacingText:
	var label := MenacingTextScript.new() as MenacingText
	label.text = content
	label.font_size = size_px
	label.outline_size = 20
	label.line_angle_degrees = angle
	label.tilt_degrees = 6.0
	label.jitter = 6.0
	label.segment_mode = true
	label.fill_color = ALARM_RED
	label.outline_color = ALARM_OUTLINE
	label.highlight_color = ALARM_HIGHLIGHT
	label.glow_color = ALARM_GLOW
	label.letter_spacing = 30.0
	add_child(label)
	return label


func get_warning_text() -> String:
	return "%s%s" % [LINE_TOP, LINE_BOTTOM]


func play(fuse_remaining: float) -> void:
	visible = true
	phase = Phase.INTRO
	_phase_time = 0.0
	_speed = SHORT_SEQUENCE_SPEED if fuse_remaining < SHORT_FUSE_SECONDS else 1.0
	for line in [line_top, line_bottom]:
		line.visible = true
		line.opacity = 1.0
		line.text_scale = 1.0
		line.set_revealed_count(0)
	timer_label.visible = false
	update_fuse(fuse_remaining)


func stop() -> void:
	phase = Phase.HIDDEN
	visible = false
	line_top.visible = false
	line_bottom.visible = false
	timer_label.visible = false


func update_fuse(fuse_remaining: float) -> void:
	timer_label.text = "%.1f" % fuse_remaining


func set_beat_pulse(pulse: float) -> void:
	_beat_pulse = pulse


func is_timer_visible() -> bool:
	return visible and timer_label.visible


func _process(delta: float) -> void:
	if phase == Phase.HIDDEN:
		return
	_layout()
	_phase_time += delta * _speed
	line_top.shake_strength = 1.0 + 1.5 * _beat_pulse
	line_bottom.shake_strength = 1.0 + 1.5 * _beat_pulse
	timer_label.shake_strength = 1.0 + 2.0 * _beat_pulse

	var total_chars := LINE_TOP.length() + LINE_BOTTOM.length()
	match phase:
		Phase.INTRO:
			var revealed := mini(int(_phase_time / CHAR_INTERVAL) + 1, total_chars)
			line_top.set_revealed_count(mini(revealed, LINE_TOP.length()))
			line_bottom.set_revealed_count(maxi(revealed - LINE_TOP.length(), 0))
			if _phase_time >= CHAR_INTERVAL * float(total_chars) + HOLD_SECONDS:
				phase = Phase.VANISH
				_phase_time = 0.0
		Phase.VANISH:
			var progress := clampf(_phase_time / VANISH_SECONDS, 0.0, 1.0)
			for line in [line_top, line_bottom]:
				line.opacity = 1.0 - progress
				line.text_scale = 1.0 + 0.25 * progress
			if progress >= 1.0:
				line_top.visible = false
				line_bottom.visible = false
				phase = Phase.TIMER
				_phase_time = 0.0
				timer_label.visible = true
		Phase.TIMER:
			# El temporizador entra con un golpe y luego late con el beat.
			var pop := clampf(_phase_time / TIMER_POP_SECONDS, 0.0, 1.0)
			timer_label.text_scale = lerpf(1.8, 1.0, 1.0 - pow(1.0 - pop, 3.0)) + 0.15 * _beat_pulse
			timer_label.opacity = pop


# Posiciones relativas a la pantalla, al estilo del boceto: dos diagonales ascendentes.
func _layout() -> void:
	_place(line_top, Vector2(0.27, 0.47), Vector2(900.0, 360.0))
	_place(line_bottom, Vector2(0.58, 0.52), Vector2(1800.0, 360.0))
	_place(timer_label, Vector2(0.5, 0.36), Vector2(900.0, 360.0))


func _place(label: MenacingText, center_ratio: Vector2, label_size: Vector2) -> void:
	label.size = label_size
	label.position = size * center_ratio - label_size * 0.5
