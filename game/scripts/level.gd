class_name Level
## Sala de teste: galpão com piso de concreto, paredes metálicas, colunas, caixas (as empilhadas têm borda
## para ficar pendurada e subir; as baixas, para escalar) e a plataforma de carga no fundo (escalar).
## Malhas subdivididas porque a luz é por vértice (como no PS1).

const TEX := {
	"concrete": preload("res://assets/textures/concrete.png"),
	"wall": preload("res://assets/textures/wall.png"),
	"crate": preload("res://assets/textures/crate.png"),
	"hazard": preload("res://assets/textures/hazard.png"),
	"chest": preload("res://assets/textures/chest.png"),
	"chest_shotgun": preload("res://assets/textures/chest_shotgun.png"),
}
const SIZE := 26.0
const WALL_H := 4.5


## Sala de um ponto no eixo X: 0 galpão, 1 pátio da mata, 2 pedreira (as divisas são as paredes das portas).
static func room_of(x: float) -> int:
	if x > -SIZE * 0.5:
		return 0
	return 1 if x > Yard.X_FAR - 0.6 else 2


## Som e alarme passam de uma sala à outra só se todas as portas entre elas estão abertas.
static func connected(tree: SceneTree, a: int, b: int) -> bool:
	for r in range(mini(a, b), maxi(a, b)):
		if not Door.is_open(tree, r):
			return false
	return true


static func material(tex: String, scale := 0.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader()
	m.set_shader_parameter("albedo_tex", TEX[tex])
	m.set_shader_parameter("world_uv", true)
	m.set_shader_parameter("world_uv_scale", scale)
	return m


static func block(parent: Node, size: Vector3, pos: Vector3, tex: String, scale := 0.5, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	# tipo de superfície para o impacto e o buraco de bala (Fx.SURFACES)
	body.set_meta("surface", tex)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	# ~1 vértice por metro para a luz por vértice não ficar "chapada"
	mesh.subdivide_width = int(size.x)
	mesh.subdivide_height = int(size.y)
	mesh.subdivide_depth = int(size.z)
	mi.mesh = mesh
	mi.material_override = material(tex, scale)
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	return body


static func build(parent: Node) -> void:
	var h := SIZE * 0.5
	block(parent, Vector3(SIZE, 0.4, SIZE), Vector3(0, -0.2, 0), "concrete", 0.35)
	for s in [-1, 1]:
		block(parent, Vector3(SIZE, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, s * h), "wall", 0.5)
		if s == 1:
			block(parent, Vector3(0.4, WALL_H, SIZE), Vector3(s * h, WALL_H * 0.5, 0), "wall", 0.5)
	# parede oeste com a porta para o pátio da mata (segunda sala) e o pátio em si
	Yard.west_wall(parent)
	Yard.build(parent)
	# a pedreira, depois do portão do pátio: última sala (alossauro)
	Arena.build(parent)
	# colunas
	for p in [Vector3(-5, 0, -4), Vector3(5, 0, -4), Vector3(-5, 0, 4), Vector3(5, 0, 4)]:
		block(parent, Vector3(0.8, WALL_H, 0.8), p + Vector3.UP * WALL_H * 0.5, "wall", 0.75)
	# caixas para cobertura
	var crates := [
		[Vector3(1.2, 1.2, 1.2), Vector3(-2.5, 0.6, -1.5), 0.2],
		[Vector3(1.2, 1.2, 1.2), Vector3(-2.3, 1.8, -1.6), -0.15],
		[Vector3(1.0, 1.0, 1.0), Vector3(3.0, 0.5, 1.0), 0.5],
		[Vector3(2.4, 1.0, 1.2), Vector3(0.5, 0.5, -7.0), 0.0],
		[Vector3(1.2, 1.2, 1.2), Vector3(8.0, 0.6, -8.5), 0.3],
		[Vector3(1.2, 1.2, 1.2), Vector3(-8.5, 0.6, 7.5), 0.0],
	]
	for c in crates:
		block(parent, c[0], c[1], "crate", 1.0 / c[0].x, c[2])
	# plataforma de carga encostada na parede do fundo (1,3 m: dá para escalar) e a faixa de perigo na frente dela
	block(parent, Vector3(6.0, 1.3, 2.0), Vector3(0, 0.65, -h + 1.2), "concrete", 0.35)
	block(parent, Vector3(6.0, 0.02, 0.6), Vector3(0, 0.01, -10.5), "hazard", 1.0)
	_details(parent)
	_lights(parent)


## Detalhes sem colisão (acima do alcance ou rente à parede): vigas, canos e luminárias.
static func _details(parent: Node) -> void:
	var h := SIZE * 0.5
	# vigas verticais encostadas nas paredes, a cada 5 m (simétricas)
	for k in range(-2, 3):
		var a := k * 5.0
		for s in [-1, 1]:
			_prop(parent, BoxMesh.new(), Vector3(0.3, WALL_H, 0.22), Vector3(a, WALL_H * 0.5, s * (h - 0.31)), "wall", 1.5)
			_prop(parent, BoxMesh.new(), Vector3(0.22, WALL_H, 0.3), Vector3(s * (h - 0.31), WALL_H * 0.5, a), "wall", 1.5)
	# canos correndo pelas paredes do fundo e da direita, com uma descida até o chão
	# (de parede a parede; o da direita fica mais baixo para não cruzar os do fundo no canto)
	for y in [3.05, 3.4]:
		_pipe(parent, Vector3(-h + 0.2, y, -h + 0.55), Vector3(h - 0.2, y, -h + 0.55), 0.09 if y > 3.2 else 0.13)
	_pipe(parent, Vector3(h - 0.55, 2.7, -h + 0.2), Vector3(h - 0.55, 2.7, h - 0.2), 0.11)
	_pipe(parent, Vector3(6.5, 3.05, -h + 0.55), Vector3(6.5, 0.0, -h + 0.55), 0.13)
	# treliças do teto (de parede a parede no eixo Z), uma sobre cada fileira de luminárias
	for x in [-7.0, 0.0, 8.0]:
		_prop(parent, BoxMesh.new(), Vector3(0.25, 0.3, SIZE - 0.4), Vector3(x, WALL_H - 0.15, 0), "wall", 1.5)
	# luminárias sobre as lâmpadas (as luzes estão em _lights): carcaça e painel aceso
	for p in [Vector3(0, 3.8, 0), Vector3(-7, 3.5, -8), Vector3(8, 3.5, 7)]:
		_prop(parent, BoxMesh.new(), Vector3(0.9, 0.16, 0.5), p + Vector3.UP * 0.35, "wall", 2.0)
		# hastes até a treliça do teto
		for dx in [-0.35, 0.35]:
			var rod: Vector3 = p + Vector3(dx, 0.43, 0)
			_pipe(parent, rod, Vector3(rod.x, WALL_H - 0.3, rod.z), 0.015)
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.75, 0.38)
		glow.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.92, 0.75)
		glow.material_override = m
		glow.rotation_degrees.x = 90.0  # virado para baixo
		glow.position = p + Vector3.UP * 0.26
		parent.add_child(glow)


