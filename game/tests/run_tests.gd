extends SceneTree
## Testes automáticos (sem janela):
##   godot --headless --path game --script res://tests/run_tests.gd
## Sai com código 1 se algum falhar.

const EXPECTED_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"UpperArm_L", "LowerArm_L", "Hand_L", "UpperArm_R", "LowerArm_R", "Hand_R",
	"UpperLeg_L", "LowerLeg_L", "Foot_L", "UpperLeg_R", "LowerLeg_R", "Foot_R",
]
const EXPECTED_ANIMS := ["Idle", "Walk", "Run", "AimIdle", "Shoot", "StrafeL", "StrafeR", "Crouch", "Roll", "Hit", "Death"]

const RAPTOR_TESTS := preload("res://tests/raptor_tests.gd")
const AI_TESTS := preload("res://tests/ai_tests.gd")
const SOLDIER_TESTS := preload("res://tests/soldier_tests.gd")
const GFX_TESTS := preload("res://tests/gfx_tests.gd")
const MOVES_TESTS := preload("res://tests/moves_tests.gd")
const WEAPONS_TESTS := preload("res://tests/weapons_tests.gd")
const BLOOD_TESTS := preload("res://tests/blood_tests.gd")
const SFX_TESTS := preload("res://tests/sfx_tests.gd")
const ALLOSAURUS_TESTS := preload("res://tests/allosaurus_tests.gd")
const SURVIVAL_TESTS := preload("res://tests/survival_tests.gd")
const KEY_TESTS := preload("res://tests/key_tests.gd")
const STEALTH_KILL_TESTS := preload("res://tests/stealth_kill_tests.gd")

var _failures: Array[String] = []
var _passed := 0
var _world: Node3D


func _initialize() -> void:
	InputSetup.register()
	# os testes do jogo de ação de antes valem no perfil "arcade" (o que o jogo mantém inteiro); o "survival" tem os seus
	GameMode.set_mode(GameMode.ARCADE)
	_run.call_deferred()


func check(cond: bool, name: String, detail := "") -> void:
	if cond:
		_passed += 1
		print("  ok   ", name)
	else:
		_failures.append(name)
		print("  FALHOU ", name, "  ", detail)


func _fresh_world() -> Node3D:
	if _world:
		_world.queue_free()
		await process_frame
	_world = Node3D.new()
	get_root().add_child(_world)
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.4, 40)
	col.shape = box
	col.position.y = -0.2
	floor.add_child(col)
	_world.add_child(floor)
	return _world


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	print("== asset")
	await test_asset()
	print("== animação")
	await test_animation_tree()
	await test_run_cycle()
	print("== ragdoll")
	await test_ragdoll()
	print("== jogadora")
	await test_player_moves()
	await test_player_roll_and_crouch()
	await test_shoot_kills_dummy()
	await test_player_death_and_respawn()
	await test_smooth_camera()
	print("== controle (gamepad)")
	await test_gamepad()
	print("== tiro e combate")
	await test_shot_cooldown()
	await test_missed_shot()
	await test_shot_on_dead_ragdoll()
	await test_hip_fire()
	await test_hit_animation()
	print("== movimento avançado")
	await test_crouch_aim()
	await test_strafe_right()
	print("== movimentos novos e fuzil")
	await MOVES_TESTS.new().run(self)
	print("== escopeta, buracos de bala e disparos")
	await WEAPONS_TESTS.new().run(self)
	print("== container trancado, chave e M79")
	await KEY_TESTS.new().run(self)
	print("== sangue e tiro na cabeça")
	await BLOOD_TESTS.new().run(self)
	print("== velociraptor")
	await RAPTOR_TESTS.new().run(self)
	print("== IA, furtividade e pátio da mata")
	await AI_TESTS.new().run(self)
	print("== guerrilheiros")
	await SOLDIER_TESTS.new().run(self)
	print("== abate furtivo e golpe crítico")
	await STEALTH_KILL_TESTS.new().run(self)
	print("== alossauro e pedreira (última sala)")
	await ALLOSAURUS_TESTS.new().run(self)
	print("== sobrevivência: câmera, armas, munição e dano")
	await SURVIVAL_TESTS.new().run(self)
	print("== visual (PS1/PS2) e atlas")
	await GFX_TESTS.new().run(self)
	print("== efeitos sonoros")
	await SFX_TESTS.new().run(self)
	print("\n%d ok, %d falharam" % [_passed, _failures.size()])
	for f in _failures:
		print("  - ", f)
	quit(1 if _failures.size() > 0 else 0)


