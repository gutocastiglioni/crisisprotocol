class_name Fx
## Efeitos curtos do tiro, diferentes para cada arma e cada superfície: clarão no cano (pistola: quadrado médio;
## M16: pequeno com a língua de fogo para a frente; escopeta: grande, com língua larga e fumaça), traçante,
## impacto (sangue, ver Blood; poeira de concreto, lascas de madeira ou faíscas no metal), decalque do buraco de bala no
## cenário e cápsula ejetada (latão da pistola/M16, cartucho vermelho da escopeta). Explosão da granada da M79
## (`explosion`: bola de fogo, luz, fumaça, faíscas e terra) e a mancha de queimado que ela deixa (`scorch`).

const HOLES := preload("res://assets/textures/bullet_holes.png")
## quadros de shot_fx.png: clarão de 4 pontas, estrela de 3 jatos (M16), baforada macia (fumaça, poeira, sangue)
const SPRITES := preload("res://assets/textures/shot_fx.png")
const SCORCH := preload("res://assets/textures/scorch.png")
const SCORCH_SIZE := 2.4  # m
enum { BURST, STAR, PUFF }
const MAX_DECALS := 96  # os mais antigos somem
const GRAVITY := Vector3(0, -9.8, 0)
## clarão de cada arma: quadro de frente (tamanho), língua de fogo para a frente (comprimento, largura),
## cor, luz (energia, alcance), duração e baforadas de fumaça
const FLASH := {
	"pistol": {"size": 0.26, "sprite": BURST, "tongue": Vector2(0.0, 0.0), "color": Color(1.0, 0.85, 0.35), "light": 2.5, "range": 5.0, "life": 0.05, "smoke": 0},
	"m16": {"size": 0.24, "sprite": STAR, "tongue": Vector2(0.24, 0.035), "color": Color(1.0, 0.7, 0.3), "light": 1.8, "range": 4.0, "life": 0.045, "smoke": 0},
	"shotgun": {"size": 0.5, "sprite": BURST, "tongue": Vector2(0.45, 0.11), "color": Color(1.0, 0.78, 0.42), "light": 4.5, "range": 7.5, "life": 0.07, "smoke": 4},
	"m79": {"size": 0.5, "sprite": BURST, "tongue": Vector2(0.3, 0.16), "color": Color(1.0, 0.72, 0.38), "light": 3.5, "range": 6.0, "life": 0.07, "smoke": 6},
}
## traçante de cada arma: largura, cor, duração
const TRACER := {
	"pistol": [0.012, Color(1.0, 0.9, 0.6), 0.04],
	"m16": [0.01, Color(1.0, 0.72, 0.38), 0.035],
	"shotgun": [0.005, Color(1.0, 0.92, 0.75), 0.03],
}
## superfície (meta "surface" do corpo atingido, ver Level.block): poeira, faíscas, mossa de metal e cor do decalque
const SURFACES := {
	"concrete": {"dust": Color(0.6, 0.58, 0.53), "sparks": 0, "metal": false, "tint": Color(1, 1, 1)},
	"hazard": {"dust": Color(0.6, 0.58, 0.53), "sparks": 0, "metal": false, "tint": Color(1, 1, 1)},
	"crate": {"dust": Color(0.6, 0.44, 0.27), "sparks": 0, "metal": false, "tint": Color(1.0, 0.78, 0.55)},
	"wall": {"dust": Color(0.45, 0.45, 0.48), "sparks": 5, "metal": true, "tint": Color(1, 1, 1)},
	"metal": {"dust": Color(0.45, 0.45, 0.48), "sparks": 5, "metal": true, "tint": Color(0.9, 1.0, 0.85)},
}

static var _decals: Array = []  # Node3D, do mais antigo ao mais novo
static var _decal_meshes := {}
static var _decal_mats := {}


