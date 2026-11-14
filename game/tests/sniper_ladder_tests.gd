class_name SniperLadderTests
extends RefCounted
## Testes do Guerrilheiro Sniper, da arma Sniper, da área suspensa (Catwalk) e da escada (Ladder)
## com a ação de subir e descer escadas.

var t: SceneTree


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func run(runner: SceneTree) -> void:
	t = runner
	await test_sniper_weapon_and_assets()
	await test_catwalk_and_ladder_structure()
	await test_ladder_climb_action()
	await test_sniper_enemy_behavior()
	await test_mezz_rifleman()
	await test_sniper_blind_spot_and_catwalk_m79()
	await test_sniper_zoom_scope()
	await test_sniper_stealth_assassination()
	await test_sniper_never_descends_catwalk()
	await test_sniper_catwalk_patrol_and_lateral_look()
	await test_rear_crates_and_ladder_discovery()
	await test_shot_hits_what_camera_sees()
	await test_suspended_ladder_and_climb()


func test_sniper_weapon_and_assets() -> void:
	# 1. Arma Sniper e nós no modelo
	var model := HeroineModel.new()
	var w: Node3D = await t._fresh_world()
	w.add_child(model)
	await t._frames(2)

	check(model._meshes.has("sniper") and model._meshes["sniper"] != null, "nó Sniper no modelo")
	check(model._muzzles.has("sniper") and model._muzzles["sniper"] != null, "marcador SniperMuzzle no modelo")
	check("sniper" in HeroineModel.LONG_GUNS, "sniper incluído em LONG_GUNS")

	# Troca de arma para sniper
	model.set_weapon("sniper")
	check(model.weapon == "sniper", "set_weapon sniper")
	check(model.is_weapon_visible("sniper") and not model.is_weapon_visible("pistol"), "sniper visível na mão")

	# glb independente da arma sniper
	var chest_sniper: Node = (load("res://assets/characters/sniper.glb") as PackedScene).instantiate()
	var mesh_inst: MeshInstance3D = chest_sniper if chest_sniper is MeshInstance3D else chest_sniper.find_children("*", "MeshInstance3D", true, false)[0]
	check(mesh_inst != null and mesh_inst.mesh.surface_get_array_index_len(0) > 0, "sniper.glb exportado com malha")
	chest_sniper.free()

	# Estatísticas de tiro e sobrevivência
	check(Player.WEAPON_STATS.has("sniper"), "Player.WEAPON_STATS possui sniper")
	var stats: Dictionary = Player.WEAPON_STATS["sniper"]
	check(int(stats.damage) >= 70, "sniper: alto dano por disparo (>= 70)", str(stats.damage))
	check(float(stats.range) >= 100.0, "sniper: longo alcance (>= 100m)", str(stats.range))
	check(GameMode.SURVIVAL_WEAPONS.has("sniper"), "GameMode.SURVIVAL_WEAPONS possui sniper")
	check(Sfx.SOUNDS.has("sniper_shot"), "som sniper_shot registrado em Sfx")


func test_catwalk_and_ladder_structure() -> void:
	var w: Node3D = await t._fresh_world()
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	await t._frames(2)

	check(catwalk.floor_body != null, "passarela possui corpo de colisão do piso")
	check(catwalk.ladder != null, "passarela possui escada (ladder) acoplada")
	check(is_equal_approx(catwalk.ladder.height, Catwalk.FLOOR_Y), "altura da escada corresponde ao piso da passarela")

	# Detecção da escada
	var ladder: Ladder = catwalk.ladder
	var ground_mount: Dictionary = ladder.can_mount(ladder.global_position + ladder.ladder_out * 0.4)
	check(ground_mount.get("can", false) and not ground_mount.get("at_top", true), "escada detecta montagem pela base")

	var top_mount: Dictionary = ladder.can_mount(ladder.top_pos + ladder.ladder_fwd * 0.2)
	check(top_mount.get("can", false) and top_mount.get("at_top", false), "escada detecta montagem pelo topo")


