class_name Arena
## Última sala: a pedreira além do túnel da mina (Tunnel), depois do portão do pátio da mata (a oeste dele). Chão de terra batida cercado de paredões de
## pedra, com ruínas de concreto (muros quebrados e pilares) e pedras grandes para se esconder (o alossauro não passa
## por elas), touceiras de capim alto (grupo "cover") e postes de luz. Aqui ficam o alossauro (ALLO) e dois raptors
## (POSTS). Usa as peças e materiais do pátio (Yard); tudo o que bloqueia fica na camada 1 e entra na malha de
## navegação (Yard.bake_nav).

## a pedreira foi empurrada para oeste o comprimento do túnel da mina (Tunnel): todas as posições abaixo são as de antes + DX
const DX := Tunnel.X_FAR - (-56.6)
const X_NEAR := Tunnel.X_FAR  # começa no fim do túnel (o portão arrombado fica no paredão leste)
const X_FAR := -108.0 + DX
const Z_HALF := 24.0
const CLIFF_H := 7.0
## alossauro: começo e ronda (pontos em chão livre, longe das ruínas e das pedras)
const ALLO := {"pos": Vector3(-90 + DX, 0, -2), "route": [Vector3(-90 + DX, 0, -2), Vector3(-97 + DX, 0, 6), Vector3(-84 + DX, 0, 8), Vector3(-76 + DX, 0, -2), Vector3(-88 + DX, 0, -10)]}
const POSTS := [
	{"pos": Vector3(-70 + DX, 0, 15), "route": [Vector3(-70 + DX, 0, 15), Vector3(-80 + DX, 0, 17), Vector3(-92 + DX, 0, 18), Vector3(-80 + DX, 0, 15)]},
	{"pos": Vector3(-72 + DX, 0, -17), "route": [Vector3(-72 + DX, 0, -17), Vector3(-84 + DX, 0, -19), Vector3(-96 + DX, 0, -18), Vector3(-84 + DX, 0, -16)]},
]
const LAMPS := [Vector3(-63 + DX, 0, -6.5), Vector3(-86 + DX, 0, 2.5), Vector3(-101 + DX, 0, -9)]
## muros e pilares de concreto: [tamanho, centro no chão, giro em graus]
const RUINS := [
	[Vector3(0.6, 2.6, 6.0), Vector3(-68 + DX, 0, 7), 0.0],
	[Vector3(5.0, 2.2, 0.6), Vector3(-79 + DX, 0, -11), 0.0],
	[Vector3(0.6, 3.0, 5.0), Vector3(-93 + DX, 0, 12), 20.0],
	[Vector3(6.0, 1.3, 0.6), Vector3(-99 + DX, 0, -4), 0.0],  # mureta baixa: dá para escalar
	[Vector3(0.9, 4.2, 0.9), Vector3(-84 + DX, 0, 13), 0.0],
	[Vector3(0.9, 4.2, 0.9), Vector3(-80 + DX, 0, -21), 0.0],
	[Vector3(0.9, 3.4, 0.9), Vector3(-104 + DX, 0, 3), 0.0],
]
## pedras grandes: [centro, raio]
const BOULDERS := [
	[Vector3(-64 + DX, 0, -12), 1.8], [Vector3(-74 + DX, 0, 3.5), 1.5], [Vector3(-90 + DX, 0, -21), 2.2],
	[Vector3(-96 + DX, 0, -12), 1.6], [Vector3(-78 + DX, 0, 20.5), 2.0], [Vector3(-104 + DX, 0, 17), 2.4], [Vector3(-60 + DX, 0, 19), 1.7],
]


static func build(parent: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261018
	# chão de terra batida: do fim do chão do pátio até um pouco além dos paredões
	Yard._box(parent, Vector3(X_NEAR - X_FAR + 6.0, 0.4, Z_HALF * 2.0 + 8.0), Vector3((X_NEAR + X_FAR - 6.0) * 0.5, -0.2, 0), "dirt", 0.5)
	_cliffs(parent, rng)
	for r in RUINS:
		var body := Yard._box(parent, r[0], Vector3(r[1].x, r[0].y * 0.5, r[1].z), "wall", 0.75)
		body.rotation.y = deg_to_rad(r[2])
	for b in BOULDERS:
		Yard._rock(parent, b[0], b[1], rng)
	for p in [Vector3(-62 + DX, 0, 14), Vector3(-101 + DX, 0, -19), Vector3(-73 + DX, 0, -21)]:
		Yard._tree(parent, p, rng.randf_range(6.0, 8.0), rng.randf_range(1.6, 2.2), rng, true)
	for c in [Vector3(-66 + DX, 0, -19), Vector3(-87 + DX, 0, 19), Vector3(-100 + DX, 0, 9), Vector3(-71 + DX, 0, 11.5), Vector3(-93 + DX, 0, -7)]:
		Yard._grass_patch(parent, c, rng.randf_range(2.0, 2.6), rng)
	# entulho e capim ralo de enfeite (sem colisão)
	for i in 70:
		var p := Vector3(rng.randf_range(X_FAR + 2.0, X_NEAR - 1.5), 0, rng.randf_range(-Z_HALF + 1.5, Z_HALF - 1.5))
		if rng.randf() < 0.45:
			Yard._rock(parent, p, rng.randf_range(0.12, 0.35), rng, false)
		else:
			Yard._card_pair(parent, p, "grass_card", rng.randf_range(0.4, 0.8), rng.randf() * PI)
	for p: Vector3 in LAMPS:
		Yard.lamp(parent, p)


## Paredões de pedra nos três lados e dos dois lados do portão (no lado do pátio), com pedras soltas no pé.
static func _cliffs(parent: Node, rng: RandomNumberGenerator) -> void:
	var t := 2.0
	var len_x := X_NEAR - X_FAR
	var cx := (X_NEAR + X_FAR) * 0.5
	for s in [-1, 1]:
		Yard._box(parent, Vector3(len_x + t * 2.0, CLIFF_H, t), Vector3(cx, CLIFF_H * 0.5, s * (Z_HALF + t * 0.5)), "rock", 0.35)
	Yard._box(parent, Vector3(t, CLIFF_H, Z_HALF * 2.0 + t * 2.0), Vector3(X_FAR - t * 0.5, CLIFF_H * 0.5, 0), "rock", 0.35)
	# lado do túnel: o paredão só deixa livre o vão do portão arrombável (Tunnel._gate: folhas e viga)
	var gz: float = Yard.ROAD[Yard.ROAD.size() - 1].y
	var g0 := gz - Yard.GATE_GAP * 0.5
	var g1 := gz + Yard.GATE_GAP * 0.5
	var x := X_NEAR + 0.4
	Yard._box(parent, Vector3(0.8, CLIFF_H, g0 + Z_HALF), Vector3(x, CLIFF_H * 0.5, (g0 - Z_HALF) * 0.5), "rock", 0.35)
	Yard._box(parent, Vector3(0.8, CLIFF_H, Z_HALF - g1), Vector3(x, CLIFF_H * 0.5, (g1 + Z_HALF) * 0.5), "rock", 0.35)
	# pedras soltas no pé dos paredões (cenário)
	var px := X_NEAR - 2.0
	while px > X_FAR + 2.0:
		for s in [-1, 1]:
			Yard._rock(parent, Vector3(px + rng.randf_range(-0.8, 0.8), 0, s * (Z_HALF - 0.9)), rng.randf_range(0.6, 1.2), rng, false)
		px -= rng.randf_range(3.0, 4.5)
