class_name Sniper
extends Enemy
## Inimigo Guerrilheiro Sniper (atirador de elite encapuzado com fuzil de precisão).
## Fica posicionado em área suspensa (passarela / mezanino) nas costas da heroína.
## Ao avistar a heroína, aciona uma mira laser vermelha visível projetada no alvo,
## trava a mira (telegrafando o tiro para a jogadora poder se esquivar ou se abrigar)
## e dispara tiros de altíssimo impacto (sniper_shot).
## Se a heroína subir a escada silenciosamente pelas costas, pode executá-lo em abate furtivo.
## Outro posto (torres de guarda do pátio, GuardTower): `perch` = retângulo XZ da plataforma, `floor_y` = piso dela e
## `home_yaw` = para onde vigia; vazio = o mezanino do galpão. `lurk`/`appear`: fora de cena até a hora (o main os põe
## nas torres quando os raptors da emboscada morrem). `falls`: ao morrer amolece encostado no guarda-corpo (`ledge`, o alto
## da barra), se debruça nela e escorrega por cima até cair; a `loot` só cai no chão depois que o corpo para (o cartão do
## painel do portão, com o último sniper das torres). No posto alto só quem cai larga o fuzil (no chão, do lado do corpo).

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
## Caindo do posto (`falls`): ainda em pé ele cambaleia para a frente (StaggerFwd) até a barriga bater na barra da cerca
## (`ledge`); aí amolece com o embalo, o tronco passa por cima da barra (dobra na cintura) e a gravidade leva o corpo.
const STAGGER_SPEED := 0.9  # m/s dos passos cambaleando até a cerca
const STAGGER_MAX := 0.9  # s: não chegou à cerca, amolece onde está
const BELLY := 0.24  # m do meio do corpo até a barra quando a barriga encosta nela
const TOPPLE_SPEED := 2.0  # m/s do embalo para a frente quando amolece na barra
## Corpo firme na queda do posto (`_firm`): sem o chacoalho de boneco mole. A coluna dobra até SLUMP_WAIST por junta (o
## ragdoll comum deixa 20: precisa para debruçar no abdome), os outros membros só FIRM_JOINTS do giro de sempre e todo
## giro amortecido em FIRM_DAMP (o ragdoll comum, 2).
const SLUMP_WAIST := 35.0
const FIRM_JOINTS := 0.4
const FIRM_DAMP := 5.0
const WAIST := ["Spine", "Chest"]
const DROP_SIDE := 1.0  # m do quadril até o fuzil e o cartão, um de cada lado do corpo caído
const TIP_DELAY := 0.1  # s depois de amolecer: o quadril sobe para a barra (as pernas não dobram embaixo dele)
const TIP_SPEED := 1.6  # m/s do quadril subindo e passando por cima da barra
const TIP_MAX := 2.5  # s: depois disso a física sozinha
const FALL_SETTLE := 0.5  # corpo mais lento que isto (m/s) já parou: a loot cai
const FALL_MAX := 6.0  # s depois de morrer a loot cai de qualquer jeito (no chão na frente do posto, se o corpo ficou lá em cima)

var model: HeroineModel
var health := MAX_HEALTH
var _shape: CollisionShape3D
var laser_mesh: MeshInstance3D
var laser_mat: StandardMaterial3D
var shots_fired := 0
var aim_progress := 0.0
var _cooldown_t := 0.0
var loot: KeyItem
## plataforma (XZ, mundo) em que anda; vazia = o mezanino do galpão
var perch := Rect2()
var floor_y := Catwalk.FLOOR_Y
var home_yaw := 0.0
var falls := false
## alto do guarda-corpo na frente do posto (mundo; só a altura e a distância para a frente contam)
var ledge := Vector3.ZERO
var _staggering := false
var _tipping := false
var _rag_t := 0.0
var _landed := false  # caiu do posto e já largou o que tinha (fuzil, cartão)


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
	investigate_speed = Player.RUN_SPEED * JOG_SCALE
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
	if lurking:
		return
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
				if falls:
					_stagger_to_rail()
					_tip_over(delta)
					_drop_when_landed()
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
			rotation.y = lerp_angle(rotation.y, home_yaw, 1.0 - exp(-4.0 * delta))
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
		"Walk", "Run":
			# `speed` vem em relação a _anim_speed: volta a m/s e escolhe andar/correr como a jogadora
			model.set_gait(speed * _anim_speed(anim == "Run"))
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
	if not perch.has_area() and alert_t <= 0.0 and target.global_position.y < floor_y - 0.4 and target.global_position.z > BLIND_SPOT_Z:
		return false
	return super._sees_target()


