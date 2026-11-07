extends RefCounted
## Testes do túnel da mina entre o portão do pátio e a pedreira (Tunnel): salas, guardas do meio e do fundo, a galeria
## abafando o som, a cena da conversa, o detonador com contagem, o portão da pedreira arrombado pela explosão, a cena do
## alossauro e o R. Chamado por run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_tunnel()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _tap_interact() -> void:
	var down := InputEventAction.new()
	down.action = "interact"
	down.pressed = true
	Input.parse_input_event(down)
	await t._frames(2)
	var up := InputEventAction.new()
	up.action = "interact"
	Input.parse_input_event(up)
	await t._frames(2)


func _put(p: Player, at: Vector3, yaw := PI * 0.5) -> void:
	p.global_position = at
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func test_tunnel() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var tn: Tunnel = main.tunnel
	var cs: Cutscene = main.cutscene
	var allo: Allosaurus = main.allosaurus
	var z := Tunnel.Z
	# --- salas e lugar de cada coisa
	t.check(Level.room_of(-80.0) == 2 and Level.room_of(Arena.ALLO.pos.x) == 3 and Arena.X_NEAR == Tunnel.X_FAR,
		"túnel = sala 2 entre o pátio e a pedreira (sala 3, empurrada para depois dele)")
	t.check(tn.gate.sealed and not tn.gate.opened and not tn.gate.can_open(Tunnel.gate_center() + Vector3.RIGHT)
		and not Level.connected(t, 2, 3), "portão da pedreira fechado e sem abrir com E")
	t.check(tn.guards.size() == 6, "6 guardas no túnel", str(tn.guards.size()))
	await t._frames(30)
	var far: Array[Soldier] = []
	for i in range(2, 6):
		far.append(tn.guards[i])
	t.check(far.all(func(s: Soldier) -> bool: return s.is_distracted() and s.model.state == "console"),
		"os 4 do fundo mexendo nos explosivos (Console, distraídos)", str(far.map(func(s: Soldier) -> String: return s.model.state)))
	t.check(not tn.guards[0].distracted and not tn.guards[1].distracted, "os 2 do meio de sentinela")
	var gap := INF
	for a in 2:
		for b: Soldier in far:
			gap = minf(gap, Enemy._flat(tn.guards[a].global_position - b.global_position).length())
	t.check(gap > Tunnel.SOUND_REACH, "os do fundo longe dos do meio (além do que a galeria deixa ouvir)", "%.1f m" % gap)
	var items := Pickup.LAYOUT.filter(func(e: Dictionary) -> bool: return Level.room_of(e.pos.x) == 2)
	t.check(items.size() >= 4, "itens para repor no caminho do túnel", str(items.size()))
	t.check(tn.crates.size() >= 14 and tn.crates.all(func(c: ExplosiveCrate) -> bool: return Level.room_of(c.global_position.x) == 2),
		"pilhas de explosivos no fundo do túnel", str(tn.crates.size()))

	# --- a galeria abafa: tiro/alarme no meio não chegam ao fundo
	var mid := Vector3(-83.0, 0, z)
	t.check(tn.guards[1]._reaches(mid) and not far[0]._reaches(mid) and not far[1]._reaches(mid), "tiro no meio não chega aos do fundo")
	t.check(far[0]._reaches(Vector3(-96.0, 0, z)), "briga levada até perto deles chega")
	tn.guards[0].broadcast_alarm(mid, false, true)
	await t._frames(5)
	t.check(tn.guards[1].alert_t > 0.0 and far.all(func(s: Soldier) -> bool: return s.alert_t <= 0.0),
		"alarme do meio chama o outro do meio, não os do fundo")
	main.reset_all()
	await t._frames(30)

	# --- a conversa: chega ao fundo sem ser vista
	for d: Door in t.get_nodes_in_group("doors"):
		if d.room == 1:
			d.unlock()
	_put(p, Vector3(Tunnel.TALK_X - 0.5, 0, z + 0.6))
	await t._frames(3)
	t.check(cs.busy and cs.scene == "talk" and p.cutscene and not tn.talk_armed, "chegou ao fundo: a cena dos guardas", "%s %s" % [cs.busy, cs.scene])
	var a: Soldier = cs.speakers[0]
	var b: Soldier = cs.speakers[1]
	await t._frames(int(5.5 * 60))
	var to_b := b.global_position - a.global_position
	t.check(absf(angle_difference(a.rotation.y, atan2(-to_b.x, -to_b.z))) < 0.5, "quem fala vira para o outro")
	t.check(cs._sub.visible and cs._sub.text == Cutscene.TALK_LINES[0], "a fala dele na faixa de baixo", cs._sub.text)
	await t._frames(int((Cutscene.TALK_END_AT - 5.5) * 60) + 10)
	t.check(not cs.busy and not p.cutscene, "a cena acaba")
	await t._frames(90)
	t.check(far.all(func(s: Soldier) -> bool: return s.alert_t <= 0.0 and not s.in_combat()), "ninguém a notou na cena")
	t.check(far.all(func(s: Soldier) -> bool: return s.is_distracted()), "os dois voltam ao trabalho",
		str(far.map(func(s: Soldier) -> String: return s.state)))

	# --- detonador: o do caixote dele morto, ela arma e sai de perto
	far[0].take_hit(9999, Vector3.UP, far[0].global_position + Vector3.UP * 1.2)
	await t._frames(30)
	_put(p, Tunnel.detonator_point(), Tunnel.guard_spot(Tunnel.TALKERS[0]).rot_y)
	await t._frames(3)
	t.check(p.pick_detonator() == tn, "na frente do caixote: ARMAR DETONADOR")
	var ticks := []
	tn.tick.connect(func(left: int) -> void: ticks.append(left))
	await _tap_interact()
	t.check(tn.fuse > 0.0 and ticks.size() == 1 and ticks[0] == int(Tunnel.FUSE), "E arma a contagem", "%.1f %s" % [tn.fuse, ticks])
	_put(p, Vector3(-80.0, 0, z), -PI * 0.5)
	for g in 2:
		tn.guards[g].process_mode = Node.PROCESS_MODE_DISABLED  # os do meio fora disto
	await t._frames(int(Tunnel.FUSE * 60) + 150)
	t.check(ticks.size() >= int(Tunnel.FUSE) - 1, "contagem segundo a segundo", str(ticks))
	t.check(tn.crates.all(func(c: ExplosiveCrate) -> bool: return c.exploded), "a contagem acaba e tudo explode")
	t.check(tn.is_breached and tn.gate.opened and Level.connected(t, 2, 3), "a explosão arromba o portão da pedreira")
	t.check(far.all(func(s: Soldier) -> bool: return s.dead), "os do fundo morrem na explosão")
	t.check(not p.dead, "ela, longe, escapa")
	t.check(allo.alert_t <= 0.0 and not allo.in_combat(), "a explosão não chama o alossauro (o portão ainda estava fechado)")

	# --- a cena do alossauro: passa pelo portão arrombado
	_put(p, Vector3(Tunnel.LAIR_X - 0.5, 0, z))
	await t._frames(3)
	t.check(cs.busy and cs.scene == "lair" and not tn.lair_armed, "passou pelo portão: a cena do alossauro", "%s %s" % [cs.busy, cs.scene])
	await t._frames(int((Cutscene.LAIR_SUB2[0] + 0.5) * 60))
	t.check(cs._sub.visible and cs._sub.text == Cutscene.LAIR_LINES[1], "ela pensa", cs._sub.text)
	t.check(not allo.in_combat(), "ele ainda não a viu")
	await t._frames(int((Cutscene.LAIR_END_AT - Cutscene.LAIR_SUB2[0]) * 60))
	t.check(not cs.busy and not p.cutscene, "a cena acaba")
	t.check(allo.in_combat() and allo.alert_t > 0.0, "ele rugiu e vem", allo.state)

	# --- R: tudo de volta
	main.reset_all()
	await t._frames(5)
	t.check(tn.crates.all(func(c: ExplosiveCrate) -> bool: return not c.exploded) and not tn.is_breached and not tn.gate.opened
		and tn.gate.collision_layer == 1 and not Level.connected(t, 2, 3), "R: caixotes e portão de volta")
	t.check(tn.talk_armed and tn.lair_armed and tn.fuse < 0.0, "R: as cenas valem de novo e o detonador desarmado")

	# --- a M79 também arromba: granada numa pilha do portão
	Grenade.explode(main, Vector3(-114.0, 1.2, z - 3.2), Vector3.RIGHT)
	await t._frames(120)
	t.check(tn.is_breached and tn.gate.opened, "granada nas pilhas do portão também o arromba")
	main.reset_all()
	await t._frames(3)
	main.queue_free()
	await t._frames(2)
