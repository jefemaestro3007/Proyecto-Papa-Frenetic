class_name HeatHud
extends Control
## HUD de la papa caliente (traído del prototipo): manómetro de calor abajo a la derecha, aviso
## "SOBRECALENTAMIENTO" con cuenta atrás de la mecha, viñeta roja que late con el beat, indicador
## del dash y el panel de fin de partida (victoria / la papa explotó).
## Va debajo del RhythmHud: la viñeta no tapa los textos de juicio.

const READY_COLOR := Color("8ee6a2")
const WAIT_COLOR := Color(0.6, 0.58, 0.68)
const SHAKE_PIXELS := 6.0
## Viñeta roja en los bordes: crece con la intensidad y late con el beat.
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float pulse = 0.0;
uniform vec4 tint : source_color = vec4(0.95, 0.12, 0.05, 1.0);
void fragment() {
	vec2 centered = (UV - vec2(0.5)) * vec2(1.0, 0.85);
	float edge = smoothstep(0.32, 0.78, length(centered));
	COLOR = vec4(tint.rgb, edge * clamp(intensity * (0.55 + 0.45 * pulse), 0.0, 0.85));
}
"""

var gauge: HeatGauge
var potato: HeatPotato
## Placa detrás de la papa y el manómetro: los separa del escenario; en alarma su borde late en rojo.
var _plate: Panel
var _plate_style: StyleBoxFlat
var alert: OverheatAlert
var dash_label: Label
var _vignette: ColorRect
## Lo que tiembla con la tensión (la viñeta no: dejaría un borde vacío).
var _shaken: Control
var _panel: PanelContainer
var _result_label: Label
var _intensity := 0.0
var _overheated := false
var _beat_pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = VIGNETTE_SHADER
	_vignette.material = material
	add_child(_vignette)
	_shaken = Control.new()
	_shaken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shaken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shaken)

	_plate_style = StyleBoxFlat.new()
	_plate_style.bg_color = Color(FreneticPalette.INK, 0.55)
	_plate_style.set_corner_radius_all(26)
	_plate_style.set_border_width_all(4)
	_plate_style.border_color = Color(FreneticPalette.INK, 0.8)
	_plate = Panel.new()
	_plate.add_theme_stylebox_override("panel", _plate_style)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_plate.offset_left = -362.0
	_plate.offset_top = -292.0
	_plate.offset_right = -18.0
	_plate.offset_bottom = -50.0
	_shaken.add_child(_plate)

	gauge = HeatGauge.new()
	gauge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	gauge.offset_left = -210.0
	gauge.offset_top = -285.0
	gauge.offset_right = -30.0
	gauge.offset_bottom = -105.0
	_shaken.add_child(gauge)

	# Papa caliente a la izquierda del manómetro: la etapa según el calor.
	potato = HeatPotato.new()
	potato.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	potato.offset_left = -350.0
	potato.offset_top = -280.0
	potato.offset_right = -200.0
	potato.offset_bottom = -110.0
	_shaken.add_child(potato)

	dash_label = _make_label(24)
	dash_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_label.offset_left = -350.0
	dash_label.offset_right = -30.0
	dash_label.offset_top = -95.0
	dash_label.offset_bottom = -59.0
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shaken.add_child(dash_label)

	alert = OverheatAlert.new()
	_shaken.add_child(alert)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(760.0, 260.0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(FreneticPalette.NAVY_DARK, 0.92)
	box.border_color = FreneticPalette.INK
	box.set_border_width_all(6)
	box.set_content_margin_all(28.0)
	_panel.add_theme_stylebox_override("panel", box)
	_panel.visible = false
	add_child(_panel)
	_result_label = _make_label(40)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_panel.add_child(_result_label)


func _process(delta: float) -> void:
	_beat_pulse = maxf(_beat_pulse - delta * 5.0, 0.0)
	var material := _vignette.material as ShaderMaterial
	material.set_shader_parameter("intensity", _intensity * (1.25 if _overheated else 1.0))
	material.set_shader_parameter("pulse", _beat_pulse)
	# El HUD tiembla: la sensación de perder el control.
	var strength := _intensity * (1.6 if _overheated else 1.0)
	_shaken.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * strength
	# Alarma (calor alto o mecha): el borde de la placa late en rojo con el beat.
	var alarm := potato.alarm()
	_plate_style.border_color = Color(FreneticPalette.INK, 0.8).lerp(HeatPotato.HALO_COLOR, alarm * (0.55 + 0.45 * _beat_pulse))
	_plate_style.set_border_width_all(4 + roundi(4.0 * alarm * _beat_pulse))
	_plate_style.bg_color = Color(FreneticPalette.INK, 0.55).lerp(Color(0.35, 0.02, 0.0, 0.6), alarm * 0.5 * _beat_pulse)
	alert.set_beat_pulse(_beat_pulse)


func set_heat(heat: float) -> void:
	gauge.set_heat(heat)
	potato.heat = heat


func set_intensity(intensity: float, overheated: bool) -> void:
	_intensity = clampf(intensity, 0.0, 1.0)
	_overheated = overheated
	gauge.set_intensity(_intensity, overheated)
	potato.overheated = overheated


func on_beat(accented: bool) -> void:
	_beat_pulse = 1.0 if accented else 0.7
	gauge.on_beat(_beat_pulse)
	potato.on_beat(_beat_pulse)


func show_overheat(active: bool, fuse_left: float) -> void:
	if active:
		alert.play(fuse_left)
	else:
		alert.stop()


func update_fuse(fuse_left: float) -> void:
	alert.update_fuse(fuse_left)


func update_dash(enabled: bool, cooldown_left: float, airborne: bool) -> void:
	dash_label.visible = enabled
	if cooldown_left > 0.0:
		dash_label.text = "DASH %.1f s" % cooldown_left
		dash_label.add_theme_color_override("font_color", WAIT_COLOR)
	elif airborne:
		dash_label.text = "DASH: solo en suelo"
		dash_label.add_theme_color_override("font_color", WAIT_COLOR)
	else:
		dash_label.text = "DASH listo (Shift)"
		dash_label.add_theme_color_override("font_color", READY_COLOR)


## Panel de fin de partida.
func show_result(won: bool, seconds: float, heat: float, score: int, best_combo: int) -> void:
	_panel.visible = true
	var whole := maxi(0, floori(seconds))
	var stats := "Tiempo %02d:%02d · Calor %d / 100 · %d pts · mejor combo x%d" % [
		whole / 60, whole % 60, roundi(heat), score, best_combo]
	if won:
		_result_label.text = "¡SALIDA!\n%s\nEnter: otra vez · N: seed siguiente" % stats
		_result_label.add_theme_color_override("font_color", FreneticPalette.YELLOW)
	else:
		_result_label.text = "LA PAPA EXPLOTÓ\n%s\nEnter: reintentar (misma seed) · N: seed siguiente" % stats
		_result_label.add_theme_color_override("font_color", FreneticPalette.CREAM)


func hide_result() -> void:
	_panel.visible = false


func reset() -> void:
	hide_result()
	alert.stop()
	set_intensity(0.0, false)
	set_heat(0.0)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", FreneticPalette.CREAM)
	label.add_theme_color_override("font_outline_color", FreneticPalette.INK)
	label.add_theme_constant_override("outline_size", 10)
	return label
