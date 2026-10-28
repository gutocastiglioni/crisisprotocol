extends RefCounted
## Testes de abate furtivo pelas costas (humanos e velociraptors), queda de 70% de dano no velociraptor ("down"),
## golpe crítico em sequência ("crit_strike"), contra-ataque ao levantar ("counter") e aviso no HUD.
## Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá).

var t: SceneTree


func run(runner: SceneTree) -> void:
	t = runner
	await test_animations_and_moves_data()
	await test_hud_prompts_and_boundaries()
	await test_soldier_stealth_assassination()
	await test_raptor_stealth_knockdown_and_crit_strike()
	await test_raptor_getup_counterattack()
	await test_cancel_and_reset_edge_cases()


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func _wall(w: Node3D, pos: Vector3, size := Vector3(10, 4, 0.4)) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	wall.add_child(col)
	wall.position = pos
	w.add_child(wall)
	return wall


func _spawn_pair(player_pos: Vector3, enemy_kind: String, enemy_pos := Vector3.ZERO, enemy_yaw := PI) -> Array:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, player_pos)
	p.rotation.y = PI
	var e: Enemy
	match enemy_kind:
		"soldier":
			e = Soldier.new()
		"raptor":
			e = Raptor.new()
		"allosaurus":
			e = Allosaurus.new()
	e.position = enemy_pos
	e.rotation.y = enemy_yaw
	e.target = p
	w.add_child(e)
	e.rng.seed = 17
	await t._frames(3)
	return [p, e, w]


