shader_type canvas_item;
// Cielo procedural: degradado, sol que late, estrellas, nubes, cordilleras,
// agua con reflejo y nieve/ceniza. Las medidas viven en una rejilla de
// `pixel_resolution` columnas; con `pixelate` se ve en pixel-art con dithering,
// sin él se dibuja suave a resolución completa.

uniform bool pixelate = false;
uniform int pixel_resolution = 320;
uniform float star_density : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.25;
uniform int mountain_layers : hint_range(0, 6) = 0;
uniform float sun_position : hint_range(0.0, 1.0) = 0.72;
uniform float sun_elevation : hint_range(0.0, 1.0) = 0.45;
uniform float sun_size = 30.0;
uniform float horizon_line : hint_range(0.0, 1.0) = 0.82;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.6;
uniform float snowfall : hint_range(0.0, 1.0) = 0.06;
uniform vec4 sky_apex : source_color = vec4(0.769, 0.071, 0.106, 1.0);
uniform vec4 horizon_glow : source_color = vec4(0.910, 0.149, 0.173, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.690, 0.541, 1.0);
uniform vec4 water_color : source_color = vec4(0.169, 0.165, 0.271, 1.0);
uniform vec4 land_color : source_color = vec4(0.431, 0.165, 0.208, 1.0);
uniform float beat_flash : hint_range(0.0, 1.0) = 0.5;
uniform float sun_beat_pulse : hint_range(0.0, 1.0) = 0.6;
// Los alimenta el script desde el Conductor y el combo (0..1).
uniform float beat_pulse = 0.0;
uniform float combo_heat = 0.0;

const float BANDS = 7.0;

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

