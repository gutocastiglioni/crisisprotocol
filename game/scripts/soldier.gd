class_name Soldier
extends Enemy
## Guerrilheiro inimigo (humano encapuzado com M16). Percepção, patrulha e alarme vêm de Enemy (o alarme também chama os raptors, e o
## grito de um raptor chama os soldados). Ao vê-la, ergue a arma ("alert", um instante para reagir) e entra em
## combate ("engage"): mira nela, atira em rajadas longas de tiro instantâneo com descanso curto (acerta menos de longe,
## se ela está agachada ou correndo, e cada tiro da rajada sobe mais que o anterior; rolar esquiva) e se mexe: avança se
## está longe, recua se ela chega perto e anda de lado no resto. Ela some atrás de algo: ainda despeja SUPPRESS_TIME de
## tiros onde ela estava (batem na cobertura). Sem vê-la por LOSE_TIME vai ao último lugar onde a viu. Morre em ragdoll, como os alvos de treino.

signal killed
signal fired

# guerrilheiro encapuzado: o esqueleto e as animações da heroína, com corpo, capuz e textura próprios (art/build_guerrilla.py)
const BODY := preload("res://assets/characters/guerrilla.glb")
const ATLAS := preload("res://assets/characters/guerrilla_atlas.png")
const MAX_HEALTH := 60
const WEAPON := "m16"
const DAMAGE := 7
const FIRE_RANGE := 22.0  # alcance do tiro
const ENGAGE_DIST := 10.0  # mais longe que isto, avança
const KEEP_DIST := 5.0  # mais perto que isto, recua
const REACT_TIME := 0.45  # entre vê-la e o primeiro tiro
const BURST_SHOTS := [4, 7]
const SHOT_GAP := 0.1
const REST_TIME := [0.3, 0.7]
const BURST_DECAY := 0.8  # chance de acerto de cada tiro da rajada = a do anterior vezes isto (o cano sobe)
const SUPPRESS_TIME := 1.2  # depois de perdê-la de vista, continua atirando onde ela estava por este tempo
const STAGGER_TIME := 0.4
const COMBAT := ["alert", "engage", "hit"]
## Guardas do galpão/pátio:
## - 1 vasculhando a ala oeste do galpão em ronda
## - 1 fazendo ronda na ala leste/fundo
## - 1 parado de sentinela à direita do baú da M16 no canto superior direito
## - 2 parados de sentinela guardando o portão da primeira fase
## - 4 de posto ("hold" = `Enemy.hold_post`: só saem do lugar depois que alguém a vê) guardando a porta do pátio dos
##   raptors, atrás das paredes de caixas (`Level.DIVIDERS`): no vão do sul, no vão do leste, no canto do fundo e na quina
const GUARDS := [
	{"route": [Vector3(-8.5, 0, -10.5), Vector3(-8.5, 0, -2.5), Vector3(-7.0, 0, -6.5)]},
	{"route": [Vector3(10.5, 0, -2), Vector3(10.5, 0, -9.0), Vector3(5.5, 0, -9.0)]},
	{"pos": Vector3(11.5, 0, -11.4), "rot_y": PI, "route": []},
	{"pos": Vector3(-11.4, 0, -6.6), "rot_y": -PI * 0.5, "route": []},
	{"pos": Vector3(-11.4, 0, -10.4), "rot_y": -PI * 0.5, "route": []},
	{"pos": Vector3(-9.6, 0, -2.2), "rot_y": -2.7, "route": [], "hold": true},
	{"pos": Vector3(-6.0, 0, -8.4), "rot_y": -PI * 0.5, "route": [], "hold": true},
	{"pos": Vector3(-8.2, 0, -12.0), "rot_y": -2.0, "route": [], "hold": true},
	{"pos": Vector3(-5.6, 0, -1.6), "rot_y": -2.74, "route": [], "hold": true},
]

