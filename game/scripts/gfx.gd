class_name Gfx
## Modo de visual (padrão: "ps2"; F2 ou --gfx=ps1 volta ao PS1 para comparar):
##   "ps1": 320x240, vértice tremido, textura torta e sem filtro, luz por vértice, cor de 15 bits com dithering.
##   "ps2": PS2 do começo (2000–2002): 640x480, luz por pixel com contorno, textura filtrada, sombras das lâmpadas.
## Os materiais dos dois modos têm os mesmos parâmetros; trocar de modo só troca o shader.

const MODES := ["ps1", "ps2"]
const RES := {"ps1": Vector2i(320, 240), "ps2": Vector2i(640, 480)}
const SHADERS := {
	"ps1": [preload("res://shaders/psx_lit.gdshader"), preload("res://shaders/psx_lit_2s.gdshader")],
	"ps2": [preload("res://shaders/ps2_lit.gdshader"), preload("res://shaders/ps2_lit_2s.gdshader")],
}

static var mode := "ps2"


## Shader do modo atual (`two_sided` = sem descartar o verso, com recorte por alfa).
static func shader(two_sided := false) -> Shader:
	return SHADERS[mode][1 if two_sided else 0]


## Troca o modo e atualiza os materiais e as luzes que já estão na árvore de `root`.
static func set_mode(m: String, root: Node) -> void:
	assert(m in MODES, "modo de visual desconhecido: " + m)
	mode = m
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		_swap(mi.material_override)
		for i in mi.get_surface_override_material_count():
			_swap(mi.get_surface_override_material(i))
	for light: Light3D in root.find_children("*", "Light3D", true, false):
		# lâmpadas do cenário fazem sombra no PS2; clarões curtos (tiro) nunca
		if light.is_in_group("lamps"):
			light.shadow_enabled = mode == "ps2"


static func _swap(m: Material) -> void:
	var sm := m as ShaderMaterial
	if sm == null:
		return
	for k in SHADERS:
		var i: int = SHADERS[k].find(sm.shader)
		if i >= 0:
			sm.shader = SHADERS[mode][i]
			return
