// Bubble wobble + glassy rim for the Bubble Shield and the Big Bubble.
//
// Deliberately samples nothing but its own UV: no screen-texture read means no
// back-buffer copy, which keeps it fast on the Compatibility renderer and on
// low-end tablets. The "refraction" look comes from a tinted lens gradient
// plus a moving highlight rather than from real screen distortion.
shader_type canvas_item;

uniform float wobble_speed : hint_range(0.0, 8.0) = 2.2;
uniform float wobble_amount : hint_range(0.0, 0.1) = 0.022;
uniform vec4 tint : source_color = vec4(0.72, 0.94, 1.0, 0.30);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
uniform float seed = 0.0;

// Keeps the quad's corners fully transparent while letting the rim draw at full
// strength right at the edge of the wobbling circle.
float body_or_rim(float body, float rim) {
	return clamp(max(body, rim), 0.0, 1.0);
}

void fragment() {
	vec2 c = UV - vec2(0.5);
	float r = length(c) * 2.0;
	float ang = atan(c.y, c.x);
	float t = TIME * wobble_speed + seed;

	// Two out-of-phase lobes keep the outline soft and alive.
	float wob = sin(ang * 3.0 + t) * wobble_amount
		+ sin(ang * 5.0 - t * 0.7) * wobble_amount * 0.55;

	float body = 1.0 - smoothstep(0.90 + wob, 1.0 + wob, r);
	float rim = smoothstep(0.62, 0.95 + wob, r) * (1.0 - smoothstep(0.97 + wob, 1.0 + wob, r));

	// A lens gradient: brighter towards the middle-bottom, as if light bends through.
	float lens = smoothstep(1.0, 0.1, length(c - vec2(0.06, 0.12)) * 2.0) * 0.18;
	float gloss = smoothstep(0.42, 0.0, length(c - vec2(-0.17, -0.19)) * 2.0) * 0.85;
	float gloss2 = smoothstep(0.2, 0.0, length(c - vec2(0.2, 0.22)) * 2.0) * 0.35;

	vec3 col = tint.rgb + vec3(lens) + vec3(gloss + gloss2) + rim_color.rgb * rim * 0.9;
	float alpha = body * tint.a + rim * rim_color.a + (gloss + gloss2) * 0.6;
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0) * body_or_rim(body, rim));
}
