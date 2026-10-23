class_name Catwalk
extends Node3D
## Área suspensa (passarela / mezanino tático) instalada na parede traseira do galpão,
## logo às costas de onde a heroína começa.
## O mezanino conta com piso de concreto reforçado, faixa de perigo, vigas metálicas diagonais
## de sustentação fixadas na parede, guarda-corpos industriais com abertura e escada de aço.

const FLOOR_Y := 3.0
const PLATFORM_W := 10.0
const PLATFORM_D := 2.2
const WALL_Z := 13.0
const FRONT_Z := WALL_Z - PLATFORM_D  # 10.8
const RAIL_H := 1.0
const LADDER_X := 2.2

var ladder: Ladder
var floor_body: StaticBody3D


func _ready() -> void:
	_build_platform()
	_build_supports()
	_build_guardrails()
	_build_ladder()
	_build_lighting()


func _build_platform() -> void:
	# Piso do mezanino: centro em x=0, y=2.275 (topo em 2.4), z=(10.8 + 13.0)/2 = 11.9
	var center_z: float = (FRONT_Z + WALL_Z) * 0.5
	floor_body = Level.block(self, Vector3(PLATFORM_W, 0.25, PLATFORM_D), Vector3(0, FLOOR_Y - 0.125, center_z), "concrete", 0.35)
	
	# Faixa de perigo amarela/preta na borda frontal da passarela
	Level.block(self, Vector3(PLATFORM_W, 0.02, 0.3), Vector3(0, FLOOR_Y + 0.01, FRONT_Z + 0.15), "hazard", 1.0)


func _build_supports() -> void:
	# Vigas estruturais diagonais de sustentação debaixo da passarela ancoradas na parede
	var mat: Material = Level.material("wall", 0.5)
	var x_coords: Array[float] = [-4.0, 0.0, 4.0]
	var beam_len: float = sqrt(pow(FLOOR_Y - 0.8, 2) + pow(PLATFORM_D * 0.9, 2))
	for x: float in x_coords:
		var bracket := Node3D.new()
		bracket.position = Vector3(x, 0.8, WALL_Z - 0.1)
		
		# Viga diagonal inclinada
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.18, beam_len)
		beam.mesh = box
		beam.material_override = mat
		beam.position = Vector3(0, (FLOOR_Y - 0.8) * 0.5, -PLATFORM_D * 0.45)
		beam.rotation.x = -atan2(FLOOR_Y - 0.8, PLATFORM_D * 0.9)
		bracket.add_child(beam)
		add_child(bracket)


func _build_guardrails() -> void:
	var mat: Material = Level.material("wall", 0.5)
	var rail_thick := 0.04
	
	# Laterais (esquerda x = -PLATFORM_W/2, direita x = +PLATFORM_W/2)
	var signs: Array[int] = [-1, 1]
	for s: int in signs:
		var x: float = float(s) * PLATFORM_W * 0.5
		var center_z: float = (FRONT_Z + WALL_Z) * 0.5
		var side_post1 := _box(Vector3(rail_thick, RAIL_H, rail_thick), mat, Vector3(x, FLOOR_Y + RAIL_H * 0.5, FRONT_Z))
		var side_post2 := _box(Vector3(rail_thick, RAIL_H, rail_thick), mat, Vector3(x, FLOOR_Y + RAIL_H * 0.5, WALL_Z))
		var side_top := _box(Vector3(rail_thick, rail_thick, PLATFORM_D), mat, Vector3(x, FLOOR_Y + RAIL_H, center_z))
		var side_mid := _box(Vector3(rail_thick, rail_thick, PLATFORM_D), mat, Vector3(x, FLOOR_Y + RAIL_H * 0.5, center_z))
		add_child(side_post1)
		add_child(side_post2)
		add_child(side_top)
		add_child(side_mid)
	
	# Borda frontal com vão livre para a escada em LADDER_X (largura ~0.8m)
	var ladder_gap := 0.8
	var x_min: float = -PLATFORM_W * 0.5
	var x_max: float = PLATFORM_W * 0.5
	var ladder_l: float = LADDER_X - ladder_gap * 0.5
	var ladder_r: float = LADDER_X + ladder_gap * 0.5
	
	# Seção esquerda da grade frontal (de x_min até ladder_l)
	var len_left: float = ladder_l - x_min
	var center_left: float = (x_min + ladder_l) * 0.5
	add_child(_box(Vector3(len_left, rail_thick, rail_thick), mat, Vector3(center_left, FLOOR_Y + RAIL_H, FRONT_Z)))
	add_child(_box(Vector3(len_left, rail_thick, rail_thick), mat, Vector3(center_left, FLOOR_Y + RAIL_H * 0.5, FRONT_Z)))
	add_child(_box(Vector3(rail_thick, RAIL_H, rail_thick), mat, Vector3(ladder_l, FLOOR_Y + RAIL_H * 0.5, FRONT_Z)))
	
	# Seção direita da grade frontal (de ladder_r até x_max)
	var len_right: float = x_max - ladder_r
	var center_right: float = (ladder_r + x_max) * 0.5
	add_child(_box(Vector3(len_right, rail_thick, rail_thick), mat, Vector3(center_right, FLOOR_Y + RAIL_H, FRONT_Z)))
	add_child(_box(Vector3(len_right, rail_thick, rail_thick), mat, Vector3(center_right, FLOOR_Y + RAIL_H * 0.5, FRONT_Z)))
	add_child(_box(Vector3(rail_thick, RAIL_H, rail_thick), mat, Vector3(ladder_r, FLOOR_Y + RAIL_H * 0.5, FRONT_Z)))
	
	# Chapa de aço de proteção / toeboard industrial no rodapé das grades frontais
	var plate_h := 0.4
	Level.block(self, Vector3(len_left, plate_h, 0.05), Vector3(center_left, FLOOR_Y + plate_h * 0.5, FRONT_Z), "wall", 1.0)
	Level.block(self, Vector3(len_right, plate_h, 0.05), Vector3(center_right, FLOOR_Y + plate_h * 0.5, FRONT_Z), "wall", 1.0)


func _build_ladder() -> void:
	ladder = Ladder.new()
	ladder.height = FLOOR_Y
	# Escada posicionada na abertura frontal da passarela, voltada para +Z (quem sobe olha para a parede)
	ladder.position = Vector3(LADDER_X, 0, FRONT_Z)
	ladder.rotation.y = 0.0
	add_child(ladder)


func _build_lighting() -> void:
	# Lâmpada industrial suspensa acima da passarela
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.92, 0.78)
	light.light_energy = 1.8
	light.omni_range = 8.0
	light.position = Vector3(0, FLOOR_Y + 1.8, (FRONT_Z + WALL_Z) * 0.5)
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
