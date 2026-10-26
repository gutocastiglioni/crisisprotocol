extends RefCounted
## Testes do HUD: sensor de perigo (Enemy.threat de cada inimigo + DangerMeter), radar com os inimigos já avistados
## (Radar), modelo da arma com a munição (WeaponIcon), barra de vida e o lugar de cada coisa na tela.
## Chamado por run_tests.gd (usa check/_frames de lá).

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_enemy_threat()
	await test_danger_meter()
	await test_hud_in_game()
	await test_hud_visibility_states()
	await test_hud_scaling()
	await test_mode_switch_hud()
	await test_all_weapons()
	await test_radar_all_enemies()
	await test_threat_special_cases()


## Soldado parado (sem processar: não atira) na frente dela, a `dist` m, já em combate.
func _soldier_at(w: Node3D, p: Player, dist: float) -> Soldier:
	var s := Soldier.new()
	s.position = p.position + Vector3(0, 0, -dist)
	s.rotation.y = PI  # de frente para ela
	s.target = p
	w.add_child(s)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	s.start_engage()
	return s


func test_enemy_threat() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	w.add_child(p)
	var s := Soldier.new()
	s.position = Vector3(0, 0, -8)
	s.rotation.y = PI
	s.target = p
	w.add_child(s)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(2)
	t.check(s.threat() == 0.0, "perigo: soldado calmo (fora de combate) não ameaça")
	s.start_engage()
	var near := s.threat()
	t.check(near > 0.5, "perigo: soldado a 8 m atirando = muito provável levar tiro", str(near))
	p.crouching = true
	var low := s.threat()
	p.crouching = false
	t.check(low < near, "perigo: agachada, menos", "%.2f %.2f" % [low, near])
	p.rolling = true
	t.check(s.threat() == 0.0, "perigo: rolando nada acerta (0)")
	p.rolling = false
	s._lost_t = 1.0
	t.check(s.threat() < 0.1, "perigo: sem vê-la, a supressão quase não ameaça", str(s.threat()))
	s._lost_t = 0.0
	p.global_position = Vector3(0, 0, Soldier.FIRE_RANGE)
	t.check(s.threat() == 0.0, "perigo: fora do alcance do tiro, nada", str(s.threat()))
	p.global_position = Vector3.ZERO
	var far_s := _soldier_at(w, p, 18.0)
	t.check(far_s.threat() < near, "perigo: de longe, menos", "%.2f %.2f" % [far_s.threat(), near])
	# sniper: sobe com a mira do laser até o disparo
	var sn := Sniper.new()
	sn.position = Vector3(6, 0, -6)
	sn.target = p
	w.add_child(sn)
	sn.process_mode = Node.PROCESS_MODE_DISABLED
	sn.state = "aim_lock"
	sn.aim_progress = 0.0
	var start := sn.threat()
	sn.aim_progress = Sniper.AIM_LOCK_TIME
	t.check(start < 0.5 and sn.threat() > 0.95, "perigo: sniper sobe junto com a mira do laser", "%.2f %.2f" % [start, sn.threat()])
	# raptor: golpe ao alcance = certo; rondando longe, pouco
	var r := Raptor.new()
	r.position = Vector3(-2, 0, 0)
	r.target = p
	w.add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	r.state = "bite"
	t.check(r.threat() == 1.0, "perigo: mordida do raptor ao alcance = certo", str(r.threat()))
	r.global_position = Vector3(-14, 0, 0)
	r.state = "study"
	t.check(r.threat() < 0.3, "perigo: raptor rondando longe, pouco", str(r.threat()))
	r.state = "charge"
	t.check(r.threat() > 0.8, "perigo: investida do raptor vem de longe", str(r.threat()))
	r.dead = true
	t.check(r.threat() == 0.0, "perigo: morto não ameaça")


