class_name Level
## Galpão da primeira sala: piso de concreto, paredes de fora, o labirinto de caixas do fundo (as pilhas não se escalam;
## as caixas baixas soltas, sim) e o painel do labirinto; as salas de dentro são do Shed, o telhado do Roof.
## Malhas subdivididas porque a luz é por vértice (como no PS1).

const TEX := {
	"concrete": preload("res://assets/textures/concrete.png"),
	"wall": preload("res://assets/textures/wall.png"),
	"crate": preload("res://assets/textures/crate.png"),
	"planks": preload("res://assets/textures/planks.png"),  # tábuas de obra (torres de guarda do pátio)
	"hazard": preload("res://assets/textures/hazard.png"),
	"chest": preload("res://assets/textures/chest.png"),
	"chest_shotgun": preload("res://assets/textures/chest_shotgun.png"),
	"chest_m79": preload("res://assets/textures/chest_m79.png"),
	"drop_crate": preload("res://assets/textures/drop_crate.png"),
	"chute": preload("res://assets/textures/chute.png"),
	"explosive": preload("res://assets/textures/explosive.png"),
}
## Galpão girado (comprido no sentido do avanço; a frente da fase é -z): de WEST a EAST em x e de SOUTH (frente, o pátio
## descoberto) a NORTH (fundo, o labirinto) em z. Do pátio descoberto (SOUTH..ROOF_Z) para o fundo há telhado (Roof).
const WEST := -13.0
const EAST := 3.0
const SOUTH := -12.0
const NORTH := 68.0
const WIDTH := EAST - WEST
const DEPTH := NORTH - SOUTH
const CX := (WEST + EAST) * 0.5
const CZ := (SOUTH + NORTH) * 0.5
const ROOF_Z := 8.0  # sala dos clones para o fundo: com telhado; antes disso, o pátio descoberto
const WALL_H := 7.5
const WALL_T := 0.4  # paredes de fora
## Lâmpadas do galpão: [posição, cor, força]. Cada uma tem luminária (_details) e feixe de luz (Haze). Labirinto, estantes
## (corredores e escada) e doca; o escritório (laje baixa), a sala dos clones e o pátio descoberto têm luz própria (Shed,
## CloneLab).
const LAMPS := [
	[Vector3(-1.0, 5.6, 61.5), Color(1.0, 0.85, 0.6), 2.0],
	[Vector3(-8.2, 5.6, 58.4), Color(0.6, 0.75, 1.0), 1.6],
	[Vector3(-7.85, 5.6, 38.0), Color(0.85, 0.9, 1.0), 2.0],
	[Vector3(-3.35, 5.6, 35.0), Color(1.0, 0.7, 0.45), 1.8],
	[Vector3(1.7, 5.6, 39.5), Color(0.9, 0.95, 1.0), 1.4],
	[Vector3(-5.0, 5.6, 29.4), Color(1.0, 0.85, 0.6), 2.2],
]
const PANEL_Y := 0.26  # painel aceso da luminária acima da lâmpada


## Sala de um ponto no eixo X: 0 galpão, 1 pátio da mata, 2 túnel da mina, 3 pedreira (as divisas são as paredes das
## portas).
static func room_of(x: float) -> int:
	if x > WEST:
		return 0
	if x > Yard.X_FAR - 0.6:
		return 1
	return 2 if x > Tunnel.GATE_X else 3


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


