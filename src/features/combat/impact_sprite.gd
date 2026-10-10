class_name ImpactSprite
extends Node2D
## Efecto de un solo dibujo (p. ej. la nube del stomp): aparece con un golpe de escala, crece un
## poco y se desvanece. El ancla es el centro del borde inferior de la textura (los pies).

const LIFETIME := 0.55
## Las texturas de efectos están al doble de resolución.
const TEXTURE_SCALE := 0.5

var _texture: Texture2D
var _strength := 1.0
var _age := 0.0


func _init(texture: Texture2D, strength: float = 1.0) -> void:
	_texture = texture
	_strength = strength


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var grow := lerpf(0.7, 1.15, ease(t, 0.3)) * _strength
	var size := _texture.get_size() * TEXTURE_SCALE * Vector2(grow, lerpf(1.2, 0.9, t) * grow)
	draw_texture_rect(_texture, Rect2(Vector2(-size.x * 0.5, -size.y), size), false,
			Color(1.0, 1.0, 1.0, 1.0 - ease(t, 2.5)))
