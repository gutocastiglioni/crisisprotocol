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
	await test_sniper_blind_spot_and_catwalk_m79()
	await test_sniper_zoom_scope()
	await test_sniper_stealth_assassination()
	await test_sniper_never_descends_catwalk()
	await test_sniper_catwalk_patrol_and_lateral_look()
	await test_rear_crates_and_ladder_discovery()


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
	check(sniper.laser_mesh != null and sniper.laser_mesh.visible, "mira laser vermelha visível")
	
	# Avançar mira até o disparo
	sniper.aim_progress = Sniper.AIM_LOCK_TIME + 0.01
	var fired_signal := [false]
	sniper.fired.connect(func() -> void: fired_signal[0] = true)
	sniper._aim_lock_process(0.02)
	check(fired_signal[0] or sniper.shots_fired > 0, "sniper efetuou disparo")
	check(sniper.shots_fired == 1, "contador de tiros do sniper incrementado")
	check(sniper.state == "cooldown", "após disparo entra em cooldown de ferrolho")
	check(not sniper.laser_mesh.visible, "laser apaga após disparo")
	
	# Morte com headshot e ragdoll
	sniper.take_headshot(10, Vector3.FORWARD, sniper.global_position + Vector3.UP * 1.5)
	check(sniper.dead, "tiro na cabeça elimina sniper instantaneamente")
	check(sniper.state == "dead", "estado dead")
	check(sniper.model.is_ragdoll(), "sniper cai em ragdoll físico")


func test_sniper_blind_spot_and_catwalk_m79() -> void:
	var w: Node3D = await t._fresh_world()
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var sniper := Sniper.new()
	sniper.position = Vector3(-2.5, Catwalk.FLOOR_Y, 12.2)
	sniper.rotation.y = 0.0
	w.add_child(sniper)
	
	var player := Player.new()
	player.position = Vector3(0, 0, 6.0)
	w.add_child(player)
	sniper.target = player
	await t._frames(3)
	
	# 1. Ponto cego: no início da sala (z = 6.0) o sniper NÃO a enxerga
	check(not sniper._sees_target(), "ponto cego: sniper não enxerga a jogadora no início da sala (z=6)")
	
	# 2. Metade da sala (z = 0): ao avançar para a frente, o sniper a enxerga fácil
	player.global_position = Vector3(0, 0, 0.0)
	await t._frames(2)
	check(sniper._sees_target(), "metade da sala: sniper enxerga a jogadora no centro da sala (z=0)")
	
	# 3. Caixa da M79 no mezanino
	var locker := Chest.new()
	locker.item = "m79"
	locker.lock = "container"
	locker.position = Vector3(0, Catwalk.FLOOR_Y, 12.2)
	w.add_child(locker)
	await t._frames(2)
	check(is_equal_approx(locker.global_position.y, Catwalk.FLOOR_Y), "caixa da M79 posicionada na altura do mezanino (y=%.1f)" % Catwalk.FLOOR_Y)
	check(locker.global_position.z > Catwalk.FRONT_Z, "caixa da M79 posicionada sobre o mezanino (z > 10.8)")


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
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var sniper := Sniper.new()
	sniper.position = Vector3(-2.5, Catwalk.FLOOR_Y, 12.2)
	sniper.rotation.y = 0.0
	w.add_child(sniper)
	
	var player := Player.new()
	player.position = Vector3(-2.5, Catwalk.FLOOR_Y, 13.5)
	player.rotation.y = 0.0
	w.add_child(player)
	sniper.target = player
	await t._frames(3)
	
	# 1. No chão embaixo da passarela: não deve permitir abate furtivo
	player.global_position = Vector3(-2.5, 0.0, 13.5)
	await t._frames(2)
	check(not sniper.can_assassinate(player), "sniper no mezanino não aceita abate furtivo vindo do chão")
	check(player.stealth_target() != sniper, "alvo furtivo não seleciona sniper no mezanino se jogadora estiver no chão")
	
	# 2. Em cima da passarela pelas costas: permite abate furtivo e exibe prompt
	player.global_position = Vector3(-2.5, Catwalk.FLOOR_Y, 13.5)
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
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var sniper := Sniper.new()
	sniper.position = Vector3(-2.5, Catwalk.FLOOR_Y, 12.2)
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
	check(sniper._goal.x >= -3.8 and sniper._goal.x <= 1.0, "start_hunt limita _goal.x dentro da passarela", str(sniper._goal))
	
	# 2. start_investigate com barulho no chão: o _goal é restrito à passarela
	sniper.start_investigate(Vector3(6.0, 0.0, 5.0))
	check(is_equal_approx(sniper._goal.y, Catwalk.FLOOR_Y), "start_investigate mantém _goal.y na passarela (Y=%.1f)" % Catwalk.FLOOR_Y)
	check(sniper._goal.x >= -3.8 and sniper._goal.x <= 1.0, "start_investigate limita _goal.x dentro da passarela", str(sniper._goal))
	
	# 3. Processamento de física em caça/investigação: Sniper nunca cai para o chão
	sniper.start_hunt(Vector3(0, 0, 0))
	for _i in range(30):
		await t.physics_frame
	check(is_equal_approx(sniper.global_position.y, Catwalk.FLOOR_Y), "sniper permanece no piso da passarela durante perseguição", str(sniper.global_position.y))
	check(sniper.global_position.x >= -4.6 and sniper.global_position.x <= 1.2, "sniper.x contido na passarela", str(sniper.global_position.x))
	check(sniper.global_position.z >= Catwalk.FRONT_Z + 0.3 and sniper.global_position.z <= Catwalk.WALL_Z - 0.3, "sniper.z contido na passarela", str(sniper.global_position.z))
	
	# 4. Alarme acionado com inimigo no chão: não faz o sniper descer da passarela
	sniper.on_alarm(player, Vector3(0, 0, 0))
	sniper._alarm_delay = 0.01
	for _i in range(10):
		await t.physics_frame
	check(absf(sniper.global_position.y - Catwalk.FLOOR_Y) < 0.1, "sniper em alerta/alarme nunca desce da passarela", "y=%.4f state=%s" % [sniper.global_position.y, sniper.state])

