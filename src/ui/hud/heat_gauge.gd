class_name HeatGauge
extends Control

# Manómetro de presión de la papa (esquina inferior derecha). Sin números (salvo el 0)
# ni umbrales de juego: una esfera con rayitas, banda verde → amarillo → naranja → rojo
# y una zona roja final de "no pasar". La aguja tiembla cada vez más con la presión;
# con la mecha encendida golpea el tope, el cristal se agrieta y sale vapor.

const DIAL_RADIUS := 148.0
# Escala visual del manómetro (0.6 = 40 % más pequeño que el diseño original).
const DIAL_SCALE := 0.6
# La escala recorre 270°: empieza abajo a la izquierda y termina abajo a la derecha.
const START_ANGLE := 2.35619449 # 135°
const SWEEP := 4.71238898 # 270°
# Zona roja final de la esfera.
const RED_ZONE_START := 0.85
# La aguja puede pasar un poco del final hasta chocar con el tope.
const PEG_LEVEL := 1.04
const LEVEL_SMOOTHING := 5.0
const MINOR_TICKS := 40
const MAJOR_EVERY := 5
const GRADIENT_STOPS: Array[Color] = [Color("3ddc5a"), Color("ffe03a"), Color("ff8c1a"), Color("ff2a1a")]

const FACE_COLOR := Color("efe6d2")
const INK_COLOR := Color("2a2622")
const BEZEL_DARK := Color("3a3d44")
const BEZEL_LIGHT := Color("c9ccd3")
const NEEDLE_COLOR := Color("d6261c")
const RED_ZONE_COLOR := Color("e3241b")

var heat := 0.0
var displayed_level := 0.0
var _intensity := 0.0
var _overheated := false
var _beat_pulse := 0.0
var _time := 0.0
var _needle_angle := START_ANGLE
var _shake_offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2.ONE * (DIAL_RADIUS * 2.0 + 40.0) * DIAL_SCALE


func set_heat(value: float) -> void:
	heat = clampf(value, 0.0, 100.0)


func set_intensity(intensity: float, overheated: bool) -> void:
	_intensity = intensity
	_overheated = overheated


func on_beat(pulse: float) -> void:
	_beat_pulse = pulse


func get_level_color() -> Color:
	return sample_gradient(displayed_level)


static func sample_gradient(level: float) -> Color:
	var scaled := clampf(level, 0.0, 1.0) * float(GRADIENT_STOPS.size() - 1)
	var index := mini(int(scaled), GRADIENT_STOPS.size() - 2)
	return GRADIENT_STOPS[index].lerp(GRADIENT_STOPS[index + 1], scaled - float(index))


static func level_to_angle(level: float) -> float:
	return START_ANGLE + SWEEP * level


func get_needle_angle() -> float:
	return _needle_angle


# Amplitud del temblor de la aguja (radianes): casi nula en frío, violenta al límite.
func get_shake_amplitude() -> float:
	var level := clampf(displayed_level, 0.0, 1.0)
	var amplitude := deg_to_rad(0.4) + deg_to_rad(5.0) * pow(level, 3.0)
	if level >= RED_ZONE_START:
		amplitude += deg_to_rad(3.0)
	if _overheated:
		amplitude += deg_to_rad(6.0)
	return amplitude


func _process(delta: float) -> void:
	_time += delta
	_beat_pulse = maxf(_beat_pulse - delta * 6.0, 0.0)
	var target := heat / 100.0
	if _overheated:
		target = PEG_LEVEL
	displayed_level = lerpf(displayed_level, target, minf(1.0, delta * LEVEL_SMOOTHING))

	# Temblor nervioso: mezcla de vibración rápida y sacudidas aleatorias.
	var amplitude := get_shake_amplitude()
	var tremble := (sin(_time * 47.0) * 0.6 + sin(_time * 29.0 + 1.3) * 0.4) * amplitude
	tremble += randf_range(-1.0, 1.0) * amplitude * 0.5
	var beat_kick := deg_to_rad(4.0) * _beat_pulse * _intensity
	var angle_level := minf(displayed_level, PEG_LEVEL)
	_needle_angle = level_to_angle(angle_level) + tremble + beat_kick
	if _overheated:
		# Rebota contra el tope del final de la escala.
		_needle_angle = minf(_needle_angle, level_to_angle(PEG_LEVEL))
		_needle_angle -= absf(sin(_time * 22.0)) * deg_to_rad(5.0)

	# Todo el manómetro vibra cerca del límite.
	var body_shake := 0.0
	if displayed_level > 0.7:
		body_shake = (displayed_level - 0.7) / 0.3 * 2.5
	if _overheated:
		body_shake = 4.5
	_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * body_shake
	queue_redraw()


