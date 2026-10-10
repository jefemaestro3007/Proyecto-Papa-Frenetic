class_name HeatPotato
extends Control
## Papa bomba del HUD: cinco dibujos del equipo, uno por cada 20 de calor (la papa se hincha y
## enrojece), con el manómetro incrustado en el centro: un solo sistema a punto de explotar. El
## manómetro se mueve con la papa (latido, vibración, tambaleo y golpe al cambiar de etapa). Late con el beat y da un golpe de escala al cambiar de etapa.
## Desde ALARM_HEAT vibra, se tambalea y tiene un halo rojo que late; con la mecha encendida
## vibra al máximo, parpadea y echa vapor: la urgencia de enfriarla tiene que leerse de un vistazo.

const TEXTURE_PATH := "res://assets/textures/ui/papa_calor_%d.png"
const STAGES := 5
## Las texturas están al doble de resolución.
const TEXTURE_SCALE := 0.5
const ALARM_HEAT := 80.0
const HALO_COLOR := Color(1.0, 0.16, 0.06)

var heat := 0.0
var overheated := false
var _textures: Array[Texture2D] = []
var _stage := 0
var _pop := 0.0
var _beat := 0.0
var _time := 0.0
var _shake := Vector2.ZERO
var _tilt := 0.0
## Manómetro incrustado (hijo de la papa) y su escala del frame.
var _gauge: HeatGauge
var _scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in STAGES:
		var path := TEXTURE_PATH % (i + 1)
		if ResourceLoader.exists(path):
			_textures.append(load(path))


## Incrusta el manómetro en la papa.
func embed(gauge: HeatGauge) -> void:
	_gauge = gauge
	add_child(gauge)
	gauge.size = gauge.custom_minimum_size
	gauge.pivot_offset = gauge.size * 0.5


func on_beat(pulse: float) -> void:
	_beat = pulse


## Etapa 0-4 según el calor (0-20, 20-40, 40-60, 60-80, 80-100).
static func stage_for(value: float) -> int:
	return clampi(floori(value / (100.0 / STAGES)), 0, STAGES - 1)


## 0 por debajo de la alarma, 1 al llegar a 100 (y durante la mecha).
func alarm() -> float:
	if overheated:
		return 1.0
	return clampf((heat - ALARM_HEAT) / (100.0 - ALARM_HEAT), 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_beat = maxf(_beat - delta * 5.0, 0.0)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	var stage := stage_for(heat)
	if stage != _stage:
		_stage = stage
		_pop = 1.0
	var alarm := alarm()
	var in_alarm := heat >= ALARM_HEAT or overheated
	# Vibración nerviosa desde la alarma; con la mecha, al máximo.
	var amplitude := (2.0 + 6.0 * alarm) * (1.6 if overheated else 1.0) if in_alarm else 0.0
	_shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude
	_tilt = sin(_time * (14.0 + 10.0 * alarm)) * deg_to_rad(3.0 + 5.0 * alarm) if in_alarm else 0.0
	_scale = 1.0 + (0.04 + 0.08 * alarm) * _beat + 0.25 * ease(_pop, 0.5)
	if _gauge != null:
		_gauge.position = gauge_center() - _gauge.size * 0.5
		_gauge.rotation = _tilt
		_gauge.scale = Vector2.ONE * _scale
	queue_redraw()


## Dónde va el centro del manómetro: en el medio de la panza de la papa.
func gauge_center() -> Vector2:
	return size * Vector2(0.5, 0.55) + _shake


func _draw() -> void:
	if _textures.is_empty():
		return
	var texture := _textures[mini(_stage, _textures.size() - 1)]
	var base := texture.get_size() * TEXTURE_SCALE
	var fit := minf(size.x / base.x, size.y / base.y)
	var in_alarm := heat >= ALARM_HEAT or overheated
	var pulse := _scale
	var center := size * 0.5 + _shake
	if in_alarm:
		# Halo rojo que late con el beat.
		var radius := base.length() * 0.32 * fit * (1.0 + 0.15 * _beat)
		for i in 4:
			var k := 1.0 - i * 0.22
			draw_circle(center, radius * (1.0 + i * 0.18), Color(HALO_COLOR, (0.18 + 0.3 * _beat) * k))
	draw_set_transform(center, _tilt, Vector2.ONE * fit * pulse)
	var rect := Rect2(-base * 0.5, base)
	var flash := 0.0
	if overheated:
		flash = 0.6 * absf(sin(_time * 18.0))
	draw_texture_rect(texture, rect, false, Color(1.0 + flash, 1.0 + flash * 0.6, 1.0 + flash * 0.6))
	draw_set_transform(Vector2.ZERO)
	if _gauge != null:
		# Hueco donde se hunde el manómetro (sombra sobre la papa).
		var hole := gauge_center() + Vector2(3.0, 6.0)
		var radius := _gauge.size.x * 0.5 * _scale
		draw_circle(hole, radius * 1.02, Color(0.18, 0.06, 0.02, 0.55))
		draw_circle(hole, radius * 0.9, Color(0.1, 0.03, 0.0, 0.35))
	draw_set_transform(center, _tilt, Vector2.ONE * fit * pulse)
	if overheated:
		# Vapor saliendo de arriba.
		for i in 4:
			var phase := fmod(_time * 1.1 + i * 0.25, 1.0)
			var puff := Vector2(sin(i * 2.3 + _time * 3.0) * base.x * 0.18, -base.y * (0.45 + 0.5 * phase))
			draw_circle(puff, base.x * (0.06 + 0.1 * phase), Color(0.95, 0.95, 0.97, 0.55 * (1.0 - phase)))
	draw_set_transform(Vector2.ZERO)
