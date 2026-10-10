@tool
class_name LiveDetailsView
extends Node2D
## Detalles animados de la azotea: balizas que laten con el beat, fuego en los barriles
## y moscas (FliesView). Separado de RooftopView para que lo estático no se redibuje cada frame.
## Solo dibuja lo que está cerca de la pantalla (SpatialIndex).

const FIRE_OUTER := Color("ff5a1a")
const FIRE_INNER := Color("ffd400")

var _style: ArtStyle
var _beacons := PackedVector2Array()
var _fires: Array[Rect2] = []
var _flies: FliesView
var _beacon_index := SpatialIndex.new()
var _fire_index := SpatialIndex.new()


func setup(data: AzoteaMapData, style: ArtStyle) -> void:
	_style = style
	_beacons.clear()
	_fires.clear()
	_beacon_index.clear()
	_fire_index.clear()
	if _flies == null:
		_flies = FliesView.new()
		add_child(_flies)
	_flies.setup(style)
	for prop in data.props:
		match prop.type:
			AzoteaMapData.Prop.Type.ANTENNA:
				_beacons.append(Vector2(prop.rect.get_center().x, prop.rect.position.y))
			AzoteaMapData.Prop.Type.BILLBOARD:
				_beacons.append(prop.rect.position + Vector2(10.0, 0.0))
				_beacons.append(Vector2(prop.rect.end.x - 10.0, prop.rect.position.y))
			AzoteaMapData.Prop.Type.BARREL:
				_fires.append(prop.rect)
				_flies.add_anchor(prop.rect.get_center() - Vector2(0.0, 50.0), prop.variant)
	_flies.add_marks(data.marks)
	for i in _beacons.size():
		_beacon_index.add(i, _beacons[i])
	for i in _fires.size():
		_fire_index.add(i, _fires[i].position)
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if _style == null:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 if Engine.is_editor_hint() else Conductor.pulse(5.0)
	var beacon := _style.blood.lightened(0.35)
	var screen := SpatialIndex.screen_rect(self)
	for i in _beacon_index.query(screen):
		var point := _beacons[i]
		draw_circle(point, 14.0 * pulse, Color(beacon, 0.35 * pulse))
		draw_circle(point, 5.0, beacon.lerp(Color.WHITE, pulse * 0.6))
	if _style.fires > 0.0:
		for i in _fire_index.query(screen):
			_draw_fire(_fires[i], time, pulse)


## Llamas: lenguas que oscilan, más altas en el beat, con resplandor.
func _draw_fire(barrel: Rect2, time: float, pulse: float) -> void:
	var base := Vector2(barrel.get_center().x, barrel.position.y)
	var height := 60.0 * _style.fires * (1.0 + 0.3 * pulse)
	draw_circle(base + Vector2(0.0, -height * 0.4), height * 1.1, Color(FIRE_OUTER, 0.12 * _style.fires))
	for layer in 2:
		var color := FIRE_OUTER if layer == 0 else FIRE_INNER
		var size_factor := 1.0 if layer == 0 else 0.55
		for i in 4:
			var offset := (i - 1.5) * barrel.size.x * 0.2 * size_factor
			var flicker := 0.75 + 0.25 * sin(time * (9.0 + i * 2.3) + barrel.position.x + i)
			var tip := base + Vector2(offset + sin(time * 7.0 + i) * 6.0, -height * flicker * size_factor)
			var flame := PackedVector2Array([base + Vector2(offset - 9.0 * size_factor, 0.0), tip,
					base + Vector2(offset + 9.0 * size_factor, 0.0)])
			draw_colored_polygon(flame, color)