func test_asset() -> void:
	var scene: PackedScene = load("res://assets/characters/heroine.glb")
	check(scene != null, "heroine.glb carrega")
	var inst := scene.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	var braid := names.filter(func(n: String) -> bool: return n.begins_with("Braid"))
	check(names.size() - braid.size() == EXPECTED_BONES.size(), "17 ossos do corpo", str(names))
	check(braid.size() == 4, "trança em 4 ossos (balança com mola)", str(braid))
	for b in EXPECTED_BONES:
		check(b in names, "osso " + b)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for a in EXPECTED_ANIMS:
		check(ap.has_animation(a) and ap.get_animation(a).length > 0.1, "animação " + a)
	# corpo + as duas armas
	var tris := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	check(tris > 800 and tris < 5000, "orçamento de triângulos, PS2 do começo (800-5000)", str(tris))
	check(inst.find_child("Muzzle", true, false) != null, "marcador do cano (Muzzle)")
	inst.free()


func test_animation_tree() -> void:
	var w := await _fresh_world()
	var m := HeroineModel.new()
	w.add_child(m)
	await _frames(5)
	# a árvore de animação atualiza no quadro de processo; com carga pesada a física pode rodar vários quadros antes
	for i in 3:
		await process_frame
	check(str(m.tree.get("parameters/base/current_state")) == "idle", "estado inicial idle")
	for s in HeroineModel.STATES:
		m.set_state(s)
		await _frames(3)
		check(str(m.tree.get("parameters/base/current_state")) == s, "transição para " + s)
	m.set_state("idle")
	m.set_aim(true)
	await _frames(20)
	check(m.is_aimed(), "mira liga (parte de cima)")
	# mirando, o braço direito fica à frente do ombro (pistola apontada)
	var sk := m.skeleton
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand_R")).origin
	var shoulder := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("UpperArm_R")).origin
	var fwd := -m.global_basis.z
	check((hand - shoulder).dot(fwd) > 0.4, "mira: mão direita à frente", str((hand - shoulder).dot(fwd)))


## Corrida estilo Syphon Filter: tronco inclinado, quique, gingado do quadril e pé de apoio no chão (sem afundar).
func test_run_cycle() -> void:
	var w := await _fresh_world()
	var inst: Node3D = HeroineModel.SCENE.instantiate()
	w.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	ap.play("Run")
	var length := ap.current_animation_length
	var pos := func(bone: String) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	var lean := INF
	var hips_lo := Vector3.INF
	var hips_hi := -Vector3.INF
	var ankle_lo := INF
	var ankle_hi := -INF
	for i in 20:
		ap.seek(length * i / 20.0, true)
		var hips: Vector3 = pos.call("Hips")
		var neck: Vector3 = pos.call("Neck")
		# o glTF olha para +Z: inclinação para a frente = pescoço à frente do quadril
		lean = minf(lean, rad_to_deg(atan2(neck.z - hips.z, neck.y - hips.y)))
		hips_lo = hips_lo.min(hips)
		hips_hi = hips_hi.max(hips)
		var low := minf(pos.call("Foot_L").y, pos.call("Foot_R").y)
		ankle_lo = minf(ankle_lo, low)
		ankle_hi = maxf(ankle_hi, low)
	# corrida de reação: levemente para a frente, sem o tronco de velocista
	check(lean > 4.0 and lean < 18.0, "corrida: tronco levemente inclinado para a frente", "%.1f°" % lean)
	var bob := hips_hi.y - hips_lo.y
	check(bob > 0.025 and bob < 0.08, "corrida: quique do quadril (baixo, sem pulo de atleta)", "%.3f" % bob)
	check(hips_hi.x - hips_lo.x > 0.04, "corrida: gingado lateral do quadril", "%.3f" % (hips_hi.x - hips_lo.x))
	check(ankle_lo > 0.05, "corrida: pé não afunda no chão", "tornozelo mais baixo %.3f" % ankle_lo)
	check(ankle_hi > 0.11, "corrida: fase de voo (os dois pés no ar)", "%.3f" % ankle_hi)
	# pé de apoio (esquerdo, quadros 0 a 4) parado em relação ao chão, que passa a Player.RUN_SPEED
	var plant_lo := Vector2.INF
	var plant_hi := -Vector2.INF
	for f in 5:
		ap.seek(f / 30.0, true)
		var a: Vector3 = pos.call("Foot_L")
		var g := Vector2(a.x, a.z + Player.RUN_SPEED * f / 30.0)
		plant_lo = plant_lo.min(g)
		plant_hi = plant_hi.max(g)
	var slide := plant_hi - plant_lo
	check(slide.x < 0.02, "corrida: pé de apoio não desliza de lado", "%.3f m" % slide.x)
	check(slide.y < 0.02, "corrida: pé de apoio não patina para a frente/trás", "%.3f m" % slide.y)


