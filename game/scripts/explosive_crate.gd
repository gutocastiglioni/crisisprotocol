class_name ExplosiveCrate
extends StaticBody3D
## Caixote de metal com explosivos (jeito Syphon Filter), empilhados no canto da porta do pátio onde os guardas do posto
## mexem neles (`Soldier.GUARDS` "work"). Bala comum (pistola, M16, escopeta) só bate no metal: faísca, mossa, a mira
## escreve HARDENED (`TEXT`, pelo `Player.armor_hit`) e o barulho do metal põe em alerta quem está perto (`ping`), que larga
## o trabalho e vai procurar. Explosão por perto (granada armada da M79, `Grenade.explode`, ou outro caixote) detona
## (`shockwave`): cada caixote explode com `RADIUS`/`DAMAGE` e a onda detona os vizinhos um instante depois (cadeia), o
## que pega o posto inteiro de uma vez. Explodido some (sem corpo); R (`reset`) põe todos de volta.

const SIZE := 1.0  # caixote de 1 m (o de trabalho fica na altura das mãos da animação Console)
const TEXT := "HARDENED"
const RADIUS := 6.0  # alcance do dano de cada caixote (m)
const CHAIN_RADIUS := 7.0  # um caixote explodindo detona os outros até aqui (a pilha do canto alcança a do sul da porta)
const FIRE_RADIUS := 0.7  # fogo que fica no chão onde estava cada pilha (Fire)
const BURN_DIST := 4.5  # guarda morto até aqui do caixote pega fogo (Soldier.ignite)
const BODY_PUSH := 5.0  # empurrão de cada caixote nos corpos caídos (são muitos: com o da granada voavam por cima das caixas)
const DAMAGE := 420  # no centro (cai até Grenade.MIN_FRACTION na borda: ainda mata um guarda)
const CHAIN_DELAY := 0.06  # s até o vizinho explodir + CHAIN_PER_M por metro de distância
const CHAIN_PER_M := 0.07
const PING_RANGE := 14.0  # quem ouve a bala batendo no metal (mesma sala)
## Pilhas no chão: [centro (x, z), caixotes na pilha, giro, de trabalho]. Encostadas na parede norte no canto da porta
## do pátio (parede oeste x = -12,8, norte z = -12,8; fora da saída da ronda 0, x = -8,5), uma no meio do canto e uma na
## parede oeste atrás do guarda 5, sem fechar o vão da porta (z -10,1..-6,9) nem a passagem dos raptors rente à parede
## oeste ao sul dela: a cadeia (`CHAIN_RADIUS`) liga todas e a explosão pega os 4 do posto.
## De trabalho = 1 caixote com o detonador em cima, o guarda 7 na frente (`work_spot`).
const STACKS := [
	[Vector2(-12.25, -12.25), 2, 0.03, false],
	[Vector2(-11.2, -12.25), 2, -0.04, false],
	[Vector2(-10.15, -12.25), 1, 0.02, false],
	[Vector2(-9.1, -12.25), 2, 0.02, false],
	[Vector2(-9.1, -11.2), 1, -0.05, false],
	[Vector2(-8.05, -12.25), 1, 0.0, true],  # o do guarda 7, olhando para a parede norte
	# elo do meio: colado ao norte da caixa baixa (-9,6; -5,2), a oeste da rota da ronda 0 (x = -8,5), entre o 3 e o 5 (na parede oeste fechava a
	# passagem dos raptors da porta para o galpão, que desce rente à parede)
	[Vector2(-9.6, -6.45), 2, -0.03, false],
	# parede oeste atrás do 5
	[Vector2(-12.25, -2.6), 2, 0.02, false],
	[Vector2(-12.25, -1.45), 1, -0.03, false],
]
const WORK_GAP := 0.32  # da face do caixote à raiz do guarda (a cápsula de 0,3 não encosta; as mãos chegam no detonador)

static var _mesh: ArrayMesh
static var _mat: ShaderMaterial

