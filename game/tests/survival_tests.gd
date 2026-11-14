extends RefCounted
## Testes do perfil "survival" de GameMode (câmera por cima do ombro, só atira mirando, munição limitada e itens, cada arma
## muda o movimento, inimigos que machucam o dobro, cambalhota com intervalo) e conferência de que o "arcade" continua o
## de antes. Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá); o runner volta ao "arcade" no fim.

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	GameMode.set_mode(GameMode.SURVIVAL)
	await test_profiles()
	await test_enemy_damage()
	await test_aim_to_shoot_and_ammo()
	await test_reload()
	await test_weapon_ammo_and_collect()
	await test_pickup_in_world()
	await test_layout_clear()
	await test_weapon_movement()
	await test_aim_lock()
	await test_shoulder_camera()
	await test_back_walk()
	await test_smart_side()
	await test_camera_outside_scenery()
	await test_recoil_kick()
	await test_roll_cooldown()
	await test_survival_roll()
	await test_roll_edge_cases()
	await test_roll_beats_charges()
	await test_raptor_bite_damage()
	await test_pack_turns()
	await test_aim_turn_one_way()
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
	# os pentes extras do galpão são para os guardas de lá: contam os de fora (pátio, túnel, pedreira)
	var pistol_total := int(GameMode.START_AMMO.pistol)
	for e in Pickup.LAYOUT:
		if e.kind == "pistol" and Level.room_of(e.pos.x) != 0:
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
	t.check(p.health == 100 - Raptor.SURVIVAL_DAMAGE.tail, "survival: rabada do raptor pela tabela do survival", str(p.health))
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


