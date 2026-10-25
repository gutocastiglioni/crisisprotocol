shader_type spatial;
// Estrela de brilho de item (KeyItem): quadro virado para a câmera, somando luz, que respeita a profundidade
// (parede/caixa na frente esconde). O vértice é puxado `pull` m na direção da câmera pelo próprio raio de visão:
// na tela fica no mesmo lugar e do mesmo tamanho, só a profundidade muda, para a ponta não entrar no chão e o
// brilho não sumir embaixo do corpo caído em cima da chave.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D sprites : source_color, filter_linear_mipmap;
uniform vec4 color : source_color = vec4(1.0);
uniform float pull = 0.4;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = length(v.xyz);
	v.xyz *= max(0.05, 1.0 - pull / max(d, 0.001));
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	vec4 t = texture(sprites, UV * vec2(1.0 / 3.0, 1.0));
	ALBEDO = t.rgb * color.rgb;
	ALPHA = t.a * color.a;
}
