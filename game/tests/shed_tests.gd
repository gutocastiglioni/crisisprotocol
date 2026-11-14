extends RefCounted
## Testes do galpão em salas (Shed), na planta girada (labirinto → escritório → estantes e doca → sala dos clones → pátio
## descoberto): paredes sólidas (seguram corpo, tiro e vista; o portão de grade deixa espiar), o labirinto sem atalho (o
## caminho do pé da escada do alçapão até o portão passa debaixo do mezanino e pelo corredor da parede oeste), a quina Q
## que mostra o atirador do mezanino, o escritório com uma saída só (a porta do arquivo, travada até o computador da mesa;
## as outras da frente nunca abrem), o som que só passa por porta aberta, a sala dos clones isolada do pátio descoberto com
## a porta enorme fechada, os guardas novos no lugar e os distraídos que não veem, os computadores (painel, escritório,
## cabine, laboratório), a cena dos clones terminando escondida e os reforços (2 levas de 3) com alarme vermelho.
## Chamado por run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_walls()
	await test_maze_route()
	await test_new_guards()
	await test_office()
	await test_booth()
	await test_panel_and_lab()
	await test_lab_isolation()
	await test_reinforcements()
	await test_guard_opens_gate()


func _main() -> Node:
	t.paused = false  # uma tela de inspeção de antes não segura a árvore parada
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


func _near(a: Vector3, b: Vector3, tol := 0.4) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() < tol


func _near_of(path: PackedVector3Array, at: Vector3) -> float:
	var near := INF
	for pt in path:
		near = minf(near, Vector2(pt.x - at.x, pt.z - at.z).length())
	return near


func _quiet(main: Node) -> void:
	for e: Enemy in main.all_enemies():
		e.process_mode = Node.PROCESS_MODE_DISABLED


func test_walls() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	t.check(shed.mid_gate.held and shed.exit_door.held and shed.corner_gate.held and shed.lab_gate.held,
		"portão do labirinto, porta do arquivo, portão dos clones e porta enorme começam travados")
	t.check([shed.mid_gate, shed.exit_door, shed.corner_gate, shed.fake_door].all(func(d: Door) -> bool: return d.room == -1),
		"portas de dentro fora da corrente de salas")
	t.check(shed.service_doors.size() == Shed.SERVICE.size() and shed.service_doors.all(func(d: Door) -> bool: return d.sealed and not d.can_open(d.global_position)),
		"portas de serviço dos reforços: seladas para ela")
	var ray := func(a: Vector3, b: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1)).is_empty()
	# parede da frente do labirinto: segura corpo, tiro e vista até o teto; o portão de grade deixa ver, sem passar
	var fz := Level.MAZE_FRONT
	t.check(_blocks_body(space, Vector3(-8.0, 0, fz), p.collision_mask), "a parede do labirinto segura ela")
	t.check(ray.call(Vector3(-8, 1.4, fz + 1.0), Vector3(-8, 1.4, fz - 1.0)) and ray.call(Vector3(-8, 6.5, fz + 1.0), Vector3(-8, 6.5, fz - 1.0)),
		"a parede do labirinto segura tiro e vista, até o teto")
	var gate := Shed.MID_GATE
	t.check(not ray.call(Vector3(gate.x, 1.4, fz + 1.0), Vector3(gate.x, 1.4, fz - 1.0)) and _blocks_body(space, gate, p.collision_mask),
		"pelo portão de grade fechado se vê o corredor do escritório, sem passar")
	# escritório: laje baixa, parede da frente fechada entre as portas; a sala dos clones fechada para o pátio descoberto
	var slab := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-9.0, 6.0, 50.0), Vector3(-9.0, 1.0, 50.0), 1))
	t.check(not slab.is_empty() and absf(slab.position.y - Shed.OFFICE_CEIL) < 0.05, "laje do escritório a OFFICE_CEIL", str(slab.get("position")))
	t.check(ray.call(Vector3(-7.0, 1.4, Shed.OFFICE_Z0 + 1.0), Vector3(-7.0, 1.4, Shed.OFFICE_Z0 - 1.0)), "parede da frente do escritório fechada")
	t.check(ray.call(Vector3(-8.0, 2.5, Level.ROOF_Z + 1.0), Vector3(-8.0, 2.5, Level.ROOF_Z - 1.0)), "parede da sala dos clones com o pátio descoberto fechada")
	var huge := Shed.HUGE_DOOR
	t.check(ray.call(Vector3(huge.x, 3.0, Level.ROOF_Z + 1.0), Vector3(huge.x, 3.0, Level.ROOF_Z - 1.0)), "porta enorme fechada: segura a vista")
	# a cabine e a doca: pisos nas alturas
	var booth := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-11.0, 6.0, 29.0), Vector3(-11.0, 0.5, 29.0), 1))
	t.check(not booth.is_empty() and absf(booth.position.y - Shed.BOOTH_Y) < 0.05, "piso da cabine a BOOTH_Y", str(booth.get("position")))
	var dock := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-4.0, 3.0, 29.0), Vector3(-4.0, 0.5, 29.0), 1))
	t.check(not dock.is_empty() and absf(dock.position.y - CloneLab.FLOOR_Y) < 0.05, "doca a CloneLab.FLOOR_Y", str(dock.get("position")))
	# som por área: entre salas só por porta aberta
	var maze := Vector3(-4.0, 0, 60.0)
	var office := Vector3(-9.0, 0, 52.0)
	var racks := Vector3(-3.0, 0, 37.0)
	var lab := Vector3(-5.0, CloneLab.FLOOR_Y, 18.0)
	var yard := Vector3(-6.0, 0, -4.0)
	t.check([Shed.zone_of(maze), Shed.zone_of(office), Shed.zone_of(racks), Shed.zone_of(Vector3(-11.0, Shed.BOOTH_Y, 29.0)),
		Shed.zone_of(lab), Shed.zone_of(yard), Shed.zone_of(Vector3(-20.0, 0, -8.5))] == ["strip", "office", "dock", "dock", "lab", "corner", ""],
		"áreas do galpão para o som")
	t.check(Shed.muffled(t, maze, office) and Shed.muffled(t, office, racks) and Shed.muffled(t, racks, lab) and Shed.muffled(t, maze, racks),
		"portas fechadas abafam")
	shed.mid_gate.open()
	shed.exit_door.open()
	t.check(not Shed.muffled(t, maze, office) and not Shed.muffled(t, maze, racks), "portas abertas: o som passa de sala em sala")
	shed.mid_gate.close()
	shed.exit_door.close()
	await t._frames(70)
	# pátio descoberto: o "canto" de agora
	t.check(Shed.in_corner(yard) and Shed.in_corner(Vector3(0.0, 0.6, 6.5)) and not Shed.in_corner(lab) and not Shed.in_corner(racks),
		"pátio descoberto: do lado de fora da parede da sala dos clones (a rampa conta)")
	main.queue_free()
	await t._frames(2)


