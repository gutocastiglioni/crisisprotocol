class_name CloneLab
extends Node3D
## Sala dos clones: anexo atrás da plataforma de carga, ao norte do galpão. O portão de enrolar (Door, `room` -1: fora da
## corrente galpão -> pátio -> pedreira) fica na parede do fundo do galpão, na altura da plataforma (o piso da sala é o
## da doca). Dentro, duas fileiras de tubos de vidro com velociraptors clonados suspensos no líquido, parados como se
## estivessem congelados (RaptorModel com a animação travada, azulados), bolhas subindo, névoa fria no chão e um console no
## fundo. Ela entra pela primeira vez: sinal `entered` (o main toca a cena do choque, Cutscene.play_clones).
## Cada tubo tem uma plaqueta (SubjectPlate, "SUBJECT XXXX", lida com E). No canto do fundo à esquerda fica o tanque
## enorme do alossauro, inteiro, drenado e com a porta de vidro aberta (vazio: ele está na pedreira); o número da
## plaqueta dele (ALLO_SUBJECT) é o código do teclado do portão da pedreira (Yard._gate). A chave que liga esse teclado
## fica em cima do console (`key_spot`, o main põe a KeyItem lá).

signal entered

const FLOOR_Y := 1.3  # = altura da plataforma de carga
const CEIL_Y := 6.7
const HALF_W := 7.0
const Z_NEAR := -Level.SIZE * 0.5  # parede do fundo do galpão
const Z_FAR := -32.0  # fundo: cabe o tanque do alossauro no canto
const GATE_W := 3.6
const GATE_TOP := 4.2
const TUBE_X := 4.3
const TUBE_Z := [-16.8, -20.3, -23.8]
const TUBE_R := 0.85
const TUBE_H := 3.9
const BASE_H := 0.45
const CAP_H := 0.4
const RAPTOR_PITCH := 85.0  # de pé no tubo: focinho para cima, cauda para baixo
const RAPTOR_SCALE := 0.92  # um pouco menor que o adulto do pátio: cauda e garras longe do vidro
const RAPTOR_FWD := 0.5  # o corpo em pé fica para trás da origem: empurra para o meio do tubo
const RAPTOR_LIFT := 2.5  # origem do raptor acima do piso (a ponta da cauda fica logo acima da base)
const FROZEN_FRAME := 0.7  # s da animação Idle em que eles ficam parados
const FROZEN_TINT := Color(0.62, 0.86, 1.08)
const ENTER_Z := Z_NEAR - 1.2  # passou do portão
const SUBJECTS := ["0412", "0413", "0414", "0415", "0416", "0417"]  # um por tubo, na ordem em que são montados
const ALLO_SUBJECT := "0927"  # o tanque vazio = código do portão da pedreira
const PLATE_IN := 1.25  # pedestal da plaqueta: do centro do tubo para o corredor
const TANK := Vector3(-4.5, FLOOR_Y, -29.4)  # centro do tanque do alossauro (canto do fundo à esquerda)
const TANK_R := 1.9
const TANK_H := 4.2
const TANK_BASE := 0.5
const TANK_CAP := 0.5
const TANK_SIDES := 16
const TANK_DOOR_OPEN := 100.0  # graus: a porta de vidro (3 lados) aberta para fora
const KEY_SPOT := Vector3(0.55, FLOOR_Y + 0.905, Z_FAR + 1.15)  # chave do painel em cima do console

var gate: Door
var clones: Array[RaptorModel] = []
var plates: Array[SubjectPlate] = []
var tank: Node3D
var played := false


func _ready() -> void:
	_build_room()
	_build_gate()
	for s in [-1, 1]:
		for z in TUBE_Z:
			_tube(Vector3(s * TUBE_X, FLOOR_Y, z), -s * PI * 0.5)
			_plate(self, Vector3(s * (TUBE_X - PLATE_IN), FLOOR_Y, z), -s * PI * 0.5, SUBJECTS[plates.size()], "VELOCIRAPTOR - CLONE", "CONGELADO / ESTAVEL", false)
	_build_tank()
	_build_console()
	_build_lights()


func _physics_process(_delta: float) -> void:
	if played or gate == null or not gate.opened:
		return
	for p: Player in get_tree().get_nodes_in_group("player"):
		if inside(p.global_position) and not p.dead:
			played = true
			entered.emit()


