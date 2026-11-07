class_name Ladder
extends Node3D
## Escada metálica de acesso à área suspensa / mezanino.
## Possui duas longarinas verticais de aço, degraus horizontais e corrimão superior para pegada firme.
## Permite subir e descer através da ação PlayerMoves.start_ladder.

const RAIL_RADIUS := 0.03
const RUNG_RADIUS := 0.02
const RUNG_SPACING := 0.3
const WIDTH := 0.55
const TOP_HANDRAIL_H := 0.8  # avanço dos corrimãos acima do piso da passarela

@export var height := 2.4
@export var width := WIDTH
## quanto as longarinas passam do topo (alçapão: fica embaixo da tampa fechada)
@export var handrail := TOP_HANDRAIL_H
## onde ela fica em pé ao sair pelo topo, à frente ao longo de ladder_fwd (no piso do mezanino, no telhado)
@export var top_exit := 0.6
## altura da beira que ela passa por cima ao entrar pelo topo (moldura do alçapão)
@export var top_lip := 0.0
## quanto abaixo do alto do ciclo ela ainda fica escondida dos inimigos (alçapão do telhado: alguns degraus)
@export var hidden_top := 0.0
## topo liberado (alçapão do telhado fechado = false: não dá para montar descendo)
var top_open := true
## Recolhida (escada do mezanino): a parte de baixo encaixada atrás da de cima, os degraus só a partir de `lift` m do
## chão, presa com corrente e cadeado. Não sobe nem desce; E embaixo dela = `locked_below` (o Player avisa).
var locked := false
var lift := 0.0

var bottom_pos: Vector3:
	get:
		return global_position
var top_pos: Vector3:
	get:
		return global_position + Vector3.UP * height

var ladder_fwd: Vector3:
	get:
		# Direção para onde a pessoa olha ao subir (em direção à escada e ao mezanino)
		return global_basis.z.normalized()

var ladder_out: Vector3:
	get:
		# Direção para fora da escada (onde a pessoa fica em pé no chão do galpão)
		return -global_basis.z.normalized()

## Lugar em pé no topo: onde ela sai ao terminar de subir e de onde monta para descer.
var top_stand: Vector3:
	get:
		return top_pos + ladder_fwd * top_exit


func _ready() -> void:
	add_to_group("ladders")
	_build_mesh()
	_build_collision()


func _build_mesh() -> void:
	var mat := Level.material("wall", 0.5)
	
	# Longarinas verticais (esquerda e direita)
	var rail_h := height + handrail - lift
	var left_rail := _create_box(Vector3(RAIL_RADIUS * 2, rail_h, RAIL_RADIUS * 2), mat)
	left_rail.position = Vector3(-width * 0.5, lift + rail_h * 0.5, 0)
	add_child(left_rail)
	
	var right_rail := _create_box(Vector3(RAIL_RADIUS * 2, rail_h, RAIL_RADIUS * 2), mat)
	right_rail.position = Vector3(width * 0.5, lift + rail_h * 0.5, 0)
	add_child(right_rail)
	
	# Degraus horizontais
	var rungs_count := int(height / RUNG_SPACING)
	for i in range(1, rungs_count + 1):
		var y := i * RUNG_SPACING
		if y > height:
			break
		if y < lift:
			continue
		var rung := _create_box(Vector3(width, RUNG_RADIUS * 2, RUNG_RADIUS * 2), mat)
		rung.position = Vector3(0, y, 0)
		add_child(rung)
	if lift > 0.0:
		_build_retracted(mat)
	
	# Alças superiores de segurança (arcos no topo para apoio ao sair no mezanino)
	var top_rung := _create_box(Vector3(width, RUNG_RADIUS * 2, RUNG_RADIUS * 2), mat)
	top_rung.position = Vector3(0, height + handrail, 0)
	add_child(top_rung)


