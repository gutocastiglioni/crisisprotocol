class_name Yard
## Segunda sala: o pátio da mata, ao oeste do galpão (porta na parede oeste). Clareira de terra e capim cercada
## de mata fechada, com uma estrada de terra batida que sai da porta e vai até um portão de ferro no fundo,
## árvores, arbustos, samambaias, pedras, troncos caídos e touceiras de capim alto (grupo "cover": agachada
## ali dentro, ela é vista de bem menos longe). No meio, numa clareira (CLEARING), o guerrilheiro morto com a chave
## do container (CORPSE, Corpse); os 3 velociraptors (POSTS) esperam escondidos nas moitas da beira dela (LURK) até a
## emboscada e depois usam as rotas de patrulha. Tudo o que bloqueia fica na camada 1 (como o galpão); a malha de navegação dos raptors sai de lá
## (bake_nav). Texturas em tools/make_level_textures.py. O portão do fundo dá na pedreira (Arena), a última sala; uma
## torre de guarda de cada lado dele (TOWERS, GuardTower: o main as monta e põe um sniper em cada depois da emboscada).

const TEX := {
	"grass": preload("res://assets/textures/grass.png"),
	"dirt": preload("res://assets/textures/dirt.png"),
	"bark": preload("res://assets/textures/bark.png"),
	"leaves": preload("res://assets/textures/leaves.png"),
	"rock": preload("res://assets/textures/rock.png"),
	"grass_card": preload("res://assets/textures/grass_card.png"),
	"fern_card": preload("res://assets/textures/fern_card.png"),
	"wall": preload("res://assets/textures/wall.png"),
}
const DOOR_Z := -8.5  # centro do portão na parede oeste do galpão (mais ao fundo da fase)
const DOOR_W := 3.2
const DOOR_H := 2.8
const X_NEAR := -13.0  # a clareira começa onde acaba o piso do galpão
const X_FAR := -55.0
const Z_HALF := 18.0
## Eixo da estrada (de terra batida), da porta até o portão.
const ROAD := [Vector2(-13.5, -8.5), Vector2(-24, -8.5), Vector2(-34, -9.5), Vector2(-45, -9.5), Vector2(-50, -3.0), Vector2(-54, -3.0)]
const ROAD_W := 4.0
const GATE_GAP := 4.4  # vão na parede do fundo, no portão (largura)
const GATE_X := X_FAR - 1.1  # o portão fecha o vão da parede do fundo (parede em X_FAR - 1,1)
const GATE_H := 4.7  # altura das folhas de chapa (acima, a viga de concreto até o topo dos paredões)
const GATE_KEY := "allo_gate"  # id do cartão que liga o teclado do portão (cai do último sniper das torres)
const MIST_H := 4.0  # altura do volume da neblina rasteira (do chão para cima; mais grossa embaixo)
const MIST_DENSITY := 0.05
## Onde cada raptor começa e a rota de patrulha dele (pontos em chão livre, longe das árvores).
const POSTS := [
	{"pos": Vector3(-24, 0, -2.5), "route": [Vector3(-24, 0, -2.5), Vector3(-31.6, 0, -7.4), Vector3(-42, 0, -9.5), Vector3(-31.6, 0, -7.4)]},
	{"pos": Vector3(-26, 0, 9), "route": [Vector3(-26, 0, 9), Vector3(-36, 0, 13), Vector3(-45, 0, 8), Vector3(-36, 0, 5)]},
	{"pos": Vector3(-28, 0, -13), "route": [Vector3(-28, 0, -13), Vector3(-38, 0, -14.5), Vector3(-48, 0, -13), Vector3(-40, 0, -12)]},
]
const LAMPS := [Vector3(-21, 0, -6.5), Vector3(-40, 0, -6.2), Vector3(-47.5, 0, 1.0)]
## Guerrilheiro morto com a chave do container (Corpse), no meio da clareira, perto da estrada e de um poste; em volta,
## CLEARING metros sem nada sólido (os raptors da emboscada entram e rodeiam ela ali). CORPSE_YAW 0: a cabeça dele para
## o norte (+Z), a mão da chave para o leste (de onde ela vem pela estrada).
const CORPSE := Vector3(-35.5, 0, -3.0)
const CORPSE_YAW := 0.0
const CLEARING := 10.5
## Onde cada raptor do pátio fica escondido até a emboscada (dentro de uma moita sem colisão, na beira da clareira).
const LURK := [Vector3(-35.0, 0, 6.5), Vector3(-44.5, 0, -6.0), Vector3(-27.0, 0, 3.0)]
## Torres de guarda (GuardTower) dos dois lados do portão do fundo, encostadas na parede, a frente para o pátio. Em volta
## delas não fica árvore (TOWER_TREES m: a copa entraria no telhado) nem outra coisa sólida (TOWER_CLEAR m).
const TOWERS := [Vector3(-54.1, 0, 1.6), Vector3(-54.1, 0, -7.6)]
const TOWER_TREES := 4.5
const TOWER_CLEAR := 3.0