## O ponto está dentro da sala (depois do portão)?
static func inside(p: Vector3) -> bool:
	return p.z < ENTER_Z and p.z > Z_FAR and absf(p.x) < HALF_W and p.y > FLOOR_Y - 0.5


func _build_room() -> void:
	var depth := Z_NEAR - Z_FAR
	var mid_z := (Z_NEAR + Z_FAR) * 0.5 - 0.2
	var wall_h := CEIL_Y + 0.3 - FLOOR_Y
	# base maciça até a altura da doca e o piso
	Level.block(self, Vector3(HALF_W * 2.0 + 0.4, FLOOR_Y, depth + 0.4), Vector3(0, FLOOR_Y * 0.5, mid_z), "concrete", 0.35)
	for s in [-1, 1]:
		Level.block(self, Vector3(0.4, wall_h, depth + 0.4), Vector3(s * HALF_W, FLOOR_Y + wall_h * 0.5, mid_z), "wall", 0.5)
	Level.block(self, Vector3(HALF_W * 2.0 + 0.4, wall_h, 0.4), Vector3(0, FLOOR_Y + wall_h * 0.5, Z_FAR), "wall", 0.5)
	# parede de cima, acima da parede do galpão (o anexo é mais alto)
	var top_h := CEIL_Y + 0.3 - Level.WALL_H
	Level.block(self, Vector3(HALF_W * 2.0 + 0.4, top_h, 0.4), Vector3(0, Level.WALL_H + top_h * 0.5, Z_NEAR), "wall", 0.5)
	var ceil := Level.block(self, Vector3(HALF_W * 2.0 + 0.4, 0.3, depth + 0.4), Vector3(0, CEIL_Y + 0.15, mid_z), "concrete", 0.35)
	(ceil.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# faixa de perigo na entrada e no corredor do meio
	Level.block(self, Vector3(GATE_W, 0.02, 0.5), Vector3(0, FLOOR_Y + 0.01, Z_NEAR - 0.6), "hazard", 1.0)
	for s in [-1, 1]:
		Level.block(self, Vector3(0.2, 0.02, depth - 3.0), Vector3(s * 2.4, FLOOR_Y + 0.01, mid_z - 0.6), "hazard", 1.0)


## Portão de enrolar: lâminas de aço que sobem para dentro da parede; a caixa do rolo fica do lado de dentro.
func _build_gate() -> void:
	gate = Door.create(self, Vector3(0, FLOOR_Y, Z_NEAR), Vector3(GATE_W, GATE_TOP - FLOOR_Y, 0.4), -1, "ABRIR PORTAO")
	var h := GATE_TOP - FLOOR_Y
	var shutter := Node3D.new()
	var slats := int(h / 0.24)
	for i in slats:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(GATE_W, h / slats + 0.01, 0.06 if i % 2 == 0 else 0.08)  # encostadas: sem fresta de luz
		mi.mesh = b
		mi.material_override = Level.material("wall", 1.0)
		mi.position = Vector3(0, (i + 0.5) * (h / slats), 0)
		shutter.add_child(mi)
	# barra de baixo pintada de perigo (sobe junto)
	var bar := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(GATE_W, 0.2, 0.12)
	bar.mesh = bb
	var paint := Level.material("hazard", 1.0)
	paint.set_shader_parameter("world_uv", false)
	bar.material_override = paint
	bar.position = Vector3(0, 0.1, 0)
	shutter.add_child(bar)
	gate.add_panel(shutter, Vector3(0, h - 0.25, 0), 0.0)
	# guias laterais do lado do galpão
	for sx in [-1, 1]:
		var rail := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.16, h + 0.3, 0.18)
		rail.mesh = rb
		rail.material_override = Level.material("wall", 2.0)
		rail.position = Vector3(sx * (GATE_W * 0.5 + 0.08), FLOOR_Y + (h + 0.3) * 0.5, Z_NEAR + 0.29)
		add_child(rail)
	var housing := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(GATE_W + 0.4, 0.5, 0.5)
	housing.mesh = hb
	housing.material_override = Level.material("wall", 1.0)
	housing.position = Vector3(0, GATE_TOP + 0.25, Z_NEAR - 0.45)
	add_child(housing)


