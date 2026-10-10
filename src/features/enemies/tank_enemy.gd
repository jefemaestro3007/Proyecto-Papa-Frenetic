class_name TankEnemy
extends Enemy
## Papa tanque (del prototipo): grande, lenta y con casco de olla. Aguanta varios golpes y no
## desaparece al tocar al jugador: le cobra el calor y sigue persiguiéndolo. Un stomp o dash que
## no la derriba hace rebotar al jugador.

const HELMET_COLOR := Color("5b6474")


func _init() -> void:
	enemy_type = &"tank"
	move_speed = 115.0
	max_health = 3
	consumed_on_contact = false
	body_radius = 48.0
	body_color = Color("9a6234")


func _draw_after_body(center: Vector2) -> void:
	if _dying:
		return
	# Casco de olla: la distingue a simple vista.
	draw_arc(center + Vector2(0.0, -6.0), body_radius + 2.0, PI * 1.08, PI * 1.92, 20, HELMET_COLOR, 16.0)
	var brim := Rect2(center + Vector2(-body_radius * 0.75, -body_radius - 4.0), Vector2(body_radius * 1.5, 10.0))
	draw_rect(brim, HELMET_COLOR)
	draw_rect(brim, _outline(), false, 2.0)
	# Cejas fruncidas.
	draw_line(center + Vector2(-24.0, -20.0), center + Vector2(-8.0, -14.0), FACE_COLOR, 4.0)
	draw_line(center + Vector2(24.0, -20.0), center + Vector2(8.0, -14.0), FACE_COLOR, 4.0)
