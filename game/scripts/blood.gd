class_name Blood
## Sangue no jeito Dino Crisis: esguicho vermelho no ponto do golpe (quadros de frente para a câmera crescendo rápido)
## com gotas voando que viram respingos onde caem, respingo na parede/chão atrás de quem levou o tiro, rastro de gotas
## de quem está ferido (`Trail`) e poça crescendo embaixo do corpo (`pool`). Respingos e poças são decalques presos ao
## corpo do cenário (como os buracos de bala), no máximo `MAX_SPLATS`; `clear()` apaga tudo (reinício).

## blood_fx.png, 2x2 quadros: esguicho (de frente para a câmera), respingo, gotas do rastro, poça
const TEX := preload("res://assets/textures/blood_fx.png")
enum { SPRAY, SPLAT, DROPS, POOL }
const MAX_SPLATS := 120  # os mais antigos somem
const GRAVITY := Vector3(0, -9.8, 0)
const COLOR := Color(0.62, 0.03, 0.03)
const SPATTER_RANGE := 2.5  # até onde o sangue que atravessa marca a parede/chão atrás
const POOL_DELAY := 1.4  # o ragdoll assenta antes da poça começar
const POOL_GROW := 6.0  # segundos até a poça chegar ao tamanho cheio

static var _splats: Array = []  # Node3D, do mais antigo ao mais novo
static var _mat: ShaderMaterial
static var _meshes := {}
static var _layer := 0  # alterna a altura dos decalques novos (sem piscar onde um cobre o outro)
static var _generation := 0  # muda no clear(): poças que ainda iam aparecer desistem


## Esguicho num golpe em `at`: `dir` = para onde o golpe ia (o sangue sai por ali), `normal` = da superfície atingida
## (respinga de volta também), `amount` ~ tamanho do ferimento (1 = tiro de pistola), `head` = tiro na cabeça
## (esguicho grande, névoa e mais gotas).
static func splash(parent: Node, at: Vector3, dir: Vector3, normal: Vector3, amount := 1.0, head := false) -> void:
	if not parent.is_inside_tree():
		return
	var d := dir.normalized() if dir.length() > 0.01 else -normal.normalized()
	var n := normal.normalized() if normal.length() > 0.01 else -d
	var a := clampf(amount, 0.2, 2.0) * (1.8 if head else 1.0)
	var space := (parent as Node3D).get_world_3d().direct_space_state if parent is Node3D else null
	# esguicho: um quadro de frente no ponto e outro saindo pelo outro lado
	_spray(parent, at + n * 0.03, 0.3 + 0.24 * a, 0.18)
	if a >= 0.6:
		_spray(parent, at + d * 0.2, 0.26 + 0.2 * a, 0.22)
	if head:
		for i in 4:
			var v := d * randf_range(0.6, 1.4) + Vector3(randf_range(-0.4, 0.4), randf_range(0.1, 0.6), randf_range(-0.4, 0.4))
			Fx._particle(parent, at, v, 0.14, Color(0.7, 0.05, 0.04, 0.7), randf_range(0.35, 0.55), 3.2, 0.2)
	# gotas: a maior parte sai junto com o golpe, algumas voltam pela frente
	for i in roundi(4.0 * a):
		var out := d if randf() < 0.7 else n
		var v := out * randf_range(1.0, 3.2) + Vector3(randf_range(-0.9, 0.9), randf_range(0.4, 1.8), randf_range(-0.9, 0.9))
		_droplet(parent, space, at, v, randf_range(0.03, 0.05))
	if space == null:
		return
	# respingo na parede/chão atrás (o que atravessou)
	if randf() < a:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + d * SPATTER_RANGE * (1.4 if head else 1.0), 1))
		if hit:
			var size := randf_range(0.35, 0.55) * minf(a, 1.6)
			_later(parent, at.distance_to(hit.position) / 14.0, func() -> void:
				if is_instance_valid(hit.collider):
					splat(hit.collider, hit.position, hit.normal, size, SPLAT))
	# o que escorre do ferimento cai logo embaixo
	var below := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + d * 0.25, at + d * 0.25 + Vector3.DOWN * 3.0, 1))
	if below:
		var size := randf_range(0.22, 0.32) * minf(a, 1.6)
		_later(parent, 0.3, func() -> void:
			if is_instance_valid(below.collider):
				splat(below.collider, below.position, below.normal, size, SPLAT))


