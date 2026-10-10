shader_type canvas_item;
// Textura "sucia" para siluetas planas: manchas fbm + motas + semitono.
// Se ancla a coordenadas locales para que no "nade" con el parallax.

uniform float dirt = 0.35;
uniform float speckle = 0.25;
uniform float halftone_size = 7.0;
uniform float halftone_strength = 0.18;

varying vec2 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		sum += value_noise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float n = fbm(local_pos * 0.012);
	vec3 col = COLOR.rgb * (1.0 - dirt * 0.5 + dirt * n);
	float speck = step(0.9, hash(floor(local_pos / 3.0)));
	col = mix(col, col * 0.6, speck * speckle);
	vec2 cell = mod(local_pos, halftone_size) - halftone_size * 0.5;
	float dot_mask = step(length(cell) / (halftone_size * 0.5), n * 1.1);
	col = mix(col, col * 0.8, dot_mask * halftone_strength);
	COLOR = vec4(col, COLOR.a);
}