func test_danger_meter() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	w.add_child(p)
	var meter := DangerMeter.new()
	meter.player = p
	w.add_child(meter)
	await t._frames(2)
	meter.update(0.1)
	t.check(meter.value == 0.0 and not meter.blink, "sensor: sem inimigo em combate, vazio")
	var a := _soldier_at(w, p, 9.0)
	var one := DangerMeter.sample(t)
	t.check(is_equal_approx(one, a.threat()), "sensor: um inimigo = a chance dele", "%.2f %.2f" % [one, a.threat()])
	_soldier_at(w, p, 11.0)
	var two := DangerMeter.sample(t)
	t.check(two > one, "sensor: dois atirando, mais provável que um", "%.2f %.2f" % [two, one])
	meter.update(0.1)
	t.check(meter.value > 0.0 and meter.value < two, "sensor: sobe aos poucos (não pula)", str(meter.value))
	for i in 10:
		meter.update(0.1)
	t.check(is_equal_approx(meter.value, meter.raw) and meter.blink and meter.tail == "!!", "sensor: chegou e pisca o aviso", "%.2f %.2f" % [meter.value, meter.raw])
	# rolando cai depressa; parada atrás de nada (sem esquivar, só fora de alcance) cai devagar
	var full := meter.value
	p.rolling = true
	meter.update(0.1)
	var dodge_drop := full - meter.value
	t.check(meter.raw == 0.0 and dodge_drop >= DangerMeter.DODGE_FALL * 0.1 - 0.001, "sensor: rolando a barra desce depressa", str(dodge_drop))
	p.rolling = false
	meter.update(0.1)
	t.check(meter.value > full - dodge_drop, "sensor: terminou a esquiva ainda na mira, volta a subir", str(meter.value))
	for i in 10:
		meter.update(0.1)
	p.global_position = Vector3(0, 0, 40.0)  # fora do alcance dos dois
	var before := meter.value
	meter.update(0.1)
	t.check(is_equal_approx(before - meter.value, DangerMeter.FALL * 0.1), "sensor: fora de perigo sem esquivar, desce devagar", str(before - meter.value))
	meter.reset()
	t.check(meter.value == 0.0 and not meter.blink, "sensor: reset zera")


func test_hud_in_game() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var radar: Radar = main.radar
	for sd: Soldier in main.soldiers:
		sd.process_mode = Node.PROCESS_MODE_DISABLED  # parados: não a veem nem atiram
	main.sniper.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(10)
	t.check(radar.seen.is_empty(), "radar: no telhado ela ainda não viu ninguém", str(radar.seen.size()))
	# no galpão, olhando para os guardas da porta do pátio
	p.global_position = Vector3(1.0, 0, -6.0)
	p.rotation.y = PI * 0.5
	p.camera_rig.yaw = p.rotation.y
	p.reset_physics_interpolation()
	await t._frames(20)
	var door_guard: Soldier = main.soldiers[3]  # sentinela da porta do pátio, à frente dela
	var behind: Soldier = main.soldiers[2]  # sentinela do baú da M16, às costas dela
	t.check(radar.is_tracked(door_guard), "radar: guarda à vista aparece", str(radar.seen.size()))
	t.check(not radar.is_tracked(behind), "radar: guarda às costas (nunca visto) não aparece")
	for r: Raptor in main.yard_raptors:
		t.check(not radar.is_tracked(r), "radar: raptor escondido na mata (outra sala) não aparece")
	# virou de costas: o que já viu continua no radar
	p.camera_rig.yaw = p.rotation.y + PI
	await t._frames(10)
	t.check(radar.is_tracked(door_guard), "radar: avistado uma vez, segue rastreado fora da vista")
	door_guard.process_mode = Node.PROCESS_MODE_INHERIT  # o ragdoll precisa do espaço da física
	door_guard.die(Vector3.BACK, door_guard.global_position + Vector3.UP)
	await t._frames(2)
	t.check(not radar.is_tracked(door_guard), "radar: morto sai do radar")
	# lugar de cada coisa: radar no alto à direita, arma embaixo à direita, ajuda sem passar por baixo do radar
	main._process(0.016)
	var area: Vector2 = main.get_viewport().get_visible_rect().size / main._hud.scale
	var r_rect := Rect2(radar.position, radar.size)
	t.check(Rect2(Vector2.ZERO, area).encloses(r_rect) and r_rect.position.x > area.x * 0.5 and r_rect.position.y < area.y * 0.2, "HUD: radar no alto à direita, inteiro na tela", str(r_rect))
	var icon: WeaponIcon = main._weapon_icon
	var i_rect := Rect2(icon.position, icon.size)
	t.check(Rect2(Vector2.ZERO, area).encloses(i_rect) and i_rect.position.x > area.x * 0.5 and i_rect.end.y > area.y * 0.8, "HUD: arma embaixo à direita, inteira na tela", str(i_rect))
	main._hud_help.visible = true
	var help: Label = main._hud_help
	t.check(help.position.x + help.size.x <= radar.position.x, "HUD: ajuda quebra antes do radar", "%s %s" % [help.size, radar.position])
	t.check(Rect2(main.danger.position, main.danger.size).end.y <= help.position.y and main._hud_health.position.y < main.danger.position.y, "HUD: vida, perigo e ajuda um embaixo do outro")
	# arma: o modelo da arma na mão, a pistola com silenciador tem o seu
	t.check(icon.kind == "pistol" and icon.texture != null, "HUD: modelo da pistola", icon.kind)
	t.check(main._hud_weapon.text == "", "HUD: arcade (munição infinita) sem número de munição", main._hud_weapon.text)
	p.model.set_weapon("m16")
	main._process(0.016)
	t.check(icon.kind == "m16", "HUD: trocou para o M16, o modelo troca", icon.kind)
	p.model.set_weapon("pistol")
	p.silencer = true
	main._process(0.016)
	t.check(icon.kind == "pistol_sd", "HUD: pistola com silenciador = modelo com silenciador", icon.kind)
	p.silencer = false
	# vida em barra
	p.health_changed.emit(40)
	t.check(is_equal_approx(main._hud_health.value, 0.4) and main._hud_health.tail == "40", "HUD: barra de vida acompanha a vida", str(main._hud_health.value))
	main.reset_all()
	await t._frames(2)
	t.check(radar.seen.is_empty() and main.danger.value == 0.0 and is_equal_approx(main._hud_health.value, 1.0), "R: radar esquece todos, perigo zera, vida cheia", "%d %.2f %.2f" % [radar.seen.size(), main.danger.value, main._hud_health.value])
	# sobrevivência: munição ao lado do modelo
	main.apply_mode(GameMode.SURVIVAL)
	await t._frames(2)
	main._process(0.016)
	t.check(main._hud_weapon.text == str(p.ammo_of("pistol")) and main._hud_weapon.position.x + main._hud_weapon.size.x <= icon.position.x, "HUD sobrevivência: munição ao lado do modelo", main._hud_weapon.text)
	main.apply_mode(GameMode.ARCADE)
	main.queue_free()
	await t._frames(2)


