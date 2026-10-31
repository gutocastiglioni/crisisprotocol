extends "res://tests/ai_tests.gd"
## Testes do guerrilheiro encapuzado (Soldier): modelo próprio, patrulha, combate com tiros, morte, recuo, alarme em
## comum com os raptors e perda de rastro. Usa os auxiliares de ai_tests.gd; chamado por run_tests.gd.


func run(runner: SceneTree) -> void:
	t = runner
	await test_guerrilla_asset()
	await test_soldier_patrol_and_spot()
	await test_soldier_gait_like_player()
	await test_soldier_shoots_and_misses()
	await test_soldier_presses_fire()
	await test_soldier_dies()
	await test_soldier_backs_off()
	await test_shared_alarm()
	await test_soldier_loses_target()
	await test_soldier_drops()
	await test_soldier_catwalk_los_and_boundaries()
	await test_soldier_idle_head_look()
	await test_post_guard_holds_until_spotted()
	await test_stealth_alert_states_and_corpse_detection()
	await test_searching_enemy_spots_on_noise_or_nearby_kill()
	await test_enemies_separation_and_no_overlap()
	await test_soldier_hunts_player_behind_rear_crates()


func _spawn_soldier(player_pos: Vector3, soldier_pos := Vector3.ZERO, yaw := PI) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	w.add_child(p)
	var s := Soldier.new()
	s.position = soldier_pos
	s.rotation.y = yaw
	s.target = p
	w.add_child(s)
	s.rng.seed = 3
	await t._frames(2)
	return [p, s, w]


func test_guerrilla_asset() -> void:
	# o guerrilheiro encapuzado: mesmo esqueleto e animações da heroína (o HeroineModel serve aos dois), visual próprio
	var inst: Node = Soldier.BODY.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	var base: Node = (load("res://assets/characters/heroine.glb") as PackedScene).instantiate()
	var base_sk: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var base_names := []
	for i in base_sk.get_bone_count():
		if not base_sk.get_bone_name(i).begins_with("Braid"):  # a trança dela é só dela
			base_names.append(base_sk.get_bone_name(i))
	check(names == base_names, "guerrilheiro: mesmo esqueleto da heroína (sem a trança)", str(names))
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var base_ap: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	var missing := []
	for a in base_ap.get_animation_list():
		if not ap.has_animation(a):
			missing.append(a)
	check(missing.is_empty(), "guerrilheiro: todas as animações da heroína", str(missing))
	for w in ["Pistol", "M16", "Shotgun", "ShotgunPump", "Muzzle", "RifleMuzzle", "ShotgunMuzzle"]:
		check(inst.find_child(w, true, false) != null, "guerrilheiro: " + w)
	var tris := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name in ["Pistol", "M16", "Shotgun", "ShotgunPump"]:
			continue
		var arr: Array = mi.mesh.surface_get_arrays(0)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris >= 800 and tris <= 5000, "guerrilheiro: orçamento de triângulos do PS2", str(tris))
	var img: Image = Soldier.ATLAS.get_image()
	check(img.get_size() == Vector2i(512, 512), "atlas do guerrilheiro 512x512", str(img.get_size()))
	var magenta := 0
	for y in range(0, 512, 8):
		for x in range(0, 512, 8):
			var c := img.get_pixel(x, y)
			if c.r > 0.95 and c.g < 0.05 and c.b > 0.95:
				magenta += 1
	check(magenta == 0, "atlas do guerrilheiro sem fundo magenta", str(magenta))
	# a cabeça é o capuz preto (nada de cabelo ruivo da heroína): o retângulo da cabeça é escuro
	var dark := 0.0
	var n := 0
	for y in range(8, 120, 6):
		for x in range(264, 504, 6):
			dark += img.get_pixel(x, y).get_luminance()
			n += 1
	check(dark / n < 0.25, "guerrilheiro: cabeça coberta por capuz escuro", str(dark / n))
	# o coturno fica em volta do tornozelo (antes ficava ~4 cm para dentro e o pé girava fora dele)
	var foot_x := sk.get_bone_global_rest(sk.find_bone("Foot_L")).origin.x
	var sum_x := 0.0
	var cnt := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if not mi.name.begins_with("Guerrilla") or mi.name in ["GuerrillaHood", "GuerrillaGear"]:
			continue
		for si in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				if v.y < 0.12 and v.x > 0.0:
					sum_x += v.x
					cnt += 1
	check(cnt > 20 and absf(sum_x / maxi(cnt, 1) - foot_x) < 0.02, "guerrilheiro: coturno na linha do tornozelo",
		"%.3f vs osso %.3f (%d vértices)" % [sum_x / maxi(cnt, 1), foot_x, cnt])
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var s: Soldier = pr[1]
	check(s.model.scene == Soldier.BODY and s.model.atlas == Soldier.ATLAS, "soldado usa o modelo do guerrilheiro, não o da heroína")
	check(s.model.is_weapon_visible("m16") and not s.model.is_weapon_visible("pistol"), "guerrilheiro empunha o M16")
	inst.free()
	base.free()


