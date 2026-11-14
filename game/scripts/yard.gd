class_name Yard
## Segunda sala: o pátio da mata, ao oeste do galpão (porta na parede oeste). Uma trilha de terra em S por mata
## fechada (jeito Dino Crisis 2 / RE4): três faixas norte-sul separadas por paredes de mata (WALL_A, WALL_B: parede
## invisível alta + fileiras de árvores), ligadas por portões de grade (GRATES) que só destravam com a seção limpa.
##   S1  faixa leste, do portão do galpão para o sul: clareira (CLEARING) com o guerrilheiro morto e a chave do container
##       (CORPSE, Corpse); os 3 velociraptors (POSTS) esperam nas moitas dos cantos (LURK) até a emboscada.
##   S2  faixa do meio, para o norte: 7 raptors que saem da mata por trechos (WAVES, `ForestTrail`), 2 de cada vez.
##       No fim dela, meio escondido, o barranco (ROCK1 + SHELF) sobe ao planalto (PLATEAU, PLATEAU_Y) com o baú da
##       escopeta e 2 raptors que pulam das moitas lá em cima (CLIFF_RAPTORS).
##   S3  ainda a faixa do meio, depois do portão do meio: 9 raptors em três levas de 3.
##   L3  faixa oeste, para o sul: trilha sem nada sólido até a praça das torres (PLAZA) e o portão de ferro do fundo.
## Tudo o que bloqueia fica na camada 1 (como o galpão); os portões de grade e as bordas do planalto ficam na
## GRATE_LAYER: seguram corpos (ela e os raptors), não seguram tiro, vista nem som. A malha de navegação dos raptors
## sai da camada 1 (bake_nav). Texturas em tools/make_level_textures.py. O portão do fundo dá no túnel da mina; uma torre
## de guarda de cada lado dele (TOWERS, GuardTower: o main as monta e põe um sniper em cada).

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
const DOOR_Z := -8.5  # centro do portão na parede oeste do galpão (no pátio descoberto, o fim do galpão)
const DOOR_W := 6.0  # portão enorme (o caminhão passa)
const DOOR_H := 3.6
const X_NEAR := -13.0  # a mata começa onde acaba o piso do galpão
const X_FAR := -55.0
const Z_HALF := 45.0
const WALL_H := 10.0  # paredes invisíveis: acima do alcance de escalar até de cima do planalto
## Paredes de mata entre as faixas (centro em x, espessura BAND): leste = S1 e o planalto, meio = S2/S3, oeste = L3.
const WALL_A := -26.5
const WALL_B := -42.5
const BAND := 1.0
const GRATE_LAYER := 1 << 5  # portões de grade e bordas do planalto: segura corpo, não segura raio
const GRATE_W := 4.0  # vão de cada portão de grade
const GRATE_H := 2.9
## Portões de grade (Door de grade, `_grate`): [pé do vão, giro]. 0 = S1→S2 (na WALL_A), 1 = S2→S3 (na parede que cruza a
## faixa do meio em z = 0), 2 = S3→L3 (na WALL_B). Começam travados; o `ForestTrail` destrava cada um quando a seção dele acaba.
const GRATES := [[Vector3(WALL_A, 0, -38.0), 0.0], [Vector3(-36.0, 0, 0.0), PI * 0.5], [Vector3(WALL_B, 0, 38.0), 0.0]]
const MID_X := [WALL_B + BAND * 0.5, WALL_A - BAND * 0.5]  # faixa do meio (S2/S3), de x a x
const WEST_X := [X_FAR, WALL_B - BAND * 0.5]  # faixa oeste (L3 e a praça)
const PLAZA_Z := [-14.0, 12.0]  # praça das torres, na faixa oeste (ao sul dela, mata fechada)
## Planalto da escopeta (faixa leste ao norte de S1): bloco de pedra de PLATEAU_Y, sobre a WALL_A até a faixa do meio.
## A beira (SHELF) desce para o fim de S2; ROCK1 é o degrau do barranco (escala ROCK1, pula e fica pendurada na
## beira do SHELF, sobe). Fora a beira do barranco, as bordas dele têm grade invisível (ninguém cai nem pula de lá).
const PLATEAU_Y := 3.5
const PLATEAU := Rect2(WALL_A - BAND * 0.5, -2.0, X_NEAR - 0.2 - (WALL_A - BAND * 0.5), Z_HALF + 2.0)
const SHELF := Rect2(-30.5, -6.0, 6.5, 4.0)
const ROCK1 := Rect2(-31.4, -6.0, 0.9, 3.5)  # raso: de cima dele a beira do SHELF fica ao alcance das mãos
const ROCK1_H := 1.2
## Alambrado na borda do planalto colada na parede oeste do galpão (logo fora da laje do telhado, Roof.X0): fecha a beira do
## planalto contra o galpão (ninguém sobe nem se pendura na parede dele).
const ROOF_FENCE_X := X_NEAR - 0.35
## Alambrado que fecha o fim de S1 por cima do barranco (do alto do planalto até WALL_H, 0,2 m para dentro da borda de
## pedra): borda sul do planalto, borda leste e borda sul da beira (SHELF) até a WALL_A. [de, até] em cima da pedra.
const S1_END_FENCE := [
	[Vector2(ROOF_FENCE_X, PLATEAU.position.y + 0.2), Vector2(SHELF.end.x - 0.2, PLATEAU.position.y + 0.2)],
	[Vector2(SHELF.end.x - 0.2, PLATEAU.position.y + 0.2), Vector2(SHELF.end.x - 0.2, SHELF.position.y + 0.2)],
	[Vector2(SHELF.end.x - 0.2, SHELF.position.y + 0.2), Vector2(WALL_A + BAND * 0.5, SHELF.position.y + 0.2)],
]
const CLIFF_RAPTORS := [Vector3(-21.0, PLATEAU_Y, 6.0), Vector3(-16.0, PLATEAU_Y, 11.5)]
## Eixo da trilha de terra batida, da porta do galpão até o portão de ferro do fundo (o último ponto é a boca do túnel).
const ROAD := [Vector2(-13.5, -8.5), Vector2(-19.0, -10.0), Vector2(-22.0, -17.0), Vector2(-22.0, -30.0), Vector2(-21.0, -38.0),
	Vector2(-30.0, -38.0), Vector2(-35.5, -31.0), Vector2(-31.0, -21.0), Vector2(-37.0, -11.0), Vector2(-36.0, -4.0),
	Vector2(-36.0, 4.0), Vector2(-31.0, 12.0), Vector2(-37.5, 21.0), Vector2(-31.5, 30.0), Vector2(-37.5, 38.0),
	Vector2(-46.5, 38.0), Vector2(-50.0, 30.0), Vector2(-46.5, 20.0), Vector2(-49.0, 9.0), Vector2(-50.0, -3.0), Vector2(-54.0, -3.0)]
