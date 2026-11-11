extends RefCounted
## Testes dos checkpoints por área (Checkpoint): abrir o portão do pátio, matar os 3 raptors da emboscada, abrir o
## portão da mina e chegar à pedreira gravam a jogadora e o mundo; no Game Over, CONTINUAR volta a eles (quem morreu antes
## segue morto e fora do jogo, quem morreu depois volta; armas, vida, baús e portas como estavam) e R recomeça do zero.
## Voltando ao checkpoint da rendição, ela vem sem cena: os lasers, as mãos ao alto e as falas no HUD, com o jogo andando.
## Chamado por run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_spawns_are_free()
	await test_yard_checkpoint()
	await test_standoff_live_second_time()
	await test_tunnel_and_allosaurus()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


## Morre e aperta CONTINUAR no Game Over.
func _die_and_continue(main: Node, p: Player) -> void:
	p.take_hit(9999, p.global_basis.z, p.global_position + Vector3.UP * 1.2)
	for i in int((main.GAME_OVER_DELAY + 1.0) * 60):
		await t._frames(1)
		if main.game_over:
			break
	t.check(main.game_over, "morreu: Game Over")
	t.check("CONTINUAR" in main._end_hint.text(), "com checkpoint o Game Over oferece CONTINUAR", main._end_hint.text())
	main._restart_from_overlay(true)
	await t._frames(3)


func _near(a: Vector3, b: Vector3, tol := 0.3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < tol


## Cada lugar de renascer tem chão embaixo e nada sólido onde a cápsula dela fica.
func test_spawns_are_free() -> void:
	var main: Node = await _main()
	var space := t.get_root().get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	for id: String in Checkpoint.ORDER:
		var at: Vector3 = Checkpoint.SPAWNS[id][0]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = 1
		q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 0.95)
		var hits := space.intersect_shape(q, 4)
		var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 0.5, 1))
		t.check(hits.is_empty() and not floor_hit.is_empty(), "renascer em %s: chão embaixo, nada sólido em volta" % id,
			str(hits.map(func(h: Dictionary) -> String: return str(h.collider.name))))
	var rooms := {"yard": 1, "standoff": 1, "tunnel": 2, "allosaurus": 3}
	for id: String in rooms:
		t.check(Level.room_of(Checkpoint.SPAWNS[id][0].x) == rooms[id], "renascer em %s fica na sala certa" % id)
	main.queue_free()
	await t._frames(2)