## Mesmo critério de passo da jogadora: o andar nunca toca acima da velocidade em que foi resolvido; mais rápido
## (investigando = trote, caçando) é a corrida, nunca o andar acelerado nem a corrida em câmera lenta (nem nas curvas:
## virando muito, freia para o passo de andar).
func test_soldier_gait_like_player() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 30), Vector3(-6, 0, 0), -PI * 0.5)
	var s: Soldier = pr[1]
	s.sight_range = 0.0
	s.set_physics_process(false)  # só o _go manda no corpo (parado, a rotina dele trocaria para "idle")
	var seen := []
	# o último caso começa de costas para o destino (curva de 180°) na velocidade de caçar
	for c in [[s.patrol_speed, -PI * 0.5], [s.investigate_speed, -PI * 0.5], [s.hunt_speed, -PI * 0.5], [s.hunt_speed, PI * 0.5]]:
		s.global_position = Vector3(-6, 0, 0)
		s.rotation.y = c[1]
		s._best_left = INF
		var worst_walk := 0.0
		var slowest_run := INF
		var gaits := {}
		for i in 40:
			s._go(Vector3(6, 0, 0), c[0], 1.0 / 60.0)
			gaits[s.model.state] = true
			if s.model.state == "walk":
				worst_walk = maxf(worst_walk, float(s.model.tree.get("parameters/walk_speed/scale")))
			elif s.model.state == "run":
				slowest_run = minf(slowest_run, float(s.model.tree.get("parameters/run_speed/scale")))
			await t._frames(1)
		seen.append([s.model.state, worst_walk, float(s.model.tree.get("parameters/run_speed/scale")), slowest_run, gaits.keys()])
	var patrol: Array = seen[0]
	var investigate: Array = seen[1]
	var hunt: Array = seen[2]
	var turn: Array = seen[3]
	check(patrol[0] == "walk" and patrol[1] <= HeroineModel.GAIT_WALK_MAX + 0.01, "ronda: passo de andar na velocidade dele", str(patrol))
	check(investigate[0] == "run" and investigate[1] <= HeroineModel.GAIT_WALK_MAX + 0.01 and investigate[3] >= Enemy.RUN_MIN_SCALE - 0.01,
		"investigando: trote (corrida a %.0f%%), sem andar acelerado nem câmera lenta" % (Enemy.JOG_SCALE * 100.0), str(investigate))
	check(hunt[0] == "run" and absf(hunt[2] - s.hunt_speed / Player.RUN_SPEED) < 0.05, "caçando: corrida no ritmo da velocidade", str(hunt))
	check(turn[0] == "run" and "walk" in turn[4] and turn[1] <= HeroineModel.GAIT_WALK_MAX + 0.01 and turn[3] >= Enemy.RUN_MIN_SCALE - 0.01,
		"curva fechada correndo: freia no passo de andar e volta a correr, sem corrida em câmera lenta", str(turn))