static var _mats := {}


static func material(tex: String, scale := 0.5, world := true, two_sided := false) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [tex, scale, world, two_sided]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader(two_sided)
	m.set_shader_parameter("albedo_tex", TEX[tex])
	m.set_shader_parameter("world_uv", world)
	m.set_shader_parameter("world_uv_scale", scale)
	_mats[key] = m
	return m


# ------------------------------------------------------------------ parede com a porta
## Parede oeste do galpão (no lugar do bloco inteiro de Level.build) com a abertura da porta.
static func west_wall(parent: Node) -> void:
	var h := Level.SIZE * 0.5
	var z0 := DOOR_Z - DOOR_W * 0.5
	var z1 := DOOR_Z + DOOR_W * 0.5
	var t := 0.4
	_box(parent, Vector3(t, Level.WALL_H, z0 + h), Vector3(-h, Level.WALL_H * 0.5, (z0 - h) * 0.5), "wall", 0.5)
	_box(parent, Vector3(t, Level.WALL_H, h - z1), Vector3(-h, Level.WALL_H * 0.5, (z1 + h) * 0.5), "wall", 0.5)
	var lintel := Level.WALL_H - DOOR_H
	_box(parent, Vector3(t, lintel, DOOR_W), Vector3(-h, DOOR_H + lintel * 0.5, DOOR_Z), "wall", 0.5)
	# batentes (só visual) e a faixa de perigo na soleira
	for z in [z0 + 0.12, z1 - 0.12]:
		_prop(parent, _bm(Vector3(0.5, DOOR_H, 0.24)), Vector3(-h, DOOR_H * 0.5, z), "wall", 1.5)
	_prop(parent, _bm(Vector3(1.0, 0.02, DOOR_W)), Vector3(-h, 0.01, DOOR_Z), "wall", 1.0)
	# portão de segurança trancado com leitor por aproximação (abre com o keycard do sniper)
	var door := Door.create(parent, Vector3(-h, 0, DOOR_Z), Vector3(t, DOOR_H, DOOR_W), 0, "ABRIR PORTÃO")
	door.lock = "keycard_gate"
	door.is_locked_door = true
	door.add_card_reader(Vector3(0.24, 1.35, DOOR_W * 0.5 + 0.35), 0.0)
	var slab := Node3D.new()
	slab.add_child(_prop_at(_bm(Vector3(0.14, DOOR_H, DOOR_W - 0.1)), Vector3(0, DOOR_H * 0.5, 0), "wall", 1.0))
	for y in [0.4, 1.2, 2.0, 2.6]:
		slab.add_child(_prop_at(_bm(Vector3(0.22, 0.10, DOOR_W - 0.1)), Vector3(0, y, 0), "wall", 2.0))
	for k in 5:
		slab.add_child(_prop_at(_bm(Vector3(0.18, DOOR_H - 0.2, 0.08)), Vector3(0, DOOR_H * 0.5, (DOOR_W - 0.4) * (k / 4.0 - 0.5)), "wall", 2.0))
	slab.add_child(_prop_at(_bm(Vector3(0.18, 0.22, DOOR_W - 0.1)), Vector3(0, 0.7, 0), "wall", 1.0))
	door.add_panel(slab, Vector3(0, 0, DOOR_W + 0.2), 0.0)


