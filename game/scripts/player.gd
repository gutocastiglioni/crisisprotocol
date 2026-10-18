class_name Player
extends CharacterBody3D
## Heroína controlável: andar/correr relativo à câmera, andar agachada, mirar andando (em pé ou agachada),
## cambalhota com projeção, pular, agarrar bordas (fica pendurada, sobe) e escalar obstáculos baixos (PlayerMoves),
## pegar armas no baú e trocar de arma, atirar (raio a partir da câmera; cada arma com cadência, dispersão, chumbos,
## coice e efeitos próprios, deixando buraco de bala no cenário), levar dano, ser empurrada, ser mordida no braço por um raptor
## (vira ragdoll pendurada na boca dele e é sacudida, lutando: soca a cara dele e chuta; apertar botões
## luta mais rápido e solta antes) e virar ragdoll ao morrer. Tiro que passa pela cabeça (parte "Head" do ragdoll de quem
## levou) é headshot: dano multiplicado por `head_mult` do alvo e `take_headshot` no lugar de `take_hit` (alvo com
## `head_mult` 1 ou sem ele, como o raptor cabeçudo, não tem headshot). Ferida, sangra
## (esguicho a cada golpe, rastro de gotas, poça ao morrer: ver Blood).
## Furtividade: `visibility()` (0..1) diz o quanto ela aparece para os raptors (agachada, devagar, parada ou no capim
## alto = menos) e os passos, a cambalhota e os tiros fazem barulho que eles ouvem (`make_noise`).

signal health_changed(value: int)
signal died
signal headshot(who: Node)

# andando, agachada e mirando, a velocidade é a dos ciclos de passo (Moves.speed): o pé não escorrega
const RUN_SPEED := 4.4
const JUMP_SPEED := 4.6  # pulo normal (~0,6 m)
const AIR_CONTROL := 2.0
const COYOTE := 0.12  # sem chão por menos que isso ainda conta como no chão (degraus, quinas)
const TURN_RATE := 12.0
const GRAVITY := 18.0
const SHOT_COOLDOWN := 0.28  # pistola
const SHOT_RANGE := 60.0
const DAMAGE := 34  # pistola
## cada arma: cadência (s), dano por projétil, projéteis por tiro, dispersão (graus: base, + por tiro seguido, máx;
## volta a `spread` a 4°/s), alcance (m; o dano cai até 30% do meio dele até o fim), tremida da câmera,
## empurrão no ragdoll por projétil, tamanho do buraco de bala, cápsula ejetada e nome no HUD
const WEAPON_STATS := {
	"pistol": {"cooldown": SHOT_COOLDOWN, "damage": DAMAGE, "pellets": 1, "spread": 0.0, "bloom": 0.0, "max_spread": 0.0,
		"range": SHOT_RANGE, "shake": 0.02, "push": 25.0, "hole": 0.09, "casing": "brass", "name": "PISTOLA"},
	"m16": {"cooldown": 0.1, "damage": 22, "pellets": 1, "spread": 0.0, "bloom": 1.0, "max_spread": 3.0,
		"range": SHOT_RANGE, "shake": 0.035, "push": 20.0, "hole": 0.08, "casing": "brass", "name": "M16"},
	"shotgun": {"cooldown": 0.8, "damage": 14, "pellets": 8, "spread": 4.5, "bloom": 0.0, "max_spread": 4.5,
		"range": 24.0, "shake": 0.14, "push": 9.0, "hole": 0.06, "casing": "shell", "name": "ESCOPETA"},
}
const BLOOM_DECAY := 4.0  # graus por segundo
const PICK_RANGE := 0.9  # distância até o lugar de ajoelhar para poder pegar
const HIP_AIM_TIME := 0.6
const SHOT_MASK := 1 | 2 | Ragdoll.LAYER
const KNOCK_DECAY := 12.0
const BITTEN_BONE := "LowerArm_L"  # a direita segura a pistola
const DOWN_TIME := 1.1  # no chão depois de solta, antes de levantar
const C_TIME := 0.35  # quanto tempo do voo ela segura o corpo dobrado em C

