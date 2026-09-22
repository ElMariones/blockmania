// BLOCKMANIA CRT pass (post-process over the whole UI).
// Curvature + scanline darkening follow the owner-supplied reference; aberration, glow,
// vignette, grain, and a slow roll bar are original additions. All strengths are uniforms so
// the settings menu can turn the effect down or off. Mouse input is remapped with the same
// warp (see crt_layer.gd), so clicks line up with what is on screen.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float warp = 0.35;       // curvature (reference used 0.75)
uniform float scan = 0.30;       // scanline darkness (reference used 0.75)
uniform float aberration = 1.2;  // RGB split in pixels at the screen edge
uniform float glow = 0.22;       // soft bloom from a blurred mip
uniform float vignette = 0.35;
uniform float grain = 0.025;
uniform float roll = 0.04;       // slow rolling brightness bar
uniform float shock = 0.0;       // 0..1 impact pulse (extra aberration + brightness)
uniform vec4 bezel : source_color = vec4(0.03, 0.02, 0.05, 1.0);

vec2 curve(vec2 uv) {
	vec2 dc = abs(0.5 - uv);
	dc *= dc;
	uv.x -= 0.5; uv.x *= 1.0 + (dc.y * (0.3 * warp)); uv.x += 0.5;
	uv.y -= 0.5; uv.y *= 1.0 + (dc.x * (0.4 * warp)); uv.y += 0.5;
	return uv;
}

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = curve(SCREEN_UV);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = bezel;
	} else {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec2 fromc = uv - 0.5;
		float edge = dot(fromc, fromc) * 4.0;
		vec2 ab = fromc * px * (aberration * (0.6 + edge) + shock * 6.0);
		vec3 col;
		col.r = texture(screen_tex, uv + ab).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - ab).b;
		vec3 blur = textureLod(screen_tex, uv, 3.0).rgb;
		col += blur * glow;
		col *= 1.0 + shock * 0.25;
		float line = abs(sin(FRAGCOORD.y * 1.5708)) * 0.5 * scan;
		col = mix(col, vec3(0.0), line);
		float bar = smoothstep(0.0, 0.08, abs(fract(uv.y * 0.5 - TIME * 0.05) - 0.5) - 0.42);
		col *= 1.0 - roll * (1.0 - bar);
		col += (rand(uv * 431.0 + fract(TIME)) - 0.5) * grain;
		float vig = 1.0 - vignette * smoothstep(0.25, 0.95, length(fromc * vec2(1.1, 1.25)));
		col *= vig;
		COLOR = vec4(col, 1.0);
	}
}
