extends RefCounted
## Testes do perfil "survival" de GameMode (câmera por cima do ombro, só atira mirando, munição limitada e itens, cada arma
## muda o movimento, inimigos que machucam o dobro, pulinho de esquiva com intervalo no lugar da cambalhota) e conferência de que o "arcade" continua o
## de antes. Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá); o runner volta ao "arcade" no fim.

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	GameMode.set_mode(GameMode.SURVIVAL)
	await test_profiles()
	await test_enemy_damage()
	await test_aim_to_shoot_and_ammo()
	await test_weapon_ammo_and_collect()
	await test_pickup_in_world()
	await test_layout_clear()
	await test_weapon_movement()
	await test_aim_lock()
	await test_shoulder_camera()
	await test_recoil_kick()
	await test_roll_cooldown()
	await test_short_dodge()
	await test_dodge_edge_cases()
	await test_dodge_beats_charges()
	await test_double_x_roll()
	await test_arcade_unchanged()
	GameMode.set_mode(GameMode.ARCADE)


## Jogadora com `weapon` na mão mirando (botão apertado) para -Z, câmera olhando a frente.
func _aimed(w: Node3D, weapon := "pistol") -> Player:
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(10)
	if weapon != "pistol":
		p.give_weapon(weapon)
	Input.action_press("aim")
	await t._frames(25)
	return p


func _release_all() -> void:
	for a in ["aim", "shoot", "move_forward", "move_left", "move_right", "roll", "crouch", "walk"]:
		Input.action_release(a)


func _tap(action: String) -> void:
	Input.action_press(action)
	await t._frames(2)
	Input.action_release(action)


func test_profiles() -> void:
	t.check(GameMode.is_survival() and GameMode.shoulder_cam() and GameMode.limited_ammo() and GameMode.aim_to_shoot(), "survival: câmera de ombro, munição limitada, só atira mirando")
	t.check(GameMode.enemy_damage(7) == 14 and GameMode.enemy_damage(22) == 44, "survival: inimigos machucam o dobro", str(GameMode.enemy_damage(7)))
	t.check(GameMode.move_scale() < 1.0, "survival: anda mais devagar", str(GameMode.move_scale()))
	var s := GameMode.weapon_stats("pistol", Player.WEAPON_STATS.pistol)
	t.check(s.cooldown > Player.WEAPON_STATS.pistol.cooldown and s.aim_speed > Player.RUN_SPEED * 0.5, "survival: pistola mais lenta, mira correndo", str(s.cooldown))
	var cap := func(k: String) -> float: return GameMode.weapon_stats(k, Player.WEAPON_STATS[k]).aim_speed
	t.check(cap.call("shotgun") == 0.0 and cap.call("shotgun") < cap.call("m16") and cap.call("m16") < cap.call("pistol"), "survival: mirando, escopeta trava, M16 anda, pistola corre")
	t.check(GameMode.weapon_stats("m16", Player.WEAPON_STATS.m16).kick > GameMode.weapon_stats("pistol", Player.WEAPON_STATS.pistol).kick, "survival: M16 com mais coice que a pistola")
	# o "arcade" é o de antes: números das armas intactos e nada de limite
	GameMode.set_mode(GameMode.ARCADE)
	var a := GameMode.weapon_stats("m16", Player.WEAPON_STATS.m16)
	t.check(a.cooldown == Player.WEAPON_STATS.m16.cooldown and a.bloom == Player.WEAPON_STATS.m16.bloom and a.kick == 0.0 and a.aim_speed > Player.RUN_SPEED, "arcade: armas como eram")
	t.check(GameMode.enemy_damage(7) == 7 and not GameMode.limited_ammo() and not GameMode.shoulder_cam() and not GameMode.aim_to_shoot() and not GameMode.pickups(), "arcade: dano normal, munição infinita, câmera livre, mira temporária, sem itens")
	GameMode.set_mode(GameMode.SURVIVAL)
	var pistol_total := int(GameMode.START_AMMO.pistol)
	for e in Pickup.LAYOUT:
		if e.kind == "pistol":
			pistol_total += int(e.amount)
	t.check(pistol_total * Player.DAMAGE < 2 * (5 * Raptor.MAX_HEALTH + Allosaurus.MAX_HEALTH), "munição escassa: a pistola sozinha não mata tudo", str(pistol_total))