## Pente e reserva (GameMode.MAGAZINE): o tiro gasta o pente; vazio com reserva, recarrega sozinha (animação por cima, o tiro
## espera); o botão recarrega o pente pela metade; trocar de arma corta a recarga.
func test_reload() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(10)
	t.check(p.mag_of("pistol") == 10 and p.reserve_of("pistol") == 0, "pistola começa com o pente cheio, sem reserva",
		"%d/%d" % [p.mag_of("pistol"), p.reserve_of("pistol")])
	t.check(p.collect("pistol", 10) and p.mag_of("pistol") == 10 and p.reserve_of("pistol") == 10, "pente extra no chão vai para a reserva")
	Input.action_press("aim")
	await t._frames(30)
	var gap := int(p.weapon_stats("pistol").cooldown * 60) + 2
	for i in 10:
		p.fire()
		await t._frames(gap)
	t.check(p.shots_fired == 10, "10 tiros no pente", str(p.shots_fired))
	await t._frames(2)
	t.check(p.reloading == "pistol" and p.model.tree.get("parameters/reload/active"), "pente vazio com reserva: recarrega sozinha (animação)",
		"recarregando '%s'" % p.reloading)
	p.fire()
	t.check(p.shots_fired == 10, "recarregando não atira")
	var dur := float(Moves.data().reload.pistol.frames) / Moves.fps()
	await t._frames(int(dur * 60) + 5)
	t.check(p.reloading == "" and p.mag_of("pistol") == 10 and p.reserve_of("pistol") == 0, "acabou a recarga: pente cheio da reserva",
		"%d/%d" % [p.mag_of("pistol"), p.reserve_of("pistol")])
	p.collect("pistol", 10)
	for i in 3:
		p.fire()
		await t._frames(gap)
	t.check(p.mag_of("pistol") == 7, "3 tiros: 7 no pente", str(p.mag_of("pistol")))
	Input.action_press("reload")
	await t._frames(2)
	Input.action_release("reload")
	await t._frames(int(dur * 60) + 5)
	t.check(p.mag_of("pistol") == 10 and p.reserve_of("pistol") == 7, "botão de recarregar completa o pente", "%d/%d" % [p.mag_of("pistol"), p.reserve_of("pistol")])
	# M16 do baú: pente cheio; trocar de arma no meio da recarga corta e o pente fica como estava
	p.give_weapon("m16")
	t.check(p.mag_of("m16") == GameMode.MAGAZINE.m16 and p.reserve_of("m16") == 0, "M16 do baú vem com o pente cheio (30)", "%d/%d" % [p.mag_of("m16"), p.reserve_of("m16")])
	t.check(p.collect_weapon("m16", 15) and p.reserve_of("m16") == 15, "M16 largado no chão (já tem): meio pente na reserva")
	await t._frames(30)
	p.fire()
	await t._frames(10)
	t.check(p.reload() and p.reloading == "m16", "M16 com 29: recarrega")
	p.switch_weapon()
	await t._frames(2)
	t.check(p.reloading == "" and p.mag_of("m16") == 29, "trocou de arma: a recarga para, o pente fica com 29", str(p.mag_of("m16")))
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
	var side_v := Vector2(p3.velocity.x, p3.velocity.z).length()
	t.check(p3.model.state == "strafe_fast_l" and absf(side_v - Moves.speed("strafe") * 1.8) < 0.05,
		"pistola mirando: passo lateral largo, na mesma velocidade de antes", "%s %.2f m/s" % [p3.model.state, side_v])
	var rate := float(p3.model.tree.get("parameters/strafe_fast_l_speed/scale"))
	t.check(rate > 0.85 and rate < 1.1, "o passo lateral largo toca perto do ritmo dele (sem trotinho)", "%.2fx" % rate)
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
	# parada, o analógico gira à vontade e a câmera fica onde foi deixada
	Input.action_release("aim")
	await t._frames(30)
	rig._look(Vector2(1.2, -0.3))
	var yaw0 := rig.yaw
	await t._frames(60)
	t.check(absf(angle_difference(yaw0, rig.yaw)) < 0.01, "survival: parada, a câmera fica onde o analógico a deixou", str(rig.yaw - yaw0))
	# andando também não gira sozinha atrás dela
	Input.action_press("move_left")
	await t._frames(120)
	Input.action_release("move_left")
	t.check(absf(angle_difference(yaw0, rig.yaw)) < 0.01, "survival: andando, a câmera não gira sozinha atrás dela", str(rig.yaw - yaw0))
	# mirando, não volta sozinha
	await t._frames(30)
	Input.action_press("aim")
	await t._frames(10)
	rig._look(Vector2(0.8, 0.0))
	var yaw_aim := rig.yaw
	Input.action_press("move_forward")
	await t._frames(60)
	Input.action_release("move_forward")
	Input.action_release("aim")
	t.check(absf(angle_difference(yaw_aim, rig.yaw)) < 0.01, "survival: mirando andando a câmera não volta sozinha", str(rig.yaw - yaw_aim))
	await t._frames(10)
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



## Survival: para trás ela anda de costas, sem virar; no arcade ela vira e corre.
func test_back_walk() -> void:
	for crouch in [false, true]:
		var w: Node3D = await t._fresh_world()
		var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
		await t._frames(30)
		p.crouching = crouch
		await t._frames(10)
		var yaw0 := p.rotation.y
		var back := p.global_basis.z
		var pos0 := p.global_position
		Input.action_press("move_back")
		await t._frames(90)
		var moved := (p.global_position - pos0).dot(back)
		var state := p.model.state
		Input.action_release("move_back")
		var label := "agachada" if crouch else "em pé"
		t.check(absf(angle_difference(yaw0, p.rotation.y)) < 0.05, "survival %s: para trás não vira" % label, str(angle_difference(yaw0, p.rotation.y)))
		var gait_speed := Moves.speed("crouch_walk") * Player.CROUCH_WALK_SCALE if crouch else Moves.speed("walk")
		t.check(moved > 0.8 and moved < gait_speed * 1.6, "survival %s: anda de costas devagar" % label, "%.2f m" % moved)
		t.check(state == ("crouch_walk" if crouch else "walk"), "survival %s: andar ao contrário" % label, state)
		p.queue_free()
	GameMode.set_mode(GameMode.ARCADE)
	var w2: Node3D = await t._fresh_world()
	var p2: Player = t._spawn_player(w2, Vector3(0, 0, 6))
	await t._frames(30)
	var yaw1 := p2.rotation.y
	Input.action_press("move_back")
	await t._frames(60)
	Input.action_release("move_back")
	t.check(absf(angle_difference(yaw1, p2.rotation.y)) > 2.5, "arcade: para trás ela vira e corre como antes", str(angle_difference(yaw1, p2.rotation.y)))
	p2.queue_free()
	GameMode.set_mode(GameMode.SURVIVAL)