var model: HeroineModel
var camera_rig: CameraRig
var health := 100
var crouching := false
var aiming := false
var dead := false
var rolling := false
var shots_fired := 0
var weapons: Array[String] = ["pistol"]
var moves: PlayerMoves
var _shape: CollisionShape3D
var _air_t := 0.0
var _jumping := false
var _shot_cd := 0.0
var _hip_aim_t := 0.0
var _bloom := 0.0  # dispersão extra de tiros seguidos (graus)
var _spawn: Transform3D
## mordida no braço por um raptor: ragdoll com o antebraço preso à boca dele
var grabbed := false
var grabber: Node3D
var struggle := 0
var _down_t := 0.0
var _fight := 0.0  # fase da luta (socos e chutes) enquanto está presa
var _held_t := 0.0
var _rising := false
var _fly_t := 0.0
var _fly_dir := Vector3.FORWARD
var _knock := Vector3.ZERO
var _stun := 0.0
var _daze := 0.0  # > 0: atordoada pelo rugido do alossauro (sem controle, mãos nos ouvidos)
var stealth: PlayerStealth
var _trail := Blood.Trail.new()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	_shape.shape = cap
	_shape.position.y = 0.85
	add_child(_shape)
	model = HeroineModel.new()
	add_child(model)
	camera_rig = CameraRig.new()
	camera_rig.target = self
	camera_rig.yaw = rotation.y
	add_child(camera_rig)
	camera_rig.spring.add_excluded_object(get_rid())
	moves = PlayerMoves.new(self)
	stealth = PlayerStealth.new(self)
	model.shell_ejected.connect(func(at: Vector3, vel: Vector3) -> void: Fx.casing(get_parent(), at, vel, "shell"))
	_spawn = global_transform