func test_enemy_damage() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 8))
	var r := Raptor.new()
	r.position = Vector3(0, 0, -10)
	r.target = p
	w.add_child(r)
	await t._frames(3)
	r._strike("tail", Vector3.BACK)
	t.check(p.health == 100 - 2 * Raptor.DAMAGE.tail, "survival: rabada do raptor tira o dobro", str(p.health))
	var s := Soldier.new()
	s.position = Vector3(0, 0, -12)
	s.target = p
	w.add_child(s)
	await t._frames(2)
	p.health = 100
	p.take_hit(GameMode.enemy_damage(Soldier.DAMAGE), Vector3.BACK, p.global_position + Vector3.UP)
	t.check(p.health == 100 - 2 * Soldier.DAMAGE, "survival: tiro de soldado tira o dobro", str(p.health))
	var a := Allosaurus.new()
	a.position = Vector3(0, 0, -14)
	a.target = p
	w.add_child(a)
	await t._frames(3)
	p.health = 100
	await t._frames(70)  # a rabada do raptor a jogou longe
	p.health = 100
	a._strike("stomp", Vector3.BACK)
	t.check(p.health == 100 - 2 * Allosaurus.DAMAGE.stomp, "survival: pisada do alossauro tira o dobro", str(p.health))


func test_aim_to_shoot_and_ammo() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(10)
	var notices: Array[String] = []
	p.notice.connect(func(text: String) -> void: notices.append(text))
	t.check(p.ammo_of("pistol") == 10, "começa com 10 balas na pistola", str(p.ammo_of("pistol")))
	p.fire()
	t.check(p.shots_fired == 0 and not p.aiming and p.ammo_of("pistol") == 10, "sem apertar mirar não atira (nada de mira temporária)")
	Input.action_press("aim")
	await t._frames(2)
	p.fire()
	t.check(p.shots_fired == 0, "mirando mas ainda erguendo a arma: não atira")
	await t._frames(25)
	t.check(p.aiming and p.model.is_aimed(), "mira apertada: arma erguida")
	p.fire()
	t.check(p.shots_fired == 1 and p.ammo_of("pistol") == 9, "mirando atira e gasta 1 bala", str(p.ammo_of("pistol")))
	await t._frames(int(p.weapon_stats("pistol").cooldown * 60) + 2)
	p.fire()
	t.check(p.shots_fired == 2 and p.ammo_of("pistol") == 8, "cadência da pistola no survival")
	p.ammo["pistol"] = 0
	await t._frames(int(p.weapon_stats("pistol").cooldown * 60) + 2)
	var clicks := int(Sfx.played.get("dry_fire", 0))
	p.fire()
	t.check(p.shots_fired == 2 and p.ammo_of("pistol") == 0, "sem munição não atira")
	t.check(int(Sfx.played.get("dry_fire", 0)) == clicks + 1 and "SEM MUNIÇÃO" in notices, "sem munição: clique e aviso", str(notices))
	var n := notices.size()
	for i in 5:
		await t._frames(2)
		p.fire()
	t.check(notices.size() == n, "o aviso de arma vazia não se repete a cada quadro", str(notices.size() - n))
	_release_all()
	p.queue_free()


func test_weapon_ammo_and_collect() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(5)
	var notices: Array[String] = []
	p.notice.connect(func(text: String) -> void: notices.append(text))
	p.give_weapon("m16")
	p.give_weapon("shotgun")
	t.check(p.ammo_of("m16") == GameMode.WEAPON_AMMO.m16 and p.ammo_of("shotgun") == GameMode.WEAPON_AMMO.shotgun, "armas dos baús trazem pouca munição", str(p.ammo))
	t.check("M16 +%d" % GameMode.WEAPON_AMMO.m16 in notices, "pegar a arma avisa a munição", str(notices))
	t.check(p.collect("pistol", 8) and p.ammo_of("pistol") == 18, "caixa de munição soma", str(p.ammo_of("pistol")))
	p.ammo["pistol"] = GameMode.AMMO_CAP.pistol - 3
	t.check(p.collect("pistol", 8) and p.ammo_of("pistol") == GameMode.AMMO_CAP.pistol, "munição não passa do máximo (pega só o que cabe)")
	t.check(not p.collect("pistol", 8) and p.ammo_of("pistol") == GameMode.AMMO_CAP.pistol, "no máximo: a caixa fica no chão")
	t.check(not p.collect("health", 35), "vida cheia: o kit fica no chão")
	p.health = 40
	t.check(p.collect("health", 35) and p.health == 75, "kit de vida cura", str(p.health))
	p.health = 90
	t.check(p.collect("health", 35) and p.health == 100, "vida não passa de 100", str(p.health))
	p.die(Vector3.BACK)
	t.check(not p.collect("pistol", 5), "morta não pega nada")
	p.respawn()
	t.check(p.ammo_of("pistol") == GameMode.START_AMMO.pistol and p.ammo_of("m16") == 0 and p.weapons.size() == 1, "reiniciar volta à munição do começo", str(p.ammo))
	p.queue_free()


