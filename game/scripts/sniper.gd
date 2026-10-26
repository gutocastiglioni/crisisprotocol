class_name Sniper
extends Enemy
## Inimigo Guerrilheiro Sniper (atirador de elite encapuzado com fuzil de precisão).
## Fica posicionado em área suspensa (passarela / mezanino) nas costas da heroína.
## Ao avistar a heroína, aciona uma mira laser vermelha visível projetada no alvo,
## trava a mira (telegrafando o tiro para a jogadora poder se esquivar ou se abrigar)
## e dispara tiros de altíssimo impacto (sniper_shot).
## Se a heroína subir a escada silenciosamente pelas costas, pode executá-lo em abate furtivo.

signal killed
signal fired

const BODY := preload("res://assets/characters/guerrilla.glb")
const ATLAS := preload("res://assets/characters/guerrilla_atlas.png")
const MAX_HEALTH := 70
const WEAPON := "sniper"
const DAMAGE := 38
const FIRE_RANGE := 35.0
const AIM_LOCK_TIME := 1.25  # tempo de mira com laser vermelho antes do disparo
const COOLDOWN_TIME := 2.2   # intervalo de recarga do ferrolho entre disparos
const STAGGER_TIME := 0.4
const COMBAT := ["alert", "aim_lock", "cooldown", "hit"]
const SEES_GRACE := 0.3  # sem vê-la por mais que isto, a mira não avança nem dispara
const BLIND_SPOT_Z := 0.0  # metade da sala (z > 0 = início da sala no chão, protegido pelo mezanino)

var model: HeroineModel
var health := MAX_HEALTH
var _shape: CollisionShape3D
var laser_mesh: MeshInstance3D
var laser_mat: StandardMaterial3D
var shots_fired := 0
var aim_progress := 0.0
var _cooldown_t := 0.0
var loot: KeyItem


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
	
	_setup_laser()
	
	# Percepção de atirador de elite no alto
	# Ponto cego para baixo: não enxerga o início da sala (z > BLIND_SPOT_Z) no chão abaixo do mezanino.
	# Ao avançar da metade da sala para a frente (z <= 0), ela entra no campo de visão e alcance de tiro (35m)
	sight_range = 26.0
	fov_half = deg_to_rad(70.0)
	eye_height = 1.55
	marker_height = 2.2
	turn_rate = 6.0
	patrol_speed = Moves.speed("walk")
	investigate_speed = 1.6
	hunt_speed = Player.RUN_SPEED
	head_mult = 10.0  # tiro na cabeça é fatal
	can_stealth = true
	drop_kind = "sniper"
	drop_is_weapon = true
	drop_amount = 5
	drop_chance = 1.0
	arrival_dist = 0.5
	search_sweeps = 0
	_enemy_ready()


func _setup_laser() -> void:
	laser_mat = StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.75)
	laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	laser_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	laser_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.015, 0.015, 1.0)
	laser_mesh.mesh = box
	laser_mesh.material_override = laser_mat
	laser_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser_mesh.visible = false
	add_child(laser_mesh)


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
				_face(_to_target(), delta, turn_rate * 2.0)
				_update_pitch(delta)
				if _t >= 0.25:
					start_aim_lock()
			"aim_lock":
				_aim_lock_process(delta)
			"cooldown":
				_cooldown_process(delta)
			"hit":
				_stop(delta)
				_hide_laser()
				if _t >= STAGGER_TIME:
					start_aim_lock()
			"dead":
				_stop(delta)
				_hide_laser()
	else:
		_hide_laser()
		if state == "patrol":
			if velocity.x > 0.05:
				_vigil_target_yaw = -0.65
				_vigil_target_pitch = -0.15
			elif velocity.x < -0.05:
				_vigil_target_yaw = 0.65
				_vigil_target_pitch = -0.15
			head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.5 * delta))
			head_pitch = lerpf(head_pitch, _vigil_target_pitch, 1.0 - exp(-3.5 * delta))
			if model:
				model.set_head_look(head_yaw, head_pitch)
		elif state in ["look", "idle"]:
			rotation.y = lerp_angle(rotation.y, 0.0, 1.0 - exp(-4.0 * delta))
			_vigil_t -= delta
			if _vigil_t <= 0.0:
				_vigil_t = rng.randf_range(1.8, 3.2)
				var r := rng.randf()
				if r < 0.35:
					_vigil_target_yaw = 0.0
				elif r < 0.68:
					_vigil_target_yaw = rng.randf_range(0.45, 0.85)
				else:
					_vigil_target_yaw = rng.randf_range(-0.85, -0.45)
				_vigil_target_pitch = rng.randf_range(-0.12, -0.22)
			head_yaw = lerpf(head_yaw, _vigil_target_yaw, 1.0 - exp(-3.5 * delta))
			head_pitch = lerpf(head_pitch, _vigil_target_pitch, 1.0 - exp(-3.5 * delta))
			if model:
				model.set_head_look(head_yaw, head_pitch)
		else:
			head_yaw = lerpf(head_yaw, 0.0, 1.0 - exp(-5.0 * delta))
			head_pitch = lerpf(head_pitch, 0.0, 1.0 - exp(-5.0 * delta))
			if model:
				model.set_head_look(head_yaw, head_pitch)
	EnemyCrowd.apply_separation(self)
	move_and_slide()
	if not dead:
		_clamp_to_catwalk()