## Labirinto: o caminho do pé da escada do alçapão até o portão do meio não tem atalho (passa debaixo do mezanino e pelo
## corredor da parede oeste até a frente); atrás da quina Q ela não é vista do mezanino e, esgueirando para o corredor da
## coluna 3, a linha até a beira da frente do mezanino fica livre; a escada do mezanino segue trancada (E avisa).
func test_maze_route() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var people: RID = main.soldiers[0].nav_map
	await t._frames(2)
	var start: Vector3 = Level.maze_cell(Level.MAZE_HATCH.x, Level.MAZE_HATCH.y + 1)
	var goal := Shed.MID_GATE + Vector3(0, 0, 0.9)
	var path := NavigationServer3D.map_get_path(people, start, goal, true)
	var under := false
	var west := false
	var length := 0.0
	for i in path.size():
		var q := path[i]
		if Catwalk.covers(q):
			under = true
		if q.x < Level.WEST + Level.MAZE_CELL.x and q.z < Level.MAZE_FRONT + Level.MAZE_CELL.y * 1.5:
			west = true
		if i > 0:
			length += Vector2(q.x - path[i - 1].x, q.z - path[i - 1].z).length()
	t.check(path.size() > 1 and _near(path[path.size() - 1], goal, 0.5), "há caminho do pé da escada até o portão do meio", str(path.size()))
	t.check(under and west and length > 33.0, "sem atalho: passa debaixo do mezanino e pelo corredor oeste até a frente",
		"debaixo %s, oeste %s, %.1f m" % [under, west, length])
	t.check(main.catwalk.ladder.locked and Level.maze_index(Vector3(Catwalk.LADDER_X, 0, Catwalk.FRONT_Z - 0.4)) == Level.maze_ladder_cell(),
		"escada do mezanino recolhida e trancada, em cima do corredor oeste")
	t.check(Level.MAZE[Level.maze_ladder_cell().y][Level.maze_ladder_cell().x] == ".", "o pé da escada trancada fica num corredor (dá para chegar e apertar E)")
	# quina Q: escondida atrás dela não vê a beira do mezanino; esgueirando para o corredor da coluna 3, vê
	var q_cell: Vector3 = Level.maze_cell(Level.MAZE_Q.x, Level.MAZE_Q.y)
	var hide: Vector3 = Level.maze_cell(Level.MAZE_Q.x, Level.MAZE_Q.y + 1)
	var guard_at := Vector3(-7.8, Catwalk.FLOOR_Y + 1.4, Catwalk.FRONT_Z + 0.54)
	var eye := Vector3(hide.x, 1.55, hide.z)
	var peek := Vector3(q_cell.x + Level.MAZE_CELL.x * 0.5 + 0.35, 1.55, hide.z)
	var seen := func(a: Vector3) -> bool: return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, guard_at, 1)).is_empty()
	t.check(not seen.call(eye), "atrás da quina Q o atirador do mezanino fica tapado")
	t.check(seen.call(peek), "esgueirando para o corredor da coluna 3: linha livre até a beira da frente do mezanino")
	# a escada trancada: E embaixo dela avisa
	_quiet(main)
	main.inspect.auto_close = 0.0
	var told := [false]
	p.ladder_locked.connect(func(_l: Ladder) -> void: told[0] = true)
	_put(p, Vector3(Catwalk.LADDER_X, 0, Catwalk.FRONT_Z - 0.6), PI)
	await t._frames(5)
	await _tap("interact")
	await t._frames(3)
	t.check(told[0], "E embaixo da escada do mezanino: trancada")
	await t._frames(int((Inspect.MIN_SHOW + 0.3) * 60))
	main.queue_free()
	await t._frames(2)