func test_pickup_in_world() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	var box := Pickup.new()
	box.kind = "m16"
	box.amount = 10
	box.position = Vector3(0, 0, 4.0)
	w.add_child(box)
	var kit := Pickup.new()
	kit.kind = "health"
	kit.amount = 35
	kit.position = Vector3(3, 0, 6)
	w.add_child(kit)
	await t._frames(5)
	t.check(box.visible and kit.visible and not box.taken, "itens aparecem no survival")
	Input.action_press("move_forward")
	await t._frames(90)
	Input.action_release("move_forward")
	t.check(box.taken and not box.visible and p.ammo_of("m16") == 10, "passar por cima pega a munição", str(p.ammo_of("m16")))
	p.global_position = Vector3(3, 0, 6)
	await t._frames(5)
	t.check(not kit.taken and kit.visible, "vida cheia: o kit não é pego")
	p.health = 50
	await t._frames(5)
	t.check(kit.taken and p.health == 85, "ferida: pega o kit", str(p.health))
	box.reset()
	kit.reset()
	t.check(not box.taken and not kit.taken, "reiniciar devolve os itens")
	GameMode.set_mode(GameMode.ARCADE)
	await t._frames(3)
	t.check(not box.visible and not kit.visible, "arcade: sem itens")
	GameMode.set_mode(GameMode.SURVIVAL)


## Os itens de `LAYOUT` ficam em chão livre do cenário de verdade (nada sólido em volta, chão embaixo).
func test_layout_clear() -> void:
	var w: Node3D = await t._fresh_world()
	for c in w.get_children():
		c.free()
	Level.build(w)
	await t._frames(3)
	var space := w.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.2, 0.9)
	for e in Pickup.LAYOUT:
		t.check(e.kind == "health" or e.kind in GameMode.AMMO_CAP, "item do cenário conhecido: %s" % e.kind)
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = box
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), e.pos + Vector3.UP * 0.9)
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(e.pos + Vector3.UP * 1.0, e.pos + Vector3.DOWN * 1.0, 1))
		t.check(space.intersect_shape(q, 4).is_empty() and not ground.is_empty(), "item em chão livre: %s em (%.1f, %.1f)" % [e.kind, e.pos.x, e.pos.z])


## Velocidade horizontal (m/s) da jogadora depois de `frames` quadros com o direcional para a frente.
func _forward_speed(p: Player, frames := 40) -> float:
	Input.action_press("move_forward")
	await t._frames(frames)
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	return v


