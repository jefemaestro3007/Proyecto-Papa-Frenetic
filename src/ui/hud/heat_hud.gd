class_name HeatHud
extends Control
## HUD de la papa caliente: abajo a la derecha la papa bomba (HeatPotato) con el manómetro incrustado
## y el indicador del dash (DashKey); aviso "SOBRECALENTAMIENTO" con cuenta atrás de la mecha y
## viñeta roja que late con el beat. El fin de partida usa las pantallas YOU WIN / YOU LOOSE (ZoneLevel).
## Va debajo del RhythmHud: la viñeta no tapa los textos de juicio.

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
var alert: OverheatAlert
var dash_key: DashKey
var _vignette: ColorRect
## Lo que tiembla con la tensión (la viñeta no: dejaría un borde vacío).
var _shaken: Control
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

	# Papa bomba abajo a la derecha, con el manómetro incrustado.
	potato = HeatPotato.new()
	potato.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	potato.offset_left = -270.0
	potato.offset_top = -300.0
	potato.offset_right = -30.0
	potato.offset_bottom = -50.0
	_shaken.add_child(potato)
	gauge = HeatGauge.new()
	potato.embed(gauge)

	# Tecla del dash a la izquierda de la papa.
	dash_key = DashKey.new()
	dash_key.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	dash_key.offset_left = -350.0
	dash_key.offset_top = -135.0
	dash_key.offset_right = -275.0
	dash_key.offset_bottom = -60.0
	_shaken.add_child(dash_key)

	alert = OverheatAlert.new()
	_shaken.add_child(alert)



func _process(delta: float) -> void:
	_beat_pulse = maxf(_beat_pulse - delta * 5.0, 0.0)
	var material := _vignette.material as ShaderMaterial
	material.set_shader_parameter("intensity", _intensity * (1.25 if _overheated else 1.0))
	material.set_shader_parameter("pulse", _beat_pulse)
	# El HUD tiembla: la sensación de perder el control.
	var strength := _intensity * (1.6 if _overheated else 1.0)
	_shaken.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * strength
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
	dash_key.on_beat(_beat_pulse)


func show_overheat(active: bool, fuse_left: float) -> void:
	if active:
		alert.play(fuse_left)
	else:
		alert.stop()


func update_fuse(fuse_left: float) -> void:
	alert.update_fuse(fuse_left)


func update_dash(enabled: bool, cooldown_left: float, cooldown_total: float, airborne: bool, facing: float) -> void:
	dash_key.visible = enabled
	dash_key.set_state(cooldown_left, cooldown_total, airborne, facing)


func reset() -> void:
	alert.stop()
	set_intensity(0.0, false)
	set_heat(0.0)