func start_hunt(at: Vector3) -> void:
	# Atirador no mezanino: se tiver linha de visada para o alvo ao ser alertado, mira imediatamente
	if _has_target() and _sees_target():
		start_alert()
		return
	var goal := _catwalk_point(at)
	if at.y < floor_y - 0.4:
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
	if at.y < floor_y - 0.4:
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


## Ponto de navegação restrito estritamente à passarela/mezanino (ou à plataforma do `perch`)
func _catwalk_point(pos: Vector3) -> Vector3:
	if perch.has_area():
		return Vector3(clampf(pos.x, perch.position.x, perch.end.x), floor_y, clampf(pos.z, perch.position.y, perch.end.y))
	var cx := clampf(pos.x, -3.8, 1.0)
	var cz := clampf(pos.z, Catwalk.FRONT_Z + 0.5, Catwalk.WALL_Z - 0.5)
	return Vector3(cx, Catwalk.FLOOR_Y, cz)


## Trava física: o Sniper nunca sai nem cai da passarela (ou da plataforma do `perch`) enquanto vivo
func _clamp_to_catwalk() -> void:
	if perch.has_area():
		global_position.x = clampf(global_position.x, perch.position.x, perch.end.x)
		global_position.z = clampf(global_position.z, perch.position.y, perch.end.y)
		if absf(global_position.y - floor_y) < 0.25 or global_position.y < floor_y:
			global_position.y = floor_y
			velocity.y = 0.0
		return
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
	if drop_is_weapon and model and not perch.has_area():
		model.holster(true)  # no posto alto o fuzil fica na mão: quem cai o larga no chão (_drop_when_landed), quem fica lá em cima não
	if not perch.has_area():
		drop_loot()
	if loot and not falls:
		loot.drop(global_position + Vector3.UP * 1.1)
	if model and model.ragdoll and perch.has_area():
		for b: PhysicalBone3D in model.ragdoll.bodies.values():
			b.collision_mask |= GuardTower.RAIL_LAYER  # o corpo mole encosta na barra da frente da torre
	if model and falls:
		# cambaleia para a frente até a cerca, venha o tiro de onde vier (ver _stagger_to_rail)
		_staggering = true
		model.set_aim(false)
		model.set_head_look(0.0, 0.0)
		model.play("stagger_fwd")
	elif model:
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


## Para a frente do posto (horizontal).
func _out() -> Vector3:
	return Vector3(-sin(home_yaw), 0.0, -cos(home_yaw))


## Morto em pé, ainda na animação: cambaleia para a frente até a barriga bater na barra da cerca e lá amolece com o embalo
## (o peito e a cabeça vão mais rápido que os pés: o tronco tomba por cima da barra).
func _stagger_to_rail() -> void:
	if not _staggering:
		return
	var out := _out()
	if out.dot(ledge - global_position) > BELLY and _t < STAGGER_MAX:
		velocity.x = out.x * STAGGER_SPEED
		velocity.z = out.z * STAGGER_SPEED
		return
	_staggering = false
	velocity = Vector3.ZERO
	_tipping = true
	_rag_t = 0.0
	_firm(true)
	model.fling_ragdoll(out * TOPPLE_SPEED + Vector3.UP * 0.5, global_position + Vector3.UP * 1.6)


## Debruçado na barra: se o peso não levou sozinho, o quadril sobe devagar por cima dela; com ele do lado de fora (ou
## já caindo), a gravidade faz o resto.
func _tip_over(delta: float) -> void:
	if not _tipping or not model or not model.ragdoll:
		return
	_rag_t += delta
	var hips: PhysicalBone3D = model.ragdoll.bodies.get("Hips")
	var out := _out()
	var bar := global_position + out * out.dot(ledge - global_position)
	bar.y = ledge.y
	if hips == null or _rag_t > TIP_MAX or out.dot(hips.global_position - bar) > 0.15 or hips.global_position.y < ledge.y - 0.6:
		_tipping = false
		return
	if _rag_t < TIP_DELAY:
		return
	var chest: PhysicalBone3D = model.ragdoll.bodies.get("Chest")
	var hanging := chest != null and chest.global_position.y < bar.y - 0.08 and out.dot(chest.global_position - bar) > 0.12
	if not hanging:
		# dobra no abdome: o quadril fica logo atrás da barra, na altura dela (o abdome apoiado nela, as pernas
		# penduradas esticadas), enquanto o tronco pende para fora
		Ragdoll.drag(hips, bar - out * 0.12 + Vector3.UP * 0.02, 3.0, TIP_SPEED)
		if chest:
			Ragdoll.drag(chest, bar + out * 0.35 + Vector3.DOWN * 0.5, 2.5, TIP_SPEED)
		return
	# tronco pendurado: o peso dele puxa o quadril, que sobe reto (encostado na barra, o atrito o prenderia) e passa por cima
	var lift := hips.global_position.y < bar.y + 0.12
	var goal := Vector3(hips.global_position.x, bar.y + 0.25, hips.global_position.z) if lift else bar + out * 0.5 + Vector3.UP * 0.2
	Ragdoll.drag(hips, goal, 3.0, TIP_SPEED)
	Ragdoll.drag(chest, bar + out * 0.3 + Vector3.DOWN * 1.0, 2.0, TIP_SPEED)


