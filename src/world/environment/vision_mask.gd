class_name VisionMask
extends Node2D
## Oscurece todo menos un rectángulo del mundo (la habitación actual o la cabina del ascensor).
## Se interpola suavemente entre rectángulos; con `strength` 0 no dibuja nada.

const FAR := 20000.0
const FEATHER := 60.0

var color := Color(0.02, 0.02, 0.04, 1.0)
var target := Rect2()
var strength_target := 0.0

var _rect := Rect2()
var _strength := 0.0


func show_only(rect: Rect2, instant := false) -> void:
	target = rect
	strength_target = 1.0
	if instant or _strength <= 0.01:
		_rect = rect


func clear() -> void:
	strength_target = 0.0


func _process(delta: float) -> void:
	_strength = move_toward(_strength, strength_target, delta * 6.0)
	var weight := clampf(delta * 12.0, 0.0, 1.0)
	_rect = Rect2(_rect.position.lerp(target.position, weight), _rect.size.lerp(target.size, weight))
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.0:
		return
	var c := Color(color, _strength)
	var r := _rect
	draw_rect(Rect2(-FAR, -FAR, FAR * 2.0, r.position.y + FAR), c)
	draw_rect(Rect2(-FAR, r.end.y, FAR * 2.0, FAR), c)
	draw_rect(Rect2(-FAR, r.position.y, r.position.x + FAR, r.size.y), c)
	draw_rect(Rect2(r.end.x, r.position.y, FAR, r.size.y), c)
	# Borde difuso hacia adentro.
	for k in 4:
		var inset := FEATHER * (k + 1) / 4.0
		draw_rect(r.grow(-inset + FEATHER * 0.25), Color(color, _strength * 0.12), false, FEATHER / 4.0)