## Recolhida: o lance de baixo encaixado atrás do de cima (longarinas e degraus a 5 cm, mais baixo um pouco) e a
## corrente de elos passando pelo degrau de baixo até a longarina, com o cadeado pendurado.
func _build_retracted(mat: Material) -> void:
	var back := 0.05
	var low := lift - 0.12
	var sec_h := height - lift
	for sx: float in [-1.0, 1.0]:
		var rail := _create_box(Vector3(RAIL_RADIUS * 2, sec_h, RAIL_RADIUS * 2), mat)
		rail.position = Vector3(sx * (width * 0.5 - 0.04), low + sec_h * 0.5, back)
		add_child(rail)
	var y := low + RUNG_SPACING * 0.5
	while y < low + sec_h:
		var rung := _create_box(Vector3(width - 0.08, RUNG_RADIUS * 2, RUNG_RADIUS * 2), mat)
		rung.position = Vector3(0, y, back)
		add_child(rung)
		y += RUNG_SPACING
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.56, 0.58)
	steel.metallic = 0.8
	steel.roughness = 0.35
	# corrente: elos alternados do degrau de baixo (os dois lances) até a longarina esquerda
	var a := Vector3(0.05, low + 0.02, back * 0.5)
	var b := Vector3(-width * 0.5, lift + RUNG_SPACING + 0.05, 0.0)
	var links := 9
	for i in links:
		var at := a.lerp(b, (float(i) + 0.5) / links) + Vector3.DOWN * sin(PI * (float(i) + 0.5) / links) * 0.06
		var link := _create_box(Vector3(0.05, 0.022, 0.012) if i % 2 == 0 else Vector3(0.05, 0.012, 0.022), steel)
		link.position = at
		link.look_at_from_position(at, at + (b - a), Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
		add_child(link)
	var padlock := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.07, 0.08, 0.03)
	padlock.mesh = body
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.72, 0.58, 0.25)
	brass.metallic = 0.7
	brass.roughness = 0.4
	padlock.material_override = brass
	padlock.position = a + Vector3(0.0, -0.07, -0.03)
	add_child(padlock)
	var shackle := _create_box(Vector3(0.045, 0.04, 0.012), steel)
	shackle.position = padlock.position + Vector3.UP * 0.055
	add_child(shackle)


## Embaixo da escada recolhida (no chão, na frente dela, ao alcance): E mostra que está trancada.
func locked_below(player_pos: Vector3, max_dist := 1.2) -> bool:
	if not locked:
		return false
	var local: Vector3 = global_basis.inverse() * (player_pos - global_position)
	return absf(local.x) < width * 0.8 + 0.3 and absf(local.y) < 0.6 and local.z < 0.05 and local.z > -max_dist


func _create_box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	return mi


func _build_collision() -> void:
	# Corpo estático para a escada encostar na parede/passarela
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.set_meta("surface", "wall")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.1, height - lift, 0.1)
	col.shape = shape
	col.position = Vector3(0, lift + (height - lift) * 0.5, 0)
	sb.add_child(col)
	add_child(sb)


## Verifica se o jogador está na posição e distância para montar na escada.
func can_mount(player_pos: Vector3, max_dist := 1.0) -> Dictionary:
	if locked:
		return {"can": false}
	var to_player: Vector3 = player_pos - global_position
	# Distância horizontal até a linha central da escada
	var local: Vector3 = global_basis.inverse() * to_player
	if absf(local.x) > width * 0.8:
		return {"can": false}
	
	# No chão (base: jogadora parada na frente da escada, z negativo em relação ao mezanino)
	if absf(player_pos.y - global_position.y) < 0.6 and local.z < -0.05 and local.z > -max_dist:
		return {"can": true, "at_top": false}
	
	# No topo (passarela: jogadora em cima do mezanino, z positivo; alçapão: só depois de aberto)
	if top_open and absf(player_pos.y - (global_position.y + height)) < 0.6 and local.z > -0.8 and local.z < 0.6:
		return {"can": true, "at_top": true}
	
	return {"can": false}