## Tubo de clonagem com um raptor dentro, olhando para o corredor do meio (`yaw`).
func _tube(at: Vector3, yaw: float) -> void:
	var tube := Node3D.new()
	tube.position = at
	add_child(tube)
	var metal := Level.material("wall", 1.5)
	_cyl(tube, TUBE_R + 0.15, BASE_H, BASE_H * 0.5, metal)
	_cyl(tube, TUBE_R + 0.15, CAP_H, BASE_H + TUBE_H + CAP_H * 0.5, metal)
	# canos do tampo até o teto
	for dx in [-0.35, 0.35]:
		var pipe := _cyl(tube, 0.07, CEIL_Y - FLOOR_Y - BASE_H - TUBE_H - CAP_H, 0.0, metal)
		pipe.position = Vector3(dx, (BASE_H + TUBE_H + CAP_H + CEIL_Y - FLOOR_Y) * 0.5, 0)
	# líquido (por dentro) e vidro
	var liquid := StandardMaterial3D.new()
	liquid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid.albedo_color = Color(0.35, 0.95, 0.85, 0.22)
	liquid.cull_mode = BaseMaterial3D.CULL_FRONT
	_cyl(tube, TUBE_R - 0.03, TUBE_H - 0.1, BASE_H + TUBE_H * 0.5, liquid)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.95, 1.0, 0.16)
	glass.metallic_specular = 1.0
	glass.roughness = 0.05
	_cyl(tube, TUBE_R, TUBE_H, BASE_H + TUBE_H * 0.5, glass)
	# o vidro segura o tiro (sem buraco de bala) e o corpo dela
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "metal")
	body.set_meta("no_decals", true)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = TUBE_R + 0.15
	shape.height = BASE_H + TUBE_H + CAP_H
	col.shape = shape
	col.position.y = shape.height * 0.5
	body.add_child(col)
	tube.add_child(body)
	# o clone: raptor de pé, parado no meio do líquido
	var holder := Node3D.new()
	holder.rotation.y = yaw
	tube.add_child(holder)
	var r := RaptorModel.new()
	r.chirps = false
	r.rotation.x = deg_to_rad(RAPTOR_PITCH)
	r.scale = Vector3.ONE * RAPTOR_SCALE
	r.position = Vector3(0, RAPTOR_LIFT, -RAPTOR_FWD)
	holder.add_child(r)
	_freeze(r)
	clones.append(r)
	# luz de dentro (embaixo e no meio, para o clone não virar só silhueta) e bolhas
	var o := OmniLight3D.new()
	o.position = Vector3(0, BASE_H + TUBE_H * 0.45, 0)
	o.light_color = Color(0.45, 1.0, 0.9)
	o.light_energy = 2.2
	o.omni_range = 3.0
	tube.add_child(o)
	tube.add_child(_bubbles())
	tube.add_child(_mist())


## Para a animação num quadro e deixa o corpo azulado e desbotado (congelado).
static func _freeze(r: RaptorModel) -> void:
	r.anim_player.seek(FROZEN_FRAME, true)
	r.anim_player.pause()
	for mi: MeshInstance3D in r.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i) as ShaderMaterial
			if m:
				m.set_shader_parameter("tint", FROZEN_TINT)
				m.set_shader_parameter("desaturate", 0.45)


func _cyl(parent: Node3D, radius: float, height: float, y: float, mat: Material) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 16
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position.y = y
	parent.add_child(mi)
	return mi


func _bubbles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 14
	p.lifetime = 3.2
	p.position.y = BASE_H + 0.15
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = TUBE_R * 0.6
	p.direction = Vector3.UP
	p.spread = 6.0
	p.gravity = Vector3(0, 0.25, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 0.9
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 1.0, 1.0, 0.55)
	sm.material = m
	p.mesh = sm
	return p