## Survival sem mirar: ombro direito; andando não troca; só passa para o esquerdo com parede/caixa fechando a direita da
## frente dela, e volta ao direito quando acaba; girar a câmera para o lado dela puxa quase para o centro e volta; mirando,
## sempre o direito.
func test_smart_side() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(40)
	var rig := p.camera_rig
	var on_right := func() -> bool: return rig.side_goal == 1.0 and rig.spring.position.x > 0.5
	var on_left := func() -> bool: return rig.side_goal == -1.0 and rig.spring.position.x < -0.4
	t.check(on_right.call(), "lado: começa no ombro direito", str(rig.spring.position.x))
	# andando para a esquerda (aberto): continua no ombro direito
	Input.action_press("move_left")
	var walk_min := 1.0
	for i in 120:
		await t._frames(1)
		walk_min = minf(walk_min, rig.spring.position.x)
	Input.action_release("move_left")
	t.check(walk_min > 0.5, "lado: andando para a esquerda não troca de ombro", "%.2f" % walk_min)
	# girando a câmera andando: também não troca
	Input.action_press("move_forward")
	await t._frames(20)
	rig._look(Vector2(-0.4, 0.0))
	await t._frames(60)
	Input.action_release("move_forward")
	t.check(rig.side_goal == 1.0, "lado: girar a câmera andando não troca de ombro")
	await t._frames(30)
	# parede colada à direita: o ombro vai para o esquerdo
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2.6, 3.0)
	shape.shape = box
	wall.add_child(shape)
	w.add_child(wall)
	var right := rig.yaw_basis().x
	wall.global_position = p.global_position + right * 0.75 + Vector3.UP * 1.3
	wall.global_rotation.y = rig.yaw
	await t._frames(20)
	t.check(rig.side_goal == 1.0, "lado: parede de passagem não troca na hora")
	await t._frames(20)
	t.check(rig.side < 1.0 and rig.side > -0.9, "lado: a troca sai devagar, sem pular", "%.2f" % rig.side)
	await t._frames(110)
	t.check(on_left.call(), "lado: parede à direita, a câmera vai para o ombro esquerdo", "%.1f %.2f" % [rig.side_goal, rig.spring.position.x])
	# a parede saiu: volta ao ombro direito
	wall.queue_free()
	await t._frames(150)
	t.check(on_right.call(), "lado: sem a parede, volta ao ombro direito", "%.1f %.2f" % [rig.side_goal, rig.spring.position.x])
	# agachada na quina esquerda da caixa em que se esconde (caixa na frente, para a direita): abre a esquerda
	p.crouching = true
	var crate := StaticBody3D.new()
	var cshape := CollisionShape3D.new()
	var cbox := BoxShape3D.new()
	cbox.size = Vector3(2.4, 1.5, 1.0)
	cshape.shape = cbox
	crate.add_child(cshape)
	w.add_child(crate)
	right = rig.yaw_basis().x
	var fwd := -rig.yaw_basis().z
	crate.global_position = p.global_position + right * 1.2 + fwd * 0.9 + Vector3.UP * 0.75
	crate.global_rotation.y = rig.yaw
	await t._frames(150)
	t.check(on_left.call(), "lado: agachada na quina esquerda da caixa da frente, abre a esquerda", "%.1f %.2f" % [rig.side_goal, rig.spring.position.x])
	# caixa da frente inteira (parede reta na frente): os dois lados fechados, fica no direito
	crate.global_position = p.global_position + fwd * 0.9 + Vector3.UP * 0.75
	cbox.size = Vector3(8.0, 1.5, 1.0)
	await t._frames(150)
	t.check(on_right.call(), "lado: parede reta na frente, fica no ombro direito", "%.1f %.2f" % [rig.side_goal, rig.spring.position.x])
	w.remove_child(crate)
	p.crouching = false
	await t._frames(150)
	# o caso da captura: agachada na quina DIREITA da caixa (caixa à esquerda dela), o corpo virado para a direita da câmera,
	# a câmera olhando ao longo da caixa: o lado aberto é o direito, fica no ombro direito
	p.crouching = true
	p.rotation.y = rig.yaw - 0.6
	var body := Basis(Vector3.UP, p.rotation.y)
	w.add_child(crate)
	cbox.size = Vector3(2.4, 1.5, 1.0)
	crate.global_position = p.global_position - body.x * 1.3 + (-body.z) * 0.5 + Vector3.UP * 0.75
	crate.global_rotation.y = p.rotation.y
	await t._frames(150)
	t.check(on_right.call(), "lado: caixa à esquerda dela, virada para a direita: fica no ombro direito", "%.1f %.2f" % [rig.side_goal, rig.spring.position.x])
	crate.queue_free()
	p.crouching = false
	await t._frames(30)
	# girando a câmera para a esquerda (para o lado dela na tela): a mola a puxa quase para o centro e abre o quadro
	var min_x := 1.0
	var max_fov := 0.0
	for i in 40:
		rig._look(Vector2(-0.04, 0.0))  # 2,4 rad/s
		await t._frames(1)
		min_x = minf(min_x, rig.spring.position.x)
		max_fov = maxf(max_fov, rig.camera.fov)
	t.check(min_x < 0.25 and max_fov > CameraRig.SHOULDER.fov + 4.0 and rig.side_goal == 1.0, "giro para a esquerda: quase centraliza e abre o quadro, sem trocar de ombro", "%.2f %.1f" % [min_x, max_fov])
	await t._frames(90)
	t.check(rig.spring.position.x > 0.5 and absf(rig.camera.fov - CameraRig.SHOULDER.fov) < 1.0, "parou de girar: volta ao ombro direito", "%.2f %.1f" % [rig.spring.position.x, rig.camera.fov])
	# girando para a direita: fica no ombro
	min_x = 1.0
	for i in 40:
		rig._look(Vector2(0.04, 0.0))
		await t._frames(1)
		min_x = minf(min_x, rig.spring.position.x)
	t.check(min_x > 0.5, "giro para a direita: não puxa", "%.2f" % min_x)
	# mirando: sem o efeito, sempre o ombro direito
	Input.action_press("aim")
	await t._frames(60)
	min_x = 1.0
	for i in 40:
		rig._look(Vector2(-0.04, 0.0))
		await t._frames(1)
		min_x = minf(min_x, rig.spring.position.x)
	Input.action_release("aim")
	t.check(absf(min_x - CameraRig.SHOULDER.side_aim) < 0.05, "lado: mirando, sem o puxão, sempre o ombro direito", "%.2f" % min_x)
	p.queue_free()


