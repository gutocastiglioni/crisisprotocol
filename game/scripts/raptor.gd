class_name Raptor
extends Enemy
## Velociraptor inimigo (jeito Dino Crisis 2). Percepção, patrulha e alarme vêm de Enemy; ao ver a presa dá o grito
## (que é o alarme), a estuda rodeando e farejando, e ataca: salto, investida, rabada (se ela estiver perto da traseira)
## ou, às vezes, mordida que segura e sacode. Rolar na hora certa esquiva de qualquer ataque.
## Emboscada (Cutscene.play_ambush): `lurk` o esconde na mata (sem corpo nem IA); `start_ambush` o faz sair correndo e
## rodear a presa a `radius` dela sem atacar (estado "ambush", a cena manda); `ambush_roar` para e ruge; `end_ambush`
## solta a luta já alertado (estuda e ataca).

signal killed
signal attacked(kind: String)

const STUDY_DIST := 4.5
const WALK_SPEED := 1.1
const RUN_SPEED := 7.0
const RUN_ANIM_SPEED := 4.2  # m/s que a animação Run representa em velocidade 1 (passada 1 m em 0,24 s de apoio)
const WALK_ANIM_SPEED := 1.075  # idem Walk (passada 0,8 m em 0,744 s de apoio): sem patinar
const CLAW_REACH := 0.5  # garra a esta distância do corpo dela = acertou
const LEAP_UP := 5.0
const LEAP_MAX_SPEED := 10.0
const LEAP_PREP := 0.32
const BITE_REACH := 2.1
const BITE_SNAP := 0.4  # quadro 12 da animação Bite
const TAIL_REACH := 2.9
const TAIL_HIT := 0.38
const TAIL_SPIN := deg_to_rad(80.0)
const HOLD_TIME := 1.6
const SHAKE_PERIOD := 0.4  # um ciclo da animação Shake
const DOWN_TIME := 3.0  # tempo caído no chão após abate furtivo antes de levantar no contra-ataque
const COUNTER_REACH := 2.8  # alcance do contra-ataque ao levantar
const MAX_HEALTH := 170
const DAMAGE := {"leap": 22, "charge": 16, "tail": 14, "bite": 7, "counter": 18}
const BITE_CHANCE := 0.6  # perto e de frente: morde ou recua
const COMBAT := ["roar", "study", "charge", "leap_prep", "leap", "bite", "hold", "tail", "counter", "recover", "hit"]

var model: RaptorModel
var health := MAX_HEALTH
var _done := false  # o golpe deste ataque já foi resolvido (acertou ou errou)
var _circle := 1.0
var _bite_after_charge := false
var _spin := 0.0
var _ticks := 0
var last_hit_at := Vector3.ZERO  # onde o último golpe pegou nela (garra no salto, cabeça na investida)
var _study_dist := STUDY_DIST
var _ring_radius := 5.0
var _ring_roar := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	# patas/corpo (movimento) + tronco e cabeça (alvo dos tiros)
	var legs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.3
	legs.shape = cap
	legs.position.y = 0.65
	add_child(legs)
	var torso := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.7, 1.7)
	torso.shape = box
	torso.position = Vector3(0, 1.1, -0.45)
	add_child(torso)
	model = RaptorModel.new()
	add_child(model)
	patrol_speed = 1.4
	investigate_speed = 2.4
	hunt_speed = 4.2
	head_mult = 1.0  # cabeçudo: tiro na cabeça vale como no corpo (sem headshot)
	can_stealth = true
	_enemy_ready()


func _physics_process(delta: float) -> void:
	if lurking:
		return
	if state == "ambush":
		_ambush(delta)
		move_and_slide()
		return
	_tick(delta)
	if not _calm_state(delta):
		_combat_state(delta)
	EnemyCrowd.apply_separation(self)
	move_and_slide()


