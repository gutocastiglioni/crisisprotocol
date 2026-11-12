extends RefCounted
## Testes do galpão em seções (Shed): grades de alambrado (seguram corpo, não tiro), o canto da porta do pátio fechado (só
## pelo portão de grade, sem escalar por cima das caixas), o computador do painel destravando a grade do meio, a sala dos
## clones com guardas e a cena terminando escondida, o computador do laboratório destravando o canto (checkpoint) e os
## reforços (2 levas de 3) com alarme vermelho. Chamado por run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_fences()
	await test_panel_and_lab()
	await test_reinforcements()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _put(p: Player, at: Vector3, yaw := 0.0) -> void:
	p.global_position = at
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _tap(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await t._frames(2)
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await t._frames(2)


func _blocks_body(space: PhysicsDirectSpaceState3D, at: Vector3, mask: int) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	q.shape = cap
	q.collision_mask = mask
	q.transform = Transform3D(Basis(), at + Vector3.UP * 0.9)
	return not space.intersect_shape(q, 1).is_empty()


func test_fences() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	t.check(shed.mid_gate.held and shed.corner_gate.held and shed.mid_gate.room == -1 and shed.corner_gate.room == -1,
		"as duas grades do galpão começam travadas, fora da corrente de salas")
	t.check(shed.service_doors.size() == Shed.SERVICE.size() and shed.service_doors.all(func(d: Door) -> bool: return d.sealed and not d.can_open(d.global_position)),
		"portas de serviço dos reforços: seladas para ela")
	# a grade do painel: segura o corpo dela e dos guardas, mas tiro e vista passam
	var on_fence := Vector3(-2.0, 0, Shed.FENCE_A_Z)
	t.check(_blocks_body(space, on_fence, p.collision_mask) and _blocks_body(space, on_fence, main.soldiers[0].collision_mask), "a grade segura ela e os guardas")
	t.check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2, 1.4, 4.5), Vector3(-2, 1.4, 1.5), 1)).is_empty(), "tiro e vista passam pela grade")
	# o vão do sul do canto (que dava direto nos guardas da porta do pátio) fechado
	t.check(_blocks_body(space, Vector3(-8.4, 0, 0.4), p.collision_mask), "o vão do sul do canto da porta do pátio está fechado")
	t.check(_blocks_body(space, Vector3(-5.6, 0, -2.0), 0) == false and _blocks_body(space, Vector3(-5.85, 0, -1.9), p.collision_mask),
		"a quina do canto (perto da coluna) fechada por grade")
	# a malha de gente: do canto para o meio, só pelo portão de grade do canto
	var people: RID = main.soldiers[0].nav_map
	await t._frames(2)
	var path := NavigationServer3D.map_get_path(people, Vector3(-8.0, 0, -7.0), Vector3(2.4, 0, -6.0), true)
	var near := INF
	for pt in path:
		near = minf(near, Vector2(pt.x - Shed.CORNER_GATE.x, pt.z - Shed.CORNER_GATE.z).length())
	t.check(path.size() > 1 and near < 1.2, "do canto para o meio só pelo portão de grade do canto", "%.1f" % near)
	# sem escalar a parede de caixas do canto e pular para dentro (grade por cima das caixas)
	_put(p, Vector3(-3.75 + 0.75, 0, -11.0), PI * 0.5)  # de frente para a parede leste do canto, do lado do meio
	await t._frames(10)
	t.check(not p.moves.try_ledge(Vector3.LEFT), "a parede de caixas do canto não dá para escalar (grade em cima)")
	main.queue_free()
	await t._frames(2)


