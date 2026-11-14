extends "res://tests/ai_tests.gd"
## Testes do guarda distraído no painel da parede (Soldier.GUARDS 12, `Enemy.distracted`, pistola) e das caixas baixas
## novas do galpão (Level.DIVIDERS). Usa os auxiliares de ai_tests.gd; chamado por run_tests.gd.


func run(runner: SceneTree, _picks: Array = []) -> void:
	t = runner
	await test_distracted_sees_nothing()
	await test_noise_wakes_him()
	await test_back_to_the_panel()
	await test_console_in_level()


## Guarda na origem olhando para +Z (rotation.y = PI), de pistola e distraído (ou não); ela na frente dele.
func _spawn_guard(player_pos: Vector3, distracted := true) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	w.add_child(p)
	var s := Soldier.new()
	s.rotation.y = PI
	s.target = p
	s.weapon = "pistol"
	s.distracted = distracted
	w.add_child(s)
	s.rng.seed = 5
	await t._frames(2)
	return [p, s, w]


func test_distracted_sees_nothing() -> void:
	# em pé, parada a 4 m bem na frente dele: o guarda comum a vê; o distraído segue no painel
	var pr := await _spawn_guard(Vector3(0, 0, 4))
	var s: Soldier = pr[1]
	var seen := false
	for i in 180:
		await t._frames(1)
		seen = seen or s.alert_level() > 0
	check(not seen and s.state == "idle" and s.is_distracted(), "guarda distraído não vê ela parada na frente", "%s nível %d" % [s.state, s.alert_level()])
	check(s.model.state == "console", "guarda distraído toca a animação do painel", s.model.state)
	check(not s.model.is_weapon_visible("pistol"), "no painel a pistola fica guardada")
	var pr2 := await _spawn_guard(Vector3(0, 0, 4), false)
	var s2: Soldier = pr2[1]
	for i in 180:
		await t._frames(1)
		if s2.in_combat():
			break
	check(s2.in_combat(), "o mesmo guarda sem estar distraído a vê", s2.state)


func test_noise_wakes_him() -> void:
	# barulho perto (passos de corrida): desconfia, vira, saca a pistola e daí vê como qualquer guarda
	var pr := await _spawn_guard(Vector3(0, 0, -5))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	await t._frames(30)
	p.make_noise(10.0, 1.0)
	var states := {}
	for i in 120:
		await t._frames(1)
		states[s.state] = true
		if s.state == "investigate":
			break
	check(states.has("suspicious") and not s.is_distracted(), "o barulho tira o guarda do painel", str(states.keys()))
	check(s.model.is_weapon_visible("pistol") and s.model.weapon == "pistol", "fora do painel a pistola vai para a mão")
	for i in 240:
		await t._frames(1)
		if s.in_combat():
			break
	check(s.in_combat(), "acordado, ele a vê e entra em combate", s.state)
	for i in 300:
		await t._frames(1)
		if s.shots_fired >= 2:
			break
	check(s.shots_fired >= 2, "atira de pistola", str(s.shots_fired))
	check(s.damage == Soldier.PISTOL.damage and s.fire_range == Soldier.PISTOL.range, "números do tiro da pistola")


func test_back_to_the_panel() -> void:
	# desistiu da busca: anda de volta, encosta no lugar da bancada e volta a mexer no painel (cego de novo)
	var pr := await _spawn_guard(Vector3(0, 0, -19))  # fora do alcance dele calmo (ela parada em pé: 16 m)
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	var post := s.global_position
	s.start_investigate(Vector3(4, 0, 3))
	for i in 600:
		await t._frames(1)
		if s.state == "search":
			break
	check(Enemy._flat(s.global_position - post).length() > 2.0, "foi ver o barulho longe do painel")
	s.alert_t = 0.0
	s.aware = 0.0
	s._resume()
	for i in 600:
		await t._frames(1)
		if s.is_distracted():
			break
	await t._frames(10)
	check(s.is_distracted() and s.model.state == "console", "voltou ao painel", "%s %.2f m" % [s.state, Enemy._flat(s.global_position - post).length()])
	check(absf(angle_difference(s.rotation.y, PI)) < 0.15, "de frente para o painel de novo", "%.2f" % s.rotation.y)
	p.global_position = Vector3(0, 0, 3)
	p.reset_physics_interpolation()
	for i in 90:
		await t._frames(1)
	check(s.alert_level() == 0, "de volta ao painel não vê ela na frente", str(s.alert_level()))


func test_console_in_level() -> void:
	var main: Node = await _main_scene()
	var g: Soldier = main.soldiers[12]  # o do painel da faixa (os outros distraídos: mesa do escritório e cabine)
	check(g != null and g.weapon == "pistol" and g.model.weapon == "pistol", "galpão: guarda de pistola no painel")
	if g == null:
		main.queue_free()
		await t.process_frame
		return
	for i in 60:
		await t._frames(1)
	check(g.is_distracted() and g.model.state == "console", "galpão: o guarda está mexendo no painel", g.state)
	# punhos no teclado: altura e distância da parede pela pose de verdade (osso da mão do esqueleto)
	var sk: Skeleton3D = g.model.skeleton
	var keys := Level.console_stand(Level.CONSOLE, Level.CONSOLE_YAW, Level.CONSOLE_DESK - 0.12)
	var out := Level.console_stand(Vector3.ZERO, Level.CONSOLE_YAW, 1.0)  # da parede para quem digita
	for side in ["L", "R"]:
		var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand_" + side))
		var fist := hand.origin + hand.basis.y.normalized() * 0.05
		var rel := Vector3(fist.x - keys.x, 0, fist.z - keys.z)
		check(absf(fist.y - Level.CONSOLE_KEYS_Y - 0.04) < 0.06 and absf(rel.dot(out)) < 0.1 and absf(rel.cross(Vector3.UP).dot(out)) < 0.35,
			"galpão: punho %s no teclado" % side, str(fist))
	# caixas baixas (estantes e pátio descoberto): escondem agachada (algo a 1 m) e não tapam quem está em pé (nada a 1,7 m)
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for at: Vector2 in [Vector2(-12.0, 37.6), Vector2(-7.85, 31.9), Vector2(-11.0, -2.0), Vector2(-1.8, -5.0)]:
		var low := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.0, at.y + 2.0), Vector3(at.x, 1.0, at.y), 1))
		var high := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.7, at.y + 2.0), Vector3(at.x, 1.7, at.y), 1))
		check(not low.is_empty() and high.is_empty(), "galpão: caixa baixa nova em %s" % str(at))
	main.queue_free()  # a cena principal não é o _world do runner: sem isto seguiria rodando nas partes seguintes
	await t.process_frame