## Monta o galpão (paredes de fora, labirinto, caixas soltas, painel), as salas de dentro (Shed), o telhado (com o
## alçapão por onde ela entra) e a sala dos clones. Devolve {"hatch": Hatch, "lab": CloneLab, "tunnel": Tunnel, "shed":
## Dictionary (Shed.build)}.
static func build(parent: Node) -> Dictionary:
	block(parent, Vector3(WIDTH, 0.4, DEPTH), Vector3(CX, -0.2, CZ), "concrete", 0.35)
	# fundo e frente inteiros; a leste os vãos das portas de serviço dos reforços (Shed.SERVICE) e a porta falsa da sala
	# dos clones (Shed.FAKE_DOOR)
	for z in [NORTH, SOUTH]:
		block(parent, Vector3(WIDTH + WALL_T, WALL_H, WALL_T), Vector3(CX, WALL_H * 0.5, z), "wall", 0.5)
	var holes := []
	for sv: Dictionary in Shed.SERVICE:
		var at: Vector3 = sv.door
		holes.append([at.z - SOUTH - Shed.SERVICE_W * 0.5, at.z - SOUTH + Shed.SERVICE_W * 0.5, at.y, at.y + Shed.SERVICE_H])
	var fk: Vector3 = Shed.FAKE_DOOR
	holes.append([fk.z - SOUTH - Shed.DOOR_W * 0.5, fk.z - SOUTH + Shed.DOOR_W * 0.5, fk.y, fk.y + Shed.DOOR_H])
	Shed.wall(parent, Vector2(EAST, SOUTH), Vector2(EAST, NORTH), 0.0, WALL_H, holes, WALL_T)
	# parede oeste com o portão para o pátio da mata (segunda sala) e o pátio em si
	Yard.west_wall(parent)
	Yard.build(parent)
	# o túnel da mina depois do portão do pátio e a pedreira no fim dele: última sala (alossauro)
	var tunnel := Tunnel.build(parent)
	Arena.build(parent)
	_dividers(parent)
	_maze(parent)
	_console(parent)
	# salas de dentro: paredes, portas e portões que abrem por objetivo, escritório, estantes, doca, pátio descoberto e as
	# saletas dos reforços (Shed)
	var shed := Shed.build(parent)
	_details(parent)
	_lights(parent)
	var lab := CloneLab.new()
	parent.add_child(lab)
	return {"hatch": Roof.build(parent), "lab": lab, "tunnel": tunnel, "shed": shed}


## Labirinto de caixas no começo da fase, no fundo do galpão (de MAZE_FRONT até a parede do fundo): a escada do alçapão
## desce no nicho do canto da direita ('L', fechado por pilhas) e a única saída é o portão de grade do meio (Shed.MID_GATE),
## depois de dar a volta inteira: corredor da linha 2 para oeste, a volta em quadrado debaixo do mezanino (Catwalk, colunas
## 0..3, linhas 0..2), o corredor da parede oeste até a frente, e o caminho em zigue-zague até o portão.
## Uma letra por célula (MAZE_CELL m; linha 0 = o fundo): '#' = pilha de duas caixas, 'Q' = pilha da quina (atrás dela,
## esgueirando, ela vê o atirador do mezanino pelo corredor da coluna 3), '.' / '_' = corredor ('_' = debaixo do
## mezanino), 'L' = pé da escada do alçapão (ela desce no vão entre a escada e a parede do fundo e sai pelo lado: a
## coluna 8 das linhas 0 e 1 fica aberta, senão a cápsula não passa entre a escada e a pilha). As pilhas passam do alcance de pendurar (Moves hang.top +
## PlayerMoves.GRAB_MAX): não dá para subir e pular o labirinto. Debaixo do mezanino a de cima é mais baixa (cabe sob o piso).
const MAZE := [
	"____.###.L",
	"_##_.###..",
	"_##_......",
	".#########",
	".#.......#",
	".#Q.#.##.#",
	"....#..#..",
]
const MAZE_CELL := Vector2(1.6, 12.0 / 7.0)  # (x, z) de cada célula
const MAZE_FRONT := NORTH - 12.0  # parede da frente do labirinto (com o portão de grade e o painel)
const MAZE_STACK := 2.7  # altura da pilha (debaixo do mezanino, até embaixo do piso dele)
const MAZE_HATCH := Vector2i(9, 0)  # célula do pé da escada do alçapão
const MAZE_Q := Vector2i(2, 5)  # a pilha da quina
## Caixas soltas pelo galpão: [centro no chão (x, z), caixas na pilha (2 = 2,4 m, tapa a visão; 1 = caixa baixa de
## LOW_CRATE_H, esconde agachada), giro]. As paredes das salas são do Shed (sólidas); estas são cobertura e pontos cegos.
const DIVIDERS := [
	# estantes: no corredor escondido da parede oeste e na frente, junto da beira da doca
	[Vector2(-12.0, 37.6), 1, 0.02], [Vector2(-7.85, 31.9), 1, -0.03],
	# pátio descoberto: caixas baixas no caminho até o portão da mata
	[Vector2(-11.0, -2.0), 1, 0.03], [Vector2(-1.8, -5.0), 1, -0.02],
]
const DIVIDER_CRATE := 1.22  # um pouco mais que o passo de 1,2 m: vizinhas encostadas, sem fresta para a visão
## Caixa baixa (sozinha ou do divisor): abaixo do cano dela mirando em pé (~1,37 m), então ela mira por cima com cabeça e
## ombros de fora (PlayerCover.OVER_MAX); agachada só o alto da cabeça (~1,3 m) passa dela e a vista dos inimigos ainda conta
## escondida (PlayerStealth.exposed_to olha o quadril); dá para escalar (heroine_moves.json mantle.max 1,6).
const LOW_CRATE_H := 1.2
## Painel de computador na parede da frente do labirinto, no nicho ao lado do portão de grade (o guarda 12 de
## Soldier.GUARDS mexe nele): ponto na face da parede, no chão, e o giro (CONSOLE_YAW: quem digita fica do lado +z).
## Bancada até CONSOLE_DESK da parede (o armário embaixo, com corpo, só até CONSOLE_BASE: a cápsula do guarda cabe na
## frente) e o teclado na altura dos punhos do guerrilheiro na animação Console (art/heroine_anims.console_keys: 1,077 m,
## 0,36 m à frente da raiz dele).
const CONSOLE := Vector3(-2.6, 0, MAZE_FRONT + 0.15)
const CONSOLE_YAW := -PI * 0.5
const CONSOLE_W := 1.1
const CONSOLE_DESK := 0.5
const CONSOLE_BASE := 0.32
const CONSOLE_KEYS_Y := 1.037  # alto do teclado (o punho fechado tem ~4 cm abaixo do centro)
const CONSOLE_SCREEN := Color(0.3, 1.0, 0.55)
const CONSOLE_GUARD := 0.74  # da face da parede até a raiz de quem digita


