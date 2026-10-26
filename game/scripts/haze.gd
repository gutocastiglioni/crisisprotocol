class_name Haze
## Ar pesado do galpão (jeito PS2 do começo, Syphon Filter/MGS2): debaixo de cada luminária um feixe de luz falso
## (cone aberto somado à cena, `light_shaft.gdshader`) e um halo em volta do painel.
## Nada aqui tem corpo, sombra nem luz própria: é só desenho, não muda a furtividade (`Player.visibility`) nem os tiros.
## Igual nos dois visuais: os materiais são próprios, fora da troca de shader do `Gfx`.

const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")
const TOP_R := 0.38  # raio do cone no painel
const SPREAD := 0.5  # quanto o raio cresce por metro de queda
const STRENGTH := 0.14  # brilho do feixe no topo, numa lâmpada de força 2
const HALO := 1.3  # lado do halo do painel (m)


## Um feixe e um halo para cada [ponto do painel aceso, cor, força da lâmpada]; o pé do cone é o chão (y = 0).
## Devolve as raízes (grupo "haze"), uma por lâmpada.
static func build(parent: Node, lamps: Array) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for l in lamps:
		var root := Node3D.new()
		root.name = "Haze"
		root.position = l[0]
		root.add_to_group("haze")
		var h: float = l[0].y
		var k: float = l[2] / 2.0
		root.add_child(_shaft(h, l[1], k))
		root.add_child(_halo(l[1], k))
		parent.add_child(root)
		out.append(root)
	return out


## Raio do cone a `drop` m abaixo do painel.
static func radius(drop: float) -> float:
	return TOP_R + SPREAD * drop


static func _shaft(h: float, color: Color, k: float) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = TOP_R
	c.bottom_radius = radius(h)
	c.height = h
	c.cap_top = false
	c.cap_bottom = false
	c.radial_segments = 16
	c.rings = 1
	var m := ShaderMaterial.new()
	m.shader = SHAFT_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("strength", STRENGTH * k)
	m.set_shader_parameter("height", h)
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	mi.mesh = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = -h * 0.5
	return mi


## Halo redondo virado para a câmera, logo abaixo do painel.
static func _halo(color: Color, k: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var q := QuadMesh.new()
	q.size = Vector2.ONE * HALO
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = tex
	m.albedo_color = Color(color.r, color.g, color.b, 0.45 * k)
	var mi := MeshInstance3D.new()
	mi.name = "Halo"
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = -0.06
	return mi