# ------------------------------------------------------------------ construção
static func build(parent: Node) -> void:
	_mats.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260418
	var cx := (X_NEAR + X_FAR - 1.6) * 0.5
	var len_x := X_NEAR - X_FAR + 1.6
	# chão da clareira (dos lados, um pouco além da mata, para nunca aparecer o vazio; no fundo, até a pedreira)
	_box(parent, Vector3(len_x, 0.4, Z_HALF * 2.0 + 14.0), Vector3(cx, -0.2, 0), "grass", 0.5)
	_road(parent)
	_boundary(parent)
	_scatter(parent, rng)
	_gate(parent)
	_mist(parent)
	_lamps(parent)
	for post in POSTS:
		_grass_patch(parent, post.route[1] + Vector3(2.5, 0, 2.0), 2.2, rng)
	for p: Vector3 in LURK:
		_lurk_bush(parent, p, rng)
	for c in [Vector3(-20, 0, 8), Vector3(-30, 0, 4.5), Vector3(-44, 0, 2), Vector3(-34, 0, -13), Vector3(-50, 0, 12), Vector3(-22, 0, -11), Vector3(-41, 0, 9)]:
		_grass_patch(parent, c, rng.randf_range(2.0, 2.8), rng)


static func _road(parent: Node) -> void:
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		var dir := b - a
		var plane := PlaneMesh.new()
		plane.size = Vector2(ROAD_W, dir.length())
		plane.subdivide_depth = int(dir.length())
		plane.subdivide_width = 3
		var mi := MeshInstance3D.new()
		mi.mesh = plane
		mi.material_override = material("dirt", 0.5)
		mi.position = Vector3((a.x + b.x) * 0.5, 0.02, (a.y + b.y) * 0.5)
		mi.rotation.y = atan2(dir.x, dir.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	# curvas: um disco em cada ponto emenda os trechos (a textura é pelo mundo, então não aparece a emenda)
	for i in range(1, ROAD.size() - 1):
		var c := CylinderMesh.new()
		c.top_radius = ROAD_W * 0.5
		c.bottom_radius = ROAD_W * 0.5
		c.height = 0.01
		c.radial_segments = 14
		c.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = c
		mi.material_override = material("dirt", 0.5)
		mi.position = Vector3(ROAD[i].x, 0.02, ROAD[i].y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Distância de um ponto do chão (x, z) ao eixo da estrada.
static func road_distance(p: Vector2) -> float:
	var best := INF
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


## Limites: paredes invisíveis (para ninguém sair) e, por cima delas, mata fechada (árvores altas e arbustos).
static func _boundary(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var far_x := X_FAR - 0.6
	for s in [-1, 1]:
		_wall_box(parent, Vector3(len_x(), 6.0, 1.0), Vector3((X_NEAR + far_x) * 0.5, 3.0, s * (Z_HALF + 0.5)))
		# a parede do galpão continua até o canto da clareira
		_box(parent, Vector3(0.4, Level.WALL_H, Z_HALF - Level.SIZE * 0.5 + 0.5), Vector3(X_NEAR, Level.WALL_H * 0.5, s * (Level.SIZE * 0.5 + (Z_HALF - Level.SIZE * 0.5 + 0.5) * 0.5 - 0.25)), "wall", 0.5)
	# parede do fundo em dois pedaços: o vão do portão fica livre para a pedreira
	var gz: float = ROAD[ROAD.size() - 1].y
	var z0 := -Z_HALF - 1.0
	var z1 := Z_HALF + 1.0
	var g0 := gz - GATE_GAP * 0.5
	var g1 := gz + GATE_GAP * 0.5
	_wall_box(parent, Vector3(1.0, 6.0, g0 - z0), Vector3(far_x - 0.5, 3.0, (z0 + g0) * 0.5))
	_wall_box(parent, Vector3(1.0, 6.0, z1 - g1), Vector3(far_x - 0.5, 3.0, (g1 + z1) * 0.5))
	# duas fileiras de árvores nas três bordas (a de fora é só cenário)
	var x := X_NEAR - 3.0
	while x > far_x - 1.0:
		for s in [-1, 1]:
			_tree(parent, Vector3(x + rng.randf_range(-0.5, 0.5), 0, s * (Z_HALF - 0.8 + rng.randf_range(-0.4, 0.4))), rng.randf_range(8.0, 10.5), rng.randf_range(2.2, 3.0), rng, true)
			_tree(parent, Vector3(x + rng.randf_range(-1.0, 1.0), 0, s * (Z_HALF + 3.5 + rng.randf_range(-0.6, 0.6))), rng.randf_range(9.0, 11.5), rng.randf_range(2.6, 3.4), rng, false)
			_bush(parent, Vector3(x + 1.3, 0, s * (Z_HALF - 1.6)), rng.randf_range(0.8, 1.2), rng)
		x -= rng.randf_range(2.4, 3.0)
	var z := -Z_HALF + 2.0
	while z < Z_HALF - 1.5:
		# nada na frente do portão (ele abre para a pedreira)
		if absf(z - gz) < GATE_GAP:
			z += rng.randf_range(2.4, 3.0)
			continue
		# (atrás desta fileira já é a pedreira: sem a segunda fileira de enfeite)
		_off_towers(_tree(parent, Vector3(far_x + 1.0 + rng.randf_range(-0.4, 0.4), 0, z), rng.randf_range(8.0, 10.5), rng.randf_range(2.2, 3.0), rng, true), TOWER_TREES)
		if absf(z - gz) > 3.2:
			_off_towers(_bush(parent, Vector3(far_x + 2.2, 0, z + 1.2), rng.randf_range(0.8, 1.2), rng), TOWER_CLEAR)
		z += rng.randf_range(2.4, 3.0)


static func len_x() -> float:
	return X_NEAR - X_FAR + 1.2


## Árvores, arbustos, samambaias, pedras e troncos soltos no meio da clareira, longe da estrada, das rotas e da porta.
static func _scatter(parent: Node, rng: RandomNumberGenerator) -> void:
	var keep: Array[Vector2] = []  # pontos livres (rotas, lâmpadas, porta) com raio
	for post in POSTS:
		for p: Vector3 in post.route:
			keep.append(Vector2(p.x, p.z))
	for p: Vector3 in LAMPS:
		keep.append(Vector2(p.x, p.z))
	keep.append(Vector2(-15.5, DOOR_Z))
	var placed: Array[Vector2] = []
	var tries := 0
	var corpse := Vector2(CORPSE.x, CORPSE.z)
	while placed.size() < 30 and tries < 600:
		tries += 1
		var p := Vector2(rng.randf_range(X_FAR + 3.0, X_NEAR - 3.0), rng.randf_range(-Z_HALF + 3.5, Z_HALF - 3.5))
		if not _clear(p, placed, keep, 3.6) or p.distance_to(corpse) < CLEARING:
			continue
		placed.append(p)
		var roll := rng.randf()
		var pos := Vector3(p.x, 0, p.y)
		if roll < 0.5:
			_off_towers(_tree(parent, pos, rng.randf_range(5.5, 8.0), rng.randf_range(1.8, 2.6), rng, true), TOWER_TREES)
		elif roll < 0.72:
			_off_towers(_bush(parent, pos, rng.randf_range(0.9, 1.4), rng), TOWER_CLEAR)
		elif roll < 0.88:
			_off_towers(_rock(parent, pos, rng.randf_range(0.5, 1.1), rng), TOWER_CLEAR)
		else:
			_off_towers(_log(parent, pos, rng.randf_range(2.4, 3.6), rng.randf() * PI), TOWER_CLEAR)
	# samambaias e capim ralo: de enfeite, sem colisão, também fora da estrada
	for i in 120:
		var p := Vector2(rng.randf_range(X_FAR + 1.5, X_NEAR - 1.0), rng.randf_range(-Z_HALF + 1.0, Z_HALF - 1.0))
		if road_distance(p) < ROAD_W * 0.5 + 0.2 or p.distance_to(corpse) < 2.2:
			continue
		var tuft := rng.randf() < 0.5
		_card_pair(parent, Vector3(p.x, 0, p.y), "fern_card" if tuft else "grass_card", rng.randf_range(0.9, 1.5) if tuft else rng.randf_range(0.5, 0.8), rng.randf() * PI)
	# pedrinhas e tufos na beira da estrada
	for i in 50:
		var seg := rng.randi_range(0, ROAD.size() - 2)
		var a: Vector2 = ROAD[seg]
		var b: Vector2 = ROAD[seg + 1]
		var along := a.lerp(b, rng.randf())
		var side := (b - a).normalized().orthogonal() * (ROAD_W * 0.5 + rng.randf_range(-0.3, 0.6)) * (1.0 if rng.randf() < 0.5 else -1.0)
		var q := along + side
		if rng.randf() < 0.5:
			_rock(parent, Vector3(q.x, 0, q.y), rng.randf_range(0.12, 0.28), rng, false)
		else:
			_card_pair(parent, Vector3(q.x, 0, q.y), "grass_card", rng.randf_range(0.4, 0.7), rng.randf() * PI)


## Tira `node` se ficou a menos de `gap` m de uma torre de guarda (depois de montado: o sorteio do resto da mata fica igual).
static func _off_towers(node: Node3D, gap: float) -> void:
	for t: Vector3 in TOWERS:
		if Vector2(node.position.x - t.x, node.position.z - t.z).length() < gap:
			node.free()
			return


static func _clear(p: Vector2, placed: Array[Vector2], keep: Array[Vector2], gap: float) -> bool:
	if road_distance(p) < ROAD_W * 0.5 + 1.2:
		return false
	for k in keep:
		if p.distance_to(k) < 3.0:
			return false
	for q in placed:
		if p.distance_to(q) < gap:
			return false
	return true


# ------------------------------------------------------------------ peças
static func _tree(parent: Node, pos: Vector3, h: float, crown: float, rng: RandomNumberGenerator, solid: bool) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "crate")
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.32
		shape.height = h * 0.9
		col.shape = shape
		col.position.y = h * 0.45
		body.add_child(col)
		root = body
	else:
		root = Node3D.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.17
	trunk.bottom_radius = 0.34
	trunk.height = h * 0.85
	trunk.radial_segments = 8
	trunk.rings = 3
	var tm := MeshInstance3D.new()
	tm.mesh = trunk
	tm.material_override = material("bark", 0.8)
	tm.position.y = h * 0.425
	root.add_child(tm)
	# copa: três bolotas de folhas em alturas e lados diferentes
	for k in 3:
		var r := crown * (1.0 - 0.18 * k) * rng.randf_range(0.9, 1.1)
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 1.5
		s.radial_segments = 9
		s.rings = 5
		var mi := MeshInstance3D.new()
		mi.mesh = s
		mi.material_override = material("leaves", 0.7)
		var off := Vector2.from_angle(rng.randf() * TAU) * crown * 0.3 * (1 if k > 0 else 0)
		mi.position = Vector3(off.x, h * (0.68 + 0.14 * k), off.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	parent.add_child(root)
	root.position = pos
	return root


static func _bush(parent: Node, pos: Vector3, r: float, rng: RandomNumberGenerator) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r * 0.75
	shape.height = r * 1.2
	col.shape = shape
	col.position.y = r * 0.6
	body.add_child(col)
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.4
	s.radial_segments = 8
	s.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = material("leaves", 1.0)
	mi.position.y = r * 0.55
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rng.randf() * TAU
	return body


static func _rock(parent: Node, pos: Vector3, r: float, rng: RandomNumberGenerator, solid := true) -> Node3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * rng.randf_range(0.9, 1.3)
	s.radial_segments = 7
	s.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = material("rock", 0.8)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "concrete")
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = r * 0.85
		shape.height = s.height * 0.8
		col.shape = shape
		col.position.y = s.height * 0.4
		body.add_child(col)
		mi.position.y = s.height * 0.4
		body.add_child(mi)
		parent.add_child(body)
		body.position = pos
	else:
		mi.position = pos + Vector3.UP * s.height * 0.3
		parent.add_child(mi)
	mi.rotation.y = rng.randf() * TAU
	return mi.get_parent() if solid else mi


## Tronco caído (deitado), baixo o bastante para ela escalar.
static func _log(parent: Node, pos: Vector3, length: float, yaw: float) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "crate")
	var r := 0.3
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = length
	col.shape = shape
	col.rotation.x = PI * 0.5
	col.position.y = r
	body.add_child(col)
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.05
	c.height = length
	c.radial_segments = 8
	c.rings = 2
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = material("bark", 0.8)
	mi.rotation.x = PI * 0.5
	mi.position.y = r
	body.add_child(mi)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = yaw
	return body


## Dois cartões cruzados com alfa (capim, samambaia).
static func _card_pair(parent: Node, pos: Vector3, tex: String, size: float, yaw: float) -> void:
	var holder := Node3D.new()
	for k in 2:
		var q := QuadMesh.new()
		q.size = Vector2(size * 1.3, size)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = material(tex, 1.0, false, true)
		mi.position.y = size * 0.5
		mi.rotation.y = k * PI * 0.5
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mi)
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = yaw