func in_combat() -> bool:
	return state in COMBAT


## Sensor de perigo: com o laser nela, sobe junto com a mira até o disparo (que não erra quem não esquiva); recarregando
## o ferrolho ou sem vê-la, pouco.
func _threat() -> float:
	if state == "aim_lock" and _lost_t <= SEES_GRACE:
		return 0.35 + 0.65 * clampf(aim_progress / AIM_LOCK_TIME, 0.0, 1.0)
	return 0.25 if _lost_t <= SEES_GRACE else 0.05


func _play(anim: String, _blend := 0.15, speed := 1.0, _restart := false) -> void:
	if not model:
		return
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


func _sees_target() -> bool:
	if not _has_target():
		return false
	# Ponto cego para baixo: se a heroína estiver no chão no início da sala (z > BLIND_SPOT_Z),
	# a estrutura do mezanino e o ângulo para baixo bloqueiam a visão do sniper.
	# Ele só a enxerga quando ela avança da metade da sala para a frente (z <= BLIND_SPOT_Z)
	# ou se ele já foi alertado (tiro, explosão ou alarme).
	if alert_t <= 0.0 and target.global_position.y < Catwalk.FLOOR_Y - 0.4 and target.global_position.z > BLIND_SPOT_Z:
		return false
	return super._sees_target()


func start_hunt(at: Vector3) -> void:
	# Atirador no mezanino: se tiver linha de visada para o alvo ao ser alertado, mira imediatamente
	if _has_target() and _sees_target():
		start_alert()
		return
	var goal := _catwalk_point(at)
	if at.y < Catwalk.FLOOR_Y - 0.4:
		# Alvo no chão: o sniper nunca desce da passarela à procura do inimigo
		if _flat(global_position - goal).length() > 0.8:
			_goal = goal
			_path = PackedVector3Array()
			_repath_t = 0.0
			_enter("hunt", "Run", 0.2)
		else:
			start_search()
		return
	super.start_hunt(goal)


func start_investigate(at: Vector3) -> void:
	if _has_target() and _sees_target():
		start_alert()
		return
	var goal := _catwalk_point(at)
	if at.y < Catwalk.FLOOR_Y - 0.4:
		# Barulho no chão: investiga da passarela sem descer
		if _flat(global_position - goal).length() > 0.8:
			_goal = goal
			_path = PackedVector3Array()
			_repath_t = 0.0
			_enter("investigate", "Walk", 0.3)
		else:
			start_search()
		return
	super.start_investigate(goal)


## Preso à passarela: procura no próprio ponto dela (sem varrer pontos do chão nem da malha de outro andar).
func _search_goal(at: Vector3) -> Vector3:
	return at


## No mezanino (faixa reta, sem malha de navegação própria) anda reto até o ponto: a malha mais próxima é a de outro
## andar (topo das caixas do labirinto, telhado) e o caminho dela o levava para a quina.
func _steer(_goal: Vector3, to: Vector3, _delta: float) -> Vector3:
	return to.normalized()


## Ponto de navegação restrito estritamente à passarela/mezanino
func _catwalk_point(pos: Vector3) -> Vector3:
	var cx := clampf(pos.x, -3.8, 1.0)
	var cz := clampf(pos.z, Catwalk.FRONT_Z + 0.5, Catwalk.WALL_Z - 0.5)
	return Vector3(cx, Catwalk.FLOOR_Y, cz)