const ROAD_W := 3.6
const GATE_GAP := 4.4  # vão na parede do fundo, no portão (largura)
const GATE_X := X_FAR - 1.1  # o portão fecha o vão da parede do fundo (parede em X_FAR - 1,1)
const GATE_H := 4.7  # altura das folhas de chapa (acima, a viga de concreto até o topo dos paredões)
const GATE_KEY := "allo_gate"  # id do cartão que liga o teclado do portão (cai do último sniper das torres)
const MIST_H := 4.0  # altura do volume da neblina rasteira (do chão para cima; mais grossa embaixo)
const MIST_DENSITY := 0.05
## Os 3 raptors da emboscada (S1): onde cada um fica depois de sair da moita e a rota de quando a perde de vista.
const POSTS := [
	{"pos": Vector3(-24.6, 0, -34.2), "route": [Vector3(-24.6, 0, -34.2), Vector3(-21.0, 0, -42.0), Vector3(-15.5, 0, -36.0), Vector3(-21.5, 0, -30.0)]},
	{"pos": Vector3(-14.8, 0, -34.6), "route": [Vector3(-14.8, 0, -34.6), Vector3(-17.0, 0, -41.0), Vector3(-24.0, 0, -40.5), Vector3(-19.0, 0, -33.0)]},
	{"pos": Vector3(-24.8, 0, -20.5), "route": [Vector3(-24.8, 0, -20.5), Vector3(-16.0, 0, -17.0), Vector3(-15.5, 0, -24.0), Vector3(-22.0, 0, -25.5)]},
]
## Raptors que saem da mata por trechos (`ForestTrail`): quando ela passa de `z` (indo para o norte) dentro da faixa do meio,
## cada `entries` ganha um raptor que pula da moita em volta dela; a seção (1 = S2, 2 = S3) acaba quando os dela morrem.
## Passou correndo: os trechos seguintes soltam os seus e todos vão atrás dela (vão se juntando).
const WAVES := [
	{"section": 1, "z": -36.5, "entries": [Vector3(-40.6, 0, -26.5), Vector3(-28.4, 0, -24.5)]},
	{"section": 1, "z": -27.0, "entries": [Vector3(-40.6, 0, -15.0), Vector3(-28.4, 0, -13.5)]},
	{"section": 1, "z": -18.0, "entries": [Vector3(-40.6, 0, -7.5), Vector3(-28.4, 0, -9.5)]},
	{"section": 1, "z": -11.0, "entries": [Vector3(-40.6, 0, -1.5)]},
	{"section": 2, "z": 3.0, "entries": [Vector3(-40.6, 0, 11.0), Vector3(-28.4, 0, 12.5), Vector3(-40.6, 0, 16.5)]},
	{"section": 2, "z": 14.0, "entries": [Vector3(-40.6, 0, 25.0), Vector3(-28.4, 0, 23.0), Vector3(-28.4, 0, 29.5)]},
	{"section": 2, "z": 25.0, "entries": [Vector3(-40.6, 0, 35.0), Vector3(-29.0, 0, 41.5), Vector3(-35.5, 0, 43.6)]},
]
const LAMPS := [Vector3(-16.5, 0, -13.0), Vector3(-25.0, 0, -42.5), Vector3(-39.5, 0, -21.0), Vector3(-29.0, 0, -1.5),
	Vector3(-39.5, 0, 6.0), Vector3(-28.5, 0, 34.5), Vector3(-44.0, 0, 30.0), Vector3(-45.0, 0, 10.5)]