func _draw() -> void:
	# Todo el manómetro se dibuja a escala alrededor de su centro.
	draw_set_transform(size * 0.5 + _shake_offset, 0.0, Vector2.ONE * DIAL_SCALE)
	var center := Vector2.ZERO
	_draw_body(center)
	_draw_scale(center)
	_draw_needle(center)
	_draw_glass(center)
	if _overheated:
		_draw_overheat(center)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body(center: Vector2) -> void:
	# Sombra, bisel metálico y esfera.
	draw_circle(center + Vector2(4.0, 6.0), DIAL_RADIUS + 16.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, DIAL_RADIUS + 16.0, BEZEL_DARK)
	draw_circle(center, DIAL_RADIUS + 12.0, BEZEL_LIGHT)
	draw_arc(center, DIAL_RADIUS + 9.0, deg_to_rad(200.0), deg_to_rad(340.0), 32, Color(1.0, 1.0, 1.0, 0.55), 3.0)
	draw_circle(center, DIAL_RADIUS + 6.0, BEZEL_DARK)
	draw_circle(center, DIAL_RADIUS, FACE_COLOR)
	# Tornillos del bisel.
	for screw_angle_deg: float in [45.0, 135.0, 225.0, 315.0]:
		var screw := center + Vector2.from_angle(deg_to_rad(screw_angle_deg)) * (DIAL_RADIUS + 11.0)
		draw_circle(screw, 3.5, BEZEL_DARK)