func test_ladder_climb_action() -> void:
	var w: Node3D = await t._fresh_world()
	var catwalk := Catwalk.new()
	w.add_child(catwalk)

	var player := Player.new()
	player.position = catwalk.ladder.global_position + catwalk.ladder.ladder_out * 0.4
	w.add_child(player)
	await t._frames(2)

	var moves: PlayerMoves = player.moves
	var ladder: Ladder = catwalk.ladder

	# 1. Montar na escada pela base
	moves.start_ladder(ladder, false)
	check(moves.mode == "ladder", "modo ladder ativado")
	check(player.model.holstered, "arma guardada ao subir na escada")
	check(player.model.state == "ladder_idle", "estado inicial ladder_idle", player.model.state)

	# 2. Subir na escada (simulando input para a frente / cima)
	moves._ladder_y = 1.0
	moves._fwd = ladder.ladder_fwd
	Input.action_press("move_forward")
	moves.update(0.1)
	Input.action_release("move_forward")
	check(player.model.state == "ladder_up", "animação de subir escada (ladder_up)", player.model.state)
	check(moves._ladder_y > 1.0, "subiu verticalmente na escada")

	# 3. Descer na escada (simulando input para trás / baixo)
	Input.action_press("move_back")
	moves.update(0.1)
	Input.action_release("move_back")
	check(player.model.state == "ladder_down", "animação de descer escada (ladder_down)", player.model.state)

	# 4. Chegar ao alto da escada: sai pela beira do mezanino (LadderOutLow, sem rebordo) até de pé no piso
	moves._ladder_y = ladder.height
	Input.action_press("move_forward")
	moves.update(0.05)
	Input.action_release("move_forward")
	check(moves.mode == "ladder_out" and player.model.state == "ladder_out_low", "no alto: sai pela beira do mezanino", "%s %s" % [moves.mode, player.model.state])
	for i in 40:
		if moves.mode == "":
			break
		moves.update(0.1)
	check(moves.mode == "", "desmontou da escada ao atingir o topo")
	check(not player.model.holstered, "arma desarma do coldre após sair da escada")
	check(absf(player.global_position.y - (ladder.global_position.y + ladder.height)) < 0.1, "jogadora está em cima do mezanino")

	# 5. Descer do topo e soltar (drop)
	moves.start_ladder(ladder, true)
	check(moves.mode == "ladder", "montou na escada pelo topo")
	Input.action_press("jump")
	moves.update(0.05)
	Input.action_release("jump")
	check(moves.mode == "", "pulo solta da escada (drop)")
	check(player.model.state == "fall", "ao soltar entra em queda")


func test_sniper_enemy_behavior() -> void:
	var w: Node3D = await t._fresh_world()
	var player := Player.new()
	player.position = Vector3(0, 0, 0)
	w.add_child(player)

	var sniper := Sniper.new()
	sniper.position = Vector3(0, 2.4, 8.0)
	sniper.target = player
	w.add_child(sniper)
	sniper.rng.seed = 42
	await t._frames(5)

	check(sniper.model.weapon == "sniper", "sniper armado com o fuzil de precisão")
	check(sniper.sight_range >= 7.0 and Sniper.FIRE_RANGE >= 25.0, "visão e alcance de tiro do sniper")

	# Iniciar trava de mira (aim lock) com laser vermelho
	sniper.start_aim_lock()
	check(sniper.state == "aim_lock", "estado aim_lock do sniper")
	await t._frames(2)  # o laser é desenhado a cada passo da mira (ponto vindo até ela), não no start_aim_lock
	check(sniper.laser != null and sniper.laser.visible, "mira laser vermelha visível")

	# Avançar mira até o disparo
	sniper.aim_progress = Sniper.AIM_LOCK_TIME + 0.01
	var fired_signal := [false]
	sniper.fired.connect(func() -> void: fired_signal[0] = true)
	sniper._aim_lock_process(0.02)
	check(fired_signal[0] or sniper.shots_fired > 0, "sniper efetuou disparo")
	check(sniper.shots_fired == 1, "contador de tiros do sniper incrementado")
	check(sniper.state == "cooldown", "após disparo entra em cooldown de ferrolho")
	check(not sniper.laser.visible, "laser apaga após disparo")

	# Morte com headshot e ragdoll
	sniper.take_headshot(10, Vector3.FORWARD, sniper.global_position + Vector3.UP * 1.5)
	check(sniper.dead, "tiro na cabeça elimina sniper instantaneamente")
	check(sniper.state == "dead", "estado dead")
	check(sniper.model.is_ragdoll(), "sniper cai em ragdoll físico")