func test_soldier_patrol_and_spot() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 19), Vector3(-5, 0, -5), -PI * 0.5)
	var s: Soldier = pr[1]
	s.route = [Vector3(-5, 0, -5), Vector3(5, 0, -5)]
	var states := {}
	var max_x := -99.0
	for i in 900:
		await t._frames(1)
		states[s.state] = true
		max_x = maxf(max_x, s.global_position.x)
	check(states.has("patrol") and states.has("look") and max_x > 4.0, "soldado patrulha a rota e para para olhar", "%s %.1f" % [str(states.keys()), max_x])
	check(s.model.state in ["idle", "walk"], "animação de andar/parado", s.model.state)
	# ela à vista a 8 m: desconfia, ergue a arma e entra em combate
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	s = pr[1]
	var seen := {}
	for i in 400:
		await t._frames(1)
		seen[s.state] = true
		if s.state == "engage":
			break
	check(seen.has("suspicious") and seen.has("alert") and s.state == "engage", "soldado: desconfia, reage, combate", str(seen.keys()))
	check(s.alert_level() == 3 and s._marker.text == "!", "soldado alertado mostra !", s._marker.text)


func test_soldier_shoots_and_misses() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	s.start_engage()
	await t._frames(5)
	for i in 600:
		await t._frames(1)
	check(s.shots_fired > 4, "no combate ele atira em rajadas", str(s.shots_fired))
	check(p.health < 100, "alguns tiros acertam", str(p.health))
	# rolando ela esquiva de todos
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	p = pr[0]
	s = pr[1]
	s.start_engage()
	p.rolling = true
	for i in 40:
		s._fire()
	check(p.health == 100, "cambalhota esquiva dos tiros", str(p.health))
	p.rolling = false
	# parede no meio: tiros batem nela
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	p = pr[0]
	s = pr[1]
	_wall(pr[2], Vector3(0, 2, 4))
	await t._frames(2)
	for i in 40:
		s._fire()
	check(p.health == 100, "parede no meio: nenhum tiro chega", str(p.health))


## Rajadas longas com descanso curto (sem pausas de segundos) e, quando ela some atrás de algo, um pouco de fogo de
## supressão onde ela estava, que não a acerta.
func test_soldier_presses_fire() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	p.health = 100000
	var clock := [0]
	var times: Array[int] = []
	s.fired.connect(func() -> void: times.append(clock[0]))
	s.start_engage()
	for i in 360:
		await t._frames(1)
		clock[0] = i
	var first := 0
	while first + 1 < times.size() and times[first + 1] - times[first] < 12:
		first += 1
	var longest := 0
	for i in range(1, times.size()):
		longest = maxi(longest, times[i] - times[i - 1])
	check(first + 1 >= Soldier.BURST_SHOTS[0], "rajada de pelo menos %d tiros" % Soldier.BURST_SHOTS[0], str(first + 1))
	check(times.size() >= 15, "atira muito em 6 s", str(times.size()))
	check(longest < 60, "nunca para mais de 1 s entre rajadas", "%d quadros" % longest)
	check(not times.is_empty() and times[0] < 45, "primeiro tiro logo depois de vê-la", str(times[0] if times.size() else -1))
	# ela some atrás de uma parede: ele ainda atira ali um pouco, sem acertar, e depois para
	var hp := p.health
	_wall(pr[2], Vector3(0, 2, 4))
	await t._frames(2)
	times.clear()
	for i in 150:
		await t._frames(1)
		clock[0] = i
	var early := times.filter(func(f: int) -> bool: return f < 70).size()
	var late := times.filter(func(f: int) -> bool: return f >= 100).size()
	check(early > 0, "perdeu de vista: fogo de supressão onde ela estava", str(times))
	check(late == 0, "supressão acaba", str(times))
	check(p.health == hp, "supressão bate na parede, não nela", str(hp - p.health))


func test_soldier_dies() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var s: Soldier = pr[1]
	var killed := [false]
	s.killed.connect(func() -> void: killed[0] = true)
	s.take_hit(34, Vector3.BACK, s.global_position + Vector3.UP)
	check(not s.dead and s.state == "hit" and s.alert_t > 0.0, "levou um tiro: reage e fica alerta", s.state)
	await t._frames(40)
	s.take_hit(34, Vector3.BACK, s.global_position + Vector3.UP)
	check(s.dead and s.state == "dead" and killed[0], "morre com a vida zerada")
	check(s.collision_layer == 0 and s.model.is_ragdoll(), "vira ragdoll e sai da física")
	check(s.alert_level() == 0 and not s._marker.visible, "morto não alerta")
	await t._frames(30)
	check(is_finite(s.model.ragdoll.bodies["Hips"].global_position.y), "ragdoll sem NaN")
	await t._frames(180)
	check(s.global_position.y > -0.5 and s.model.skeleton.global_position.y > -0.5, "morto não afunda no chão (o corpo não some)", str(s.global_position))
	s.reset()
	await t._frames(3)
	check(not s.dead and s.health == Soldier.MAX_HEALTH and s.collision_layer == 2 and not s.model.is_ragdoll(), "reset: de pé e vivo")


