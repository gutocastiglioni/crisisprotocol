shader_type canvas_item;
// Pós-processo de PS1: cor de 15 bits (5 bits por canal) com dithering ordenado 4x4.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float levels = 32.0;
uniform float dither_strength : hint_range(0.0, 2.0) = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float b = BAYER[p.x + p.y * 4] / 16.0 - 0.5;
	c += b * dither_strength / levels;
	c = floor(clamp(c, 0.0, 1.0) * (levels - 1.0) + 0.5) / (levels - 1.0);
	COLOR = vec4(c, 1.0);
}