func test_yard_checkpoint() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var sd: Array[Soldier] = main.soldiers
	t.check(main.checkpoint.is_empty(), "começo da fase: nenhum checkpoint")
	# antes do portão: um guarda morto, a M16 pega do baú, um pouco de dano e o cartão gasto
	sd[0].take_hit(999, Vector3.FORWARD, sd[0].global_position + Vector3.UP)
	main.chest.take_item()
	p.give_weapon("m16")
	p.health = 70
	p.health_changed.emit(p.health)
	main.hatch.open(0.01)
	await t._frames(30)
	var drops_before := t.get_root().get_tree().get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool:
		return pk.is_drop and not pk.taken and not pk.is_queued_for_deletion()).size()
	main.yard_door.unlock(p)
	await t._frames(2)
	t.check(main.checkpoint.get("id", "") == "yard", "abriu o portão do pátio: checkpoint", str(main.checkpoint.get("id")))
	t.check(main._hud_notice.visible and main._hud_notice.text == "CHECKPOINT", "aviso CHECKPOINT no HUD")
	# depois do checkpoint: outro guarda morto, a escopeta e mais dano
	sd[1].take_hit(999, Vector3.FORWARD, sd[1].global_position + Vector3.UP)
	p.give_weapon("shotgun")
	await t._frames(30)
	await _die_and_continue(main, p)
	t.check(not main.game_over and not p.dead, "CONTINUAR: de volta ao jogo")
	t.check(_near(p.global_position, Checkpoint.SPAWNS.yard[0]) and Level.room_of(p.global_position.x) == 1, "ela renasce no pátio, do lado de dentro do portão",
		str(p.global_position))
	t.check(p.health == 70 and "m16" in p.weapons and not "shotgun" in p.weapons, "vida e armas de quando chegou ao checkpoint",
		"%d %s" % [p.health, p.weapons])
	t.check(sd[0].dead and sd[0].cleared and not sd[0].visible and sd[0].process_mode == Node.PROCESS_MODE_DISABLED,
		"quem morreu antes do checkpoint segue morto e fora do jogo")
	t.check(not sd[1].dead and sd[1].visible and sd[1].state != "dead", "quem morreu depois do checkpoint volta ao posto")
	t.check(main.yard_door.opened and not main.yard_door.is_locked(), "o portão do pátio continua aberto")
	t.check(main.hatch.opened and main.chest.item == "" and main.chest.is_open(), "alçapão aberto e o baú da M16 vazio e aberto")
	var drops_after := t.get_root().get_tree().get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool:
		return pk.is_drop and not pk.taken and not pk.is_queued_for_deletion()).size()
	t.check(drops_after == drops_before, "o que caiu dos mortos antes do checkpoint está no chão de novo", "%d x %d" % [drops_after, drops_before])
	# R recomeça do zero: sem checkpoint, todos vivos, portão fechado
	main.reset_all()
	await t._frames(3)
	t.check(main.checkpoint.is_empty() and not sd[0].dead and not sd[0].cleared and sd[0].visible and sd[0].process_mode == Node.PROCESS_MODE_INHERIT,
		"R: do zero, o guarda morto volta")
	t.check(not main.yard_door.opened and p.weapons == ["pistol"] and p.health == 100, "R: portão fechado, só a pistola, vida cheia")
	# sem checkpoint o Game Over recomeça do zero
	p.take_hit(9999, p.global_basis.z, p.global_position + Vector3.UP * 1.2)
	for i in int((main.GAME_OVER_DELAY + 1.0) * 60):
		await t._frames(1)
		if main.game_over:
			break
	t.check("RECOMEÇAR" in main._end_hint.text() and not "CONTINUAR" in main._end_hint.text(), "sem checkpoint o Game Over só recomeça",
		main._end_hint.text())
	main._restart_from_overlay(true)
	await t._frames(3)
	t.check(not p.dead and _near(p.global_position, Roof.START), "e ela volta ao telhado")
	main.queue_free()
	await t._frames(2)


func test_standoff_live_second_time() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var cs: Cutscene = main.cutscene
	var snipers: Array[Sniper] = main.tower_snipers
	p.health = 100
	main.corpse.armed = false
	p.global_position = Vector3(-48.5, 0, 9.0)  # já na trilha da faixa oeste
	p.rotation.y = PI * 0.5
	p.reset_physics_interpolation()
	await t._frames(3)
	for r: Raptor in main.yard_raptors:
		r.lurking = false
		r.take_hit(999, Vector3.FORWARD, r.global_position)
	await t._frames(2)
	t.check(main.checkpoint.get("id", "") == "standoff", "a mata limpa: checkpoint", str(main.checkpoint.get("id")))
	for i in 150:
		await t._frames(1)
		if cs.busy:
			break
	t.check(cs.busy and cs.scene == "standoff" and main.standoff_seen, "a primeira vez: a cena da rendição")
	cs.stop()
	await t._frames(2)
	await _die_and_continue(main, p)
	t.check(_near(p.global_position, Checkpoint.SPAWNS.standoff[0]), "renasce no fim de S3, na frente do último portão de grade")
	t.check(main.yard_raptors.all(func(r: Raptor) -> bool: return r.dead and r.cleared), "os raptors da mata seguem mortos")
	t.check(main.trail.gates.all(func(g: Door) -> bool: return not g.held), "os portões de grade seguem destravados")
	t.check(snipers.all(func(s: Sniper) -> bool: return not s.dead and s.lurking), "as torres esperam ela descer a trilha da faixa oeste")
	t.check(main.key.shine and main.key.state == "held", "a chave brilha na mão do morto")
	p.global_position = Vector3(-48.5, 0, 9.0)
	p.reset_physics_interpolation()
	await t._frames(3)
	t.check(snipers.all(func(s: Sniper) -> bool: return not s.dead and not s.lurking and s.visible), "desceu: os snipers estão nas torres")
	var started := false
	for i in 150:
		await t._frames(1)
		if p.surrendered:
			started = true
			break
	t.check(started and not cs.busy and not p.cutscene and main._hud.visible, "a segunda vez: rendida sem cena (jogo andando, HUD na tela)")
	t.check(snipers.all(func(s: Sniper) -> bool: return s.in_standoff()), "os dois a pegam na mira")
	# segurar a mira enquanto levanta as mãos ainda não conta (ela estava jogando)
	Input.action_press("aim")
	await t._frames(10)
	t.check(p.surrendered, "mirar enquanto as mãos sobem não quebra a rendição")
	Input.action_release("aim")
	var lines := {}
	var hands := false
	for i in int(Cutscene.STAND_SUBS[-1][1] * 60) + 30:
		await t._frames(1)
		if main._hud_line.visible:
			lines[main._hud_line.text] = true
		if p.model.state == "surrender_hold" and p.model.hands_up:
			hands = true
	t.check(hands and p.surrendered, "mãos ao alto, rendida")
	t.check(Cutscene.STAND_LINES.all(func(l: String) -> bool: return lines.has(l)), "as três falas dos snipers no HUD", str(lines.keys()))
	t.check(not main._hud_line.visible, "as falas somem no fim")
	t.check(snipers.all(func(s: Sniper) -> bool: return s.shots_fired == 0 and s.laser.visible), "ninguém atirou; os lasers seguem nela")
	main.queue_free()
	await t._frames(2)