const SHADOW_LAMPS := 3  # só as primeiras fazem sombra no PS2 (cada sombra de omni pesa)
## Guerrilheiro morto com a chave do container (Corpse), numa clareira ao lado da trilha no fim de S1. Em volta, CLEARING
## metros sem nada sólido (os raptors da emboscada saem dos cantos dela). CORPSE_YAW: a mão da chave para o norte (de
## onde ela vem pela trilha), a cabeça para o oeste.
const CORPSE := Vector3(-17.8, 0, -27.5)
const CORPSE_YAW := -PI * 0.5
const CLEARING := 6.0
## Container trancado da M79 (main, Chest com cadeado) na saída da clareira do morto para o primeiro portão de grade (S1→S2),
## em chão livre (fora da trilha e das rotas dos raptors; o `_scatter` não põe nada em cima), a boca virada para a trilha.
const LOCKER := Vector3(-18.2, 0, -35.6)
const LOCKER_YAW := -PI * 0.5
## Onde cada raptor da emboscada fica escondido (moita sem colisão num canto da clareira, na frente e dos lados dela).
const LURK := [Vector3(-24.6, 0, -34.2), Vector3(-14.8, 0, -34.6), Vector3(-24.8, 0, -20.5)]
## Mata de dentro das faixas numa grade (`COVER_CELL` m, cada célula com um item mexido): moita, árvore, touceira de capim
## alto, pedra ou tronco. Perto da trilha só cabe capim (não sólido); a trilha fica livre de portão a portão.
const COVER_CELL := 3.6
const TREE_GAP := 4.5  # árvore só a CLEARING + isto do morto (a câmera do alto da emboscada passa por cima da beira)
## Baú da escopeta (main) no planalto, a boca virada para o norte; um tronco caído escora o fundo (CHEST_LOG): ela dá a
## volta para chegar na boca.
const SHOTGUN_CHEST := Vector3(-19.5, PLATEAU_Y, 22.0)
const CHEST_LOG := 3.4  # comprimento do tronco atrás do baú
## Torres de guarda (GuardTower) dos dois lados do portão do fundo, encostadas na parede, a frente para a praça. Em volta
## delas não fica árvore (TOWER_TREES m: a copa entraria no telhado) nem outra coisa sólida (TOWER_CLEAR m).
const TOWERS := [Vector3(-54.1, 0, 1.6), Vector3(-54.1, 0, -7.6)]
const TOWER_TREES := 4.5
const TOWER_CLEAR := 3.0
## Rendição: ela passou o último portão de grade e desceu a trilha da faixa oeste até aqui (z): os snipers sobem nas torres.
const STANDOFF_Z := 27.0
## Mata de enfeite (sem corpo) a oeste do galpão, além da parede norte do pátio: do telhado (Roof, aviso do cheiro) ela
## aparece. Faixa em z (de, até) e até onde vai a oeste.
const SHED_WOODS := [Z_HALF + 1.5, Level.NORTH + 2.0]
const SHED_WOODS_X := -40.0

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


## Na faixa do meio (S2/S3), no chão?
static func in_mid(p: Vector3) -> bool:
	return p.x > MID_X[0] and p.x < MID_X[1] and p.y < 2.0


## Em cima do planalto da escopeta (ou da beira do barranco)?
static func on_plateau(p: Vector3) -> bool:
	if p.y < PLATEAU_Y - 0.6:
		return false
	var q := Vector2(p.x, p.z)
	return PLATEAU.grow(0.3).has_point(q) or SHELF.grow(0.3).has_point(q)


## Na faixa oeste (depois do último portão de grade): a trilha até a praça das torres.
static func in_west(p: Vector3) -> bool:
	return p.x > WEST_X[0] - 1.5 and p.x < WEST_X[1] and absf(p.z) <= Z_HALF