## Centro da célula (coluna, linha) do labirinto, no chão.
static func maze_cell(c: int, r: int) -> Vector3:
	return Vector3(WEST + (c + 0.5) * MAZE_CELL.x, 0, NORTH - (r + 0.5) * MAZE_CELL.y)


## Célula (coluna, linha) de um ponto do labirinto.
static func maze_index(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - WEST) / MAZE_CELL.x), floori((NORTH - p.z) / MAZE_CELL.y))


## Dentro do retângulo do labirinto (no plano)?
static func in_maze(p: Vector3) -> bool:
	return p.x > WEST and p.x < EAST and p.z > MAZE_FRONT and p.z < NORTH


## Célula debaixo da escada recolhida do mezanino (onde ela aperta E e lê que está trancada).
static func maze_ladder_cell() -> Vector2i:
	return maze_index(Vector3(Catwalk.LADDER_X, 0, Catwalk.FRONT_Z - 0.4))


## Ponto no chão na frente de um painel `c` (face da parede) girado `yaw` (console_at), a `dist` da parede.
static func console_stand(c: Vector3, yaw: float, dist := CONSOLE_GUARD) -> Vector3:
	return c + Vector3(cos(yaw), 0, -sin(yaw)) * dist


static func _maze(parent: Node) -> void:
	for r in MAZE.size():
		var row: String = MAZE[r]
		for c in row.length():
			if row[c] != "#" and row[c] != "Q":
				continue
			var at := maze_cell(c, r)
			# variação fixa por célula: as pilhas não ficam alinhadas como tijolos
			# vizinhas encostadas (sem fresta para a visão nem para o tiro)
			var k := float((c * 7 + r * 13) % 5) / 4.0 - 0.5
			var size := Vector3(MAZE_CELL.x + 0.02, 1.4, MAZE_CELL.y + 0.02)
			var top_h := (Catwalk.FLOOR_Y - 0.4 if Catwalk.covers(at) else MAZE_STACK) - size.y
			# no_climb (PlayerMoves.find_ledge): o labirinto não se pula por cima
			block(parent, size, at + Vector3(0, size.y * 0.5, 0), "crate", 1.0 / size.x, k * 0.03).set_meta("no_climb", true)
			var top := Vector3(size.x - 0.04, top_h, size.z - 0.04)
			block(parent, top, at + Vector3(-k * 0.02, size.y + top_h * 0.5, k * 0.02), "crate", 1.0 / top.x, -k * 0.04).set_meta("no_climb", true)


