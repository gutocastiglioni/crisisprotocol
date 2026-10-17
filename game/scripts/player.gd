class_name Player
extends CharacterBody3D
## Heroína controlável: andar/correr relativo à câmera, mirar com passo lateral, rolar, agachar,
## atirar (raio a partir da câmera), levar dano, ser empurrada, ser mordida no braço por um raptor
## (vira ragdoll pendurada na boca dele e é sacudida, lutando: soca a cara dele e chuta; apertar botões
## luta mais rápido e solta antes) e virar ragdoll ao morrer.

signal health_changed(value: int)
signal died

const WALK_SPEED := 1.7
const RUN_SPEED := 4.4
const AIM_SPEED := 1.5
const ROLL_SPEED := 4.6
const ROLL_TIME := 0.85
const TURN_RATE := 12.0
const GRAVITY := 18.0
const SHOT_COOLDOWN := 0.28
const SHOT_RANGE := 60.0
const DAMAGE := 34
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
var _shape: CollisionShape3D
var _roll_t := 0.0
var _roll_dir := Vector3.FORWARD
var _shot_cd := 0.0
var _hip_aim_t := 0.0
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
	_spawn = global_transform


func _physics_process(delta: float) -> void:
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
	_shot_cd -= delta
	_hip_aim_t -= delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := camera_rig.yaw_basis() * Vector3(input.x, 0.0, input.y)
	aiming = (Input.is_action_pressed("aim") or _hip_aim_t > 0.0) and not rolling

	if Input.is_action_just_pressed("crouch") and not rolling:
		crouching = not crouching
	if Input.is_action_just_pressed("roll") and not rolling and is_on_floor():
		_start_roll(wish)

	var hv := Vector3.ZERO
	if rolling:
		_roll_t -= delta
		hv = _roll_dir * ROLL_SPEED * clampf(_roll_t / ROLL_TIME * 1.6, 0.25, 1.0)
		_face(_roll_dir, delta)
		if _roll_t <= 0.0:
			rolling = false
	elif crouching:
		model.set_state("crouch")
		if aiming:
			_face(-camera_rig.yaw_basis().z, delta)
	elif aiming:
		_face(-camera_rig.yaw_basis().z, delta)
		hv = wish * AIM_SPEED
		_aim_locomotion(wish)
	else:
		var walking := Input.is_action_pressed("walk") or wish.length() < 0.6
		hv = wish * (WALK_SPEED if walking else RUN_SPEED)
		if wish.length() > 0.1:
			_face(wish, delta)
			model.set_state("walk" if walking else "run")
		else:
			model.set_state("idle")

	if Input.is_action_pressed("shoot") and not rolling:
		fire()
	if Input.is_action_just_pressed("debug_hit"):
		take_hit(10, global_basis.z, global_position + Vector3.UP * 1.2)
	if Input.is_action_just_pressed("debug_kill"):
		take_hit(999, global_basis.z, global_position + Vector3.UP * 1.2)

	model.set_aim(aiming)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()


func _aim_locomotion(wish: Vector3) -> void:
	if wish.length() < 0.1:
		model.set_state("idle")
		return
	var local := global_basis.inverse() * wish
	if absf(local.x) > absf(local.z):
		model.set_state("strafe_r" if local.x > 0.0 else "strafe_l")
	else:
		model.set_state("walk", 1.0 if local.z < 0.0 else -1.0)


func _start_roll(wish: Vector3) -> void:
	rolling = true
	crouching = false
	_roll_t = ROLL_TIME
	_roll_dir = wish.normalized() if wish.length() > 0.1 else -global_basis.z
	model.state = ""
	model.set_state("roll")


func _face(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-TURN_RATE * delta))


func fire() -> void:
	if _shot_cd > 0.0 or dead or grabbed:
		return
	_shot_cd = SHOT_COOLDOWN
	shots_fired += 1
	if not aiming:
		_hip_aim_t = HIP_AIM_TIME
		aiming = true
		rotation.y = camera_rig.yaw
	model.set_aim(true)
	model.shoot()
	var ray := camera_rig.aim_ray()
	var exclude: Array[RID] = [get_rid()]
	exclude.append_array(model.ragdoll.body_rids())
	var q := PhysicsRayQueryParameters3D.create(ray[0], ray[0] + ray[1] * SHOT_RANGE, SHOT_MASK, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var muzzle := model.muzzle_position()
	Fx.muzzle_flash(get_parent(), muzzle)
	var end: Vector3 = hit.position if hit else ray[0] + ray[1] * SHOT_RANGE
	Fx.tracer(get_parent(), muzzle, end)
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col is PhysicalBone3D:
		var who := Ragdoll.owner_of(col)
		if who and who.has_method("take_hit") and not who.get("dead"):
			who.take_hit(DAMAGE, ray[1], hit.position)
		else:
			# corpo já caído: o tiro empurra a parte atingida
			Ragdoll.push(col, ray[1] * 25.0, hit.position)
		Fx.impact(get_parent(), hit.position, true)
	elif col.has_method("take_hit"):
		col.take_hit(DAMAGE, ray[1], hit.position)
		Fx.impact(get_parent(), hit.position, true)
	else:
		Fx.impact(get_parent(), hit.position, false)


## Ponto que a câmera segue: os pés da cápsula viva, ou o quadril do ragdoll (caída ou na boca do raptor).
func camera_focus() -> Vector3:
	if model.is_ragdoll():
		return model.ragdoll.bodies["Hips"].global_position - Vector3.UP * 0.9
	return global_position


func take_hit(amount: int, dir: Vector3, at: Vector3) -> void:
	if dead:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	if health == 0:
		die(dir * 9.0 + Vector3.UP * 2.0, at)
	else:
		model.hit()


## Golpe que empurra (investida, salto, rabada): perde o controle por um instante.
func knockback(push: Vector3) -> void:
	if dead or grabbed:
		return
	rolling = false
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
	rolling = false
	crouching = false
	aiming = false
	_stun = 0.0
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


## Rolando (ou caída, levantando) ela não leva outro golpe.
func is_dodging() -> bool:
	return rolling or _down_t > 0.0 or _rising


func grab(by: Node3D) -> void:
	if dead:
		return
	grabbed = true
	grabber = by
	struggle = 0
	_fight = 0.0
	_held_t = 0.0
	rolling = false
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


func _get_up() -> void:
	var hips: Vector3 = model.ragdoll.bodies["Hips"].global_position
	model.stop_ragdoll()
	global_position = Vector3(hips.x, global_position.y, hips.z)
	_shape.set_deferred("disabled", false)
	# levanta agachada, sem controle por um instante
	_rising = true
	_stun = 0.5
	_knock = Vector3.ZERO


func die(impulse: Vector3, at: Variant = null) -> void:
	# mordida: o corpo continua preso na boca até o raptor largar
	dead = true
	_down_t = 0.0
	aiming = false
	rolling = false
	_shape.set_deferred("disabled", true)
	model.start_ragdoll(impulse, at)
	died.emit()


func respawn() -> void:
	model.stop_ragdoll()
	dead = false
	crouching = false
	rolling = false
	grabbed = false
	grabber = null
	_stun = 0.0
	_down_t = 0.0
	_fly_t = 0.0
	_rising = false
	_knock = Vector3.ZERO
	health = 100
	health_changed.emit(health)
	velocity = Vector3.ZERO
	global_transform = _spawn
	camera_rig.yaw = rotation.y
	_shape.set_deferred("disabled", false)
