class_name SupplyDrop
extends StaticBody3D
## Caixa de lançamento aéreo caída de paraquedas no telhado da sala dos clones, bem no fundo (`POS`): caixa de
## compensado oliva com cintas de carga, caída torta, a lona do paraquedas murcha esparramada atrás e as cordas até as
## alças da caixa. Fica escondida na neblina do telhado (Roof._fog) até ela chegar perto. Interagir (E) na frente: igual
## ao baú (PlayerMoves.start_pickup), ela ajoelha (kneel_transform), a tampa abre (`open`), a mão direita pega a pistola
## com silenciador deitada na caixa (animação PickupPistol; `take_item` no quadro da pegada), que entra no lugar da
## pistola dela (`Player.silencer`: mesma arma e munição, tiro abafado), e ela levanta; no fim (`finish`) o sinal
## `picked` faz o main mostrar o item (Inspect.show_drop). A pistola na caixa (pistol_crate.glb) já vem do build onde a
## mão a pega, em relação à raiz ajoelhada (art/heroine_drop.py). Reinício (`reset`): fechada de novo, com a pistola
## dentro. Frente = +Z local.

signal picked(drop: SupplyDrop)

const POS := Vector3(-3.4, CloneLab.CEIL_Y + 0.3, -23.6)  # em cima da laje do anexo, perto da borda do fundo
const YAW := 0.4
const SIZE := Vector3(0.9, 0.42, 0.62)  # corpo (sem a tampa)
const LID_T := 0.06
const TILT := 3.0  # graus em volta da frente: caiu com um lado apoiado na lona dobrada
const PICK_RANGE := 0.9  # do lugar de ajoelhar até ela (o mesmo do baú)
const LID_OPEN := -100.0  # graus (para trás)
const OPEN_TIME := 0.45
const ITEM := preload("res://assets/characters/pistol_sd.glb")  # sozinha, para a tela do item
const CRATE_ITEM := preload("res://assets/characters/pistol_crate.glb")  # deitada onde a mão a pega
const ATLAS := preload("res://assets/characters/heroine_atlas.png")
const NAME := "PISTOLA COM SILENCIADOR"
const DESCRIPTION := "Pistola .45 com silenciador rosqueado.\nTiro abafado: so quem esta perto ouve."
## lona: retângulo atrás da caixa (x0, x1, z0, z1 em relação à caixa) e grade de pontos
const CHUTE := [-1.4, 1.5, -0.45, -2.75]
const CHUTE_GRID := Vector2i(9, 7)

var _lid: Node3D
var _pistol: Node3D
var _taken := false
var _tween: Tween
static var _white: ImageTexture


func _ready() -> void:
	add_to_group("drops")
	collision_layer = 1
	collision_mask = 0
	set_meta("surface", "crate")  # compensado: poeira de madeira
	set_meta("no_decals", true)  # caixa torta e tampa que abre: buraco de bala ficaria flutuando
	var crate := Node3D.new()
	crate.rotation_degrees.z = TILT
	add_child(crate)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE.x, SIZE.y + LID_T, SIZE.z)
	col.shape = shape
	col.rotation_degrees.z = TILT
	col.position = crate.transform * Vector3(0, (SIZE.y + LID_T) * 0.5, 0)
	add_child(col)
	var paint := _mat("drop_crate")
	_cube(crate, SIZE, Vector3(0, SIZE.y * 0.5, 0), paint)
	# espuma escura por dentro (aparece com a tampa aberta) e a pistola deitada nela
	var foam := MeshInstance3D.new()
	var fq := PlaneMesh.new()
	fq.size = Vector2(SIZE.x - 0.08, SIZE.z - 0.08)
	foam.mesh = fq
	foam.material_override = _plain(Color(0.3, 0.31, 0.27))  # cinza claro: a pistola preta aparece nela
	foam.position.y = SIZE.y + 0.002
	crate.add_child(foam)
	# o glTF olha para +Z: girado como o modelo dela, na raiz ajoelhada (fora da caixa torta: a mão chega certo nela)
	_pistol = _atlas(CRATE_ITEM.instantiate())
	add_child(_pistol)
	_pistol.transform = _local_kneel() * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	# tampa com a dobradiça na borda de trás
	_lid = Node3D.new()
	_lid.position = Vector3(0, SIZE.y, -SIZE.z * 0.5)
	crate.add_child(_lid)
	_cube(_lid, Vector3(SIZE.x + 0.02, LID_T, SIZE.z + 0.02), Vector3(0, LID_T * 0.5, SIZE.z * 0.5), paint)
	# alças de metal nos quatro cantos de cima, onde as cordas prendem
	var steel := _plain(Color(0.4, 0.42, 0.44))
	var lugs: Array[Vector3] = []
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := Vector3(sx * (SIZE.x * 0.5 + 0.015), SIZE.y - 0.05, sz * (SIZE.z * 0.5 - 0.08))
			var lug := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(0.03, 0.05, 0.06)
			lug.mesh = lb
			lug.material_override = steel
			lug.position = at
			crate.add_child(lug)
			lugs.append(crate.transform * at)
	_build_chute(lugs)


## A pistola com silenciador sozinha (pistol_sd.glb: origem no meio dela, cano +X, ferrolho +Y), com o atlas da heroína.
static func build_item(parent: Node3D) -> Node3D:
	var gun := _atlas(ITEM.instantiate())
	parent.add_child(gun)
	return gun


static func _atlas(gun: Node3D) -> Node3D:
	for mi: MeshInstance3D in gun.find_children("*", "MeshInstance3D", true, false):
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader()
		m.set_shader_parameter("albedo_tex", ATLAS)
		m.set_shader_parameter("rim", 0.35)
		mi.material_override = m
	return gun


