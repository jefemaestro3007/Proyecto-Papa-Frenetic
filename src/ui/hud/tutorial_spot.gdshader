shader_type canvas_item;
// Fondo del diálogo del tutorial: oscurece la pantalla salvo un círculo (el foco) alrededor de lo
// que se está explicando, p. ej. la papa bomba del HUD. Sin foco, oscurece parejo.

uniform float darkness = 0.9;
// Tamaño del rectángulo en píxeles y centro y radio del foco en esos píxeles (radio 0 = sin foco).
uniform vec2 size_px = vec2(1.0);
uniform vec2 hole_center = vec2(0.0);
uniform float hole_radius = 0.0;

void fragment() {
	float d = distance(UV * size_px, hole_center);
	float open = hole_radius > 0.0 ? 1.0 - smoothstep(hole_radius, hole_radius + 28.0, d) : 0.0;
	COLOR = vec4(0.0, 0.0, 0.0, darkness * (1.0 - open));
}