## A câmera nunca fica dentro do cenário: colada numa caixa baixa ao lado dela e num canto de paredes altas, em pé, agachada
## e mirando, girando em volta dela e olhando para baixo/para cima (o desvio do ombro e o pivô atrasado também desviam).
func test_camera_outside_scenery() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	await t._frames(20)
	var rig := p.camera_rig
	var boxes: Array[StaticBody3D] = []
	var add_box := func(size: Vector3, at: Vector3) -> void:
		var b := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		b.add_child(cs)
		w.add_child(b)
		b.global_position = p.global_position + at + Vector3.UP * size.y * 0.5
		boxes.append(b)
	var probe := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.05
	probe.shape = ball
	probe.collision_mask = 1
	var space := p.get_world_3d().direct_space_state
	var setups := {
		"caixa baixa à direita": [[Vector3(1.0, 1.5, 2.4), Vector3(0.85, 0, 0)]],
		"canto de paredes altas": [[Vector3(0.3, 2.7, 4.0), Vector3(0.6, 0, 0)], [Vector3(4.0, 2.7, 0.3), Vector3(0, 0, -0.6)]],
	}
	for setup: String in setups:
		for b in boxes:
			b.queue_free()
		boxes.clear()
		for spec: Array in setups[setup]:
			add_box.call(spec[0], spec[1])
		var bad := 0
		var first := ""
		for state: String in ["em pé", "agachada", "mirando"]:
			p.crouching = state == "agachada"
			if state == "mirando":
				Input.action_press("aim")
			for step in 8:
				for pt: float in [-0.6, -0.1, 0.95]:
					rig.yaw = TAU * step / 8.0
					rig.pitch = pt
					for f in 10:
						await t._frames(1)
						probe.transform = Transform3D(Basis(), rig.camera.global_position)
						if not space.intersect_shape(probe, 1).is_empty():
							bad += 1
							if first == "":
								first = "%s giro %d° incl. %.1f" % [state, step * 45, pt]
			Input.action_release("aim")
			p.crouching = false
		t.check(bad == 0, "câmera fora do cenário: " + setup, "%d quadros dentro (%s)" % [bad, first])
	for b in boxes:
		b.queue_free()
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
	await _press_x()
	t.check(p.moves.mode == "roll" and p.rolling, "survival: o botão faz a cambalhota (sem pulinho de esquiva)", p.moves.mode)
	await t._frames(_roll_frames())
	t.check(p.moves.mode == "", "cambalhota termina")
	await _press_x()
	t.check(p.moves.mode == "" and p._roll_cd > 0.0, "survival: não encadeia cambalhota (intervalo)", str(p._roll_cd))
	await t._frames(60)
	await _press_x()
	t.check(p.moves.mode == "roll", "passado o intervalo, rola de novo")
	GameMode.set_mode(GameMode.ARCADE)
	await t._frames(110)
	await _press_x()
	t.check(p.moves.mode == "roll" and p._roll_cd <= 0.0, "arcade: cambalhota na hora, sem intervalo")
	GameMode.set_mode(GameMode.SURVIVAL)
	p.queue_free()


