// BLOCKMANIA mood layer (original shader). A transparent full-screen overlay that only paints
// the screen's edges, so the board and text in the middle stay untouched:
//   boss     - hazard tape (diagonal stripes) crawling along the border plus a red glow
//   danger   - a red vignette that throbs with the heartbeat (set by script each frame)
//   heat     - rising heat haze and embers along the bottom edge (Heat 3+, act 3)
//   flash    - a full-screen color flash for slams (fades by script)
// Presentation only; the Screen Effects setting scales `strength` (0 turns it off).
shader_type canvas_item;

uniform float boss = 0.0;
uniform vec4 boss_col : source_color = vec4(0.92, 0.16, 0.26, 1.0);
uniform float danger = 0.0;
uniform float beat = 0.0;
uniform float heat = 0.0;
uniform vec4 heat_col : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float flash = 0.0;
uniform vec4 flash_col : source_color = vec4(1.0, 0.3, 0.35, 1.0);
uniform float strength = 1.0;
uniform float time_scale = 1.0;
uniform float pixel_size = 4.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy / pixel_size) * pixel_size;
	vec2 uv = px / res;
	float t = TIME * time_scale;
	// Distance to the nearest screen edge in pixels.
	float edge = min(min(px.x, res.x - px.x), min(px.y, res.y - px.y));
	vec4 col = vec4(0.0);

	// Boss: a 22-px hazard tape frame whose stripes crawl, and a soft red glow inside it.
	if (boss > 0.0) {
		float band = 22.0;
		if (edge < band) {
			float s = step(0.5, fract((px.x + px.y) / 36.0 - t * 0.6));
			vec3 tape = mix(vec3(0.07, 0.03, 0.08), boss_col.rgb, s);
			col = vec4(tape, 0.9 * boss);
		} else {
			float glow = exp(-(edge - band) / 90.0) * (0.35 + 0.15 * sin(t * 2.4));
			col = vec4(boss_col.rgb, glow * boss * 0.55);
		}
	}

	// Danger: a vignette that throbs with the heartbeat.
	if (danger > 0.0) {
		vec2 c = uv - 0.5;
		float v = smoothstep(0.32, 0.75, length(c * vec2(1.0, 0.85)));
		float a = v * danger * (0.22 + 0.33 * beat);
		col.rgb = mix(col.rgb, vec3(0.75, 0.05, 0.12), a / max(0.001, col.a + a));
		col.a = max(col.a, a);
	}

	// Heat: haze and embers rising from the bottom edge.
	if (heat > 0.0) {
		float y = 1.0 - uv.y;
		float haze = smoothstep(0.28, 0.0, y) * (0.18 + 0.08 * sin(uv.x * 30.0 + t * 3.0 + y * 40.0));
		vec2 cell = floor(vec2(px.x / 10.0, (px.y + t * 60.0) / 10.0));
		float ember = step(0.996, hash(cell)) * smoothstep(0.45, 0.0, y);
		float a = (haze + ember * 0.9) * heat;
		col.rgb = mix(col.rgb, mix(heat_col.rgb, vec3(1.0, 0.85, 0.4), ember), a / max(0.001, col.a + a));
		col.a = max(col.a, a);
	}

	// Flash: a quick full-screen tint.
	if (flash > 0.0) {
		col.rgb = mix(col.rgb, flash_col.rgb, flash / max(0.001, col.a + flash));
		col.a = max(col.a, flash * 0.55);
	}
	col.a *= strength;
	COLOR = col;
}
