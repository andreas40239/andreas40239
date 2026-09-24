shader_type canvas_item;
// Eingeschraenkte Sicht bei Nacht (GDD Abschnitt 6 und 9): um die Katze bleibt
// ein heller Bereich, nach aussen wird es dunkel-nachtblau.

uniform vec2 center = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 1.0) = 0.4;
uniform float softness : hint_range(0.01, 1.0) = 0.3;
uniform float darkness : hint_range(0.0, 1.0) = 0.78;
uniform float aspect = 1.7778;
uniform vec3 night_color : source_color = vec3(0.01, 0.015, 0.045);

void fragment() {
	vec2 offset = (UV - center) * vec2(aspect, 1.0);
	float shade = smoothstep(radius, radius + softness, length(offset));
	COLOR = vec4(night_color, shade * darkness);
}