func test_tunnel_and_allosaurus() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var tn: Tunnel = main.tunnel
	p.health = 100000
	main.standoff_armed = false
	for s: Sniper in main.tower_snipers:
		s.appear()
		s.take_hit(9999, Vector3.FORWARD, s.global_position + Vector3.UP)
	main.mine_door.unlock(p)
	await t._frames(2)
	t.check(main.checkpoint.get("id", "") == "tunnel", "abriu o portão da mina: checkpoint", str(main.checkpoint.get("id")))
	# um sentinela do meio morto depois do checkpoint volta; os caixotes estouram e arrombam o portão da pedreira
	tn.guards[0].take_hit(9999, Vector3.FORWARD, tn.guards[0].global_position + Vector3.UP)
	for c in tn.crates:
		c.detonate(0.0)
	for i in 240:
		await t._frames(1)
		if tn.gate.opened:
			break
	t.check(tn.is_breached and tn.gate.blown, "portão da pedreira arrombado")
	await t._frames(60)
	Fire.clear(t.get_root().get_tree())
	p.global_position = Vector3(Tunnel.X_FAR - 0.7, 0, Tunnel.Z)
	p.rotation.y = PI * 0.5
	p.reset_physics_interpolation()
	await t._frames(2)
	t.check(main.checkpoint.get("id", "") == "allosaurus", "chegou à pedreira: checkpoint", str(main.checkpoint.get("id")))
	var dead_guards: Array = tn.guards.map(func(s: Soldier) -> bool: return s.dead)
	main.cutscene.stop()
	p.health = 50
	await _die_and_continue(main, p)
	t.check(_near(p.global_position, Checkpoint.SPAWNS.allosaurus[0]) and Level.room_of(p.global_position.x) == 3, "renasce na pedreira, depois do portão")
	t.check(tn.is_breached and tn.gate.opened and tn.gate.blown and tn.gate.collision_layer == 0, "o portão segue arrombado, as folhas no chão")
	t.check(tn.crates.all(func(c: ExplosiveCrate) -> bool: return c.exploded and not c.visible), "os caixotes seguem estourados")
	t.check(tn.guards.map(func(s: Soldier) -> bool: return s.dead) == dead_guards, "os guardas da mina mortos/vivos como no checkpoint")
	t.check(main.tower_snipers.all(func(s: Sniper) -> bool: return s.cleared), "os snipers das torres seguem mortos")
	t.check(not main.allosaurus.dead and not main.allosaurus.in_combat() and tn.lair_armed, "o alossauro calmo; a chegada à pedreira vale de novo")
	p.global_position = Vector3(Tunnel.LAIR_X - 0.4, 0, Tunnel.Z)
	p.reset_physics_interpolation()
	for i in 30:
		await t._frames(1)
		if main.cutscene.busy:
			break
	t.check(main.cutscene.busy and main.cutscene.scene == "lair", "passando do portão, a cena do alossauro")
	main.cutscene.stop()
	# voltar ao checkpoint do túnel não dá: o da pedreira é mais à frente
	main.reach_checkpoint("tunnel")
	t.check(main.checkpoint.id == "allosaurus", "checkpoint só anda para a frente")
	main.queue_free()
	await t._frames(2)
