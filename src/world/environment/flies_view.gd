@tool
class_name FliesView
extends Node2D
## Moscas que orbitan de forma errática alrededor de anclas (sangre, huesos, escombros, basura).
## Cada ancla recuerda qué marca la atrae: solo hay moscas donde el estilo muestra esa marca.

const MAX_ANCHORS := 200

var _style: ArtStyle
var _anchors := PackedVector2Array()
var _phases := PackedFloat32Array()
## Tipo de MapMark que atrae a cada grupo (-1 = siempre visible) y su peso.
var _kinds := PackedInt32Array()
var _weights := PackedFloat32Array()


func setup(style: ArtStyle) -> void:
	_style = style
	_anchors.clear()
	_phases.clear()
	_kinds.clear()
	_weights.clear()


func add_anchor(point: Vector2, variant: int, kind: int = -1, weight: float = 0.0) -> void:
	if _anchors.size() < MAX_ANCHORS:
		_anchors.append(point)
		_phases.append(float(variant % 1000))
		_kinds.append(kind)
		_weights.append(weight)


## Agrega como anclas las marcas que atraen moscas.
func add_marks(marks: Array[MapMark]) -> void:
	for mark in marks:
		if mark.type in [MapMark.Type.BLOOD, MapMark.Type.BONES, MapMark.Type.RUBBLE]:
			add_anchor(mark.position + Vector2(0.0, -20.0), mark.variant, mark.type, mark.weight)


func _visible_anchor(index: int) -> bool:
	match _kinds[index]:
		MapMark.Type.BLOOD:
			return _weights[index] < _style.blood_amount
		MapMark.Type.BONES:
			return _weights[index] < _style.bones_amount
		MapMark.Type.RUBBLE:
			return _weights[index] < _style.rubble_amount
	return true


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and _style != null and _style.flies > 0.0:
		queue_redraw()


func _draw() -> void:
	if _style == null or _style.flies <= 0.0:
		return
	var time := Time.get_ticks_msec() / 1000.0
	var per_anchor := maxi(1, roundi(_style.flies * 4.0))
	for a in _anchors.size():
		if not _visible_anchor(a):
			continue
		for f in per_anchor:
			var fly_seed := _phases[a] + f * 17.3
			var radius := 14.0 + fmod(fly_seed * 7.1, 18.0)
			var pos := _anchors[a] + Vector2(sin(time * (5.0 + fmod(fly_seed, 3.0)) + fly_seed) * radius,
					cos(time * (7.0 + fmod(fly_seed, 2.0)) + fly_seed * 1.7) * radius * 0.6)
			var wing := 0.5 + 0.5 * sin(time * 60.0 + fly_seed)
			draw_circle(pos + Vector2(0.0, -2.0), 2.2, Color(_style.edge, 0.35 * wing))
			draw_circle(pos, 2.4, _style.outline)