func test_panel_and_lab() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	for sd: Soldier in main.soldiers:
		sd.process_mode = Node.PROCESS_MODE_DISABLED
	# o computador do painel: com o guarda mexendo nele, não dá; com ele morto, E destrava a grade do meio
	var guard: Soldier = main.soldiers[12]
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	await t._frames(3)
	_put(p, Shed.PANEL_USE[0], Shed.PANEL_USE[1])
	await t._frames(3)
	t.check(guard.is_distracted() and p.pick_terminal() == null, "com o guarda no painel, o computador não serve")
	guard.take_headshot(999, Vector3.FORWARD, guard.global_position + Vector3.UP * 1.6)
	await t._frames(3)
	t.check(p.pick_terminal() == shed.panel, "guarda morto: aviso de usar o computador")
	await _tap("interact")
	await t._frames(3)
	t.check(shed.panel.done and not shed.mid_gate.held, "E no computador: a grade do meio destrava")
	_put(p, Shed.MID_GATE + Vector3(0, 0, 1.0), 0.0)
	await t._frames(3)
	t.check(p.pick_door() == shed.mid_gate, "na frente da grade: aviso de abrir")
	# sala dos clones: 4 guardas (3 distraídos no tanque e no computador), o som do galpão não passa o portão fechado
	t.check(shed.lab_guards.size() == Shed.LAB_GUARDS.size() and shed.lab_guards.all(func(g: Soldier) -> bool: return CloneLab.inside(g.global_position)),
		"guardas dentro da sala dos clones")
	t.check(shed.lab_guards.filter(func(g: Soldier) -> bool: return g.distracted).size() == 3, "três distraídos: tanque vazio e computador")
	p.make_noise(26.0, 2.2)
	await t._frames(3)
	t.check(shed.lab_guards.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "portão da sala fechado: o tiro do galpão não chega lá dentro")
	# a cena do susto: no fim ela está agachada atrás da caixa de equipamento, ninguém a viu
	Settings.cutscenes_seen.clear()
	main.lab.gate.open()
	_put(p, Vector3(0, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - 0.3), 0.0)
	await t._frames(3)
	t.check(main.cutscene.busy and main.cutscene.scene == "clones", "entrou: a cena dos clones")
	t.check(main.checkpoint.get("id", "") == "lab", "entrar na sala dos clones é checkpoint", str(main.checkpoint.get("id")))
	await t._frames(int(Cutscene.END_AT * 60) + 20)
	t.check(not main.cutscene.busy and p.crouching, "no fim da cena ela está agachada")
	var cover: Vector3 = CloneLab.COVER[0]
	t.check(p.global_position.z > cover.z and absf(p.global_position.x - cover.x) < 1.0 and p.global_position.distance_to(Vector3(cover.x, p.global_position.y, cover.z)) < 3.0,
		"atrás da caixa de equipamento", str(p.global_position))
	t.check(shed.lab_guards.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "os guardas do laboratório não a viram")
	# o computador do laboratório (com o guarda dele morto) destrava o canto da porta do pátio: checkpoint
	var tech: Soldier = shed.lab_guards[0]
	tech.take_headshot(999, Vector3.FORWARD, tech.global_position + Vector3.UP * 1.6)
	p.crouching = false
	_put(p, Shed.LAB_USE[0], Shed.LAB_USE[1])
	await t._frames(3)
	t.check(p.pick_terminal() == shed.lab_panel, "computador do laboratório ao alcance")
	await _tap("interact")
	await t._frames(3)
	t.check(not shed.corner_gate.held and main.checkpoint.get("id", "") == "corner", "o computador do laboratório destrava o canto (checkpoint)", str(main.checkpoint.get("id")))
	# voltando do checkpoint: as duas grades seguem destravadas
	main.continue_from_checkpoint()
	await t._frames(3)
	t.check(not shed.corner_gate.held and not shed.mid_gate.held and shed.lab_panel.done, "checkpoint: grades destravadas e computadores usados")
	t.check(_near(p.global_position, Checkpoint.SPAWNS.corner[0]), "renasce na frente da grade do canto", str(p.global_position))
	# R: tudo travado de novo
	main.reset_all()
	await t._frames(3)
	t.check(shed.mid_gate.held and shed.corner_gate.held and not shed.panel.done and not shed.lab_panel.done, "R: grades travadas, computadores sem uso")
	main.queue_free()
	await t._frames(2)


func _near(a: Vector3, b: Vector3, tol := 0.4) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < tol


## Alarme vermelho no canto da porta do pátio: a primeira leva entra pela porta de serviço; com ela ainda à vista depois de
## SECOND_AFTER, a segunda. Fora da seção, nada.
func test_reinforcements() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	t.check(shed.reinforcements.all(func(l: Array) -> bool: return l.size() == Shed.WAVE * Shed.WAVES and l.all(func(sd: Soldier) -> bool:
		return sd.lurking and not sd.visible and sd.process_mode == Node.PROCESS_MODE_DISABLED)), "2 levas de 3 por seção, escondidas na saleta")
	# alarme fora da seção: nada entra
	_put(p, Vector3(2.4, 0, -6.0), PI * 0.5)
	main.soldiers[11].spot()
	await t._frames(int((Shed.WAVE_DELAY + 1.0) * 60))
	t.check(shed.waves_sent == [0, 0], "alarme no meio do galpão: nenhum reforço", str(shed.waves_sent))
	main.reset_all()
	await t._frames(3)
	# ela dentro do canto, à vista do sentinela: alarme vermelho (o R volta a vida dela ao normal)
	p.health = 100000
	_put(p, Vector3(-8.0, 0, -6.6), -PI * 0.5)
	var post: Soldier = main.soldiers[3]
	post.spot()
	await t._frames(int(Shed.WAVE_DELAY * 60) + 5 + int(Shed.WAVE_STAGGER * 60 * Shed.WAVE))
	var first: Array = shed.reinforcements[1].slice(0, Shed.WAVE)
	t.check(shed.waves_sent[1] == 1 and shed.service_doors[1].opened, "alarme vermelho no canto: a porta de serviço abre e entra uma leva", str(shed.waves_sent))
	t.check(first.all(func(sd: Soldier) -> bool: return not sd.lurking and sd.visible and sd.collision_layer == 2 and sd.alert_t > 0.0),
		"os 3 da primeira leva entram alertados", str(first.map(func(sd: Soldier) -> String: return sd.state)))
	t.check(shed.reinforcements[1].slice(Shed.WAVE).all(func(sd: Soldier) -> bool: return sd.lurking), "a segunda leva ainda espera")
	t.check(shed.waves_sent[0] == 0, "a sala dos clones não manda ninguém")
	var second := false
	for i in int((Shed.SECOND_AFTER + 4.0) * 60):
		await t._frames(1)
		if shed.waves_sent[1] == 2:
			second = true
			break
	t.check(second, "a luta segue com ela no canto: a segunda leva entra", str(shed.waves_sent))
	main.reset_all()
	await t._frames(3)
	t.check(shed.waves_sent == [0, 0] and shed.reinforcements[1].all(func(sd: Soldier) -> bool: return sd.lurking and not sd.visible),
		"R: reforços de volta à saleta")
	main.queue_free()
	await t._frames(2)