## HUD escondido/visível nos estados especiais: cutscene, inspect, pause, game over.
func test_hud_visibility_states() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var hud: CanvasLayer = main._hud
	t.check(hud.visible, "HUD: visível no jogo normal")
	# cutscene: HUD escondido
	main.cutscene.play_clones(p, main.lab)
	await t._frames(2)
	t.check(not hud.visible and p.cutscene, "HUD: escondido durante cutscene", str(hud.visible))
	main.cutscene.stop()
	await t._frames(2)
	t.check(hud.visible and not p.cutscene, "HUD: volta depois da cutscene")
	# inspect: HUD escondido
	var key_item: KeyItem = main.key
	main.inspect.show_item(key_item)
	await t._frames(2)
	t.check(not hud.visible and main.inspect.busy, "HUD: escondido durante tela de inspeção", str(hud.visible))
	main.inspect._elapsed = 999.0
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(2)
	t.check(hud.visible and not main.inspect.busy, "HUD: volta depois da inspeção")
	# game over: HUD continua (mostra a vida que acabou)
	p.die(Vector3.BACK, p.global_position + Vector3.UP)
	await t._frames(2)
	main._game_over_t = 0.0
	main.show_game_over()
	await t._frames(2)
	t.check(hud.visible and main.game_over, "HUD: continua visível no game over (mostra a vida)")
	# end screen: HUD continua
	main.reset_all()
	await t._frames(2)
	main.ended = true
	main.show_end()
	await t._frames(2)
	t.check(hud.visible and main.ended, "HUD: continua visível na tela de fim")
	main.queue_free()
	await t._frames(2)