## Física a 60 Hz em tela de 144+ Hz: posição interpolada, câmera seguindo a posição desenhada.
func test_smooth_camera() -> void:
	check(ProjectSettings.get_setting("physics/common/physics_interpolation", false), "interpolação da física ligada")
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(5)
	check(p.camera_rig.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_OFF, "câmera movida por quadro (fora da interpolação)")
	check(p.camera_focus().is_equal_approx(p.get_global_transform_interpolated().origin), "câmera segue a posição interpolada")


func _body_ok(m: HeroineModel) -> Dictionary:
	var out := {"finite": true, "min_y": INF, "max_y": -INF}
	for b in m.ragdoll.bodies.values():
		var p: Vector3 = b.global_position
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			out.finite = false
		out.min_y = minf(out.min_y, p.y)
		out.max_y = maxf(out.max_y, p.y)
	return out


func test_ragdoll() -> void:
	var w := await _fresh_world()
	var m := HeroineModel.new()
	w.add_child(m)
	await _frames(5)
	check(m.ragdoll.bodies.size() == 12, "12 corpos físicos", str(m.ragdoll.bodies.size()))
	m.start_ragdoll(Vector3(0, 2, 8), Vector3(0, 1.3, 0))
	await _frames(2)
	check(m.is_ragdoll(), "ragdoll simulando")
	var hips: PhysicalBone3D = m.ragdoll.bodies["Hips"]
	var y0 := hips.global_position.y
	await _frames(180)
	var st := _body_ok(m)
	check(st.finite, "ragdoll sem NaN", str(st))
	check(hips.global_position.y < y0 - 0.4, "quadril caiu", "%.2f -> %.2f" % [y0, hips.global_position.y])
	check(st.min_y > -0.15, "não atravessou o chão", str(st))
	check(st.max_y < 0.8, "corpo deitado no chão", str(st))
	var head: PhysicalBone3D = m.ragdoll.bodies["Head"]
	var chest: PhysicalBone3D = m.ragdoll.bodies["Chest"]
	check(head.global_position.distance_to(chest.global_position) < 0.5, "cabeça presa ao peito", str(head.global_position.distance_to(chest.global_position)))
	for side in ["L", "R"]:
		var ul: PhysicalBone3D = m.ragdoll.bodies["UpperLeg_" + side]
		var ll: PhysicalBone3D = m.ragdoll.bodies["LowerLeg_" + side]
		check(ul.global_position.distance_to(ll.global_position) < 0.6, "perna %s inteira" % side)
	m.stop_ragdoll()
	await _frames(3)
	check(not m.is_ragdoll() and m.tree.active, "ragdoll desliga e animação volta")


func _spawn_player(w: Node3D, pos := Vector3.ZERO) -> Player:
	var p := Player.new()
	p.position = pos
	w.add_child(p)
	return p


func test_player_moves() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	var z0 := p.global_position.z
	Input.action_press("move_forward")
	await _frames(60)
	check(p.model.state == "run", "segurar frente = correr", p.model.state)
	check(p.global_position.z < z0 - 3.0, "andou para a frente da câmera", str(p.global_position))
	Input.action_press("walk")
	await _frames(5)
	check(p.model.state == "walk", "shift = andar", p.model.state)
	Input.action_release("walk")
	Input.action_release("move_forward")
	await _frames(10)
	check(p.model.state == "idle", "solta = parada", p.model.state)
	Input.action_press("aim")
	Input.action_press("move_left")
	await _frames(10)
	check(p.model.state == "strafe_l", "mirando + esquerda = passo lateral", p.model.state)
	Input.action_release("move_left")
	Input.action_press("move_back")
	await _frames(10)
	check(p.model.state == "walk" and float(p.model.tree.get("parameters/walk_speed/scale")) < 0.0, "mirando + trás = anda de costas")
	Input.action_release("move_back")
	Input.action_release("aim")


