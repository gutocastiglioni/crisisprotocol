extends RefCounted
## Testes da IA dos raptors (patrulha, visão com cone, audição, alarme, perda de rastro) e do pátio da mata
## (segunda sala: porta, malha de navegação, rotas). Chamados por run_tests.gd (usa check/_fresh_world/_frames de lá).
## Raptor na origem olhando para +Z (rotation.y = PI); a heroína é posta na frente (+Z) ou atrás (-Z) dele.

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_suspicion_then_spot()
	await test_cone_and_hearing()
	await test_crouch_stays_hidden()
	await test_crouch_close_is_seen()
	await test_cover_hides()
	await test_footsteps_make_noise()
	await test_gunshot_investigates()
	await test_patrol_route()
	await test_alarm_calls_others()
	await test_damage_while_unaware_alarms()
	await test_loses_target_and_gives_up()
	await test_yard_nav()
	await test_main_scene_patrols()
	await test_doors_seal_rooms()


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func _spawn(player_pos: Vector3, raptor_pos := Vector3.ZERO, raptor_yaw := PI, with_floor := true) -> Array:
	var w: Node3D = await t._fresh_world()
	if not with_floor:
		for c in w.get_children():
			c.free()
	var p := Player.new()
	p.position = player_pos
	w.add_child(p)
	var r := Raptor.new()
	r.position = raptor_pos
	r.rotation.y = raptor_yaw
	r.target = p
	w.add_child(r)
	r.rng.seed = 11
	await t._frames(2)
	return [p, r, w]


func _wall(w: Node3D, pos: Vector3, size := Vector3(30, 4, 0.4)) -> void:
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	wall.add_child(col)
	wall.position = pos
	w.add_child(wall)


func test_suspicion_then_spot() -> void:
	var pr := await _spawn(Vector3(0, 0, 8))
	var r: Raptor = pr[1]
	var seen := {}
	var first_roar := -1
	for i in 300:
		await t._frames(1)
		seen[r.state] = true
		if r.state == "roar" and first_roar < 0:
			first_roar = i
			break
	check(seen.has("suspicious"), "vê de longe: primeiro desconfia (para e olha)", str(seen.keys()))
	check(first_roar > 10, "não nota na hora a 8 m", str(first_roar))
	check(r.state == "roar" and r.alert_level() == 2, "depois nota: grita e fica alertado", r.state)
	check(r._marker.text == "!", "indicador ! sobre a cabeça", r._marker.text)


