extends RefCounted
## Testes da trilha em S do pátio da mata (Yard + ForestTrail): faixas separadas por mata fechada, portões de grade
## travados por seção, raptors que saem da mata por trechos (e se juntam quando ela passa correndo), o barranco até o
## planalto da escopeta com os 2 raptors de lá e a capacidade da escopeta. Chamado por run_tests.gd (usa check/_frames
## de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_layout()
	await test_waves_and_gates()
	await test_barranco_and_cliff()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	main.corpse.armed = false  # sem a cena da emboscada no caminho
	main.standoff_armed = false
	return main


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


func _put(p: Player, at: Vector3, yaw := 0.0) -> void:
	p.global_position = at
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()


func _hit(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask := 1) -> bool:
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask)).is_empty()


## Faixas, mata entre elas, portões de grade (seguram corpo, deixam passar tiro e vista) e o caminho em S da porta do
## galpão até a boca do túnel.
func test_layout() -> void:
	var main: Node = await _main()
	var trail: ForestTrail = main.trail
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	t.check(trail.gates.size() == Yard.GRATES.size() and trail.gates.all(func(g: Door) -> bool:
		return g.room == -1 and g.held and g.solid_layer == Yard.GRATE_LAYER and g.collision_layer == Yard.GRATE_LAYER),
		"3 portões de grade, fora da corrente de salas, travados, na camada da grade")
	t.check(trail.gates.all(func(g: Door) -> bool: return not g.can_open(g.global_position + Vector3(0.6, 0, 0))), "travado: sem E")
	for i in Yard.GRATES.size():
		var g: Door = trail.gates[i]
		var across := Vector3.RIGHT.rotated(Vector3.UP, g.rotation.y)
		var c := g.global_position + Vector3.UP * 1.2
		t.check(not _hit(space, c + across * 2.0, c - across * 2.0), "portão %d: tiro e vista passam pela grade" % i)
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.6
		q.shape = cap
		q.collision_mask = main.player.collision_mask
		q.transform = Transform3D(Basis(), g.global_position + Vector3.UP * 0.9)
		t.check(not space.intersect_shape(q, 1).is_empty(), "portão %d: segura o corpo dela" % i)
	# a mata entre as faixas tapa a vista; a borda do planalto sobre S3 segura o corpo mas não a vista
	t.check(_hit(space, Vector3(-34, 1.5, -20), Vector3(-20, 1.5, -20)), "S2 não vê S1 através da mata")
	t.check(_hit(space, Vector3(-36, 1.5, 20), Vector3(-49, 1.5, 20)), "S3 não vê a trilha oeste através da mata")
	var top := Yard.PLATEAU_Y
	t.check(not _hit(space, Vector3(-26.0, top + 1.5, 20), Vector3(-34, 1.0, 20)), "da beira do planalto a vista e o tiro descem em S3")
	t.check(_hit(space, Vector3(-23, top + 1.0, 20), Vector3(-30, top + 1.0, 20), Yard.GRATE_LAYER), "a borda do planalto segura quem quer pular para S3")
	# entradas dos trechos sempre à frente da linha que as solta (ela anda para o norte na faixa do meio)
	var ahead := Yard.WAVES.all(func(w: Dictionary) -> bool: return w.entries.all(func(e: Vector3) -> bool: return e.z > w.z + 6.0))
	t.check(ahead, "cada trecho solta raptors à frente dela (6 m ou mais)")
	t.check(Yard.WAVES.all(func(w: Dictionary) -> bool: return w.entries.all(func(e: Vector3) -> bool: return Yard.in_mid(e))), "as moitas dos trechos ficam na faixa do meio")
	# caminho da porta do galpão até a boca do túnel (malha dos raptors; portões fora da malha) passa pelos 3 portões
	var map: RID = main.get_world_3d().navigation_map
	await t._frames(2)
	var path := NavigationServer3D.map_get_path(map, Vector3(-15.0, 0, Yard.DOOR_Z), Vector3(-53.0, 0, -3.0), true)
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	t.check(path.size() > 1 and path[-1].distance_to(Vector3(-53.0, 0, -3.0)) < 1.0, "da porta do galpão chega à boca do túnel", str(path[-1] if path.size() else "-"))
	t.check(length > 150.0, "o caminho dá a volta em S (longo, não reto)", "%.0f m" % length)
	for i in Yard.GRATES.size():
		var gp: Vector3 = Yard.GRATES[i][0]
		var near := INF
		for pt in path:
			near = minf(near, Vector2(pt.x - gp.x, pt.z - gp.z).length())
		t.check(near < 2.5, "o caminho passa pelo portão %d" % i, "%.1f m" % near)
	t.check(GameMode.AMMO_CAP.shotgun == 25, "escopeta guarda até 25 cartuchos")
	main.queue_free()
	await t._frames(2)