static func _prop(parent: Node, mesh: PrimitiveMesh, size: Vector3, pos: Vector3, tex: String, scale := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	mi.mesh = mesh
	mi.material_override = material(tex, scale)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _pipe(parent: Node, a: Vector3, b: Vector3, radius: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = a.distance_to(b)
	c.radial_segments = 10
	c.rings = 1
	var mi := _prop(parent, c, Vector3.ZERO, (a + b) * 0.5, "wall", 2.0)
	var dir := (b - a).normalized()
	# o cilindro nasce em pé (Y): gira Y para a direção do cano
	mi.basis = Basis(Quaternion(Vector3.UP, dir)) if absf(dir.dot(Vector3.UP)) < 0.999 else Basis()


static func _lights(parent: Node) -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 0.55
	sun.light_color = Color(0.75, 0.8, 1.0)
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.add_to_group("lamps")
	parent.add_child(sun)
	var lamps := [
		[Vector3(0, 3.8, 0), Color(1.0, 0.85, 0.6), 2.2],
		[Vector3(-7, 3.5, -8), Color(0.6, 0.75, 1.0), 1.6],
		[Vector3(8, 3.5, 7), Color(1.0, 0.55, 0.35), 1.6],
	]
	for l in lamps:
		var o := OmniLight3D.new()
		o.position = l[0]
		o.light_color = l[1]
		o.light_energy = l[2]
		o.omni_range = 11.0
		o.omni_attenuation = 1.2
		o.add_to_group("lamps")
		parent.add_child(o)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.34, 0.42)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.04)
	env.fog_density = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
