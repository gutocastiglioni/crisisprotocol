class_name Soldier
extends Enemy
## Guerrilheiro inimigo (humano encapuzado com M16). Percepção, patrulha e alarme vêm de Enemy (o alarme também chama os raptors, e o
## grito de um raptor chama os soldados). Ao vê-la, ergue a arma ("alert", um instante para reagir) e entra em
## combate ("engage"): mira nela, atira em rajadas de tiro instantâneo (acerta menos de longe, se ela está agachada ou
## correndo; rolar esquiva) e se mexe: avança se está longe, recua se ela chega perto e anda de lado no resto. Sem vê-la
## por LOSE_TIME vai ao último lugar onde a viu. Morre em ragdoll, como os alvos de treino.

signal killed
signal fired

# guerrilheiro encapuzado: o esqueleto e as animações da heroína, com corpo, capuz e textura próprios (art/build_guerrilla.py)
const BODY := preload("res://assets/characters/guerrilla.glb")
const ATLAS := preload("res://assets/characters/guerrilla_atlas.png")
const MAX_HEALTH := 60
const WEAPON := "m16"
const DAMAGE := 7
const FIRE_RANGE := 22.0  # alcance do tiro
const ENGAGE_DIST := 12.0  # mais longe que isto, avança
const KEEP_DIST := 5.0  # mais perto que isto, recua
const REACT_TIME := 0.7  # entre vê-la e o primeiro tiro
const BURST_SHOTS := [2, 4]
const SHOT_GAP := 0.11
const REST_TIME := [0.7, 1.5]
const STAGGER_TIME := 0.4
const COMBAT := ["alert", "engage", "hit"]
## Guardas do galpão: onde começam e a rota (pontos em chão livre, fora da vista de quem começa o jogo).
const GUARDS := [
	{"route": [Vector3(-9, 0, -10), Vector3(-9, 0, -2), Vector3(-7.5, 0, -6.5)]},
	{"route": [Vector3(10.5, 0, -2), Vector3(10.5, 0, -11), Vector3(5.5, 0, -9.5)]},
]

var model: HeroineModel
var health := MAX_HEALTH
var _shape: CollisionShape3D
var _burst := 0
var _shot_t := 0.0
var _rest := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var shots_fired := 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.72
	_shape.shape = cap
	_shape.position.y = 0.86
	add_child(_shape)
	model = HeroineModel.new()
	model.scene = BODY
	model.atlas = ATLAS
	add_child(model)
	model.set_weapon(WEAPON)
	sight_range = 16.0
	fov_half = deg_to_rad(62.0)
	eye_height = 1.55
	marker_height = 2.2
	turn_rate = 8.0
	patrol_speed = Moves.speed("walk")
	investigate_speed = 1.8
	hunt_speed = Player.RUN_SPEED
	head_mult = 10.0  # tiro na cabeça mata na hora (até chumbo de escopeta de longe)
	_enemy_ready()


func _physics_process(delta: float) -> void:
	_tick(delta)
	if not _calm_state(delta):
		match state:
			"alert":
				_stop(delta)
				_face(_to_target(), delta, turn_rate)
				if _t >= REACT_TIME:
					start_engage()
			"engage":
				_engage(delta)
			"hit":
				_stop(delta)
				if _t >= STAGGER_TIME:
					start_engage()
			"dead":
				_stop(delta)
	move_and_slide()


func in_combat() -> bool:
	return state in COMBAT


## Nomes de animação do raptor ("Idle", "Walk", "Run", "Study") traduzidos para os estados do corpo dela.
func _play(anim: String, _blend := 0.15, speed := 1.0, _restart := false) -> void:
	model.set_aim(in_combat())
	match anim:
		"Walk":
			model.set_state("walk", speed)
		"Run":
			model.set_state("run", speed)
		_:
			model.set_state("idle")


func _anim_speed(run: bool) -> float:
	return Player.RUN_SPEED if run else Moves.speed("walk")


func _on_spotted() -> void:
	start_alert()


func start_alert() -> void:
	_enter("alert", "Idle", 0.1)
	model.set_aim(true)


func start_engage() -> void:
	if not _has_target():
		_resume()
		return
	_enter("engage", "Idle", 0.1)
	model.set_aim(true)
	_burst = 0
	_rest = 0.2
	_strafe_t = 0.0


## Combate: mira, atira em rajadas e se mexe (avança, recua ou anda de lado).
func _engage(delta: float) -> void:
	if not _has_target():
		_resume()
		return
	if _lost_t > LOSE_TIME:
		alert_t = ALERT_TIME
		start_hunt(_last_known)
		return
	var to := _to_target()
	var dist := to.length()
	var sees := _lost_t < 0.4
	_face(to if sees else _last_known - global_position, delta, turn_rate)
	var dir := Vector3.ZERO
	var gait := "walk"
	if not sees:
		# sumiu de vista: vai até onde a viu, pelo caminho
		var goal := _flat(_last_known - global_position)
		if goal.length() > 1.0:
			dir = _steer(_last_known, goal, delta)
	elif dist > ENGAGE_DIST:
		dir = _avoid(to.normalized())
	elif dist < KEEP_DIST:
		dir = _avoid(-to.normalized())
	else:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe = 1.0 if rng.randf() < 0.5 else -1.0
			_strafe_t = rng.randf_range(1.2, 2.6)
		dir = to.normalized().cross(Vector3.UP) * _strafe
		gait = "strafe"
		if not _free(global_position + Vector3.UP * 0.6, dir):
			_strafe = -_strafe
			dir = Vector3.ZERO
	_move_aiming(dir, gait, delta)
	# tiro: rajada de 2 a 4 e descanso, só com ela à vista e a arma já apontada
	if not sees or not model.is_aimed():
		return
	_shot_t -= delta
	if _rest > 0.0:
		_rest -= delta
	elif _burst > 0:
		if _shot_t <= 0.0:
			_fire()
			_burst -= 1
			_shot_t = SHOT_GAP
			if _burst == 0:
				_rest = rng.randf_range(REST_TIME[0], REST_TIME[1])
	elif dist < FIRE_RANGE:
		_burst = rng.randi_range(BURST_SHOTS[0], BURST_SHOTS[1])


