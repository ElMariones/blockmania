// BLOCKMANIA card effects (original shader). Set on a card and inherited by every part of it
// (use_parent_material), so each piece of the card is recolored as it is drawn:
//   negative - the card is drawn as a photographic negative (a Negative Joker takes no slot)
//   again    - the card turns red with a slow pulse (an AGAIN Joker triggers once more)
//   holo     - a chrome-foil rainbow sweeps across the bright parts (Holo shelf cards)
// Pixelated in stage pixels so the sheen keeps the kit's chunky look. `motion` 0 freezes it
// (Reduced Motion): the look, and the NEGATIVE / AGAIN / HOLO tags on the card, stay.
// Presentation only: nothing here reaches the rules.
shader_type canvas_item;

uniform bool negative = false;
uniform bool again = false;
uniform bool holo = false;
uniform float motion = 1.0;
uniform float pixel = 4.0;

vec3 rainbow(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = COLOR;
	vec2 p = floor(FRAGCOORD.xy / pixel) * pixel;
	float t = TIME * motion;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (negative) {
		c.rgb = vec3(1.0) - c.rgb;
		// A cold film cast keeps it from reading as a plain dark card.
		c.rgb = mix(c.rgb, c.rgb * vec3(0.78, 0.92, 1.12), 0.6);
	}
	if (again) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 red = vec3(1.0, 0.24, 0.3) * (0.35 + 0.9 * l);
		float pulse = 0.5 + 0.5 * sin(t * 3.0);
		c.rgb = mix(c.rgb, red, 0.5 + 0.12 * pulse);
	}
	if (holo) {
		// Diagonal sweep plus a slow hue drift: brighter parts (the chrome frame, the card
		// face) catch more of it, dark ink keeps its contrast.
		float band = sin((p.x + p.y) * 0.011 - t * 1.6);
		float glint = smoothstep(0.55, 1.0, band);
		vec3 hue = rainbow(fract((p.x - p.y) * 0.0016 + t * 0.07));
		float face = smoothstep(0.35, 0.95, lum);
		c.rgb = mix(c.rgb, c.rgb * (0.82 + 0.3 * hue), 0.45 * face);
		c.rgb += hue * (0.1 + 0.34 * glint) * face;
	}
	COLOR = c;
}
