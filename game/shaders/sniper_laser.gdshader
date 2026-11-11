shader_type spatial;
// Feixe da mira laser do sniper (SniperLaser): fita virada para a câmera entre `start` e `end` (mundo), somada à cena.
// Nunca fica mais fina que `min_px` pixels da tela (na resolução interna de 854x480 / 427x240 uma linha de 1,5 cm
// sumia): núcleo quase branco no meio, halo vermelho em volta e uma poeira que corre devagar pelo feixe.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform, fog_disabled;

uniform vec3 start = vec3(0.0);
uniform vec3 end = vec3(0.0, 0.0, -1.0);
uniform vec4 color : source_color = vec4(1.0, 0.08, 0.05, 1.0);
uniform float width = 0.01;  // m do núcleo
uniform float min_px = 2.2;  // espessura mínima do núcleo, em pixels (menos que 2 sai pontilhado na diagonal)
uniform float halo = 3.0;  // a fita tem o núcleo vezes isto de largura (o resto é o halo)
uniform float strength = 1.0;  // 0..1 (o pisca-pisca antes do tiro e o acender)

varying float across;  // -1..1 de um lado ao outro da fita
varying float dist;  // m desde o cano

void vertex() {
	// QuadMesh 1x1 no plano XY: x = lado, y = ao longo (-0.5 no cano, 0.5 no alvo)
	float k = VERTEX.y + 0.5;
	across = VERTEX.x * 2.0;
	dist = k * length(end - start);
	vec3 p = (VIEW_MATRIX * vec4(mix(start, end, k), 1.0)).xyz;
	vec3 d = (VIEW_MATRIX * vec4(end - start, 0.0)).xyz;
	vec3 side = cross(d, p);
	side = length(side) > 1e-5 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float px = max(-p.z, 0.05) * 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);  // m por pixel nesta profundidade
	float w = max(width, min_px * px) * halo;
	VERTEX = p + side * VERTEX.x * w;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float u = abs(across) * halo;  // 1 = beira do núcleo
	float core = clamp(1.4 - u, 0.0, 1.0);
	float glow = exp(-u * u * 0.35) * 0.45;
	float dust = 0.82 + 0.18 * sin(dist * 9.0 - TIME * 2.3) * sin(dist * 3.7 + TIME * 1.1);
	float near = smoothstep(0.0, 0.08, dist);  // não acende dentro do cano
	ALBEDO = mix(color.rgb, vec3(1.0, 0.85, 0.8), core * 0.6);
	ALPHA = clamp((core + glow * dust) * strength * near, 0.0, 1.0);
}
