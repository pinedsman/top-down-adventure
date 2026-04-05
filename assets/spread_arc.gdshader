shader_type canvas_item;

uniform vec4 fill_color : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float arc_radius : hint_range(1.0, 500.0) = 40.0;
// Where along the arc (0 = player origin, 1 = outer edge) the peak opacity sits
uniform float peak_position : hint_range(0.0, 1.0) = 0.5;
// How wide the visible band is — smaller values give a sharper, narrower peak
uniform float peak_width : hint_range(0.01, 1.0) = 0.3;

varying float v_dist;

void vertex() {
	v_dist = length(VERTEX) / arc_radius;
}

void fragment() {
	// Gaussian bell: single peak at peak_position, falls off symmetrically on both sides
	float fade = exp(-pow((v_dist - peak_position) / peak_width, 2.0));
	COLOR = vec4(fill_color.rgb, fill_color.a * fade);
}