## Quadros (a 60 por segundo) da cambalhota inteira, com folga.
func _roll_frames() -> int:
	return int(float(Moves.data().roll.frames) / Moves.fps() * 60.0) + 6


## Um clique no botão de rolar (com `dir` = ação de direção segurada junto, ou nenhuma).
func _press_x(dir := "") -> void:
	if dir:
		Input.action_press(dir)
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	if dir:
		Input.action_release(dir)


## Survival: parada rola para a frente, com direção rola para lado pedido; mergulho de ~2,6 m.
func test_survival_roll() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 10))
	await t._frames(10)
	var p0 := p.global_position
	await _press_x()
	t.check(p.moves.mode == "roll" and p.model.state == "roll" and p.is_dodging(), "survival: parada, rola para a frente", p.model.state)
	await t._frames(_roll_frames())
	var moved := p.global_position - p0
	t.check(p.moves.mode == "" and moved.z < -2.2 and moved.z > -2.9 and absf(moved.x) < 0.1, "cambalhota para a frente: ~2,6 m", "%.2f, %.2f" % [moved.x, moved.z])
	await t._frames(90)
	p0 = p.global_position
	await _press_x("move_left")
	await t._frames(_roll_frames())
	var side := p.global_position - p0
	t.check(side.x < -2.2 and side.x > -2.9 and absf(side.z) < 0.2, "esquerda + rolar = rola para a esquerda", "%.2f, %.2f" % [side.x, side.z])
	_release_all()
	p.queue_free()