func test_animations_and_moves_data() -> void:
	var d := Moves.data()
	for k in ["assassinate", "crit_strike"]:
		check(d.has(k) and int(d[k].frames) > int(d[k].hit) and int(d[k].hit) > 0, "Moves.data() contém " + k, str(d.get(k)))
	for asset_path in ["res://assets/characters/heroine.glb", "res://assets/characters/guerrilla.glb"]:
		var inst: Node = (load(asset_path) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		for anim in ["Assassinate", "CritStrike"]:
			check(ap.has_animation(anim) and ap.get_animation(anim).length > 0.4, "%s tem animação %s" % [asset_path.get_file(), anim])
		inst.free()


func test_hud_prompts_and_boundaries() -> void:
	# Atrás do soldado calmo a 1,6 m: abate furtivo disponível
	var ps := await _spawn_pair(Vector3(0, 0, -1.6), "soldier")
	var p: Player = ps[0]
	var s: Soldier = ps[1]
	var w: Node3D = ps[2]
	p.stealth.update(0.016)
	check(s.can_assassinate(p) and p.stealth_target() == s, "atrás do soldado calmo: elegível para abate furtivo")
	check(p.stealth_prompt() == PlayerStealth.ASSASSINATE_PROMPT, "HUD prompt de abate furtivo", p.stealth_prompt())

	# Mirando: desativa abate furtivo
	Input.action_press("aim")
	check(p.stealth_target() == null and p.stealth_prompt() == "", "mirando (Input): abate furtivo indisponível")
	Input.action_release("aim")
	p.aiming = true
	check(p.stealth_target() == null and p.stealth_prompt() == "", "mirando (p.aiming): abate furtivo indisponível")
	p.aiming = false

	# Fora do alcance (> Enemy.ASSASSINATE_RANGE = 2.2 m) ou colada demais (< 0.05 m)
	p.global_position = Vector3(0, 0, -2.5)
	check(not s.can_assassinate(p) and p.stealth_target() == null, "além de ASSASSINATE_RANGE (2,5 m): indisponível")
	p.global_position = Vector3(0, 0, -0.02)
	check(not s.can_assassinate(p), "distância < 0,05 m: indisponível")

	# Na frente do inimigo (dentro do cone de visão)
	p.global_position = Vector3(0, 0, 1.5)
	check(not s.can_assassinate(p) and p.stealth_target() == null, "na frente do soldado: abate furtivo indisponível")

	# Parede entre a heroína e o inimigo bloqueia o golpe
	p.global_position = Vector3(0, 0, -1.6)
	var wall := _wall(w, Vector3(0, 1.5, -0.8))
	await t._frames(2)
	check(not s.can_assassinate(p) and p.stealth_target() == null, "parede no meio: abate furtivo bloqueado")
	wall.free()
	await t._frames(2)
	check(s.can_assassinate(p), "sem parede: abate furtivo volta a ficar disponível")

	# Inimigo alertado ou em combate não aceita abate furtivo
	s.alert_t = 5.0
	check(not s.can_assassinate(p), "inimigo com alert_t > 0: abate furtivo indisponível")
	s.alert_t = 0.0
	s.start_engage()
	check(s.in_combat() and not s.can_assassinate(p), "inimigo em combate: abate furtivo indisponível")
	s.reset()
	await t._frames(2)

	# Estados incapacitados da jogadora bloqueiam o alvo furtivo
	p.daze(1.0)
	check(p.stealth_target() == null, "jogadora atordoada (daze): sem alvo furtivo")
	p._daze = 0.0

	# Dois inimigos ao alcance: escolhe o mais próximo
	var r := Raptor.new()
	r.position = Vector3(0.4, 0, -1.1)
	r.rotation.y = PI
	r.target = p
	w.add_child(r)
	await t._frames(2)
	p.global_position = Vector3(0, 0, -2.0)
	check(p.stealth_target() == r, "dois inimigos ao alcance: escolhe o mais próximo")

	# Alossauro nunca aceita abate furtivo nem golpe crítico
	var pa := await _spawn_pair(Vector3(0, 0, -1.8), "allosaurus")
	var p_allo: Player = pa[0]
	var allo: Allosaurus = pa[1]
	check(not allo.can_stealth and not allo.can_assassinate(p_allo) and not allo.can_crit_strike(p_allo), "alossauro nunca aceita abate furtivo ou golpe crítico")
	check(p_allo.stealth_target() == null and p_allo.stealth_prompt() == "", "atrás do alossauro: sem prompt furtivo")

	# Integração com o HUD da cena principal (main.tscn)
	if t._world:
		t._world.queue_free()
		t._world = null
		await t.process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(3)
	var mp: Player = main.player
	var msd: Soldier = main.soldiers[0]
	msd.route.clear()
	msd._enter("idle", "Idle")
	msd.global_position = Vector3(0, 0, 2)
	msd.rotation.y = 0.0
	mp.global_position = Vector3(0, 0, 3.5)
	mp.rotation.y = 0.0
	main._notice_t = 0.0
	await t._frames(2)
	main._process(0.016)
	var shoot_glyph: Dictionary = UiStyle.glyph("shoot")
	check(main._prompt.visible and main._prompt.text() == PlayerStealth.ASSASSINATE_PROMPT and main._prompt.items[0].action == "shoot",
		"main.gd mostra o botão de atirar com ABATE FURTIVO", "%s %s" % [main._prompt.text(), shoot_glyph])
	check(not main._hud_notice.visible, "o abate furtivo não repete na faixa de avisos", main._hud_notice.text)
	var mr: Raptor = main.raptors[0]
	mr.reset()  # fora da moita da emboscada
	mr.route.clear()
	mr.global_position = Vector3(0, 0, 2)
	mr.start_down()
	msd.global_position = Vector3(10, 0, -10)
	await t._frames(2)
	main._process(0.016)
	check(main._prompt.visible and main._prompt.text() == PlayerStealth.CRIT_PROMPT, "main.gd mostra o botão de atirar com GOLPE CRÍTICO", main._prompt.text())
	mr.global_position = Vector3(10, 0, -10)
	main._process(0.016)
	check(not main._prompt.visible, "main.gd oculta imediatamente o botão furtivo/crítico quando sai do alcance")
	main.queue_free()
	await t.process_frame


func test_soldier_stealth_assassination() -> void:
	GameMode.set_mode(GameMode.SURVIVAL)
	var ps := await _spawn_pair(Vector3(0, 0, -1.6), "soldier")
	var p: Player = ps[0]
	var s: Soldier = ps[1]
	var w: Node3D = ps[2]
	# Outros inimigos na mesma sala para provar que o abate é 100% silencioso
	var guard2 := Soldier.new()
	guard2.position = Vector3(4, 0, -2)
	guard2.rotation.y = PI
	guard2.target = p
	w.add_child(guard2)
	var rap := Raptor.new()
	rap.position = Vector3(-4, 0, -2)
	rap.rotation.y = PI
	rap.target = p
	w.add_child(rap)
	await t._frames(2)

	# Mesmo sem munição no modo survival, o botão de atirar sem mirar executa o abate furtivo
	p.ammo["pistol"] = 0
	var killed := [false]
	s.killed.connect(func() -> void: killed[0] = true)
	p.fire()
	check(p.moves.mode == "assassinate" and p.model.state == "assassinate", "atirar sem mirar atrás do soldado inicia assassinate", p.moves.mode)
	check(p.model.holstered and not p.model.is_weapon_visible("pistol"), "guarda a arma durante o abate furtivo")
	check(s._stealth_locked, "soldado fica travado no lugar durante o golpe")
	check(p.is_dodging(), "heroína fica invulnerável durante a execução do golpe")
	check(p.shots_fired == 0 and p.ammo_of("pistol") == 0, "abate furtivo não gasta munição nem conta como tiro")

	var total_frames := int(float(Moves.data().assassinate.frames) / Moves.fps() * 60.0) + 6
	await t._frames(total_frames)
	check(s.dead and s.health == 0 and s.state == "dead" and killed[0], "soldado morre na hora (100% da vida) com o abate furtivo", "vida=%d estado=%s" % [s.health, s.state])
	check(s.model.is_ragdoll() and s.collision_layer == 0, "soldado abatido vira ragdoll")
	check(p.moves.mode == "" and not p.model.holstered and p.model.is_weapon_visible("pistol"), "ao terminar o abate, a arma volta para a mão")
	check(guard2.alert_level() == 0 and guard2.aware == 0.0 and rap.alert_level() == 0 and rap.aware == 0.0, "abate furtivo é silencioso: outros inimigos na sala continuam calmos")
	# Boneco de treino (TargetDummy): abate furtivo funciona nos bonecos de teste e derruba a chave se tiver
	var dummy := TargetDummy.new()
	dummy.position = Vector3(0, 0, -5.0)
	w.add_child(dummy)
	var key := KeyItem.new()
	w.add_child(key)
	dummy.loot = key
	p.global_position = Vector3(0, 0, -3.5)
	await t._frames(3)
	check(dummy.can_assassinate(p) and p.stealth_target() == dummy and p.stealth_prompt() == PlayerStealth.ASSASSINATE_PROMPT, "boneco de treino aceita abate furtivo e exibe aviso no HUD")
	check(not p.crouching and p.model.state != "crouch", "abate furtivo começado em pé termina em pé")
	p.crouching = true
	p.fire()
	check(p.moves.mode == "assassinate", "atirar sem mirar no boneco de treino inicia assassinate")
	await t._frames(total_frames)
	check(dummy.dead and dummy.model.is_ragdoll() and key.state == "dropped", "boneco de treino morre em ragdoll no abate furtivo e solta a chave")
	check(p.crouching and p.model.state == "crouch", "abate furtivo começado agachada termina agachada", p.model.state)
	GameMode.set_mode(GameMode.ARCADE)


func test_raptor_stealth_knockdown_and_crit_strike() -> void:
	var pr := await _spawn_pair(Vector3(0, 0, -1.6), "raptor")
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var w: Node3D = pr[2]
	var other := Raptor.new()
	other.position = Vector3(5, 0, -2)
	other.rotation.y = PI
	other.target = p
	w.add_child(other)
	await t._frames(2)

	var killed := [false]
	r.killed.connect(func() -> void: killed[0] = true)

	# 1º golpe furtivo pelas costas: tira 70% da vida (119 de 170, sobrando 51) e derruba em "down"
	p.fire()
	check(p.moves.mode == "assassinate", "1º ataque sem mirar no raptor inicia assassinate", p.moves.mode)
	var assassinate_frames := int(float(Moves.data().assassinate.frames) / Moves.fps() * 60.0) + 6
	await t._frames(assassinate_frames)
	var expected_hp := Raptor.MAX_HEALTH - roundi(Raptor.MAX_HEALTH * 0.7)
	check(not r.dead and r.health == expected_hp, "raptor perde 70%% da vida no abate furtivo (%d -> %d)" % [Raptor.MAX_HEALTH, r.health])
	check(r.state == "down" and not r.in_combat(), "raptor cai atordoado no estado down", r.state)
	check(other.alert_level() == 0 and other.aware == 0.0, "derrubar o raptor no furtivo não alerta os outros")
	check(not r.can_assassinate(p) and r.can_crit_strike(p), "raptor caído: can_crit_strike é true e can_assassinate é false")
	p.stealth.update(0.016)
	check(p.stealth_prompt() == PlayerStealth.CRIT_PROMPT, "HUD avisa GOLPE CRÍTICO perto do raptor caído", p.stealth_prompt())

	# Mesmo pela frente do raptor caído, o golpe crítico está disponível (qualquer direção até CRIT_RANGE)
	p.global_position = r.global_position + Vector3(0, 0, 1.5)
	check(r.can_crit_strike(p), "golpe crítico funciona de qualquer direção perto do raptor caído")
	p.global_position = r.global_position + Vector3(0, 0, -1.4)

	# Quase no fim do tempo no chão: iniciar o 2º golpe trava o raptor para não contra-atacar no meio da animação
	r._t = Raptor.DOWN_TIME - 0.03
	p.crouching = true
	p.fire()
	check(p.moves.mode == "crit_strike" and p.model.state == "crit_strike", "2º ataque sem mirar inicia crit_strike", p.moves.mode)
	check(r._stealth_locked, "crit_strike trava o raptor caído para impedir contra-ataque durante o golpe")
	await t._frames(4)
	check(r.state == "down" and p.health == 100, "raptor travado não entra em counter no meio do crit_strike", r.state)

	var crit_frames := int(float(Moves.data().crit_strike.frames) / Moves.fps() * 60.0) + 6
	await t._frames(crit_frames)
	check(r.dead and r.health == 0 and r.state == "dead" and killed[0], "golpe crítico em sequência mata o velociraptor", "vida=%d estado=%s" % [r.health, r.state])
	check(r.model.is_ragdoll() and r.collision_layer == 0, "velociraptor finalizado vira ragdoll")
	check(p.crouching and p.model.state == "crouch", "golpe crítico começado agachada termina agachada", p.model.state)
	check(other.alert_level() == 0 and other.aware == 0.0, "finalização com golpe crítico também é silenciosa")

	# Se o raptor já estava muito ferido (<= 70% da vida), o primeiro abate furtivo já o mata direto
	var pr2 := await _spawn_pair(Vector3(0, 0, -1.6), "raptor")
	var r2: Raptor = pr2[1]
	r2.health = 80
	r2.assassinate(Vector3.FORWARD)
	check(r2.dead and r2.health == 0 and r2.state == "dead", "raptor já ferido morre direto no abate furtivo")


func test_raptor_getup_counterattack() -> void:
	# Caso 1: não finalizou a tempo e continuou perto (< COUNTER_REACH) -> contra-ataque acerta, derruba e dá alarme
	var pr := await _spawn_pair(Vector3(0, 0, -1.5), "raptor")
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var w: Node3D = pr[2]
	var ally := Soldier.new()
	ally.position = Vector3(6, 0, -2)
	ally.rotation.y = PI
	ally.target = p
	w.add_child(ally)
	await t._frames(2)

	var attacks: Array[String] = []
	r.attacked.connect(func(kind: String) -> void: attacks.append(kind))
	r.assassinate(Vector3.FORWARD)
	check(r.state == "down" and r._dur == Raptor.DOWN_TIME, "raptor caído por DOWN_TIME (3,0 s)")
	r._t = Raptor.DOWN_TIME - 0.05
	await t._frames(6)
	check(r.state == "counter" and r.alert_t > 0.0, "ao expirar DOWN_TIME sem golpe crítico, entra em counter e dá o alarme", r.state)
	check(ally.alert_t > 0.0, "contra-ataque do raptor alerta os outros inimigos da sala")
	for i in 60:
		await t._frames(1)
		if "counter" in attacks:
			break
	check("counter" in attacks, "contra-ataque desfere o golpe counter", str(attacks))
	check(p.health == 100 - Raptor.DAMAGE.counter, "contra-ataque causa dano na heroína", str(p.health))
	check(p._down_t > 0.0 and p.model.is_ragdoll(), "contra-ataque derruba a heroína no chão (launch/ragdoll)")
	for i in 90:
		await t._frames(1)
		if r.state == "study":
			break
	check(r.state == "study", "após o contra-ataque, o raptor entra em study", r.state)

	# Caso 2: a heroína se afasta (> COUNTER_REACH) antes do raptor levantar -> ele levanta sem acertá-la
	var pr2 := await _spawn_pair(Vector3(0, 0, -1.5), "raptor")
	var p2: Player = pr2[0]
	var r2: Raptor = pr2[1]
	r2.assassinate(Vector3.FORWARD)
	p2.global_position = Vector3(0, 0, -4.5)
	r2._t = Raptor.DOWN_TIME - 0.05
	for i in 90:
		await t._frames(1)
		if r2.state == "study":
			break
	check(r2.state == "study" and p2.health == 100 and not p2.model.is_ragdoll(), "longe ao levantar (> COUNTER_REACH): contra-ataque erra e raptor vai para study")


func test_cancel_and_reset_edge_cases() -> void:
	var pr := await _spawn_pair(Vector3(0, 0, -1.6), "raptor")
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.fire()
	await t._frames(3)
	check(p.moves.mode == "assassinate" and r._stealth_locked, "golpe furtivo em andamento")
	# Interrompida antes do quadro do impacto (_hit_frame = 8)
	p.knockback(Vector3(0, 0, -4))
	await t._frames(2)
	check(p.moves.mode == "" and not p.model.holstered and not r._stealth_locked, "cancelar golpe furtivo destrava o inimigo e devolve a arma")
	check(r.health == Raptor.MAX_HEALTH and r.state == "idle", "golpe cancelado antes do quadro de impacto não fere o raptor")

	# Respawn da jogadora e reset do raptor a partir do estado down / crit_strike
	r.assassinate(Vector3.FORWARD)
	check(r.state == "down", "raptor em down")
	r.take_hit(10, Vector3.FORWARD, r.global_position + Vector3.UP)
	check(r.state == "down" and r.health == Raptor.MAX_HEALTH - roundi(Raptor.MAX_HEALTH * 0.7) - 10, "dano comum durante down tira vida sem cancelar o estado down")
	p.moves.start_crit_strike(r)
	check(p.moves.mode == "crit_strike" and r._stealth_locked, "crit_strike iniciado")
	p.respawn()
	r.reset()
	await t._frames(2)
	check(p.moves.mode == "" and not p.model.holstered, "respawn limpa crit_strike e devolve arma")
	check(r.state == "idle" and r.health == Raptor.MAX_HEALTH and not r.dead and not r._stealth_locked, "reset do raptor restaura vida, estado idle e destrava stealth_lock")

	# Chamar assassinate/crit_strike em inimigo já morto não causa erro nem revive
	r.die(Vector3.FORWARD)
	r.assassinate(Vector3.FORWARD)
	r.crit_strike(Vector3.FORWARD)
	check(r.dead and r.state == "dead", "assassinate/crit_strike em raptor morto é ignorado com segurança")