## Touceira de capim alto: esconde quem está agachada dentro dela (grupo "cover", meta "radius").
static func _grass_patch(parent: Node, center: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var patch := Node3D.new()
	patch.add_to_group("cover")
	patch.set_meta("radius", radius)
	parent.add_child(patch)
	patch.position = center
	for i in int(radius * 9.0):
		var o := Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf())
		_card_pair(patch, Vector3(o.x, 0, o.y), "grass_card", rng.randf_range(1.1, 1.5), rng.randf() * PI)


## Portão de aço fechado no vão da parede do fundo: duas folhas de chapa cheia (não dá para ver a pedreira por
## ele) presas em pilares de concreto, com uma viga de concreto por cima até a altura dos paredões (nada aparece
## por cima, nem do telhado). Trancado: E no teclado do pilar (Door.add_keypad) abre a tela do painel (Inspect.keypad);
## com o cartão do último sniper das torres (GATE_KEY) ele liga e o código (o SUBJECT do tanque vazio do alossauro)
## destranca. Aberto, as folhas giram para dentro da pedreira e dão na última sala.
static func _gate(parent: Node) -> void:
	var gz: float = ROAD[ROAD.size() - 1].y
	var gx := GATE_X
	var top := GATE_H + 0.1  # pé da viga
	for s in [-1, 1]:
		Level.block(parent, Vector3(1.0, Arena.CLIFF_H, 0.8), Vector3(gx, Arena.CLIFF_H * 0.5, gz + s * (GATE_GAP * 0.5 + 0.4)), "concrete", 0.35)
	Level.block(parent, Vector3(1.0, Arena.CLIFF_H - top, GATE_GAP + 1.6), Vector3(gx, (Arena.CLIFF_H + top) * 0.5, gz), "concrete", 0.35)
	# faixa de perigo no pé da viga, dos dois lados
	for sx in [-1, 1]:
		_prop(parent, _bm(Vector3(0.04, 0.3, GATE_GAP)), Vector3(gx + sx * 0.52, top + 0.2, gz), "wall", 1.0).material_override = Level.material("hazard", 1.0)
	var door := Door.create(parent, Vector3(gx, 0, gz), Vector3(0.6, top, GATE_GAP + 0.4), 1, "ABRIR PORTÃO")
	# trancado: o cartão do último sniper das torres liga o teclado no pilar e o código é o número do tanque vazio
	door.lock = GATE_KEY
	door.code = CloneLab.ALLO_SUBJECT
	door.is_locked_door = true
	door.add_keypad(Vector3(0.53, 1.35, GATE_GAP * 0.5 + 0.4), PI * 0.5)
	var w := GATE_GAP * 0.5 - 0.01  # largura de cada folha (as duas se encontram no meio)
	for s in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(0, 0, s * GATE_GAP * 0.5)
		# chapa cheia, com nervuras de reforço, montantes nas beiradas e a faixa de perigo embaixo
		_prop(leaf, _bm(Vector3(0.1, GATE_H, w)), Vector3(0, GATE_H * 0.5, -s * w * 0.5), "wall", 1.0)
		for y in [0.55, 1.75, 2.95, 4.15]:
			_prop(leaf, _bm(Vector3(0.22, 0.16, w)), Vector3(0, y, -s * w * 0.5), "wall", 2.0)
		for z in [0.06, w - 0.06]:
			_prop(leaf, _bm(Vector3(0.24, GATE_H, 0.12)), Vector3(0, GATE_H * 0.5, -s * z), "wall", 2.0)
		_prop(leaf, _bm(Vector3(0.14, 0.3, w)), Vector3(0, 0.15, -s * w * 0.5), "wall", 1.0).material_override = Level.material("hazard", 1.0)
		door.add_panel(leaf, leaf.position, s * deg_to_rad(-75.0))