## Trava física: o Sniper nunca sai nem cai da passarela enquanto vivo
func _clamp_to_catwalk() -> void:
	global_position.x = clampf(global_position.x, -4.6, 1.2)
	global_position.z = clampf(global_position.z, Catwalk.FRONT_Z + 0.3, Catwalk.WALL_Z - 0.3)
	if absf(global_position.y - Catwalk.FLOOR_Y) < 0.25 or global_position.y < Catwalk.FLOOR_Y:
		global_position.y = Catwalk.FLOOR_Y
		velocity.y = 0.0


func _on_spotted() -> void:
	start_alert()


func start_alert() -> void:
	_enter("alert", "Idle", 0.1)
	if model:
		model.set_aim(true)
	_hide_laser()


func start_aim_lock() -> void:
	if not _has_target() or dead:
		_resume()
		_hide_laser()
		return
	# não zera `_lost_t`: quem diz se ele a vê é `_track_target` (antes cada ciclo mira/recarga zerava e ele nunca a perdia)
	_enter("aim_lock", "Idle", 0.1)
	if model:
		model.set_aim(true)
	aim_progress = 0.0
	_show_laser()


func _aim_lock_process(delta: float) -> void:
	if not _has_target() or dead:
		_resume()
		_hide_laser()
		return
	if _lost_t > LOSE_TIME:
		_lose_target()
		return
	velocity.x = 0.0
	velocity.z = 0.0
	if _lost_t > SEES_GRACE:
		# sumiu atrás de algo: o laser apaga e a mira esfria; olha para onde a viu por último (não sabe onde ela está)
		_hide_laser()
		aim_progress = maxf(aim_progress - delta * 2.0, 0.0)
		_face(_last_known - global_position, delta, turn_rate)
		return
	
	var to: Vector3 = _to_target()
	_face(to, delta, turn_rate * 1.5)  # mira firme e focada
	_update_pitch(delta)
	
	aim_progress += delta
	_update_laser(to)
	
	# Laser pulsa e brilha mais forte conforme o tiro se aproxima
	if laser_mat:
		var pulse: float = clampf(aim_progress / AIM_LOCK_TIME, 0.0, 1.0)
		laser_mat.albedo_color = Color(1.0, 0.1 + pulse * 0.2, 0.1, 0.5 + pulse * 0.5)
	
	if aim_progress >= AIM_LOCK_TIME:
		_fire_sniper()


func _cooldown_process(delta: float) -> void:
	_hide_laser()
	if not _has_target():
		_resume()
		return
	if _lost_t > LOSE_TIME:
		_lose_target()
		return
	var to: Vector3 = _to_target() if _lost_t <= SEES_GRACE else _flat(_last_known - global_position)
	_face(to, delta, turn_rate * 1.0)
	_update_pitch(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	
	_cooldown_t -= delta
	if _cooldown_t <= 0.0:
		start_aim_lock()


## Sem vê-la por LOSE_TIME: sai do combate e vai procurar na passarela onde a viu por último; sem achar, esquece.
func _lose_target() -> void:
	_hide_laser()
	alert_t = ALERT_TIME
	start_hunt(_last_known)


func _update_pitch(delta: float) -> void:
	if not model or not model.aim_pitch or not _has_target():
		return
	var eye_y := global_position.y + eye_height
	var target_y := target.global_position.y + (0.8 if target.crouching else 1.2)
	var horiz_d := _to_target().length()
	if horiz_d > 0.1:
		var target_pitch := atan2(target_y - eye_y, horiz_d)
		model.aim_pitch.pitch = lerpf(model.aim_pitch.pitch, target_pitch, 1.0 - exp(-10.0 * delta))


func _update_laser(_to: Vector3) -> void:
	if not model or not laser_mesh:
		return
	var muzzle: Vector3 = model.muzzle_position()
	var chest: Vector3 = target.global_position + Vector3.UP * (0.8 if target.crouching else 1.2)
	
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var block: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1))
	var end: Vector3 = (block.position as Vector3) if not block.is_empty() else chest
	
	var beam_vec: Vector3 = end - muzzle
	var dist: float = beam_vec.length()
	if dist < 0.1:
		_hide_laser()
		return
	
	laser_mesh.visible = true
	laser_mesh.global_position = muzzle + beam_vec * 0.5
	
	var fwd: Vector3 = beam_vec.normalized()
	var up: Vector3 = Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD
	var right: Vector3 = fwd.cross(up).normalized()
	up = right.cross(fwd).normalized()
	laser_mesh.global_basis = Basis(right, up, fwd).scaled(Vector3(1.0, 1.0, dist))


