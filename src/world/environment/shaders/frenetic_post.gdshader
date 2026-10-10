shader_type canvas_item;
// Post-proceso de pantalla del ArtStyle: pixelado, paleta reducida con dithering,
// gradación (desaturar + tinte), viñeta, foco de luz, haz de luz, grano,
// aberración cromática y glitch de impacto (`shock`).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float pixel_size = 1.0;
uniform float color_levels = 0.0;
uniform float dither = 0.0;
uniform float vignette = 0.0;
uniform float vignette_softness = 0.5;
uniform float desaturate = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float grain = 0.0;
uniform float aberration = 1.5;
uniform float spotlight = 0.0;
uniform float spotlight_radius = 0.6;
uniform float light_shaft = 0.0;
// Los alimenta el script en cada frame.
uniform vec2 spotlight_center = vec2(0.5);
uniform float shock = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float x) {
	return fract(sin(x * 91.345) * 47453.5453);
}

float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	float cell = max(pixel_size, 1.0);
	vec2 art_px = floor(SCREEN_UV * screen_px / cell);
	vec2 uv = (art_px + 0.5) * cell / screen_px;

	// Bandas horizontales desplazadas durante el impacto.
	float band = floor(uv.y * 40.0);
	float jitter = step(1.0 - shock * 0.5, hash1(band + floor(TIME * 30.0))) * (hash1(band) - 0.5);
	uv.x += jitter * 0.04 * shock;

	vec2 offset = vec2((aberration + shock * 10.0) * cell, 0.0) * SCREEN_PIXEL_SIZE;
	vec3 col = vec3(texture(screen_tex, uv + offset).r, texture(screen_tex, uv).g,
			texture(screen_tex, uv - offset).b);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturate) * tint.rgb;

	vec2 aspect = vec2(screen_px.x / screen_px.y, 1.0);
	float edge = length((uv - 0.5) * aspect);
	col *= 1.0 - vignette * smoothstep(mix(0.75, 0.2, vignette_softness), 1.0, edge);
	float spot = smoothstep(spotlight_radius, spotlight_radius * 0.3, length((uv - spotlight_center) * aspect));
	col *= mix(1.0, 0.3 + 0.85 * spot, spotlight);

	// Haz diagonal que entra desde arriba y se apaga hacia abajo.
	float beam = smoothstep(0.14, 0.0, abs(uv.x - 0.42 - uv.y * 0.22)) * (1.0 - uv.y);
	col += vec3(1.0, 0.88, 0.75) * beam * light_shaft * 0.22;

	col += (hash(art_px + floor(TIME * 24.0) * 13.0) - 0.5) * grain;

	if (color_levels > 1.0) {
		float steps = color_levels - 1.0;
		col = floor(col * steps + 0.5 + (bayer4(art_px) - 0.5) * dither) / steps;
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