static func _dividers(parent: Node) -> void:
	for d in DIVIDERS:
		var at := Vector3(d[0].x, 0, d[0].y)
		var size := Vector3.ONE * DIVIDER_CRATE
		if d[1] == 1:
			size.y = LOW_CRATE_H
		block(parent, size, at + Vector3(0, size.y * 0.5, 0), "crate", 1.0 / size.x, d[2])
		if d[1] > 1:
			# a de cima um pouco menor e torta, como nas pilhas do labirinto
			var top := Vector3(size.x - 0.04, size.y, size.z - 0.04)
			block(parent, top, at + Vector3(0, size.y + top.y * 0.5, 0), "crate", 1.0 / top.x, -d[2] * 1.5)


## Painel de computador do labirinto (CONSOLE): armário com a bancada por cima, teclado, painel com a tela acesa e as
## luzinhas, e uma luz verde fraca na frente (o nicho não tem lâmpada: é ela que mostra o guarda).
static func _console(parent: Node) -> void:
	console_at(parent, CONSOLE, CONSOLE_YAW, true)
	# bancadas dos guardas distraídos do labirinto (Soldier.P1_BENCH / P2_BENCH): quem digita fica do lado -z
	for b: Vector3 in [Soldier.P1_BENCH, Soldier.P2_BENCH]:
		console_at(parent, b, PI * 0.5, false)


## O mesmo painel em qualquer parede: `c` = ponto no chão na face da parede, `yaw` = giro do +X (para quem digita: 0 = leste,
## -PI/2 = sul); `light` = a luz verde na frente. O teclado fica a CONSOLE_KEYS_Y (animação Console do guerrilheiro).
static func console_at(parent: Node, c: Vector3, yaw: float, light: bool) -> void:
	var pivot := Node3D.new()
	pivot.position = c
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var keys_y := CONSOLE_KEYS_Y
	var desk_y := keys_y - 0.03
	block(pivot, Vector3(CONSOLE_BASE, desk_y - 0.04, CONSOLE_W - 0.1), Vector3(CONSOLE_BASE * 0.5, (desk_y - 0.04) * 0.5, 0), "wall", 0.75)
	_prop(pivot, BoxMesh.new(), Vector3(CONSOLE_DESK, 0.04, CONSOLE_W + 0.1), Vector3(CONSOLE_DESK * 0.5, desk_y - 0.02, 0), "wall", 1.5)
	var kb := _prop(pivot, BoxMesh.new(), Vector3(0.16, 0.03, 0.46), Vector3(CONSOLE_DESK - 0.12, desk_y + 0.015, 0), "wall", 3.0)
	(kb.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.25, 0.25, 0.28))  # teclado escuro
	# painel na parede, tela inclinada para quem está na bancada
	_prop(pivot, BoxMesh.new(), Vector3(0.1, 0.8, CONSOLE_W), Vector3(0.05, keys_y + 0.55, 0), "wall", 1.5)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.albedo_color = CONSOLE_SCREEN
	var screen := _glow(pivot, Vector2(0.62, 0.4), Vector3(0.105, keys_y + 0.62, 0), lit)
	# linhas de texto escuras na tela
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = CONSOLE_SCREEN.darkened(0.7)
	for i in 6:
		var w := [0.42, 0.3, 0.5, 0.22, 0.36, 0.14][i] as float
		var line := _glow(screen, Vector2(w, 0.022), Vector3(-0.25 + w * 0.5, 0.14 - i * 0.05, 0.002), ink)
		line.rotation = Vector3.ZERO
	# luzinhas embaixo da tela
	for i in 3:
		var led := StandardMaterial3D.new()
		led.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		led.albedo_color = [Color(1, 0.2, 0.15), Color(1, 0.75, 0.2), CONSOLE_SCREEN][i]
		_glow(pivot, Vector2(0.035, 0.035), Vector3(0.105, keys_y + 0.32, -0.2 + i * 0.08), led)
	if light:
		var o := OmniLight3D.new()
		o.position = Vector3(0.6, keys_y + 0.6, 0)
		o.light_color = CONSOLE_SCREEN
		o.light_energy = 0.7
		o.omni_range = 3.0
		pivot.add_child(o)