func in_combat() -> bool:
	return state in COMBAT


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
			_stop(delta)
			_face(_to_target(), delta, 2.0)
			if _t >= model.length_of("Roar"):
				start_study()
		"study":
			_study(delta)
		"charge":
			_charge(delta)
		"leap_prep":
			_stop(delta)
			_face(_to_target(), delta, 12.0)
			if _t >= LEAP_PREP:
				_launch()
		"leap":
			_leap(delta)
		"bite":
			_bite(delta)
		"hold":
			_hold(delta)
		"tail":
			_tail(delta)
		"down":
			_stop(delta)
			if not _stealth_locked and _t >= _dur:
				start_counter()
		"counter":
			_counter(delta)
		"recover", "hit":
			_stop(delta)
			if state == "recover" and _t > 0.3 and _behind_close():
				start_tail()
			elif _has_target():
				_face(_to_target(), delta, 3.0)
			if _t >= _dur:
				start_study()
		"dead":
			_stop(delta)


# ------------------------------------------------------------------ estados
func start_roar() -> void:
	_enter("roar", "Roar")


func start_study() -> void:
	if not _has_target():
		_enter("idle", "Idle")
		return
	_study_dist = STUDY_DIST + rng.randf_range(-0.5, 0.5)
	_enter("study", "Walk", 0.25)
	_dur = rng.randf_range(1.1, 2.4)
	_circle = 1.0 if rng.randf() < 0.5 else -1.0


func start_charge(bite := false) -> void:
	_bite_after_charge = bite
	_enter("charge", "Run", 0.1)


func start_leap() -> void:
	_enter("leap_prep", "LeapPrep", 0.1)


func start_bite() -> void:
	_enter("bite", "Bite", 0.08)


func start_tail() -> void:
	var local := global_basis.inverse() * _to_target()
	# vira o corpo para o lado contrário dela: a cauda varre por cima de onde ela está
	var on_left := local.x < 0.0
	_spin = -TAIL_SPIN if on_left else TAIL_SPIN
	_enter("tail", "TailWhip" if on_left else "TailWhipR", 0.08)


## Cai no chão atordoado após o abate furtivo por DOWN_TIME segundos, vulnerável ao golpe crítico.
func start_down() -> void:
	velocity = Vector3.ZERO
	_enter("down", "Death", 0.08)
	_play("Death", 0.08, 1.6)
	_dur = DOWN_TIME


## Levanta do chão num contra-ataque se não foi finalizado a tempo: dá o alarme e varre em volta.
func start_counter() -> void:
	if _has_target():
		_raise_alarm()
	var local := global_basis.inverse() * _to_target()
	var on_left := local.x < 0.0
	_spin = -TAIL_SPIN if on_left else TAIL_SPIN
	_enter("counter", "TailWhip" if on_left else "TailWhipR", 0.1)


## Escondido em `at` (na moita) até a emboscada: invisível, sem colisão e sem IA.
func lurk(at: Vector3) -> void:
	lurking = true
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	global_position = at
	reset_physics_interpolation()
	state = "idle"
	_update_marker()


## Sai da moita correndo até `radius` dela e passa a rodeá-la (`circle` = 1 ou -1, o sentido), sem atacar.
func start_ambush(radius: float, circle: float) -> void:
	lurking = false
	visible = true
	collision_layer = 2
	_ring_radius = radius
	_circle = circle
	_ring_roar = false
	if _has_target():
		var to := _to_target()
		rotation.y = atan2(-to.x, -to.z)
	reset_physics_interpolation()
	_enter("ambush", "Run", 0.1)


## No meio da roda: para, vira para ela e ruge (a cena escolhe quem).
func ambush_roar() -> void:
	_ring_roar = true
	_t = 0.0
	_play("Roar", 0.15, 1.0, true)