func test_weapon_movement() -> void:
	# sem mirar: anda e corre mais devagar que no arcade
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 18))
	await t._frames(10)
	var run := await _forward_speed(p)
	t.check(absf(run - Player.RUN_SPEED * GameMode.move_scale()) < 0.15, "survival: corrida mais lenta", str(run))
	t.check(p.model.state == "run", "survival: continua usando a animação de corrida", p.model.state)
	# SHIFT / L3: corrida forte, acima da normal mas longe de velocista
	Input.action_release("move_forward")
	await t._frames(10)
	Input.action_press("sprint")
	var sprint := await _forward_speed(p)
	t.check(sprint > run * 1.1 and sprint < Player.RUN_SPEED * 1.1 and absf(sprint - Player.SPRINT_SPEED) < 0.15 and p.model.state == "run", "SHIFT/L3: corrida forte, mais rápida que a normal sem ser velocista", "%f contra %f (%s)" % [sprint, run, p.model.state])
	Input.action_release("sprint")
	# ALT: andar devagar (o SHIFT agora é a corrida forte)
	Input.action_press("walk_slow")
	var slow := await _forward_speed(p)
	t.check(absf(slow - Moves.speed("walk") * GameMode.move_scale()) < 0.1 and p.model.state == "walk", "ALT: andar devagar", "%f %s" % [slow, p.model.state])
	Input.action_release("walk_slow")
	# agachada não corre forte, e mirando a arma manda (escopeta trava mesmo com SHIFT)
	Input.action_press("crouch")
	await t._frames(3)
	Input.action_release("crouch")
	Input.action_press("sprint")
	var crouched := await _forward_speed(p)
	t.check(p.crouching and crouched < 1.5, "agachada: SHIFT não faz correr", str(crouched))
	Input.action_release("sprint")
	_release_all()
	p.queue_free()
	var w2: Node3D = await t._fresh_world()
	var p2 := await _aimed(w2, "shotgun")
	Input.action_press("sprint")
	var locked := await _forward_speed(p2)
	t.check(locked < 0.05, "escopeta mirando: SHIFT não destrava", str(locked))
	Input.action_release("sprint")
	_release_all()
	p2.queue_free()
	# no arcade o SHIFT continua sendo andar devagar e não há corrida forte
	GameMode.set_mode(GameMode.ARCADE)
	var w3: Node3D = await t._fresh_world()
	var p3: Player = t._spawn_player(w3, Vector3(0, 0, 18))
	await t._frames(10)
	Input.action_press("sprint")
	var arcade_run := await _forward_speed(p3)
	t.check(absf(arcade_run - Player.RUN_SPEED) < 0.15, "arcade: sprint não existe, corre como antes", str(arcade_run))
	Input.action_release("sprint")
	Input.action_press("walk")
	var arcade_walk := await _forward_speed(p3)
	t.check(absf(arcade_walk - Moves.speed("walk")) < 0.1, "arcade: SHIFT continua andar devagar", str(arcade_walk))
	Input.action_release("walk")
	p3.queue_free()
	GameMode.set_mode(GameMode.SURVIVAL)


## Velocidade horizontal com o direcional empurrado para a frente, mirando com `kind` na mão (a jogadora já está mirando).
func _aimed_speed(kind: String) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := await _aimed(w, kind)
	var v := await _forward_speed(p)
	var state := p.model.state
	_release_all()
	p.queue_free()
	return [v, state]


## Apertar mirar com a arma na mão decide o movimento, sem ela precisar parar: pistola corre, M16 vira andar devagar,
## escopeta trava sozinha. Atirar nunca é bloqueado por andar.
func test_aim_lock() -> void:
	var pistol: Array = await _aimed_speed("pistol")
	t.check(absf(pistol[0] - 2.8) < 0.15 and pistol[1] == "run", "pistola mirando: corre e atira", str(pistol))
	var m16: Array = await _aimed_speed("m16")
	t.check(absf(m16[0] - 1.5) < 0.15 and m16[1] == "walk", "M16 mirando: vira andar devagar sozinha, sem soltar o direcional", str(m16))
	var shotgun: Array = await _aimed_speed("shotgun")
	t.check(shotgun[0] < 0.05 and shotgun[1] == "idle", "escopeta mirando: o movimento trava sozinho, mesmo com o direcional empurrado", str(shotgun))
	t.check(m16[0] < pistol[0] and shotgun[0] < m16[0], "pistola > M16 > escopeta")
	# soltou o botão de mirar: volta a correr normal (a trava é só mirando)
	var w: Node3D = await t._fresh_world()
	var p := await _aimed(w, "shotgun")
	Input.action_press("move_forward")
	await t._frames(20)
	t.check(Vector2(p.velocity.x, p.velocity.z).length() < 0.05, "escopeta: mirando, travada")
	Input.action_release("aim")
	await t._frames(20)
	t.check(Vector2(p.velocity.x, p.velocity.z).length() > 3.0 and p.model.state == "run", "escopeta: soltou a mira, corre de novo", str(p.velocity))
	# atira com o direcional empurrado, sem aviso nem bloqueio, e o corpo continua parado
	Input.action_press("aim")
	await t._frames(25)
	var shots := p.shots_fired
	p.fire()
	t.check(p.shots_fired == shots + 1 and p.ammo_of("shotgun") == GameMode.WEAPON_AMMO.shotgun - 1, "escopeta: atira com o direcional apertado e gasta 1 cartucho", str(p.ammo_of("shotgun")))
	await t._frames(10)
	t.check(Vector2(p.velocity.x, p.velocity.z).length() < 0.05, "escopeta: continua travada depois do tiro")
	_release_all()
	p.queue_free()
	# M16: o tiro desacelera ainda mais por um instante (coice)
	var w2: Node3D = await t._fresh_world()
	var p2 := await _aimed(w2, "m16")
	Input.action_press("move_forward")
	await t._frames(25)
	var before := Vector2(p2.velocity.x, p2.velocity.z).length()
	p2.fire()
	await t._frames(6)
	var after := Vector2(p2.velocity.x, p2.velocity.z).length()
	t.check(after < before * 0.8, "M16: atirar andando desacelera", "%f contra %f" % [after, before])
	# de lado: passo lateral
	_release_all()
	var w3: Node3D = await t._fresh_world()
	var p3 := await _aimed(w3, "pistol")
	Input.action_press("move_left")
	await t._frames(30)
	t.check(p3.model.state == "strafe_l" and Vector2(p3.velocity.x, p3.velocity.z).length() > 0.5, "pistola mirando: passo lateral", p3.model.state)
	# agachada com a escopeta também trava
	_release_all()
	var w4: Node3D = await t._fresh_world()
	var p4 := await _aimed(w4, "shotgun")
	Input.action_press("crouch")
	await t._frames(3)
	Input.action_release("crouch")
	Input.action_press("move_forward")
	await t._frames(30)
	t.check(p4.crouching and Vector2(p4.velocity.x, p4.velocity.z).length() < 0.05, "escopeta agachada mirando: também trava")
	_release_all()