func test_player_roll_and_crouch() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	var z0 := p.global_position.z
	Input.action_press("roll")
	await _frames(2)
	Input.action_release("roll")
	check(p.rolling and p.model.state == "roll", "espaço = rolar")
	await _frames(int(Moves.data().roll.frames * 2) + 6)
	check(not p.rolling, "rolamento termina")
	check(p.global_position.z < z0 - 2.0, "rolamento desloca para a frente", str(p.global_position.z - z0))
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	await _frames(5)
	check(p.crouching and p.model.state == "crouch", "C = agachar")
	Input.action_press("move_forward")
	await _frames(20)
	check(p.velocity.z < -1.0 and p.velocity.z > -Player.RUN_SPEED * 0.5 and p.crouching, "agachada anda devagar (bem abaixo da corrida)", str(p.velocity.z))
	Input.action_release("move_forward")


func test_shoot_kills_dummy() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w, Vector3(0, 0, 4))
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, -2)
	w.add_child(d)
	await _frames(10)
	# mira de verdade: segura o botão, a câmera vai para o ombro e a retícula é posta no peito do alvo
	Input.action_press("aim")
	await _frames(30)
	for i in 3:
		p.camera_rig.look_at_point(d.global_position + Vector3.UP * 1.2)
		await _frames(2)
		p.fire()
		await _frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	Input.action_release("aim")
	check(p.shots_fired == 3, "3 disparos", str(p.shots_fired))
	check(d.dead, "alvo morre com 3 tiros", "vida=%d" % d.health)
	await _frames(5)
	check(d.model.is_ragdoll(), "alvo vira ragdoll")
	var hips: PhysicalBone3D = d.model.ragdoll.bodies["Hips"]
	await _frames(120)
	check(hips.global_position.z < -2.0, "alvo cai para trás (direção do tiro)", str(hips.global_position))
	check(_body_ok(d.model).finite, "ragdoll do alvo sem NaN")
	d.reset()
	await _frames(3)
	check(not d.dead and not d.model.is_ragdoll() and d.health == 100, "alvo reinicia")


func test_player_death_and_respawn() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	p.take_hit(30, Vector3.BACK, p.global_position + Vector3.UP)
	check(p.health == 70 and not p.dead, "dano tira vida")
	p.take_hit(999, Vector3.BACK, p.global_position + Vector3.UP)
	await _frames(3)
	check(p.dead and p.model.is_ragdoll(), "morte = ragdoll")
	Input.action_press("move_forward")
	await _frames(30)
	Input.action_release("move_forward")
	check(_body_ok(p.model).finite, "ragdoll da heroína sem NaN")
	p.respawn()
	await _frames(5)
	check(not p.dead and p.health == 100 and not p.model.is_ragdoll(), "reinício volta à vida")


func test_shot_cooldown() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	Input.action_press("aim")
	await _frames(30)
	var shots0 := p.shots_fired
	p.fire()
	await _frames(1)
	check(p.shots_fired == shots0 + 1, "primeiro tiro sai")
	# tenta atirar de novo antes do cooldown passar
	p.fire()
	await _frames(1)
	check(p.shots_fired == shots0 + 1, "cooldown bloqueia segundo tiro imediato", str(p.shots_fired))
	await _frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	p.fire()
	await _frames(1)
	check(p.shots_fired == shots0 + 2, "após cooldown, tiro sai")
	Input.action_release("aim")


func test_missed_shot() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w, Vector3(0, 0, 4))
	await _frames(10)
	Input.action_press("aim")
	await _frames(30)
	# mira para o céu (nenhum alvo)
	p.camera_rig.pitch = 0.5
	p.fire()
	await _frames(2)
	check(p.shots_fired == 1, "tiro que erra conta como disparado")
	Input.action_release("aim")


func test_shot_on_dead_ragdoll() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w, Vector3(0, 0, 4))
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, -2)
	w.add_child(d)
	await _frames(10)
	# mata o alvo
	Input.action_press("aim")
	await _frames(30)
	for i in 3:
		p.camera_rig.look_at_point(d.global_position + Vector3.UP * 1.2)
		await _frames(2)
		p.fire()
		await _frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	check(d.dead and d.model.is_ragdoll(), "alvo morto vira ragdoll")
	await _frames(180)
	var hips: PhysicalBone3D = d.model.ragdoll.bodies["Hips"]
	# espera estabilizar completamente
	var stable_y := hips.global_position.y
	await _frames(10)
	var drift := absf(hips.global_position.y - stable_y)
	# atira no corpo caído (cabeça, que é mais leve e deve mover mais)
	var head: PhysicalBone3D = d.model.ragdoll.bodies["Head"]
	# a câmera de mira fica no ombro e orbita ao girar: reaponta até convergir (um giro grande erra a cabeça)
	for i in 4:
		p.camera_rig.look_at_point(head.global_position)
		await _frames(2)
	var head_z0 := head.global_position.z
	p.fire()
	await _frames(30)
	var head_moved := absf(head.global_position.z - head_z0)
	check(head_moved > drift * 2.0, "tiro em ragdoll morto empurra o corpo", "movimento=%.3f drift=%.3f" % [head_moved, drift])
	Input.action_release("aim")