func _physics_process(delta: float) -> void:
	stealth.update(delta)
	if not dead and not grabbed:
		_trail.update(self, delta, 1.0 - health / 100.0)
	if grabbed:
		_held(delta)
		return
	if dead:
		# cápsula desligada: o corpo fica parado e quem cai é o ragdoll
		velocity = Vector3.ZERO
		return
	if _down_t > 0.0:
		velocity = Vector3.ZERO
		if _fly_t > 0.0:
			_fly_t -= delta
			_hold_c()
		_down_t -= delta
		if _down_t <= 0.0:
			_get_up()
		return
	if _daze > 0.0:
		_dazed(delta)
		return
	_shot_cd -= delta
	_hip_aim_t -= delta
	_bloom = maxf(0.0, _bloom - BLOOM_DECAY * delta)
	if moves.busy():
		aiming = false
		model.set_aim(false)
		moves.update(delta)
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if _stun > 0.0:
		# empurrada por um golpe: desliza sem controle até o empurrão acabar
		_stun -= delta
		aiming = false
		model.set_aim(false)
		model.set_state("crouch" if _rising else "idle")
		_rising = _rising and _stun > 0.0
		velocity.x = _knock.x
		velocity.z = _knock.z
		_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
		move_and_slide()
		return
	var wish := move_wish()
	_air_t = 0.0 if is_on_floor() else _air_t + delta
	var grounded := _air_t < COYOTE and not _jumping
	aiming = (Input.is_action_pressed("aim") or _hip_aim_t > 0.0) and grounded

	if grounded:
		if Input.is_action_just_pressed("crouch"):
			crouching = not crouching
		if Input.is_action_just_pressed("roll"):
			make_noise(7.0, 0.7)
			moves.start_roll(wish.normalized() if wish.length() > 0.1 else -global_basis.z)
			return
		if Input.is_action_just_pressed("jump") and _jump(wish):
			return
		if Input.is_action_just_pressed("interact") and pick_target():
			moves.start_pickup(pick_target())
			return
	if Input.is_action_just_pressed("switch_weapon"):
		switch_weapon()

	var hv := Vector3.ZERO
	if not grounded:
		# no ar: mantém o embalo, pouco controle
		hv = Vector3(velocity.x, 0.0, velocity.z).lerp(wish * Moves.speed("walk"), AIR_CONTROL * delta * wish.length())
		model.set_state("jump" if _jumping and velocity.y > -1.0 else "fall")
	elif aiming:
		_aim_at(delta)
		hv = _aim_locomotion(wish)
	elif crouching:
		var speed := Moves.speed("crouch_walk") * minf(1.0, wish.length() / 0.6)
		hv = wish.normalized() * speed
		if wish.length() > 0.1:
			_face(wish, delta)
			model.set_state("crouch_walk", speed / Moves.speed("crouch_walk"))
		else:
			model.set_state("crouch")
	else:
		var walk_btn := Input.is_action_pressed("walk")
		if wish.length() < 0.1:
			model.set_state("idle")
		elif walk_btn or wish.length() < 0.6:
			# andar devagar: com o analógico pela metade, mais devagar ainda (e a animação junto)
			var speed := Moves.speed("walk") * (1.0 if walk_btn else clampf(wish.length() / 0.6, 0.3, 1.0))
			hv = wish.normalized() * speed
			_face(wish, delta)
			model.set_state("walk", speed / Moves.speed("walk"))
		else:
			hv = wish * RUN_SPEED
			_face(wish, delta)
			model.set_state("run", hv.length() / RUN_SPEED)
	if is_on_floor() and _air_t == 0.0 and velocity.y <= 0.0:
		_jumping = false

	if Input.is_action_pressed("shoot") and grounded:
		fire()
	if Input.is_action_just_pressed("debug_hit"):
		take_hit(10, global_basis.z, global_position + Vector3.UP * 1.2)
	if Input.is_action_just_pressed("debug_kill"):
		take_hit(999, global_basis.z, global_position + Vector3.UP * 1.2)

	model.set_aim(aiming)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()


## O quanto ela aparece para os inimigos (0..1): multiplica o alcance da visão deles (ver PlayerStealth).
func visibility() -> float:
	return stealth.visibility


## Barulho no lugar dela que os inimigos a `radius` metros ouvem (a atenção deles sobe até `power`, mais quanto mais perto).
func make_noise(radius: float, power: float) -> void:
	get_tree().call_group("enemies", "hear_noise", global_position, radius, power)


## Direção pedida no plano, relativa à câmera (comprimento = quanto o direcional foi empurrado).
func move_wish() -> Vector3:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return camera_rig.yaw_basis() * Vector3(input.x, 0.0, input.y)


## Pulo: com borda à frente, escala/agarra (PlayerMoves); senão, pulo normal mantendo o embalo.
func _jump(wish: Vector3) -> bool:
	crouching = false
	if moves.try_ledge(wish if wish.length() > 0.1 else -global_basis.z):
		return true
	_jumping = true
	velocity.y = JUMP_SPEED
	model.play("jump")
	return false


## Mirando: passo lateral, para a frente ou de costas (em pé ou agachada), na velocidade dos ciclos de passo.
func _aim_locomotion(wish: Vector3) -> Vector3:
	var prefix := "crouch_" if crouching else ""
	if wish.length() < 0.1:
		model.set_state("crouch" if crouching else "idle")
		return Vector3.ZERO
	var speed := Moves.speed(prefix + "strafe") * minf(1.0, wish.length())
	var local := global_basis.inverse() * wish
	if absf(local.x) > absf(local.z):
		model.set_state(prefix + ("strafe_r" if local.x > 0.0 else "strafe_l"), speed / Moves.speed(prefix + "strafe"))
	else:
		var gait := "crouch_walk" if crouching else "walk"
		model.set_state(gait, (1.0 if local.z < 0.0 else -1.0) * speed / Moves.speed(gait))
	return wish.normalized() * speed