## Quadro aceso virado para longe da parede oeste (+X).
static func _glow(parent: Node, size: Vector2, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.rotation_degrees.y = 90.0
	mi.position = pos
	parent.add_child(mi)
	return mi


## Detalhes sem colisão (acima do alcance ou rente à parede): vigas, canos e luminárias.
static func _details(parent: Node) -> void:
	# vigas verticais encostadas nas paredes de fora, a cada 5 m (fora dos vãos do portão da mata e das portas a leste)
	var free_w := func(z: float) -> bool: return absf(z - Yard.DOOR_Z) > Yard.DOOR_W * 0.5 + 0.3
	var free_e := func(z: float) -> bool:
		for sv: Dictionary in Shed.SERVICE:
			if absf(z - sv.door.z) < Shed.SERVICE_W * 0.5 + 0.3:
				return false
		return absf(z - Shed.FAKE_DOOR.z) > Shed.DOOR_W * 0.5 + 0.3
	var z := SOUTH + 2.5
	while z < NORTH - 1.0:
		if free_w.call(z):
			_prop(parent, BoxMesh.new(), Vector3(0.22, WALL_H, 0.3), Vector3(WEST + 0.31, WALL_H * 0.5, z), "wall", 1.5)
		if free_e.call(z):
			_prop(parent, BoxMesh.new(), Vector3(0.22, WALL_H, 0.3), Vector3(EAST - 0.31, WALL_H * 0.5, z), "wall", 1.5)
		z += 5.0
	# canos correndo pelas paredes de fora, altos (acima das estantes e da cabine), com uma descida até o chão no fundo
	for y in [6.55, 6.76]:
		_pipe(parent, Vector3(WEST + 0.4, y, ROOF_Z + 0.3), Vector3(WEST + 0.4, y, NORTH - 0.3), 0.09 if y > 6.6 else 0.13)
	_pipe(parent, Vector3(EAST - 0.4, 6.9, SOUTH + 0.3), Vector3(EAST - 0.4, 6.9, NORTH - 0.3), 0.11)
	_pipe(parent, Vector3(WEST + 0.4, 6.55, NORTH - 0.6), Vector3(WEST + 0.4, 3.2, NORTH - 0.6), 0.13)
	# treliças do teto (de parede a parede no eixo X), da sala dos clones para o fundo (o pátio descoberto não tem teto)
	z = ROOF_Z + 3.0
	while z < NORTH:
		_prop(parent, BoxMesh.new(), Vector3(WIDTH - 0.4, 0.3, 0.25), Vector3(CX, WALL_H - 0.15, z), "wall", 1.5)
		z += 6.0
	# luminárias sobre as lâmpadas (as luzes estão em _lights): carcaça e painel aceso
	for l in LAMPS:
		var p: Vector3 = l[0]
		_prop(parent, BoxMesh.new(), Vector3(0.9, 0.16, 0.5), p + Vector3.UP * 0.35, "wall", 2.0)
		# hastes até o teto
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
	# ar pesado: feixe de luz e halo debaixo de cada painel e névoa rala no galpão coberto (o pátio descoberto fica de fora)
	Haze.build(parent, LAMPS.map(func(l: Array) -> Array: return [l[0] + Vector3.UP * PANEL_Y, l[1], l[2]]))
	Haze.air(parent, Vector3(CX, 0, (ROOF_Z + NORTH) * 0.5), Vector3(WIDTH - 0.8, WALL_H, NORTH - ROOF_Z - 0.8))


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
	sun.light_energy = 0.85
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
	env.ambient_light_energy = 0.5
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