var exploded := false
var work_dir := Vector3.ZERO  # lado do guarda do caixote de trabalho (zero = pelo `work_spot` das pilhas do galpão)
var _fuse := -1.0
var _shape: CollisionShape3D
var _view: Node3D


## Monta as pilhas de `STACKS` em `parent` (antes de assar a malha de navegação).
static func build(parent: Node) -> Array[ExplosiveCrate]:
	var out: Array[ExplosiveCrate] = []
	for s in STACKS:
		for k in int(s[1]):
			var c := ExplosiveCrate.new()
			# o de cima um pouco torto, como nas pilhas de caixas do galpão
			c.rotation.y = float(s[2]) * (1.0 if k == 0 else -1.5)
			parent.add_child(c)
			c.position = Vector3(s[0].x, SIZE * (k + 0.5), s[0].y)
			if s[3]:
				c._add_detonator()
			out.append(c)
	return out


## Onde fica o guarda que mexe no caixote de trabalho `i` (índice em STACKS) e o giro dele (de frente para o caixote).
static func work_spot(i: int) -> Dictionary:
	var s: Array = STACKS[i]
	var c := Vector3(s[0].x, 0, s[0].y)
	# o lado de fora: do caixote para o meio do canto
	var out := Vector3(1, 0, 0) if s[0].y > -11.8 else Vector3(0, 0, 1)
	var pos := c + out * (SIZE * 0.5 + WORK_GAP)
	return {"pos": pos, "rot_y": atan2(out.x, out.z)}


func _ready() -> void:
	add_to_group("explosives")
	collision_layer = 1
	collision_mask = 0
	set_meta("surface", "metal")  # faísca e mossa de metal (Fx.SURFACES)
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * SIZE
	_shape.shape = box
	add_child(_shape)
	_view = Node3D.new()
	add_child(_view)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh()
	mi.material_override = _material()
	_view.add_child(mi)


## Caixa com UV 0..1 em cada face (a textura é uma face inteira; com o UV do mundo o losango saía cortado) e 2x2 quads por
## face (a luz é por vértice).
static func _box_mesh() -> ArrayMesh:
	if _mesh:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := SIZE * 0.5
	# [normal, direita, cima] de cada face, vista de fora
	var faces := [
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP], [Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP], [Vector3.LEFT, Vector3.BACK, Vector3.UP],
		[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK],
	]
	var n := 2
	for f in faces:
		var nrm: Vector3 = f[0]
		var r: Vector3 = f[1]
		var u: Vector3 = f[2]
		for i in n:
			for j in n:
				var quad := []
				for c in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
					var a := float(c[0]) / n
					var b := float(c[1]) / n
					quad.append([nrm * h + r * (a - 0.5) * SIZE + u * (b - 0.5) * SIZE, Vector2(a, 1.0 - b)])
				for idx in [0, 2, 1, 0, 3, 2]:
					st.set_normal(nrm)
					st.set_uv(quad[idx][1])
					st.add_vertex(quad[idx][0])
	_mesh = st.commit()
	return _mesh


static func _material() -> ShaderMaterial:
	if _mat == null or _mat.shader != Gfx.shader():
		_mat = ShaderMaterial.new()
		_mat.shader = Gfx.shader()
		_mat.set_shader_parameter("albedo_tex", Level.TEX.explosive)
	return _mat


## Detonador em cima do caixote de trabalho, do lado do guarda: caixinha escura com fios e a luzinha vermelha.
func _add_detonator() -> void:
	var toward := work_dir
	if toward == Vector3.ZERO:
		var spot := work_spot(_stack_index())
		toward = ((spot.pos as Vector3) - Vector3(position.x, 0, position.z)).normalized()
	var yaw := atan2(toward.x, toward.z)
	var top := SIZE * 0.5
	_part(Vector3(0.3, 0.06, 0.2), Vector3(0, top + 0.03, 0) + toward * 0.36, Color(0.16, 0.17, 0.15), yaw)
	_part(Vector3(0.04, 0.02, 0.04), Vector3(0, top + 0.07, 0) + toward * 0.3, Color(1.0, 0.15, 0.1), yaw, true)
	for k in [-1, 1]:
		var side: Vector3 = toward.cross(Vector3.UP) * 0.08 * k
		_part(Vector3(0.02, 0.02, 0.4), Vector3(0, top + 0.01, 0) + toward * 0.02 + side,
			Color(0.8, 0.12, 0.08) if k < 0 else Color(0.1, 0.25, 0.8), yaw)


