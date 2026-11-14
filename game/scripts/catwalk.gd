class_name Catwalk
extends Node3D
## Mezanino quadrado no canto do fundo à esquerda do labirinto (Level.MAZE, colunas 0..3, linhas 0..2), onde fica o
## guarda de M16 (Sniper rifleman, ronda no perímetro). Piso de concreto a FLOOR_Y em pilares, faixa de perigo nas beiras
## abertas (frente e leste), guarda-corpo com rodapé de chapa e a escada de aço na beira da frente.
## Debaixo dele o labirinto continua: os corredores ('_') e as pilhas mais baixas (cabem sob o piso).
## Fase (main, `suspended`): a escada fica recolhida e trancada (`Ladder.locked`, degraus só de LADDER_LIFT para cima) e
## não há como subir: ela só o vê de baixo (pela quina Level.MAZE_Q, esgueirando). Embaixo da escada, E = LOCKED_TEXT.

const FLOOR_Y := 3.0
const X0 := Level.WEST  # parede oeste
const X1 := Level.WEST + 4.0 * Level.MAZE_CELL.x  # beira leste (-6,6)
const WALL_Z := Level.NORTH  # parede do fundo
const FRONT_Z := Level.NORTH - 3.0 * Level.MAZE_CELL.y  # beira da frente (62,86)
const PLATFORM_W := X1 - X0
const PLATFORM_D := WALL_Z - FRONT_Z
const RAIL_H := 1.0
const LADDER_X := Level.WEST + 0.5 * Level.MAZE_CELL.x  # em cima do corredor da parede oeste (coluna 0)
const LADDER_LIFT := 2.0
## Pilares (x, z) nas quinas abertas e no meio das beiras, encostados nas pilhas (fora do meio dos corredores).
const POSTS := [Vector2(X1 - 0.12, FRONT_Z + 0.12), Vector2(X1 - 0.12, WALL_Z - 0.3), Vector2(X0 + 0.3, FRONT_Z + 0.12),
	Vector2(X1 - 0.12, (FRONT_Z + WALL_Z) * 0.5)]
## Ronda do guarda no perímetro (Sniper: `_catwalk_point` / `_clamp_to_catwalk` o seguram aqui dentro).
const ROUTE := [Vector3(X0 + 0.6, FLOOR_Y, FRONT_Z + 0.54), Vector3(X1 - 0.6, FLOOR_Y, FRONT_Z + 0.54),
	Vector3(X1 - 0.6, FLOOR_Y, WALL_Z - 0.6), Vector3(X0 + 0.6, FLOOR_Y, WALL_Z - 0.6)]
## Morto lá em cima, o cartão e o fuzil dele caem da beira no pé da escada (o mezanino não tem subida).
const DROP_POINT := Vector3(LADDER_X + 0.2, 0, FRONT_Z - 0.75)
const LOCKED_TEXT := "Está trancada. O guarda deve gostar de privacidade.
Não vou precisar dela de qualquer forma."

var ladder: Ladder
var floor_body: StaticBody3D


## true = como na fase (escada recolhida e trancada); false = escada de subir (testes da escada).
var suspended := false


## O ponto (no plano) fica debaixo do mezanino?
static func covers(p: Vector3) -> bool:
	return p.x < X1 and p.z > FRONT_Z


func _ready() -> void:
	_build_platform()
	_build_supports()
	_build_guardrails()
	_build_ladder()
	_build_lighting()


func _build_platform() -> void:
	var c := Vector3((X0 + X1) * 0.5, FLOOR_Y - 0.125, (FRONT_Z + WALL_Z) * 0.5)
	floor_body = Level.block(self, Vector3(PLATFORM_W, 0.25, PLATFORM_D), c, "concrete", 0.35)
	# faixa de perigo nas beiras abertas
	Level.block(self, Vector3(PLATFORM_W, 0.02, 0.3), Vector3(c.x, FLOOR_Y + 0.01, FRONT_Z + 0.15), "hazard", 1.0)
	Level.block(self, Vector3(0.3, 0.02, PLATFORM_D - 0.3), Vector3(X1 - 0.15, FLOOR_Y + 0.01, c.z + 0.15), "hazard", 1.0)


## Pilares de aço até o chão (a beira descansa neles e nas pilhas de baixo) e a longarina embaixo das beiras abertas.
func _build_supports() -> void:
	var mat: Material = Level.material("wall", 0.5)
	var under_y := FLOOR_Y - 0.25
	for p: Vector2 in POSTS:
		Level.block(self, Vector3(0.18, under_y, 0.18), Vector3(p.x, under_y * 0.5, p.y), "wall", 1.5)
	add_child(_box(Vector3(PLATFORM_W, 0.14, 0.14), mat, Vector3((X0 + X1) * 0.5, under_y - 0.07, FRONT_Z + 0.08)))
	add_child(_box(Vector3(0.14, 0.14, PLATFORM_D), mat, Vector3(X1 - 0.08, under_y - 0.07, (FRONT_Z + WALL_Z) * 0.5)))


func _build_guardrails() -> void:
	var mat: Material = Level.material("wall", 0.5)
	var gap := 0.8
	var l := LADDER_X - gap * 0.5
	var r := LADDER_X + gap * 0.5
	# frente (com o vão da escada) e o lado leste: rodapé de chapa (segura o corpo) + corrimão
	for e: Array in [[Vector2(X0, FRONT_Z), Vector2(l, FRONT_Z)], [Vector2(r, FRONT_Z), Vector2(X1, FRONT_Z)],
			[Vector2(X1, FRONT_Z), Vector2(X1, WALL_Z)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var d := b - a
		var m := (a + b) * 0.5
		var yaw := -atan2(d.y, d.x)
		Level.block(self, Vector3(d.length(), 0.4, 0.05), Vector3(m.x, FLOOR_Y + 0.2, m.y), "wall", 1.0, yaw)
		for y in [RAIL_H, RAIL_H * 0.5]:
			var bar := _box(Vector3(d.length(), 0.04, 0.04), mat, Vector3(m.x, FLOOR_Y + y, m.y))
			bar.rotation.y = yaw
			add_child(bar)
		for p: Vector2 in [a, b]:
			add_child(_box(Vector3(0.04, RAIL_H, 0.04), mat, Vector3(p.x, FLOOR_Y + RAIL_H * 0.5, p.y)))


func _build_ladder() -> void:
	ladder = Ladder.new()
	ladder.height = FLOOR_Y
	# na beira da frente, voltada para +Z (quem sobe olha para o mezanino)
	ladder.position = Vector3(LADDER_X, 0, FRONT_Z)
	ladder.rotation.y = 0.0
	if suspended:
		ladder.locked = true
		ladder.lift = LADDER_LIFT
	add_child(ladder)


func _build_lighting() -> void:
	# lâmpada industrial pendurada sobre o mezanino
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.78)
	light.light_energy = 1.8
	light.omni_range = 8.0
	light.position = Vector3((X0 + X1) * 0.5, FLOOR_Y + 2.4, (FRONT_Z + WALL_Z) * 0.5)
	light.shadow_enabled = true
	light.add_to_group("lamps")
	add_child(light)


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	return mi
