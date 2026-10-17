shader_type spatial;
// mesmo shader, sem descartar o verso e com recorte por alfa (cabelo e mechas abertas; o PS1 também tinha texel transparente)
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_disabled;

#define ALPHA_CUT
#include "res://shaders/psx_common.gdshaderinc"
