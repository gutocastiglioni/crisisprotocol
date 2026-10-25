class_name Roof
## Telhado do galpão, onde ela começa a fase: laje de concreto em cima das paredes com o furo do alçapão (Hatch) no
## canto do fundo à direita, parapeito baixo em volta (dá para escalar e se jogar: a queda mata), casas de máquinas e
## respiros. A laje não faz sombra (o "sol" da noite iluminaria só o telhado).
## O teto do anexo dos clones (CloneLab) fica LAB_Y acima, 1,5 m acima da laje (dá para escalar na parede do fundo): tem
## mureta nos três lados de fora e, no fundo, a caixa de paraquedas (SupplyDrop). Neblina (`_fog`) cobre os dois: rala
## sobre o galpão, mais grossa sobre o anexo (a caixa só aparece de perto).

const Y := Level.WALL_H + 0.3  # topo da laje
const THICK := 0.3
const EDGE := Level.SIZE * 0.5 + 0.2  # a laje cobre as paredes
const PARAPET_H := 1.0
const PARAPET_T := 0.3
const HATCH_POS := Vector3(11.8, 0, Level.SIZE * 0.5 - 0.2)  # beira do furo junto à face de dentro da parede do fundo
const START := Vector3(6.5, Y, 4.5)  # onde ela começa, olhando para o alçapão (~10 m dele)
const LAB_Y := CloneLab.CEIL_Y + 0.3  # topo do teto do anexo dos clones
const LAB_X := CloneLab.HALF_W + 0.2  # meia-largura do teto do anexo
const LAB_Z0 := CloneLab.Z_NEAR  # o teto do anexo vai da parede do fundo do galpão...
const LAB_Z1 := CloneLab.Z_FAR - 0.4  # ... até depois da parede do fundo do anexo
const SMELL_DIST := 3.0  # da mureta oeste (o lado do pátio) até onde ela sente o cheiro
const SMELL_TEXT := "Um cheiro forte de sangue\nvem dessa area vegetada..."
const FOG_H := 4.0  # altura da neblina acima da laje
const FOG_DENSITY := 0.1  # sobre o galpão: o alçapão (~10 m do começo) ainda aparece
const LAB_FOG_DENSITY := 0.22  # a mais sobre o anexo: a caixa de paraquedas some a poucos metros


## Chegou à beira do lado do pátio (mureta oeste, em cima da laje do galpão)? Na primeira vez o main para o jogo com
## SMELL_TEXT (Inspect.show_message).
static func near_yard(pos: Vector3) -> bool:
	return has(pos) and pos.y < LAB_Y - 0.2 and pos.x < -EDGE + SMELL_DIST


## `pos` está em cima da laje? Lá em cima ela fica fora do alcance dos inimigos: som e vista não passam a laje.
static func has(pos: Vector3) -> bool:
	if pos.y > LAB_Y - 0.2 and absf(pos.x) < LAB_X and pos.z < LAB_Z0 and pos.z > LAB_Z1:
		return true  # no teto do anexo dos clones
	return pos.y > Y - 0.2 and absf(pos.x) < EDGE and absf(pos.z) < EDGE


static func build(parent: Node) -> Hatch:
	var hole_x0 := HATCH_POS.x - Hatch.HOLE.x * 0.5
	var hole_x1 := HATCH_POS.x + Hatch.HOLE.x * 0.5
	var hole_z0 := HATCH_POS.z - Hatch.HOLE.y
	var hole_z1 := HATCH_POS.z
	var y := Y - THICK * 0.5
	# laje em quatro pedaços em volta do furo
	_slab(parent, -EDGE, EDGE, -EDGE, hole_z0, y)
	_slab(parent, -EDGE, hole_x0, hole_z0, EDGE, y)
	_slab(parent, hole_x1, EDGE, hole_z0, EDGE, y)
	_slab(parent, hole_x0, hole_x1, hole_z1, EDGE, y)
	# parapeito nas quatro bordas (o do norte some atrás do anexo dos clones, mais alto)
	var e := EDGE - PARAPET_T * 0.5
	_parapet(parent, Vector3(EDGE * 2.0, 0, PARAPET_T), Vector3(0, 0, e))
	for s in [-1, 1]:
		_parapet(parent, Vector3(PARAPET_T, 0, EDGE * 2.0), Vector3(s * e, 0, 0))
	var lab_x := CloneLab.HALF_W + 0.2
	var side := (EDGE - lab_x)
	for s in [-1, 1]:
		_parapet(parent, Vector3(side, 0, PARAPET_T), Vector3(s * (lab_x + side * 0.5), 0, -e))
	# mureta no teto do anexo dos clones (o lado do galpão fica aberto: é por onde ela sobe e desce)
	var le := LAB_X - PARAPET_T * 0.5
	for s in [-1, 1]:
		_parapet(parent, Vector3(PARAPET_T, 0, LAB_Z0 - LAB_Z1), Vector3(s * le, 0, (LAB_Z0 + LAB_Z1) * 0.5), LAB_Y)
	_parapet(parent, Vector3(LAB_X * 2.0, 0, PARAPET_T), Vector3(0, 0, LAB_Z1 + PARAPET_T * 0.5), LAB_Y)
	_props(parent)
	_fog(parent)
	var hatch := Hatch.new()
	hatch.position = HATCH_POS
	parent.add_child(hatch)
	return hatch