## Os guardas novos no lugar da planta (labirinto P1..P4 de pistola, escritório C/F/S/A/A, pátio T/T2) e os distraídos não a
## veem com ela parada bem na frente deles.
func test_new_guards() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	p.health = 100000
	var spots := {16: Vector3(-2.6, 0, 63.82), 17: Vector3(-10.0, 0, 67.3), 18: Vector3(-12.2, 0, 62.2), 19: Vector3(-7.4, 0, 60.29),
		20: Vector3(1.5, 0, 50.8), 21: Vector3(-1.4, 0, 55.0), 22: Vector3(2.2, 0, 44.2), 23: Vector3(-11.6, 0, 45.1),
		24: Vector3(-8.7, 0, 44.2), 25: Vector3(-11.9, 0, 3.4), 26: Vector3(-3.7, 0, 5.0), 2: Vector3(0.6, 0, 57.2),
		12: Vector3(-2.6, 0, Level.MAZE_FRONT + 0.15 + Level.CONSOLE_GUARD)}
	t.check(main.soldiers.size() == Soldier.GUARDS.size() and Soldier.GUARDS.size() == 27, "27 guardas no galpão", str(main.soldiers.size()))
	for i: int in spots:
		var sd: Soldier = main.soldiers[i]
		t.check(_near(sd.global_position, spots[i], 0.45), "guarda %d no lugar da planta" % i, str(sd.global_position))
	for i in [2, 12, 16, 17, 18, 19]:
		t.check(main.soldiers[i].weapon == "pistol", "guarda %d do labirinto de pistola" % i)
	var distracted := [12, 16, 17, 20, 21, 25, 26, 11, 13, 15]
	t.check(distracted.all(func(i: int) -> bool: return main.soldiers[i].distracted), "os do computador, das bancadas, do armário, do celular e do caminhão estão distraídos")
	# distraídos: com ela parada de pé a 2,5 m na frente deles, não a veem
	for i in [16, 20, 21, 25, 26]:
		_quiet(main)
		var sd: Soldier = main.soldiers[i]
		sd.process_mode = Node.PROCESS_MODE_INHERIT
		await t._frames(3)
		var front := -sd.global_basis.z
		var at := sd.global_position + front * 1.6
		var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(sd.global_position + Vector3.UP * 1.0, at + Vector3.UP * 1.0, 1)).is_empty():
			at = sd.global_position + sd.global_basis.x * 1.6  # bancada na frente: de lado
		_put(p, at, 0.0)
		await t._frames(90)
		t.check(sd.is_distracted() and sd.alert_level() == 0 and not sd.in_combat(), "guarda %d distraído não a vê" % i, "%s %d" % [sd.state, sd.alert_level()])
	main.queue_free()
	await t._frames(2)