## Guarda do mezanino de M16 (`Sniper.weapon` "m16"): sem laser; mira RIFLE_AIM s e solta uma rajada de vários tiros de
## longe (dentro de FIRE_RANGE), depois descansa; o sensor de perigo sobe na mira; morto, larga o M16 com meio pente.
func test_mezz_rifleman() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var player := Player.new()
	player.position = Vector3(-9.8, 0, 51.3)
	player.health = 100000
	w.add_child(player)
	var sn := Sniper.new()
	sn.weapon = "m16"
	sn.position = Vector3(-9.8, Catwalk.FLOOR_Y, 64.0)  # de longe (12,7 m)
	sn.target = player
	w.add_child(sn)
	sn.rng.seed = 3
	await t._frames(5)
	check(sn.rifleman() and sn.model.weapon == "m16" and sn.laser == null, "guarda do mezanino: M16 na mão, sem laser")
	sn.spot()
	var t0 := sn.threat()
	var shots := [0]
	var first := -1.0
	var burst_max := 0
	for i in 60 * 4:
		await t.physics_frame
		if sn.shots_fired > 0 and first < 0.0:
			first = i / 60.0
		if sn.state == "burst":
			burst_max = maxi(burst_max, sn.shots_fired)
	shots[0] = sn.shots_fired
	check(first >= Sniper.RIFLE_AIM and first < Sniper.RIFLE_AIM + 0.6, "mira um instante antes da primeira rajada", "%.2f s" % first)
	check(burst_max >= Sniper.RIFLE_BURST[0], "rajada de vários tiros de longe", str(burst_max))
	check(shots[0] > burst_max, "descansa e solta outra rajada", str(shots[0]))
	check(player.health < 100000, "a rajada de longe acerta", str(100000 - player.health))
	check(t0 < 0.5, "sensor de perigo baixo antes de ele mirar", "%.2f" % t0)
	sn.take_hit(999, Vector3.FORWARD, sn.global_position + Vector3.UP)
	await t._frames(10)
	var drop: Pickup = null
	for d in w.find_children("*", "Pickup", true, false):
		if d.is_drop and d.is_weapon and d.kind == "m16":
			drop = d
	check(sn.dead and drop != null and drop.amount == 15, "morto, larga o M16 com meio pente")


func test_sniper_blind_spot_and_catwalk_m79() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)

	var sniper := Sniper.new()
	sniper.position = Vector3(-9.8, Catwalk.FLOOR_Y, 64.0)
	sniper.rotation.y = 0.0
	w.add_child(sniper)

	var player := Player.new()
	player.position = Vector3(-9.8, 0, 58.0)
	w.add_child(player)
	sniper.target = player
	await t._frames(3)

	# 1. Ponto cego: logo na frente do mezanino (6 m) o sniper NÃO a enxerga
	check(not sniper._sees_target(), "ponto cego: sniper não enxerga a jogadora logo na frente do mezanino")

	# 2. Mais longe (12 m): ao avançar para a frente, o sniper a enxerga fácil
	player.global_position = Vector3(-9.8, 0, 52.0)
	await t._frames(2)
	check(sniper._sees_target(), "mais longe: sniper enxerga a jogadora")

	# 3. O container da M79 saiu do mezanino (que não tem subida): fica no chão do pátio da mata
	check(Yard.LOCKER.y == 0.0 and Yard.LOCKER.x < Yard.X_NEAR and not Catwalk.covers(Yard.LOCKER), "container da M79 no chão do pátio da mata")