static func _slab(parent: Node, x0: float, x1: float, z0: float, z1: float, y: float) -> void:
	var body := Level.block(parent, Vector3(x1 - x0, THICK, z1 - z0), Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), "concrete", 0.35)
	(body.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mureta de 1 m: dá para escalar e pular para fora (a queda mata: Player.fall_damage / VOID_Y).
static func _parapet(parent: Node, size: Vector3, at: Vector3, base := Y) -> void:
	Level.block(parent, Vector3(size.x, PARAPET_H, size.z), Vector3(at.x, base + PARAPET_H * 0.5, at.z), "wall", 0.5)


## Casas de máquinas (dá para subir nelas, não para fora), respiros e uma luz vermelha de aviso.
static func _props(parent: Node) -> void:
	for b in [[Vector3(2.2, 1.2, 1.6), Vector3(4.0, 0, 8.5)], [Vector3(1.6, 1.0, 1.6), Vector3(-6.0, 0, 3.0)],
			[Vector3(2.6, 1.4, 1.8), Vector3(-2.0, 0, -7.0)]]:
		Level.block(parent, b[0], Vector3(b[1].x, Y + b[0].y * 0.5, b[1].z), "wall", 0.75)
	for v in [Vector3(7.0, 0, 11.0), Vector3(-9.0, 0, -4.0), Vector3(1.0, 0, 2.0), Vector3(9.0, 0, -9.0)]:
		var c := CylinderMesh.new()
		c.top_radius = 0.18
		c.bottom_radius = 0.22
		c.height = 0.9
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = Level.material("wall", 2.0)
		mi.position = v + Vector3.UP * (Y + 0.45)
		parent.add_child(mi)
	var beacon := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	beacon.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.15, 0.1)
	beacon.material_override = m
	beacon.position = Vector3(4.0, Y + 1.27, 8.5)
	parent.add_child(beacon)
	var o := OmniLight3D.new()
	o.position = beacon.position + Vector3.UP * 0.1
	o.light_color = Color(1.0, 0.2, 0.15)
	o.light_energy = 0.9
	o.omni_range = 4.0
	parent.add_child(o)


## Neblina do telhado (volume de névoa, como a do pátio: Yard._mist): uma rala sobre a laje inteira e outra, mais grossa,
## sobre o teto do anexo dos clones. Começa logo acima da laje (não entra no galpão) e se apaga para cima e nas bordas.
static func _fog(parent: Node) -> void:
	for f in [[Vector3(EDGE * 2.0 + 2.0, FOG_H, EDGE - LAB_Z1 + 2.0), Vector3(0, Y - 0.1 + FOG_H * 0.5, (EDGE + LAB_Z1) * 0.5), FOG_DENSITY],
			[Vector3(LAB_X * 2.0 + 2.0, FOG_H, LAB_Z0 - LAB_Z1 + 1.0), Vector3(0, LAB_Y - 0.1 + FOG_H * 0.5, (LAB_Z0 + LAB_Z1) * 0.5 - 0.5), LAB_FOG_DENSITY]]:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = f[0]
		fv.position = f[1]
		var m := FogMaterial.new()
		m.density = f[2]
		m.albedo = Color(0.62, 0.66, 0.72)
		m.emission = Color(0.035, 0.04, 0.05)
		m.height_falloff = 0.6
		m.edge_fade = 0.3
		fv.material = m
		parent.add_child(fv)
