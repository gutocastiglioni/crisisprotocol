class_name Allosaurus
extends Enemy
## Alossauro, o chefe da última sala (~9 m, quadril a 2,6 m). Percepção, patrulha e alarme vêm de Enemy. Ao ver a presa
## ruge de cabeça erguida: não fere, mas quem estiver a até ROAR_RANGE fica atordoada por DAZE_TIME (Player.daze). Depois a
## persegue andando pesado e ataca conforme a distância e o lado em que ela está: pisada (perto dos pés: esmaga e
## arremessa), cabeçada (perto, do lado da cabeça: derruba para o lado), rabada (atrás dele: o corpo gira e a cauda varre),
## mordida (na frente, a meia distância: agarra pelo corpo, sacode e arremessa para o lado), rugido na batalha (abaixa e
## ruge na cara dela: atordoa só quem está na frente, até ROAR_AT_RANGE) ou investida (longe). Rolar na hora certa
## esquiva dos golpes (não do rugido). Grande demais para se encolher a cada tiro: só reage (Hit) depois de juntar
## FLINCH_DAMAGE. Morre em ragdoll (sinal `killed`: fim do jogo).

signal killed
signal attacked(kind: String)

const WALK_ANIM_SPEED := 2.016  # m/s da animação Walk em velocidade 1 (art/allosaurus_anims.py, anim_speed)
const RUN_ANIM_SPEED := 6.19  # idem Run
const WALK_SPEED := 1.8
const RUN_SPEED := 6.2  # mais rápido que ela correndo (4,4): tem que rolar ou se esconder
const STALK_DIST := 6.0
const MAX_HEALTH := 900
const FLINCH_DAMAGE := 140
const ROAR_RANGE := 18.0
const ROAR_PEAK := 0.667  # quadro 20 do Roar
const ROAR_COOLDOWN := 14.0
const DAZE_TIME := 3.0
const STOMP_RANGE := 3.6  # ela a esta distância (na frente ou do lado): pisada
const STOMP_HIT := 0.667  # quadro 20 do Stomp
const STOMP_RADIUS := 1.8  # do pé que desce até ela: esmagada e arremessada
const SHOCK_RADIUS := 3.2  # mais longe que isso, só o tremor (empurrão sem dano)
const BITE_RANGE := Vector2(1.5, 5.2)  # na frente, entre estas distâncias: mordida
const BITE_SNAP := 0.5  # quadro 15 do Bite
const BITE_REACH := 1.4  # da boca até o peito dela no fechar da boca
const HOLD_TIME := 1.0
const SHAKE_PERIOD := 0.533  # um ciclo da animação Shake
const THROW_RELEASE := 0.333  # quadro 10 do Throw
const ROAR_AT_PEAK := 0.533  # quadro 16 do RoarAt
const ROAR_AT_RANGE := 14.0
const ROAR_AT_CONE := deg_to_rad(45.0)  # meio cone à frente dele em que o rugido direcionado pega
const HEAD_HIT := Vector2(0.3, 0.55)  # janela em que a cabeça varre o lado (quadro 12 do Headbutt no meio)
const HEAD_REACH := 1.1  # do crânio (nuca até a boca) até o peito dela
const HEAD_SIDE := 1.2  # ela a mais que isso para o lado (perto): cabeçada em vez de pisada
const TAIL_HIT := Vector2(0.4, 0.75)  # janela em que a cauda varre (quadro 16 do TailWhip no começo)
const TAIL_REACH := 6.5  # ela atrás dele, até esta distância: rabada
const TAIL_SPIN := deg_to_rad(70.0)
const DAMAGE := {"stomp": 30, "bite": 8, "throw": 14, "charge": 22, "headbutt": 18, "tail": 20}
const COMBAT := ["roar", "roar_at", "stalk", "charge", "stomp", "bite", "hold", "throw", "headbutt", "tail", "recover", "hit"]