func test_sniper_zoom_scope() -> void:
	var w: Node3D = await t._fresh_world()
	var player := Player.new()
	w.add_child(player)
	await t._frames(2)

	# 1. Arma Sniper equipada e mira
	player.give_weapon("sniper")
	check(player.weapon() == "sniper", "sniper equipada")
	check(not player.is_sniper_zoomed(), "mira telescópica inativa sem mirar")

	# Mira ativada
	player.aiming = true
	check(player.is_sniper_zoomed(), "mira telescópica Sniper ativa ao mirar")
	check(is_equal_approx(player.sniper_zoom(), 2.0), "zoom inicial é 2.0x", str(player.sniper_zoom()))
	check(player.sniper_zoom_label() == "2.0x", "label inicial 2.0x")

	# 2. X aumenta o zoom
	check(player.zoom_in(), "zoom_in aumentou para 4x")
	check(is_equal_approx(player.sniper_zoom(), 4.0), "zoom agora é 4.0x", str(player.sniper_zoom()))
	check(player.sniper_zoom_label() == "4.0x", "label 4.0x")

	check(player.zoom_in(), "zoom_in aumentou para 8x")
	check(is_equal_approx(player.sniper_zoom(), 8.0), "zoom agora é 8.0x", str(player.sniper_zoom()))

	check(player.zoom_in(), "zoom_in aumentou para 16x")
	check(is_equal_approx(player.sniper_zoom(), 16.0), "zoom agora é 16.0x", str(player.sniper_zoom()))

	# Limite máximo de zoom
	check(not player.zoom_in(), "zoom_in no limite máximo retorna false")
	check(is_equal_approx(player.sniper_zoom(), 16.0), "mantém 16.0x no teto")

	# 3. O diminui o zoom
	check(player.zoom_out(), "zoom_out diminuiu para 8x")
	check(is_equal_approx(player.sniper_zoom(), 8.0), "zoom agora é 8.0x")

	check(player.zoom_out(), "zoom_out diminuiu para 4x")
	check(is_equal_approx(player.sniper_zoom(), 4.0), "zoom agora é 4.0x")

	check(player.zoom_out(), "zoom_out diminuiu para 2x")
	check(is_equal_approx(player.sniper_zoom(), 2.0), "zoom agora é 2.0x")

	# Limite mínimo de zoom
	check(not player.zoom_out(), "zoom_out no limite mínimo retorna false")
	check(is_equal_approx(player.sniper_zoom(), 2.0), "mantém 2.0x no piso")

	# 4. Câmera e visibilidade do modelo em zoom
	player.camera_rig._process(0.016)
	check(player.camera_rig.camera.fov < 55.0, "câmera estreitou FOV para zoom", str(player.camera_rig.camera.fov))
	check(not player.model.visible, "modelo oculto durante mira com sniper para desobstruir visão")

	# Soltar mira restaura modelo
	player.aiming = false
	check(not player.is_sniper_zoomed(), "mira telescópica desativa ao soltar mira")
	player.camera_rig._process(0.016)
	check(player.model.visible, "modelo volta a ficar visível ao soltar mira")

	# 5. Overlay SniperScope
	var scope := SniperScope.new()
	w.add_child(scope)
	await t._frames(1)
	scope.update_scope(true, player.sniper_zoom_label(), 45.0)
	check(scope._root.visible, "SniperScope visível quando ativa")
	check(scope._label_zoom.text.contains("2.0x"), "SniperScope exibe zoom 2.0x")
	check(scope._label_range.text.contains("45.0"), "SniperScope exibe distância")
	scope.update_scope(false, "", 0.0)
	check(not scope._root.visible, "SniperScope oculta quando inativa")
	scope.queue_free()


func test_sniper_stealth_assassination() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)

	var sniper := Sniper.new()
	sniper.position = Vector3(-9.8, Catwalk.FLOOR_Y, 64.0)
	sniper.rotation.y = 0.0
	w.add_child(sniper)

	var player := Player.new()
	player.position = Vector3(-9.8, Catwalk.FLOOR_Y, 65.3)
	player.rotation.y = 0.0
	w.add_child(player)
	sniper.target = player
	await t._frames(3)

	# 1. No chão embaixo da passarela: não deve permitir abate furtivo
	player.global_position = Vector3(-9.8, 0.0, 65.3)
	await t._frames(2)
	check(not sniper.can_assassinate(player), "sniper no mezanino não aceita abate furtivo vindo do chão")
	check(player.stealth_target() != sniper, "alvo furtivo não seleciona sniper no mezanino se jogadora estiver no chão")

	# 2. Em cima da passarela pelas costas: permite abate furtivo e exibe prompt
	player.global_position = Vector3(-9.8, Catwalk.FLOOR_Y, 65.3)
	await t._frames(2)
	check(sniper.can_assassinate(player), "sniper pelas costas aceita abate furtivo")
	check(player.stealth_target() == sniper, "player.stealth_target() seleciona sniper")
	check(player.stealth_prompt() == PlayerStealth.ASSASSINATE_PROMPT, "prompt de abate furtivo ativo para sniper")

	# 3. Execução do abate furtivo
	var killed := [false]
	sniper.killed.connect(func() -> void: killed[0] = true)
	player.fire()
	check(player.moves.mode == "assassinate", "atirar sem mirar inicia assassinate no sniper")
	check(sniper._stealth_locked, "sniper fica travado durante a execução do abate")

	var total_frames := int(float(Moves.data().assassinate.frames) / Moves.fps() * 60.0) + 6
	await t._frames(total_frames)
	check(sniper.dead and sniper.health == 0 and sniper.state == "dead" and killed[0], "sniper morre com abate furtivo")
	check(sniper.model.is_ragdoll() and sniper.collision_layer == 0, "sniper vira ragdoll sem colisão")