func test_soldier_backs_off() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 3.2))
	var p: Player = pr[0]
	p.health = 100000
	var s: Soldier = pr[1]
	s.start_engage()
	var d0 := s.global_position.distance_to(p.global_position)
	await t._frames(90)
	check(s.global_position.distance_to(p.global_position) > d0 + 0.5, "ela chega perto: ele recua", "%.1f -> %.1f" % [d0, s.global_position.distance_to(p.global_position)])
	check(s.model.state in ["walk", "strafe_l", "strafe_r", "idle"], "recua sem virar de costas (mirando)", s.model.state)


func test_shared_alarm() -> void:
	# o grito de um raptor chama o soldado, e o soldado que a vê chama o raptor
	var pr := await _spawn(Vector3(0, 0, 8))
	var w: Node3D = pr[2]
	var r: Raptor = pr[1]
	var s := Soldier.new()
	s.position = Vector3(-18, 0, -10)
	s.target = pr[0]
	w.add_child(s)
	await t._frames(2)
	for i in 300:
		await t._frames(1)
		if r.state == "roar":
			break
	for i in 120:
		await t._frames(1)
		if s.state == "investigate":
			break
	check(s.state == "investigate" and s.alert_level() == 2, "raptor grita: o soldado vem procurar (andando, com calma)", s.state)
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	w = pr[2]
	s = pr[1]
	r = Raptor.new()
	r.position = Vector3(-18, 0, -10)
	r.target = pr[0]
	w.add_child(r)
	await t._frames(2)
	for i in 400:
		await t._frames(1)
		if s.state in Soldier.COMBAT:
			break
	for i in 120:
		await t._frames(1)
		if r.state == "hunt":
			break
	check(r.state == "hunt" and r.alert_level() == 2, "soldado a vê: o raptor vem caçar", r.state)


func test_soldier_loses_target() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	_wall(pr[2], Vector3(0, 2, 12))
	s.start_engage()
	await t._frames(5)
	p.health = 100000
	p.global_position = Vector3(0, 0, 19)
	p.reset_physics_interpolation()
	var hunted := false
	for i in 600:
		await t._frames(1)
		if s.state == "hunt":
			hunted = true
			break
	check(hunted, "perde a heroína de vista: vai ao último lugar", s.state)
	var searched := false
	for i in 900:
		await t._frames(1)
		if s.state == "search":
			searched = true
			break
	check(searched, "chega e procura", s.state)