func test_cone_and_hearing() -> void:
	# ela atrás dele, parada: fora do cone (e sem barulho) ele não percebe
	var pr := await _spawn(Vector3(0, 0, -6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await t._frames(120)
	check(r.state == "idle" and r.aware == 0.0, "atrás dele e parada: não percebe", "%s %.2f" % [r.state, r.aware])
	# pisadas de corrida atrás dele: ouve, desconfia e vai ver
	for i in 4:
		p.make_noise(10.0, 0.5)
		await t._frames(1)
	check(r.state in ["suspicious", "investigate"], "ouve passos: desconfia ou investiga", r.state)
	await t._frames(10)
	check(r.state in ["suspicious", "investigate"], "continua desconfiado/investigando", r.state)
	for i in 400:
		await t._frames(1)
		if r.state in Raptor.COMBAT:
			break
	check(r.state in Raptor.COMBAT, "investigando, chega e a vê: ataca", r.state)


func test_crouch_stays_hidden() -> void:
	var pr := await _spawn(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.crouching = true
	await t._frames(240)
	check(p.visibility() < 0.35, "agachada e parada: pouco visível", str(p.visibility()))
	check(r.state == "idle" and r.aware == 0.0, "agachada a 8 m: ele não a percebe", "%s %.2f" % [r.state, r.aware])


func test_crouch_close_is_seen() -> void:
	var pr := await _spawn(Vector3(0, 0, 2.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.crouching = true
	for i in 240:
		await t._frames(1)
		if r.state in Raptor.COMBAT:
			break
	check(r.state in Raptor.COMBAT, "agachada mas colada nele: é vista", r.state)


func test_cover_hides() -> void:
	var pr := await _spawn(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var w: Node3D = pr[2]
	p.crouching = true
	await t._frames(3)
	var open_vis := p.visibility()
	var patch := Node3D.new()
	patch.add_to_group("cover")
	patch.set_meta("radius", 2.0)
	w.add_child(patch)
	patch.position = Vector3(0, 0, 8.5)
	await t._frames(3)
	check(p.visibility() < open_vis * 0.6, "agachada no capim alto: ainda menos visível", "%.2f -> %.2f" % [open_vis, p.visibility()])
	p.crouching = false
	await t._frames(3)
	check(p.visibility() > 0.5, "em pé no capim: aparece quase como no aberto", str(p.visibility()))
	patch.queue_free()


func test_footsteps_make_noise() -> void:
	var pr := await _spawn(Vector3(0, 0, -5))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	# passos de corrida (10 m) a 5 m chegam; um barulho de raio menor que a distância é ignorado
	r.hear_noise(p.global_position, 4.0, 0.3)
	check(r.aware == 0.0, "barulho que não alcança (5 m, raio 4): ignorado", str(r.aware))
	r.hear_noise(p.global_position, 10.0, 0.5)
	check(r.aware > 0.2 and r.aware < 0.3, "passos de corrida a 5 m: atenção sobe proporcional à distância", str(r.aware))
	# o jogador de verdade faz esse barulho ao correr (e nada parado)
	pr = await _spawn(Vector3(0, 0, -5))
	p = pr[0]
	r = pr[1]
	await t._frames(30)
	check(r.aware == 0.0, "parada: não faz barulho", str(r.aware))
	p.velocity = Vector3(0, 0, 4.4)
	p.stealth.step_t = 0.0
	p.stealth.update(0.016)
	check(r.aware > 0.0 or not p.is_on_floor(), "correndo no chão: o raptor ouve", str(r.aware))


func test_gunshot_investigates() -> void:
	var pr := await _spawn(Vector3(0, 0, 20))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.make_noise(26.0, 2.2)
	await t._frames(2)
	check(r.state == "suspicious", "tiro a 20 m: desconfia", r.state)
	pr = await _spawn(Vector3(0, 0, 10))
	p = pr[0]
	r = pr[1]
	p.make_noise(26.0, 2.2)
	await t._frames(2)
	check(r.state == "investigate", "tiro a 10 m: vai investigar", r.state)


func test_patrol_route() -> void:
	var pr := await _spawn(Vector3(0, 0, 19), Vector3(-5, 0, -5), -PI * 0.5)
	var r: Raptor = pr[1]
	r.route = [Vector3(-5, 0, -5), Vector3(5, 0, -5)]
	var states := {}
	var min_x := 99.0
	var max_x := -99.0
	var max_speed := 0.0
	for i in 900:
		await t._frames(1)
		states[r.state] = true
		min_x = minf(min_x, r.global_position.x)
		max_x = maxf(max_x, r.global_position.x)
		max_speed = maxf(max_speed, Vector2(r.velocity.x, r.velocity.z).length())
	check(states.has("patrol") and states.has("look"), "patrulha anda e para para olhar em volta", str(states.keys()))
	check(min_x < -4.0 and max_x > 4.0, "vai e volta entre os pontos", "%.1f..%.1f" % [min_x, max_x])
	check(max_speed <= r.patrol_speed + 0.05, "andando a ritmo de patrulha", str(max_speed))
	check(not states.has("roar"), "sem ela por perto: patrulha em paz")


func test_alarm_calls_others() -> void:
	var pr := await _spawn(Vector3(0, 0, 8))
	var w: Node3D = pr[2]
	var a: Raptor = pr[1]
	var b := Raptor.new()
	b.position = Vector3(-18, 0, -10)
	b.target = pr[0]
	w.add_child(b)
	b.rng.seed = 5
	await t._frames(2)
	for i in 300:
		await t._frames(1)
		if a.state == "roar":
			break
	check(a.state == "roar", "o primeiro viu e gritou", a.state)
	for i in 120:
		await t._frames(1)
		if b.state == "hunt":
			break
	check(b.state == "hunt", "o outro (sem vê-la) ouve o grito e vem correndo", b.state)
	check(b.alert_level() == 2 and b._marker.text == "!", "outro alertado mostra !", b.state)
	a.process_mode = Node.PROCESS_MODE_DISABLED  # o primeiro não ataca enquanto o outro chega
	var start := b.global_position.distance_to(pr[0].global_position)
	for i in 900:
		await t._frames(1)
		if b.state in Raptor.COMBAT:
			break
	check(b.state in Raptor.COMBAT, "chega, a vê e também ataca", "%s a %.1f m (partiu de %.1f)" % [b.state, b.global_position.distance_to(pr[0].global_position), start])


func test_damage_while_unaware_alarms() -> void:
	var pr := await _spawn(Vector3(0, 0, -8))
	var w: Node3D = pr[2]
	var a: Raptor = pr[1]
	var b := Raptor.new()
	b.position = Vector3(12, 0, -14)
	b.target = pr[0]
	w.add_child(b)
	await t._frames(2)
	check(a.state == "idle" and b.state == "idle", "ninguém a percebeu ainda")
	a.take_hit(10, Vector3.BACK, a.global_position + Vector3.UP)
	check(a.alert_t > 0.0 and a.state == "hit", "levou tiro sem ver: alertado", a.state)
	for i in 120:
		await t._frames(1)
		if b.state == "hunt":
			break
	check(b.state == "hunt" or b.state in Raptor.COMBAT, "tiro no primeiro alerta o segundo", b.state)
	check(b.alert_t > 0.0, "o segundo ficou alertado", str(b.alert_t))


func test_loses_target_and_gives_up() -> void:
	var pr := await _spawn(Vector3(0, 0, 5))
	var p: Player = pr[0]
	var w: Node3D = pr[2]
	var r: Raptor = pr[1]
	_wall(w, Vector3(0, 2, 10))
	r.start_study()
	await t._frames(5)
	check(r.state == "study", "estudando a presa", r.state)
	# ela some atrás da parede, longe: depois de LOSE_TIME ele vai ao último lugar onde a viu
	p.global_position = Vector3(0, 0, 19)
	p.reset_physics_interpolation()
	var hunted := false
	for i in 600:
		await t._frames(1)
		if r.state == "hunt":
			hunted = true
			break
	check(hunted, "perde a presa de vista e vai caçar o último lugar", r.state)
	var searched := false
	for i in 600:
		await t._frames(1)
		if r.state == "search":
			searched = true
			break
	check(searched, "chega no lugar, não acha ninguém: procura", r.state)
	check(r.global_position.distance_to(Vector3(0, 0, 5)) < 2.0, "procurou onde a viu por último", str(r.global_position))
	for i in 600:
		await t._frames(1)
		if r.state == "idle":
			break
	check(r.state == "idle" and r.alert_t == 0.0 and r.aware == 0.0, "desiste e volta à guarda", "%s %.1f" % [r.state, r.alert_t])


func test_yard_nav() -> void:
	var w: Node3D = await t._fresh_world()
	for c in w.get_children():
		c.free()
	Level.build(w)
	Yard.bake_nav(w)
	var map := w.get_world_3d().navigation_map
	# a sincronização do mapa roda em outra thread: espera por relógio (com passo fixo os quadros passam rápido demais)
	var probe: Vector3 = Yard.POSTS[0].pos
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) > 0.5:
		await t._frames(1)
	check(NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) <= 0.5, "malha de navegação do pátio sincronizada")
	# porta fechada: nada passa (tiro, visão, corpo); aberta (E), um raio passa de um lado ao outro, e a parede ao lado bloqueia
	var space := w.get_world_3d().direct_space_state
	var through := PhysicsRayQueryParameters3D.create(Vector3(-10, 1.0, Yard.DOOR_Z), Vector3(-16, 1.0, Yard.DOOR_Z), 1)
	check(not space.intersect_ray(through).is_empty(), "porta do galpão começa fechada")
	for d: Door in w.get_tree().get_nodes_in_group("doors"):
		d.open()
	await t._frames(3)
	check(space.intersect_ray(through).is_empty(), "porta: passa de um lado ao outro")
	var beside := PhysicsRayQueryParameters3D.create(Vector3(-10, 1.0, 4.0), Vector3(-16, 1.0, 4.0), 1)
	check(not space.intersect_ray(beside).is_empty(), "parede oeste fora da porta continua fechada")
	var lintel := PhysicsRayQueryParameters3D.create(Vector3(-10, Yard.DOOR_H + 0.5, Yard.DOOR_Z), Vector3(-16, Yard.DOOR_H + 0.5, Yard.DOOR_Z), 1)
	check(not space.intersect_ray(lintel).is_empty(), "porta: verga fecha o vão em cima")
	# pontos de partida e rotas em chão livre (na malha) e ligados entre si e ao galpão
	var bad := []
	for post in Yard.POSTS:
		for p: Vector3 in post.route:
			if NavigationServer3D.map_get_closest_point(map, p).distance_to(p) > 0.5:
				bad.append(p)
	check(bad.is_empty(), "todos os pontos de patrulha estão na malha (fora das árvores)", str(bad))
	var shed := Vector3(0, 0, 6)
	var cut := []
	for post in Yard.POSTS:
		var path := NavigationServer3D.map_get_path(map, post.pos, shed, true)
		if path.is_empty() or path[path.size() - 1].distance_to(shed) > 1.0:
			cut.append(post.pos)
	check(cut.is_empty(), "do pátio dá para chegar ao galpão pela porta", str(cut))
	var through_door := false
	for pt in NavigationServer3D.map_get_path(map, Yard.POSTS[1].pos, shed, true):
		if absf(pt.x + 13.0) < 1.0 and absf(pt.z - Yard.DOOR_Z) < Yard.DOOR_W * 0.5:
			through_door = true
	check(through_door, "o caminho passa pela porta")
	# um raptor de verdade percorre esse caminho até o galpão
	var r := Raptor.new()
	r.position = Yard.POSTS[1].pos
	w.add_child(r)
	await t._frames(3)
	r.start_hunt(shed)
	var arrived := false
	for i in 1800:
		await t._frames(1)
		if r.state == "search":
			arrived = true
			break
	check(arrived and r.global_position.distance_to(shed) < 1.6, "caça do pátio ao galpão, passando pela porta, sem prender", "%s %s" % [r.state, r.global_position])
	# e volta (patrulha de uma rota que cruza a clareira, desviando das árvores)
	r.start_hunt(Yard.POSTS[2].pos)
	arrived = false
	for i in 1800:
		await t._frames(1)
		if r.state == "search":
			arrived = true
			break
	check(arrived and r.global_position.distance_to(Yard.POSTS[2].pos) < 1.6, "volta do galpão ao fundo do pátio", "%s %s" % [r.state, r.global_position])


func test_main_scene_patrols() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t.process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(3)
	var rs: Array = main.raptors
	check(main.soldiers.size() == Soldier.GUARDS.size(), "cena principal: soldados de guarda no galpão", str(main.soldiers.size()))
	for sd: Soldier in main.soldiers:
		check(absf(sd.global_position.x) < 13.0 and absf(sd.global_position.z) < 13.0, "soldado começa dentro do galpão", str(sd.global_position))
	check(rs.size() == Yard.POSTS.size() + Arena.POSTS.size(), "cena principal: um raptor por posto (pátio e pedreira)", str(rs.size()))
	var start := []
	for r: Raptor in rs:
		start.append(r.global_position)
		check(r.global_position.x < -13.0, "raptor começa no pátio (fora do galpão)", str(r.global_position))
	var moved := []
	moved.resize(rs.size())
	moved.fill(0.0)
	var sold_moved := 0.0
	var sold_start: Vector3 = main.soldiers[0].global_position
	var alerted := false
	for i in 1500:
		await t._frames(1)
		for k in rs.size():
			moved[k] = maxf(moved[k], rs[k].global_position.distance_to(start[k]))
		sold_moved = maxf(sold_moved, main.soldiers[0].global_position.distance_to(sold_start))
		for e in t.get_nodes_in_group("enemies"):
			alerted = alerted or e.alert_level() > 0
	for k in rs.size():
		check(moved[k] > 4.0, "raptor %d patrulha de verdade" % k, "%.1f m" % moved[k])
		check(rs[k].global_position.y > -0.5, "raptor %d não caiu do mundo" % k, str(rs[k].global_position))
	check(sold_moved > 3.0, "soldado faz a ronda de verdade", "%.1f m" % sold_moved)
	check(not alerted, "a heroína parada na entrada não é notada por ninguém (raptors, alossauro nem guardas do galpão)")
	main.queue_free()
	await t.process_frame


## Três salas separadas por portas fechadas: o tiro e o alarme de uma sala não chamam os inimigos das outras; com a porta
## aberta (E) o barulho passa; a porta abre ao interagir perto dela.
func test_doors_seal_rooms() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t.process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(3)
	var doors := t.get_nodes_in_group("doors")
	check(doors.size() == 2, "duas portas: galpão-pátio e pátio-pedreira", str(doors.size()))
	check(doors.all(func(d: Door) -> bool: return not d.opened), "as portas começam fechadas")
	check(Level.room_of(0.0) == 0 and Level.room_of(-30.0) == 1 and Level.room_of(-80.0) == 2, "três salas: galpão, pátio e pedreira")
	var yard_r: Raptor = main.raptors[0]
	var p: Player = main.player
	# depois de matar os guardas a tiros, nada vem: tiro e grito não atravessam a porta fechada
	p.global_position = Vector3(-11.5, 0, Yard.DOOR_Z)
	main.soldiers[0].spot()
	p.make_noise(26.0, 2.2)
	await t._frames(30)
	check(yard_r.alert_level() == 0 and yard_r.aware < 0.1, "porta fechada: o tiro e o alarme do galpão não chegam ao pátio", "%d %.2f" % [yard_r.alert_level(), yard_r.aware])
	for r: Raptor in main.raptors:
		check(r.alert_level() == 0, "porta fechada: nenhum raptor alertado", str(r.global_position))
	check(main.allosaurus.alert_level() == 0, "porta fechada: o alossauro não ouve nada")
	# a porta abre com E, perto dela
	check(p.pick_door() != null and p.pick_door().room == 0, "perto da porta do galpão: aviso de abrir")
	Input.action_press("interact")
	await t._frames(4)
	Input.action_release("interact")
	var shed_door: Door = null
	for d: Door in doors:
		if d.room == 0:
			shed_door = d
	check(shed_door.opened and shed_door.collision_layer == 0, "E abre a porta e tira a colisão")
	check(Level.connected(t, 0, 1) and not Level.connected(t, 0, 2), "porta do galpão aberta, a do portão ainda fechada")
	p.make_noise(26.0, 2.2)
	await t._frames(3)
	check(yard_r.aware > 0.5 or yard_r.alert_level() > 0, "porta aberta: o tiro chega ao pátio", "%.2f" % yard_r.aware)
	for r: Raptor in main.raptors.slice(Yard.POSTS.size()):
		check(r.alert_level() == 0 and r.aware < 0.1, "pedreira continua sem ouvir (portão fechado)", str(r.aware))
	# reiniciar fecha as portas
	main.reset_all()
	check(not shed_door.opened and shed_door.collision_layer == 1, "reiniciar fecha as portas")
	main.queue_free()
	await t.process_frame
