class_name ChargerEnemy
extends Enemy
## Papa embestidora (del prototipo): al ver al jugador en su nivel avisa (se pone roja y muestra
## "!") y carga a gran velocidad por su carril. Es más para esquivar que para matar: tras cada
## carga queda aturdida (estrellas), la mejor ventana para golpearla. No desaparece al tocar al
## jugador y le suma más calor que las demás.

enum State { IDLE, WINDUP, CHARGE, RECOVER }

var detect_range := 900.0
var windup_seconds := 0.45
var charge_speed := 1000.0
var max_charge_seconds := 1.1
var recover_seconds := 1.0
var idle_speed := 55.0
var state := State.IDLE

var _state_time := 0.0
var _charge_direction := 1
var _visual_time := 0.0


func _init() -> void:
	enemy_type = &"charger"
	contact_heat_scale = 1.5
	consumed_on_contact = false
	body_color = Color("c4683c")


func _move(delta: float) -> void:
	_state_time = maxf(_state_time - delta, 0.0)
	match state:
		State.IDLE:
			var dx := target.global_position.x - global_position.x
			if is_same_level_as_target() and absf(dx) <= detect_range:
				facing = 1 if dx > 0.0 else -1
				_enter(State.WINDUP, windup_seconds)
			elif absf(dx) > 4.0:
				# Merodea despacio mientras no ve al jugador.
				facing = 1 if dx > 0.0 else -1
				position.x = clampf(position.x + facing * idle_speed * delta, lane_left, lane_right)
		State.WINDUP:
			if _state_time <= 0.0:
				_charge_direction = facing
				_enter(State.CHARGE, max_charge_seconds)
		State.CHARGE:
			var next_x := position.x + _charge_direction * charge_speed * delta
			position.x = clampf(next_x, lane_left, lane_right)
			# Termina al agotar su tiempo o al llegar al final del carril.
			if _state_time <= 0.0 or next_x <= lane_left or next_x >= lane_right:
				_enter(State.RECOVER, recover_seconds)
		State.RECOVER:
			if _state_time <= 0.0:
				_enter(State.IDLE, 0.0)


func _enter(new_state: State, duration: float) -> void:
	state = new_state
	_state_time = duration


func _update_visuals(delta: float) -> void:
	_visual_time += delta


func _body_color() -> Color:
	if state == State.WINDUP and not _dying:
		return body_color.lerp(Color("ff3b2f"), 0.5 + 0.5 * sin(_visual_time * 40.0))
	return body_color


func _draw_before_body(center: Vector2) -> void:
	if _dying or state != State.CHARGE:
		return
	# Líneas de velocidad detrás de la carga.
	var back := -float(_charge_direction)
	for i in 4:
		var y := center.y - 20.0 + i * 13.0
		draw_line(Vector2(back * (body_radius + 6.0), y), Vector2(back * (body_radius + 46.0 + 12.0 * i), y),
				Color(1.0, 0.9, 0.75, 0.7), 4.0)


func _draw_after_body(center: Vector2) -> void:
	if _dying:
		return
	# Cuernos y cejas de enojo.
	for side: float in [-1.0, 1.0]:
		var horn := PackedVector2Array([
			center + Vector2(side * 14.0, -body_radius + 6.0),
			center + Vector2(side * 30.0, -body_radius - 18.0),
			center + Vector2(side * 26.0, -body_radius + 12.0),
		])
		draw_colored_polygon(horn, Color("f2e6c9"))
		draw_polyline(horn + PackedVector2Array([horn[0]]), _outline(), 2.0)
		draw_line(center + Vector2(side * 20.0, -18.0), center + Vector2(side * 6.0, -11.0), FACE_COLOR, 4.0)


## Embistiendo (aviso y carga) muestra la pose de ataque; aturdida, la de herida.
func sprite_pose() -> StringName:
	if _dying or _hurt_left > 0.0 or state == State.RECOVER:
		return &"herido"
	if state == State.WINDUP or state == State.CHARGE:
		return &"ataque"
	return &"base"


## "!" al prepararse y estrellas de aturdimiento: momento ideal para golpearla.
func _draw_indicators(_center: Vector2) -> void:
	match state:
		State.WINDUP:
			var font := ThemeDB.fallback_font
			var at := Vector2(-9.0, _top_y - 12.0)
			draw_string_outline(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, 10, Color(0.1, 0.05, 0.05))
			draw_string(font, at, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color("ff5a4a"))
		State.RECOVER:
			# Estrellitas de aturdimiento: momento ideal para golpearla.
			for i in 3:
				var angle := _visual_time * 6.0 + TAU * i / 3.0
				draw_circle(Vector2(cos(angle) * 30.0, _top_y - 6.0 + sin(angle) * 8.0), 5.0,
						Color("ffd166"))
