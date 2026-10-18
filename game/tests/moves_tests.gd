extends RefCounted
## Testes dos movimentos novos e do fuzil, chamados por run_tests.gd (usa check/_fresh_world/_frames de lá):
## passos sem deslizar, andar agachada e mirando, cambalhota com projeção, pulo, pendurar/subir/soltar,
## escalar obstáculo baixo, baú com M16 (ajoelha, pega, empunha) e troca de arma.

const NEW_ANIMS := [
	"CrouchWalk", "CrouchStrafeL", "CrouchStrafeR", "Jump", "Fall", "Hang", "ClimbUp", "Mantle",
	"RifleHold", "RifleAim", "RifleShoot", "Pickup",
]

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_assets()
	await test_gaits_dont_slide()
	await test_walk_speed()
	await test_crouch_walk()
	await test_crouch_aim_strafe()
	await test_roll_projection()
	await test_jump()
	await test_hang_and_climb()
	await test_hang_drop()
	await test_low_ledge_climbs_from_jump()
	await test_mantle()
	await test_no_ledge_plain_jump()
	await test_chest_pickup()
	await test_pickup_interrupted()
	await test_switch_weapon_and_fire()
	await test_hit_while_hanging()
	await test_gamepad_buttons()
	await test_crouch_pistol_guard()
	await test_weapon_follows_aim()


func _world() -> Node3D:
	return await t._fresh_world()


