// Visual de "PS2 do começo" (2000–2002): sem a tremida de vértice nem a textura torta do PS1,
// luz por pixel com contorno de luz (rim) e textura filtrada com mipmaps.
// Mesmos uniforms do psx_common: o Gfx troca só o shader e o material mantém os parâmetros.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform bool world_uv = false;
uniform float world_uv_scale = 0.5;
// contorno de luz que destaca personagens no escuro (cenário fica em 0)
uniform float rim : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	if (world_uv) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 wn = abs(normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz));
		vec2 uv;
		if (wn.y >= wn.x && wn.y >= wn.z) {
			uv = wp.xz;
		} else if (wn.x >= wn.z) {
			uv = vec2(wp.z, -wp.y);
		} else {
			uv = vec2(wp.x, -wp.y);
		}
		UV = uv * world_uv_scale;
	}
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 c = t.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(c, vec3(g), desaturate) * tint.rgb;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	RIM = rim;
	RIM_TINT = 0.6;
#ifdef ALPHA_CUT
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
#endif
}