static func _unshaded(color: Color, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _temp(parent: Node, node: Node3D, at: Vector3, life: float) -> void:
	parent.add_child(node)
	node.global_position = at
	parent.get_tree().create_timer(life).timeout.connect(node.queue_free)


## Quadro de frente para a câmera com o `sprite` de shot_fx.png (`glow` = soma a luz: clarões).
static func _quad(size: float, color: Color, sprite := PUFF, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := _unshaded(color)
	m.albedo_texture = SPRITES
	m.uv1_scale = Vector3(1.0 / 3.0, 1.0, 1.0)
	m.uv1_offset = Vector3(sprite / 3.0, 0.0, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Caixa esticada de `from` até `to` (traçante, língua de fogo, faísca).
static func _streak(parent: Node, from: Vector3, to: Vector3, width: float, color: Color, life: float) -> void:
	var len := from.distance_to(to)
	if len < 0.01:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, len)
	mi.mesh = box
	mi.material_override = _unshaded(color, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_temp(parent, mi, (from + to) * 0.5, life)
	mi.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)


## Língua de fogo saindo do cano: dois quadros cruzados ao longo de `dir` (de trás ficam de lado e quase somem,
## em vez de mostrar a ponta quadrada de uma caixa). `size` = (comprimento, largura).
static func _tongue(parent: Node, at: Vector3, dir: Vector3, size: Vector2, life: float) -> void:
	var root := Node3D.new()
	for roll in [0.0, PI * 0.5]:
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(size.y, size.x)
		mi.mesh = q
		var m := _unshaded(Color(1.0, 0.9, 0.6), false)
		m.albedo_texture = SPRITES
		m.uv1_scale = Vector3(1.0 / 3.0, 1.0, 1.0)
		m.uv1_offset = Vector3(BURST / 3.0, 0.0, 0.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# quadro deitado ao longo de Z (o comprimento), girado `roll` em volta dele
		mi.basis = Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, PI * 0.5)
		root.add_child(mi)
	_temp(parent, root, at + dir * size.x * 0.5, life)
	root.look_at(at + dir * size.x, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)


## Partícula que voa com gravidade (`fall` = quanto da gravidade), cresce e some.
static func _particle(parent: Node, at: Vector3, vel: Vector3, size: float, color: Color, life: float, grow := 1.0, fall := 1.0) -> void:
	var mi := _quad(size, color)
	var mat := mi.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	parent.add_child(mi)
	mi.global_position = at
	var a0 := color.a
	var step := func(t: float) -> void:
		mi.global_position = at + vel * t + GRAVITY * (0.5 * fall * t * t)
		mi.scale = Vector3.ONE * lerpf(1.0, grow, t / life)
		mat.albedo_color.a = a0 * (1.0 - t / life)
	var tw := mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


## Fumaça: baforada cinza em `at` voando a `vel` (sobe devagar), que cresce `grow` vezes e some em `life` s.
static func smoke(parent: Node, at: Vector3, vel: Vector3, size: float, life: float, grow := 3.0) -> void:
	_particle(parent, at, vel, size, Color(0.5, 0.5, 0.48, 0.45), life, grow, -0.05)


## Explosão da granada em `at` (`normal` da superfície): clarão que cresce, luz forte que apaga, línguas de fogo, faíscas,
## terra/lascas que caem e fumaça escura subindo.
static func explosion(parent: Node, at: Vector3, normal := Vector3.UP) -> void:
	var n := normal.normalized() if normal.length() > 0.5 else Vector3.UP
	var root := Node3D.new()
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 9.0
	light.omni_range = 13.0
	root.add_child(light)
	var ball := _quad(1.0, Color(1.0, 0.75, 0.35), BURST, true)
	root.add_child(ball)
	var core := _quad(1.2, Color(1.0, 0.55, 0.2, 0.9), PUFF, true)
	root.add_child(core)
	_temp(parent, root, at + n * 0.3, 0.6)
	var tw := root.create_tween().set_parallel()
	tw.tween_property(light, "light_energy", 0.0, 0.45).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "scale", Vector3.ONE * 3.6, 0.22).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "transparency", 1.0, 0.25)
	tw.tween_property(core, "scale", Vector3.ONE * 3.0, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(core, "transparency", 1.0, 0.45)
	# línguas de fogo para fora, mais para o lado de fora da superfície
	for i in 9:
		var v := (n * 1.2 + Vector3(randf_range(-1, 1), randf_range(-0.3, 1), randf_range(-1, 1))).normalized() * randf_range(2.5, 5.0)
		_particle(parent, at + n * 0.2, v, 0.45, Color(1.0, 0.5, 0.15, 0.85), randf_range(0.3, 0.45), 2.5, -0.1)
	for i in 14:
		var dir := (n + Vector3(randf_range(-1, 1), randf_range(-0.2, 1), randf_range(-1, 1))).normalized()
		_streak(parent, at + dir * 0.2, at + dir * randf_range(0.8, 1.8), 0.02, Color(1.0, 0.8, 0.4), 0.1)
	# terra e lascas que sobem e caem
	for i in 10:
		var v := (n * 1.5 + Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1))).normalized() * randf_range(3.0, 6.0)
		_particle(parent, at, v, 0.06, Color(0.25, 0.22, 0.18), randf_range(0.6, 0.9))
	# fumaça escura subindo e abrindo
	for i in 10:
		var v := Vector3(randf_range(-1.2, 1.2), randf_range(0.8, 2.2), randf_range(-1.2, 1.2)) + n * 0.6
		_particle(parent, at + n * 0.4 + v * 0.1, v, 0.7, Color(0.16, 0.15, 0.14, 0.7), randf_range(1.6, 2.6), 4.0, -0.06)