func test_sniper_never_descends_catwalk() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)

	var sniper := Sniper.new()
	sniper.position = Vector3(-9.8, Catwalk.FLOOR_Y, 64.0)
	sniper.rotation.y = 0.0
	w.add_child(sniper)

	var player := Player.new()
	player.position = Vector3(0, 0, -8.0)
	w.add_child(player)
	sniper.target = player
	await t._frames(2)

	# 1. start_hunt com alvo no chão: o _goal é restrito à passarela (Y = Catwalk.FLOOR_Y)
	sniper.start_hunt(Vector3(-5.0, 0.0, -10.0))
	check(is_equal_approx(sniper._goal.y, Catwalk.FLOOR_Y), "start_hunt mantém _goal.y na passarela (Y=%.1f)" % Catwalk.FLOOR_Y)
	check(sniper._goal.x >= Catwalk.X0 + 0.5 - 0.01 and sniper._goal.x <= Catwalk.X1 - 0.5 + 0.01, "start_hunt limita _goal.x dentro da passarela", str(sniper._goal))

	# 2. start_investigate com barulho no chão: o _goal é restrito à passarela
	sniper.start_investigate(Vector3(6.0, 0.0, 5.0))
	check(is_equal_approx(sniper._goal.y, Catwalk.FLOOR_Y), "start_investigate mantém _goal.y na passarela (Y=%.1f)" % Catwalk.FLOOR_Y)
	check(sniper._goal.x >= Catwalk.X0 + 0.5 - 0.01 and sniper._goal.x <= Catwalk.X1 - 0.5 + 0.01, "start_investigate limita _goal.x dentro da passarela", str(sniper._goal))

	# 3. Processamento de física em caça/investigação: Sniper nunca cai para o chão
	sniper.start_hunt(Vector3(0, 0, 0))
	for _i in range(30):
		await t.physics_frame
	check(is_equal_approx(sniper.global_position.y, Catwalk.FLOOR_Y), "sniper permanece no piso da passarela durante perseguição", str(sniper.global_position.y))
	check(sniper.global_position.x >= Catwalk.X0 + 0.3 - 0.01 and sniper.global_position.x <= Catwalk.X1 - 0.3 + 0.01, "sniper.x contido na passarela", str(sniper.global_position.x))
	check(sniper.global_position.z >= Catwalk.FRONT_Z + 0.3 and sniper.global_position.z <= Catwalk.WALL_Z - 0.3, "sniper.z contido na passarela", str(sniper.global_position.z))

	# 4. Alarme acionado com inimigo no chão: não faz o sniper descer da passarela
	sniper.on_alarm(player, Vector3(0, 0, 0))
	sniper._alarm_delay = 0.01
	for _i in range(10):
		await t.physics_frame
	check(absf(sniper.global_position.y - Catwalk.FLOOR_Y) < 0.1, "sniper em alerta/alarme nunca desce da passarela", "y=%.4f state=%s" % [sniper.global_position.y, sniper.state])

