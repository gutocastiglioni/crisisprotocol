class_name Roof
## Telhado do galpão, onde ela começa a fase: laje de concreto em cima das paredes (da sala dos clones para o fundo; o pátio
## descoberto não tem teto) com o furo do alçapão (Hatch) no canto do fundo à direita, parapeito baixo em volta (dá para
## escalar e se jogar: a queda mata), casas de máquinas e respiros. Da metade para a frente (z < FENCE_Z) a cobertura é de
## telha translúcida: um alambrado alto atravessa o telhado e ela fica na parte de trás. A caixa de paraquedas
## (SupplyDrop) fica na parte de trás, no mesmo nível, escondida na neblina (`_fog`: rala sobre o telhado, mais grossa no
## canto da caixa). A laje não faz sombra (o "sol" da noite iluminaria só o telhado).

const Y := Level.WALL_H + 0.3  # topo da laje
const THICK := 0.3
const X0 := Level.WEST - 0.2  # a laje cobre as paredes
const X1 := Level.EAST + 0.2
const Z0 := Level.ROOF_Z - 0.2  # beira da frente (sobre a parede da sala dos clones com o pátio descoberto)
const Z1 := Level.NORTH + 0.2  # beira do fundo
const PARAPET_H := 1.0
const PARAPET_T := 0.3
const HATCH_POS := Vector3(2.2, 0, Level.NORTH - Level.WALL_T * 0.5)  # beira do furo junto à face de dentro da parede do fundo
const START := Vector3(-6.0, Y, 59.0)  # onde ela começa, olhando para o alçapão (~11 m dele)
## Telha translúcida da frente: alambrado de lado a lado (alto: não se pula nem se escala) e as placas claras da telha.
const FENCE_Z := 53.0
const FENCE_H := 3.2
const SMELL_DIST := 3.0  # da mureta oeste (o lado do pátio da mata) até onde ela sente o cheiro
const SMELL_TEXT := "Um cheiro forte de sangue\nvem dessa área vegetada..."
const FOG_H := 4.0  # altura da neblina acima da laje
const FOG_DENSITY := 0.08  # sobre o telhado: o alçapão ainda aparece do começo
## Mais grossa no canto da caixa de paraquedas (x0, x1, z0, z1): a caixa só aparece a poucos metros.
const DROP_FOG := [Level.WEST - 0.2, -7.5, 61.0, Level.NORTH + 0.2]
const DROP_FOG_DENSITY := 0.35


## Chegou à beira do lado do pátio da mata (mureta oeste)? Na primeira vez o main para o jogo com SMELL_TEXT
## (Inspect.show_message).
static func near_yard(pos: Vector3) -> bool:
	return has(pos) and pos.x < X0 + SMELL_DIST


## `pos` está em cima da laje? Lá em cima ela fica fora do alcance dos inimigos: som e vista não passam a laje.
static func has(pos: Vector3) -> bool:
	return pos.y > Y - 0.2 and pos.x > X0 and pos.x < X1 and pos.z > Z0 and pos.z < Z1


static func build(parent: Node) -> Hatch:
	var hole_x0 := HATCH_POS.x - Hatch.HOLE.x * 0.5
	var hole_x1 := HATCH_POS.x + Hatch.HOLE.x * 0.5
	var hole_z0 := HATCH_POS.z - Hatch.HOLE.y
	var hole_z1 := HATCH_POS.z
	var y := Y - THICK * 0.5
	# laje em quatro pedaços em volta do furo
	_slab(parent, X0, X1, Z0, hole_z0, y)
	_slab(parent, X0, hole_x0, hole_z0, Z1, y)
	_slab(parent, hole_x1, X1, hole_z0, Z1, y)
	_slab(parent, hole_x0, hole_x1, hole_z1, Z1, y)
	# parapeito nas quatro bordas
	var t := PARAPET_T
	_parapet(parent, Vector3(X1 - X0, 0, t), Vector3((X0 + X1) * 0.5, 0, Z1 - t * 0.5))
	_parapet(parent, Vector3(X1 - X0, 0, t), Vector3((X0 + X1) * 0.5, 0, Z0 + t * 0.5))
	_parapet(parent, Vector3(t, 0, Z1 - Z0), Vector3(X0 + t * 0.5, 0, (Z0 + Z1) * 0.5))
	_parapet(parent, Vector3(t, 0, Z1 - Z0), Vector3(X1 - t * 0.5, 0, (Z0 + Z1) * 0.5))
	_skylights(parent)
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


## Telha translúcida da frente: o alambrado alto de mureta a mureta em FENCE_Z (camada da grade: segura o corpo, a vista
## passa) e as faixas claras da telha por cima da laje (só desenho).
static func _skylights(parent: Node) -> void:
	Shed.fence(parent, Vector2(X0 + PARAPET_T, FENCE_Z), Vector2(X1 - PARAPET_T, FENCE_Z), Y, Y + FENCE_H)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.55, 0.62, 0.6)
	m.roughness = 0.4
	var z := FENCE_Z - 1.6
	while z > Z0 + 1.0:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(X1 - X0 - 1.2, 0.03, 1.4)
		mi.mesh = bm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((X0 + X1) * 0.5, Y + 0.015, z)
		parent.add_child(mi)
		z -= 2.2


## Casas de máquinas (dá para subir nelas, não para fora), respiros e uma luz vermelha de aviso.
static func _props(parent: Node) -> void:
	for b in [[Vector3(2.2, 1.2, 1.6), Vector3(-0.5, 0, 56.0)], [Vector3(1.6, 1.0, 1.6), Vector3(-10.0, 0, 56.5)],
			[Vector3(2.6, 1.4, 1.8), Vector3(-4.0, 0, 47.0)]]:
		Level.block(parent, b[0], Vector3(b[1].x, Y + b[0].y * 0.5, b[1].z), "wall", 0.75)
	for v in [Vector3(1.5, 0, 61.0), Vector3(-8.5, 0, 66.0), Vector3(-3.0, 0, 55.0), Vector3(-9.0, 0, 30.0)]:
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
	beacon.position = Vector3(-0.5, Y + 1.27, 56.0)
	parent.add_child(beacon)
	var o := OmniLight3D.new()
	o.position = beacon.position + Vector3.UP * 0.1
	o.light_color = Color(1.0, 0.2, 0.15)
	o.light_energy = 0.9
	o.omni_range = 4.0
	o.add_to_group("lamps")  # sombra no PS2 (Gfx)
	parent.add_child(o)


## Neblina do telhado (volume de névoa, como a do pátio: Yard._mist): uma rala sobre a laje inteira e outra, mais grossa,
## no canto da caixa de paraquedas. Começa logo acima da laje (não entra no galpão) e se apaga para cima e nas bordas.
static func _fog(parent: Node) -> void:
	var d: Array = DROP_FOG
	for f in [[Vector3(X1 - X0 + 2.0, FOG_H, Z1 - Z0 + 2.0), Vector3((X0 + X1) * 0.5, Y - 0.1 + FOG_H * 0.5, (Z0 + Z1) * 0.5), FOG_DENSITY],
			[Vector3(d[1] - d[0], FOG_H, d[3] - d[2]), Vector3((d[0] + d[1]) * 0.5, Y - 0.1 + FOG_H * 0.5, (d[2] + d[3]) * 0.5), DROP_FOG_DENSITY]]:
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