func _draw_scale(center: Vector2) -> void:
	# Banda de color difuminada a lo largo de la escala.
	var band_radius := DIAL_RADIUS - 14.0
	var steps := 90
	for step in range(steps):
		var from_level := float(step) / float(steps)
		var to_level := float(step + 1) / float(steps)
		draw_arc(center, band_radius, level_to_angle(from_level), level_to_angle(to_level) + 0.01, 3, Color(sample_gradient(from_level), 0.55), 10.0)
	# Zona roja de "no pasar", más gruesa e intensa.
	draw_arc(center, band_radius + 2.0, level_to_angle(RED_ZONE_START), level_to_angle(1.0), 24, RED_ZONE_COLOR, 16.0)
	for stripe in range(6):
		var stripe_level := lerpf(RED_ZONE_START, 1.0, (float(stripe) + 0.5) / 6.0)
		var direction := Vector2.from_angle(level_to_angle(stripe_level))
		draw_line(center + direction * (band_radius - 6.0), center + direction * (band_radius + 9.0), Color(0.45, 0.02, 0.0, 0.7), 2.0)

	# Rayitas: menores y mayores.
	for tick in range(MINOR_TICKS + 1):
		var level := float(tick) / float(MINOR_TICKS)
		var direction := Vector2.from_angle(level_to_angle(level))
		var major := tick % MAJOR_EVERY == 0
		var outer := DIAL_RADIUS - 24.0
		var inner := outer - (18.0 if major else 9.0)
		var ink := RED_ZONE_COLOR.darkened(0.2) if level >= RED_ZONE_START else INK_COLOR
		draw_line(center + direction * inner, center + direction * outer, ink, 4.0 if major else 2.0)

	# El único número: el cero del inicio.
	var font := ThemeDB.fallback_font
	var zero_position := center + Vector2.from_angle(level_to_angle(0.0)) * (DIAL_RADIUS - 62.0)
	draw_string(font, zero_position + Vector2(-9.0, 9.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, INK_COLOR)
	# Señal de peligro junto a la zona roja.
	var warning_position := center + Vector2.from_angle(level_to_angle(0.93)) * (DIAL_RADIUS - 64.0)
	draw_colored_polygon(PackedVector2Array([
		warning_position + Vector2(0.0, -14.0), warning_position + Vector2(13.0, 9.0), warning_position + Vector2(-13.0, 9.0),
	]), RED_ZONE_COLOR)
	draw_rect(Rect2(warning_position + Vector2(-1.5, -6.0), Vector2(3.0, 8.0)), FACE_COLOR)
	draw_rect(Rect2(warning_position + Vector2(-1.5, 4.0), Vector2(3.0, 3.0)), FACE_COLOR)
	# Tope de la aguja al final de la escala.
	draw_circle(center + Vector2.from_angle(level_to_angle(PEG_LEVEL + 0.01)) * (DIAL_RADIUS - 30.0), 5.0, BEZEL_DARK)


func _draw_needle(center: Vector2) -> void:
	var direction := Vector2.from_angle(_needle_angle)
	var normal := Vector2(-direction.y, direction.x)
	var tip := center + direction * (DIAL_RADIUS - 26.0)
	var tail := center - direction * 26.0
	# Sombra de la aguja.
	draw_colored_polygon(PackedVector2Array([
		tip + Vector2(3.0, 4.0), center + normal * 7.0 + Vector2(3.0, 4.0), tail + Vector2(3.0, 4.0), center - normal * 7.0 + Vector2(3.0, 4.0),
	]), Color(0.0, 0.0, 0.0, 0.25))
	draw_colored_polygon(PackedVector2Array([tip, center + normal * 7.0, tail, center - normal * 7.0]), NEEDLE_COLOR)
	draw_line(center, tip, NEEDLE_COLOR.lightened(0.35), 1.5)
	# Tapa central metálica.
	draw_circle(center, 14.0, BEZEL_DARK)
	draw_circle(center, 10.0, BEZEL_LIGHT)
	draw_circle(center + Vector2(-3.0, -3.0), 3.5, Color(1.0, 1.0, 1.0, 0.7))


func _draw_glass(center: Vector2) -> void:
	# Reflejo del cristal.
	draw_arc(center, DIAL_RADIUS - 10.0, deg_to_rad(195.0), deg_to_rad(255.0), 20, Color(1.0, 1.0, 1.0, 0.35), 8.0)
	draw_arc(center, DIAL_RADIUS - 24.0, deg_to_rad(205.0), deg_to_rad(230.0), 12, Color(1.0, 1.0, 1.0, 0.22), 5.0)


func _draw_overheat(center: Vector2) -> void:
	# Cristal agrietado.
	var crack_color := Color(0.18, 0.16, 0.15, 0.85)
	var crack_edge := Color(1.0, 1.0, 1.0, 0.6)
	var crack_origin := center + Vector2(DIAL_RADIUS * 0.35, -DIAL_RADIUS * 0.3)
	var crack_points: Array = [
		[Vector2(0, 0), Vector2(30, -26), Vector2(52, -30)],
		[Vector2(0, 0), Vector2(-24, -34), Vector2(-30, -62)],
		[Vector2(0, 0), Vector2(-36, 10), Vector2(-70, 4)],
		[Vector2(0, 0), Vector2(12, 34), Vector2(6, 58)],
	]
	for crack: Array in crack_points:
		for index in range(crack.size() - 1):
			draw_line(crack_origin + crack[index] + Vector2(1.0, 1.0), crack_origin + crack[index + 1] + Vector2(1.0, 1.0), crack_edge, 1.5)
			draw_line(crack_origin + crack[index], crack_origin + crack[index + 1], crack_color, 2.5)
	# Vapor saliendo por arriba.
	for puff in range(4):
		var phase := fmod(_time * 0.9 + float(puff) * 0.25, 1.0)
		var puff_position := center + Vector2(sin(float(puff) * 2.1) * 30.0 + sin(_time * 3.0 + float(puff)) * 8.0, -DIAL_RADIUS - 10.0 - phase * 70.0)
		draw_circle(puff_position, 10.0 + phase * 18.0, Color(0.92, 0.92, 0.95, 0.5 * (1.0 - phase)))