func _box(w: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	b.add_child(col)
	b.position = pos
	w.add_child(b)
	return b


func _player(w: Node3D, pos := Vector3.ZERO) -> Player:
	return t._spawn_player(w, pos)


func _tap(action: String) -> void:
	Input.action_press(action)
	await t._frames(2)
	Input.action_release(action)


## Centro do punho (osso da mão + 5 cm ao longo dele), no mundo.
func _palm(m: HeroineModel, side: String) -> Vector3:
	var sk := m.skeleton
	var pose := sk.get_bone_global_pose(sk.find_bone("Hand_" + side))
	return sk.global_transform * (pose.origin + pose.basis.y.normalized() * 0.05)


func test_assets() -> void:
	var inst: Node3D = HeroineModel.SCENE.instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for a in NEW_ANIMS:
		t.check(ap.has_animation(a) and ap.get_animation(a).length > 0.1, "animação " + a)
	for n in ["Pistol", "M16", "RifleMuzzle"]:
		t.check(inst.find_child(n, true, false) != null, "nó " + n + " no modelo")
	inst.free()
	var d := Moves.data()
	t.check(d.has("roll") and d.has("climb") and d.has("mantle") and d.has("rifle"), "medidas dos movimentos (heroine_moves.json)")
	var chest_rifle: Node = load("res://assets/characters/m16.glb").instantiate()
	var rifle_mesh: MeshInstance3D = chest_rifle.find_children("*", "MeshInstance3D", true, false)[0]
	t.check(rifle_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size() > 0, "m16.glb (fuzil do baú) com UV para o atlas")
	chest_rifle.free()


## Pé de apoio parado em relação ao chão, que passa na velocidade do jogo: caminhada, agachada e passo lateral.
func test_gaits_dont_slide() -> void:
	var w := await _world()
	var inst: Node3D = HeroineModel.SCENE.instantiate()
	w.add_child(inst)
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	# glTF olha para +Z (frente) e a esquerda dela é +X; o chão passa no sentido contrário ao do corpo
	for g in [["Walk", "walk", Vector3(0, 0, 1)], ["CrouchWalk", "crouch_walk", Vector3(0, 0, 1)],
			["StrafeL", "strafe", Vector3(1, 0, 0)], ["CrouchStrafeL", "crouch_strafe", Vector3(1, 0, 0)]]:
		ap.play(g[0])
		var v: float = Moves.speed(g[1])
		var length := ap.current_animation_length
		var n := int(round(length * 30.0))
		# quadros em que o pé esquerdo está chato no chão: no ponto mais baixo (até 4 mm) e na direção de repouso
		# (calcanhar subindo ou ponta subindo giram o pé em volta da ponta/calcanhar, que é o que fica parado)
		var foot := sk.find_bone("Foot_L")
		var rest_dir := sk.get_bone_global_rest(foot).basis.y.normalized()
		var ys := []
		for f in n:
			ap.seek(f / 30.0, true)
			var fp := sk.get_bone_global_pose(foot)
			var flat := fp.basis.y.normalized().angle_to(rest_dir) < deg_to_rad(2.0)
			ys.append((sk.global_transform * fp.origin).y if flat else INF)
		var low: float = ys.min()
		var worst := 0.0
		var prev := Vector3.INF
		for f in n:
			if ys[f] > low + 0.004:
				prev = Vector3.INF
				continue
			ap.seek(f / 30.0, true)
			var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Foot_L")).origin
			var ground: Vector3 = a + g[2] * v * f / 30.0
			if prev != Vector3.INF:
				worst = maxf(worst, Vector2(ground.x - prev.x, ground.z - prev.z).length())
			prev = ground
		t.check(worst < 0.006, "%s: pé de apoio não desliza (a %.2f m/s)" % [g[0], v], "%.4f m/quadro" % worst)
	inst.queue_free()


func test_walk_speed() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	Input.action_press("walk")
	Input.action_press("move_forward")
	await t._frames(30)
	var z0 := p.global_position.z
	await t._frames(60)
	var speed := (z0 - p.global_position.z)
	Input.action_release("move_forward")
	Input.action_release("walk")
	t.check(absf(speed - Moves.speed("walk")) < 0.05, "andar: velocidade igual à do ciclo (sem deslizar)", "%.2f m/s" % speed)
	t.check(speed < 1.2, "andar: mais lento que antes (1,7 m/s)", "%.2f" % speed)
	t.check(absf(float(p.model.tree.get("parameters/walk_speed/scale")) - 1.0) < 0.01, "andar: animação na velocidade certa")


func test_crouch_walk() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	await _tap("crouch")
	Input.action_press("move_forward")
	await t._frames(30)
	var z0 := p.global_position.z
	await t._frames(60)
	Input.action_release("move_forward")
	t.check(p.crouching and p.model.state == "crouch_walk", "agachada + frente = anda agachada", p.model.state)
	t.check(absf((z0 - p.global_position.z) - Moves.speed("crouch_walk")) < 0.05, "agachada anda devagar, na velocidade do ciclo", "%.2f m/s" % (z0 - p.global_position.z))
	await t._frames(10)
	t.check(p.model.state == "crouch", "agachada parada")


func test_crouch_aim_strafe() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	await _tap("crouch")
	Input.action_press("aim")
	Input.action_press("move_left")
	await t._frames(20)
	var x0 := p.global_position.x
	await t._frames(30)
	t.check(p.aiming and p.crouching and p.model.state == "crouch_strafe_l", "agachada mirando + esquerda = passo lateral agachada", p.model.state)
	t.check(p.global_position.x < x0 - 0.15, "agachada mirando anda de lado", "%.2f" % (p.global_position.x - x0))
	Input.action_release("move_left")
	Input.action_press("move_forward")
	await t._frames(10)
	t.check(p.model.state == "crouch_walk", "agachada mirando + frente = anda agachada mirando", p.model.state)
	Input.action_release("move_forward")
	Input.action_release("aim")
	# em pé mirando, para a frente também anda (e na velocidade do passo lateral)
	await _tap("crouch")
	Input.action_press("aim")
	Input.action_press("move_forward")
	await t._frames(20)
	t.check(not p.crouching and p.aiming and p.model.state == "walk" and p.velocity.length() > 0.5, "em pé mirando anda para a frente", p.model.state)
	Input.action_release("move_forward")
	Input.action_release("aim")


func test_roll_projection() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	var z0 := p.global_position.z
	await _tap("roll")
	t.check(p.rolling and p.model.state == "roll" and p.is_dodging(), "cambalhota começa e esquiva")
	await t._frames(20)
	t.check(p.global_position.z < z0 - 0.7, "projeção: já mergulhou para a frente no começo", "%.2f" % (p.global_position.z - z0))
	await t._frames(60)
	t.check(not p.rolling, "cambalhota termina")
	var dist := z0 - p.global_position.z
	t.check(dist > 3.5 and dist < 4.5, "cambalhota longa (não fica num ponto só)", "%.2f m" % dist)


func test_jump() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	await _tap("jump")
	await t._frames(8)
	t.check(not p.is_on_floor() and p.global_position.y > 0.3, "pulo sai do chão", "%.2f" % p.global_position.y)
	t.check(p.model.state == "jump", "pulo: animação", p.model.state)
	await t._frames(60)
	t.check(p.is_on_floor() and p.model.state == "idle", "pulo: cai de pé", p.model.state)


## Caixa de 2,4 m: pula, agarra, fica pendurada (mãos na borda), sobe e termina de pé em cima.
func test_hang_and_climb() -> void:
	var w := await _world()
	_box(w, Vector3(2, 2.4, 2), Vector3(0, 1.2, -1.6))  # parede em z = -0.6
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	await _tap("jump")
	await t._frames(40)
	t.check(p.moves.hanging() and p.model.state == "hang", "pula e fica pendurada", p.moves.mode)
	await t._frames(60)
	t.check(p.moves.hanging(), "continua pendurada sem apertar nada")
	var top := 2.4
	var worst := 0.0
	for s in ["L", "R"]:
		var palm := _palm(p.model, s)
		worst = maxf(worst, absf(palm.y - (top + 0.03)))
		t.check(palm.z < -0.6 and palm.z > -0.72, "pendurada: mão %s em cima da borda" % s, str(palm))
	t.check(worst < 0.05, "pendurada: mãos na altura da borda", "%.3f" % worst)
	t.check(not p.model.is_weapon_visible("pistol"), "pendurada: arma guardada")
	await _tap("jump")
	var hands := 0.0
	var until: float = float(Moves.data().climb.hands_until) / 30.0
	var t0 := 0.0
	while p.moves.mode == "climb" and t0 < 3.0:
		await t._frames(3)
		t0 += 3.0 / 60.0
		if t0 < until - 0.05:
			for s in ["L", "R"]:
				hands = maxf(hands, absf(_palm(p.model, s).y - (top + 0.03)))
	t.check(hands < 0.07, "subindo: mãos ficam presas na borda (sem escorregar)", "%.3f m" % hands)
	await t._frames(10)
	t.check(p.moves.mode == "" and absf(p.global_position.y - top) < 0.05 and p.global_position.z < -0.7, "subiu: de pé em cima da caixa", str(p.global_position))
	t.check(p.model.is_weapon_visible("pistol"), "subiu: arma de volta na mão")


func test_hang_drop() -> void:
	var w := await _world()
	_box(w, Vector3(2, 2.4, 2), Vector3(0, 1.2, -1.6))
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	await _tap("jump")
	await t._frames(40)
	await _tap("crouch")
	await t._frames(60)
	t.check(p.moves.mode == "" and p.is_on_floor() and p.global_position.y < 0.05, "agachar pendurada = solta e cai", str(p.global_position))


## Borda de 1,8 m: os pés ficariam no chão pendurada, então o pulo entra direto na subida.
func test_low_ledge_climbs_from_jump() -> void:
	var w := await _world()
	_box(w, Vector3(2, 1.8, 2), Vector3(0, 0.9, -1.6))
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	await _tap("jump")
	await t._frames(150)
	t.check(p.moves.mode == "" and absf(p.global_position.y - 1.8) < 0.05, "borda de 1,8 m: sobe direto", str(p.global_position))


func test_mantle() -> void:
	var w := await _world()
	_box(w, Vector3(2, 1.2, 2), Vector3(0, 0.6, -1.6))
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	Input.action_press("move_forward")
	await _tap("jump")
	Input.action_release("move_forward")
	t.check(p.moves.mode == "mantle" and p.model.state == "mantle", "obstáculo de 1,2 m: escala", p.moves.mode)
	# mãos no topo enquanto empurra
	var hands := (Moves.data().mantle.hands as Array)
	await t._frames(int((float(hands[0]) + float(hands[1])) / 2.0 / 30.0 * 60.0))
	var palm := _palm(p.model, "L")
	t.check(absf(palm.y - 1.23) < 0.06, "escalando: mão no topo do obstáculo", str(palm))
	await t._frames(60)
	t.check(p.moves.mode == "" and absf(p.global_position.y - 1.2) < 0.05, "escalou: de pé em cima", str(p.global_position))


func test_no_ledge_plain_jump() -> void:
	var w := await _world()
	_box(w, Vector3(2, 4.0, 2), Vector3(0, 2.0, -1.6))  # parede alta demais
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	await _tap("jump")
	await t._frames(4)
	t.check(p.moves.mode == "" and p.velocity.y > 0.0, "parede alta demais: pulo normal")


func _chest_scene() -> Array:
	var w := await _world()
	var c := Chest.new()
	c.position = Vector3(0, 0, -2)
	w.add_child(c)
	var p := _player(w, Vector3(0, 0, 1.5))
	await t._frames(10)
	return [w, c, p]


func test_chest_pickup() -> void:
	var s := await _chest_scene()
	var c: Chest = s[1]
	var p: Player = s[2]
	t.check(p.pick_target() == null, "longe do baú: sem aviso de pegar")
	# o fuzil do baú fica dentro dele (abaixo da tampa, entre as paredes)
	var aabb := AABB()
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() != c and mi.get_parent().get_parent() == c and mi.mesh is ArrayMesh:
			aabb = c.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
	var inner := AABB(Vector3(-Chest.SIZE.x / 2 + Chest.WALL, Chest.PALLET + Chest.WALL, -Chest.SIZE.z / 2 + Chest.WALL),
		Vector3(Chest.SIZE.x - 2 * Chest.WALL, Chest.SIZE.y - Chest.WALL, Chest.SIZE.z - 2 * Chest.WALL))
	t.check(aabb.size.x > 0.8 and inner.grow(0.005).encloses(aabb), "M16 deitado dentro do baú", "%s em %s" % [aabb, inner])
	p.global_position = c.kneel_transform().origin + Vector3(0.3, 0, 0.3)
	await t._frames(3)
	t.check(p.pick_target() == c, "perto do baú: aviso de pegar")
	await _tap("interact")
	t.check(p.moves.mode == "pickup" and p.model.state == "pickup", "triângulo/E = ajoelha para pegar")
	await t._frames(20)
	t.check(c.is_open(), "tampa abre")
	t.check(not p.model.is_weapon_visible("pistol"), "guarda a pistola para pegar o fuzil")
	# no quadro em que as mãos pegam, o fuzil da mão está onde estava o do baú
	var grab := float(Moves.data().rifle.grab_frame) / 30.0
	await t._frames(int(grab * 60.0) - 22 + 4)
	var muzzle := p.model.muzzle_position()
	t.check(p.weapon() == "m16" and not c.has_item(), "pega o fuzil no quadro das mãos")
	t.check((c.global_transform * aabb).grow(0.06).has_point(muzzle), "fuzil passa do baú para as mãos sem pular", "cano %s" % muzzle)
	await t._frames(70)
	t.check(p.moves.mode == "" and p.model.state == "idle", "levanta e termina de pé")
	t.check(p.model.is_weapon_visible("m16") and not p.model.is_weapon_visible("pistol"), "empunha o M16")
	t.check(float(p.model.tree.get("parameters/carry/blend_amount")) > 0.5, "M16 na pose de carregar")
	t.check(p.pick_target() == null, "baú vazio: sem aviso")
	t.check(Array(p.weapons) == ["pistol", "m16"], "inventário: pistola e M16", str(p.weapons))
	p.respawn()
	c.reset()
	await t._frames(3)
	t.check(p.weapon() == "pistol" and p.weapons.size() == 1 and c.has_item() and not c.is_open(), "reinício: volta só com a pistola e o baú cheio")


## Golpe antes das mãos chegarem: o fuzil fica no baú e ela volta com a pistola.
func test_pickup_interrupted() -> void:
	var s := await _chest_scene()
	var c: Chest = s[1]
	var p: Player = s[2]
	p.global_position = c.kneel_transform().origin
	await t._frames(3)
	await _tap("interact")
	await t._frames(10)
	p.knockback(Vector3(0, 0, 4))
	await t._frames(3)
	t.check(p.moves.mode == "" and c.has_item() and p.weapon() == "pistol" and p.model.is_weapon_visible("pistol"), "pegando e leva golpe: fuzil fica, pistola volta")


func test_switch_weapon_and_fire() -> void:
	var w := await _world()
	var p := _player(w, Vector3(0, 0, 4))
	await t._frames(10)
	await _tap("switch_weapon")
	t.check(p.weapon() == "pistol", "só com a pistola: Select não troca")
	p.give_weapon("m16")
	await t._frames(2)
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, -2)
	w.add_child(d)
	Input.action_press("aim")
	await t._frames(30)
	p.camera_rig.look_at_point(d.global_position + Vector3.UP * 1.2)
	await t._frames(2)
	var shots := p.shots_fired
	var h0 := d.health
	p.fire()
	await t._frames(1)
	t.check(h0 - d.health == Player.WEAPON_STATS.m16.damage, "M16: dano do fuzil", str(h0 - d.health))
	await t._frames(int(Player.WEAPON_STATS.m16.cooldown * 60) + 1)
	p.fire()
	await t._frames(1)
	t.check(p.shots_fired == shots + 2, "M16: cadência maior que a pistola")
	t.check(float(p.model.tree.get("parameters/aim_pose/blend_amount")) == 1.0, "M16: pose de mira do fuzil")
	Input.action_release("aim")
	await t._frames(10)
	await _tap("switch_weapon")
	await t._frames(2)
	t.check(p.weapon() == "pistol" and p.model.is_weapon_visible("pistol") and not p.model.is_weapon_visible("m16"), "Select/Q volta para a pistola")
	await _tap("switch_weapon")
	await t._frames(2)
	t.check(p.weapon() == "m16", "Select/Q troca para o M16")
	d.queue_free()


