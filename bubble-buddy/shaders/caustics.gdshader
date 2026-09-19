// Gentle underwater caustic light, done with layered sine waves so it stays
// cheap enough for the Compatibility renderer on low-end tablets.
shader_type canvas_item;
render_mode blend_add;

uniform float time_scale : hint_range(0.0, 2.0) = 0.35;
uniform float strength : hint_range(0.0, 2.0) = 0.55;
uniform vec3 light_color : source_color = vec3(1.0, 0.99, 0.86);

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	float w = sin(uv.x * 13.0 + t * 1.7)
		+ sin(uv.x * 23.0 - t * 1.1 + uv.y * 4.0) * 0.7
		+ sin((uv.x + uv.y * 0.6) * 8.0 + t * 0.8) * 0.8;
	float band = smoothstep(1.05, 2.1, abs(w));
	// Brightest near the surface (top of the screen), never fully dark below.
	float fade = mix(0.25, 1.0, 1.0 - uv.y);
	COLOR = vec4(light_color * band * fade * strength, band * fade * strength);
}