## Escritório: das três portas da frente só a do arquivo abre, travada até o computador da mesa (com o guarda 11 fora
## dali); as outras duas e a porta falsa da sala dos clones nunca abrem (E avisa).
func test_office() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	_quiet(main)
	main.inspect.auto_close = 0.0
	var barred := [0]
	p.door_barred.connect(func(_d: Door) -> void: barred[0] += 1)
	for d: Door in shed.barred:
		_put(p, d.global_position + Vector3(0, 0, 1.0), 0.0)
		await t._frames(3)
		t.check(p.pick_door() == d, "porta trancada da frente: aviso ao chegar")
		await _tap("interact")
		await t._frames(3)
		t.check(not d.opened and d.locked_text != "", "E: segue fechada (trancada para sempre)")
		await t._frames(int((Inspect.MIN_SHOW + 0.3) * 60))
	t.check(barred[0] == shed.barred.size(), "E nas portas trancadas mostra o aviso", str(barred[0]))
	_put(p, Shed.EXIT_DOOR + Vector3(0, 0, 1.0), 0.0)
	await t._frames(3)
	t.check(p.pick_door() == null and shed.exit_door.held, "porta do arquivo travada: sem aviso de abrir")
	var guard: Soldier = main.soldiers[11]
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	await t._frames(3)
	_put(p, Shed.OFFICE_USE[0], Shed.OFFICE_USE[1])
	await t._frames(3)
	t.check(guard.is_distracted() and p.pick_terminal() == null, "com o guarda na mesa, o computador do escritório não serve")
	guard.take_headshot(999, Vector3.FORWARD, guard.global_position + Vector3.UP * 1.6)
	await t._frames(3)
	t.check(p.pick_terminal() == shed.office_panel, "guarda morto: aviso de usar o computador da mesa")
	var got := [""]
	shed.objective.connect(func(id: String) -> void: got[0] = id)
	await _tap("interact")
	await t._frames(3)
	t.check(shed.office_panel.done and not shed.exit_door.held and got[0] == "office", "computador da mesa: a porta do arquivo destrava (objetivo office)")
	_put(p, Shed.EXIT_DOOR + Vector3(0, 0, 1.0), 0.0)
	await t._frames(3)
	t.check(p.pick_door() == shed.exit_door, "porta do arquivo: aviso de abrir")
	await t._frames(int((Inspect.MIN_SHOW + 0.3) * 60))
	t.check(shed.barred.all(func(d: Door) -> bool: return not d.opened and d.locked_text != ""), "as outras portas da frente seguem trancadas")
	# porta falsa da sala dos clones
	_put(p, Shed.FAKE_DOOR + Vector3(-1.0, 0, 0), -PI * 0.5)
	await t._frames(3)
	t.check(p.pick_door() == shed.fake_door, "porta falsa: aviso ao chegar")
	await _tap("interact")
	await t._frames(3)
	t.check(not shed.fake_door.opened and barred[0] == shed.barred.size() + 1, "porta falsa: E só avisa")
	await t._frames(int((Inspect.MIN_SHOW + 0.3) * 60))
	main.reset_all()
	await t._frames(3)
	t.check(shed.exit_door.held and not shed.office_panel.done, "R: porta do arquivo travada de novo")
	main.queue_free()
	await t._frames(2)


