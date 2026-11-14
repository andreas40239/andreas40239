shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

// Stilisiertes Wasser: zwei gegeneinander wandernde Rauschlagen erzeugen
// wandernde Lichtflecken; sehr günstig und damit gut für Mobilgeräte.
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 shallow : source_color = vec3(0.36, 0.74, 0.88);
uniform vec3 deep : source_color = vec3(0.12, 0.44, 0.72);
uniform vec3 sparkle : source_color = vec3(0.92, 0.98, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz * 0.055;
	float n1 = texture(noise_tex, uv + TIME * vec2(0.010, 0.022)).r;
	float n2 = texture(noise_tex, uv * 1.9 - TIME * vec2(0.016, 0.007)).g;
	float n3 = texture(noise_tex, uv * 0.45 + TIME * vec2(-0.004, 0.006)).b;
	float n = n1 * 0.55 + n2 * 0.45;
	vec3 col = mix(deep, shallow, smoothstep(0.25, 0.8, n * 0.7 + n3 * 0.3));
	float spark = smoothstep(0.66, 0.70, n) * (1.0 - smoothstep(0.72, 0.78, n));
	ALBEDO = mix(col, sparkle, spark * 0.55);
	ROUGHNESS = 0.12;
	SPECULAR = 0.7;
	ALPHA = 0.9;
}