func test_shoulder_camera() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(60)
	var rig := p.camera_rig
	t.check(absf(rig.spring.spring_length - CameraRig.SHOULDER.length) < 0.05, "survival: câmera mais perto que a do arcade", str(rig.spring.spring_length))
	t.check(absf(rig.spring.position.x - CameraRig.SHOULDER.side) < 0.03, "survival: câmera por cima do ombro direito mesmo sem mirar", str(rig.spring.position.x))
	Input.action_press("aim")
	await t._frames(60)
	t.check(absf(rig.spring.spring_length - CameraRig.SHOULDER.length_aim) < 0.05 and rig.camera.fov < CameraRig.SHOULDER.fov - 10.0, "mirando: chega mais perto e fecha o campo de visão", "%f %f" % [rig.spring.spring_length, rig.camera.fov])
	# não volta sozinha para trás dela
	Input.action_release("aim")
	await t._frames(30)
	var yaw0 := rig.yaw
	Input.action_press("move_left")
	await t._frames(240)
	Input.action_release("move_left")
	t.check(absf(angle_difference(yaw0, rig.yaw)) < 0.01, "survival: a câmera não gira sozinha atrás dela", str(rig.yaw - yaw0))
	# mirando, o mouse gira mais devagar
	Input.action_press("aim")
	await t._frames(5)
	var y1 := rig.yaw
	rig._look(Vector2(100, 0))
	var slow := absf(rig.yaw - y1)
	Input.action_release("aim")
	await t._frames(5)
	var y2 := rig.yaw
	rig._look(Vector2(100, 0))
	var normal := absf(rig.yaw - y2)
	t.check(slow < normal * 0.8, "mirando o mouse gira mais devagar", "%f contra %f" % [slow, normal])
	p.queue_free()


