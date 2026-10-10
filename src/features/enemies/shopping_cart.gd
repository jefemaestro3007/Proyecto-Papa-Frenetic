class_name ShoppingCart
extends Area2D
## Carrito que lanza el reponedor: rueda por el carril de la papa y suma calor al tocar al jugador
## (si es invulnerable lo atraviesa). Al llegar al final del carril choca, vuelca y desaparece.

signal hit_player(cart: ShoppingCart)

## Escala del dibujo (alto de la papa que lo empuja).
const HEIGHT := 104.0
const CRASH_SECONDS := 0.6

var direction := 1.0
var speed := 900.0
var lane_left := 0.0
var lane_right := 0.0
var target: Node2D
var style: ArtStyle
var _crash := -1.0
var _spin := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(HEIGHT * 0.9, HEIGHT * 0.6)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(direction * HEIGHT * 0.45, -HEIGHT * 0.32)
	add_child(collision)
	z_index = 44


func is_rolling() -> bool:
	return _crash < 0.0


func _physics_process(delta: float) -> void:
	if not is_rolling():
		_crash += delta
		rotation = direction * minf(_crash * 6.0, PI * 0.5)
		modulate.a = clampf(1.0 - (_crash - CRASH_SECONDS * 0.5) / (CRASH_SECONDS * 0.5), 0.0, 1.0)
		if _crash >= CRASH_SECONDS:
			queue_free()
		return
	position.x += direction * speed * delta
	_spin += speed * delta / (HEIGHT * 0.05)
	if position.x <= lane_left or position.x >= lane_right:
		position.x = clampf(position.x, lane_left, lane_right)
		_crash = 0.0
		return
	if is_instance_valid(target) and overlaps_body(target):
		hit_player.emit(self)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# El dibujo tiene el canasto a la izquierda: se espeja al rodar hacia la derecha.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(-direction, 1.0))
	var ink := style.outline if style != null else FreneticPalette.INK
	var width := clampf(style.outline_width * 0.75 if style != null else 3.0, 2.0, 4.0)
	EnemyCostume.cart(self, Vector2.ZERO, HEIGHT, ink, width, 0.0, _spin)
	# Líneas de velocidad detrás.
	if is_rolling():
		for i in 3:
			var y := -HEIGHT * (0.25 + i * 0.15)
			draw_line(Vector2(HEIGHT * 0.25, y), Vector2(HEIGHT * 0.6, y), Color(FreneticPalette.CREAM, 0.7), 3.0)