## Cabine da doca: o guarda 13 no computador lá em cima; morto, E destrava o portão dos clones (checkpoint); a escadinha
## sobe da doca.
func test_booth() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	_quiet(main)
	var guard: Soldier = main.soldiers[13]
	guard.process_mode = Node.PROCESS_MODE_INHERIT
	await t._frames(3)
	t.check(guard.is_distracted() and absf(guard.global_position.y - Shed.BOOTH_Y) < 0.1, "guarda da cabine no computador, lá em cima")
	_put(p, Shed.BOOTH_USE[0], Shed.BOOTH_USE[1])
	await t._frames(3)
	t.check(p.pick_terminal() == null, "com o guarda na cabine, o computador não serve")
	guard.take_headshot(999, Vector3.FORWARD, guard.global_position + Vector3.UP * 1.6)
	await t._frames(3)
	t.check(p.pick_terminal() == shed.booth_panel, "guarda morto: aviso de usar o computador da cabine")
	await _tap("interact")
	await t._frames(3)
	t.check(shed.booth_panel.done and not shed.lab_gate.held and main.checkpoint.get("id", "") == "control",
		"computador da cabine: portão dos clones destravado (checkpoint)", str(main.checkpoint.get("id")))
	var ladder: Ladder = null
	for l: Ladder in t.get_nodes_in_group("ladders"):
		if l.global_position.distance_to(Shed.BOOTH_LADDER) < 0.1:
			ladder = l
	t.check(ladder != null and ladder.can_mount(ladder.bottom_pos + ladder.ladder_out * 0.45).get("can", false), "a escadinha da cabine sobe da doca")
	main.continue_from_checkpoint()
	await t._frames(3)
	t.check(not shed.lab_gate.held and shed.booth_panel.done and shed.mid_gate.held, "checkpoint da cabine: só o que ela destravou")
	t.check(_near(p.global_position, Checkpoint.SPAWNS.control[0]) and absf(p.global_position.y - Shed.BOOTH_Y) < 0.2, "renasce na cabine", str(p.global_position))
	main.reset_all()
	await t._frames(3)
	t.check(shed.lab_gate.held and not shed.booth_panel.done, "R: portão dos clones travado")
	main.queue_free()
	await t._frames(2)


func test_panel_and_lab() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	_quiet(main)
	# o computador do painel: com o guarda mexendo nele, não dá; com ele morto, E destrava o portão do labirinto
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
	t.check(shed.panel.done and not shed.mid_gate.held, "E no computador: o portão do labirinto destrava")
	_put(p, Shed.MID_GATE + Vector3(0, 0, 1.0), 0.0)
	await t._frames(3)
	t.check(p.pick_door() == shed.mid_gate, "na frente da grade: aviso de abrir")
	# sala dos clones: 4 guardas (3 distraídos no tanque e no computador), o som da doca não passa o portão fechado
	t.check(shed.lab_guards.size() == Shed.LAB_GUARDS.size() and shed.lab_guards.all(func(g: Soldier) -> bool: return CloneLab.inside(g.global_position)),
		"guardas dentro da sala dos clones")
	t.check(shed.lab_guards.filter(func(g: Soldier) -> bool: return g.distracted).size() == 3, "três distraídos: tanque vazio e computador")
	for g: Soldier in shed.lab_guards:
		g.process_mode = Node.PROCESS_MODE_INHERIT
	_put(p, Vector3(CloneLab.CX, CloneLab.FLOOR_Y, CloneLab.Z_NEAR + 1.6), PI)
	await t._frames(3)
	p.make_noise(26.0, 2.2)
	await t._frames(3)
	t.check(shed.lab_guards.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "portão da sala fechado: o tiro da doca não chega lá dentro")
	t.check(p.pick_door() == null and main.lab.gate.held, "portão dos clones travado: sem aviso de abrir")
	shed.booth_panel.use()
	await t._frames(3)
	t.check(p.pick_door() == main.lab.gate, "cabine usada: na doca, aviso de abrir o portão dos clones")
	# a cena do susto: no fim ela está agachada atrás da caixa de equipamento, ninguém a viu
	Settings.cutscenes_seen.clear()
	main.lab.gate.open()
	_put(p, Vector3(CloneLab.CX, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - 0.3), 0.0)
	await t._frames(3)
	t.check(main.cutscene.busy and main.cutscene.scene == "clones", "entrou: a cena dos clones")
	t.check(main.checkpoint.get("id", "") == "lab", "entrar na sala dos clones é checkpoint", str(main.checkpoint.get("id")))
	await t._frames(int(Cutscene.END_AT * 60) + 20)
	t.check(not main.cutscene.busy and p.crouching, "no fim da cena ela está agachada")
	var cover: Vector3 = CloneLab.COVER[0]
	t.check(p.global_position.z > cover.z and absf(p.global_position.x - cover.x) < 1.0 and p.global_position.distance_to(Vector3(cover.x, p.global_position.y, cover.z)) < 3.0,
		"atrás da caixa de equipamento", str(p.global_position))
	t.check(shed.lab_guards.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "os guardas do laboratório não a viram")
	# o computador do laboratório (com o guarda dele morto) abre a porta enorme para o pátio descoberto: checkpoint
	var tech: Soldier = shed.lab_guards[0]
	tech.take_headshot(999, Vector3.FORWARD, tech.global_position + Vector3.UP * 1.6)
	p.crouching = false
	_put(p, Shed.LAB_USE[0], Shed.LAB_USE[1])
	await t._frames(3)
	t.check(p.pick_terminal() == shed.lab_panel, "computador do laboratório ao alcance")
	await _tap("interact")
	await t._frames(3)
	t.check(not shed.corner_gate.held and shed.corner_gate.opened and main.checkpoint.get("id", "") == "corner",
		"o computador do laboratório abre a porta enorme (checkpoint)", str(main.checkpoint.get("id")))
	# voltando do checkpoint: as portas seguem como ela deixou
	main.continue_from_checkpoint()
	await t._frames(3)
	t.check(not shed.corner_gate.held and not shed.mid_gate.held and not shed.lab_gate.held and shed.lab_panel.done, "checkpoint: portas destravadas e computadores usados")
	t.check(_near(p.global_position, Checkpoint.SPAWNS.corner[0]), "renasce na frente da porta enorme", str(p.global_position))
	main.reset_all()
	await t._frames(3)
	t.check(shed.mid_gate.held and shed.corner_gate.held and not shed.corner_gate.opened and not shed.panel.done and not shed.lab_panel.done,
		"R: portas travadas, computadores sem uso")
	main.queue_free()
	await t._frames(2)


