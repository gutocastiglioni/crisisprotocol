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
	await test_raptor_gait()
	await test_patrol_route()
	await test_alarm_calls_others()
	await test_damage_while_unaware_alarms()
	await test_loses_target_and_gives_up()
	await test_alerted_can_hide()
	await test_yard_nav()
	await test_main_scene_patrols()
	await test_doors_seal_rooms()
	await test_unreachable_hunt_gives_up()
	await test_sniper_forgets()


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
	check(r.state == "roar" and r.alert_level() == 3, "depois nota: grita e fica alertado", r.state)
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


## Passo do raptor no `_go`: andar até a ronda, trote/corrida acima disso; nunca a corrida em câmera lenta (nem na curva,
## em que freia para o andar) nem o andar acelerado ao investigar.
func test_raptor_gait() -> void:
	var pr := await _spawn(Vector3(0, 0, 30), Vector3(-6, 0, 0), -PI * 0.5)
	var r: Raptor = pr[1]
	r.sight_range = 0.0
	r.set_physics_process(false)
	var max_walk := r.patrol_speed / Raptor.WALK_ANIM_SPEED + 0.01
	for c in [[r.patrol_speed, -PI * 0.5, "Walk"], [r.investigate_speed, -PI * 0.5, "Run"], [r.hunt_speed, -PI * 0.5, "Run"],
			[r.hunt_speed, PI * 0.5, "Run"]]:
		r.global_position = Vector3(-6, 0, 0)
		r.rotation.y = c[1]
		r._best_left = INF
		var worst_walk := 0.0
		var slowest_run := INF
		for i in 40:
			r._go(Vector3(6, 0, 0), c[0], 1.0 / 60.0)
			if r.model.current == "Walk":
				worst_walk = maxf(worst_walk, r.model.anim_player.speed_scale)
			elif r.model.current == "Run":
				slowest_run = minf(slowest_run, r.model.anim_player.speed_scale)
			await t._frames(1)
		check(r.model.current == c[2] and worst_walk <= max_walk and slowest_run >= Enemy.RUN_MIN_SCALE - 0.01,
			"raptor a %.1f m/s: %s, sem andar acelerado nem corrida em câmera lenta" % [c[0], c[2]],
			"%s andar %.2f corrida %.2f" % [r.model.current, worst_walk, slowest_run])


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