func test_recoil_kick() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(5)
	var rig := p.camera_rig
	rig.pitch = 0.0
	rig.kick(0.1)
	t.check(is_equal_approx(rig.pitch, 0.1), "coice sobe a mira", str(rig.pitch))
	await t._frames(120)
	t.check(rig.pitch > 0.03 and rig.pitch < 0.05, "a câmera desfaz parte do coice e o resto fica", str(rig.pitch))
	GameMode.set_mode(GameMode.ARCADE)
	rig.pitch = 0.0
	rig.kick(0.1)
	t.check(rig.pitch == 0.0, "arcade: sem coice na câmera")
	GameMode.set_mode(GameMode.SURVIVAL)
	# tiros seguidos de M16 sobem mais a mira que um de pistola (recoil mínimo)
	var w2: Node3D = await t._fresh_world()
	var p2 := await _aimed(w2, "m16")
	p2.camera_rig.pitch = 0.0
	p2.camera_rig._recoil = 0.0
	var before := p2.camera_rig.pitch
	p2.fire()
	var m16_kick := p2.camera_rig.pitch - before
	t.check(m16_kick > 0.015, "tiro de M16 dá coice médio", str(m16_kick))
	p2.queue_free()
	_release_all()
	var w3: Node3D = await t._fresh_world()
	var p3 := await _aimed(w3, "pistol")
	p3.camera_rig._recoil = 0.0
	var b3 := p3.camera_rig.pitch
	p3.fire()
	var pistol_kick := p3.camera_rig.pitch - b3
	t.check(pistol_kick > 0.0 and pistol_kick < m16_kick, "pistola: coice mínimo", "%f contra %f" % [pistol_kick, m16_kick])
	_release_all()
	p3.queue_free()


func test_roll_cooldown() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 10))
	await t._frames(10)
	await _dodge()
	t.check(p.moves.mode == "dodge", "esquiva começa")
	await t._frames(int(Moves.data().dodge.frames / Moves.fps() * 60.0) + 6)
	t.check(p.moves.mode == "", "esquiva termina")
	await _press_x()
	t.check(p.moves.mode == "" and p._roll_cd > 0.0, "survival: não encadeia esquiva (intervalo)", str(p._roll_cd))
	await t._frames(60)
	await _dodge()
	t.check(p.moves.mode == "dodge", "passado o intervalo, esquiva de novo")
	GameMode.set_mode(GameMode.ARCADE)
	await t._frames(110)
	await _press_x()
	t.check(p.moves.mode == "roll" and p._roll_cd <= 0.0, "arcade: cambalhota na hora, sem intervalo")
	GameMode.set_mode(GameMode.SURVIVAL)
	p.queue_free()


## Um clique no X (com `dir` = ação de direção segurada junto, ou nenhuma).
func _press_x(dir := "") -> void:
	if dir:
		Input.action_press(dir)
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	if dir:
		Input.action_release(dir)


## Um X só e espera a janela do clique duplo passar (aí sai o pulinho).
func _dodge(dir := "") -> void:
	await _press_x(dir)
	await t._frames(int(PlayerMoves.DOUBLE_TAP * 60.0) + 3)


## Survival: o botão de esquiva dá um pulinho curto sem rolar: parada = para trás, com direção = de lado, sem virar.
func test_short_dodge() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 10))
	await t._frames(10)
	var d: Dictionary = Moves.data().dodge
	var whole := int(float(d.frames) / Moves.fps() * 60.0) + 6
	var p0 := p.global_position
	await _dodge()
	t.check(p.moves.mode == "dodge" and p.model.state == "dodge_back" and not p.rolling and p.is_dodging(), "survival: esquiva parada = pulinho para trás, sem rolar", p.model.state)
	await t._frames(int(float(d.guard) / Moves.fps() * 60.0) + 2)
	t.check(p.moves.mode == "dodge" and not p.is_dodging(), "invulnerável só no começo do pulinho (guard)")
	await t._frames(whole)
	var back := p.global_position - p0
	t.check(p.moves.mode == "" and back.z > 1.3 and back.z < 1.8 and absf(back.x) < 0.1, "pulinho para trás: ~1,5 m", "%.2f, %.2f" % [back.x, back.z])
	t.check(absf(p.rotation.y) < 0.05, "para trás sem girar", str(p.rotation.y))
	await t._frames(90)
	await _dodge("move_left")
	p0 = p.global_position  # o pulinho mal saiu do lugar (a espera do clique duplo pode ter freado um embalo)
	t.check(p.model.state == "dodge_l", "esquerda + esquiva = pulinho para a esquerda", p.model.state)
	await t._frames(whole)
	var side := p.global_position - p0
	t.check(side.x < -1.6 and side.x > -2.1 and absf(side.z) < 0.1 and absf(p.rotation.y) < 0.05, "pulinho de lado: ~1,8 m, olhando para a frente", "%.2f, %.2f" % [side.x, side.z])
	await t._frames(90)
	await _dodge("move_right")
	p0 = p.global_position
	t.check(p.model.state == "dodge_r", "direita + esquiva = pulinho para a direita", p.model.state)
	await t._frames(whole)
	t.check(p.global_position.x - p0.x > 1.6, "pulinho para a direita", "%.2f" % (p.global_position.x - p0.x))
	await t._frames(90)
	# para a frente não tem pulinho: ela vira o mínimo e pula de lado na direção pedida
	await _dodge("move_forward")
	p0 = p.global_position
	t.check(p.model.state in ["dodge_l", "dodge_r"], "frente + esquiva = pulinho de lado", p.model.state)
	await t._frames(whole)
	t.check(p0.z - p.global_position.z > 1.6 and absf(absf(wrapf(p.rotation.y, -PI, PI)) - PI / 2.0) < 0.1, "vai para onde pediu, de lado", "%.2f %.2f" % [p0.z - p.global_position.z, p.rotation.y])
	_release_all()
	p.queue_free()