func test_sniper_catwalk_patrol_and_lateral_look() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)

	var player := Player.new()
	player.position = Vector3(0, 0, 20.0)  # longe, para não alertar o sniper
	w.add_child(player)

	var sniper := Sniper.new()
	sniper.position = Catwalk.ROUTE[0]
	sniper.rotation.y = 0.0
	sniper.target = player
	sniper.route.assign(Catwalk.ROUTE)
	w.add_child(sniper)
	sniper.rng.seed = 7

	var min_x := 99.0
	var max_x := -99.0
	var looked_lateral := false
	var looked_at_wall := false
	var looked_down := false
	var wall_frames := 0

	for i in 900:
		await t._frames(1)
		min_x = minf(min_x, sniper.global_position.x)
		max_x = maxf(max_x, sniper.global_position.x)

		# Ao andar ao longo das beiras (+X ou -X), a cabeça deve olhar para o galpão (-Z / lateral), nunca para a parede
		if sniper.state == "patrol" and absf(sniper.velocity.x) > 0.1 and absf(sniper.velocity.x) > 2.0 * absf(sniper.velocity.z) and absf(sniper.head_yaw) > 0.3:
			var look := sniper.rotation.y + sniper.head_yaw
			if -cos(look) < -0.2:
				looked_lateral = true
			else:
				wall_frames += 1  # (virando a quina a cabeça ainda vem da perna de antes: só uns quadros)
		looked_down = looked_down or (sniper.state == "patrol" and sniper.head_pitch <= Sniper.DOWN_AT)

		# parado (vigiando), ele não fica de frente para a parede de trás (+Z, rotation.y ~ PI): só o tempo de virar
		if sniper.state in ["look", "idle"] and absf(angle_difference(sniper.rotation.y, 0.0)) > PI * 0.55:
			wall_frames += 1
	looked_at_wall = looked_at_wall or wall_frames > 90

	check(max_x - min_x > 2.0, "sniper anda ao longo do mezanino (delta_x=%.2f > 2.0m)" % (max_x - min_x))
	check(looked_lateral, "sniper olha para a lateral (galpão abaixo) enquanto patrulha")
	check(not looked_at_wall, "sniper nunca fica olhando para a parede atrás dele (+Z)")
	check(looked_down, "na ronda o sniper também olha para baixo (as caixas do labirinto)")


func test_rear_crates_and_ladder_discovery() -> void:
	var w: Node3D = await t._fresh_world()
	Level.build(w)
	var catwalk := Catwalk.new()
	catwalk.suspended = true
	w.add_child(catwalk)
	await t._frames(3)

	var space := w.get_world_3d().direct_space_state

	# 1. Do corredor do escritório não se vê o mezanino: a parede da frente do labirinto fecha (só o portão de grade deixa
	# espiar o corredor do labirinto logo atrás dele)
	var eye := Vector3(-8.0, 1.45, Shed.OFFICE_Z1 - 2.0)
	var ladder_target := catwalk.ladder.global_position + Vector3.UP * 2.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, ladder_target, 1))
	check(not hit.is_empty(), 'do escritório a visão do mezanino é interceptada')

	# 2. A parede da frente do labirinto fecha de lado a lado, sem fresta (fora o portão de grade, que segura o corpo)
	var open_front := []
	var x := Level.WEST + 0.25
	while x < Level.EAST - 0.25:
		if absf(x - Shed.MID_GATE.x) < Shed.GATE_W * 0.5 + 0.2:
			x += 0.1
			continue
		for y in [0.3, 0.9, 1.6, 2.4, 5.0]:
			var front_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y, Level.MAZE_FRONT - 1.0), Vector3(x, y, Level.MAZE_FRONT + 1.0), 1))
			if front_hit.is_empty():
				open_front.append(Vector2(x, y))
		x += 0.1
	check(open_front.is_empty(), 'a frente do labirinto é fechada (sem fresta fora o portão de grade)', str(open_front.slice(0, 6)))

	# 3. A escada do mezanino fica recolhida e trancada, em cima do corredor da parede oeste
	var lad := Level.maze_ladder_cell()
	check(catwalk.ladder.locked and Level.MAZE[lad.y][lad.x] == ".", 'escada do mezanino recolhida, em cima de um corredor')