## Neblina rasteira sobre o pátio (volume de névoa: precisa de `volumetric_fog_enabled` no ambiente, ver Level):
## mais grossa no chão e rala na altura da cabeça; vista de cima (do telhado) vira um lençol que esconde o fundo.
static func _mist(parent: Node) -> void:
	var fv := FogVolume.new()
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	fv.size = Vector3(X_NEAR - GATE_X + 0.4, MIST_H, Z_HALF * 2.0 + 4.0)
	fv.position = Vector3((X_NEAR + GATE_X - 0.4) * 0.5, MIST_H * 0.5 - 0.5, 0)
	var m := FogMaterial.new()
	m.density = MIST_DENSITY
	m.albedo = Color(0.7, 0.78, 0.74)
	m.emission = Color(0.05, 0.06, 0.06)
	m.height_falloff = 1.0
	m.edge_fade = 0.15
	fv.material = m
	parent.add_child(fv)


## Moita de esconderijo de um raptor da emboscada: folhagem e samambaias sem colisão (ele sai de dentro dela).
static func _lurk_bush(parent: Node, pos: Vector3, rng: RandomNumberGenerator) -> void:
	for k in 3:
		var r := rng.randf_range(0.9, 1.2)
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 1.5
		s.radial_segments = 8
		s.rings = 4
		var mi := MeshInstance3D.new()
		mi.mesh = s
		mi.material_override = material("leaves", 1.0)
		var off := Vector2.from_angle(TAU * k / 3.0 + rng.randf() * 0.5) * 0.7
		mi.position = pos + Vector3(off.x, r * 0.6, off.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	for k in 5:
		var off := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.8, 1.8)
		_card_pair(parent, pos + Vector3(off.x, 0, off.y), "fern_card", rng.randf_range(1.0, 1.5), rng.randf() * PI)


