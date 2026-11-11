shader_type spatial;
// Ponto da mira laser (SniperLaser) onde o feixe bate: brilho redondo virado para a câmera, nunca menor que `min_px`
// pixels, puxado `lift` m para a câmera (o ponto está NA superfície e não pode afundar nela; o que estiver na frente,
// da câmera, ainda o tapa).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.08, 0.05, 1.0);
uniform float size = 0.05;  // m de diâmetro
uniform float min_px = 9.0;
uniform float strength = 1.0;
uniform float lift = 0.1;

varying vec2 uv;

void vertex() {
	uv = VERTEX.xy * 2.0;
	vec3 c = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float px = max(-c.z, 0.05) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float s = max(size, min_px * px);
	c -= normalize(c) * min(lift, -c.z * 0.5);
	VERTEX = c + vec3(VERTEX.xy * s, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(uv);
	float core = clamp(1.0 - r * 3.2, 0.0, 1.0);
	float glow = exp(-r * r * 6.0) * 0.8;
	ALBEDO = mix(color.rgb, vec3(1.0, 0.9, 0.85), core);
	ALPHA = clamp((core + glow) * strength, 0.0, 1.0) * step(r, 1.0);
}
