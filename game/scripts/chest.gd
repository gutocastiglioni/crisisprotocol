class_name Chest
extends StaticBody3D
## Baú de armas em cima de um palete, com uma arma dentro (`item`: M16 ou escopeta; definir antes de entrar na
## árvore). Ela chega perto, aperta interagir (triângulo / E), ajoelha na frente (kneel_transform), a tampa abre e
## as mãos pegam a arma (PlayerMoves.start_pickup). A arma (m16.glb / shotgun.glb) já vem do build na posição em
## que as mãos dela a pegam, em relação à raiz ajoelhada (as duas têm o cabo e a telha nos mesmos pontos).
## Frente do baú = +Z local.
## Trancado (`lock` = id da chave, ver KeyItem; definir antes de entrar na árvore): ferrolho na tampa e cadeado
## pendurado na frente. Não abre sem a chave (Player.locked -> main mostra o cadeado de perto, `lock_view`, e
## chacoalha ele, `rattle`); com a chave, `unlock` solta o cadeado no chão e o baú volta a ser como os outros.

## arma -> [malha deitada no baú, textura do baú (estêncil)]
const ITEMS := {
	"m16": [preload("res://assets/characters/m16.glb"), "chest"],
	"shotgun": [preload("res://assets/characters/shotgun.glb"), "chest_shotgun"],
	"m79": [preload("res://assets/characters/m79.glb"), "chest_m79"],
}
const LOCK_Y := 0.43  # altura do cadeado (topo do corpo dele)
const STEEL := Color(0.42, 0.44, 0.47)
const BRASS := Color(0.78, 0.6, 0.26)
const ATLAS := preload("res://assets/characters/heroine_atlas.png")
const SIZE := Vector3(1.2, 0.42, 0.5)  # corpo do baú (largura, altura, fundo)
const PALLET := 0.12  # altura do palete
const WALL := 0.03
const LID_OPEN := -105.0  # graus (para trás)
const OPEN_TIME := 0.45

var item := "m16"
## id da chave que abre ("" = sem cadeado)
var lock := ""
var _start_item := ""
var _lid: Node3D
var _rifle: Node3D
var _unlocked := false
var _padlock: Node3D
var _shackle: Node3D
static var _plain: ImageTexture


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
	if lock != "":
		_build_lock()


## Ferrolho (chapa presa na tampa que desce sobre a frente e argola no corpo) e o cadeado pendurado na argola.
func _build_lock() -> void:
	var front := SIZE.z * 0.5
	var top := PALLET + SIZE.y
	# a chapa vai com a tampa quando abre
	_metal(_lid, Vector3(0.07, 0.11, 0.01), Vector3(0, -0.035, SIZE.z + 0.016), STEEL)
	_metal(self, Vector3(0.016, 0.03, 0.03), Vector3(0, top - 0.06, front + 0.026), STEEL)  # argola
	_padlock = Node3D.new()
	_padlock.position = Vector3(0, LOCK_Y, front + 0.04)
	add_child(_padlock)
	_metal(_padlock, Vector3(0.065, 0.06, 0.026), Vector3(0, -0.03, 0), BRASS)  # corpo
	_metal(_padlock, Vector3(0.012, 0.02, 0.004), Vector3(0, -0.035, 0.014), Color(0.15, 0.13, 0.1))  # buraco da chave
	_shackle = Node3D.new()
	_padlock.add_child(_shackle)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.017
	torus.outer_radius = 0.025
	torus.rings = 12
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _metal_mat(STEEL)
	ring.rotation.x = PI * 0.5  # argola em pé, de frente
	ring.position.y = 0.012  # sai de dentro do corpo e passa pela argola
	_shackle.add_child(ring)


func _metal(parent: Node3D, size: Vector3, pos: Vector3, tint: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _metal_mat(tint)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Metal liso da cor `tint` (o cadeado e o ferrolho são pequenos: textura de painel viraria um armário).
func _metal_mat(tint: Color) -> ShaderMaterial:
	if _plain == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_plain = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader()
	m.set_shader_parameter("albedo_tex", _plain)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("rim", 0.3)
	return m


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


func is_locked() -> bool:
	return lock != "" and not _unlocked


## Câmera de perto no cadeado (ou onde ele fica): um pouco acima e à frente, olhando para ele.
func lock_view() -> Transform3D:
	var at := global_transform * Vector3(0, LOCK_Y - 0.02, SIZE.z * 0.5 + 0.04)
	var eye := at + global_basis.z * 0.55 + Vector3.UP * 0.16 + global_basis.x * 0.12
	return Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)


## Puxou o cadeado trancado: ele chacoalha na argola (`pausable` = anda com o jogo pausado, no zoom).
func rattle() -> void:
	if _padlock == null:
		return
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for a in [0.35, -0.3, 0.22, -0.15, 0.0]:
		tw.tween_property(_padlock, "rotation:z", a, 0.06)


## Destranca: a haste do cadeado salta e ele cai no chão na frente do baú. Devolve a duração (s).
func unlock() -> float:
	_unlocked = true
	if _padlock == null:
		return 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.25)
	tw.tween_property(_shackle, "position:y", 0.022, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	var ground := Vector3(0.05, 0.02, SIZE.z * 0.5 + 0.12)
	tw.tween_property(_padlock, "position", ground, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_padlock, "rotation", Vector3(-PI * 0.5, 0.4, 0.0), 0.35)
	return 0.95


func open() -> void:
	Sfx.play(self, "chest_open", global_position + Vector3.UP * 0.6)
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
	_unlocked = false
	if _padlock:
		_padlock.position = Vector3(0, LOCK_Y, SIZE.z * 0.5 + 0.04)
		_padlock.rotation = Vector3.ZERO
		_shackle.position = Vector3.ZERO
	_rifle.visible = true
	_lid.rotation_degrees.x = 0.0
