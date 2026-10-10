shader_type canvas_item;
// Desvanece la parte de abajo de la imagen (el corte de un busto) hacia transparente.
// COLOR ya trae el color de la textura: solo se toca la opacidad.

uniform float fade_from : hint_range(0.0, 1.0) = 0.72;
uniform float fade_to : hint_range(0.0, 1.0) = 0.97;

void fragment() {
	COLOR.a *= 1.0 - smoothstep(fade_from, fade_to, UV.y);
}
