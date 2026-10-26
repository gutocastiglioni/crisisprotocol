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
	"chest_m79": preload("res://assets/textures/chest_m79.png"),
	"drop_crate": preload("res://assets/textures/drop_crate.png"),
	"chute": preload("res://assets/textures/chute.png"),
}
const SIZE := 26.0
const WALL_H := 5.2
## Lâmpadas do galpão: [posição, cor, força]. Cada uma tem luminária (_details) e feixe de luz (Haze).
const LAMPS := [
	[Vector3(0, 3.8, 0), Color(1.0, 0.85, 0.6), 2.2],
	[Vector3(-7, 3.5, -8), Color(0.6, 0.75, 1.0), 1.6],
	[Vector3(8, 3.5, 7), Color(1.0, 0.55, 0.35), 1.6],
]
const PANEL_Y := 0.26  # painel aceso da luminária acima da lâmpada


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


## Monta o galpão, o telhado (com o alçapão por onde ela entra) e a sala dos clones atrás da plataforma de carga.
## Devolve {"hatch": Hatch, "lab": CloneLab}.
static func build(parent: Node) -> Dictionary:
	var h := SIZE * 0.5
	block(parent, Vector3(SIZE, 0.4, SIZE), Vector3(0, -0.2, 0), "concrete", 0.35)
	block(parent, Vector3(SIZE, WALL_H, 0.4), Vector3(0, WALL_H * 0.5, h), "wall", 0.5)
	block(parent, Vector3(0.4, WALL_H, SIZE), Vector3(h, WALL_H * 0.5, 0), "wall", 0.5)
	_north_wall(parent)
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
	_dividers(parent)
	_maze(parent)
	# plataforma de carga encostada na parede do fundo (1,3 m: dá para escalar; o portão da sala dos clones fica atrás dela)
	# e a faixa de perigo na frente dela
	block(parent, Vector3(6.0, CloneLab.FLOOR_Y, 2.0), Vector3(0, CloneLab.FLOOR_Y * 0.5, -h + 1.2), "concrete", 0.35)
	block(parent, Vector3(6.0, 0.02, 0.6), Vector3(0, 0.01, -10.5), "hazard", 1.0)
	_details(parent)
	_lights(parent)
	var lab := CloneLab.new()
	parent.add_child(lab)
	return {"hatch": Roof.build(parent), "lab": lab}


## Parede do fundo (norte) com o vão do portão da sala dos clones na altura da plataforma de carga.
static func _north_wall(parent: Node) -> void:
	var h := SIZE * 0.5
	var gw := CloneLab.GATE_W * 0.5
	var side := h - gw
	for s in [-1, 1]:
		block(parent, Vector3(side, WALL_H, 0.4), Vector3(s * (gw + side * 0.5), WALL_H * 0.5, -h), "wall", 0.5)
	block(parent, Vector3(gw * 2.0, CloneLab.FLOOR_Y, 0.4), Vector3(0, CloneLab.FLOOR_Y * 0.5, -h), "wall", 0.5)
	var top := WALL_H - CloneLab.GATE_TOP
	block(parent, Vector3(gw * 2.0, top, 0.4), Vector3(0, CloneLab.GATE_TOP + top * 0.5, -h), "wall", 0.5)