## Lona murcha: grade com dobras (ondas + sorteio fixo), mais alta junto da caixa (encostada nela) e um bolsão de ar no
## meio; as cordas saem da borda da frente da lona até as alças.
func _build_chute(lugs: Array[Vector3]) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := CHUTE_GRID.x
	var nz := CHUTE_GRID.y
	var pts: Array[Vector3] = []
	for j in nz:
		for i in nx:
			var u := float(i) / (nx - 1)
			var v := float(j) / (nz - 1)
			var x := lerpf(CHUTE[0], CHUTE[1], u) + rng.randf_range(-0.08, 0.08)
			var z := lerpf(CHUTE[2], CHUTE[3], v) + rng.randf_range(-0.08, 0.08)
			var fold := maxf(0.0, sin(x * 3.4 + z * 1.2)) * 0.12 + maxf(0.0, sin(z * 4.1 - x * 0.7)) * 0.07
			var puff := exp(-(pow((x - 0.4) / 0.6, 2.0) + pow((z + 1.7) / 0.5, 2.0))) * 0.24
			var lean := 0.22 * maxf(0.0, 1.0 - v * 3.0) * (1.0 - absf(u - 0.5) * 1.6)  # encostada na caixa
			var edge := 0.0 if i == 0 or j == nz - 1 or i == nx - 1 else 1.0
			pts.append(Vector3(x, 0.015 + (fold + puff) * edge + maxf(lean, 0.0), z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			for k in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.set_uv(Vector2(pts[k].x, pts[k].z) * 0.6)
				st.add_vertex(pts[k])
	st.generate_normals()
	var cloth := MeshInstance3D.new()
	cloth.mesh = st.commit()
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader(true)  # dos dois lados: as dobras mostram o avesso
	m.set_shader_parameter("albedo_tex", Level.TEX["chute"])
	m.set_shader_parameter("rim", 0.2)
	cloth.material_override = m
	cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cloth)
	# cordas: das alças até pontos da borda da frente da lona (as de trás passam por cima da caixa)
	var cord := _plain(Color(0.62, 0.6, 0.5))
	for k in lugs.size():
		var i := 1 + k * 2
		for s in [0, 1]:
			_cord(lugs[k], pts[nx + mini(i + s, nx - 2)] + Vector3.UP * 0.02, cord)


func _cord(a: Vector3, b: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.008, 0.008, a.distance_to(b))
	mi.mesh = bm
	mi.material_override = mat
	add_child(mi)
	mi.look_at_from_position((a + b) * 0.5, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Caixa com a textura inteira em cada face (o estêncil e as cintas aparecem certos mesmo com a caixa girada).
func _cube(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	# cada face: normal, eixo da direita e eixo de cima da textura
	for f in [[Vector3.FORWARD, Vector3.LEFT, Vector3.UP], [Vector3.BACK, Vector3.RIGHT, Vector3.UP],
			[Vector3.LEFT, Vector3.BACK, Vector3.UP], [Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
			[Vector3.UP, Vector3.RIGHT, Vector3.FORWARD], [Vector3.DOWN, Vector3.RIGHT, Vector3.BACK]]:
		var n: Vector3 = f[0]
		var r: Vector3 = f[1]
		var up: Vector3 = f[2]
		var c := n * h
		var rr := r * h
		var uu := up * h
		var quad := [c - rr - uu, c + rr - uu, c + rr + uu, c - rr + uu]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for k in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[k])
			st.add_vertex(quad[k] + at)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _mat(tex: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Gfx.shader()
	m.set_shader_parameter("albedo_tex", Level.TEX[tex])
	m.set_shader_parameter("rim", 0.25)
	return m


func _plain(tint: Color) -> ShaderMaterial:
	if _white == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	var m := _mat("drop_crate")
	m.set_shader_parameter("albedo_tex", _white)
	m.set_shader_parameter("tint", tint)
	return m


func _local_kneel() -> Transform3D:
	# kneel_dist = da raiz dela até a frente do corpo (a mesma do baú; a pistola foi posta pensando nessa medida)
	return Transform3D(Basis(), Vector3(0, 0, SIZE.z * 0.5 + float(Moves.data().rifle.kneel_dist)))


## Onde ela fica ajoelhada para pegar a pistola: na frente, olhando para a caixa.
func kneel_transform() -> Transform3D:
	return global_transform * _local_kneel()


## Ponto no chão onde ela ajoelha (aviso e revisão).
func front_point() -> Vector3:
	return kneel_transform().origin


func has_item() -> bool:
	return not _taken


## Ela (pés em `pos`) está na frente da caixa fechada, perto o bastante para abrir?
func can_pick(pos: Vector3) -> bool:
	var d := front_point() - pos
	return not _taken and Vector2(d.x, d.z).length() < PICK_RANGE and absf(d.y) < 0.8


## Ela começou a ajoelhar: a tampa abre.
func open() -> void:
	Sfx.play(self, "chest_open", global_position + Vector3.UP * 0.5)
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation_degrees:x", LID_OPEN, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## A mão chegou na pistola: ela sai da caixa (PlayerMoves põe o silenciador e a dá para a mão). Devolve a arma.
func take_item() -> String:
	_taken = true
	_pistol.visible = false
	return "pistol"


## Ela levantou com a pistola: mostra o item.
func finish() -> void:
	picked.emit(self)


func reset() -> void:
	if _tween:
		_tween.kill()  # R com a tampa abrindo
	_taken = false
	_pistol.visible = true
	_lid.rotation_degrees.x = 0.0