var model: AllosaurusModel
var health := MAX_HEALTH
var grab_bone := "Spine"  # a mordida pega o corpo dela (Player._held_body), não o braço como o raptor
var last_hit_at := Vector3.ZERO
var _done := false
var _dazed_done := false
var _roar_cd := 0.0
var _flinch := 0
var _ticks := 0
var _spin := 0.0
var _side := 1.0  # para onde o golpe varre: 1 = esquerda dele


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	# pernas (movimento) + tronco, pescoço e cabeça (alvo dos tiros)
	var legs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.9
	cap.height = 2.8
	legs.shape = cap
	legs.position.y = 1.4
	add_child(legs)
	var torso := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.6, 4.6)
	torso.shape = box
	torso.position = Vector3(0, 2.75, -0.9)
	add_child(torso)
	var head := CollisionShape3D.new()
	var hb := BoxShape3D.new()
	hb.size = Vector3(0.8, 1.0, 1.4)
	head.shape = hb
	head.position = Vector3(0, 3.2, -2.75)
	add_child(head)
	model = AllosaurusModel.new()
	add_child(model)
	sight_range = 18.0
	fov_half = deg_to_rad(70.0)
	eye_height = 3.4
	marker_height = 4.6
	turn_rate = 2.5
	patrol_speed = 1.6
	investigate_speed = 2.0
	hunt_speed = 5.0
	head_mult = 1.5
	_enemy_ready()


func _physics_process(delta: float) -> void:
	_tick(delta)
	_roar_cd = maxf(_roar_cd - delta, 0.0)
	if not _calm_state(delta):
		_combat_state(delta)
	EnemyCrowd.apply_separation(self)
	move_and_slide()


func in_combat() -> bool:
	return state in COMBAT


## Sensor de perigo: pisada/mordida/cabeçada/cauda ao alcance = certo; a investida vem de longe. O rugido não fere.
func _threat() -> float:
	if state in ["roar", "roar_at"]:
		return 0.3
	return _melee_threat(["stomp", "bite", "hold", "throw", "headbutt", "tail"], BITE_RANGE.y, ["charge"])