## Casos de borda: no ar (não sai), agachada (sai), cancelamento por golpe/respawn, com arma longa.
func test_dodge_edge_cases() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 10))
	await t._frames(10)
	# no ar: esquiva não sai
	await _tap("jump")
	await t._frames(10)
	t.check(not p.is_on_floor(), "no ar")
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	t.check(p.moves.mode == "" and not p.hopping, "no ar: esquiva não sai", p.moves.mode)
	await t._frames(60)
	# agachada: esquiva sai normalmente
	await _tap("crouch")
	await t._frames(5)
	await _dodge("move_left")
	t.check(p.moves.mode == "dodge" and p.model.state == "dodge_l", "agachada: esquiva sai", p.model.state)
	await t._frames(80)
	# mirando: esquiva sai (a mira desliga durante moves.busy())
	Input.action_press("aim")
	await t._frames(20)
	var was_aiming := p.aiming
	await _dodge("move_right")
	t.check(p.moves.mode == "dodge" and was_aiming, "mirando: esquiva sai e desliga a mira", p.model.state)
	await t._frames(80)
	Input.action_release("aim")
	# com arma longa (m16): esquiva sai e a pose é preservada (carregar)
	p.give_weapon("m16")
	await t._frames(5)
	await _dodge()
	await t._frames(10)
	var carry: float = p.model.tree.get("parameters/carry/blend_amount")
	t.check(p.moves.mode == "dodge" and carry > 0.5, "M16: esquiva mantém a pose de carregar", "carry=%.2f" % carry)
	await t._frames(80)
	# golpe durante hopping: cancel() zera hopping
	await _dodge("move_left")
	await t._frames(int(float(Moves.data().dodge.guard) / Moves.fps() * 60.0) - 4)
	t.check(p.hopping, "esquivando (ainda invulnerável)")
	p.knockback(Vector3(0, 0, 4))
	await t._frames(2)
	t.check(not p.hopping and p.moves.mode == "", "golpe durante esquiva: cancel() zera hopping", "hopping=%s mode=%s" % [p.hopping, p.moves.mode])
	await t._frames(60)
	# respawn durante esquiva: cancel() é chamado
	await _dodge()
	await t._frames(5)
	t.check(p.moves.mode == "dodge", "esquivando")
	p.respawn()
	await t._frames(2)
	t.check(p.moves.mode == "" and not p.hopping, "respawn cancela esquiva", "mode=%s hopping=%s" % [p.moves.mode, p.hopping])
	_release_all()
	p.queue_free()


