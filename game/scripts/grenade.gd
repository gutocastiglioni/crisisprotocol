class_name Grenade
extends Node3D
## Granada de 40 mm da M79: sai do cano em arco (velocidade SPEED, gravidade) já apontada para cair no ponto da retícula
## (`aim_velocity`, o arco baixo), deixando um rastro de fumaça. Bate em algo (cenário, personagem, corpo caído):
## a menos de ARM_DIST do cano ela ainda não armou (como a de verdade) e só dá a pancada (`impact_damage`); armada,
## explode (`explode`): bola de fogo, fumaça, luz, mancha de queimado no cenário, barulho que os inimigos de longe ouvem,
## dano em área que cai com a distância (só em quem está à vista da explosão: parede e porta fechada protegem),
## empurra os corpos caídos e arremessa a jogadora se pegar perto (ela também se machuca com a própria granada).

const SPEED := 32.0  # m/s (a de verdade sai a 76: aqui mais lenta para o arco aparecer)
const GRAVITY := 9.8
const ARM_DIST := 3.0  # m do cano até armar
const RADIUS := 5.0  # alcance do dano (m)
const DAMAGE := 260  # no centro; cai até MIN_FRACTION na borda
const MIN_FRACTION := 0.2
const PLAYER_SHARE := 0.4  # a jogadora leva esta parte (senão a própria granada a matava de qualquer jeito)
const LAUNCH_DIST := 3.0  # mais perto que isso da explosão, a jogadora é arremessada (ragdoll)
const BODY_PUSH := 22.0  # empurrão nos corpos caídos (no centro)
const SHAKE_DIST := 18.0  # a câmera dela treme se a explosão for até esta distância
const NOISE := 45.0  # m: quem ouve a explosão
const LIFE := 6.0
const MASK := 1 | 2 | Ragdoll.LAYER

var vel := Vector3.ZERO
var shooter: Node3D
var impact_damage := 60
var travel := 0.0  # metros percorridos desde o cano
var _exclude: Array[RID] = []
var _t := 0.0
var _trail_t := 0.0


## Lança uma granada de `from` para cair em `target` (quem atirou não é atingido por ela no caminho).
static func launch(parent: Node, from: Vector3, target: Vector3, by: Node3D = null, impact := 60) -> Grenade:
	var g := Grenade.new()
	g.shooter = by
	g.impact_damage = impact
	g.vel = aim_velocity(from, target, SPEED, GRAVITY)
	if by is CollisionObject3D:
		g._exclude.append((by as CollisionObject3D).get_rid())
	var m: Variant = by.get("model") if by else null
	if m != null and m.get("ragdoll") != null:
		g._exclude.append_array(m.ragdoll.body_rids())
	parent.add_child(g)
	g.global_position = from
	return g


## Velocidade inicial (módulo `speed`) do arco baixo que sai de `from` e passa por `to`; longe demais, sai a 45°.
static func aim_velocity(from: Vector3, to: Vector3, speed: float, g: float) -> Vector3:
	var d := to - from
	var h := Vector2(d.x, d.z).length()
	if h < 0.01:
		return d.normalized() * speed if d.length() > 0.01 else Vector3.FORWARD * speed
	var v2 := speed * speed
	var disc := v2 * v2 - g * (g * h * h + 2.0 * d.y * v2)
	var theta := PI * 0.25 if disc < 0.0 else atan((v2 - sqrt(disc)) / (g * h))
	var flat := Vector3(d.x, 0.0, d.z) / h
	return flat * cos(theta) * speed + Vector3.UP * sin(theta) * speed


func _ready() -> void:
	add_to_group("grenades")
	# corpo verde-oliva com a ogiva dourada (~4 cm x 10 cm, um pouco maior para aparecer no voo)
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.026
	c.bottom_radius = 0.026
	c.height = 0.09
	c.radial_segments = 8
	c.rings = 1
	body.mesh = c
	body.material_override = _mat(Color(0.3, 0.34, 0.2))
	body.rotation.x = -PI * 0.5  # o cilindro nasce em pé: deitado ao longo de -Z (a frente)
	add_child(body)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.004
	cone.bottom_radius = 0.026
	cone.height = 0.04
	cone.radial_segments = 8
	cone.rings = 1
	tip.mesh = cone
	tip.material_override = _mat(Color(0.75, 0.6, 0.2))
	tip.rotation.x = -PI * 0.5
	tip.position.z = -0.065
	add_child(tip)
	_face_velocity()


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m