// Matriz de Bayer 4x4 calculada aritméticamente (0..1).
float bayer2(vec2 a) {
	a = floor(a);
	return fract(a.x / 2.0 + a.y * a.y * 0.75);
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

// Cuantiza a BANDS niveles; el umbral de Bayer decide el pixel en las fronteras.
// En modo suave devuelve el valor continuo.
float dq(float v, float threshold) {
	if (!pixelate) {
		return clamp(v, 0.0, 1.0);
	}
	return clamp(floor(v * BANDS + (threshold - 0.5) * dither_strength + 0.5) / BANDS, 0.0, 1.0);
}

void fragment() {
	float columns = float(pixel_resolution);
	vec2 res = vec2(columns, floor(columns * SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y));
	vec2 p = pixelate ? floor(UV * res) : UV * res;
	// En modo suave, los elementos puntuales (estrellas, copos) se dibujan como discos.
	vec2 cell_uv = fract(p) - 0.5;
	float dot_mask = pixelate ? 1.0 : smoothstep(0.5, 0.15, length(cell_uv));
	vec2 uv = (p + 0.5) / res;
	float threshold = bayer4(p);
	float horizon = horizon_line * res.y;
	float pulse = beat_pulse;

	vec2 sun_center = vec2(sun_position * res.x, horizon - sun_elevation * horizon);
	float radius = sun_size * (1.0 + sun_beat_pulse * pulse * 0.35 + combo_heat * 0.3);
	float sun_dist = length(p - sun_center);
	vec3 col;

	if (p.y < horizon) {
		float t = p.y / max(horizon, 1.0);
		col = mix(sky_apex.rgb, horizon_glow.rgb, dq(pow(t, 1.6), threshold));

		// Estrellas: más densas arriba, titilan y se encienden en el beat.
		vec2 cell = floor(p);
		float star = step(1.0 - star_density * 0.03, hash(cell)) * step(0.12, 1.0 - t) * dot_mask;
		float twinkle = max(0.5 + 0.5 * sin(TIME * 3.0 + hash(cell + 7.0) * 40.0), pulse);
		col = mix(col, sun_color.rgb, star * twinkle * (1.0 - t));

		// Halo y disco del sol, con cortes horizontales en la mitad inferior.
		if (sun_size > 0.0) {
			float halo = clamp(1.0 - (sun_dist - radius) / (radius * 2.5), 0.0, 1.0);
			halo *= 0.55 + 0.45 * max(pulse * sun_beat_pulse, combo_heat);
			col = mix(col, mix(horizon_glow.rgb, sun_color.rgb, 0.5), dq(halo, threshold) * 0.7);
			if (sun_dist < radius) {
				float rel = (p.y - sun_center.y) / radius;
				float cut = rel > 0.15 ? step(mod(p.y, 4.0), rel * 2.4 - 0.3) : 0.0;
				col = mix(sun_color.rgb, col, cut);
			}
		}

		// Nubes: fbm estirado en x, a la deriva, iluminadas según cercanía al sol.
		if (cloud_coverage > 0.0) {
			float c = fbm(vec2(p.x + TIME * 2.0, p.y * 2.2) * 0.035 + 3.0);
			c *= smoothstep(0.08, 0.35, t) * smoothstep(1.0, 0.7, t);
			float edge = c - (0.72 - 0.4 * cloud_coverage);
			float cover = pixelate ? step(0.0, edge + (threshold - 0.5) * 0.06 * dither_strength)
					: smoothstep(0.0, 0.02, edge);
			float lit = clamp(1.0 - sun_dist / (res.x * 0.6), 0.0, 1.0);
			vec3 shade = mix(sky_apex.rgb, land_color.rgb, 0.45);
			col = mix(col, mix(shade, horizon_glow.rgb, dq(lit * 0.75 + t * 0.25, threshold)), cover);
		}

		// Cordilleras: la capa 0 es la más lejana (más alta y con más bruma).
		for (int i = 0; i < 6; i++) {
			if (i >= mountain_layers) {
				break;
			}
			float fi = float(i);
			float depth = 1.0 - fi / float(mountain_layers);
			float amp = res.y * (0.05 + 0.09 * depth);
			float ridge = horizon - amp * (0.3 + fbm(vec2(p.x * (0.01 + 0.006 * fi) + fi * 17.3, fi * 3.1)));
			if (p.y >= ridge) {
				col = mix(land_color.rgb, horizon_glow.rgb, dq(depth * 0.55, threshold));
			}
		}
	} else {
		// Agua: refleja el resplandor cerca del horizonte y la columna del sol.
		float t = (p.y - horizon) / max(res.y - horizon, 1.0);
		col = mix(water_color.rgb, horizon_glow.rgb, dq((1.0 - t) * (1.0 - t) * 0.6, threshold));
		float wave = sin(p.y * 0.9 + TIME * 2.0) * 1.5 + sin(p.y * 0.37 - TIME * 1.3);
		float column = abs(p.x + wave - sun_center.x);
		float scan = step(mod(p.y + floor(TIME * 6.0), 3.0), 1.0);
		if (sun_size > 0.0 && column < radius * (1.1 - t * 0.6) && scan > 0.0) {
			col = mix(col, sun_color.rgb, 0.85 * (1.0 - t));
		}
		col = mix(col, sun_color.rgb, step(0.996, hash(floor(p) + floor(TIME * 4.0))) * 0.6 * dot_mask);
	}

	// Nieve / ceniza en dos planos de profundidad.
	for (int k = 0; k < 2; k++) {
		float fk = float(k);
		float cell = 6.0 + fk * 3.0;
		vec2 q = p + vec2(sin(TIME * 0.8 + p.y * 0.05 + fk) * 1.5, -TIME * (6.0 + fk * 5.0));
		vec2 id = floor(q / cell);
		vec2 f = mod(q, cell);
		vec2 flake = floor(vec2(hash(id + fk * 31.0), hash(id + 5.3)) * (cell - 1.0));
		bool hit = f.x >= flake.x && f.x < flake.x + 1.0 && f.y >= flake.y && f.y < flake.y + 1.0;
		if (hit && hash(id + 11.7 * fk) < snowfall) {
			col = mix(col, vec3(1.0), 0.85 * (pixelate ? 1.0 : smoothstep(0.5, 0.2, length(f - flake - 0.5))));
		}
	}

	// Viñeta que respira con el beat y destello de color.
	vec2 centered = (uv - vec2(0.5, 0.45)) * vec2(1.6, 1.0);
	float vignette = smoothstep(0.55 - pulse * beat_flash * 0.15, 1.15, length(centered));
	col = mix(col, col * 0.55, vignette);
	col += horizon_glow.rgb * pulse * beat_flash * (0.08 + combo_heat * 0.12);
	COLOR = vec4(col, 1.0);
}