## HUD ampliado corretamente com F2 (PS1 240p → PS2 480p): escala dobra, itens inteiros na tela.
func test_hud_scaling() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	main.apply_gfx("ps1")
	await t._frames(2)
	var ps1_scale: Vector2 = main._hud.scale
	t.check(is_equal_approx(ps1_scale.x, 1.0) and is_equal_approx(ps1_scale.y, 1.0), "HUD PS1: escala 1x (240p)", str(ps1_scale))
	main.apply_gfx("ps2")
	await t._frames(2)
	var ps2_scale: Vector2 = main._hud.scale
	t.check(is_equal_approx(ps2_scale.x, 2.0) and is_equal_approx(ps2_scale.y, 2.0), "HUD PS2: escala 2x (480p)", str(ps2_scale))
	# conferir que o radar, arma e vida ficam inteiros na tela em ambos os modos
	main._process(0.016)
	var area: Vector2 = main.get_viewport().get_visible_rect().size / main._hud.scale
	var r_rect := Rect2(main.radar.position, main.radar.size)
	var i_rect := Rect2(main._weapon_icon.position, main._weapon_icon.size)
	var h_rect := Rect2(main._hud_health.position, main._hud_health.size)
	t.check(Rect2(Vector2.ZERO, area).encloses(r_rect), "HUD PS2: radar inteiro na tela", str(r_rect))
	t.check(Rect2(Vector2.ZERO, area).encloses(i_rect), "HUD PS2: arma inteira na tela", str(i_rect))
	t.check(Rect2(Vector2.ZERO, area).encloses(h_rect), "HUD PS2: vida inteira na tela", str(h_rect))
	main.queue_free()
	await t._frames(2)


## F3 troca de modo: arcade sem número de munição, survival com número ao lado da arma.
func test_mode_switch_hud() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	main.apply_mode(GameMode.ARCADE)
	await t._frames(2)
	main._process(0.016)
	t.check(main._hud_weapon.text == "", "arcade: sem número de munição no HUD", main._hud_weapon.text)
	main.apply_mode(GameMode.SURVIVAL)
	await t._frames(2)
	main._process(0.016)
	var ammo_text: String = main._hud_weapon.text
	t.check(ammo_text != "" and ammo_text.is_valid_int(), "survival: número de munição no HUD", ammo_text)
	t.check(int(ammo_text) == main.player.ammo_of("pistol"), "survival: número correto", "%s vs %d" % [ammo_text, main.player.ammo_of("pistol")])
	# munição baixa (LOW_AMMO): vermelho
	main.player.ammo["pistol"] = 2
	main._process(0.016)
	var low_color: Color = main._hud_weapon.get_theme_color("font_color")
	t.check(low_color.r > 0.9 and low_color.g < 0.5, "survival: munição baixa fica vermelha", str(low_color))
	# reiniciar limpa o aviso e volta à munição inicial
	main.reset_all()
	await t._frames(2)
	main._process(0.016)
	t.check(main._hud_weapon.text != "" and int(main._hud_weapon.text) > 2, "R limpa e volta à munição inicial", main._hud_weapon.text)
	main.apply_mode(GameMode.ARCADE)  # os testes seguintes são do arcade
	main.queue_free()
	await t._frames(2)


## Todas as armas no WeaponIcon: pistol, pistol_sd, m16, shotgun, sniper, m79.
func test_all_weapons() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var icon: WeaponIcon = main._weapon_icon
	# pistol
	p.model.set_weapon("pistol")
	p.silencer = false
	main._process(0.016)
	t.check(icon.kind == "pistol" and icon.texture != null, "arma: pistola", icon.kind)
	# pistol_sd (com silenciador)
	p.silencer = true
	main._process(0.016)
	t.check(icon.kind == "pistol_sd" and icon.texture != null, "arma: pistola com silenciador", icon.kind)
	p.silencer = false
	# m16
	p.model.set_weapon("m16")
	main._process(0.016)
	t.check(icon.kind == "m16" and icon.texture != null, "arma: M16", icon.kind)
	# shotgun
	p.model.set_weapon("shotgun")
	main._process(0.016)
	t.check(icon.kind == "shotgun" and icon.texture != null, "arma: escopeta", icon.kind)
	# sniper
	p.model.set_weapon("sniper")
	main._process(0.016)
	t.check(icon.kind == "sniper" and icon.texture != null, "arma: sniper", icon.kind)
	# m79
	p.model.set_weapon("m79")
	main._process(0.016)
	t.check(icon.kind == "m79" and icon.texture != null, "arma: M79", icon.kind)
	main.queue_free()
	await t._frames(2)