## Mancha de queimado no cenário onde a granada explodiu (presa ao corpo atingido, conta junto com os buracos de bala
## em MAX_DECALS e some com o R). Só em cenário (não em personagem, ragdoll ou "no_decals") e sem pendurar em
## quina: se a mancha inteira não cabe, tenta a metade; senão, nenhuma. Devolve o nó ou null.
static func scorch(body: Object, at: Vector3, normal: Vector3) -> Node3D:
	var host := body as CollisionObject3D
	if host == null or host is PhysicalBone3D or host.has_method("take_hit") or host.get_meta("no_decals", false):
		return null
	if not host.is_inside_tree() or normal.length() < 0.5:
		return null
	var n := normal.normalized()
	var helper := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var tangent := helper.cross(n).normalized().rotated(n, randf() * TAU)
	var bitangent := n.cross(tangent)
	var space := host.get_world_3d().direct_space_state
	for size in [SCORCH_SIZE, SCORCH_SIZE * 0.5]:
		var fits := true
		for c in [tangent + bitangent, tangent - bitangent, -tangent + bitangent, -tangent - bitangent]:
			var p: Vector3 = at + c * size * 0.35
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + n * 0.05, p - n * 0.12, 1))
			if h.is_empty() or h.collider != host or (h.normal as Vector3).dot(n) < 0.95:
				fits = false
				break
		if not fits:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Scorch"
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mi.mesh = q
		var m := ShaderMaterial.new()
		m.shader = Gfx.shader(true)
		m.set_shader_parameter("albedo_tex", SCORCH)
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mi)
		mi.global_transform = Transform3D(Basis(tangent, bitangent, n).scaled(Vector3.ONE * size), at - n * 0.045 + n * 0.006)
		mi.add_to_group("bullet_decals")
		_decals.append(mi)
		while _decals.size() > MAX_DECALS:
			var old: Node3D = _decals.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		return mi
	return null