func test_hip_fire() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	check(not p.aiming, "começa sem mirar")
	p.fire()
	await _frames(1)
	check(p.shots_fired == 1, "hip fire dispara")
	check(p.aiming, "hip fire força mira temporária")
	await _frames(int(Player.HIP_AIM_TIME * 60) + 2)
	check(not p.aiming, "mira temporária expira")


func test_hit_animation() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	p.take_hit(10, Vector3.BACK, p.global_position + Vector3.UP)
	await _frames(2)
	# a animação Hit é tocada via OneShot, então não muda o state da base
	check(p.health == 90 and not p.dead, "dano não-letal tira vida sem matar")
	# o teste indireto é que o modelo tem a função hit() chamada e não crashou
	check(p.model.tree.active, "animação continua ativa após Hit")


func test_crouch_aim() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	Input.action_press("crouch")
	await _frames(2)
	Input.action_release("crouch")
	await _frames(5)
	check(p.crouching and p.model.state == "crouch", "agachada")
	Input.action_press("aim")
	await _frames(10)
	check(p.aiming and p.crouching, "agachada + mirando")
	var yaw0 := p.rotation.y
	p.camera_rig.yaw = yaw0 + 0.5
	await _frames(30)
	# vira para o ponto sob a retícula (a câmera fica no ombro direito: perto, não é a frente da câmera)
	var d := p.camera_rig.aim_point([p.get_rid()]) - p.global_position
	var want := atan2(-d.x, -d.z)
	check(absf(angle_difference(p.rotation.y, want)) < 0.1 and absf(angle_difference(p.rotation.y, yaw0 + 0.5)) < 0.45,
		"agachada mirando vira para onde a câmera mira", "%.2f x %.2f" % [p.rotation.y, want])
	Input.action_release("aim")


func test_strafe_right() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	Input.action_press("aim")
	Input.action_press("move_right")
	await _frames(10)
	check(p.model.state == "strafe_r", "mirando + direita = passo lateral direito", p.model.state)
	Input.action_release("move_right")
	Input.action_release("aim")


func _joy_axis(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _joy_button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


## Eventos de controle de verdade (não action_press): prova o mapeamento do InputSetup.
func test_gamepad() -> void:
	var w := await _fresh_world()
	var p := _spawn_player(w)
	await _frames(10)
	var z0 := p.global_position.z
	_joy_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(40)
	check(p.model.state == "run" and p.global_position.z < z0 - 1.5, "analógico esquerdo todo = correr", p.model.state)
	_joy_axis(JOY_AXIS_LEFT_Y, -0.45)
	await _frames(5)
	check(p.model.state == "walk", "analógico esquerdo pela metade = andar", p.model.state)
	_joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(5)
	check(p.model.state == "idle", "analógico solto = parada", p.model.state)
	var yaw0 := p.camera_rig.yaw
	_joy_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(20)
	_joy_axis(JOY_AXIS_RIGHT_X, 0.0)
	check(absf(p.camera_rig.yaw - yaw0) > 0.3, "analógico direito gira a câmera", str(p.camera_rig.yaw - yaw0))
	_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	await _frames(5)
	check(p.aiming, "gatilho esquerdo (LT) = mirar")
	var shots := p.shots_fired
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(3)
	_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	check(p.shots_fired == shots + 1, "gatilho direito (RT) = atirar")
	_joy_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	await _frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	_joy_button(JOY_BUTTON_LEFT_SHOULDER, true)
	_joy_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await _frames(3)
	check(p.aiming and p.shots_fired == shots + 2, "LB = mirar, RB = atirar")
	_joy_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_joy_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await _frames(40)
	_joy_button(JOY_BUTTON_A, true)
	await _frames(2)
	_joy_button(JOY_BUTTON_A, false)
	check(p.rolling, "botão A = rolar")
	await _frames(int(Moves.data().roll.frames * 2) + 6)
	_joy_button(JOY_BUTTON_B, true)
	await _frames(2)
	_joy_button(JOY_BUTTON_B, false)
	await _frames(3)
	check(p.crouching, "botão B = agachar")