func test_soldier_drops() -> void:
	GameMode.set_mode(GameMode.SURVIVAL)
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	var w: Node3D = pr[2]
	p.reset_loadout()
	check(p.weapons == ["pistol"], "comeca apenas com pistola")
	s.take_hit(100, Vector3.BACK, s.global_position + Vector3.UP)
	await t._frames(10)
	check(s.dead and s.model.holstered, "soldado morre e solta a arma da mao")
	var drops := w.find_children("*", "Pickup", true, false)
	check(drops.size() >= 1, "soldado dropa item no mundo", str(drops.size()))
	var drop: Pickup = drops[0]
	check(drop.is_weapon and drop.kind == "m16" and drop.amount == 15, "drop e o fuzil M16 com 15 balas")
	# Jogadora passa por cima e pega a arma
	p.global_position = drop.global_position
	await t._frames(5)
	check("m16" in p.weapons and p.weapon() == "m16", "jogadora pegou o fuzil dropado do soldado")
	check(p.ammo_of("m16") == 15, "jogadora recebeu as 15 balas da arma dropada", str(p.ammo_of("m16")))
	# Segundo soldado dropa municao
	var s2 := Soldier.new()
	s2.position = Vector3(5, 0, 0)
	s2.drop_is_weapon = false
	s2.drop_kind = "shotgun"
	s2.drop_amount = 6
	s2.target = p
	w.add_child(s2)
	s2.take_hit(100, Vector3.BACK, s2.global_position + Vector3.UP)
	await t._frames(10)
	var drops2 := w.find_children("*", "Pickup", true, false)
	var ammo_drop: Pickup = null
	for d in drops2:
		if not d.is_weapon and d.kind == "shotgun":
			ammo_drop = d
			break
	check(ammo_drop != null and ammo_drop.amount == 6, "segundo soldado dropou caixa de municao de escopeta")
	p.global_position = ammo_drop.global_position
	await t._frames(5)
	check(p.ammo_of("shotgun") == 6, "jogadora coletou a municao dropada", str(p.ammo_of("shotgun")))
	# Sniper dropa o rifle Sniper
	var sn := Sniper.new()
	sn.position = Vector3(-5, 0, 0)
	sn.target = p
	w.add_child(sn)
	sn.take_hit(100, Vector3.BACK, sn.global_position + Vector3.UP)
	await t._frames(10)
	check(sn.dead and sn.model.holstered, "sniper morre e solta o fuzil de precisao")
	var drops3 := w.find_children("*", "Pickup", true, false)
	var sniper_drop: Pickup = null
	for d in drops3:
		if d.is_weapon and d.kind == "sniper":
			sniper_drop = d
			break
	check(sniper_drop != null and sniper_drop.amount == 5, "sniper dropou o fuzil Sniper com 5 balas")
	p.global_position = sniper_drop.global_position
	await t._frames(5)
	check("sniper" in p.weapons and p.weapon() == "sniper", "jogadora pegou o rifle Sniper dropado")
	check(p.ammo_of("sniper") == 5, "jogadora recebeu municao do Sniper", str(p.ammo_of("sniper")))


func test_soldier_catwalk_los_and_boundaries() -> void:
	var w: Node3D = await t._fresh_world()
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var p := Player.new()
	p.position = Vector3(0, Catwalk.FLOOR_Y, 12.0)
	p.health = 100000
	w.add_child(p)
	
	var s := Soldier.new()
	s.position = Vector3(0, 0, 4.0)
	s.target = p
	w.add_child(s)
	await t._frames(3)
	
	# 1. Alvo elevado detectado e mira inclinada para cima
	check(s._is_target_elevated(), "soldado identifica que a heroina esta no mezanino/elevada")
	s.start_engage()
	await t._frames(15)
	check(s.model.aim_pitch != null and s.model.aim_pitch.pitch > 0.05, "soldado inclina o tronco e a arma para cima mirando na passarela", str(s.model.aim_pitch.pitch if s.model.aim_pitch else 0.0))
	
	# 2. Em combate com alvo na passarela, soldado nao avanca para baixo do mezanino (z <= Catwalk.FRONT_Z - 1.0)
	var max_z := -999.0
	for i in 60:
		await t._frames(1)
		max_z = maxf(max_z, s.global_position.z)
	check(max_z <= Catwalk.FRONT_Z - 0.9, "soldado mantem distancia e nao entra debaixo do mezanino (max_z=%.2f <= %.2f)" % [max_z, Catwalk.FRONT_Z - 0.9])
	check(s.global_position.y >= 0.0, "soldado permanece no chão sem cair no vácuo (y=%.2f)" % s.global_position.y)
	check(s.shots_fired > 0, "soldado atira contra a heroina no mezanino", str(s.shots_fired))
	
	# 3. Soldado colocado muito perto do mezanino recua para abrir campo de visao
	s.global_position = Vector3(0, 0, 7.5)
	s._lost_t = 0.0
	await t._frames(35)
	check(s.global_position.z < 7.5, "soldado muito proximo do mezanino recua para abrir o campo de visao (z=%.2f < 7.5)" % s.global_position.z)
	
	# 4. Ao perder de vista alvo no mezanino, soldado recua/manobra em vez de correr para debaixo dele
	s._lost_t = 1.0  # simula perda temporaria de visada
	await t._frames(30)
	check(s.global_position.z <= Catwalk.FRONT_Z - 0.9, "sem visao de alvo elevado, soldado nao corre para debaixo do mezanino", str(s.global_position.z))
	
	# 5. start_hunt e start_investigate limitam o destino fora de debaixo do mezanino
	s.start_hunt(Vector3(0, Catwalk.FLOOR_Y, 12.5))
	check(s._goal.z <= Catwalk.FRONT_Z - 4.5, "start_hunt com alvo no mezanino mira no patio em frente (goal.z=%.2f)" % s._goal.z)
	check(s._goal.y == 0.0, "start_hunt mantém o soldado no chão (goal.y=0)")
	
	s.start_investigate(Vector3(0, Catwalk.FLOOR_Y, 12.5))
	check(s._goal.z <= Catwalk.FRONT_Z - 4.5, "start_investigate com barulho no mezanino mira no patio em frente (goal.z=%.2f)" % s._goal.z)
	
	# 6. Trava física _clamp_to_bounds
	s.global_position = Vector3(0, -2.0, 12.8)
	s._clamp_to_bounds()
	check(s.global_position.y >= 0.0, "_clamp_to_bounds impede y negativo", str(s.global_position.y))
	check(s.global_position.z <= Catwalk.FRONT_Z - 1.0 + 0.01, "_clamp_to_bounds trava z antes do mezanino", str(s.global_position.z))