## Clarão no cano de `kind` ("pistol", "m16", "shotgun", "m79") apontando para `dir`.
static func muzzle_flash(parent: Node, at: Vector3, kind := "pistol", dir := Vector3.ZERO) -> void:
	var f: Dictionary = FLASH.get(kind, FLASH.pistol)
	var root := Node3D.new()
	root.add_child(_quad(f.size, f.color, f.sprite, true))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = f.light
	light.omni_range = f.range
	root.add_child(light)
	_temp(parent, root, at, f.life)
	var tongue: Vector2 = f.tongue
	if tongue.x > 0.0 and dir.length() > 0.1:
		_tongue(parent, at, dir.normalized(), tongue, f.life)
	for i in int(f.smoke):
		var v := dir.normalized() * randf_range(0.4, 1.2) + Vector3(randf_range(-0.2, 0.2), randf_range(0.2, 0.5), randf_range(-0.2, 0.2))
		_particle(parent, at + dir.normalized() * 0.1 * i, v, 0.16, Color(0.55, 0.55, 0.55, 0.5), randf_range(0.5, 0.8), 3.0, -0.05)


static func tracer(parent: Node, from: Vector3, to: Vector3, kind := "pistol") -> void:
	if from.distance_to(to) < 0.3:
		return
	var t: Array = TRACER.get(kind, TRACER.pistol)
	_streak(parent, from, to, t[0], t[1], t[2])


## Impacto em `at` com a normal da superfície: carne (sangue) ou cenário (`surface` = chave de SURFACES).
static func impact(parent: Node, at: Vector3, flesh: bool, normal := Vector3.UP, surface := "concrete") -> void:
	if flesh:
		Blood.splash(parent, at, -normal, normal, 0.7)
		return
	var s: Dictionary = SURFACES.get(surface, SURFACES.concrete)
	Sfx.play(parent as Node3D, "impact_metal" if s.metal else ("impact_wood" if surface == "crate" else "impact_concrete"), at)
	_temp(parent, _quad(0.09, Color(1.0, 0.95, 0.75), BURST, true), at + normal * 0.01, 0.03)
	for i in 2:
		var v := normal * randf_range(0.4, 0.9) + Vector3(randf_range(-0.2, 0.2), 0.15, randf_range(-0.2, 0.2))
		var dust: Color = s.dust
		_particle(parent, at + normal * 0.02, v, 0.08, Color(dust, 0.75), randf_range(0.35, 0.55), 2.2, 0.15)
	for i in int(s.sparks):
		var dir := (normal + Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.8), randf_range(-0.7, 0.7))).normalized()
		_streak(parent, at + dir * 0.02, at + dir * randf_range(0.12, 0.3), 0.008, Color(1.0, 0.85, 0.4), 0.06)
	if not s.metal:
		# lascas (concreto, madeira) voando para fora
		for i in 2:
			var v := normal * randf_range(1.0, 2.0) + Vector3(randf_range(-0.6, 0.6), randf_range(0.3, 1.0), randf_range(-0.6, 0.6))
			_particle(parent, at, v, 0.025, s.dust.darkened(0.3), 0.35)


# ------------------------------------------------------------------ decalques (buracos de bala)
## Quadro do atlas bullet_holes.png: buraco de bala (0 = concreto/madeira, 1 = mossa no metal), chumbo (2, 3).
static func _decal_mesh(frame: int) -> ArrayMesh:
	if _decal_meshes.has(frame):
		return _decal_meshes[frame]
	var u0 := (frame % 2) * 0.5
	var v0 := (frame / 2) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corners := [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]
	var uvs := [Vector2(u0, v0 + 0.5), Vector2(u0 + 0.5, v0 + 0.5), Vector2(u0 + 0.5, v0), Vector2(u0, v0)]
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(Vector3.BACK)
		st.set_uv(uvs[i])
		st.add_vertex(Vector3(corners[i].x, corners[i].y, 0.0))
	var mesh := st.commit()
	_decal_meshes[frame] = mesh
	return mesh


static func _decal_material(tint: Color) -> ShaderMaterial:
	var m: ShaderMaterial = _decal_mats.get(tint)
	if m == null:
		m = ShaderMaterial.new()
		m.set_shader_parameter("albedo_tex", HOLES)
		m.set_shader_parameter("tint", tint)
		_decal_mats[tint] = m
	# o modo de visual pode ter mudado desde a última vez (os que estão na árvore o Gfx já trocou)
	m.shader = Gfx.shader(true)
	return m