## Trechos de S2: passou da linha, os raptors dele saem da mata à frente; passou correndo, os seguintes também (se juntam).
## Seção limpa: o portão de grade destrava (estalo, lampião verde), E abre; checkpoint. O portão de trás fica aberto.
func test_waves_and_gates() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var trail: ForestTrail = main.trail
	t.check(trail.sections[0].size() == 3 and trail.sections[1].size() == 7 and trail.sections[2].size() == 9 and trail.cliff.size() == 2,
		"S1 = 3, S2 = 7, S3 = 9, barranco = 2", str([trail.sections[0].size(), trail.sections[1].size(), trail.sections[2].size(), trail.cliff.size()]))
	var walkers: Array[Raptor] = []
	walkers.assign(trail.sections[1] + trail.sections[2] + trail.cliff)
	t.check(walkers.all(func(r: Raptor) -> bool: return r.lurking and not r.visible and r.collision_layer == 0 and r.model.process_mode == Node.PROCESS_MODE_DISABLED),
		"todos escondidos nas moitas, sem corpo e sem animar")
	# S1 ainda viva: o primeiro portão travado
	_put(p, Vector3(-24.6, 0, -38.0), PI * 0.5)
	await t._frames(3)
	t.check(trail.gates[0].held and not trail.gates[0].can_open(p.global_position), "S1 viva: o portão de grade não abre")
	for r: Raptor in trail.sections[0]:
		r.lurking = false
		r.take_hit(999, Vector3.FORWARD, r.global_position)
	await t._frames(3)
	t.check(not trail.gates[0].held and trail.gates[0].can_open(p.global_position) and trail.section_done(0), "S1 limpa: o portão destrava e abre com E")
	t.check(main.key.shine and main.checkpoint.get("id", "") == "trail", "S1 limpa: a chave brilha e é checkpoint", str(main.checkpoint.get("id")))
	trail.gates[0].open()
	# entrando em S2, antes da primeira linha: nada; passou dela: o primeiro par sai das moitas
	_put(p, Vector3(-30.0, 0, -37.5), PI)
	await t._frames(10)
	var w0: Dictionary = trail.waves[0]
	t.check(not w0.fired and w0.raptors.all(func(r: Raptor) -> bool: return r.lurking), "antes da linha do trecho: escondidos")
	_put(p, Vector3(-30.0, 0, -35.5), PI)
	await t._frames(int(ForestTrail.STAGGER * 60) + 6)
	t.check(w0.fired and w0.raptors.all(func(r: Raptor) -> bool: return not r.lurking and r.visible and r.collision_layer == 2),
		"passou da linha: o par do trecho sai das moitas", str(w0.raptors.map(func(r: Raptor) -> String: return r.state)))
	var others: Array[Raptor] = []
	others.assign(walkers.filter(func(r: Raptor) -> bool: return r not in w0.raptors))
	t.check(others.all(func(r: Raptor) -> bool: return r.lurking), "os outros trechos seguem escondidos")
	var d0: Array = w0.raptors.map(func(r: Raptor) -> float: return r.global_position.distance_to(p.global_position))
	await t._frames(80)
	var d1: Array = w0.raptors.map(func(r: Raptor) -> float: return r.global_position.distance_to(p.global_position))
	t.check(w0.raptors.all(func(r: Raptor) -> bool: return r.in_combat() and r.alert_t > 0.0) and d1[0] < d0[0] and d1[1] < d0[1],
		"pularam para perto dela e já estão em luta", "%s -> %s" % [d0, d1])
	# passou correndo pelo resto de S2: os outros trechos também saem (todos atrás dela)
	_put(p, Vector3(-36.0, 0, -9.0), PI)
	await t._frames(int(ForestTrail.STAGGER * 60) + 8)
	t.check(trail.sections[1].all(func(r: Raptor) -> bool: return not r.lurking), "correndo por S2: os 7 saíram e se juntam")
	t.check(trail.sections[2].all(func(r: Raptor) -> bool: return r.lurking), "S3 segue escondida (atrás do portão do meio)")
	t.check(trail.gates[1].held, "S2 viva: o portão do meio travado")
	# o portão de trás (S1) segue aberto: dá para voltar
	t.check(trail.gates[0].opened, "o portão de trás fica aberto")
	for r: Raptor in trail.sections[1]:
		r.take_hit(999, Vector3.FORWARD, r.global_position)
	_put(p, Vector3(-36.0, 0, -2.0), PI)
	await t._frames(3)
	t.check(not trail.gates[1].held and trail.gates[1].can_open(p.global_position) and main.checkpoint.get("id", "") == "trail2",
		"S2 limpa: o portão do meio destrava; checkpoint", str(main.checkpoint.get("id")))
	# R: tudo de volta (escondidos, trechos armados, portões travados)
	main.reset_all()
	await t._frames(3)
	t.check(walkers.all(func(r: Raptor) -> bool: return r.lurking and not r.dead and not r.visible), "R: de volta às moitas")
	t.check(trail.waves.all(func(w: Dictionary) -> bool: return not w.fired) and trail.gates.all(func(g: Door) -> bool: return g.held and not g.opened),
		"R: trechos armados e portões travados")
	main.queue_free()
	await t._frames(2)


