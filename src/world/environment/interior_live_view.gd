@tool
class_name InteriorLiveView
extends Node2D
## Detalles animados del interior: lámparas que parpadean al ritmo (algunas fallan en
## ciertos beats), conos de luz, carteles de salida que laten y moscas.

var _style: ArtStyle
var _lamps: Array[OficinasMapData.Lamp] = []
var _signs: Array[Rect2] = []
var _flies: FliesView


func setup(data: OficinasMapData, style: ArtStyle) -> void:
	_style = style
	_lamps = data.lamps
	_signs.clear()
	for item in data.furniture:
		if item.type == OficinasMapData.Furniture.Type.EXIT_SIGN:
			_signs.append(item.rect)
	if _flies == null:
		_flies = FliesView.new()
		add_child(_flies)
	_flies.setup(style)
	_flies.add_marks(data.marks)
	queue_redraw()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if _style == null:
		return
	var editor := Engine.is_editor_hint()
	var pulse := 1.0 if editor else Conductor.pulse(6.0)
	var beat := 0 if editor else Conductor.beat_index()
	for lamp in _lamps:
		if not lamp.working:
			continue
		# Parpadeo determinista: cada lámpara se apaga en algunos beats propios.
		var off := fposmod(sin(float(beat * 31 + lamp.variant % 997)) * 43758.5453, 1.0) < 0.12
		if off:
			continue
		var top := lamp.position + Vector2(0.0, 36.0)
		var strength := 0.10 + 0.06 * pulse
		var cone := PackedVector2Array([top + Vector2(-60.0, 0.0), top + Vector2(60.0, 0.0),
				top + Vector2(170.0, 330.0), top + Vector2(-170.0, 330.0)])
		draw_colored_polygon(cone, Color(_style.window_lit, strength))
		draw_rect(Rect2(top.x - 60.0, top.y - 4.0, 120.0, 5.0), _style.window_lit.lerp(Color.WHITE, 0.5 * pulse))
	for rect in _signs:
		draw_rect(rect.grow(10.0 * pulse), Color(InteriorView.EXIT_GREEN, 0.18 * pulse))
