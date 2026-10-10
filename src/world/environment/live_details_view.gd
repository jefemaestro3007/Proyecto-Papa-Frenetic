@tool
class_name BeaconView
extends Node2D
## Luces de baliza en la punta de antenas y carteles; laten con el Conductor.
## Separado de RooftopView para que lo estático no se redibuje cada frame.

var color: Color = FreneticPalette.SKY
var _points := PackedVector2Array()


func setup(data: AzoteaMapData, beacon_color: Color) -> void:
	color = beacon_color
	_points.clear()
	for prop in data.props:
		match prop.type:
			AzoteaMapData.Prop.Type.ANTENNA:
				_points.append(Vector2(prop.rect.get_center().x, prop.rect.position.y))
			AzoteaMapData.Prop.Type.BILLBOARD:
				_points.append(prop.rect.position + Vector2(10.0, 0.0))
				_points.append(Vector2(prop.rect.end.x - 10.0, prop.rect.position.y))
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	var pulse := 1.0 if Engine.is_editor_hint() else Conductor.pulse(5.0)
	for point in _points:
		draw_circle(point, 14.0 * pulse, Color(color, 0.35 * pulse))
		draw_circle(point, 5.0, color.lerp(Color.WHITE, pulse * 0.6))