func _show_laser() -> void:
	if laser_mesh:
		laser_mesh.visible = true


func _hide_laser() -> void:
	if laser_mesh:
		laser_mesh.visible = false


## Disparo potente de fuzil de precisão
func _fire_sniper() -> void:
	shots_fired += 1
	if model:
		model.shoot()
	_hide_laser()
	
	var parent: Node = get_parent()
	var muzzle: Vector3 = model.muzzle_position() if model else global_position + Vector3.UP * 1.3
	var chest: Vector3 = target.global_position + Vector3.UP * (0.8 if target.crouching else 1.2)
	var dir: Vector3 = (chest - muzzle).normalized()
	
	Fx.muzzle_flash(parent, muzzle, WEAPON, dir)
	
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var block: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1))
	
	var hit_her := false
	var end: Vector3 = (block.position as Vector3) if not block.is_empty() else chest
	
	# Se a jogadora estiver em esquiva/rolamento ou atrás de obstáculo, o tiro erra
	if not block.is_empty():
		end = block.position
		Fx.impact(parent, end, false, block.normal, str((block.collider as Node).get_meta("surface", "concrete")))
	elif target.is_dodging():
		# Erra por pouco
		var miss_dir: Vector3 = dir + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.15, 0.15))
		var far: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, muzzle + miss_dir * FIRE_RANGE * 1.5, 1))
		end = far.position if not far.is_empty() else muzzle + miss_dir * FIRE_RANGE
		if not far.is_empty():
			Fx.impact(parent, end, false, far.normal, str((far.collider as Node).get_meta("surface", "concrete")))
	else:
		hit_her = true
	
	Fx.tracer(parent, muzzle, end, WEAPON)
	
	if hit_her:
		target.take_hit(GameMode.enemy_damage(DAMAGE), dir, chest)
	
	fired.emit()
	
	# Entra no estado de recarga de ferrolho / cooldown
	_enter("cooldown", "Idle", 0.1)
	_cooldown_t = COOLDOWN_TIME


func take_hit(amount: int, dir: Vector3, at: Vector3, head := false) -> void:
	if dead:
		return
	health -= amount
	_hide_laser()
	if health <= 0:
		die(dir, at, head)
		return
	if not in_combat() and _has_target():
		_raise_alarm()
	if model:
		model.hit(dir)
		model.set_aim(true)
	_enter("hit", "Idle", 0.05)


func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(maxi(amount, health), dir, at, true)


func assassinate(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	stealth_lock(false)
	_hide_laser()
	health = 0
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.3
	var d := dir.normalized() if dir.length() > 0.01 else -global_basis.z
	Blood.splash(get_parent(), hit, d, -d, 1.2, true)
	die(d, hit, false, true)


func die(dir := Vector3.ZERO, at: Variant = null, head := false, silent := false) -> void:
	dead = true
	state = "dead"
	_t = 0.0
	_hide_laser()
	collision_layer = 0
	_shape.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	if drop_is_weapon and model:
		model.holster(true)
	drop_loot()
	if loot:
		loot.drop(global_position + Vector3.UP * 1.1)
	if model:
		model.start_ragdoll(dir.normalized() * (22.0 if head else 15.0) + Vector3.UP * 2.8, at)
		if model.ragdoll and model.ragdoll.bodies.has("Chest"):
			Blood.pool(model.ragdoll.bodies["Chest"], 1.1)
		if head and model.ragdoll and model.ragdoll.bodies.has("Head"):
			Blood.pool(model.ragdoll.bodies["Head"], 0.6, Blood.POOL_DELAY + 0.4)
	if not silent and is_inside_tree():
		get_tree().call_group("enemies", "hear_noise", global_position, 6.0, 1.2)
	if is_inside_tree():
		get_tree().call_group("enemies", "on_nearby_kill", global_position, 8.0)
	_update_marker()
	killed.emit()


func reset() -> void:
	if model:
		model.stop_ragdoll()
		model.set_weapon(WEAPON)
		model.holster(false)
		model.set_head_look(0.0, 0.0)
	head_yaw = 0.0
	head_pitch = 0.0
	_reset_enemy()
	health = MAX_HEALTH
	collision_layer = 2
	_shape.set_deferred("disabled", false)
	_hide_laser()
	_enter("idle", "Idle", 0.0)

func has_head_look() -> bool:
	return true