var model: HeroineModel
var health := MAX_HEALTH
var _shape: CollisionShape3D
var _burst := 0
var _burst_i := 0  # tiros já dados na rajada
var _shot_t := 0.0
var _rest := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var shots_fired := 0
var engage_dist := ENGAGE_DIST
var keep_dist := KEEP_DIST


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
	if drop_kind == "":
		drop_kind = "m16"
		drop_is_weapon = true
		drop_amount = 15
	head_mult = 10.0  # tiro na cabeça mata na hora (até chumbo de escopeta de longe)
	can_stealth = true
	arrival_dist = 0.7
	# gente procura com calma: só os 2 mais perto saem quando um dá o alarme, andando, e vasculham mais pontos
	alarm_responders = 2
	alarm_walks = true
	search_sweeps = 3
	engage_dist = ENGAGE_DIST + rng.randf_range(-1.0, 1.0)
	keep_dist = KEEP_DIST + rng.randf_range(-0.4, 0.4)
	_enemy_ready()


func _physics_process(delta: float) -> void:
	_tick(delta)
	if not _calm_state(delta):
		head_yaw = 0.0
		head_pitch = 0.0
		if model:
			model.set_head_look(0.0, 0.0)
		match state:
			"alert":
				_stop(delta)
				_face(_to_target(), delta, turn_rate)
				_update_pitch(delta)
				if _t >= REACT_TIME:
					start_engage()
			"engage":
				_engage(delta)
			"hit":
				_stop(delta)
				_update_pitch(delta)
				if _t >= STAGGER_TIME:
					start_engage()
			"dead":
				_stop(delta)
	else:
		if state == "patrol":
			head_yaw = lerpf(head_yaw, 0.0, 1.0 - exp(-5.0 * delta))
			if model:
				model.set_head_look(head_yaw, 0.0)
		elif state in ["look", "idle", "search"]:
			if model:
				model.set_head_look(head_yaw, head_pitch)
	if not in_combat() and model and model.aim_pitch and absf(model.aim_pitch.pitch) > 0.01:
		model.aim_pitch.pitch = lerpf(model.aim_pitch.pitch, 0.0, 1.0 - exp(-6.0 * delta))
	
	if in_combat() and _is_target_elevated() and global_position.y < 1.2 and global_position.x > -12.6 and global_position.z >= Catwalk.FRONT_Z - 1.2:
		if velocity.z > 0.0:
			velocity.z = 0.0
	EnemyCrowd.apply_separation(self)
	move_and_slide()
	if not dead:
		_clamp_to_bounds()


## Trava física: soldados no chão nunca saem do mapa nem caem no vácuo; em combate com ela no mezanino não entram
## debaixo dele (perderiam a linha de tiro). Procurando, entram (corredor e pé da escada).
func _clamp_to_bounds() -> void:
	if global_position.y < 1.2:
		global_position.y = maxf(global_position.y, 0.0)
		if velocity.y < 0.0 and global_position.y <= 0.01:
			velocity.y = 0.0
		if global_position.x > -12.6:
			global_position.x = clampf(global_position.x, -12.4, 12.4)
			var max_z := Catwalk.FRONT_Z - 1.0 if in_combat() and _is_target_elevated() else 12.4
			global_position.z = clampf(global_position.z, -12.4, max_z)


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
	_rest = 0.1
	_strafe_t = 0.0


func _is_target_elevated() -> bool:
	if is_instance_valid(target):
		if target.global_position.y > 1.8 and target.global_position.z >= Catwalk.FRONT_Z - 0.5:
			return true
	return _last_known.y > 1.8 and _last_known.z >= Catwalk.FRONT_Z - 0.5


func _update_pitch(delta: float) -> void:
	if not model or not model.aim_pitch or not _has_target():
		return
	var eye_y := global_position.y + eye_height
	var target_y := target.global_position.y + (0.8 if target.crouching else 1.2)
	var horiz_d := _to_target().length()
	if horiz_d > 0.1:
		var target_pitch := atan2(target_y - eye_y, horiz_d)
		model.aim_pitch.pitch = lerpf(model.aim_pitch.pitch, target_pitch, 1.0 - exp(-10.0 * delta))