func test_hit_while_hanging() -> void:
	var w := await _world()
	_box(w, Vector3(2, 2.4, 2), Vector3(0, 1.2, -1.6))
	var p := _player(w, Vector3(0, 0, 0.0))
	await t._frames(10)
	await _tap("jump")
	await t._frames(40)
	p.knockback(Vector3(0, 1, 4))
	await t._frames(90)
	t.check(p.moves.mode == "" and p.is_on_floor() and p.model.is_weapon_visible("pistol"), "golpe pendurada: cai e volta ao normal", str(p.global_position))


func test_gamepad_buttons() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	t._joy_button(JOY_BUTTON_X, true)
	await t._frames(2)
	t._joy_button(JOY_BUTTON_X, false)
	await t._frames(6)
	t.check(not p.is_on_floor() and p.velocity.y != 0.0, "botão X (quadrado) = pular")
	await t._frames(60)
	p.give_weapon("m16")
	t._joy_button(JOY_BUTTON_BACK, true)
	await t._frames(2)
	t._joy_button(JOY_BUTTON_BACK, false)
	await t._frames(2)
	t.check(p.weapon() == "pistol", "Select = trocar arma")
	var c := Chest.new()
	w.add_child(c)
	c.global_position = p.global_position + Vector3(0, 0, -(Chest.SIZE.z * 0.5 + float(Moves.data().rifle.kneel_dist)))
	await t._frames(3)
	t._joy_button(JOY_BUTTON_Y, true)
	await t._frames(2)
	t._joy_button(JOY_BUTTON_Y, false)
	t.check(p.moves.mode == "pickup", "triângulo (Y) = pegar")


