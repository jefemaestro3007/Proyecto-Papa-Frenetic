class_name WallDoorNode
extends StaticBody2D
## Puerta entre módulos. Se abre sola al acercarse (en el beat, si se pide) y deja pasar;
## si tiene cerradura, solo se abre con la llave de su color. Se cierra al alejarse.

const OPEN_DISTANCE := 150.0
const CLOSE_DISTANCE := 260.0
const KEY_COLORS := [Color("ff4a4a"), Color("ffd400"), Color("4fd8ff")]

var spec: OficinasMapData.WallDoor
var style: ArtStyle
## Quien puede abrirla y la función que dice si tiene una llave.
var opener: Node2D
var has_key: Callable
var sync_to_beat := true

var _open := 0.0
var _wants_open := false
var _open_at_beat := -1
var _collision: CollisionShape2D


func setup(p_spec: OficinasMapData.WallDoor, p_style: ArtStyle) -> void:
	spec = p_spec
	style = p_style
	position = spec.rect.position
	var shape := RectangleShape2D.new()
	shape.size = spec.rect.size
	_collision = CollisionShape2D.new()
	_collision.shape = shape
	_collision.position = spec.rect.size * 0.5
	add_child(_collision)


func is_locked() -> bool:
	return spec.key >= 0 and not (has_key.is_valid() and has_key.call(spec.key))


func _physics_process(delta: float) -> void:
	if opener == null:
		return
	var distance := absf(opener.global_position.x - (position.x + spec.rect.size.x * 0.5))
	var same_floor := absf(opener.global_position.y - spec.rect.end.y) < 60.0
	if same_floor and distance < OPEN_DISTANCE and not is_locked():
		if not _wants_open:
			_wants_open = true
			_open_at_beat = Conductor.beat_index() + 1 if sync_to_beat else -1
	elif distance > CLOSE_DISTANCE or not same_floor:
		_wants_open = false
	var opening := _wants_open and (_open_at_beat < 0 or Conductor.beat_index() >= _open_at_beat)
	_open = move_toward(_open, 1.0 if opening else 0.0, delta * 8.0)
	# Pasable en cuanto empieza a abrirse; vuelve a ser sólida solo cerrada del todo.
	_collision.disabled = _open > 0.2
	queue_redraw()


func _draw() -> void:
	if style == null:
		return
	var size := spec.rect.size
	var outline := maxf(style.outline_width * 0.6, 2.0)
	if _open < 1.0:
		# Hoja que gira hacia el fondo: se angosta al abrirse.
		var width := size.x * (1.0 - _open) + 2.0
		var leaf := Rect2(size.x * 0.5 - width * 0.5, 0.0, width, size.y)
		draw_rect(leaf, style.furniture)
		draw_rect(leaf, style.outline, false, outline)
	if _open > 0.0:
		var swing := PackedVector2Array([Vector2(size.x, 0.0), Vector2(size.x + 50.0 * _open, 16.0 * _open),
				Vector2(size.x + 50.0 * _open, size.y - 2.0), Vector2(size.x, size.y)])
		draw_colored_polygon(swing, style.furniture.darkened(0.15))
		draw_polyline(swing, style.outline, outline)
	if spec.key >= 0:
		var color: Color = KEY_COLORS[spec.key % KEY_COLORS.size()]
		var lock := Vector2(size.x * 0.5, size.y * 0.5)
		draw_rect(Rect2(lock + Vector2(-12.0, -6.0), Vector2(24.0, 20.0)), color)
		draw_arc(lock + Vector2(0.0, -6.0), 8.0, PI, TAU, 10, color, 4.0)
		draw_rect(Rect2(lock + Vector2(-12.0, -6.0), Vector2(24.0, 20.0)), style.outline, false, 2.0)