func _face_velocity() -> void:
	if vel.length() > 0.1:
		look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()
		return
	var from := global_position
	var next := from + vel * delta + Vector3.DOWN * (0.5 * GRAVITY * delta * delta)
	vel += Vector3.DOWN * GRAVITY * delta
	var q := PhysicsRayQueryParameters3D.create(from, next, MASK, _exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		travel += from.distance_to(hit.position)
		global_position = hit.position
		_impact(hit)
		return
	travel += from.distance_to(next)
	global_position = next
	_face_velocity()
	_trail_t -= delta
	if _trail_t <= 0.0 and travel > 0.6:
		_trail_t = 0.03
		Fx.smoke(get_parent(), global_position, -vel.normalized() * 0.2 + Vector3.UP * 0.15, 0.07, 0.5, 2.5)


func _impact(hit: Dictionary) -> void:
	var parent := get_parent()
	var col: Object = hit.collider
	var normal: Vector3 = hit.normal
	queue_free()
	if travel < ARM_DIST:
		# não armou: só a pancada (e o barulho de metal batendo)
		var who: Object = Ragdoll.owner_of(col) if col is PhysicalBone3D else col
		if who and who.has_method("take_hit") and not who.get("dead"):
			who.take_hit(impact_damage, vel.normalized(), hit.position)
		else:
			Fx.impact(parent, hit.position, false, normal, "metal")
		return
	explode(parent, hit.position + normal * 0.05, normal, col)


## Explosão em `at` (`normal` = da superfície atingida; `surface` = o corpo dela, para a mancha de queimado).
static func explode(parent: Node, at: Vector3, normal := Vector3.UP, surface: Object = null) -> void:
	var world := parent as Node3D
	Fx.explosion(parent, at, normal)
	if surface:
		Fx.scorch(surface, at, normal)
	Sfx.play(world, "explosion", at)
	parent.get_tree().call_group("enemies", "hear_noise", at, NOISE, 3.0)
	var space := world.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	q.shape = sphere
	q.transform = Transform3D(Basis(), at)
	q.collision_mask = 2 | Ragdoll.LAYER
	var seen := {}
	for h in space.intersect_shape(q, 128):
		var col: Object = h.collider
		if col is PhysicalBone3D:
			var who := Ragdoll.owner_of(col)
			if who == null or not who.has_method("take_hit") or who.get("dead"):
				# corpo caído (ou ragdoll de quem já morreu): só é empurrado
				var pb := col as PhysicalBone3D
				if _in_sight(space, at, pb.global_position):
					var away := pb.global_position - at
					var k := clampf(1.0 - away.length() / RADIUS, 0.0, 1.0)
					Ragdoll.push(pb, (away.normalized() + Vector3.UP * 0.6) * BODY_PUSH * k, pb.global_position)
				continue
			col = who
		if col == null or not col.has_method("take_hit") or seen.has(col) or col.get("dead"):
			continue
		seen[col] = true
		var center := (col as Node3D).global_position + Vector3.UP * 0.9
		if not _in_sight(space, at, center):
			continue
		var d := maxf(0.0, at.distance_to(center) - 0.3)
		var frac := clampf(1.0 - d / RADIUS, MIN_FRACTION, 1.0)
		var dir := (center - at).normalized()
		if col is Player:
			var p := col as Player
			p.take_hit(maxi(1, roundi(DAMAGE * frac * PLAYER_SHARE)), dir, center)
			if not p.dead:
				if d < LAUNCH_DIST:
					p.launch(Vector3(dir.x, 0.0, dir.z).normalized() * 6.0 + Vector3.UP * 4.0, center)
				else:
					p.knockback(Vector3(dir.x, 0.0, dir.z).normalized() * 4.0)
		else:
			col.take_hit(maxi(1, roundi(DAMAGE * frac)), dir, center)
	var player := parent.get_tree().get_first_node_in_group("player") as Player
	if player:
		var pd := player.global_position.distance_to(at)
		if pd < SHAKE_DIST:
			player.camera_rig.shake(0.3 * (1.0 - pd / SHAKE_DIST), 0.6)


## Nada de cenário (parede, porta, caixa) entre a explosão e o ponto.
static func _in_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()