func test_soldier_idle_head_look() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 20), Vector3(-11.4, 0, -6.6), -PI * 0.5)
	var s: Soldier = pr[1]
	s.route = []
	s._vigil_t = 0.05
	var initial_yaw := s.rotation.y
	var saw_head_turn := false
	var body_stayed_planted := true
	
	for i in 120:
		await t._frames(1)
		if absf(s.head_yaw) > 0.1:
			saw_head_turn = true
		if absf(s.rotation.y - initial_yaw) > 0.001:
			body_stayed_planted = false
	
	check(body_stayed_planted, "guarda parado: corpo não desliza para rotacionar (fica fixo no posto)")
	check(saw_head_turn, "guarda parado: vigia movendo a cabeça suavemente")
	check(s.model.head_look != null and absf(s.model.get_head_yaw()) > 0.05, "modelo 3D recebe rotação da cabeça via HeadLook")


## Guarda de posto (`hold_post`, os da porta do pátio): barulho só o faz parar e olhar para lá, sem sair do lugar; depois
## volta a vigiar o posto. Só quando a vê entra em combate. O guarda comum (sem `hold_post`) vai investigar o mesmo barulho.
func test_post_guard_holds_until_spotted() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, -18), Vector3.ZERO, PI)  # atrás dele e longe: não a vê
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	s.hold_post = true
	var post := s.global_position
	var states := {}
	var moved := 0.0
	var turned := 0.0
	s.hear_noise(Vector3(6, 0, 0), 26.0, 2.2)
	for i in 240:
		await t._frames(1)
		states[s.state] = true
		moved = maxf(moved, Enemy._flat(s.global_position - post).length())
		turned = maxf(turned, absf(angle_difference(s.rotation.y, PI)))
	check(states.has("suspicious") and not states.has("investigate"), "guarda de posto: o barulho só o faz olhar (não vai investigar)", str(states.keys()))
	check(moved < 0.3, "guarda de posto não sai do lugar com o barulho", "%.2f m" % moved)
	check(turned > 0.5, "guarda de posto vira para o lado do barulho", "%.2f rad" % turned)
	for i in 600:
		await t._frames(1)
		if s.state == "idle" and absf(angle_difference(s.rotation.y, PI)) < 0.1:
			break
	check(s.state == "idle" and absf(angle_difference(s.rotation.y, PI)) < 0.1, "depois volta a vigiar para onde vigiava", "%s %.2f" % [s.state, s.rotation.y])
	# viu: sai do posto como qualquer guarda
	p.global_position = Vector3(0, 0, 6)
	p.reset_physics_interpolation()
	for i in 120:
		await t._frames(1)
		if s.in_combat():
			break
	check(s.in_combat() and s.alert_t > 0.0, "guarda de posto que a vê entra em combate", s.state)
	# o guarda comum vai investigar o mesmo barulho
	var pr2 := await _spawn_soldier(Vector3(0, 0, -18), Vector3.ZERO, PI)
	var s2: Soldier = pr2[1]
	s2.hear_noise(Vector3(6, 0, 0), 26.0, 2.2)
	for i in 180:
		await t._frames(1)
		if s2.state == "investigate":
			break
	check(s2.state == "investigate", "guarda comum vai investigar o barulho", s2.state)


