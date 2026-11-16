shader_type canvas_item;
// Zombie-Sicht: alles in Rot-Tönen. Kräftiges Gelb (erkannte Menschen, Ovale)
// bleibt gelb erhalten.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float time_s = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = pow(l, 0.8);
	vec3 red = vec3(l * 1.25 + 0.05, l * l * 0.22, l * l * 0.1);
	// "Gelbheit": viel Rot und Grün, wenig Blau
	float y = min(c.r, c.g * 1.05) - c.b * 1.6;
	float keep = smoothstep(0.38, 0.6, y);
	vec3 yellow = vec3(1.0, 0.9, 0.1) * (0.6 + 0.6 * max(c.r, c.g));
	vec3 o = mix(red, yellow, keep);
	// pulsierende Vignette
	vec2 d = SCREEN_UV - vec2(0.5);
	float v = smoothstep(0.3, 0.85, length(d * vec2(1.0, 1.15)));
	o *= 1.0 - (0.55 + 0.08 * sin(time_s * 2.2)) * v;
	o += vec3(0.25, 0.0, 0.0) * v * (0.5 + 0.5 * sin(time_s * 2.2));
	COLOR = vec4(mix(c, o, strength), 1.0);
}
