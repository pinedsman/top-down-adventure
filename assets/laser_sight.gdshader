shader_type canvas_item;

uniform float fade_start: hint_range(0.0, 1.0) = 0.5;
uniform float laser_length: hint_range(0.0, 2000.0) = 300.0;
uniform float texture_width: hint_range(0.0, 512.0) = 32.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    float tiles = laser_length / texture_width;
    float pixel_u = UV.x * tiles;
    float fade = smoothstep(tiles, fade_start * tiles, pixel_u);
    COLOR = vec4(tex.rgb, 0.35 * tex.a * fade);
}