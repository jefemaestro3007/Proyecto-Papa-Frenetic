@tool
class_name DepthPlane
extends Node2D
## Plano a una profundidad fija `depth` (Perspectiva de Oferta): proyectar todo un plano hacia el
## punto de fuga es solo escalarlo `1 − depth` alrededor de ese punto. Lo que cuelga de este nodo se
## dibuja una vez en coordenadas del plano jugable (estático, en trozos con ChunkedView) y en cada
## frame solo cambia la transformación: la pared del fondo, el frente de las góndolas y el de los
## freezers no se redibujan aunque la cámara se mueva.

var depth := 0.45


func _init(p_depth := 0.45) -> void:
	depth = p_depth


func _process(_delta: float) -> void:
	_follow()


func _enter_tree() -> void:
	_follow()


## vp + (p − vp)·(1 − d) = p·(1 − d) + vp·d
func _follow() -> void:
	var parent := get_parent() as CanvasItem
	if parent == null:
		return
	var screen := SpatialIndex.screen_rect(parent, 120.0)
	if screen.size.x > 1e6:
		screen = Rect2(-200.0, -900.0, 2400.0, 1200.0)
	var vp := screen.get_center()
	position = vp * depth
	scale = Vector2.ONE * (1.0 - depth)
