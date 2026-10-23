shader_type canvas_item;
// Máscara da mira telescópica (Sniper Scope): centro circular transparente com lente óptica,
// aro metálico escuro com chanfro (bezel) e máscara opaca cobrindo as bordas da tela.

uniform float aspect = 1.333333;
uniform float lens_radius = 0.42;
uniform float bezel_width = 0.016;
uniform vec4 mask_color : source_color = vec4(0.015, 0.015, 0.02, 1.0);
uniform vec4 bezel_outer : source_color = vec4(0.09, 0.10, 0.12, 1.0);
uniform vec4 bezel_inner : source_color = vec4(0.25, 0.27, 0.30, 1.0);

void fragment() {
	vec2 uv = UV - vec2(0.5);
	uv.x *= aspect;
	float dist = length(uv);

	if (dist < lens_radius) {
		// Interior da lente: transparente, com vinheta suave nas quinas do vidro
		float edge = dist / lens_radius;
		float vign = smoothstep(0.88, 1.0, edge) * 0.28;
		COLOR = vec4(0.0, 0.0, 0.0, vign);
	} else if (dist < lens_radius + bezel_width) {
		// Aro metálico do tubo da mira telescópica
		float t = (dist - lens_radius) / bezel_width;
		vec4 ring = mix(bezel_inner, bezel_outer, t);
		COLOR = ring;
	} else {
		// Fora da lente: máscara preta cobrindo a tela
		COLOR = mask_color;
	}
}
