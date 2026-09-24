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
uniform float pixel_size = 4.0; // in 1920x1080 stage pixels; scaled to the window below

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	// The UI is a 1920x1080 stage scaled by `sc` and centered; `off` is the letterbox space
	// around it on each axis (window pixels). Everything below is sized in stage pixels, so the
	// frame looks the same at 720p, 1080p, 1440p, 16:10 and ultrawide.
	float sc = min(res.x / 1920.0, res.y / 1080.0);
	vec2 off = max(vec2(0.0), (res - vec2(1920.0, 1080.0) * sc) * 0.5);
	float ps = max(1.0, floor(pixel_size * sc + 0.5));
	vec2 px = floor(FRAGCOORD.xy / ps) * ps;
	vec2 uv = px / res;
	float t = TIME * time_scale;
	vec2 d = min(px, res - px); // distance to the left/right and top/bottom window edges
	// Distance to the nearest screen edge in pixels.
	float edge = min(d.x, d.y);
	vec4 col = vec4(0.0);

	// Boss: hazard tape whose stripes crawl, and a soft red glow inside it. On the playfield the
	// tape is only 7 stage px deep (clear of the HUD text at the stage's top edge); where the
	// window has letterbox space it widens into it, up to 22 stage px.
	if (boss > 0.0) {
		vec2 band = clamp(off, vec2(7.0 * sc), vec2(22.0 * sc));
		band = max(vec2(ps), floor(band / ps) * ps);
		if (d.x < band.x || d.y < band.y) {
			float s = step(0.5, fract((px.x + px.y) / (36.0 * sc) - t * 0.6));
			vec3 tape = mix(vec3(0.07, 0.03, 0.08), boss_col.rgb, s);
			col = vec4(tape, 0.9 * boss);
		} else {
			float inside = min(d.x - band.x, d.y - band.y);
			float glow = exp(-inside / (70.0 * sc)) * (0.3 + 0.12 * sin(t * 2.4));
			col = vec4(boss_col.rgb, glow * boss * 0.45);
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
		vec2 cell = floor(vec2(px.x / (10.0 * sc), (px.y + t * 60.0 * sc) / (10.0 * sc)));
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