## Com a porta enorme fechada nada passa entre a sala dos clones e o pátio descoberto (som, grito, alarme, vista); aberta,
## passa.
func test_lab_isolation() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	_quiet(main)
	main.lab.gate.open()
	main.lab.played = true
	var lab := Vector3(-3.0, CloneLab.FLOOR_Y, 11.0)
	var yard := Vector3(-3.0, 0, 1.0)
	t.check(Shed.apart(t, lab, yard) and Shed.muffled(t, lab, yard), "porta enorme fechada: a sala e o pátio ficam à parte")
	var inside: Array = shed.lab_guards
	var outside: Array = Soldier.CORNER_GUARDS.map(func(i: int) -> Soldier: return main.soldiers[i])
	for g: Soldier in inside + outside:
		g.process_mode = Node.PROCESS_MODE_INHERIT
	# tiro no pátio descoberto: ninguém da sala ouve
	_put(p, Vector3(1.5, 0, 6.0), PI)
	await t._frames(3)
	p.make_noise(26.0, 2.2)
	await t._frames(20)
	t.check(inside.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "tiro no pátio: a sala dos clones não ouve")
	# tiro na sala: ninguém do pátio ouve
	main.reset_all()
	await t._frames(3)
	_quiet(main)
	main.lab.gate.open()
	main.lab.played = true
	for g: Soldier in inside + outside:
		g.process_mode = Node.PROCESS_MODE_INHERIT
	_put(p, lab, 0.0)
	await t._frames(3)
	p.make_noise(26.0, 2.2)
	await t._frames(20)
	t.check(outside.all(func(g: Soldier) -> bool: return g.alert_level() == 0 and not g.in_combat()), "tiro na sala: o pátio não ouve")
	# alarme de quem a viu no pátio não chega à sala
	main.reset_all()
	await t._frames(3)
	_quiet(main)
	for g: Soldier in inside + outside:
		g.process_mode = Node.PROCESS_MODE_INHERIT
	_put(p, Vector3(-8.0, 0, -6.6), -PI * 0.5)
	await t._frames(3)
	main.soldiers[3].spot()
	await t._frames(30)
	t.check(inside.all(func(g: Soldier) -> bool: return g.alert_level() == 0), "alarme no pátio: não chega à sala dos clones")
	# aberta, junta
	shed.corner_gate.open()
	t.check(not Shed.apart(t, lab, yard), "porta enorme aberta: a sala e o pátio se juntam")
	main.queue_free()
	await t._frames(2)


