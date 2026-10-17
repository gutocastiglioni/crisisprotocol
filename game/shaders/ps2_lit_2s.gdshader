shader_type spatial;
// mesmo shader, sem descartar o verso e com recorte por alfa (pontas das mechas de cabelo)
render_mode diffuse_lambert, cull_disabled;

#define ALPHA_CUT
#include "res://shaders/ps2_common.gdshaderinc"