## Mirando: vira para o ponto sob a retícula e inclina o tronco até a altura dele (o cano aponta para onde o tiro
## vai). `delta` grande = vira de uma vez (tiro sem mirar antes).
func _aim_at(delta: float) -> void:
	var target := camera_rig.aim_point([get_rid()])
	var shoulder := global_position + Vector3.UP * (0.95 if crouching else 1.38)
	var d := target - shoulder
	_face(Vector3(d.x, 0.0, d.z), delta)
	model.set_aim_pitch(clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2))


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_RATE * delta))


## Arma na mão ("pistol", "m16" ou "shotgun").
func weapon() -> String:
	return model.weapon


## Recebe uma arma (do baú): entra no inventário e já vai para a mão.
func give_weapon(w: String) -> void:
	if w == "":
		return
	if not w in weapons:
		weapons.append(w)
	model.set_weapon(w)
	model.holster(false)


## Próxima arma do inventário (Select / Q).
func switch_weapon() -> void:
	if weapons.size() < 2 or moves.busy():
		return
	model.set_weapon(weapons[(weapons.find(weapon()) + 1) % weapons.size()])
	_shot_cd = 0.15


## Baú com arma ao alcance (para o aviso de interação e para pegar), ou null.
func pick_target() -> Node:
	if dead or grabbed or moves.busy():
		return null
	for c in get_tree().get_nodes_in_group("chests"):
		if c.has_item() and c.kneel_transform().origin.distance_to(global_position) < PICK_RANGE:
			return c
	return null


func fire() -> void:
	if _shot_cd > 0.0 or dead or grabbed or moves.busy():
		return
	var kind := weapon()
	var stats: Dictionary = WEAPON_STATS[kind]
	_shot_cd = stats.cooldown
	shots_fired += 1
	stealth.shot()
	make_noise(26.0, 2.2)  # tiro: ouvido de longe, e o clarão a deixa visível
	if not aiming:
		_hip_aim_t = HIP_AIM_TIME
		aiming = true
		_aim_at(1.0)
	model.set_aim(true)
	model.shoot()
	camera_rig.shake(stats.shake, 0.12 if kind == "shotgun" else 0.06)
	var ray := camera_rig.aim_ray()
	var muzzle := model.muzzle_position()
	var parent := get_parent()
	Fx.muzzle_flash(parent, muzzle, kind, ray[1])
	if stats.casing == "brass":
		# janela de ejeção do lado direito, atrás do cano (a escopeta ejeta ao bombear: HeroineModel.shell_ejected)
		var right := global_basis.x
		var port: Vector3 = muzzle - ray[1] * (0.58 if kind == "m16" else 0.12) + right * 0.03
		Fx.casing(parent, port, right * randf_range(1.4, 2.0) + Vector3.UP * randf_range(1.0, 1.6) - ray[1] * 0.3)
	var exclude: Array[RID] = [get_rid()]
	exclude.append_array(model.ragdoll.body_rids())
	var space := get_world_3d().direct_space_state
	var cone := float(stats.spread) + _bloom
	_bloom = minf(_bloom + float(stats.bloom), float(stats.max_spread))
	# dano somado por alvo (os chumbos da escopeta acertam juntos: uma reação só)
	var hits := {}
	for i in int(stats.pellets):
		var dir := _spread_dir(ray[1], cone)
		var q := PhysicsRayQueryParameters3D.create(ray[0], ray[0] + dir * float(stats.range), SHOT_MASK, exclude)
		var hit := space.intersect_ray(q)
		var end: Vector3 = hit.position if hit else ray[0] + dir * float(stats.range)
		# a escopeta mostra só alguns traçantes (8 riscos ao mesmo tempo viram um borrão)
		if i < 3:
			Fx.tracer(parent, muzzle, end, kind)
		if hit.is_empty():
			continue
		_pellet_hit(hit, dir, stats, hits)
	for who: Node in hits:
		if is_instance_valid(who) and not who.get("dead"):
			var h: Dictionary = hits[who]
			if h.head and who.has_method("take_headshot"):
				who.take_headshot(h.damage, h.dir, h.at)
				headshot.emit(who)
			else:
				who.take_hit(h.damage, h.dir, h.at)


