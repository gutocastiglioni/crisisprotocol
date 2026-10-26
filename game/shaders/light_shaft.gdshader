shader_type spatial;
// Feixe de luz falso (jeito PS2 do começo: Syphon Filter, MGS2): cone aberto somado à cena, sem luz nem sombra.
// Mais forte no topo (lâmpada) e sumindo até o pé; borda mole na silhueta; some quando a câmera entra nele.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float strength = 0.14;
uniform float height = 3.5;  // altura do cone (o CylinderMesh fica centrado na origem)
uniform float near_fade = 2.0;  // a esta distância da câmera já tem brilho cheio

varying float along;  // 1 no topo, 0 no pé

void vertex() {
	along = clamp(VERTEX.y / height + 0.5, 0.0, 1.0);
}

void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float near = smoothstep(0.3, near_fade, -VERTEX.z);
	ALBEDO = color.rgb;
	ALPHA = strength * pow(along, 1.5) * face * face * near;
}
