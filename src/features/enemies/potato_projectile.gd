class_name PotatoProjectile
extends Area2D
## Papa frita lanzada por la tiradora: vuela en arco, se rompe contra el escenario y suma calor
## al tocar al jugador (si es invulnerable, lo atraviesa sin daño). La de la promotora va en llamas.

signal hit_player(projectile: PotatoProjectile)
## Chocó contra el escenario (antes de desaparecer).
signal hit_solid(projectile: PotatoProjectile)

const GRAVITY := 1400.0
const RADIUS := 12.0
const MAX_LIFETIME := 4.0

var velocity := Vector2.ZERO
var target: Node2D
var style: ArtStyle
## Muestra en llamas de la promotora (Bienestar U): quema al impactar y deja fuego en el piso.
var flaming := false
var _age := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	body_entered.connect(_on_body_entered)
	z_index = 46


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation += 14.0 * delta
	_age += delta
	if flaming:
		queue_redraw()
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	# Si el jugador era invulnerable al entrar, se reintenta mientras sigan solapados.
	if is_instance_valid(target) and overlaps_body(target):
		hit_player.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if body == target:
		hit_player.emit(self)
	elif body is StaticBody2D:
		hit_solid.emit(self)
		queue_free()


func _draw() -> void:
	if flaming:
		# Estela de fuego hacia atrás (en coordenadas del mundo: no gira con la papa).
		draw_set_transform(Vector2.ZERO, -rotation)
		var back := -velocity.normalized() * RADIUS
		var flicker := 0.8 + 0.2 * sin(_age * 40.0)
		draw_circle(Vector2.ZERO, RADIUS * 1.9, Color("ff7a2f", 0.35))
		var outer := PackedVector2Array([back.orthogonal() * 1.6, back * 4.5 * flicker, -back.orthogonal() * 1.6])
		draw_colored_polygon(outer, Color("ff7a2f"))
		draw_polyline(outer, style.outline if style != null else FreneticPalette.INK, 2.0, true)
		draw_colored_polygon(PackedVector2Array([back.orthogonal() * 0.8, back * 2.8 * flicker, -back.orthogonal() * 0.8]),
				FreneticPalette.YELLOW)
		draw_set_transform(Vector2.ZERO)
	var rect := Rect2(-RADIUS * 0.45, -RADIUS * 1.3, RADIUS * 0.9, RADIUS * 2.6)
	draw_rect(rect, Color("f2c14e"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, RADIUS * 0.5)), Color("d98e2b"))
	draw_rect(rect, style.outline if style != null else FreneticPalette.INK, false, 2.0)
