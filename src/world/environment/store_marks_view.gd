@tool
class_name StoreMarksView
extends StyledCanvas
## Marcas del piso de Bienestar U en el plano jugable: papeles, escombros, huesos y charcos de
## sangre. Cada estilo muestra la fracción que le corresponde (`MapMark.weight`); estático, en trozos
## (ChunkedView). Las moscas (FliesView) rondan las que el estilo muestra.

var _marks: Array[MapMark] = []


func setup(marks: Array[MapMark], style: ArtStyle) -> void:
	_marks = marks
	_style = style
	queue_redraw()


func _draw() -> void:
	if _style == null:
		return
	for mark in _marks:
		if _owns(mark.position):
			_draw_mark(mark)


func _draw_mark(mark: MapMark) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = mark.variant
	match mark.type:
		MapMark.Type.PAPERS:
			for i in rng.randi_range(3, 7):
				var center := mark.position + Vector2(rng.randf_range(-50.0, 50.0), -3.0 - rng.randf() * 4.0)
				draw_set_transform(center, rng.randf_range(-0.4, 0.4))
				draw_rect(Rect2(-13.0, -3.0, 26.0, 5.0), _style.paper)
				draw_rect(Rect2(-13.0, -3.0, 26.0, 5.0), _style.outline, false, 1.5)
				draw_set_transform(Vector2.ZERO)
		MapMark.Type.RUBBLE:
			if mark.weight < _style.rubble_amount:
				_draw_rubble(mark.position, mark.size * 0.8, rng)
		MapMark.Type.BONES:
			if mark.weight < _style.bones_amount:
				_draw_bones(mark.position, mark.size, rng)
		MapMark.Type.BLOOD:
			if mark.weight < _style.blood_amount:
				# Charco aplastado sobre el piso, con gotas alrededor.
				var radius := Vector2(56.0, 9.0) * mark.size
				_fill(_ellipse(mark.position + Vector2(0.0, -3.0), radius, 16, 0.25, rng), _style.blood)
				for d in rng.randi_range(3, 7):
					draw_circle(mark.position + Vector2(rng.randf_range(-1.6, 1.6) * radius.x, -rng.randf_range(1.0, 5.0)),
							rng.randf_range(2.0, 5.0), _style.blood)
