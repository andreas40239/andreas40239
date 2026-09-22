// Toon-Shading fuer das Asset-Kit (GDD Abschnitt 9):
// flache Flaechen mit zwei bis drei harten Helligkeitsstufen, keine Texturen.
//
// Die Farbe kommt aus den Eckpunkten, der Alphakanal steuert das Leuchten -
// damit braucht das gesamte Kit nur dieses eine Material.
//
// Die Stufen berechnet light(). Der Compatibility-Renderer unterstuetzt keine
// eigenen light()-Funktionen; dort springt der Ersatzpfad ein, den
// AssetKit.configure_material() einschaltet.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

uniform int light_steps : hint_range(2, 4) = 3;
/// Helligkeit der dunkelsten Stufe - ohne sie saufen abgewandte Flaechen ab.
uniform float shadow_level : hint_range(0.0, 0.8) = 0.3;
uniform float emission_strength : hint_range(0.0, 8.0) = 1.0;
uniform vec3 tint : source_color = vec3(1.0);

// Ersatzbeleuchtung fuer Renderer ohne light()-Unterstuetzung.
uniform bool fallback_sun = false;
uniform vec3 fallback_sun_direction = vec3(0.32, -0.64, -0.69);
uniform vec3 fallback_sun_color : source_color = vec3(1.0, 0.96, 0.88);
uniform float fallback_sun_energy : hint_range(0.0, 2.0) = 0.85;

// Die Palette ist wie im Inspektor in sRGB angelegt.
vec3 to_linear(vec3 color) {
	return pow(color, vec3(2.2));
}

float quantize_light(float value) {
	float steps = float(light_steps);
	float stepped = clamp(floor(value * steps) / max(steps - 1.0, 1.0), 0.0, 1.0);
	return mix(shadow_level, 1.0, stepped);
}

void fragment() {
	vec3 base = to_linear(COLOR.rgb) * tint;
	ALBEDO = base;
	vec3 glow = base * COLOR.a * emission_strength;
	if (fallback_sun) {
		// NORMAL liegt im Sichtraum, die Sonnenrichtung in Weltkoordinaten.
		vec3 sun_view = normalize((VIEW_MATRIX * vec4(fallback_sun_direction, 0.0)).xyz);
		float ndotl = max(dot(normalize(NORMAL), -sun_view), 0.0);
		glow += base * fallback_sun_color * quantize_light(ndotl) * fallback_sun_energy;
	}
	EMISSION = glow;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndotl = max(dot(normalize(NORMAL), normalize(LIGHT)), 0.0);
	// Durch PI geteilt wie Godots eingebautes Lambert - so trifft die Helligkeit
	// den Ersatzpfad und ein Standardmaterial.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * quantize_light(ndotl) / PI;
}