## Buraco de bala no cenário em `at` (normal `normal`), preso ao corpo atingido (anda junto com ele).
## `pellet` = chumbo da escopeta (menor). Não marca personagens, alvos nem corpos com meta "no_decals", e só
## marca se o quadro inteiro cabe na superfície (sem ficar pendurado numa quina). Devolve o nó ou null.
static func decal(body: Object, at: Vector3, normal: Vector3, size: float, pellet := false) -> Node3D:
	var host := body as CollisionObject3D
	if host == null or host is PhysicalBone3D or host.has_method("take_hit") or host.get_meta("no_decals", false):
		return null
	if not host.is_inside_tree() or normal.length() < 0.5:
		return null
	var n := normal.normalized()
	var helper := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var tangent := helper.cross(n).normalized().rotated(n, randf() * TAU)
	var bitangent := n.cross(tangent)
	var space := host.get_world_3d().direct_space_state
	for c in [tangent + bitangent, tangent - bitangent, -tangent + bitangent, -tangent - bitangent]:
		var p: Vector3 = at + c * size * 0.4
		var q := PhysicsRayQueryParameters3D.create(p + n * 0.03, p - n * 0.03, 1)
		var h := space.intersect_ray(q)
		if h.is_empty() or h.collider != host or (h.normal as Vector3).dot(n) < 0.95:
			return null
	var s: Dictionary = SURFACES.get(host.get_meta("surface", "concrete"), SURFACES.concrete)
	var mi := MeshInstance3D.new()
	mi.name = "BulletHole"
	mi.mesh = _decal_mesh((2 if pellet else 0) + (1 if s.metal else 0))
	mi.material_override = _decal_material(s.tint)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	mi.global_transform = Transform3D(Basis(tangent, bitangent, n).scaled(Vector3.ONE * size), at + n * 0.004)
	mi.add_to_group("bullet_decals")
	_decals.append(mi)
	while _decals.size() > MAX_DECALS:
		var old: Node3D = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	return mi


static func decal_count() -> int:
	# sem tipo no parâmetro: o corpo que levava o buraco pode ter sido apagado (objeto inválido)
	_decals = _decals.filter(func(d: Variant) -> bool: return is_instance_valid(d) and not (d as Node).is_queued_for_deletion())
	return _decals.size()


## Apaga todos os buracos de bala (reinício).
static func clear_decals() -> void:
	for d in _decals:
		if is_instance_valid(d):
			d.queue_free()
	_decals.clear()


# ------------------------------------------------------------------ cápsulas
## Cápsula ejetada: "brass" (latão da pistola e do M16) ou "shell" (cartucho vermelho da escopeta). Voa, gira,
## para no chão embaixo dela e some depois de alguns segundos.
static func casing(parent: Node, at: Vector3, vel: Vector3, kind := "brass") -> void:
	var shell := kind == "shell"
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.022, 0.022, 0.065) if shell else Vector3(0.009, 0.009, 0.024)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.08, 0.06) if shell else Color(0.78, 0.6, 0.25)
	m.metallic = 0.0 if shell else 0.6
	m.roughness = 0.5
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	var floor_y := at.y - 3.0
	var hit := mi.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 3.0, 1))
	if hit:
		floor_y = hit.position.y + box.size.x * 0.5
	var axis := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var state := {"landed": false}
	var step := func(t: float) -> void:
		if state.landed:
			return
		var p := at + vel * t + GRAVITY * (0.5 * t * t)
		if p.y <= floor_y and t > 0.05:
			p.y = floor_y
			state.landed = true
			mi.global_basis = Basis(Vector3.UP, randf() * TAU)  # deitada (o comprimento é o Z da caixa)
			Sfx.play(mi, "casing_" + kind, p)
		else:
			mi.global_basis = Basis(axis, t * 25.0)
		mi.global_position = p
	var tw := mi.create_tween()
	tw.tween_method(step, 0.0, 1.2, 1.2)
	tw.tween_interval(4.0)
	tw.tween_callback(mi.queue_free)
