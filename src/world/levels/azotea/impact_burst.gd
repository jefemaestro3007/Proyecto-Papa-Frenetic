class_name ImpactBurst
extends Node2D
## Estallido amarillo de rayos dentados con contorno negro; se expande y se borra solo.

const LIFETIME := 0.28

var _rays: Array[PackedVector2Array] = []
var _age := 0.0


func _init(rng: RandomNumberGenerator, strength: float) -> void:
	var count := rng.randi_range(10, 16)
	for i in count:
		# Abanico hacia arriba: el golpe viene del suelo.
		var angle := lerpf(PI * 1.05, PI * 1.95, (i + rng.randf_range(-0.3, 0.3)) / (count - 1))
		var length := rng.randf_range(80.0, 190.0) * strength
		var width := rng.randf_range(16.0, 30.0)
		var dir := Vector2.from_angle(angle)
		var side := dir.orthogonal()
		var start := dir * rng.randf_range(10.0, 30.0)
		var mid := start + dir * length * 0.55 + side * rng.randf_range(-6.0, 6.0)
		_rays.append(PackedVector2Array([
			start + side * width * 0.5, mid + side * width * 0.35,
			start + dir * length, mid - side * width * 0.35, start - side * width * 0.5]))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var t := _age / LIFETIME
	scale = Vector2.ONE * lerpf(0.6, 1.25, ease(t, 0.4))
	modulate.a = 1.0 - ease(t, 3.0)
	queue_redraw()


func _draw() -> void:
	for ray in _rays:
		draw_colored_polygon(ray, FreneticPalette.YELLOW)
		var closed := ray.duplicate()
		closed.append(ray[0])
		draw_polyline(closed, FreneticPalette.INK, 4.0)
