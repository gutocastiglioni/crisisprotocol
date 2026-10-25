shader_type spatial;
// Brilho de arma largada (Pickup): soma luz, sem quina dura. `beam` falso = halo redondo deitado no chão (some do
// centro para a borda); verdadeiro = feixe em pé (some para os lados e para cima). Pulsa devagar pela `phase`.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform bool beam = false;
uniform float phase = 0.0;

void fragment() {
	float a;
	if (beam) {
		float side = 1.0 - abs(UV.x * 2.0 - 1.0);
		a = side * side * pow(UV.y, 1.6);  // UV.y = 1 embaixo (QuadMesh)
	} else {
		float r = length(UV * 2.0 - 1.0);
		a = 1.0 - smoothstep(0.0, 1.0, r);
		a *= a;
	}
	a *= 0.75 + 0.25 * sin(TIME * 3.0 + phase);
	ALBEDO = color.rgb;
	ALPHA = a * color.a;
}