## Alertado (caçando/procurando) ele vê mais longe e mais para os lados, mas não nas costas, e agachada ela ainda se
## esconde; em combate, parede no meio corta o rastro mesmo bem perto. Sem achá-la, esquece e volta à guarda.
func test_alerted_can_hide() -> void:
	var pr := await _spawn(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.crouching = true
	r.alert_t = Enemy.ALERT_TIME
	r.start_search()
	var fought := false
	for i in 480:
		await t._frames(1)
		fought = fought or r.state in Raptor.COMBAT
	check(not fought, "alertado, procurando: agachada a 8 m na frente não é vista", r.state)
	check(r.state == "idle" and r.alert_t == 0.0 and r.aware == 0.0, "não a acha: esquece e volta à guarda", "%s %.1f" % [r.state, r.alert_t])
	# em pé atrás dele, parada: alertado não vê nas costas
	pr = await _spawn(Vector3(0, 0, -6))
	r = pr[1]
	r.alert_t = Enemy.ALERT_TIME
	await t._frames(90)
	check(not r.state in Raptor.COMBAT and r.aware < 1.0, "alertado: não vê nas costas", "%s %.2f" % [r.state, r.aware])
	# em combate, colada mas atrás de parede: perde o rastro
	pr = await _spawn(Vector3(0, 0, 3))
	r = pr[1]
	_wall(pr[2], Vector3(0, 2, 1.5))
	await t._frames(2)
	check(not r._combat_sees(), "em combate a 3 m com parede no meio: não sabe onde ela está")


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
	var posts: Array = main.soldiers.filter(func(s: Soldier) -> bool: return s.hold_post)
	var post_start: Array = posts.map(func(s: Soldier) -> Vector3: return s.global_position)
	var post_moved := 0.0
	var alerted := false
	for i in 1500:
		await t._frames(1)
		for k in rs.size():
			moved[k] = maxf(moved[k], rs[k].global_position.distance_to(start[k]))
		sold_moved = maxf(sold_moved, main.soldiers[0].global_position.distance_to(sold_start))
		for k in posts.size():
			post_moved = maxf(post_moved, posts[k].global_position.distance_to(post_start[k]))
		for e in t.get_nodes_in_group("enemies"):
			alerted = alerted or e.alert_level() > 0
	for k in rs.size():
		if rs[k] in main.yard_raptors:
			# os do pátio ficam escondidos na mata até a emboscada no morto (ambush_tests.gd)
			check(rs[k].lurking and moved[k] < 0.1, "raptor %d do pátio espera escondido" % k, "%.1f m" % moved[k])
		else:
			check(moved[k] > 4.0, "raptor %d patrulha de verdade" % k, "%.1f m" % moved[k])
		check(rs[k].global_position.y > -0.5, "raptor %d não caiu do mundo" % k, str(rs[k].global_position))
	check(sold_moved > 3.0, "soldado faz a ronda de verdade", "%.1f m" % sold_moved)
	# os guardas novos da porta do pátio: de posto, no canto cercado pelas caixas (Level.DIVIDERS), parados
	check(posts.size() == 4 and posts.all(func(s: Soldier) -> bool: return s.route.is_empty() and s.global_position.x < -3.75 and s.global_position.z < 0.4),
		"4 guardas novos de posto na porta do pátio, no canto cercado de caixas", str(posts.size()))
	check(post_moved < 0.2, "os guardas de posto ficam parados (sem ronda)", "%.2f m" % post_moved)
	check(main.dummies.is_empty() and t.get_nodes_in_group("dummies").is_empty(), "o galpão não tem mais bonecos de treino")
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
	check(doors.size() == 3, "três portas: galpão-pátio, pátio-pedreira e o portão da sala dos clones", str(doors.size()))
	check(doors.all(func(d: Door) -> bool: return not d.opened), "as portas começam fechadas")
	check(Level.room_of(0.0) == 0 and Level.room_of(-30.0) == 1 and Level.room_of(-80.0) == 2, "três salas: galpão, pátio e pedreira")
	var yard_r: Raptor = main.raptors[0]
	yard_r.reset()  # fora da moita da emboscada: um raptor comum no pátio
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
	var shed_door: Door = null
	for d: Door in doors:
		if d.room == 0:
			shed_door = d
	check(p.pick_door() == shed_door, "perto da porta do galpão: aviso de abrir")
	if shed_door.is_locked():
		p.add_key(shed_door.lock)
	Input.action_press("interact")
	await t._frames(4)
	Input.action_release("interact")
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


## Busca no galpão (malha de gente, `Yard.bake_people_nav`, célula de 5 cm): os corredores de 1,6 m do labirinto (até o
## miolo, passando debaixo das mãos-francesas do mezanino) e o nicho da escada do mezanino são chão para os soldados; raptor não cabe.
## Alarme (topo da escada do mezanino, miolo do labirinto, em cima das caixas): além de quem viu, só os 2 soldados mais
## perto saem, andando; os outros param, olham e ficam. Cada um vai a um lugar (o primeiro ao mais perto que dá, o outro a
## um ponto com vista), vasculham uns pontos em volta, desistem e voltam à rotina; sentinelas voltam ao posto.
## Antes ficavam parados na boca do corredor ou presos na quina em "hunt" para sempre (HUD "BUSCA ATIVA" sem fim).
func test_unreachable_hunt_gives_up() -> void:
	var ladder_top := Vector3(Catwalk.LADDER_X, Catwalk.FLOOR_Y, Catwalk.FRONT_Z + 0.5)
	var maze_in := Level.maze_cell(1, 1)
	var searching := ["hunt", "investigate", "search", "sweep"]
	for at: Vector3 in [ladder_top, maze_in, Level.maze_cell(2, 0) + Vector3(0, Level.MAZE_STACK, 0)]:
		if t._world:
			t._world.queue_free()
			t._world = null
			await t.process_frame
		var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
		t.get_root().add_child(main)
		await t._frames(3)
		var people: RID = main.soldiers[0].nav_map
		check(people.is_valid() and main.soldiers.all(func(s: Soldier) -> bool: return s.nav_map == people), "soldados andam na malha de gente")
		# a sincronização do mapa roda em outra thread: espera por relógio
		var probe: Vector3 = Soldier.GUARDS[1].route[0]  # chão livre (o mapa vazio devolve a origem: ela não serve)
		var until := Time.get_ticks_msec() + 5000
		while Time.get_ticks_msec() < until and NavigationServer3D.map_get_closest_point(people, probe).distance_to(probe) > 0.5:
			await t._frames(1)
		if at == ladder_top:
			var raptor_map: RID = main.get_world_3d().navigation_map
			var cut := []
			for r in Level.MAZE.size():
				for c in Level.MAZE[r].length():
					var cell := Level.maze_cell(c, r)
					var path := NavigationServer3D.map_get_path(people, probe, cell, true)
					if Level.MAZE[r][c] == "." and (path.is_empty() or Enemy._flat(path[path.size() - 1] - cell).length() > 0.5):
						cut.append(Vector2i(c, r))
			check(cut.is_empty(), "todo corredor do labirinto (e o nicho da escada do mezanino) é chão para os soldados", str(cut))
			var raptor_path := NavigationServer3D.map_get_path(raptor_map, probe, maze_in, true)
			check(raptor_path.is_empty() or Enemy._flat(raptor_path[raptor_path.size() - 1] - maze_in).length() > 0.5, "raptor (malha grossa) não cabe no labirinto")
		# ela fica no telhado (começo da fase), longe da vista: só o alarme manda os guardas ao ponto
		var src: Soldier = main.soldiers[0]
		src.start_hunt(at)
		src.broadcast_alarm(at)
		var went := {}
		var in_niche := false
		var reached := false
		var swept := false
		var crowded := []
		var calm_at := -1.0
		for i in 6000:
			await t._frames(1)
			var busy := []
			for sd: Soldier in main.soldiers:
				if sd.state in searching:
					went[sd] = true
					busy.append(sd)
				in_niche = in_niche or (absf(sd.global_position.x - Catwalk.LADDER_X) < 0.8 and sd.global_position.z > Level.MAZE_Z0 + Level.MAZE_CELL)
				reached = reached or Enemy._flat(sd.global_position - at).length() < 1.2
				swept = swept or sd.state == "sweep"
			if i == 90:
				for a in busy.size():
					for b in range(a + 1, busy.size()):
						if Enemy._flat(busy[a]._goal - busy[b]._goal).length() < Enemy.CLAIM_DIST - 0.05:
							crowded.append("%s %s" % [busy[a]._goal, busy[b]._goal])
			if i > 90 and main.soldiers.all(func(s: Soldier) -> bool: return s.alert_level() == 0 and s.state in ["idle", "patrol", "look"]):
				calm_at = i / 60.0
				break
		check(went.size() == 3, "alarme em %s: quem viu e só os 2 mais perto vão procurar (não todos de vez)" % at, str(went.size()))
		check(crowded.is_empty(), "cada um vai a um lugar diferente (sem amontoar)", str(crowded))
		if at == ladder_top:
			check(in_niche, "um guarda entra no corredor até o pé da escada do mezanino")
		if at == maze_in:
			check(reached, "um guarda entra no miolo do labirinto e chega ao lugar")
		check(swept, "vasculham pontos em volta antes de desistir")
		check(calm_at >= 0.0, "alarme em %s: todos desistem e voltam à rotina em menos de 100 s" % at,
			str(main.soldiers.map(func(s: Soldier) -> String: return "%s %s" % [s.state, s.global_position])))
		# os sentinelas voltam andando (o do canto atravessa o galpão inteiro) e param no posto
		var off_post := []
		for i in 5400:
			off_post.clear()
			for k in Soldier.GUARDS.size():
				var g: Dictionary = Soldier.GUARDS[k]
				var sd: Soldier = main.soldiers[k]
				if g.route.is_empty() and (sd.state != "idle" or Enemy._flat(sd.global_position - g.pos).length() > 1.2):
					off_post.append("%d %s %s" % [k, sd.state, sd.global_position])
			if off_post.is_empty():
				break
			await t._frames(1)
		check(off_post.is_empty(), "sentinelas voltam andando ao posto e param lá", str(off_post))
		main.queue_free()
		await t.process_frame


## Sniper do mezanino: com ela à vista mira (laser) e atira; ela some atrás das caixas do labirinto = o laser apaga, ele
## não atira mais nas caixas e, sem vê-la por LOSE_TIME, procura na passarela e esquece. Antes cada ciclo de mira e
## recarga zerava o tempo sem vê-la: atirava nas caixas para sempre (impossível de jogar).
func test_sniper_forgets() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t.process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(3)
	var p: Player = main.player
	p.health = 100000
	for sd: Soldier in main.soldiers:
		sd.global_position = Vector3(0, -40, 0)  # só o sniper
	var sn: Sniper = main.sniper
	# no chão, à frente do mezanino (fora do ponto cego), parada à vista
	p.global_position = Vector3(-1.0, 0, -4.0)
	p.reset_physics_interpolation()
	await t._frames(3)
	sn.spot()
	var shots0 := sn.shots_fired
	for i in 600:
		await t._frames(1)
		if sn.shots_fired > shots0:
			break
	check(sn.shots_fired > shots0, "sniper atira nela à vista")
	# ela some no canto do labirinto onde a escada do telhado desce (atrás das pilhas de caixas: dali ele não a vê)
	p.global_position = Level.maze_cell(11, 3)
	p.reset_physics_interpolation()
	await t._frames(30)
	var shots1 := sn.shots_fired
	var calm_at := -1.0
	for i in 1500:
		await t._frames(1)
		if not sn.in_combat() and sn.alert_level() == 0 and sn.alert_t == 0.0:
			calm_at = i / 60.0
			break
	check(sn.shots_fired == shots1, "escondida: ele não atira mais nas caixas", str(sn.shots_fired - shots1))
	check(not sn.laser_mesh.visible, "escondida: laser apagado")
	check(calm_at >= 0.0 and calm_at < 15.0, "sem vê-la, procura na passarela e esquece (em menos de 15 s)", "%s %.1f" % [sn.state, calm_at])
	main.queue_free()
	await t.process_frame