## Labirinto de caixas no começo da fase, no fundo do galpão: a escada do telhado desce no canto da direita (última
## coluna, linha de trás) e a única saída é pela esquerda, por baixo do mezanino (coluna 0, linha de trás).
## Uma letra por célula de MAZE_CELL m: '#' = pilha de duas caixas, '.' = corredor.
## A escada do mezanino (`maze_ladder_cell`) fica num nicho à parte, que só abre para o galpão (a fresta na frente):
## do labirinto não se chega nela (os lados são caixa e atrás dela uma parede de caixas, `_seal`, fecha o vão para o
## corredor de baixo do mezanino). Para pegar o sniper por trás ela sai do labirinto e dá a volta por fora.
## As pilhas passam do alcance de pendurar (Moves hang.top + PlayerMoves.GRAB_MAX): não dá para subir e pular o labirinto.
## Debaixo do mezanino a de cima é mais baixa (cabe sob o piso dele).
const MAZE := [
	"#####.######",
	"#...#.#....#",
	"#.#.#.#.##.#",
	"..#.....##..",
]
const MAZE_CELL := 1.6
const MAZE_X0 := -5.6  # centro da coluna 0
const MAZE_Z0 := 7.2  # centro da linha 0 (a frente)
const MAZE_STACK := 2.7  # altura da pilha (2,6 debaixo do mezanino)
## Caixas que dividem o galpão: [centro no chão (x, z), caixas na pilha (2 = 2,4 m, tapa a visão; 1 = só esconde
## agachada), giro]. Cercam o canto da porta do pátio (Soldier.GUARDS) com uma parede ao sul (z = 0,4) e outra a leste
## (x = -3,75), cada uma com um vão de 1,6 m (x = -8,4 / z = -8,4); a terceira entrada é a quina perto da coluna.
## Dentro, caixas baixas para chegar agachada; fora, uma parede curta separa o canto do baú da M16 do meio do galpão.
const DIVIDERS := [
	[Vector2(-12.2, 0.4), 2, 0.02], [Vector2(-11.0, 0.4), 2, -0.03], [Vector2(-9.8, 0.4), 2, 0.01],
	[Vector2(-7.0, 0.4), 2, -0.02], [Vector2(-5.8, 0.4), 1, 0.03],
	[Vector2(-3.75, -12.2), 2, 0.03], [Vector2(-3.75, -11.0), 2, -0.01], [Vector2(-3.75, -9.8), 1, 0.02],
	[Vector2(-3.75, -7.0), 2, -0.03], [Vector2(-3.75, -5.8), 2, 0.01],
	[Vector2(-7.4, -3.6), 1, 0.25], [Vector2(-9.6, -5.2), 1, -0.2], [Vector2(-6.4, -11.4), 1, 0.1],
	# parede curta separando o canto do baú da M16 do meio do galpão (termina em x = 9: a ronda da ala leste passa ao lado)
	[Vector2(6.0, -2.6), 2, 0.02], [Vector2(7.2, -2.6), 2, -0.02], [Vector2(8.4, -2.6), 1, 0.04],
]
const DIVIDER_CRATE := 1.22  # um pouco mais que o passo de 1,2 m: vizinhas encostadas, sem fresta para a visão


## Centro da célula (coluna, linha) do labirinto, no chão.
static func maze_cell(c: int, r: int) -> Vector3:
	return Vector3(MAZE_X0 + c * MAZE_CELL, 0, MAZE_Z0 + r * MAZE_CELL)


## Célula do nicho onde fica o pé da escada do mezanino.
static func maze_ladder_cell() -> Vector2i:
	return Vector2i(roundi((Catwalk.LADDER_X - MAZE_X0) / MAZE_CELL), roundi((Catwalk.FRONT_Z - 0.4 - MAZE_Z0) / MAZE_CELL))


static func _maze(parent: Node) -> void:
	_seal(parent)
	for r in MAZE.size():
		var row: String = MAZE[r]
		for c in row.length():
			if row[c] != "#":
				continue
			var at := maze_cell(c, r)
			# variação fixa por célula: as pilhas não ficam alinhadas como tijolos
			# vizinhas encostadas (sem fresta para a visão nem para o tiro)
			var k := float((c * 7 + r * 13) % 5) / 4.0 - 0.5
			var size := Vector3(MAZE_CELL + 0.02, 1.4, MAZE_CELL + 0.02)
			var under := absf(at.x) - size.x * 0.5 < Catwalk.PLATFORM_W * 0.5 and at.z + size.z * 0.5 > Catwalk.FRONT_Z
			var top_h := (Catwalk.FLOOR_Y - 0.4 if under else MAZE_STACK) - size.y
			block(parent, size, at + Vector3(0, size.y * 0.5, 0), "crate", 1.0 / size.x, k * 0.03)
			var top := Vector3(size.x - 0.04, top_h, size.z - 0.04)
			block(parent, top, at + Vector3(-k * 0.02, size.y + top_h * 0.5, k * 0.02), "crate", 1.0 / top.x, -k * 0.04)