## Direção aleatória num cone de `degrees` em volta de `dir` (distribuição uniforme no disco).
func _spread_dir(dir: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP).normalized() if absf(dir.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(dir).normalized()
	var r := tan(deg_to_rad(degrees)) * sqrt(randf())
	var a := randf() * TAU
	return (dir + side * cos(a) * r + up * sin(a) * r).normalized()


## Um projétil acertou: soma o dano no alvo (`hits`; na cabeça, vezes o `head_mult` dele), empurra corpo caído ou
## marca o cenário. Carne atingida esguicha sangue na direção do tiro.
func _pellet_hit(hit: Dictionary, dir: Vector3, stats: Dictionary, hits: Dictionary) -> void:
	var col: Object = hit.collider
	var parent := get_parent()
	var dist := (hit.position as Vector3).distance_to(global_position)
	var half := float(stats.range) * 0.5
	var falloff := clampf(1.0 - (dist - half) / half, 0.3, 1.0)
	var wound := float(stats.damage) / DAMAGE * falloff  # tamanho do esguicho (1 = pistola de perto)
	var who: Node = null
	var head := false
	if col is PhysicalBone3D:
		who = Ragdoll.owner_of(col)
		head = (col as PhysicalBone3D).bone_name == "Head" and _has_headshot(who)
		if not (who and who.has_method("take_hit") and not who.get("dead")):
			# corpo já caído: o tiro empurra a parte atingida
			Ragdoll.push(col, dir * float(stats.push), hit.position)
			who = null
		Blood.splash(parent, hit.position, dir, hit.normal, wound, head)
	elif col.has_method("take_hit"):
		who = col
		head = _has_headshot(col) and body_part(col, hit.position, dir) == "Head"
		Blood.splash(parent, hit.position, dir, hit.normal, wound, head)
	else:
		Fx.impact(parent, hit.position, false, hit.normal, (col as Node).get_meta("surface", "concrete"))
		Fx.decal(col, hit.position, hit.normal, float(stats.hole) * randf_range(0.85, 1.15), int(stats.pellets) > 1)
	if who:
		var h: Dictionary = hits.get(who, {"damage": 0, "dir": dir, "at": hit.position, "head": false})
		var mult: float = float(who.get("head_mult")) if head else 1.0
		h.damage += maxi(1, roundi(float(stats.damage) * falloff * mult))
		if head and not h.head:
			h.head = true
			h.at = hit.position  # o golpe do ragdoll vai na cabeça
		hits[who] = h


## Quem tem tiro na cabeça: `head_mult` acima de 1 (o raptor, cabeçudo, não tem).
static func _has_headshot(who: Object) -> bool:
	if who == null:
		return false
	var mult: Variant = who.get("head_mult")
	return mult != null and float(mult) > 1.0


## Parte do corpo de `who` por onde passa o tiro que bateu na cápsula dele em `at` (nome do osso, "" = nenhuma): a
## cápsula cobre o corpo todo, então o raio segue mais um pouco só contra as partes do ragdoll (que acompanham a
## animação enquanto ele está vivo).
func body_part(who: Object, at: Vector3, dir: Vector3) -> String:
	var q := PhysicsRayQueryParameters3D.create(at - dir * 0.05, at + dir * 0.8, Ragdoll.LAYER, model.ragdoll.body_rids())
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h and h.collider is PhysicalBone3D and Ragdoll.owner_of(h.collider) == who:
		return (h.collider as PhysicalBone3D).bone_name
	return ""


## Ponto que a câmera segue: os pés da cápsula viva, ou o quadril do ragdoll (caída ou na boca do raptor).
func camera_focus() -> Vector3:
	if model.is_ragdoll():
		return model.ragdoll.bodies["Hips"].global_position - Vector3.UP * 0.9
	# posição desenhada (entre dois passos da física), para a câmera seguir sem tranco
	return get_global_transform_interpolated().origin


func take_hit(amount: int, dir: Vector3, at: Vector3) -> void:
	if dead:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	Blood.splash(get_parent(), at, dir, -dir, amount / 20.0)
	if health == 0:
		die(dir * 9.0 + Vector3.UP * 2.0, at)
	else:
		model.hit()


## Rugido do alossauro: atordoada por `time` segundos (não fere). Golpe, mordida ou arremesso acabam com isso.
func daze(time: float) -> void:
	if dead or grabbed or _down_t > 0.0:
		return
	moves.cancel()
	crouching = false
	aiming = false
	_daze = maxf(_daze, time)
	camera_rig.shake(0.1, 0.6)


func is_dazed() -> bool:
	return _daze > 0.0


func _dazed(delta: float) -> void:
	_daze -= delta
	aiming = false
	model.set_aim(false)
	model.set_state("dazed")
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


## Golpe que empurra (investida, salto, rabada): perde o controle por um instante.
func knockback(push: Vector3) -> void:
	if dead or grabbed:
		return
	_daze = 0.0
	moves.cancel()
	crouching = false
	_knock = Vector3(push.x, 0.0, push.z)
	_stun = 0.45
	velocity.y = maxf(velocity.y, push.y)
	camera_rig.shake(0.12, 0.35)


## Golpe forte (salto, investida): ela é arremessada como ragdoll dobrada em C em volta do ponto `at`
## (barriga, ou onde a garra pegou), cai e levanta depois.
func launch(vel: Vector3, at: Variant = null) -> void:
	if dead or grabbed:
		return
	moves.cancel()
	crouching = false
	aiming = false
	_stun = 0.0
	_daze = 0.0
	_shape.set_deferred("disabled", true)
	_down_t = DOWN_TIME + 0.5
	camera_rig.shake(0.15, 0.4)
	_fly_dir = Vector3(vel.x, 0.0, vel.z).normalized()
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.0
	await model.fling_ragdoll(vel, hit)
	_fly_t = C_TIME


## No começo do voo: cabeça, braços e pernas ficam para trás do quadril (do lado de quem bateu) = C.
## Os alvos andam junto com o quadril (base = velocidade dele), então o corpo segue voando.
func _hold_c() -> void:
	var b: Dictionary = model.ragdoll.bodies
	var hips: PhysicalBone3D = b["Hips"]
	var base := PhysicsServer3D.body_get_state(hips.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY) as Vector3
	var back := -_fly_dir
	var h := hips.global_position
	var goals := {
		"Head": h + back * 0.4 + Vector3.UP * 0.45, "Chest": h + back * 0.2 + Vector3.UP * 0.3,
		"LowerArm_L": h + back * 0.5 + Vector3.UP * 0.2, "LowerArm_R": h + back * 0.5 + Vector3.UP * 0.2,
		"LowerLeg_L": h + back * 0.4 - Vector3.UP * 0.4, "LowerLeg_R": h + back * 0.4 - Vector3.UP * 0.4,
	}
	for n in goals:
		Ragdoll.drag(b[n], goals[n], 8.0, 5.0, base)


## Na cambalhota (ou caída, levantando) ela não leva outro golpe.
func is_dodging() -> bool:
	return rolling or _down_t > 0.0 or _rising


func grab(by: Node3D) -> void:
	if dead:
		return
	grabbed = true
	grabber = by
	_daze = 0.0
	struggle = 0
	_fight = 0.0
	_held_t = 0.0
	moves.cancel()
	crouching = false
	aiming = false
	_stun = 0.0
	_shape.set_deferred("disabled", true)
	model.start_ragdoll(Vector3.ZERO)


## Solta da boca: o corpo é arremessado com `throw` e, viva, ela levanta depois de DOWN_TIME.
func release(throw: Vector3) -> void:
	if not grabbed:
		return
	grabbed = false
	grabber = null
	var chest: PhysicalBone3D = model.ragdoll.bodies["Chest"]
	Ragdoll.push(chest, throw * 6.0, chest.global_position)
	if not dead:
		_down_t = DOWN_TIME


## Pendurada pelo braço: a física puxa o antebraço para a boca e a cabeça dele sacode o corpo todo.
## Viva, ela luta por cima disso (mesmo sem botão): puxa o corpo para longe, soca o olho dele com a mão
## livre e chuta alternando as pernas. Morta, fica só o braço preso.
## A cápsula não se move aqui (mover o pai arrastaria os corpos do ragdoll); ela é ressincronizada ao levantar.
func _held(delta: float) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(grabber):
		release(Vector3.ZERO)
		return
	var b: Dictionary = model.ragdoll.bodies
	var mouth: Vector3 = grabber.model.mouth_position()
	var body_bone: Variant = grabber.get("grab_bone")
	if body_bone is String:
		_held_body(delta, b, mouth, body_bone)
		return
	Ragdoll.drag(b[BITTEN_BONE], mouth, 25.0, 18.0)
	camera_rig.shake(0.08, 0.1)
	_held_t += delta
	if dead:
		return
	for a in ["shoot", "roll", "aim", "crouch"]:
		if Input.is_action_just_pressed(a):
			struggle += 1
	_fight += delta * TAU / maxf(0.26, 0.5 - struggle * 0.02)
	# "para longe" = à frente do focinho dele
	var fwd: Vector3 = -grabber.global_basis.z
	var away := fwd
	var hips: Vector3 = b["Hips"].global_position
	# a cabeça dele joga o corpo dela de um lado para o outro (um ciclo da animação Shake = 0,4 s)
	var whip: Vector3 = grabber.global_basis.x * sin(_held_t * TAU / 0.4) * 0.4
	var chest := mouth + away * 0.45 - Vector3.UP * 0.15 + whip * 0.6
	# puxa o corpo para trás, como quem tenta arrancar o braço da boca
	Ragdoll.drag(b["Hips"], mouth + away * 0.75 - Vector3.UP * 0.55 + whip, 6.0, 8.0)
	Ragdoll.drag(b["Chest"], chest, 6.0, 8.0)
	Ragdoll.drag(b["Head"], chest + Vector3.UP * 0.35 + away * 0.05, 4.0, 3.0)
	# socos com a mão livre (a da pistola) no olho dele
	var eye := mouth - fwd * 0.3 + Vector3.UP * 0.12
	Ragdoll.drag(b["LowerArm_R"], chest.lerp(eye, 0.5 + 0.5 * sin(_fight)), 9.0, 7.0)
	# chutes alternados no peito dele, dobrando só o joelho para o lado certo: coxa à frente e a canela
	# vai de pendurada (joelho dobrado) a esticada; com pouca força para os limites das juntas mandarem
	var toward := -fwd
	var right := toward.cross(Vector3.UP)
	for leg in [["L", 0.0, -1.0], ["R", PI, 1.0]]:
		var k := 0.5 + 0.5 * sin(_fight * 0.8 + leg[1])
		var lateral: Vector3 = right * leg[2] * 0.1
		Ragdoll.drag(b["UpperLeg_" + leg[0]], hips + toward * (0.18 + 0.05 * k) - Vector3.UP * 0.08 + lateral, 4.0, 3.0)
		var tucked := hips + toward * 0.38 - Vector3.UP * 0.30
		var kick := hips + toward * 0.66 - Vector3.UP * 0.12
		Ragdoll.drag(b["LowerLeg_" + leg[0]], tucked.lerp(kick, k) + lateral, 5.0, 4.0)


## Agarrada pelo corpo (alossauro): atravessada na boca dele, presa pela cintura (`bone`); quadril e pernas pendem de um
## lado, peito e cabeça do outro. Viva, soca o focinho dele com as duas mãos e chuta (mesmos botões de se debater).
func _held_body(delta: float, b: Dictionary, mouth: Vector3, bone: String) -> void:
	Ragdoll.drag(b[bone], mouth, 25.0, 18.0)
	camera_rig.shake(0.1, 0.1)
	_held_t += delta
	if dead:
		return
	for a in ["shoot", "roll", "aim", "crouch"]:
		if Input.is_action_just_pressed(a):
			struggle += 1
	_fight += delta * TAU / maxf(0.26, 0.5 - struggle * 0.02)
	var side: Vector3 = grabber.global_basis.x
	var fwd: Vector3 = -grabber.global_basis.z
	var hips := mouth + side * 0.45 - Vector3.UP * 0.35
	var chest := mouth - side * 0.4 + Vector3.UP * 0.05
	Ragdoll.drag(b["Hips"], hips, 6.0, 8.0)
	Ragdoll.drag(b["Chest"], chest, 6.0, 8.0)
	Ragdoll.drag(b["Head"], chest - side * 0.3 + Vector3.UP * 0.2, 4.0, 3.0)
	var snout := mouth - fwd * 0.5 + Vector3.UP * 0.35  # focinho dele, por cima da boca
	for arm in [["LowerArm_R", 0.0], ["LowerArm_L", PI]]:
		Ragdoll.drag(b[arm[0]], chest.lerp(snout, 0.5 + 0.5 * sin(_fight + arm[1])), 9.0, 7.0)
	for leg in [["L", 0.0], ["R", PI]]:
		var k := 0.5 + 0.5 * sin(_fight * 0.8 + leg[1])
		Ragdoll.drag(b["LowerLeg_" + leg[0]], hips + side * (0.25 + 0.2 * k) - Vector3.UP * (0.45 - 0.3 * k), 5.0, 4.0)


func _get_up() -> void:
	var hips: Vector3 = model.ragdoll.bodies["Hips"].global_position
	model.stop_ragdoll()
	global_position = Vector3(hips.x, global_position.y, hips.z)
	reset_physics_interpolation()
	_shape.set_deferred("disabled", false)
	# levanta agachada, sem controle por um instante
	_rising = true
	_stun = 0.5
	_knock = Vector3.ZERO


func die(impulse: Vector3, at: Variant = null) -> void:
	# mordida: o corpo continua preso na boca até o raptor largar
	dead = true
	_down_t = 0.0
	_daze = 0.0
	aiming = false
	moves.cancel()
	_shape.set_deferred("disabled", true)
	model.start_ragdoll(impulse, at)
	Blood.pool(model.ragdoll.bodies["Chest"], 1.0)
	died.emit()


func respawn() -> void:
	moves.cancel()
	model.stop_ragdoll()
	dead = false
	crouching = false
	_jumping = false
	weapons = ["pistol"]
	_bloom = 0.0
	model.set_weapon("pistol")
	grabbed = false
	grabber = null
	_stun = 0.0
	_daze = 0.0
	_down_t = 0.0
	_fly_t = 0.0
	_rising = false
	_knock = Vector3.ZERO
	stealth.loud_t = 0.0
	health = 100
	health_changed.emit(health)
	velocity = Vector3.ZERO
	global_transform = _spawn
	reset_physics_interpolation()
	camera_rig.yaw = rotation.y
	_shape.set_deferred("disabled", false)