## Clique duplo no X = cambalhota direto, sem o pulinho começar antes; um X só = espera a janela do clique duplo
## (já invulnerável) e pula; um segundo X depois da janela não faz nada.
func test_double_x_roll() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 4))
	await t._frames(10)
	var p0 := p.global_position
	await _press_x()
	t.check(p.moves.mode == "dodge_wait" and p.is_dodging() and not p.model.state.begins_with("dodge"), "primeiro X: espera o segundo clique, já invulnerável, sem começar o pulinho", p.model.state)
	await t._frames(4)
	await _press_x()
	t.check(p.moves.mode == "roll" and p.rolling and p.model.state == "roll", "clique duplo: cambalhota direto", p.moves.mode)
	var states := {}
	while p.moves.mode != "":
		states[p.model.state] = true
		await t._frames(1)
	t.check(not (states.has("dodge_back") or states.has("dodge_l") or states.has("dodge_r")), "clique duplo: nenhum quadro do pulinho", str(states.keys()))
	var moved := p.global_position - p0
	t.check(moved.z > 3.5 and absf(moved.x) < 0.2, "clique duplo parada: cambalhota para trás", "%.2f, %.2f" % [moved.x, moved.z])
	t.check(p._roll_cd > 0.0, "a cambalhota do clique duplo também conta o intervalo", str(p._roll_cd))
	await t._frames(90)
	await _dodge()
	t.check(p.moves.mode == "dodge", "um X só: passou a janela, pulinho")
	await t._frames(4)
	await _press_x()
	t.check(p.moves.mode == "dodge", "segundo X devagar (fora da janela): continua só o pulinho", p.moves.mode)
	await _until(func() -> bool: return p.moves.mode == "", 60)
	t.check(p.moves.mode == "", "e termina sem rolar")
	_release_all()
	p.queue_free()


## O pulinho na hora certa escapa da investida do raptor e da do alossauro (que vira bote quando chega perto);
## sem esquivar, as mesmas investidas pegam (o teste não passa à toa).
func test_dodge_beats_charges() -> void:
	for dodge in [false, true]:
		var w: Node3D = await t._fresh_world()
		var p: Player = t._spawn_player(w, Vector3(0, 0, 12))
		var r := Raptor.new()
		r.rotation.y = PI
		r.target = p
		w.add_child(r)
		r.rng.seed = 7
		await t._frames(10)
		r.start_charge(false)
		await _until(func() -> bool: return r.global_position.distance_to(p.global_position) < 3.0, 120)
		if dodge:
			await _dodge("move_left")
		await _until(func() -> bool: return r.state != "charge", 120)
		await t._frames(30)
		var hurt := p.health < 100 or p.model.is_ragdoll()
		t.check(hurt != dodge, "raptor: investida %s" % ("esquivada com o pulinho" if dodge else "acerta sem esquiva"), "vida=%d" % p.health)
		r.queue_free()
		p.queue_free()
	for dodge in [false, true]:
		var w: Node3D = await t._fresh_world()
		var p: Player = t._spawn_player(w, Vector3(0, 0, 16))
		var a := Allosaurus.new()
		a.rotation.y = PI
		a.target = p
		w.add_child(a)
		a.rng.seed = 7
		await t._frames(10)
		a.start_charge()
		# quem joga reage quando ele dá o bote (ou já está em cima)
		await _until(func() -> bool: return (a.state == "bite" and a._t > 0.15) or a.global_position.distance_to(p.global_position) < 3.2, 240)
		if dodge:
			await _dodge("move_left")
		await t._frames(90)
		var hurt := p.health < 100 or p.grabbed or p.model.is_ragdoll()
		t.check(hurt != dodge, "alossauro: investida/bote %s" % ("esquivado com o pulinho" if dodge else "pega sem esquiva"), "vida=%d estado=%s" % [p.health, a.state])
		a.queue_free()
		p.queue_free()
	_release_all()


func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await t._frames(1)
	return cond.call()


## No arcade nada mudou: tiro do quadril liga a mira, munição não gasta e a câmera é a de antes.
func test_arcade_unchanged() -> void:
	GameMode.set_mode(GameMode.ARCADE)
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(60)
	var rig := p.camera_rig
	t.check(absf(rig.spring.spring_length - 3.0) < 0.05 and absf(rig.spring.position.x) < 0.03, "arcade: câmera atrás dela como antes", "%f %f" % [rig.spring.spring_length, rig.spring.position.x])
	p.fire()
	t.check(p.shots_fired == 1 and p.aiming, "arcade: tiro do quadril liga a mira temporária")
	t.check(p.ammo_of("pistol") == 999, "arcade: munição não acaba")
	await t._frames(30)
	var yaw0 := rig.yaw
	Input.action_press("move_left")
	await t._frames(240)
	Input.action_release("move_left")
	t.check(absf(angle_difference(yaw0, rig.yaw)) > 0.2, "arcade: a câmera volta sozinha para trás dela", str(rig.yaw - yaw0))
	p.queue_free()
	GameMode.set_mode(GameMode.SURVIVAL)
