// BLOCKMANIA backdrop: slowly swirling enamel "paint" (original shader).
// Domain-warped value noise inside a polar swirl, posterized into a small palette with
// ordered (Bayer 4x4) dithering on a coarse pixel grid for a hand-made retro look.
shader_type canvas_item;

uniform vec4 col_deep : source_color = vec4(0.078, 0.047, 0.141, 1.0);
uniform vec4 col_mid : source_color = vec4(0.231, 0.114, 0.318, 1.0);
uniform vec4 col_teal : source_color = vec4(0.043, 0.302, 0.341, 1.0);
uniform vec4 col_hot : source_color = vec4(0.580, 0.176, 0.439, 1.0);
uniform vec4 col_glint : source_color = vec4(1.0, 0.72, 0.30, 1.0);
uniform float pixel_size = 6.0;      // screen pixels per backdrop pixel
uniform float speed = 0.05;
uniform float swirl = 2.4;
uniform float pulse = 0.0;           // 0..1, set by gameplay (big clears)
uniform vec2 focus = vec2(0.5, 0.5); // 0..1 screen position that bends the swirl
uniform float time_scale = 1.0;      // 0 under reduced motion

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int idx = x + y * 4;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[idx]) + 0.5) / 16.0;
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / pixel_size);
	vec2 uv = cell * pixel_size / res;
	float aspect = res.x / res.y;
	float t = TIME * speed * time_scale;

	vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
	vec2 f = (focus - 0.5) * vec2(aspect, 1.0);
	p -= f * 0.15;
	float r = length(p);
	float ang = atan(p.y, p.x) + swirl * exp(-r * 1.6) + t * 1.3 + pulse * 0.6;
	p = vec2(cos(ang), sin(ang)) * r;

	vec2 q = vec2(fbm(p * 2.2 + vec2(t, -t * 0.7)), fbm(p * 2.2 + vec2(-t * 0.8, t) + 5.2));
	vec2 w = vec2(fbm(p * 1.7 + q * 2.6 + vec2(1.7, 9.2) + t * 0.6), fbm(p * 1.7 + q * 2.6 + vec2(8.3, 2.8) - t * 0.5));
	float n = fbm(p * 1.4 + w * 3.0);
	n = clamp(n * 1.25 - 0.1 + pulse * 0.12, 0.0, 1.0);

	// Posterize with ordered dithering: 5 bands.
	float d = bayer4(cell) - 0.5;
	float level = clamp(floor(n * 5.0 + d * 0.9), 0.0, 4.0);
	vec3 col;
	if (level < 1.0) col = col_deep.rgb;
	else if (level < 2.0) col = mix(col_deep.rgb, col_mid.rgb, 0.6);
	else if (level < 3.0) col = col_mid.rgb;
	else if (level < 4.0) col = mix(col_teal.rgb, col_hot.rgb, smoothstep(0.3, 0.7, w.x));
	else col = mix(col_hot.rgb, col_glint.rgb, 0.35 + pulse * 0.4);

	// Soft vignette toward the edges, keeps the centre calm behind the board.
	float vig = smoothstep(1.15, 0.35, length((uv - 0.5) * vec2(aspect * 0.8, 1.0)));
	col *= mix(0.55, 1.0, vig);
	COLOR = vec4(col, 1.0);
}