func test_stealth_alert_states_and_corpse_detection() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, -19), Vector3(0, 0, 0), PI)  # atrás dele, ainda no chão do mundo de teste (40 m)
	var p: Player = pr[0]
	var sentry: Soldier = pr[1]
	var w: Node3D = pr[2]
	sentry.route = []
	
	var patrol := Soldier.new()
	patrol.position = Vector3(0, 0, 4)
	patrol.rotation.y = 0.0
	patrol.target = p
	w.add_child(patrol)
	await t._frames(3)
	
	check(sentry.alert_level() == 0 and not sentry._marker.visible, "sentinela começa calma (nível 0)")
	
	# Guarda de ronda morre baleado a 4 metros de distância da sentinela
	patrol.die(Vector3.FORWARD, null, false, false)
	await t._frames(3)
	
	# Sentinela ouve a queda do corpo / percebe o companheiro abatido: entra em desconfiado (Amarelo, nível 1, "?")
	check(sentry.state == "suspicious" and sentry.alert_level() == 1, "sentinela desconfia ao ouvir baque/ver o corpo (nível 1 Amarelo)", "%s %d" % [sentry.state, sentry.alert_level()])
	check(sentry._marker.text == "?" and sentry._marker.modulate == UiStyle.ACCENT, "marcador amarelo ? sobre a cabeça")
	
	# Após olhar brevemente, a sentinela inicia busca ativa indo investigar o ponto (Laranja, nível 2, "!")
	for i in 120:
		await t._frames(1)
		if sentry.state == "investigate":
			break
	check(sentry.state == "investigate" and sentry.alert_level() == 2, "sentinela inicia busca ativa investigando o local (nível 2 Laranja)", "%s %d" % [sentry.state, sentry.alert_level()])
	check(sentry._marker.text == "!" and sentry._marker.modulate.g < 0.7, "marcador laranja ! na busca ativa")
	
	# Ao chegar ao corpo e confirmar a morte, dá o alarme e entra em caça (hunt, ainda busca ativa nível 2)
	for i in 300:
		await t._frames(1)
		if sentry.state in ["hunt", "search"]:
			break
	check(sentry.state in ["hunt", "search"] and sentry.alert_level() == 2, "confirma a morte do companheiro e passa a caçar o invasor (nível 2 Laranja)")
	
	# Agora a heroína entra no campo de visão da sentinela
	p.global_position = sentry.global_position + (-sentry.global_basis.z * 5.0)
	for i in 60:
		await t._frames(1)
		if sentry.in_combat():
			break
	check(sentry.in_combat() and sentry.alert_level() == 3, "ao avistar a heroína entra em combate (nível 3 Vermelho)", "%s %d" % [sentry.state, sentry.alert_level()])
	check(sentry._marker.text == "!" and sentry._marker.modulate == UiStyle.DANGER, "marcador vermelho ! em combate (encontrou)")


func test_searching_enemy_spots_on_noise_or_nearby_kill() -> void:
	# 1. Inimigo vasculhando (Laranja / Level 2): tiro faz ir direto para Encontrou (Vermelho / Level 3)
	var pr := await _spawn_soldier(Vector3(0, 0, -20), Vector3(0, 0, 0), PI)
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	var w: Node3D = pr[2]
	s.start_search()
	await t._frames(2)
	check(s.is_searching() and s.alert_level() == 2, "soldado está em busca ativa vasculhando (Laranja)")
	
	# Heroína escondida atrás dispara um tiro: revela a posição
	p.make_noise(26.0, 2.2)
	await t._frames(2)
	check(s.in_combat() and s.alert_level() == 3, "vasculhando + tiro: vai direto para Encontrou (Vermelho)", "%s %d" % [s.state, s.alert_level()])
	check(s._marker.text == "!" and s._marker.modulate == UiStyle.DANGER, "marcador vermelho !")
	
	# 2. Inimigo vasculhando: barulho de passos/corrida revela a posição e encontra
	pr = await _spawn_soldier(Vector3(0, 0, -6), Vector3(0, 0, 0), PI)
	p = pr[0]
	s = pr[1]
	s.start_hunt(Vector3(5, 0, 0))
	await t._frames(2)
	check(s.is_searching() and s.alert_level() == 2, "soldado vasculhando em hunt")
	p.make_noise(10.0, 0.5)
	await t._frames(2)
	check(s.in_combat() and s.alert_level() == 3, "vasculhando + barulho de passos: vai em Encontrou (Vermelho)", "%s %d" % [s.state, s.alert_level()])
	
	# 3. Inimigo vasculhando: morte de companheiro próximo revela a posição e encontra
	pr = await _spawn_soldier(Vector3(0, 0, -20), Vector3(0, 0, 0), PI)
	p = pr[0]
	s = pr[1]
	w = pr[2]
	s.start_search()
	await t._frames(2)
	var victim := Soldier.new()
	victim.position = Vector3(3, 0, 0)
	victim.target = p
	w.add_child(victim)
	await t._frames(2)
	# Morte da vítima a 3 m do guarda que vasculha (mesmo silenciosa/assassinate)
	victim.die(Vector3.FORWARD, null, false, true)
	await t._frames(2)
	check(s.in_combat() and s.alert_level() == 3, "vasculhando + abate próximo: vai em Encontrou (Vermelho)", "%s %d" % [s.state, s.alert_level()])