# ------------------------------------------------------------------ parede com a porta
## Parede oeste do galpão (no lugar do bloco inteiro de Level.build) com a abertura da porta.
static func west_wall(parent: Node) -> void:
	var x := Level.WEST
	var s0 := Level.SOUTH - Level.WALL_T * 0.5
	var s1 := Level.NORTH + Level.WALL_T * 0.5
	var z0 := DOOR_Z - DOOR_W * 0.5
	var z1 := DOOR_Z + DOOR_W * 0.5
	var t := Level.WALL_T
	_box(parent, Vector3(t, Level.WALL_H, z0 - s0), Vector3(x, Level.WALL_H * 0.5, (z0 + s0) * 0.5), "wall", 0.5)
	_box(parent, Vector3(t, Level.WALL_H, s1 - z1), Vector3(x, Level.WALL_H * 0.5, (z1 + s1) * 0.5), "wall", 0.5)
	var lintel := Level.WALL_H - DOOR_H
	_box(parent, Vector3(t, lintel, DOOR_W), Vector3(x, DOOR_H + lintel * 0.5, DOOR_Z), "wall", 0.5)
	# batentes (só visual) e a faixa de perigo na soleira
	for z in [z0 + 0.12, z1 - 0.12]:
		_prop(parent, _bm(Vector3(0.5, DOOR_H, 0.24)), Vector3(x, DOOR_H * 0.5, z), "wall", 1.5)
	_prop(parent, _bm(Vector3(1.0, 0.02, DOOR_W)), Vector3(x, 0.01, DOOR_Z), "wall", 1.0)
	# portão de segurança trancado com leitor por aproximação (abre com o keycard do atirador do mezanino)
	var door := Door.create(parent, Vector3(x, 0, DOOR_Z), Vector3(t, DOOR_H, DOOR_W), 0, "ABRIR PORTÃO")
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
	# pintado como as portas de aço do galpão (Shed.DOOR_PAINT), com a placa SAÍDA em cima (Shed.door_signs)
	for part: MeshInstance3D in slab.get_children():
		var paint := (part.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		paint.set_shader_parameter("tint", Shed.DOOR_PAINT)
		part.material_override = paint
	door.add_panel(slab, Vector3(0, 0, DOOR_W + 0.2), 0.0)


# ------------------------------------------------------------------ construção
static func build(parent: Node) -> void:
	_mats.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260418
	var cx := (X_NEAR + X_FAR - 1.6) * 0.5
	var len_x := X_NEAR - X_FAR + 1.6
	# chão da mata (dos lados, um pouco além, para nunca aparecer o vazio; no fundo, até o túnel)
	_box(parent, Vector3(len_x, 0.4, Z_HALF * 2.0 + 14.0), Vector3(cx, -0.2, 0), "grass", 0.5)
	_road(parent)
	_boundary(parent)
	_bands(parent)
	_plateau(parent, rng)
	_scatter(parent, rng)
	_gate(parent)
	for g: Array in GRATES:
		_grate(parent, g[0], g[1])
	_mist(parent)
	_lamps(parent)
	_shed_woods(parent, rng)
	for p: Vector3 in LURK:
		_lurk_bush(parent, p, rng)
	for w: Dictionary in WAVES:
		for p: Vector3 in w.entries:
			_lurk_bush(parent, p, rng)
	for p: Vector3 in CLIFF_RAPTORS:
		_lurk_bush(parent, p, rng)
	# tronco caído escorado no fundo do baú da escopeta (fixo: não depende do sorteio da mata)
	var back := SHOTGUN_CHEST.z - Chest.SIZE.z * 0.5 - 0.32
	_log(parent, Vector3(SHOTGUN_CHEST.x, PLATEAU_Y, back), CHEST_LOG, PI * 0.5)


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


## Limites: paredes invisíveis altas (para ninguém sair nem escalar) e, por cima delas, mata fechada.
static func _boundary(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var far_x := X_FAR - 0.6
	for s in [-1, 1]:
		_wall_box(parent, Vector3(len_x(), WALL_H, 1.0), Vector3((X_NEAR + far_x) * 0.5, WALL_H * 0.5, s * (Z_HALF + 0.5)))
		# a parede do galpão continua até o canto da mata ao sul dele (ao norte o galpão já cobre a mata inteira); por cima
		# da parede do galpão, invisível até WALL_H: do planalto não se sobe nela
		var a := -Z_HALF - 0.5 if s < 0 else Level.SOUTH
		var b := Level.SOUTH if s < 0 else Z_HALF + 0.5
		if s < 0:
			_box(parent, Vector3(0.4, Level.WALL_H, b - a), Vector3(X_NEAR, Level.WALL_H * 0.5, (a + b) * 0.5), "wall", 0.5)
		_wall_box(parent, Vector3(0.4, WALL_H - Level.WALL_H, b - a), Vector3(X_NEAR, (WALL_H + Level.WALL_H) * 0.5, (a + b) * 0.5))
	# parede do fundo em dois pedaços: o vão do portão fica livre para o túnel
	var gz: float = ROAD[ROAD.size() - 1].y
	var z0 := -Z_HALF - 1.0
	var z1 := Z_HALF + 1.0
	var g0 := gz - GATE_GAP * 0.5
	var g1 := gz + GATE_GAP * 0.5
	_wall_box(parent, Vector3(1.0, WALL_H, g0 - z0), Vector3(far_x - 0.5, WALL_H * 0.5, (z0 + g0) * 0.5))
	_wall_box(parent, Vector3(1.0, WALL_H, z1 - g1), Vector3(far_x - 0.5, WALL_H * 0.5, (g1 + z1) * 0.5))
	# duas fileiras de árvores nas bordas de cima e de baixo (a de fora é só cenário)
	var x := X_NEAR - 3.0
	while x > far_x - 1.0:
		for s in [-1, 1]:
			_tree(parent, Vector3(x + rng.randf_range(-0.5, 0.5), 0, s * (Z_HALF - 0.8 + rng.randf_range(-0.4, 0.4))), rng.randf_range(8.0, 10.5), rng.randf_range(2.2, 3.0), rng, true)
			_tree(parent, Vector3(x + rng.randf_range(-1.0, 1.0), 0, s * (Z_HALF + 3.5 + rng.randf_range(-0.6, 0.6))), rng.randf_range(9.0, 11.5), rng.randf_range(2.6, 3.4), rng, false)
			if not (s > 0 and x > PLATEAU.position.x):  # em cima do planalto a beira tem a decoração dele
				_bush(parent, Vector3(x + 1.3, 0, s * (Z_HALF - 1.6)), rng.randf_range(0.8, 1.2), rng)
		x -= rng.randf_range(2.4, 3.0)
	var z := -Z_HALF + 2.0
	while z < Z_HALF - 1.5:
		# nada na frente do portão (ele abre para o túnel)
		if absf(z - gz) < GATE_GAP:
			z += rng.randf_range(2.4, 3.0)
			continue
		_off_towers(_tree(parent, Vector3(far_x + 1.0 + rng.randf_range(-0.4, 0.4), 0, z), rng.randf_range(8.0, 10.5), rng.randf_range(2.2, 3.0), rng, true), TOWER_TREES)
		if absf(z - gz) > 3.2:
			_off_towers(_bush(parent, Vector3(far_x + 2.2, 0, z + 1.2), rng.randf_range(0.8, 1.2), rng), TOWER_CLEAR)
		z += rng.randf_range(2.4, 3.0)


## Mata de enfeite a oeste do galpão, ao norte do pátio (SHED_WOODS): árvores e moitas sem corpo, só para o telhado.
static func _shed_woods(parent: Node, rng: RandomNumberGenerator) -> void:
	var z: float = SHED_WOODS[0]
	while z < SHED_WOODS[1]:
		var x := X_NEAR - 2.0 - rng.randf_range(0.0, 1.5)
		while x > SHED_WOODS_X:
			_tree(parent, Vector3(x, 0, z + rng.randf_range(-0.8, 0.8)), rng.randf_range(8.0, 11.0), rng.randf_range(2.2, 3.2), rng, false)
			x -= rng.randf_range(3.0, 4.2)
		z += rng.randf_range(3.2, 4.0)
	# chão de mato embaixo (sem colisão nenhuma: ninguém chega lá)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(X_NEAR - SHED_WOODS_X + 4.0, SHED_WOODS[1] - SHED_WOODS[0] + 4.0)
	mi.mesh = plane
	mi.material_override = material("grass", 0.5)
	mi.position = Vector3((X_NEAR + SHED_WOODS_X) * 0.5 - 2.0, -0.01, (SHED_WOODS[0] + SHED_WOODS[1]) * 0.5)
	parent.add_child(mi)


static func len_x() -> float:
	return X_NEAR - X_FAR + 1.2


## Paredes de mata entre as faixas: parede invisível alta (camada 1, também para a malha dos raptors) com os vãos dos
## portões de grade, e por cima dela árvores e moitas dos dois lados (mata fechada, sem fresta para a vista).
static func _bands(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var g0: Vector3 = GRATES[0][0]
	var g1: Vector3 = GRATES[1][0]
	var g2: Vector3 = GRATES[2][0]
	var hw := GRATE_W * 0.5 + 0.35  # pilares dos portões nas pontas
	# WALL_A (leste|meio): do sul até o portão 0, do portão 0 até a beira do barranco (dali para o norte é o planalto)
	_band(parent, Vector2(WALL_A, -Z_HALF), Vector2(WALL_A, g0.z - hw), rng)
	_band(parent, Vector2(WALL_A, g0.z + hw), Vector2(WALL_A, SHELF.position.y), rng)
	# WALL_B (meio|oeste), com o portão 2
	_band(parent, Vector2(WALL_B, -Z_HALF), Vector2(WALL_B, g2.z - hw), rng)
	_band(parent, Vector2(WALL_B, g2.z + hw), Vector2(WALL_B, Z_HALF), rng)
	# parede que cruza a faixa do meio em z = 0 (S2|S3), com o portão 1
	_band(parent, Vector2(MID_X[0], 0.0), Vector2(g1.x - hw, 0.0), rng)
	_band(parent, Vector2(g1.x + hw, 0.0), Vector2(PLATEAU.position.x, 0.0), rng)
	# faixa oeste: ao sul da praça, mata fechada
	_band(parent, Vector2(WEST_X[0] - 0.6, PLAZA_Z[0]), Vector2(WEST_X[1], PLAZA_Z[0]), rng)
	var x := WEST_X[0] + 1.5
	while x < WEST_X[1] - 1.0:
		var z := -Z_HALF + 1.5
		while z < PLAZA_Z[0] - 1.5:
			_tree(parent, Vector3(x + rng.randf_range(-0.6, 0.6), 0, z + rng.randf_range(-0.6, 0.6)), rng.randf_range(7.0, 10.0), rng.randf_range(2.0, 2.8), rng, false)
			z += rng.randf_range(2.6, 3.4)
		x += rng.randf_range(2.6, 3.4)


## Um trecho de parede de mata de `a` até `b` (no chão): parede invisível + árvores na linha e moitas dos dois lados.
static func _band(parent: Node, a: Vector2, b: Vector2, rng: RandomNumberGenerator) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.2:
		return
	var mid := (a + b) * 0.5
	var along_x := absf(d.x) > absf(d.y)
	var size := Vector3(length, WALL_H, BAND) if along_x else Vector3(BAND, WALL_H, length)
	_wall_box(parent, size, Vector3(mid.x, WALL_H * 0.5, mid.y))
	var dir := d / length
	var side := dir.orthogonal()
	var t := 0.8
	while t < length - 0.6:
		var p := a + dir * t
		_tree(parent, Vector3(p.x + rng.randf_range(-0.25, 0.25), 0, p.y + rng.randf_range(-0.25, 0.25)), rng.randf_range(7.5, 10.5), rng.randf_range(2.0, 2.9), rng, false)
		for s in [-1.0, 1.0]:
			if rng.randf() < 0.75:
				var q: Vector2 = p + dir * rng.randf_range(-0.8, 0.8) + side * s * rng.randf_range(0.9, 1.3)
				_bush_visual(parent, Vector3(q.x, 0, q.y), rng.randf_range(0.8, 1.25), rng)
		t += rng.randf_range(2.1, 2.7)


## Moita só de enfeite (sem colisão): fica na beira das paredes de mata, onde a parede invisível já segura.
static func _bush_visual(parent: Node, pos: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 1.4
	s.radial_segments = 8
	s.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = s
	mi.material_override = material("leaves", 1.0)
	mi.position = pos + Vector3.UP * r * 0.55
	mi.rotation.y = rng.randf() * TAU
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


## Planalto da escopeta: bloco de pedra com grama em cima, a beira do barranco (SHELF), o degrau ROCK1 escondido atrás de
## samambaias e, em cima, árvores, pedras e moitas; nas bordas (menos a do barranco) grade invisível na GRATE_LAYER.
static func _plateau(parent: Node, rng: RandomNumberGenerator) -> void:
	for r: Rect2 in [PLATEAU, SHELF]:
		var c := r.get_center()
		var body := _box(parent, Vector3(r.size.x, PLATEAU_Y, r.size.y), Vector3(c.x, PLATEAU_Y * 0.5, c.y), "rock", 0.35)
		body.set_meta("surface", "concrete")
		# tampa de grama (só a cor: o corpo de pedra é que segura)
		var lid := _prop(parent, _bm(Vector3(r.size.x, 0.04, r.size.y)), Vector3(c.x, PLATEAU_Y + 0.02, c.y), "grass", 0.5)
		lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.set_meta("step", "grass")
	var rc := ROCK1.get_center()
	_box(parent, Vector3(ROCK1.size.x, ROCK1_H, ROCK1.size.y), Vector3(rc.x, ROCK1_H * 0.5, rc.y), "rock", 0.35)
	# meio escondido: samambaias altas na frente do degrau e pedrinhas soltas
	for k in 7:
		var q := Vector2(ROCK1.position.x - rng.randf_range(0.6, 2.0), rng.randf_range(ROCK1.position.y - 0.5, ROCK1.end.y + 0.8))
		_card_pair(parent, Vector3(q.x, 0, q.y), "fern_card", rng.randf_range(1.3, 1.9), rng.randf() * PI)
	# bordas com grade invisível (do alto do planalto até WALL_H): ninguém pula de lá nem sobe por elas
	var top := WALL_H - PLATEAU_Y
	var y := PLATEAU_Y + top * 0.5
	var px0 := PLATEAU.position.x
	var px1 := PLATEAU.end.x
	_grate_box(parent, Vector3(0.3, top, PLATEAU.end.y - SHELF.end.y), Vector3(px0, y, (SHELF.end.y + PLATEAU.end.y) * 0.5))
	_grate_box(parent, Vector3(px1 - SHELF.end.x, top, 0.3), Vector3((SHELF.end.x + px1) * 0.5, y, PLATEAU.position.y))
	_grate_box(parent, Vector3(0.3, top, SHELF.size.y), Vector3(SHELF.end.x, y, SHELF.get_center().y))
	_grate_box(parent, Vector3(SHELF.size.x, top, 0.3), Vector3(SHELF.get_center().x, y, SHELF.position.y))
	# borda colada no galpão: o alto da mureta do telhado fica só ROOF_DROP acima do planalto (o pulo não machuca);
	# alambrado de verdade (visível) do planalto até WALL_H, da beira sul do planalto até a parede que continua o galpão
	Shed.fence(parent, Vector2(ROOF_FENCE_X, PLATEAU.position.y - 0.15), Vector2(ROOF_FENCE_X, PLATEAU.end.y), PLATEAU_Y, WALL_H)
	# fim de S1 (a faixa de baixo, ao norte): alambrado em cima da borda do planalto e da beira, do alto da pedra até
	# WALL_H, da parede do galpão até a WALL_A (a face de pedra fica à vista de S1). Grade logo atrás da beira = ela não
	# se agarra nela (`PlayerMoves.find_ledge`), nem pulando do telhado na diagonal.
	for seg: Array in S1_END_FENCE:
		Shed.fence(parent, seg[0], seg[1], PLATEAU_Y, WALL_H)
	# a borda de cima da beira (para o norte, sobre o fim de S2) e a do degrau ficam abertas: é por ali que ela desce
	# mureta de pedra baixa na borda que dá para S3 (só enfeite: a grade invisível é que segura)
	var z := PLATEAU.position.y + 1.0
	while z < PLATEAU.end.y - 1.0:
		_rock(parent, Vector3(px0 + 0.45, PLATEAU_Y, z), rng.randf_range(0.3, 0.55), rng, false)
		z += rng.randf_range(1.2, 2.4)
	# decoração em cima: árvores e moitas nas beiradas, pedras soltas; livre o caminho da beira até o baú e as moitas dos raptors
	var keep: Array[Vector2] = [Vector2(SHOTGUN_CHEST.x, SHOTGUN_CHEST.z), Vector2(SHOTGUN_CHEST.x, SHOTGUN_CHEST.z + 2.0)]
	for p: Vector3 in CLIFF_RAPTORS:
		keep.append(Vector2(p.x, p.z))
	for e in Pickup.LAYOUT:
		if on_plateau(e.pos):
			keep.append(Vector2(e.pos.x, e.pos.z))
	var x := px1 - 1.6
	while x > px0 + 2.8:  # a beira sobre S3 fica livre (a vista desce)
		var zz := PLATEAU.position.y + 3.5
		while zz < PLATEAU.end.y - 1.5:
			var p := Vector2(x + rng.randf_range(-1.0, 1.0), zz + rng.randf_range(-1.0, 1.0))
			zz += 3.6
			var near_path := absf(p.x - (px0 + px1) * 0.5) < 1.6 and p.y < SHOTGUN_CHEST.z + 2.0
			if near_path or keep.any(func(k: Vector2) -> bool: return p.distance_to(k) < 2.6):
				continue
			var roll := rng.randf()
			var at := Vector3(p.x, PLATEAU_Y, p.y)
			if roll < 0.3:
				_tree(parent, at, rng.randf_range(5.5, 7.5), rng.randf_range(1.8, 2.4), rng, true)
			elif roll < 0.6:
				_bush(parent, at, rng.randf_range(0.8, 1.2), rng)
			elif roll < 0.75:
				_rock(parent, at, rng.randf_range(0.5, 0.9), rng)
			else:
				_grass_patch(parent, at, rng.randf_range(1.4, 2.0), rng)
		x -= 3.6


## Bloco invisível na GRATE_LAYER: segura ela e os raptors, deixa passar tiro, vista e a malha da navegação.
static func _grate_box(parent: Node, size: Vector3, pos: Vector3) -> void:
	var body := _wall_box(parent, size, pos)
	body.collision_layer = GRATE_LAYER


## Árvores, moitas, touceiras de capim alto, pedras e troncos dentro das faixas (grade COVER_CELL), longe da trilha,
## das rotas, das moitas dos raptors, das lâmpadas, da porta, dos itens, dos portões, do barranco e da clareira do morto.
## A faixa do meio (lutas) fica mais rala de coisa sólida; a trilha da faixa oeste não tem nada sólido (a rendição é
## de longe: as miras dos snipers a acham descendo).
static func _scatter(parent: Node, rng: RandomNumberGenerator) -> void:
	var keep: Array[Vector2] = []  # pontos livres (rotas, lâmpadas, porta, moitas da emboscada) com raio
	for post in POSTS:
		for p: Vector3 in post.route:
			keep.append(Vector2(p.x, p.z))
	for p: Vector3 in LAMPS + LURK:
		keep.append(Vector2(p.x, p.z))
	for w: Dictionary in WAVES:
		for p: Vector3 in w.entries:
			keep.append(Vector2(p.x, p.z))
	keep.append(Vector2(-15.5, DOOR_Z))
	for g: Array in GRATES:
		var gp: Vector3 = g[0]
		var across := Vector2.RIGHT.rotated(-float(g[1]))
		for s in [-2.6, 2.6]:
			keep.append(Vector2(gp.x, gp.z) + across * s)
	var items: Array[Vector2] = []  # nem capim por cima
	for e in Pickup.LAYOUT:
		if e.pos.x < X_NEAR and e.pos.x > X_FAR and not on_plateau(e.pos):
			items.append(Vector2(e.pos.x, e.pos.z))
	items.append(Vector2(LOCKER.x, LOCKER.z))
	keep.append_array(items)
	var placed: Array[Vector2] = []
	var patches: Array[Vector3] = []  # touceiras já postas (x, z, raio): uma não entra na outra
	var corpse := Vector2(CORPSE.x, CORPSE.z)
	var barranco := Rect2(ROCK1.position - Vector2(3.0, 1.5), Vector2(ROCK1.size.x + SHELF.size.x + 3.0, SHELF.size.y + 3.0))
	var x := X_NEAR - 2.2
	while x > X_FAR + 2.0:
		var z := -Z_HALF + 2.6
		while z < Z_HALF - 2.0:
			var jitter := COVER_CELL * 0.35
			var p := Vector2(x + rng.randf_range(-jitter, jitter), z + rng.randf_range(-jitter, jitter))
			var roll := rng.randf()
			var size := rng.randf()
			z += COVER_CELL
			if _in_band(p, 1.4) or PLATEAU.grow(0.8).has_point(p) or barranco.has_point(p):
				continue
			if p.x < WEST_X[1] and p.y < PLAZA_Z[0] + 1.0:
				continue  # ao sul da praça: mata fechada (montada em _bands)
			var west := p.x < WEST_X[1]
			var mid := p.x > MID_X[0] and p.x < MID_X[1]
			var pos := Vector3(p.x, 0, p.y)
			var solid_ok := _clear(p, placed, keep, 2.4) and p.distance_to(corpse) >= CLEARING
			var grass_odds := 0.45 if mid else 0.24
			if roll < grass_odds or not solid_ok or west:
				# touceira: fora da terra da trilha e da clareira, longe dos itens e da porta
				var r := lerpf(1.5, 2.2, size)
				if road_distance(p) < ROAD_W * 0.5 + r * 0.75 or p.distance_to(corpse) < CLEARING + r * 0.5 \
						or p.distance_to(Vector2(-15.5, DOOR_Z)) < 4.0 or items.any(func(q: Vector2) -> bool: return p.distance_to(q) < r + 0.8) \
						or patches.any(func(g: Vector3) -> bool: return p.distance_to(Vector2(g.x, g.y)) < r + g.z - 0.8) \
						or (west and _near_towers(p, TOWER_CLEAR + r)):
					continue
				patches.append(Vector3(p.x, p.y, r))
				_grass_patch(parent, pos, r, rng)
				continue
			if mid and roll > 0.86:
				continue  # clareiras na faixa do meio (espaço para a luta)
			placed.append(p)
			# perto da clareira só moita (baixa): copa de árvore ali entra no plano do alto da cena da emboscada
			if roll < 0.62 or (roll < 0.82 and p.distance_to(corpse) < CLEARING + TREE_GAP):
				_bush(parent, pos, lerpf(0.9, 1.4, size), rng)
			elif roll < 0.82:
				_tree(parent, pos, lerpf(5.5, 8.0, size), rng.randf_range(1.8, 2.6), rng, true)
			elif roll < 0.93:
				_rock(parent, pos, lerpf(0.5, 1.1, size), rng)
			else:
				_log(parent, pos, lerpf(2.4, 3.6, size), rng.randf() * PI)
		x -= COVER_CELL
	# samambaias e capim ralo: de enfeite, sem colisão, também fora da estrada
	for i in 260:
		var p := Vector2(rng.randf_range(X_FAR + 1.5, X_NEAR - 1.0), rng.randf_range(-Z_HALF + 1.0, Z_HALF - 1.0))
		if road_distance(p) < ROAD_W * 0.5 + 0.2 or p.distance_to(corpse) < 2.2 or PLATEAU.grow(0.2).has_point(p) or SHELF.grow(0.2).has_point(p):
			continue
		var tuft := rng.randf() < 0.5
		_card_pair(parent, Vector3(p.x, 0, p.y), "fern_card" if tuft else "grass_card", rng.randf_range(0.9, 1.5) if tuft else rng.randf_range(0.5, 0.8), rng.randf() * PI)
	# pedrinhas e tufos na beira da estrada
	for i in 110:
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


## Dentro (ou a `margin` m) de uma parede de mata entre as faixas?
static func _in_band(p: Vector2, margin: float) -> bool:
	if absf(p.x - WALL_A) < BAND * 0.5 + margin or absf(p.x - WALL_B) < BAND * 0.5 + margin:
		return true
	if p.x > MID_X[0] - margin and p.x < MID_X[1] + margin and absf(p.y) < BAND * 0.5 + margin:
		return true
	return p.x < WEST_X[1] + margin and absf(p.y - PLAZA_Z[0]) < BAND * 0.5 + margin


static func _near_towers(p: Vector2, gap: float) -> bool:
	for t: Vector3 in TOWERS:
		if p.distance_to(Vector2(t.x, t.z)) < gap:
			return true
	return false


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


## Portão de grade num vão de parede de mata (`at` = pé do vão, `yaw` = giro; 0 = o vão ao longo de z): duas folhas de
## barras de ferro em pilares de madeira, com um lampião em cima de um pilar (vermelho travado, verde destravado: o
## leitor do Door). Fica na GRATE_LAYER (segura corpo, não segura tiro nem vista) e fora da corrente de salas (room -1).
## Começa travado (`Door.held`); o `ForestTrail` destrava quando a seção de antes dele acaba e ela abre com E.
static func _grate(parent: Node, at: Vector3, yaw: float) -> Door:
	var hw := GRATE_W * 0.5
	for s in [-1, 1]:
		var off := Vector3(0, (GRATE_H + 0.5) * 0.5, s * (hw + 0.22)).rotated(Vector3.UP, yaw)
		var post := Level.block(parent, Vector3(0.45, GRATE_H + 0.5, 0.45), at + off, "crate", 0.6, yaw)
		(post.get_child(0) as MeshInstance3D).material_override = material("bark", 0.8)
	var door := Door.create(parent, at, Vector3(0.3, GRATE_H, GRATE_W), -1, "ABRIR PORTÃO")
	door.rotation.y = yaw
	door.solid_layer = GRATE_LAYER
	door.collision_layer = GRATE_LAYER
	door.held = true
	door.set_meta("surface", "metal")
	door.add_status_lamp(Vector3(0.0, GRATE_H + 0.62, hw + 0.22))
	var w := hw - 0.02
	for s in [-1, 1]:
		var leaf := Node3D.new()
		leaf.position = Vector3(0, 0, s * hw)
		for y in [0.18, GRATE_H * 0.5, GRATE_H - 0.12]:
			_prop(leaf, _bm(Vector3(0.08, 0.08, w)), Vector3(0, y, -s * w * 0.5), "wall", 2.0)
		var n := 9
		for k in n:
			var bz: float = -s * (0.08 + (w - 0.16) * k / float(n - 1))
			_prop(leaf, _bm(Vector3(0.04, GRATE_H - 0.1, 0.04)), Vector3(0, GRATE_H * 0.5, bz), "wall", 4.0)
		door.add_panel(leaf, leaf.position, s * deg_to_rad(-100.0))
	return door


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
	for i in LAMPS.size():
		lamp(parent, LAMPS[i], i < SHADOW_LAMPS)


## Um poste com a lâmpada acesa (o pátio e a pedreira usam). `shadow` = no grupo "lamps" (sombra no PS2).
static func lamp(parent: Node, p: Vector3, shadow := true) -> void:
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
	if shadow:
		o.add_to_group("lamps")  # sombra no PS2 (Gfx)
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
	nm.geometry_collision_mask = 1 | GRATE_LAYER  # grades fixas (alambrado do galpão, bordas do planalto) são parede na malha
	var data := NavigationMeshSourceGeometryData3D.new()
	# portas fechadas (portões de grade também) não entram na malha como parede: quando abrem, o caminho já passa por elas
	# (as que nunca abrem, `Door.locked_text`, ficam como parede)
	var doors: Array[Node] = parent.get_tree().get_nodes_in_group("doors").filter(func(d: Door) -> bool: return d.locked_text == "")
	for d: Door in doors:
		d.collision_layer = 0
	NavigationServer3D.parse_source_geometry_data(nm, data, parent)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	for d: Door in doors:
		d.collision_layer = 0 if d.opened else d.solid_layer
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
	var shed := AABB(Vector3(Level.WEST, -1.0, Level.SOUTH), Vector3(Level.WIDTH, Level.WALL_H + 1.0, Level.DEPTH))
	var region := bake_nav(parent, 0.25, 1.75, map, PEOPLE_CELL, shed)
	region.tree_exited.connect(func() -> void: NavigationServer3D.free_rid(map))
	return map