## Casos de borda: no ar (não sai), agachada e mirando (sai), reinício no meio (cancela).
func test_roll_edge_cases() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 10))
	await t._frames(10)
	await _tap("jump")
	await t._frames(10)
	t.check(not p.is_on_floor(), "no ar")
	await _press_x()
	t.check(p.moves.mode == "" and not p.rolling, "no ar: cambalhota não sai", p.moves.mode)
	await t._frames(90)
	await _tap("crouch")
	await t._frames(5)
	await _press_x("move_left")
	t.check(p.moves.mode == "roll" and not p.crouching, "agachada: cambalhota sai", p.moves.mode)
	await t._frames(_roll_frames() + 30)
	Input.action_press("aim")
	await t._frames(20)
	var was_aiming := p.aiming
	await _press_x("move_right")
	t.check(p.moves.mode == "roll" and was_aiming, "mirando: cambalhota sai", p.moves.mode)
	Input.action_release("aim")
	await t._frames(_roll_frames() + 30)
	await _press_x()
	await t._frames(5)
	t.check(p.moves.mode == "roll", "rolando")
	p.respawn()
	await t._frames(2)
	t.check(p.moves.mode == "" and not p.rolling, "reinício cancela a cambalhota", "mode=%s rolando=%s" % [p.moves.mode, p.rolling])
	_release_all()
	p.queue_free()


## A cambalhota na hora certa escapa da investida do raptor e da do alossauro (que vira bote quando chega perto);
## sem rolar, as mesmas investidas pegam (o teste não passa à toa).
func test_roll_beats_charges() -> void:
	for roll in [false, true]:
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
		if roll:
			await _press_x("move_left")
		await _until(func() -> bool: return r.state != "charge", 120)
		await t._frames(30)
		var hurt := p.health < 100 or p.model.is_ragdoll()
		t.check(hurt != roll, "raptor: investida %s" % ("escapada rolando" if roll else "acerta sem rolar"), "vida=%d" % p.health)
		r.queue_free()
		p.queue_free()
	for roll in [false, true]:
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
		if roll:
			await _press_x("move_left")
		await t._frames(90)
		var hurt := p.health < 100 or p.grabbed or p.model.is_ragdoll()
		t.check(hurt != roll, "alossauro: investida/bote %s" % ("escapado rolando" if roll else "pega sem rolar"), "vida=%d estado=%s" % [p.health, a.state])
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


## Agarrão inteiro do raptor (sem se debater) tira no máximo ~1/4 da vida.
func test_raptor_bite_damage() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 1.6))
	var r := Raptor.new()
	r.rotation.y = PI
	r.target = p
	w.add_child(r)
	await t._frames(3)
	r.start_bite()
	for i in 40:
		if p.grabbed:
			break
		await t._frames(1)
	t.check(p.grabbed, "survival: mordida agarra")
	for i in 200:
		if not p.grabbed:
			break
		await t._frames(1)
	t.check(not p.grabbed and p.health >= 100 - 4 * Raptor.SURVIVAL_DAMAGE.bite and p.health < 100, "survival: agarrão inteiro tira até 24", str(p.health))


