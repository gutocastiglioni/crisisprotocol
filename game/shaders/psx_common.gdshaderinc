// Visual de PS1: vértices presos à grade de pixels (tremida), textura "afim" (distorce em ângulo),
// luz por vértice (render_mode vertex_lighting no shader que inclui este arquivo) e filtro "nearest".

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
// 1.0 = vértice preso a cada pixel da tela interna (320x240); menor = mais tremida
uniform float snap_scale : hint_range(0.1, 2.0) = 0.5;
uniform float affine_strength : hint_range(0.0, 1.0) = 1.0;
// UV pelo mundo (cenário): projeta pela maior componente da normal, como uma caixa
uniform bool world_uv = false;
uniform float world_uv_scale = 0.5;
// só usado no visual PS2 (declarado aqui para o parâmetro sobreviver à troca de shader)
uniform float rim : hint_range(0.0, 1.0) = 0.0;

varying vec3 affine_uv;

void vertex() {
	vec2 uv = UV;
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 wn = abs(n);
		// nas paredes o U segue a direita de quem olha a face (sem o sinal, faces -Z e +X saíam espelhadas)
		if (wn.y >= wn.x && wn.y >= wn.z) {
			uv = wp.xz;
		} else if (wn.x >= wn.z) {
			uv = vec2(-sign(n.x) * wp.z, -wp.y);
		} else {
			uv = vec2(sign(n.z) * wp.x, -wp.y);
		}
		uv *= world_uv_scale;
	}
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = VIEWPORT_SIZE * 0.5 * snap_scale;
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
	affine_uv = vec3(uv * clip.w, clip.w);
	UV = uv;
}

void fragment() {
	vec2 uv = mix(UV, affine_uv.xy / affine_uv.z, affine_strength);
	vec4 t = texture(albedo_tex, uv);
	vec3 c = t.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate) * tint.rgb;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#ifdef ALPHA_CUT
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