## Agachada com a pistola: as duas mãos juntas na arma (guarda), parada e andando.
func test_crouch_pistol_guard() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	await _tap("crouch")
	await t._frames(20)
	var gap := _palm(p.model, "L").distance_to(_palm(p.model, "R"))
	t.check(p.model.state == "crouch" and gap < 0.1, "agachada parada: as duas mãos na pistola", "%.3f m" % gap)
	Input.action_press("move_forward")
	var worst := 0.0
	for i in 6:
		await t._frames(8)
		worst = maxf(worst, _palm(p.model, "L").distance_to(_palm(p.model, "R")))
	Input.action_release("move_forward")
	t.check(p.model.state == "crouch_walk" and worst < 0.1, "andando agachada: as duas mãos na pistola", "%.3f m" % worst)


## Mirando para cima, reto e para baixo, o cano aponta para o ponto da retícula (o tiro sai em linha reta do cano).
func test_weapon_follows_aim() -> void:
	var w := await _world()
	var p := _player(w)
	await t._frames(10)
	for wpn in ["pistol", "m16"]:
		if wpn == "m16":
			p.give_weapon("m16")
		for pitch in [0.45, 0.0, -0.4]:
			for i in 40:
				Input.action_press("aim")
				p.camera_rig.pitch = pitch
				await t.physics_frame
			# o anexo do cano segue o osso já inclinado pela mira (a pose lida de fora é a da animação)
			var barrel: Vector3 = (p.model._muzzles[wpn].get_parent() as Node3D).global_basis.y.normalized()
			var to := (p.camera_rig.aim_point([p.get_rid()]) - p.model.muzzle_position()).normalized()
			var err := rad_to_deg(barrel.angle_to(to))
			t.check(err < 5.0, "%s mirando %+.0f°: cano aponta para a retícula" % [wpn, rad_to_deg(pitch)], "%.1f°" % err)
	Input.action_release("aim")