## Barranco no fim de S2: escala o degrau, pula, fica pendurada na beira e sobe ao planalto; lá em cima os 2 raptors das
## moitas pulam nela; o baú da escopeta está no planalto.
func test_barranco_and_cliff() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var trail: ForestTrail = main.trail
	var foot := Vector3(Yard.ROCK1.position.x - 0.45, 0, Yard.ROCK1.get_center().y)
	_put(p, foot, -PI * 0.5)  # de frente para o leste (o degrau)
	await t._frames(10)
	await _tap("jump")
	for i in 120:
		await t._frames(1)
		if p.moves.mode == "" and p.is_on_floor() and p.global_position.y > 0.5:
			break
	t.check(absf(p.global_position.y - Yard.ROCK1_H) < 0.15, "escala o degrau do barranco", str(p.global_position))
	await t._frames(10)
	await _tap("jump")
	await t._frames(40)
	t.check(p.moves.hanging(), "pula e fica pendurada na beira do barranco", "%s %s" % [p.moves.mode, p.global_position])
	await _tap("jump")
	for i in 240:
		await t._frames(1)
		if p.moves.mode == "" and p.is_on_floor():
			break
	t.check(absf(p.global_position.y - Yard.PLATEAU_Y) < 0.15 and Yard.on_plateau(p.global_position), "sobe ao planalto", str(p.global_position))
	await t._frames(int(ForestTrail.STAGGER * 60) + 10)
	t.check(trail.cliff_fired and trail.cliff.all(func(r: Raptor) -> bool: return not r.lurking and r.visible), "lá em cima os 2 raptors saem das moitas")
	var chest: Chest = main.chests.filter(func(c: Chest) -> bool: return c.item == "shotgun")[0]
	t.check(Yard.on_plateau(chest.global_position + Vector3.UP * 0.1), "o baú da escopeta fica no planalto", str(chest.global_position))
	t.check(trail.sections[2].all(func(r: Raptor) -> bool: return r.lurking), "do barranco e do planalto ela não solta os trechos de S3")
	main.queue_free()
	await t._frames(2)