static func _dividers(parent: Node) -> void:
	for d in DIVIDERS:
		var at := Vector3(d[0].x, 0, d[0].y)
		var size := Vector3.ONE * DIVIDER_CRATE
		block(parent, size, at + Vector3(0, size.y * 0.5, 0), "crate", 1.0 / size.x, d[2])
		if d[1] > 1:
			# a de cima um pouco menor e torta, como nas pilhas do labirinto
			var top := Vector3(size.x - 0.04, size.y, size.z - 0.04)
			block(parent, top, at + Vector3(0, size.y + top.y * 0.5, 0), "crate", 1.0 / top.x, -d[2] * 1.5)


## Parede de caixas logo atrás da escada do mezanino, do chão até embaixo do piso dele: o nicho da escada não se liga ao
## corredor de baixo do mezanino.
static func _seal(parent: Node) -> void:
	var at := maze_cell(maze_ladder_cell().x, 0)
	var h := Catwalk.FLOOR_Y - 0.4
	var depth := MAZE_Z0 + (maze_ladder_cell().y + 0.5) * MAZE_CELL - (Catwalk.FRONT_Z + 0.1)
	var size := Vector3(MAZE_CELL + 0.02, h, depth)
	block(parent, size, Vector3(at.x, h * 0.5, Catwalk.FRONT_Z + 0.1 + depth * 0.5), "crate", 1.0 / size.x)


## Detalhes sem colisão (acima do alcance ou rente à parede): vigas, canos e luminárias.
static func _details(parent: Node) -> void:
	var h := SIZE * 0.5
	# vigas verticais encostadas nas paredes, a cada 5 m (simétricas)
	for k in range(-2, 3):
		var a := k * 5.0
		for s in [-1, 1]:
			if s == -1 and absf(a) < CloneLab.GATE_W * 0.5:
				continue  # vão do portão da sala dos clones
			_prop(parent, BoxMesh.new(), Vector3(0.3, WALL_H, 0.22), Vector3(a, WALL_H * 0.5, s * (h - 0.31)), "wall", 1.5)
			_prop(parent, BoxMesh.new(), Vector3(0.22, WALL_H, 0.3), Vector3(s * (h - 0.31), WALL_H * 0.5, a), "wall", 1.5)
	# canos correndo pelas paredes do fundo e da direita, com uma descida até o chão
	# (de parede a parede; os do fundo passam por cima do portão da sala dos clones; o da direita fica mais baixo para não
	# cruzar os do fundo no canto)
	for y in [4.55, 4.76]:
		_pipe(parent, Vector3(-h + 0.2, y, -h + 0.55), Vector3(h - 0.2, y, -h + 0.55), 0.09 if y > 4.6 else 0.13)
	_pipe(parent, Vector3(h - 0.55, 2.7, -h + 0.2), Vector3(h - 0.55, 2.7, h - 0.2), 0.11)
	_pipe(parent, Vector3(6.5, 4.55, -h + 0.55), Vector3(6.5, 0.0, -h + 0.55), 0.13)
	# treliças do teto (de parede a parede no eixo Z), uma sobre cada fileira de luminárias
	for x in [-7.0, 0.0, 8.0]:
		_prop(parent, BoxMesh.new(), Vector3(0.25, 0.3, SIZE - 0.4), Vector3(x, WALL_H - 0.15, 0), "wall", 1.5)
	# luminárias sobre as lâmpadas (as luzes estão em _lights): carcaça e painel aceso
	for l in LAMPS:
		var p: Vector3 = l[0]
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
		glow.position = p + Vector3.UP * PANEL_Y
		parent.add_child(glow)
	# ar pesado: feixe de luz e halo debaixo de cada painel
	Haze.build(parent, LAMPS.map(func(l: Array) -> Array: return [l[0] + Vector3.UP * PANEL_Y, l[1], l[2]]))


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
	for l in LAMPS:
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
	# névoa volumétrica só onde há FogVolume (a neblina rasteira do pátio, Yard._mist)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 80.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