## Matilha: 3 raptors em volta dela atacam um de cada vez, com intervalo entre um ataque e o próximo, e os que esperam
## ficam parados em lugares espalhados em volta dela, observando (Study), sem rodear.
func test_pack_turns() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 0))
	var pack: Array[Raptor] = []
	for i in 3:
		var r := Raptor.new()
		var a := TAU * i / 3.0
		r.position = Vector3(sin(a), 0, cos(a)) * 5.0
		r.rotation.y = a
		r.target = p
		w.add_child(r)
		r.rng.seed = 11 + i  # depois do add_child: o _ready do Enemy sorteia a semente (rng.randomize())
		pack.append(r)
	await t._frames(3)
	for r in pack:
		r.end_ambush()
	var most := 0
	var starts := 0
	var gap_min := INF
	var last_end := -INF
	var busy_before := false
	var spread_min := INF
	var pairs := 0
	var wait_frames := 0
	var still_frames := 0
	var her_at := p.global_position
	var her_still := 0.0  # há quanto tempo ela não sai do lugar (golpe que a arremessa muda os lugares deles)
	for f in 60 * 20:
		await t._frames(1)
		p.health = 100  # só a coordenação importa aqui
		var busy := pack.filter(func(r: Raptor) -> bool: return r.state in Raptor.ATTACKS)
		most = maxi(most, busy.size())
		var now := Raptor._now()
		if not busy.is_empty() and not busy_before:
			starts += 1
			if last_end > -INF:
				gap_min = minf(gap_min, now - last_end)
		if busy.is_empty() and busy_before:
			last_end = now
		busy_before = not busy.is_empty()
		# os que esperam a vez há um tempo: espalhados em volta dela (nenhum par colado do mesmo lado)
		var waiting := pack.filter(func(r: Raptor) -> bool: return r._waiting and r._turn_wait > 1.5)
		if p.global_position.distance_to(her_at) > 0.3:
			her_at = p.global_position
			her_still = 0.0
		her_still += 1.0 / 60.0
		for r: Raptor in waiting.filter(func(_r: Raptor) -> bool: return her_still > 3.0):
			wait_frames += 1
			if Vector2(r.velocity.x, r.velocity.z).length() < 0.15 and r.model.current == "Study":
				still_frames += 1
		for i in waiting.size():
			for j in range(i + 1, waiting.size()):
				var u: Vector3 = waiting[i].global_position - p.global_position
				var v: Vector3 = waiting[j].global_position - p.global_position
				u.y = 0.0
				v.y = 0.0
				spread_min = minf(spread_min, absf(u.signed_angle_to(v, Vector3.UP)))
				pairs += 1
	t.check(most == 1, "matilha: só um ataca por vez", str(most))
	t.check(starts >= 3, "matilha: os ataques continuam vindo", str(starts))
	t.check(gap_min >= Raptor.PACK_GAP.x - 0.6, "matilha: espera entre um ataque e o próximo", "%.2f s" % gap_min)
	t.check(pairs > 60 and spread_min > deg_to_rad(60.0), "matilha: quem espera cerca espalhado", "%.0f° (%d)" % [rad_to_deg(spread_min), pairs])
	# o que sobra é quem anda até o lugar novo depois do próprio ataque (Walk a SLOT_SPEED pela beira da faixa), não rodear
	t.check(wait_frames > 120 and still_frames > wait_frames * 0.85, "matilha: quem espera fica parado observando (não rodeia)", "%d/%d" % [still_frames, wait_frames])


## Giro da mira quase de costas: o lado do giro escolhido no começo segue até o fim, mesmo com o alvo pulando para o outro
## lado do "de costas" no meio (ponto sob a retícula perto de parede); sem volta inteira.
func test_aim_turn_one_way() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 0))
	await t._frames(5)
	p.process_mode = Node.PROCESS_MODE_DISABLED  # só o giro, chamado à mão
	p.rotation.y = 0.0
	var travel := 0.0
	var last := 0.0
	var signs := {}
	for f in 60:
		# o alvo fica em 178° e -178° alternando nos primeiros quadros (de costas para ela, um lado e o outro)
		var yaw := deg_to_rad(178.0 if f % 2 == 0 or f > 6 else -178.0)
		p._face_aim(Vector3(-sin(yaw), 0, -cos(yaw)), 1.0 / 60.0)
		var step := wrapf(p.rotation.y - last, -PI, PI)
		if absf(step) > 0.0001:
			signs[signf(step)] = true
		travel += absf(step)
		last = p.rotation.y
	t.check(signs.size() == 1 and travel < deg_to_rad(200.0) and absf(wrapf(p.rotation.y - deg_to_rad(178.0), -PI, PI)) < 0.05,
		"giro da mira de costas: um lado só, sem volta inteira", "%.0f° percorridos, lados %s" % [rad_to_deg(travel), str(signs.keys())])
	p.queue_free()