## Quadro do esguicho: aparece pequeno, abre rápido e some.
static func _spray(parent: Node, at: Vector3, size: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := Fx._unshaded(Color(1.0, 0.12, 0.1))  # sem luz: vermelho vivo até no escuro, como no Dino Crisis
	m.albedo_texture = TEX
	m.uv1_scale = Vector3(0.5, 0.5, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at
	mi.rotation.z = randf() * TAU
	var step := func(t: float) -> void:
		var k := t / life
		mi.scale = Vector3.ONE * lerpf(0.35, 1.25, sqrt(k))
		m.albedo_color.a = 1.0 - k * k
	var tw := mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	tw.tween_callback(mi.queue_free)


## Gota que voa com gravidade e, onde bate no cenário, deixa um respingo pequeno.
static func _droplet(parent: Node, space: PhysicsDirectSpaceState3D, at: Vector3, vel: Vector3, size: float) -> void:
	var land := {}
	var life := 0.9
	if space:
		# o caminho em pedaços: o primeiro que bate no cenário é onde a gota cai
		var dt := 0.06
		var t := 0.0
		var p0 := at
		while t < life:
			var p1 := at + vel * (t + dt) + GRAVITY * (0.5 * (t + dt) * (t + dt))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p0, p1, 1))
			if hit:
				land = hit
				life = t + dt * p0.distance_to(hit.position) / maxf(p0.distance_to(p1), 0.001)
				break
			p0 = p1
			t += dt
	var mi := Fx._quad(size, COLOR)
	parent.add_child(mi)
	mi.global_position = at
	var step := func(t: float) -> void:
		mi.global_position = at + vel * t + GRAVITY * (0.5 * t * t)
	var tw := mi.create_tween()
	tw.tween_method(step, 0.0, life, life)
	if land:
		var s := randf_range(0.09, 0.17)
		var gen := _generation
		tw.tween_callback(func() -> void:
			if gen == _generation and is_instance_valid(land.collider):
				splat(land.collider, land.position, land.normal, s, DROPS if randf() < 0.5 else SPLAT))
	tw.tween_callback(mi.queue_free)


static func _later(parent: Node, delay: float, fn: Callable) -> void:
	var gen := _generation
	parent.get_tree().create_timer(delay, false).timeout.connect(func() -> void:
		if gen == _generation:
			fn.call())


# ------------------------------------------------------------------ decalques (respingos e poças)
static func _mesh(frame: int) -> ArrayMesh:
	if not _meshes.has(frame):
		_meshes[frame] = Fx._decal_mesh(frame)  # mesmo layout 2x2 do atlas dos buracos de bala
	return _meshes[frame]


static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.set_shader_parameter("albedo_tex", TEX)
	# o modo de visual pode ter mudado desde a última vez (os que estão na árvore o Gfx já trocou)
	_mat.shader = Gfx.shader(true)
	return _mat


## Superfície que leva sangue: cenário (camada 1), sem personagens/ragdoll nem corpos com meta "no_decals" (baú).
static func _paintable(body: Object) -> bool:
	var host := body as CollisionObject3D
	return host != null and host.is_inside_tree() and not host is PhysicalBone3D and not host.has_method("take_hit") \
		and not host.get_meta("no_decals", false)