## Radar rastreia todos os tipos de inimigo: soldado, sniper, raptor, alossauro; mortos somem.
func test_radar_all_enemies() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var radar: Radar = main.radar
	# começa no telhado: ninguém visto
	t.check(radar.seen.is_empty(), "radar: no telhado ninguém visto", str(radar.seen.size()))
	# no meio do galpão; cada tipo de inimigo é posto à frente da câmera dela (sem nada no meio), depois some de vista
	p.global_position = Vector3(1.0, 0, -6.0)
	p.rotation.y = PI * 0.5
	p.camera_rig.yaw = p.rotation.y
	p.reset_physics_interpolation()
	var all: Array[Enemy] = [main.soldiers[2], main.sniper, main.yard_raptors[0], main.allosaurus]  # soldiers[2] = às costas dela
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED  # parados: não a veem nem atiram
	main.yard_raptors[0].lurking = false
	await t._frames(10)
	# um lugar sabidamente à vista: o de um guarda que o radar já pegou (caixas tapam boa parte do galpão)
	var spot := Vector3.INF
	for sd: Soldier in main.soldiers:
		if not sd in all and radar.is_tracked(sd):
			spot = sd.global_position
	t.check(spot != Vector3.INF, "radar: algum guarda à vista no galpão")
	var homes := {}
	for e in all:
		homes[e] = e.global_position
	for e in all:
		t.check(not radar.is_tracked(e), "radar: %s ainda não visto" % e.get_script().get_global_name())
		e.global_position = spot
		e.reset_physics_interpolation()
		await t._frames(6)
		t.check(radar.is_tracked(e), "radar: %s à vista = rastreado" % e.get_script().get_global_name())
		e.global_position = homes[e]  # volta para longe (outra sala, mezanino): segue rastreado
		e.reset_physics_interpolation()
		await t._frames(2)
		t.check(radar.is_tracked(e), "radar: %s longe da vista segue rastreado" % e.get_script().get_global_name())
	# cada tipo morre: some do radar (o ragdoll precisa do espaço da física)
	for e in all:
		e.process_mode = Node.PROCESS_MODE_INHERIT
		e.die(Vector3.BACK, e.global_position + Vector3.UP)
		await t._frames(2)
		t.check(not radar.is_tracked(e), "radar: %s morto some" % e.get_script().get_global_name())
	# R esquece todos
	main.reset_all()
	await t._frames(2)
	t.check(radar.seen.is_empty(), "R: radar esquece todos", str(radar.seen.size()))
	main.queue_free()
	await t._frames(2)


## Casos especiais de ameaça: sniper no telhado/escada escondida = 0, alossauro rugindo, raptor investindo.
func test_threat_special_cases() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	w.add_child(p)
	await t._frames(2)
	# sniper no telhado: ela está fora do alcance dele (Roof.has = true, _reaches = false)
	var sn := Sniper.new()
	sn.position = Vector3(6, 0, -6)
	sn.target = p
	w.add_child(sn)
	sn.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(2)
	sn.state = "aim_lock"
	sn.aim_progress = Sniper.AIM_LOCK_TIME
	# ela no telhado (sem passar quadros: ir e voltar de lá entre quadros seria uma queda que mata)
	p.global_position = Roof.START
	t.check(Roof.has(p.global_position), "telhado: ela está no telhado", str(p.global_position))
	t.check(sn.threat() == 0.0, "perigo: sniper enquanto ela está no telhado = 0 (fora do alcance)", str(sn.threat()))
	p.global_position = Vector3(0, 0, 0)
	t.check(sn.threat() > 0.95, "perigo: o mesmo sniper com ela no chão, à mostra = certo", str(sn.threat()))
	# alossauro rugindo: ameaça baixa (atordoa, não machuca)
	var allo := Allosaurus.new()
	allo.position = Vector3(-8, 0, 0)
	allo.target = p
	w.add_child(allo)
	allo.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(2)
	allo.state = "roar"
	t.check(allo.threat() < 0.35, "perigo: alossauro rugindo = baixo (atordoa, não mata)", str(allo.threat()))
	# raptor investindo: alto (vem de longe)
	var r := Raptor.new()
	r.position = Vector3(-14, 0, 0)
	r.target = p
	w.add_child(r)
	r.process_mode = Node.PROCESS_MODE_DISABLED
	await t._frames(2)
	r.state = "charge"
	t.check(r.threat() > 0.8, "perigo: raptor investindo = alto", str(r.threat()))
	# raptor mordendo: certo
	r.global_position = Vector3(-2, 0, 0)
	r.state = "bite"
	t.check(r.threat() == 1.0, "perigo: raptor mordendo ao alcance = certo", str(r.threat()))