## Ela no mezanino ou em cima das caixas: Enemy._search_goal manda um ao pé da escada e os outros a pontos do chão de
## onde se vê o lugar.
func start_hunt(at: Vector3) -> void:
	if _has_target() and _sees_target():
		start_alert()
		return
	super.start_hunt(at)


func start_investigate(at: Vector3) -> void:
	if _has_target() and _sees_target():
		start_alert()
		return
	super.start_investigate(at)


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
	_update_pitch(delta)
	var dir := Vector3.ZERO
	var gait := "walk"
	var elevated := _is_target_elevated()
	if elevated and global_position.y < 1.2:
		# Alvo elevado (na passarela / mezanino): manter campo de visão aberto
		if not sees:
			# Perdeu de vista: se estiver perto da passarela, recua para abrir o ângulo de visada;
			# caso contrário, anda de lado e recua suavemente para tentar novo ângulo desobstruído
			if global_position.z > 5.0:
				dir = Vector3(0, 0, -1.0)
				gait = "walk"
			else:
				_strafe_t -= delta
				if _strafe_t <= 0.0:
					_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
					_strafe_t = rng.randf_range(1.0, 2.2)
				dir = (to.normalized().cross(Vector3.UP) * _strafe - Vector3(0, 0, 0.3)).normalized()
				gait = "strafe"
				if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
					_strafe = -_strafe
					dir = Vector3(0, 0, -1.0)
		elif global_position.z > 6.0:
			# Perto demais do mezanino: a borda frontal/rodapé cortará a linha de tiro; recua
			dir = Vector3(0, 0, -1.0)
			gait = "walk"
		elif global_position.z < 1.0 and dist > 14.0:
			# Longe demais para tiro preciso: avança um pouco até a zona ideal de combate
			dir = Vector3(0, 0, 1.0)
			gait = "walk"
		else:
			# Posição ideal com visão desobstruída do mezanino: anda de lado atirando
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
				_strafe_t = rng.randf_range(1.2, 2.6)
			dir = to.normalized().cross(Vector3.UP) * _strafe
			gait = "strafe"
			if dir.z > 0.0 and global_position.z >= 5.2:
				dir.z = 0.0
			if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
				_strafe = -_strafe
				dir = Vector3.ZERO
	else:
		if not sees:
			# sumiu de vista: vai até onde a viu, pelo caminho
			var goal := _flat(_last_known - global_position)
			if goal.length() > 1.0:
				dir = _steer(_last_known, goal, delta)
		elif dist > engage_dist:
			dir = _avoid(to.normalized())
		elif dist < keep_dist:
			dir = _avoid(-to.normalized())
		else:
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe = EnemyCrowd.get_flank_strafe(self, target.global_position, 1.0 if rng.randf() < 0.5 else -1.0)
				_strafe_t = rng.randf_range(1.2, 2.6)
			dir = to.normalized().cross(Vector3.UP) * _strafe
			gait = "strafe"
			if not _free(global_position + Vector3.UP * 0.6, dir) or EnemyCrowd.is_enemy_in_path(self, dir, 1.4):
				_strafe = -_strafe
				dir = Vector3.ZERO
	_move_aiming(dir, gait, delta)
	# tiro: rajadas longas e descanso curto com ela à vista; recém-sumida, fogo de supressão onde ela estava
	_shot_t -= delta
	_rest = maxf(_rest - delta, 0.0)
	var suppress := not sees and _lost_t < SUPPRESS_TIME
	if not (sees or suppress) or not model.is_aimed() or _rest > 0.0:
		return
	if _burst == 0:
		var reach := dist if sees else _flat(_last_known - global_position).length()
		if reach >= FIRE_RANGE:
			return
		_burst = rng.randi_range(BURST_SHOTS[0], BURST_SHOTS[1])
		_burst_i = 0
	if _shot_t <= 0.0:
		_fire(sees)
		_burst -= 1
		_burst_i += 1
		_shot_t = SHOT_GAP
		if _burst == 0:
			_rest = rng.randf_range(REST_TIME[0], REST_TIME[1])


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