## Corpo firme para a queda do posto (juntas mais curtas e giro amortecido, a coluna livre para dobrar no abdome) ou, com
## `on` falso, de volta ao ragdoll de sempre (Ragdoll.BONES).
func _firm(on: bool) -> void:
	if not model or not model.ragdoll:
		return
	for n: String in model.ragdoll.bodies:
		var b: PhysicalBone3D = model.ragdoll.bodies[n]
		var cfg: Dictionary = Ragdoll.BONES.get(n, {})
		b.angular_damp = FIRM_DAMP if on else 2.0
		var k := FIRM_JOINTS if on else 1.0
		match cfg.get("joint", ""):
			"cone":
				b.set("joint_constraints/swing_span", SLUMP_WAIST if on and n in WAIST else float(cfg.swing) * k)
				b.set("joint_constraints/twist_span", float(cfg.twist) * k)
			"hinge":
				b.set("joint_constraints/angular_limit_lower", float(cfg.lower) * k)
				b.set("joint_constraints/angular_limit_upper", float(cfg.upper) * k)


## Fuzil do sniper que caiu do posto alto: cai de `from` até o chão embaixo.
func _ground_drop(from: Vector3) -> void:
	if _dropped or drop_kind == "" or randf() > drop_chance:
		return
	_dropped = true
	var p := get_parent()
	if p:
		Pickup.spawn_drop(p, from, drop_kind, drop_amount, drop_is_weapon)


## Caiu do posto (`falls`): primeiro o corpo chega ao chão e para; só então o fuzil e a `loot` aparecem, um de cada lado
## dele. Se o corpo ficou lá em cima, caem no chão na frente do posto (nunca presos onde ela não sobe).
func _drop_when_landed() -> void:
	if _landed or not model or not model.ragdoll:
		return
	var hips: PhysicalBone3D = model.ragdoll.bodies.get("Hips")
	if hips == null or _staggering:
		return
	# debruçado na barra o quadril também fica parado: só conta parado depois de descer do posto
	var down := hips.global_position.y < floor_y - 1.0
	if _t < FALL_MAX and (_staggering or _tipping or not down or hips.linear_velocity.length() > FALL_SETTLE):
		return
	_landed = true
	var at := hips.global_position
	if at.y > floor_y - 1.0:
		at = Vector3(global_position.x, 1.0, global_position.z) + _out() * 2.0
	# um de cada lado do corpo deitado (de través do quadril para a cabeça): nenhum dos dois fica embaixo dele
	var head: PhysicalBone3D = model.ragdoll.bodies.get("Head")
	var along := Vector3(head.global_position.x - at.x, 0.0, head.global_position.z - at.z) if head else Vector3.ZERO
	if along.length() < 0.2:
		along = _out()
	var side := along.normalized().cross(Vector3.UP) * DROP_SIDE
	if drop_is_weapon:
		model.holster(true)
	_ground_drop(at + side + Vector3.UP * 0.8)
	if loot and loot.state == "hidden":
		loot.drop(at - side + Vector3.UP * 0.4)


## Fora de cena até a hora: invisível, sem colisão e sem IA.
func lurk() -> void:
	lurking = true
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	_hide_laser()
	_update_marker()


## Entra em cena no posto, calmo.
func appear() -> void:
	lurking = false
	visible = true
	collision_layer = 2
	reset_physics_interpolation()
	_enter("idle", "Idle", 0.0)


func reset() -> void:
	if model:
		model.stop_ragdoll()
		model.set_weapon(WEAPON)
		model.holster(false)
		model.set_head_look(0.0, 0.0)
	head_yaw = 0.0
	head_pitch = 0.0
	_staggering = false
	_tipping = false
	_landed = false
	_firm(false)
	_reset_enemy()
	health = MAX_HEALTH
	collision_layer = 2
	_shape.set_deferred("disabled", false)
	_hide_laser()
	_enter("idle", "Idle", 0.0)

func has_head_look() -> bool:
	return true
