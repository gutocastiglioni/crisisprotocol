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


func _ready() -> void:
	add_to_group("ladders")
	_build_mesh()
	_build_collision()


func _build_mesh() -> void:
	var mat := Level.material("wall", 0.5)
	
	# Longarinas verticais (esquerda e direita)
	var left_rail := _create_box(Vector3(RAIL_RADIUS * 2, height + TOP_HANDRAIL_H, RAIL_RADIUS * 2), mat)
	left_rail.position = Vector3(-width * 0.5, (height + TOP_HANDRAIL_H) * 0.5, 0)
	add_child(left_rail)
	
	var right_rail := _create_box(Vector3(RAIL_RADIUS * 2, height + TOP_HANDRAIL_H, RAIL_RADIUS * 2), mat)
	right_rail.position = Vector3(width * 0.5, (height + TOP_HANDRAIL_H) * 0.5, 0)
	add_child(right_rail)
	
	# Degraus horizontais
	var rungs_count := int(height / RUNG_SPACING)
	for i in range(1, rungs_count + 1):
		var y := i * RUNG_SPACING
		if y > height:
			break
		var rung := _create_box(Vector3(width, RUNG_RADIUS * 2, RUNG_RADIUS * 2), mat)
		rung.position = Vector3(0, y, 0)
		add_child(rung)
	
	# Alças superiores de segurança (arcos no topo para apoio ao sair no mezanino)
	var top_rung := _create_box(Vector3(width, RUNG_RADIUS * 2, RUNG_RADIUS * 2), mat)
	top_rung.position = Vector3(0, height + TOP_HANDRAIL_H, 0)
	add_child(top_rung)


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
	shape.size = Vector3(width + 0.1, height, 0.1)
	col.shape = shape
	col.position = Vector3(0, height * 0.5, 0)
	sb.add_child(col)
	add_child(sb)


## Verifica se o jogador está na posição e distância para montar na escada.
func can_mount(player_pos: Vector3, max_dist := 1.0) -> Dictionary:
	var to_player: Vector3 = player_pos - global_position
	# Distância horizontal até a linha central da escada
	var local: Vector3 = global_basis.inverse() * to_player
	if absf(local.x) > width * 0.8:
		return {"can": false}
	
	# No chão (base: jogadora parada na frente da escada, z negativo em relação ao mezanino)
	if absf(player_pos.y - global_position.y) < 0.6 and local.z < -0.05 and local.z > -max_dist:
		return {"can": true, "at_top": false}
	
	# No topo (passarela: jogadora em cima do mezanino, z positivo)
	if absf(player_pos.y - (global_position.y + height)) < 0.6 and local.z > -0.8 and local.z < 0.6:
		return {"can": true, "at_top": true}
	
	return {"can": false}