## Um tiro nela: acerta com chance que cai com a distância, ao longo da rajada, se ela está agachada ou correndo;
## rolando, nunca. Sem linha livre o tiro bate na parede. `at_her` = false: supressão, atira no último lugar onde a
## viu (não acerta; bate na cobertura ou passa).
func _fire(at_her := true) -> void:
	shots_fired += 1
	model.shoot()
	var parent := get_parent()
	var muzzle := model.muzzle_position()
	var chest := target.global_position + Vector3.UP * (0.8 if target.crouching else 1.2)
	if not at_her:
		chest = _last_known + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.6, 1.3), rng.randf_range(-0.4, 0.4))
	var dir := (chest - muzzle).normalized()
	Fx.muzzle_flash(parent, muzzle, WEAPON, dir)
	var space := get_world_3d().direct_space_state
	var block := space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1))
	var dist := muzzle.distance_to(chest)
	var chance := clampf(0.8 - dist * 0.03, 0.15, 0.7) * pow(BURST_DECAY, _burst_i)
	if not at_her:
		chance = 0.0
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
		target.take_hit(GameMode.enemy_damage(DAMAGE), dir, chest)  # o sangue sai no take_hit dela
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
	model.hit(dir)
	_enter("hit", "Idle", 0.05)
	model.set_aim(true)


## Tiro na cabeça de um humano é letal, qualquer arma e distância (a queda de dano com o alcance não salva ninguém).
func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(maxi(amount, health), dir, at, true)


## Abate furtivo silencioso pelas costas: mata na hora (100% da vida), esguicha sangue e cai em ragdoll sem dar alarme.
func assassinate(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	stealth_lock(false)
	health = 0
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.3
	var d := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.splash(get_parent(), hit, d, -d, 1.2, true)
	die(d, hit, false, true)


func wound() -> float:
	return 1.0 - float(maxi(health, 0)) / MAX_HEALTH


## Cai em ragdoll na direção do tiro (na cabeça, o tranco vai nela e joga a cabeça para trás); a poça cresce embaixo.
func die(dir := Vector3.ZERO, at: Variant = null, head := false, silent := false) -> void:
	dead = true
	state = "dead"
	_t = 0.0
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if drop_is_weapon and model:
		model.holster(true)
	drop_loot()
	model.start_ragdoll(dir.normalized() * (20.0 if head else 14.0) + Vector3.UP * 2.5, at)
	Blood.pool(model.ragdoll.bodies["Chest"], 1.1)
	if head:
		Blood.pool(model.ragdoll.bodies["Head"], 0.6, Blood.POOL_DELAY + 0.4)
	if not silent and is_inside_tree():
		get_tree().call_group("enemies", "hear_noise", global_position, 6.0, 1.2)
	if is_inside_tree():
		get_tree().call_group("enemies", "on_nearby_kill", global_position, 8.0)
	_update_marker()
	killed.emit()


func reset() -> void:
	model.stop_ragdoll()
	model.set_weapon(WEAPON)
	model.holster(false)
	_reset_enemy()
	health = MAX_HEALTH
	engage_dist = ENGAGE_DIST + rng.randf_range(-1.0, 1.0)
	keep_dist = KEEP_DIST + rng.randf_range(-0.4, 0.4)
	collision_layer = 2
	_shape.set_deferred("disabled", false)
	_burst = 0
	_burst_i = 0
	if model and model.aim_pitch:
		model.aim_pitch.pitch = 0.0
	_enter("idle", "Idle", 0.0)

func has_head_look() -> bool:
	return true


func _idle_vigil(delta: float) -> void:
	_stop(delta)
	_play("Idle", 0.3)
	_vigil_t -= delta
	if _vigil_t <= 0.0:
		_vigil_t = rng.randf_range(2.0, 3.8)
		var r := rng.randf()
		_vigil_target_yaw = 0.0 if r < 0.3 else (rng.randf_range(0.5, 1.05) if r < 0.65 else rng.randf_range(-1.05, -0.5))
	head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.0 * delta))
	head_pitch = lerpf(head_pitch, 0.0, 1.0 - exp(-3.0 * delta))
	if model:
		model.set_head_look(head_yaw, head_pitch)