## Névoa fria rente ao chão em volta da base.
func _mist() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 4.0
	p.position.y = 0.1
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = TUBE_R + 0.2
	p.emission_ring_inner_radius = TUBE_R
	p.emission_ring_height = 0.05
	p.direction = Vector3(1, 0, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.2
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var q := QuadMesh.new()
	q.size = Vector2(0.7, 0.35)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(0.8, 0.95, 1.0, 0.18)
	m.albedo_texture = _puff()
	q.material = m
	p.mesh = q
	return p


## Mancha redonda que some nas bordas (a névoa não aparece como quadrados).
static func _puff() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex


## Pedestal com a plaqueta do tubo, de frente para quem vem pelo corredor (`yaw`: +Z local = para onde ela olha).
func _plate(parent: Node3D, at: Vector3, yaw: float, number: String, species: String, status: String, empty: bool) -> SubjectPlate:
	var pl := SubjectPlate.new()
	pl.number = number
	pl.species = species
	pl.status = status
	pl.empty = empty
	pl.position = at
	pl.rotation.y = yaw
	parent.add_child(pl)
	plates.append(pl)
	return pl


## Tanque do alossauro: bem maior que os dos raptors, inteiro e drenado (sem líquido, bolhas nem clone), com a porta de
## vidro de três lados aberta para fora, mangueiras soltas penduradas do tampo, um resto de líquido no fundo e uma luz
## vermelha de aviso. O vidro é um polígono de TANK_SIDES lados (a porta é a parte da frente); +Z local = para o meio da sala.
func _build_tank() -> void:
	tank = Node3D.new()
	tank.position = TANK
	var to_room := Vector3(0, FLOOR_Y, -26.0) - TANK
	tank.rotation.y = atan2(to_room.x, to_room.z)
	add_child(tank)
	var metal := Level.material("wall", 1.5)
	_cyl(tank, TANK_R + 0.2, TANK_BASE, TANK_BASE * 0.5, metal)
	_cyl(tank, TANK_R + 0.2, TANK_CAP, TANK_BASE + TANK_H + TANK_CAP * 0.5, metal)
	for dx in [-0.7, 0.0, 0.7]:
		var pipe := _cyl(tank, 0.11, CEIL_Y - FLOOR_Y - TANK_BASE - TANK_H - TANK_CAP, 0.0, metal)
		pipe.position = Vector3(dx, (TANK_BASE + TANK_H + TANK_CAP + CEIL_Y - FLOOR_Y) * 0.5, 0)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.7, 0.95, 1.0, 0.14)
	glass.metallic_specular = 1.0
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var seg := TAU / TANK_SIDES
	var chord := 2.0 * TANK_R * sin(seg * 0.5)
	var apothem := TANK_R * cos(seg * 0.5)
	var y := TANK_BASE + TANK_H * 0.5
	for k in TANK_SIDES:
		if k == 0 or k == 1 or k == TANK_SIDES - 1:
			continue  # a porta
		var a := k * seg
		var pane := _box(tank, Vector3(chord, TANK_H, 0.03), Vector3(sin(a) * apothem, y, cos(a) * apothem), glass)
		pane.rotation.y = a
		# montante de metal em cada quina
		var b := (k + 0.5) * seg
		_box(tank, Vector3(0.07, TANK_H, 0.07), Vector3(sin(b) * TANK_R, y, cos(b) * TANK_R), metal)
	# porta: uma folha reta no lugar dos três lados da frente, presa pela quina da direita e aberta para fora
	var edge := 1.5 * seg
	var w := 2.0 * TANK_R * sin(edge)
	var hinge := Node3D.new()
	hinge.position = Vector3(sin(edge) * TANK_R, 0, cos(edge) * TANK_R)
	hinge.rotation.y = deg_to_rad(TANK_DOOR_OPEN)
	tank.add_child(hinge)
	_box(hinge, Vector3(w, TANK_H, 0.04), Vector3(-w * 0.5, y, 0), glass)
	for x in [-0.04, -w + 0.04]:
		_box(hinge, Vector3(0.08, TANK_H, 0.08), Vector3(x, y, 0), metal)
	for yy in [TANK_BASE + 0.04, TANK_BASE + TANK_H - 0.04]:
		_box(hinge, Vector3(w, 0.08, 0.08), Vector3(-w * 0.5, yy, 0), metal)
	_box(tank, Vector3(0.07, TANK_H, 0.07), Vector3(-sin(edge) * TANK_R, y, cos(edge) * TANK_R), metal)
	# o vidro e a porta seguram o corpo e o tiro
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "metal")
	body.set_meta("no_decals", true)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = TANK_R + 0.2
	shape.height = TANK_BASE + TANK_H + TANK_CAP
	col.shape = shape
	col.position.y = shape.height * 0.5
	body.add_child(col)
	var door_col := CollisionShape3D.new()
	var door_shape := BoxShape3D.new()
	door_shape.size = Vector3(w, TANK_H, 0.1)
	door_col.shape = door_shape
	door_col.transform = hinge.transform * Transform3D(Basis.IDENTITY, Vector3(-w * 0.5, y, 0))
	body.add_child(door_col)
	tank.add_child(body)
	# resto do líquido drenado no fundo e escorrido pela porta, mangueiras soltas do tampo
	var residue := StandardMaterial3D.new()
	residue.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	residue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	residue.albedo_color = Color(0.35, 0.95, 0.75, 0.35)
	_cyl(tank, TANK_R - 0.05, 0.03, TANK_BASE + 0.02, residue)
	var puddle := _cyl(tank, 0.9, 0.01, 0.0, residue)
	puddle.position = Vector3(0.1, 0.006, TANK_R + 0.75)
	puddle.scale = Vector3(1.3, 1.0, 0.8)
	var hose := Level.material("wall", 3.0)
	for h in [[Vector3(-0.5, 0, 0.2), 0.25, 2.3], [Vector3(0.45, 0, -0.3), -0.2, 1.7], [Vector3(0.05, 0, 0.55), 0.1, 2.8]]:
		var mi := _cyl(tank, 0.045, h[2], 0.0, hose)
		mi.position = h[0] + Vector3(0, TANK_BASE + TANK_H - h[2] * 0.5, 0)
		mi.rotation.z = h[1]
	var warn := OmniLight3D.new()
	warn.position = Vector3(0, TANK_BASE + TANK_H * 0.6, 0)
	warn.light_color = Color(1.0, 0.25, 0.2)
	warn.light_energy = 1.6
	warn.omni_range = 4.0
	tank.add_child(warn)
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.25, 0.2)
	_box(tank, Vector3(0.3, 0.12, 0.06), Vector3(0, TANK_BASE + TANK_H + TANK_CAP * 0.5, TANK_R + 0.23), lamp)
	# plaqueta do lado da porta (à esquerda de quem chega), fora do caminho da folha aberta
	_plate(tank, Vector3(-1.0, 0, TANK_R + 0.55), 0.0, ALLO_SUBJECT, "ALLOSAURUS - PROTOTIPO", "VAZIO / TRANSFERIDO", true)