## Alarme vermelho no pátio descoberto: a primeira leva entra pela porta de serviço; com ela ainda à vista depois de
## SECOND_AFTER, a segunda. Fora da seção, nada.
func test_reinforcements() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	t.check(shed.reinforcements.size() == Shed.SERVICE.size() and shed.reinforcements.all(func(l: Array) -> bool: return l.size() == Shed.WAVE * Shed.WAVES and l.all(func(sd: Soldier) -> bool:
		return sd.lurking and not sd.visible and sd.process_mode == Node.PROCESS_MODE_DISABLED)), "2 levas de 3 por seção, escondidas na saleta")
	# alarme fora das seções (escritório): nada entra
	_put(p, Vector3(-9.0, 0, 52.0), PI * 0.5)
	main.soldiers[0].spot()
	await t._frames(int((Shed.WAVE_DELAY + 1.0) * 60))
	t.check(shed.waves_sent == [0, 0, 0], "alarme no escritório: nenhum reforço", str(shed.waves_sent))
	main.reset_all()
	await t._frames(3)
	# ela no pátio descoberto, à vista do posto: alarme vermelho (o R volta a vida dela ao normal)
	p.health = 100000
	_put(p, Vector3(-8.0, 0, -6.6), -PI * 0.5)
	var post: Soldier = main.soldiers[3]
	post.spot()
	await t._frames(int(Shed.WAVE_DELAY * 60) + 5 + int(Shed.WAVE_STAGGER * 60 * Shed.WAVE))
	var first: Array = shed.reinforcements[1].slice(0, Shed.WAVE)
	t.check(shed.waves_sent[1] == 1 and shed.service_doors[1].opened, "alarme vermelho no pátio: a porta de serviço abre e entra uma leva", str(shed.waves_sent))
	t.check(first.all(func(sd: Soldier) -> bool: return not sd.lurking and sd.visible and sd.collision_layer == 2 and sd.alert_t > 0.0),
		"os 3 da primeira leva entram alertados", str(first.map(func(sd: Soldier) -> String: return sd.state)))
	t.check(shed.reinforcements[1].slice(Shed.WAVE).all(func(sd: Soldier) -> bool: return sd.lurking), "a segunda leva ainda espera")
	t.check(shed.waves_sent[0] == 0 and shed.waves_sent[2] == 0, "a sala dos clones e as estantes não mandam ninguém")
	var second := false
	for i in int((Shed.SECOND_AFTER + 4.0) * 60):
		await t._frames(1)
		if shed.waves_sent[1] == 2:
			second = true
			break
	t.check(second, "a luta segue com ela no pátio: a segunda leva entra", str(shed.waves_sent))
	main.reset_all()
	await t._frames(3)
	t.check(shed.waves_sent == [0, 0, 0] and shed.reinforcements[1].all(func(sd: Soldier) -> bool: return sd.lurking and not sd.visible),
		"R: reforços de volta à saleta")
	# estantes: a saleta leste delas
	p.health = 100000
	_put(p, Vector3(-3.0, 0, 34.0), PI)
	main.soldiers[8].spot()
	await t._frames(int(Shed.WAVE_DELAY * 60) + 10)
	t.check(shed.waves_sent[2] == 1 and shed.service_doors[2].opened, "alarme vermelho nas estantes: entra a leva da saleta delas", str(shed.waves_sent))
	main.queue_free()
	await t._frames(2)


## Guarda indo do labirinto para o escritório (busca) abre o portão de grade travado ao chegar nele; passou, o portão fecha
## sozinho depois de AUTO_CLOSE s com o vão livre e segue travado.
func test_guard_opens_gate() -> void:
	var main: Node = await _main()
	var shed: Shed = main.shed
	var p: Player = main.player
	p.health = 100000
	_put(p, Vector3(-11.0, 0, 46.0))  # longe, fora da vista (no arquivo)
	_quiet(main)
	var g: Soldier = main.soldiers[19]  # ronda do corredor da linha 4 do labirinto
	g.process_mode = Node.PROCESS_MODE_INHERIT
	g.global_position = Shed.MID_GATE + Vector3(0, 0, 1.6)
	g.reset_physics_interpolation()
	await t._frames(5)
	var goal := Vector3(-4.2, 0, 53.5)
	g._alert_self(goal)
	g.start_hunt(goal)
	var opened := false
	for i in 400:
		await t._frames(1)
		if shed.mid_gate.opened:
			opened = true
			break
	t.check(opened, "guarda indo para o escritório abre o portão travado")
	var through := false
	for i in 600:
		await t._frames(1)
		if g.global_position.z < Shed.MID_GATE.z - 1.5:
			through = true
			break
	t.check(through, "e passa por ele", str(g.global_position))
	var closed := false
	for i in int((Shed.AUTO_CLOSE + 4.0) * 60):
		await t._frames(1)
		if not shed.mid_gate.opened:
			closed = true
			break
	t.check(closed and shed.mid_gate.held, "com o vão livre o portão fecha sozinho e segue travado")
	main.queue_free()
	await t._frames(2)
