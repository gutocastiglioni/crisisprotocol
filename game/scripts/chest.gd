class_name Chest
extends StaticBody3D
## Baú de armas em cima de um palete, com uma arma dentro (`item`: M16 ou escopeta; definir antes de entrar na
## árvore). Ela chega perto, aperta interagir (triângulo / E), ajoelha na frente (kneel_transform), a tampa abre e
## as mãos pegam a arma (PlayerMoves.start_pickup). A arma (m16.glb / shotgun.glb) já vem do build na posição em
## que as mãos dela a pegam, em relação à raiz ajoelhada (as duas têm o cabo e a telha nos mesmos pontos).
## Frente do baú = +Z local.

## arma -> [malha deitada no baú, textura do baú (estêncil)]
const ITEMS := {
	"m16": [preload("res://assets/characters/m16.glb"), "chest"],
	"shotgun": [preload("res://assets/characters/shotgun.glb"), "chest_shotgun"],
}
const ATLAS := preload("res://assets/characters/heroine_atlas.png")
const SIZE := Vector3(1.2, 0.42, 0.5)  # corpo do baú (largura, altura, fundo)
const PALLET := 0.12  # altura do palete
const WALL := 0.03
const LID_OPEN := -105.0  # graus (para trás)
const OPEN_TIME := 0.45

var item := "m16"
var _start_item := ""
var _lid: Node3D
var _rifle: Node3D


func _ready() -> void:
	assert(item in ITEMS, "baú com arma desconhecida: " + item)
	_start_item = item
	var tex: String = ITEMS[item][1]
	add_to_group("chests")
	collision_layer = 1
	collision_mask = 0
	# a colisão é maior que a caixa (e a tampa abre): buraco de bala ficaria flutuando
	set_meta("surface", "metal")
	set_meta("no_decals", true)
	var top := PALLET + SIZE.y
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE.x + 0.08, top, SIZE.z + 0.08)
	col.shape = shape
	col.position.y = top * 0.5
	add_child(col)
	_box(self, Vector3(SIZE.x + 0.08, PALLET, SIZE.z + 0.08), Vector3(0, PALLET * 0.5, 0), "crate")
	# caixa aberta em cima (fundo + 4 paredes) para ver o fuzil lá dentro
	var y0 := PALLET
	_box(self, Vector3(SIZE.x, WALL, SIZE.z), Vector3(0, y0 + WALL * 0.5, 0), tex)
	for sz in [-1, 1]:
		_box(self, Vector3(SIZE.x, SIZE.y, WALL), Vector3(0, y0 + SIZE.y * 0.5, sz * (SIZE.z - WALL) * 0.5), tex)
	for sx in [-1, 1]:
		_box(self, Vector3(WALL, SIZE.y, SIZE.z - 2 * WALL), Vector3(sx * (SIZE.x - WALL) * 0.5, y0 + SIZE.y * 0.5, 0), tex)
	# tampa com a dobradiça na borda de trás
	_lid = Node3D.new()
	_lid.position = Vector3(0, top, -SIZE.z * 0.5)
	add_child(_lid)
	_box(_lid, Vector3(SIZE.x + 0.02, 0.05, SIZE.z + 0.02), Vector3(0, 0.025, SIZE.z * 0.5), tex)
	_rifle = (ITEMS[item][0] as PackedScene).instantiate()
	# o glTF olha para +Z: girado como o modelo dela, na raiz ajoelhada
	add_child(_rifle)
	_rifle.transform = _local_kneel() * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	for mi: MeshInstance3D in _rifle.find_children("*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader()
		m.set_shader_parameter("albedo_tex", ATLAS)
		m.set_shader_parameter("rim", 0.35)
		mi.material_override = m


func _box(parent: Node3D, size: Vector3, pos: Vector3, tex: String) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = Level.material(tex, 1.0 / maxf(size.x, 0.5))
	mi.position = pos
	parent.add_child(mi)


func _local_kneel() -> Transform3D:
	# kneel_dist = da raiz dela até a frente do corpo do baú (o fuzil foi posto pensando nessa medida)
	return Transform3D(Basis(), Vector3(0, 0, SIZE.z * 0.5 + float(Moves.data().rifle.kneel_dist)))


## Onde ela fica ajoelhada para pegar a arma: na frente, olhando para o baú.
func kneel_transform() -> Transform3D:
	return global_transform * _local_kneel()


func has_item() -> bool:
	return item != ""


func open() -> void:
	create_tween().tween_property(_lid, "rotation_degrees:x", LID_OPEN, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Tira a arma do baú (as mãos dela chegaram nela) e devolve qual era.
func take_item() -> String:
	var w := item
	item = ""
	_rifle.visible = false
	return w


func is_open() -> bool:
	return _lid.rotation_degrees.x < -10.0


func reset() -> void:
	item = _start_item
	_rifle.visible = true
	_lid.rotation_degrees.x = 0.0