## A câmera (acima e atrás do cano) vê o sniper do mezanino por cima das pilhas do labirinto: o tiro acerta o que a
## retícula mostra (antes o raio saía do cano e batia na quina da pilha); de dentro do labirinto a câmera sobe até ele.
func test_shot_hits_what_camera_sees() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	GameMode.set_mode(GameMode.SURVIVAL)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var s: Sniper = main.sniper
	for e: Node in t.get_nodes_in_group("enemies"):
		if e != s:
			e.process_mode = Node.PROCESS_MODE_DISABLED
	s.set_physics_process(false)  # parado no lugar, com corpo (PROCESS_MODE_DISABLED tiraria a cápsula da física)
	p.health = 100000
	Input.action_press("aim")
	# [onde ela está, onde ele está, parte]: de dentro do labirinto, ele fica acima dos 31,5° que a câmera subia. (O caso
	# do chão em z = 3, rente à quina de uma pilha do labirinto, saiu: ali agora passa a grade do painel, Shed, e da
	# frente dela a pilha tapa mesmo a linha do tiro.)
	var cases := [[Level.maze_cell(8, 2) + Vector3(0, 0.05, 0), Vector3(Catwalk.X1 - 0.6, Catwalk.FLOOR_Y, Catwalk.FRONT_Z + 1.2), "Chest"]]
	for c in cases:
		s.global_position = c[1]
		s.health = Sniper.MAX_HEALTH
		p.global_position = c[0]
		p.velocity = Vector3.ZERO
		await t._frames(30)
		var pt: Vector3 = s.model.ragdoll.bodies[c[2]].global_position
		for k in 30:
			p.camera_rig.look_at_point(pt)
			await t._frames(1)
		var ray := p.camera_rig.aim_ray()
		var off := rad_to_deg((pt - ray[0]).normalized().angle_to(ray[1]))
		var info := p.aim_target_info()
		check(off < 1.0 and info.target == s and not info.blocked, "mira no sniper do mezanino de %s: retícula nele, sem bloqueio" % [c[0]],
			"desvio %.1f° alvo %s bloqueado %s" % [off, info.target, info.blocked])
		p._shot_cd = 0.0
		p._bloom = 0.0
		p.fire()
		await t._frames(2)
		check(s.health < Sniper.MAX_HEALTH, "o tiro acerta o que a retícula mostra (sniper de %s)" % [c[0]], str(s.health))
	Input.action_release("aim")
	main.queue_free()
	await t._frames(2)
	GameMode.set_mode(GameMode.ARCADE)


## Na fase a escada do mezanino fica recolhida e trancada: não monta (nem de baixo nem de cima) e E embaixo dela avisa. O
## mezanino não tem subida (sem a caixa de escalar): da beira só se pendura quem já está em cima.
func test_suspended_ladder_and_climb() -> void:
	var w: Node3D = await t._fresh_world()
	Level.block(w, Vector3(30, 0.4, 30), Vector3(-6, -0.2, 58), "concrete")  # chão perto do mezanino (o do mundo de teste fica na origem)
	var catwalk := Catwalk.new()
	catwalk.suspended = true
	w.add_child(catwalk)
	var player: Player = t._spawn_player(w, Vector3(Catwalk.LADDER_X, 0.0, Catwalk.FRONT_Z - 0.6))
	player.rotation.y = PI  # de frente para o mezanino (+Z)
	player.camera_rig.yaw = PI
	await t._frames(10)
	var ladder: Ladder = catwalk.ladder
	check(ladder.locked and not ladder.can_mount(ladder.bottom_pos + ladder.ladder_out * 0.45).get("can", false),
		"escada do mezanino recolhida: não monta")
	check(ladder.can_mount(ladder.top_stand).is_empty() or not ladder.can_mount(ladder.top_stand).get("can", false),
		"escada recolhida: nem de cima")
	var said := []
	player.ladder_locked.connect(func(l: Ladder) -> void: said.append(l))
	check(player.pick_locked_ladder() == ladder, "embaixo da escada: aviso de escada trancada")
	Input.action_release("interact")
	await t._frames(2)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(2)
	check(said.size() == 1 and said[0] == ladder and not player.moves.busy(), "E embaixo da escada recolhida: avisa, não sobe", str(said))
	check(Catwalk.LOCKED_TEXT.begins_with("Está trancada."), "texto do aviso", Catwalk.LOCKED_TEXT)
	# do chão a beira do mezanino (3 m) fica fora do alcance: pulando, ela não se agarra
	Input.action_press("jump")
	await t._frames(2)
	Input.action_release("jump")
	await t._frames(60)
	check(not player.moves.hanging() and player.global_position.y < 0.5, "do chão não se agarra na beira do mezanino", "%s %s" % [player.moves.mode, player.global_position])
