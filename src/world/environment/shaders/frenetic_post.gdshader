shader_type canvas_item;
// Post-proceso de pantalla: aberración cromática + líneas de glitch que se disparan con `shock`.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float aberration = 1.5;
// 0..1, lo sube el script en cada impacto y decae solo.
uniform float shock = 0.0;

float hash(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Bandas horizontales desplazadas durante el impacto.
	float band = floor(uv.y * 40.0);
	float jitter = step(1.0 - shock * 0.5, hash(band + floor(TIME * 30.0))) * (hash(band) - 0.5);
	uv.x += jitter * 0.04 * shock;

	vec2 offset = vec2(aberration + shock * 10.0, 0.0) * SCREEN_PIXEL_SIZE;
	float r = texture(screen_tex, uv + offset).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - offset).b;
	COLOR = vec4(r, g, b, 1.0);
}