func _stack_index() -> int:
	for i in STACKS.size():
		if Vector2(position.x, position.z).distance_to(STACKS[i][0]) < 0.05:
			return i
	return 0


## Peça lisa de `size` em `at` (medidas e giro `yaw` do mundo, sem o giro do caixote).
func _part(size: Vector3, at: Vector3, color: Color, yaw: float, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Basis(Vector3.UP, -rotation.y) * at
	mi.rotation.y = yaw - rotation.y
	_view.add_child(mi)
	return mi


## Bala comum bateu no metal em `at`: quem está perto ouve (mesma sala) e entra em alerta (o alarme do Enemy: os mais
## perto vão ver, os outros param e olham); o posto larga o trabalho.
func ping(at: Vector3) -> void:
	if exploded:
		return
	var near: Array = get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return e is Enemy and not e.dead and not e.lurking and e._reaches(at) and e.global_position.distance_to(at) < PING_RANGE)
	near.sort_custom(func(a: Enemy, b: Enemy) -> bool: return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	var ranks := {}
	for e: Enemy in near:
		var kind: Script = e.get_script()
		e.on_alarm(self, at, ranks.get(kind, 0))
		ranks[kind] = ranks.get(kind, 0) + 1


## Explosão em `at` com alcance `radius`: detona os caixotes ao alcance, cada um um instante depois pela distância.
static func shockwave(tree: SceneTree, at: Vector3, radius: float) -> void:
	for c: ExplosiveCrate in tree.get_nodes_in_group("explosives"):
		if c.exploded:
			continue
		var d := maxf(0.0, c.global_position.distance_to(at) - SIZE * 0.5)
		if d <= radius:
			c.detonate(CHAIN_DELAY + d * CHAIN_PER_M)


## Explode daqui a `delay` s (a mais curta vale).
func detonate(delay := 0.0) -> void:
	if exploded:
		return
	_fuse = delay if _fuse < 0.0 else minf(_fuse, delay)


func _physics_process(delta: float) -> void:
	if _fuse < 0.0 or exploded:
		return
	_fuse -= delta
	if _fuse <= 0.0:
		_explode()


func _explode() -> void:
	exploded = true
	_fuse = -1.0
	var at := global_position
	visible = false
	_shape.set_deferred("disabled", true)
	var others: Array[RID] = []
	for c: ExplosiveCrate in get_tree().get_nodes_in_group("explosives"):
		others.append(c.get_rid())
	# mancha de queimado no chão embaixo dele
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * (position.y + 1.0), 1, others)
	var floor_hit := space.intersect_ray(q)
	Grenade.blast(get_parent(), at, Vector3.UP, null, RADIUS, DAMAGE, others, BODY_PUSH)
	if floor_hit:
		Fx.scorch(floor_hit.collider, floor_hit.position + Vector3.UP * 0.02, Vector3.UP)
		if position.y < SIZE:
			# o de baixo de cada pilha deixa o chão pegando fogo
			Fire.burn(get_parent(), floor_hit.position, FIRE_RADIUS)
	# quem a explosão matou por perto pega fogo
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e is Soldier and e.dead and (e as Soldier).global_position.distance_to(at) < BURN_DIST:
			(e as Soldier).ignite()
	shockwave(get_tree(), at, CHAIN_RADIUS)


func reset() -> void:
	exploded = false
	_fuse = -1.0
	visible = true
	_shape.set_deferred("disabled", false)
