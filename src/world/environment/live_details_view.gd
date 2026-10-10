@tool
class_name LiveDetailsView
extends Node2D
## Detalles animados de la azotea: balizas que laten con el beat, fuego en los barriles
## y moscas zumbando. Separado de RooftopView para que lo estático no se redibuje cada frame.

const FIRE_OUTER := Color("ff5a1a")
const FIRE_INNER := Color("ffd400")
const MAX_FLY_ANCHORS := 200

var _style: ArtStyle
var _beacons := PackedVector2Array()
var _fires: Array[Rect2] = []
var _fly_anchors := PackedVector2Array()
var _fly_phases := PackedFloat32Array()
## Marca que atrae cada grupo de moscas (o -1 para barriles) y su peso, para mostrar
## solo las moscas de marcas que el estilo actual hace visibles.
var _fly_kinds := PackedInt32Array()
var _fly_weights := PackedFloat32Array()


func setup(data: AzoteaMapData, style: ArtStyle) -> void:
	_style = style
	_beacons.clear()
	_fires.clear()
	_fly_anchors.clear()
	_fly_phases.clear()
	_fly_kinds.clear()
	_fly_weights.clear()
	for prop in data.props:
		match prop.type:
			AzoteaMapData.Prop.Type.ANTENNA:
				_beacons.append(Vector2(prop.rect.get_center().x, prop.rect.position.y))
			AzoteaMapData.Prop.Type.BILLBOARD:
				_beacons.append(prop.rect.position + Vector2(10.0, 0.0))
				_beacons.append(Vector2(prop.rect.end.x - 10.0, prop.rect.position.y))
			AzoteaMapData.Prop.Type.BARREL:
				_fires.append(prop.rect)
				_add_fly_anchor(prop.rect.get_center() - Vector2(0.0, 50.0), prop.variant, -1, 0.0)
	for mark in data.marks:
		match mark.type:
			AzoteaMapData.Mark.Type.BLOOD, AzoteaMapData.Mark.Type.BONES, AzoteaMapData.Mark.Type.RUBBLE:
				_add_fly_anchor(mark.position + Vector2(0.0, -20.0), mark.variant, mark.type, mark.weight)
	queue_redraw()


func _add_fly_anchor(point: Vector2, variant: int, kind: int, weight: float) -> void:
	if _fly_anchors.size() < MAX_FLY_ANCHORS:
		_fly_anchors.append(point)
		_fly_phases.append(float(variant % 1000))
		_fly_kinds.append(kind)
		_fly_weights.append(weight)


func _anchor_visible(index: int) -> bool:
	match _fly_kinds[index]:
		AzoteaMapData.Mark.Type.BLOOD:
			return _fly_weights[index] < _style.blood_amount
		AzoteaMapData.Mark.Type.BONES:
			return _fly_weights[index] < _style.bones_amount
		AzoteaMapData.Mark.Type.RUBBLE:
			return _fly_weights[index] < _style.rubble_amount
	return true


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if _style == null:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 if Engine.is_editor_hint() else Conductor.pulse(5.0)
	var beacon := _style.blood.lightened(0.35)
	for point in _beacons:
		draw_circle(point, 14.0 * pulse, Color(beacon, 0.35 * pulse))
		draw_circle(point, 5.0, beacon.lerp(Color.WHITE, pulse * 0.6))
	if _style.fires > 0.0:
		for barrel in _fires:
			_draw_fire(barrel, time, pulse)
	if _style.flies > 0.0:
		_draw_flies(time)


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


## Moscas: puntos con alas que orbitan de forma errática alrededor de cada ancla.
func _draw_flies(time: float) -> void:
	var per_anchor := maxi(1, roundi(_style.flies * 4.0))
	for a in _fly_anchors.size():
		if not _anchor_visible(a):
			continue
		var anchor := _fly_anchors[a]
		var phase := _fly_phases[a]
		for f in per_anchor:
			var fly_seed := phase + f * 17.3
			var radius := 14.0 + fmod(fly_seed * 7.1, 18.0)
			var pos := anchor + Vector2(sin(time * (5.0 + fmod(fly_seed, 3.0)) + fly_seed) * radius,
					cos(time * (7.0 + fmod(fly_seed, 2.0)) + fly_seed * 1.7) * radius * 0.6)
			var wing := 0.5 + 0.5 * sin(time * 60.0 + fly_seed)
			draw_circle(pos + Vector2(0.0, -2.0), 2.2, Color(_style.edge, 0.35 * wing))
			draw_circle(pos, 2.4, _style.outline)