## Onde a chave do painel fica, em cima do console (mundo).
func key_spot() -> Transform3D:
	return global_transform * Transform3D(Basis(Vector3.UP, 0.5), KEY_SPOT)


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi


## Console de controle no fundo: mesa e três telas acesas.
func _build_console() -> void:
	var z := Z_FAR + 0.9
	Level.block(self, Vector3(3.2, 0.9, 0.9), Vector3(0, FLOOR_Y + 0.45, z), "wall", 0.75)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 1.0, 0.55)
	for dx in [-1.0, 0.0, 1.0]:
		var frame := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.8, 0.55, 0.08)
		frame.mesh = fb
		frame.material_override = Level.material("wall", 2.0)
		frame.position = Vector3(dx, FLOOR_Y + 1.35, z - 0.25)
		frame.rotation.x = deg_to_rad(-12.0)
		add_child(frame)
		var screen := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.68, 0.43)
		screen.mesh = q
		screen.material_override = m
		screen.position = Vector3(0, 0, 0.045)
		frame.add_child(screen)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, FLOOR_Y + 1.4, z + 0.6)
	glow.light_color = Color(0.3, 1.0, 0.55)
	glow.light_energy = 0.8
	glow.omni_range = 3.5
	add_child(glow)


## Luz fria do teto (com sombra no PS2, como as do galpão).
func _build_lights() -> void:
	for z in [-16.0, -23.0, -29.5]:
		var o := OmniLight3D.new()
		o.position = Vector3(0, CEIL_Y - 0.6, z)
		o.light_color = Color(0.6, 0.8, 1.0)
		o.light_energy = 1.4
		o.omni_range = 9.0
		o.omni_attenuation = 1.2
		o.add_to_group("lamps")
		add_child(o)
		var panel := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.6, 0.3)
		panel.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.95, 1.0)
		panel.material_override = m
		panel.rotation_degrees.x = 90.0
		panel.position = Vector3(0, CEIL_Y - 0.02, z)
		add_child(panel)


## Reinício: portão fechado e a cena do choque volta a tocar na próxima entrada.
func reset() -> void:
	played = false