func _play(anim: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	model.play(anim, blend, speed, restart)


func _anim_speed(run: bool) -> float:
	return RUN_ANIM_SPEED if run else WALK_ANIM_SPEED


func _on_spotted() -> void:
	start_roar()


func _on_enter() -> void:
	_done = false


func _combat_state(delta: float) -> void:
	match state:
		"roar":
			_roar(delta)
		"roar_at":
			_roar_at(delta)
		"headbutt":
			_headbutt(delta)
		"tail":
			_tail(delta)
		"stalk":
			_stalk(delta)
		"charge":
			_charge(delta)
		"stomp":
			_stomp(delta)
		"bite":
			_bite(delta)
		"hold":
			_hold(delta)
		"throw":
			_throw(delta)
		"recover", "hit":
			_stop(delta)
			if _has_target():
				_face(_to_target(), delta, 1.5)
			if _t >= _dur:
				start_stalk()
		"dead":
			_stop(delta)


# ------------------------------------------------------------------ estados
func start_roar() -> void:
	_dazed_done = false
	_roar_cd = ROAR_COOLDOWN
	_enter("roar", "Roar", 0.2)


## Rugido na batalha: abaixa e ruge voltado para ela.
func start_roar_at() -> void:
	_dazed_done = false
	_roar_cd = ROAR_COOLDOWN
	_enter("roar_at", "RoarAt", 0.15)


## Cabeçada para o lado em que ela está.
func start_headbutt() -> void:
	var on_left := (global_basis.inverse() * _to_target()).x < 0.0  # -X do corpo = esquerda dele
	_side = 1.0 if on_left else -1.0
	_enter("headbutt", "Headbutt" if on_left else "HeadbuttR", 0.1)


## Rabada: vira o corpo para o lado contrário dela e a cauda varre por cima de onde ela está.
func start_tail() -> void:
	var on_left := (global_basis.inverse() * _to_target()).x < 0.0
	_spin = -TAIL_SPIN if on_left else TAIL_SPIN
	_side = 1.0 if on_left else -1.0
	_enter("tail", "TailWhip" if on_left else "TailWhipR", 0.1)


func start_stalk() -> void:
	if not _has_target():
		_enter("idle", "Idle")
		return
	_enter("stalk", "Walk", 0.3)
	_dur = rng.randf_range(1.2, 2.4)


func start_charge() -> void:
	_enter("charge", "Run", 0.2)


func start_stomp() -> void:
	_enter("stomp", "Stomp", 0.12)


func start_bite() -> void:
	_enter("bite", "Bite", 0.1)


func _recover(time := 0.9) -> void:
	_enter("recover", "Idle", 0.3)
	_dur = time


## Decide o ataque pela distância e pelo lado em que ela está.
func choose_attack() -> void:
	if not _combat_sees():
		alert_t = ALERT_TIME
		start_hunt(_last_known)
		return
	var to := _to_target()
	var dist := to.length()
	var local := global_basis.inverse() * to
	var ahead := local.z < 0.0 and absf(local.x) < -local.z * 1.2
	if local.z > 0.5 and dist < TAIL_REACH:
		start_tail()
	elif dist < STOMP_RANGE + 0.8 and local.z < 1.0 and absf(local.x) > HEAD_SIDE:
		start_headbutt()
	elif dist < STOMP_RANGE and local.z < 1.0:
		start_stomp()
	elif _roar_cd <= 0.0 and ahead and dist < ROAR_AT_RANGE and rng.randf() < 0.3:
		start_roar_at()
	elif ahead and dist >= BITE_RANGE.x and dist <= BITE_RANGE.y:
		start_bite()
	elif dist > STALK_DIST + 3.0:
		start_charge()
	else:
		start_stalk()


func _roar(delta: float) -> void:
	_stop(delta)
	if _has_target():
		_face(_to_target(), delta, 1.5)
	if not _dazed_done and _t >= ROAR_PEAK:
		_dazed_done = true
		# o rugido não fere: atordoa quem estiver perto o bastante para levar o susto
		if _has_target() and _to_target().length() < ROAR_RANGE:
			target.daze(DAZE_TIME)
			attacked.emit("roar")
	if _t >= model.length_of("Roar"):
		start_stalk()


## Rugido direcionado: atordoa se ela estiver na frente dele e perto o bastante (no pico do rugido).
func _roar_at(delta: float) -> void:
	_stop(delta)
	# só termina de virar na preparação: quem rola para o lado no rugido escapa
	if _has_target() and _t < 0.27:
		_face(_to_target(), delta, 3.0)
	if not _dazed_done and _t >= ROAR_AT_PEAK:
		_dazed_done = true
		if _has_target():
			var to := _to_target()
			var off := absf(angle_difference(rotation.y, atan2(-to.x, -to.z)))
			if to.length() < ROAR_AT_RANGE and off < ROAR_AT_CONE:
				target.daze(DAZE_TIME)
	if _t >= model.length_of("RoarAt"):
		start_stalk()


## Cabeçada: na janela em que o crânio varre o lado, se ele passar por ela, derruba para o lado do golpe.
func _headbutt(delta: float) -> void:
	_stop(delta)
	if not _done and _t >= HEAD_HIT.x and _t <= HEAD_HIT.y and _has_target():
		var chest := target.global_position + Vector3.UP * 1.1
		var skull := Geometry3D.get_closest_point_to_segment(chest, model.bone_point("Head"), model.mouth_position())
		if skull.distance_to(chest) < HEAD_REACH:
			var push := -global_basis.x * _side * 8.0 - global_basis.z * 2.0 + Vector3.UP * 3.0
			_strike("headbutt", push, skull)
	if _t >= model.length_of("Headbutt"):
		_recover(0.7)


## Rabada: o corpo gira e a cauda varre; se a cauda passar por ela, arremessa para o lado da varrida.
func _tail(delta: float) -> void:
	_stop(delta)
	if _t > 0.3 and _t < 0.65:
		rotation.y += _spin / 0.35 * delta
	if not _done and _t >= TAIL_HIT.x and _t <= TAIL_HIT.y and _has_target():
		var hip := target.global_position + Vector3.UP * 0.9
		var tail := Geometry3D.get_closest_point_to_segment(hip, model.bone_point("Tail2"), model.bone_point("Tail4", 1.55))
		if tail.distance_to(hip) < 1.1:
			var push := -global_basis.x * _side * 9.0 + global_basis.z * 2.0 + Vector3.UP * 3.0
			_strike("tail", push, tail)
	if _t >= model.length_of("TailWhip"):
		_recover(0.6)


## Persegue andando pesado até a distância de ataque, sempre de frente para ela.
func _stalk(delta: float) -> void:
	if not _has_target():
		_enter("idle", "Idle")
		return
	if _lost_t > LOSE_TIME:
		alert_t = ALERT_TIME
		start_hunt(_last_known)
		return
	# ela chegou perto da traseira: rabada na hora (antes de virar de frente para ela)
	var local := global_basis.inverse() * _to_target()
	if local.z > 0.5 and _to_target().length() < TAIL_REACH - 1.0:
		start_tail()
		return
	var to := _to_target()
	var dist := to.length()
	_face(to, delta, turn_rate)
	if dist > STALK_DIST * 0.6:
		var fwd := -global_basis.z
		var speed := WALK_SPEED * maxf(fwd.dot(to / maxf(dist, 0.01)), 0.0)
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
		model.play("Walk", 0.3, maxf(speed, 0.4) / WALK_ANIM_SPEED)
	else:
		_stop(delta)
		model.play("Study", 0.3)
	# perto o bastante para um golpe: decide já; senão, depois do tempo de perseguir
	if dist < BITE_RANGE.y or _t >= _dur:
		choose_attack()


func _charge(delta: float) -> void:
	var to := _to_target()
	var dist := to.length()
	_face(to, delta, 3.0)
	var fwd := -global_basis.z
	velocity.x = fwd.x * RUN_SPEED
	velocity.z = fwd.z * RUN_SPEED
	model.play("Run", 0.15, RUN_SPEED / RUN_ANIM_SPEED)
	if not _has_target() or _t > 3.5:
		_recover()
	elif dist < BITE_RANGE.y - 0.5:
		var local := global_basis.inverse() * to
		if dist < 2.4:
			# trombada com o peito
			_strike("charge", fwd * 9.0 + Vector3.UP * 3.0, target.global_position + Vector3.UP * 1.0)
			_recover(1.0)
		elif local.z < 0.0:
			start_bite()


## Ergue o pé e esmaga: perto do pé que desce, ela é ferida e arremessada; um pouco mais longe, só o tremor a empurra.
func _stomp(delta: float) -> void:
	_stop(delta)
	if _t < 0.3 and _has_target():
		_face(_to_target(), delta, 4.0)
	if not _done and _t >= STOMP_HIT:
		_done = true
		var foot: Vector3 = model.claw_positions()[1]
		foot.y = global_position.y
		if _has_target():
			var away := _flat(target.global_position - foot)
			var d := away.length()
			var dir := away / d if d > 0.05 else -global_basis.z
			if d < STOMP_RADIUS:
				_strike("stomp", dir * 9.0 + Vector3.UP * 4.0, foot + Vector3.UP * 0.3)
			elif d < SHOCK_RADIUS and not target.is_dodging():
				target.knockback(dir * 5.0)
		attacked.emit("stomp_ground")
	if _t >= model.length_of("Stomp"):
		_recover(0.7)


func _bite(delta: float) -> void:
	# avança com o bote até a boca chegar nela
	var close := _has_target() and _to_target().length() < 2.6
	var lunge := 3.5 if _t > 0.15 and _t < BITE_SNAP and not close else 0.0
	var fwd := -global_basis.z
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if _t < 0.25 and _has_target():
		_face(_to_target(), delta, 6.0)
	if not _done and _t >= BITE_SNAP:
		_done = true
		if _has_target() and not target.is_dodging() and _mouth_on_target():
			_start_hold()
			return
	if _t >= model.length_of("Bite"):
		_recover(0.8)


func _mouth_on_target() -> bool:
	var chest := target.global_position + Vector3.UP * 1.1
	return model.mouth_position().distance_to(chest) < BITE_REACH


func _start_hold() -> void:
	_enter("hold", "Shake", 0.06)
	_ticks = 0
	target.grab(self)
	attacked.emit("bite")


func _hold(_delta: float) -> void:
	_stop(1.0)
	if not is_instance_valid(target) or not target.grabbed or target.grabber != self:
		_recover(0.8)
		return
	var tick := int(_t / SHAKE_PERIOD)
	if tick > _ticks and not target.dead:
		_ticks = tick
		target.take_hit(GameMode.enemy_damage(DAMAGE.bite), global_basis.x * (1.0 if tick % 2 == 0 else -1.0), model.mouth_position())
	if _t >= HOLD_TIME:
		_enter("throw", "Throw", 0.08)


## Chicoteia a cabeça para a esquerda dele e solta: ela voa para o lado e cai.
func _throw(_delta: float) -> void:
	_stop(1.0)
	if not _done and _t >= THROW_RELEASE:
		_done = true
		if is_instance_valid(target) and target.grabbed and target.grabber == self:
			# esquerda dele = -X do corpo (o modelo é girado 180°)
			var throw := -global_basis.x * 8.0 - global_basis.z * 4.0 + Vector3.UP * 5.0
			last_hit_at = model.mouth_position()
			target.take_hit(GameMode.enemy_damage(DAMAGE.throw), throw.normalized(), last_hit_at)
			_release(throw)
			attacked.emit("throw")
	if _t >= model.length_of("Throw"):
		_recover(1.0)


func _release(throw: Vector3) -> void:
	if is_instance_valid(target) and target.grabbed and target.grabber == self:
		target.release(throw)


## Golpe `kind` (dano + arremesso a partir de `at`), a não ser que ela esteja rolando.
func _strike(kind: String, push: Vector3, at: Variant = null) -> void:
	_done = true
	if not _has_target() or target.is_dodging():
		return
	var hit: Vector3 = at if at is Vector3 else target.global_position + Vector3.UP
	last_hit_at = hit
	target.take_hit(GameMode.enemy_damage(DAMAGE[kind]), push.normalized(), hit)
	if not target.dead:
		target.launch(push, hit)
	attacked.emit(kind)


# ------------------------------------------------------------------ dano
func take_hit(amount: int, dir: Vector3, at: Vector3, _head := false) -> void:
	if dead:
		return
	health = maxi(0, health - amount)
	if health == 0:
		die(dir, at)
		return
	if not state in COMBAT and _has_target():
		_raise_alarm()
		start_roar()
		return
	_flinch += amount
	if _flinch >= FLINCH_DAMAGE and state in ["stalk", "recover", "charge"]:
		_flinch = 0
		_enter("hit", "Hit", 0.05)
		_dur = 0.5


func wound() -> float:
	return 1.0 - float(health) / MAX_HEALTH


func die(dir := Vector3.ZERO, at: Variant = null) -> void:
	_release(-global_basis.z * 2.0)
	dead = true
	state = "dead"
	_t = 0.0
	collision_layer = 0
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var carry := Vector3(velocity.x, maxf(velocity.y, 0.0), velocity.z)
	velocity = Vector3.ZERO
	model.start_ragdoll(carry + flat * 1.2, flat * 400.0, at)
	Blood.pool(model.ragdoll.bodies["Spine"], 5.0)
	_update_marker()
	killed.emit()


func reset() -> void:
	model.stop_ragdoll()
	_reset_enemy()
	health = MAX_HEALTH
	_flinch = 0
	_roar_cd = 0.0
	collision_layer = 2
	_enter("idle", "Idle", 0.0)