## Postes de luz na beira da estrada: luz fria esverdeada, sem sombra (só os do galpão fazem, ver Gfx.set_mode).
static func _lamps(parent: Node) -> void:
	for p: Vector3 in LAMPS:
		lamp(parent, p)


## Um poste com a lâmpada acesa (o pátio e a pedreira usam).
static func lamp(parent: Node, p: Vector3) -> void:
	_box(parent, Vector3(0.22, 3.4, 0.22), p + Vector3.UP * 1.7, "wall", 1.5)
	_prop(parent, _bm(Vector3(0.7, 0.14, 0.4)), p + Vector3(0, 3.45, 0), "wall", 2.0)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.55, 0.3)
	glow.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 1.0, 0.8)
	glow.material_override = m
	glow.rotation_degrees.x = 90.0
	glow.position = p + Vector3(0, 3.37, 0)
	parent.add_child(glow)
	var o := OmniLight3D.new()
	o.position = p + Vector3(0, 3.0, 0)
	o.light_color = Color(0.7, 0.95, 0.7)
	o.light_energy = 1.8
	o.omni_range = 13.0
	o.omni_attenuation = 1.2
	parent.add_child(o)


# ------------------------------------------------------------------ blocos e navegação
static func _bm(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _prop(parent: Node, mesh: Mesh, pos: Vector3, tex: String, scale := 0.5) -> MeshInstance3D:
	var mi := _prop_at(mesh, pos, tex, scale)
	parent.add_child(mi)
	return mi


## Como `_prop`, mas devolve a malha solta (para entrar numa folha de porta).
static func _prop_at(mesh: Mesh, pos: Vector3, tex: String, scale := 0.5) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(tex, scale)
	mi.position = pos
	return mi


## Bloco sólido (camada 1) com malha subdividida, como Level.block.
static func _box(parent: Node, size: Vector3, pos: Vector3, tex: String, scale := 0.5) -> StaticBody3D:
	var body := _wall_box(parent, size, pos)
	body.set_meta("surface", "wall" if tex == "wall" else "concrete")
	if tex == "grass":
		body.set_meta("step", "grass")  # passos na grama (Sfx.step)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.subdivide_width = int(size.x)
	mesh.subdivide_height = int(size.y)
	mesh.subdivide_depth = int(size.z)
	mi.mesh = mesh
	mi.material_override = material(tex, scale)
	body.add_child(mi)
	return body


## Bloco sólido invisível.
static func _wall_box(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = pos
	return body


## Malha de navegação dos raptors a partir de tudo o que é sólido na camada 1 (chamar depois de montar a cena).
## `radius`/`height` = tamanho de quem anda nela; `map` vazio = o mapa do mundo; `cell` = tamanho da célula (o raio é
## múltiplo dela); `area` vazia = a cena toda.
static func bake_nav(parent: Node, radius := 0.75, height := 2.0, map := RID(), cell := 0.25, area := AABB()) -> NavigationRegion3D:
	var nm := NavigationMesh.new()
	nm.cell_size = cell
	nm.cell_height = cell
	nm.agent_radius = radius  # múltiplos do tamanho da célula para a malha sair exata
	nm.agent_height = height
	if area.has_volume():
		nm.filter_baking_aabb = area
	nm.agent_max_climb = 0.25
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	var data := NavigationMeshSourceGeometryData3D.new()
	# portas fechadas não entram na malha como parede: quando abrem, o caminho já passa por elas
	var doors: Array[Node] = parent.get_tree().get_nodes_in_group("doors")
	for d: Door in doors:
		d.collision_layer = 0
	NavigationServer3D.parse_source_geometry_data(nm, data, parent)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	for d: Door in doors:
		d.collision_layer = 0 if d.opened else 1
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	if map.is_valid():
		region.set_navigation_map(map)
	parent.add_child(region)
	return region


## Malha de gente (soldados), num mapa à parte e só no galpão (onde eles ficam): mais fina que a dos raptors, passa
## nos corredores de 1,6 m do labirinto, no nicho da escada do mezanino e debaixo das mãos-francesas do mezanino (acima
## da cabeça; célula de 5 cm para a malha enxergar as frestas). O mapa some com a cena.
const PEOPLE_CELL := 0.05
static func bake_people_nav(parent: Node) -> RID:
	var map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(map, PEOPLE_CELL)
	NavigationServer3D.map_set_cell_height(map, PEOPLE_CELL)
	NavigationServer3D.map_set_active(map, true)
	var h := Level.SIZE * 0.5
	var shed := AABB(Vector3(-h, -1.0, -h), Vector3(Level.SIZE, Level.WALL_H + 1.0, Level.SIZE))
	var region := bake_nav(parent, 0.25, 1.75, map, PEOPLE_CELL, shed)
	region.tree_exited.connect(func() -> void: NavigationServer3D.free_rid(map))
	return map