func test_enemies_separation_and_no_overlap() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = Vector3(0, 0, 10)
	w.add_child(p)
	
	# 1. Dois soldados posicionados colados (sobrepostos a 0.08 m):
	# O sistema de separação de multidão afasta ambos suavemente para distâncias seguras (> 0.85 m)
	var s1 := Soldier.new()
	s1.position = Vector3(0, 0, 0)
	s1.target = p
	w.add_child(s1)
	
	var s2 := Soldier.new()
	s2.position = Vector3(0.08, 0, 0.05)
	s2.target = p
	w.add_child(s2)
	
	await t._frames(30)
	var d_soldiers := s1.global_position.distance_to(s2.global_position)
	check(d_soldiers >= 0.85, "soldados sobrepostos se repelem e não ocupam o mesmo espaço (d=%.2f >= 0.85)" % d_soldiers)
	
	# 2. Ambos entram em combate (engage):
	# Ao se posicionarem e strafarem mirando no alvo, mantêm separação e não entram um dentro do outro
	s1.start_engage()
	s2.start_engage()
	var min_combat_dist := 999.0
	for i in 60:
		await t._frames(1)
		var d := s1.global_position.distance_to(s2.global_position)
		min_combat_dist = minf(min_combat_dist, d)
	check(min_combat_dist >= 0.85, "em combate e strafe, soldados não vazam um dentro do outro (min_d=%.2f >= 0.85)" % min_combat_dist)


func test_soldier_hunts_player_behind_rear_crates() -> void:
	var w: Node3D = await t._fresh_world()
	Level.build(w)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var p := Player.new()
	# Heroína escondida no chão no corredor atrás das caixas decorativas
	p.position = Vector3(-0.5, 0.0, 10.2)
	p.health = 100000
	w.add_child(p)
	
	var s := Soldier.new()
	s.position = Vector3(0.0, 0.0, 2.0)
	s.target = p
	w.add_child(s)
	await t._frames(3)
	
	# 1. Alvo no chão atrás das caixas não deve ser considerado elevado
	check(not s._is_target_elevated(), "heroína no chão atrás das caixas não é considerada elevada")
	
	# 2. start_hunt e start_investigate não devem limitar goal.z a 5.8 quando no chão
	s.start_hunt(p.global_position)
	check(s._goal.z >= 10.0, "start_hunt busca a heroína atrás das caixas sem travar em z=5.8 (goal.z=%.2f)" % s._goal.z)
	
	s.start_investigate(p.global_position)
	check(s._goal.z >= 10.0, "start_investigate investiga atrás das caixas sem travar em z=5.8 (goal.z=%.2f)" % s._goal.z)
	
	# 3. Soldado no chão pode avançar além de z=9.8 para caçar no corredor
	s.global_position = Vector3(-0.5, 0.0, 10.2)
	s._clamp_to_bounds()
	check(s.global_position.z >= 10.0, "_clamp_to_bounds permite soldado no corredor atrás das caixas (z=%.2f)" % s.global_position.z)