## Anda na direção `dir` sem virar o corpo (continua mirando): para a frente/de costas ou de lado, no ritmo da animação.
func _move_aiming(dir: Vector3, gait: String, _delta: float) -> void:
	if dir.length() < 0.1:
		velocity.x = 0.0
		velocity.z = 0.0
		model.set_state("idle")
		return
	var speed := Moves.speed(gait)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	var local := global_basis.inverse() * dir
	if absf(local.x) > absf(local.z):
		model.set_state("strafe_r" if local.x > 0.0 else "strafe_l", speed / Moves.speed("strafe"))
	else:
		model.set_state("walk", (1.0 if local.z < 0.0 else -1.0) * speed / Moves.speed("walk"))


## Um tiro nela: acerta com chance que cai com a distância, se ela está agachada ou correndo; rolando, nunca.
## Sem linha livre o tiro bate na parede.
func _fire() -> void:
	shots_fired += 1
	model.shoot()
	var parent := get_parent()
	var muzzle := model.muzzle_position()
	var chest := target.global_position + Vector3.UP * (0.8 if target.crouching else 1.2)
	var dir := (chest - muzzle).normalized()
	Fx.muzzle_flash(parent, muzzle, WEAPON, dir)
	var space := get_world_3d().direct_space_state
	var block := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1))
	var dist := muzzle.distance_to(chest)
	var chance := clampf(0.8 - dist * 0.03, 0.15, 0.7)
	if target.crouching:
		chance *= 0.8
	if Vector2(target.velocity.x, target.velocity.z).length() > 3.0:
		chance *= 0.7
	if target.is_dodging():
		chance = 0.0
	var end := chest
	var hit_her := false
	if block:
		end = block.position
		Fx.impact(parent, end, false, block.normal, str(block.collider.get_meta("surface", "concrete")))
	elif rng.randf() < chance:
		hit_her = true
	else:
		# errou: o tiro passa raspando e vai até o que houver atrás
		var side := dir.cross(Vector3.UP).normalized() * rng.randf_range(-1.0, 1.0)
		var miss := (chest + side * 0.9 + Vector3.UP * rng.randf_range(-0.4, 0.4) - muzzle).normalized()
		var far := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, muzzle + miss * FIRE_RANGE * 1.5, 1))
		end = far.position if far else muzzle + miss * FIRE_RANGE
		if far:
			Fx.impact(parent, end, false, far.normal, str(far.collider.get_meta("surface", "concrete")))
	Fx.tracer(parent, muzzle, end, WEAPON)
	if hit_her:
		target.take_hit(DAMAGE, dir, chest)  # o sangue sai no take_hit dela
	fired.emit()


# ------------------------------------------------------------------ dano
func take_hit(amount: int, dir: Vector3, at: Vector3, head := false) -> void:
	if dead:
		return
	health -= amount
	if health <= 0:
		die(dir, at, head)
		return
	if not in_combat() and _has_target():
		_raise_alarm()  # levou tiro sem tê-la notado: já sabe onde ela está e avisa os outros
	model.hit()
	_enter("hit", "Idle", 0.05)
	model.set_aim(true)


## Tiro na cabeça de um humano é letal, qualquer arma e distância (a queda de dano com o alcance não salva ninguém).
func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(maxi(amount, health), dir, at, true)


func wound() -> float:
	return 1.0 - float(maxi(health, 0)) / MAX_HEALTH


## Cai em ragdoll na direção do tiro (na cabeça, o tranco vai nela e joga a cabeça para trás); a poça cresce embaixo.
func die(dir := Vector3.ZERO, at: Variant = null, head := false) -> void:
	dead = true
	state = "dead"
	_t = 0.0
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	model.start_ragdoll(dir.normalized() * (20.0 if head else 14.0) + Vector3.UP * 2.5, at)
	Blood.pool(model.ragdoll.bodies["Chest"], 1.1)
	if head:
		Blood.pool(model.ragdoll.bodies["Head"], 0.6, Blood.POOL_DELAY + 0.4)
	_update_marker()
	killed.emit()


func reset() -> void:
	model.stop_ragdoll()
	model.set_weapon(WEAPON)
	_reset_enemy()
	health = MAX_HEALTH
	collision_layer = 2
	_shape.set_deferred("disabled", false)
	_burst = 0
	_enter("idle", "Idle", 0.0)