## Decalque de sangue (`frame` = SPLAT, DROPS ou POOL) de lado `size` em `at`, rente à superfície de normal `normal`,
## preso a `body`. Pode passar de um corpo do cenário para outro (piso em placas), mas não fica pendurado numa quina:
## se não cabe, tenta menor; não cabendo, devolve null.
static func splat(body: Object, at: Vector3, normal: Vector3, size: float, frame := SPLAT) -> Node3D:
	if not _paintable(body) or normal.length() < 0.5:
		return null
	var host := body as CollisionObject3D
	var n := normal.normalized()
	var helper := Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT
	var tangent := helper.cross(n).normalized().rotated(n, randf() * TAU)
	var bitangent := n.cross(tangent)
	var space := host.get_world_3d().direct_space_state
	var fits := func(s: float) -> bool:
		for c in [tangent + bitangent, tangent - bitangent, -tangent + bitangent, -tangent - bitangent]:
			var p: Vector3 = at + c * s * 0.4
			var h := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + n * 0.05, p - n * 0.05, 1))
			if h.is_empty() or (h.normal as Vector3).dot(n) < 0.9 or not _paintable(h.collider):
				return false
		return true
	if not fits.call(size):
		size *= 0.55
		if not fits.call(size):
			return null
	var mi := MeshInstance3D.new()
	mi.name = "Blood"
	mi.mesh = _mesh(frame)
	mi.material_override = _material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	# poças por cima dos respingos; entre os outros, cada novo um pouco mais alto que o anterior
	_layer = (_layer + 1) % 12
	var lift := 0.003 + _layer * 0.0004 + (0.006 if frame == POOL else 0.0)
	mi.global_transform = Transform3D(Basis(tangent, bitangent, n).scaled(Vector3.ONE * size), at + n * lift)
	mi.add_to_group("blood")
	_splats.append(mi)
	while _splats.size() > MAX_SPLATS:
		var old: Variant = _splats.pop_front()  # sem tipo: pode já ter sido apagado junto com o corpo
		if is_instance_valid(old):
			old.queue_free()
	return mi


## Poça embaixo de `body` (parte do ragdoll de quem morreu): espera o corpo assentar e cresce até `size`.
static func pool(body: Node3D, size: float, delay := POOL_DELAY) -> void:
	if not body.is_inside_tree():
		return
	var ref: WeakRef = weakref(body)  # o corpo pode ser apagado antes da hora
	_later(body, delay, func() -> void:
		var b: Node3D = ref.get_ref()
		if b == null or not b.is_inside_tree():
			return
		var from := b.global_position + Vector3.UP * 0.3
		var hit := b.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1))
		if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
			return
		var mi := splat(hit.collider, hit.position, hit.normal, size, POOL)
		if mi == null:
			return
		var full := mi.scale
		mi.scale = full * 0.15
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", full, POOL_GROW).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT))


## Uma gota de quem está sangrando, no chão embaixo de `at`.
static func drip(world_node: Node3D, at: Vector3, size: float) -> Node3D:
	var from := at + Vector3.UP * 0.5
	var hit := world_node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.5, 1))
	if hit.is_empty() or (hit.normal as Vector3).y < 0.7:
		return null
	return splat(hit.collider, hit.position, hit.normal, size, DROPS)


static func count() -> int:
	# sem tipo no parâmetro: o corpo que levava o respingo pode ter sido apagado (objeto inválido)
	_splats = _splats.filter(func(s: Variant) -> bool: return is_instance_valid(s) and not (s as Node).is_queued_for_deletion())
	return _splats.size()


## Apaga todo o sangue (reinício), inclusive poças que ainda iam aparecer.
static func clear() -> void:
	_generation += 1
	for s in _splats:
		if is_instance_valid(s):
			s.queue_free()
	_splats.clear()


## Rastro de quem está ferido (`wound` 0..1 = quanto da vida perdeu): uma gota a cada tantos metros andados, ou de
## tempos em tempos parado; quanto pior o ferimento, mais perto uma da outra e maiores. Sem ferimento, nada.
class Trail:
	extends RefCounted
	const STEP := Vector2(1.8, 0.45)  # metros entre gotas (ferimento leve, grave)
	const IDLE := Vector2(3.0, 0.9)  # segundos entre gotas parado
	var _last := Vector3.INF
	var _dist := 0.0
	var _idle := 0.0

	## Chamar a cada passo de física. Devolve o decalque da gota quando pinga uma, senão null.
	func update(who: Node3D, delta: float, wound: float) -> Node3D:
		var p := who.global_position
		if wound <= 0.0 or _last == Vector3.INF:
			_last = p
			_dist = 0.0
			_idle = 0.0
			return null
		var moved := Vector2(p.x - _last.x, p.z - _last.z).length()
		_last = p
		_dist += moved
		_idle += delta
		var w := clampf(wound, 0.0, 1.0)
		if _dist < lerpf(STEP.x, STEP.y, w) and _idle < lerpf(IDLE.x, IDLE.y, w):
			return null
		_dist = 0.0
		_idle = 0.0
		var off := Vector3(randf_range(-0.15, 0.15), 0.0, randf_range(-0.15, 0.15))
		return Blood.drip(who, p + off, randf_range(0.14, 0.22) * lerpf(0.8, 1.4, w))