func test_sniper_catwalk_patrol_and_lateral_look() -> void:
	var w: Node3D = await t._fresh_world()
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	
	var player := Player.new()
	player.position = Vector3(0, 0, 20.0)  # longe, para não alertar o sniper
	w.add_child(player)
	
	var sniper := Sniper.new()
	sniper.position = Vector3(-2.0, Catwalk.FLOOR_Y, 11.7)
	sniper.rotation.y = 0.0
	sniper.target = player
	sniper.route = [Vector3(-3.5, Catwalk.FLOOR_Y, 11.7), Vector3(0.5, Catwalk.FLOOR_Y, 11.7)]
	w.add_child(sniper)
	sniper.rng.seed = 7
	
	var min_x := 99.0
	var max_x := -99.0
	var looked_lateral := false
	var looked_at_wall := false
	
	for i in 650:
		await t._frames(1)
		min_x = minf(min_x, sniper.global_position.x)
		max_x = maxf(max_x, sniper.global_position.x)
		
		# Ao andar ao longo da passarela (+X ou -X), a cabeça deve olhar para o galpão (-Z / lateral)
		if sniper.state == "patrol" and absf(sniper.velocity.x) > 0.1:
			if absf(sniper.head_yaw) > 0.1:
				looked_lateral = true
		
		# O sniper NUNCA deve olhar diretamente para a parede de trás (+Z, rotation.y ~ PI)
		if absf(sniper.rotation.y) > PI * 0.55:
			looked_at_wall = true
	
	check(max_x - min_x > 2.0, "sniper anda ao longo da passarela (delta_x=%.2f > 2.0m)" % (max_x - min_x))
	check(looked_lateral, "sniper olha para a lateral (galpão abaixo) enquanto patrulha")
	check(not looked_at_wall, "sniper nunca fica olhando para a parede atrás dele (+Z)")


func test_rear_crates_and_ladder_discovery() -> void:
	var w: Node3D = await t._fresh_world()
	Level.build(w)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	await t._frames(3)
	
	var space := w.get_world_3d().direct_space_state
	
	# 1. Visão direta para a escada a partir do ponto de spawn da heroína (0, 1.45, 6)
	# Deve ser completamente bloqueada pelas caixas decorativas empilhadas (surface == 'crate')
	var eye := Vector3(0.0, 1.45, 6.0)
	var ladder_target := catwalk.ladder.global_position + Vector3.UP * 1.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, ladder_target, 1))
	check(not hit.is_empty(), 'visão para a escada é interceptada por obstáculo')
	var collider = hit.get('collider')
	check(collider != null and collider.get_meta('surface', '') == 'crate', 'obstáculo que bloqueia a visão da escada é a pilha de caixas')
	
	# 2. Caminhada em linha reta para trás ao nível da jogadora (y = 0.9m)
	# Deve colidir diretamente com as caixas, impedindo saída reta para trás
	var walk_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 0.9, 6.0), Vector3(0, 0.9, 9.5), 1))
	check(not walk_hit.is_empty() and walk_hit.collider.get_meta('surface', '') == 'crate', 'caminhada direta para trás é bloqueada por caixas')
	
	# 3. A frente do labirinto (Level.MAZE, linha 0) fecha o fundo do galpão em toda a largura, sem fresta (fora a do nicho
	# da escada do mezanino, que não se liga ao labirinto)
	var open_front := []
	var x := Level.MAZE_X0 - Level.MAZE_CELL * 0.5 + 0.05
	var niche_x := Level.maze_cell(Level.maze_ladder_cell().x, 0).x
	while x < Level.SIZE * 0.5 - 0.25:  # até a face de dentro da parede da direita
		if absf(x - niche_x) < Level.MAZE_CELL * 0.5 + 0.05:
			x += 0.1
			continue
		for y in [0.3, 0.9, 1.6, 2.4]:
			var front_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, y, 5.6), Vector3(x, y, 9.0), 1))
			if front_hit.is_empty() or front_hit.collider.get_meta('surface', '') != 'crate':
				open_front.append(Vector2(x, y))
		x += 0.1
	check(open_front.is_empty(), 'a frente do labirinto de caixas é fechada (sem fresta fora o nicho da escada)', str(open_front.slice(0, 6)))
	
	# 4. O nicho da escada do mezanino (pela frente) está livre e permite montagem
	var ladder_pos := catwalk.ladder.global_position
	var mount_pos := ladder_pos + catwalk.ladder.ladder_out * 0.45
	var mount_info: Dictionary = catwalk.ladder.can_mount(mount_pos)
	check(mount_info.get('can', false) and not mount_info.get('at_top', true), 'corredor atrás das caixas permite acessar e montar na escada')
