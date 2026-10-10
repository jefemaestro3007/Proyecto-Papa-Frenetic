class_name ImpactBurst
extends Node2D
## Impacto de caída: abanico de rayos dentados con contorno + escombros con gravedad.
## Toda la forma sale de ImpactFxParams y escala con `strength`; se borra sola.

var _fx: ImpactFxParams
var _rays: Array[PackedVector2Array] = []
var _debris_pos := PackedVector2Array()
var _debris_vel := PackedVector2Array()
var _debris_size := PackedFloat32Array()
var _debris_color := PackedColorArray()
var _age := 0.0


func _init(rng: RandomNumberGenerator, strength: float, fx: ImpactFxParams) -> void:
	_fx = fx
	var spread := deg_to_rad(fx.spread_degrees)
	var start_angle := -PI * 0.5 - spread * 0.5
	var count := rng.randi_range(fx.ray_count_min, maxi(fx.ray_count_min, fx.ray_count_max))
	for i in count:
		var t := (i + rng.randf_range(-0.3, 0.3)) / maxf(count - 1, 1)
		var dir := Vector2.from_angle(start_angle + spread * t)
		var side := dir.orthogonal()
		var length := rng.randf_range(fx.ray_length_min, maxf(fx.ray_length_min, fx.ray_length_max)) * strength
		var width := rng.randf_range(fx.ray_width_min, maxf(fx.ray_width_min, fx.ray_width_max))
		var start := dir * rng.randf_range(10.0, 30.0)
		var mid := start + dir * length * 0.55 + side * rng.randf_range(-fx.jaggedness, fx.jaggedness)
		_rays.append(PackedVector2Array([
			start + side * width * 0.5, mid + side * width * 0.35,
			start + dir * length, mid - side * width * 0.35, start - side * width * 0.5]))

	var debris := roundi(fx.debris_count * clampf(strength, 0.0, 2.0))
	for i in debris:
		var angle := start_angle + spread * rng.randf()
		var speed := rng.randf_range(fx.debris_speed_min, maxf(fx.debris_speed_min, fx.debris_speed_max))
		_debris_pos.append(Vector2(rng.randf_range(-12.0, 12.0), -4.0))
		_debris_vel.append(Vector2.from_angle(angle) * speed * sqrt(strength))
		_debris_size.append(rng.randf_range(fx.debris_size_min, maxf(fx.debris_size_min, fx.debris_size_max)))
		_debris_color.append(fx.debris_color if rng.randf() < 0.6 else fx.debris_color_alt)


func _process(delta: float) -> void:
	_age += delta
	if _age >= maxf(_fx.ray_lifetime, _fx.debris_lifetime):
		queue_free()
		return
	for i in _debris_pos.size():
		var velocity := _debris_vel[i] + Vector2(0.0, _fx.debris_gravity * delta)
		_debris_vel[i] = velocity
		_debris_pos[i] += velocity * delta
	queue_redraw()


func _draw() -> void:
	if _age < _fx.ray_lifetime:
		var t := _age / _fx.ray_lifetime
		var s := lerpf(_fx.scale_start, _fx.scale_end, ease(t, 0.4))
		var alpha := 1.0 - ease(t, 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		for ray in _rays:
			draw_colored_polygon(ray, Color(_fx.fill_color, alpha))
			if _fx.outline_width > 0.0:
				var closed := ray.duplicate()
				closed.append(ray[0])
				draw_polyline(closed, Color(_fx.outline_color, alpha), _fx.outline_width)
		draw_set_transform(Vector2.ZERO)

	var debris_alpha := 1.0 - ease(clampf(_age / _fx.debris_lifetime, 0.0, 1.0), 2.0)
	for i in _debris_pos.size():
		var size := _debris_size[i]
		var rect := Rect2(_debris_pos[i] - Vector2.ONE * size * 0.5, Vector2.ONE * size)
		draw_rect(rect, Color(_debris_color[i], debris_alpha))
		if _fx.outline_width > 0.0:
			draw_rect(rect, Color(_fx.outline_color, debris_alpha), false, 2.0)