func _ambush(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	if not _has_target():
		_stop(delta)
		return
	var to := _to_target()
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	if _ring_roar:
		_stop(delta)
		_face(dir, delta, 6.0)
		if _t >= model.length_of("Roar"):
			_ring_roar = false
		return
	var move: Vector3
	var speed: float
	if dist > _ring_radius + 1.0:
		move = dir
		speed = minf(4.2, (dist - _ring_radius) * 2.0 + 1.5)
	else:
		var tangent := dir.cross(Vector3.UP) * _circle
		move = (tangent + dir * clampf((dist - _ring_radius) * 0.8, -1.0, 1.0)).normalized()
		speed = 1.6
	_face(move, delta, 5.0)
	var fwd := -global_basis.z
	var v := speed * maxf(fwd.dot(move), 0.2)
	velocity.x = fwd.x * v
	velocity.z = fwd.z * v
	var run := v > 3.0
	model.play("Run" if run else "Walk", 0.25, maxf(v, 0.4) / (RUN_ANIM_SPEED if run else WALK_ANIM_SPEED))


## Fim da cena da emboscada: já sabe onde ela está e avisou os outros; estuda um tempo (`delay` a mais) e ataca.
func end_ambush(delay := 0.0) -> void:
	if dead:
		return
	if lurking:
		start_ambush(_ring_radius, _circle)
	alert_t = ALERT_TIME
	aware = 1.0
	_lost_t = 0.0
	_alarm_delay = -1.0
	if _has_target():
		_last_known = target.global_position
	start_study()
	_dur += delay


func _recover(time := 0.8) -> void:
	_enter("recover", "Idle", 0.25)
	_dur = time


## Decide o ataque depois de estudar a presa (distância e lado em que ela está).
func choose_attack() -> void:
	if not _combat_sees():
		# ela sumiu enquanto ele estudava: não ataca no escuro, vai até onde a viu
		alert_t = ALERT_TIME
		start_hunt(_last_known)
		return
	var to := _to_target()
	var dist := to.length()
	var local := global_basis.inverse() * to
	var r := rng.randf()
	if local.z > 0.3 and dist < TAIL_REACH:
		start_tail()
	elif dist < 2.6:
		if r < BITE_CHANCE:
			start_bite()
		else:
			start_study()  # recua até a distância de estudo
	elif dist < 8.0:
		if r < 0.45:
			start_leap()
		else:
			start_charge(r > 0.75)
	else:
		start_charge(r > 0.6)


func _study(delta: float) -> void:
	if not _has_target():
		_enter("idle", "Idle")
		return
	# perdeu a presa de vista (ela se escondeu ou fugiu): vai até onde a viu por último
	if _lost_t > LOSE_TIME:
		alert_t = ALERT_TIME
		start_hunt(_last_known)
		return
	# ela chegou perto da traseira: rabada na hora (antes de virar de frente para ela)
	if _behind_close():
		start_tail()
		return
	var to := _to_target()
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	var looking := _t > _dur * 0.6
	var move := Vector3.ZERO
	if not looking:
		var tangent := dir.cross(Vector3.UP) * _circle
		if EnemyCrowd.is_enemy_in_path(self, tangent, 2.2):
			_circle = -_circle
			tangent = dir.cross(Vector3.UP) * _circle
		move = (tangent + dir * clampf((dist - _study_dist) * 0.8, -1.0, 1.0)).normalized()
	elif absf(dist - _study_dist) > 1.5:
		move = dir * signf(dist - _study_dist)
	if move.length() > 0.1:
		# anda para onde o corpo aponta (nunca de lado) e a passada acompanha a velocidade: pés não patinam
		_face(move, delta, 3.0)
		var fwd := -global_basis.z
		var speed := WALK_SPEED * maxf(fwd.dot(move), 0.0)
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
		model.play("Walk", 0.3, maxf(speed, 0.35) / WALK_ANIM_SPEED)
	else:
		_stop(delta)
		_face(dir, delta, 4.0)
		model.play("Study", 0.3)
	if _t >= _dur:
		choose_attack()


func _charge(delta: float) -> void:
	var to := _to_target()
	var dist := to.length()
	_face(to, delta, 8.0)
	var fwd := -global_basis.z
	velocity.x = fwd.x * RUN_SPEED
	velocity.z = fwd.z * RUN_SPEED
	model.play("Run", 0.1, RUN_SPEED / RUN_ANIM_SPEED)
	if not _has_target() or _t > 2.4:
		_recover()
	elif _bite_after_charge and dist < BITE_REACH + 0.6:
		start_bite()
	elif dist < 1.9:
		# trombada: derruba para trás com a cabeça e o peito
		_strike("charge", fwd * 7.0 + Vector3.UP * 2.0, target.global_position + Vector3.UP * 1.0)
		velocity.x *= 0.2
		velocity.z *= 0.2
		model.play("Bite", 0.05, 1.4, true)
		_recover(0.9)


func _launch() -> void:
	var to := _to_target()
	var dist := to.length()
	var flight := 2.0 * LEAP_UP / GRAVITY
	# cai em cima dela, considerando para onde ela está indo
	var aim: Vector3 = to + (target.velocity * 0.25 if _has_target() else Vector3.ZERO)
	aim.y = 0.0
	var speed := minf(maxf(aim.length() - 0.6, 0.0) / flight, LEAP_MAX_SPEED)
	var dir := aim.normalized() if aim.length() > 0.01 else -global_basis.z
	velocity = dir * speed + Vector3.UP * LEAP_UP
	_face(dir, 1.0, 100.0)
	_enter("leap", "LeapAir", 0.05)


func _leap(_delta: float) -> void:
	# acerta com as garras dos pés (pose LeapAir: pernas à frente)
	if not _done and _has_target():
		var feet := target.global_position
		for claw in model.claw_positions():
			var on_body := Vector3(feet.x, clampf(claw.y, feet.y + 0.2, feet.y + 1.5), feet.z)
			if claw.distance_to(on_body) < CLAW_REACH + 0.28:  # + raio da cápsula dela
				_strike("leap", -global_basis.z * 8.0 + Vector3.UP * 2.5, claw)
				break
	if _t > 0.15 and is_on_floor():
		velocity.x = 0.0
		velocity.z = 0.0
		_recover(0.7)


func _bite(delta: float) -> void:
	# avança com o bote entre o preparo e o fechar da boca, até a boca chegar nela
	var close := _has_target() and _to_target().length() < 1.6
	var lunge := 2.5 if _t > 0.15 and _t < BITE_SNAP and not close else 0.0
	var fwd := -global_basis.z
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	if _t < 0.2 and _has_target():
		_face(_to_target(), delta, 10.0)
	if not _done and _t >= BITE_SNAP:
		_done = true
		if _in_bite_range() and not target.is_dodging():
			_start_hold()
			return
	if _t >= model.length_of("Bite"):
		_recover(0.6)


func _in_bite_range() -> bool:
	if not _has_target():
		return false
	var to := _to_target()
	var local := global_basis.inverse() * to
	return to.length() < BITE_REACH and local.z < 0.0 and absf(local.x) < -local.z * 0.85


func _start_hold() -> void:
	_enter("hold", "Shake", 0.05)
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
		var side := global_basis.x * (1.0 if tick % 2 == 0 else -1.0)
		target.take_hit(GameMode.enemy_damage(DAMAGE.bite), side, model.mouth_position())
	# ela se debatendo (apertando botões) solta antes; morta, ele sacode até o fim e larga
	if _t >= maxf(0.6, HOLD_TIME - target.struggle * 0.1):
		_release(-global_basis.z * 5.0 + global_basis.x * 3.0 + Vector3.UP * 2.0)
		_recover(1.0)


func _release(throw: Vector3) -> void:
	if is_instance_valid(target) and target.grabbed and target.grabber == self:
		target.release(throw)


func _tail(delta: float) -> void:
	_stop(delta)
	if _t > 0.23 and _t < 0.53:
		rotation.y += _spin / 0.3 * delta
	if not _done and _t >= TAIL_HIT:
		_done = true
		var to := _to_target()
		var local := global_basis.inverse() * to
		if _has_target() and to.length() < TAIL_REACH and local.z > -0.8:
			# a cauda varre de lado: empurra na direção do giro
			var push := global_basis.x * (1.0 if _spin > 0.0 else -1.0)
			_strike("tail", push * 7.0 + to.normalized() * 3.0 + Vector3.UP * 2.0)
	if _t >= model.length_of("TailWhip"):
		_recover(0.6)


## Executa o contra-ataque ao levantar: gira o corpo e derruba a heroína se ela estiver perto (COUNTER_REACH).
func _counter(delta: float) -> void:
	_stop(delta)
	if _has_target() and _t < TAIL_HIT:
		_face(_to_target(), delta, 10.0)
	if _t > 0.23 and _t < 0.53:
		rotation.y += _spin / 0.3 * delta
	if not _done and _t >= TAIL_HIT:
		_done = true
		var to := _to_target()
		if _has_target() and to.length() < COUNTER_REACH:
			var dir := to.normalized() if to.length() > 0.01 else -global_basis.z
			_strike("counter", dir * 8.0 + Vector3.UP * 2.5, target.global_position + Vector3.UP * 1.0)
	if _t >= model.length_of("TailWhip"):
		start_study()


## Aplica o golpe `kind` (dano + empurrão a partir de `at`), a não ser que ela esteja rolando.
func _strike(kind: String, push: Vector3, at: Variant = null) -> void:
	_done = true
	if not _has_target() or target.is_dodging():
		return
	var hit: Vector3 = at if at is Vector3 else target.global_position + Vector3.UP
	last_hit_at = hit
	target.take_hit(GameMode.enemy_damage(DAMAGE[kind]), push.normalized(), hit)
	if target.dead:
		pass
	elif kind in ["leap", "charge", "counter"]:
		target.launch(push, hit)  # arremessada, dobrando em C em volta do golpe
	else:
		target.knockback(push)
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
		# levou tiro sem ter notado ninguém: já sabe onde ela está e avisa os outros
		_raise_alarm()
	if state == "hold":
		# tiro faz soltar a presa
		_release(-global_basis.z * 3.0 + Vector3.UP * 1.5)
	if state in ["leap", "tail", "charge", "down", "counter"]:
		return
	_enter("hit", "Hit", 0.05)
	_dur = 0.45


## Golpe crítico disponível quando o raptor está caído no chão ("down") a até CRIT_RANGE, de qualquer direção.
func can_crit_strike(p: Player) -> bool:
	if dead or state != "down" or not is_instance_valid(p) or p.dead:
		return false
	return _flat(p.global_position - global_position).length() <= CRIT_RANGE and _line_clear(p)


## Abate furtivo silencioso pelas costas: tira 70% da vida máxima sem dar alarme e derruba no chão ("down").
func assassinate(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	stealth_lock(false)
	var dmg := roundi(MAX_HEALTH * 0.7)
	health = maxi(0, health - dmg)
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.0
	var d := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.splash(get_parent(), hit, d, -d, 1.2)
	Sfx.play(model, "impact_flesh", hit)
	Sfx.play(model, "raptor_hurt", model.mouth_position(), 0.0, model.voice_pitch)
	if health == 0:
		die(d, hit)
	else:
		start_down()


## Segundo golpe em sequência no raptor caído: dano crítico letal que o finaliza sem dar alarme.
func crit_strike(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	stealth_lock(false)
	var dmg := maxi(health, roundi(MAX_HEALTH * 0.35))
	health = maxi(0, health - dmg)
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 0.5
	var d := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.splash(get_parent(), hit, d, Vector3.UP, 1.5)
	Sfx.play(model, "impact_flesh", hit)
	die(d, hit, true)


func wound() -> float:
	return 1.0 - float(health) / MAX_HEALTH


## Morre virando ragdoll: tomba na direção do tiro, levando junto o embalo que tinha (salto, investida); a poça de
## sangue cresce embaixo do corpo.
func die(dir := Vector3.ZERO, at: Variant = null, silent := false) -> void:
	_release(-global_basis.z * 2.0)
	var was_down := state == "down"
	dead = true
	state = "dead"
	_t = 0.0
	collision_layer = 0
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var carry := Vector3(velocity.x, maxf(velocity.y, 0.0), velocity.z)
	velocity = Vector3.ZERO
	model.start_ragdoll(carry + flat * (0.6 if was_down else 1.8), flat * (12.0 if was_down else 30.0), at)
	Blood.pool(model.ragdoll.bodies["Spine"], 2.4)
	if not silent and is_inside_tree():
		get_tree().call_group("enemies", "hear_noise", global_position, 6.0, 1.2)
	if is_inside_tree():
		get_tree().call_group("enemies", "on_nearby_kill", global_position, 8.0)
	_update_marker()
	killed.emit()


func reset() -> void:
	model.stop_ragdoll()
	lurking = false
	visible = true
	_ring_roar = false
	_reset_enemy()
	health = MAX_HEALTH
	collision_layer = 2
	_enter("idle", "Idle", 0.0)


# ------------------------------------------------------------------ apoio
func _behind_close() -> bool:
	if not _has_target():
		return false
	var to := _to_target()
	return (global_basis.inverse() * to).z > 0.3 and to.length() < TAIL_REACH - 0.3


