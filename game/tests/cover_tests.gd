extends RefCounted
## Testes do encostar de costas na caixa/parede (PlayerCover, survival), por comando: parada ou andando contra a parede ela
## NÃO encosta sozinha; G (ou dois empurrões do analógico direito para cima) encosta na parede mais perto (de costas, na
## distância da pose, glúteo na parede) e solta; anda de lado colada e para na beirada olhando para ela, sai andando para
## longe, caixa baixa só serve agachada, mirar sai, quem está atrás da caixa a vê menos (do lado aberto, igual) e no arcade
## o comando não faz nada.
## Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá).

const WALL_FACE := -0.7  # frente da parede (z, normal +Z); a parede vai de x = -2 a x = 2

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	GameMode.set_mode(GameMode.SURVIVAL)
	await test_command_enters()
	await test_double_flick()
	await test_no_auto_cover()
	await test_slide_to_edge()
	await test_walk_away()
	await test_low_crate()
	await test_aim_leaves()
	await test_hidden_behind()
	GameMode.set_mode(GameMode.ARCADE)
	await test_arcade_off()


## Parede de 4 m de largura, `h` de altura e 0,6 m de fundo, com a frente em z = WALL_FACE.
func _world_with_wall(h := 2.4) -> Node3D:
	var w: Node3D = await t._fresh_world()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, h, 0.6)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, h * 0.5, WALL_FACE - 0.3)
	w.add_child(body)
	return w


## Posição final de um osso (depois dos modificadores).
func _bone(p: Player, bone: String) -> Vector3:
	var sk := p.model.skeleton
	var m := {"at": Vector3.ZERO}  # a lambda copia variável local
	var grab := func() -> void:
		m.at = sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin
	sk.skeleton_updated.connect(grab)
	await t._frames(2)
	sk.skeleton_updated.disconnect(grab)
	return m.at


func _wall_z() -> float:
	return WALL_FACE + float(Moves.cover().wall)


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await t._frames(frames)
	Input.action_release(action)


## Um toque no G (encostar/soltar).
func _command() -> void:
	await _hold("cover", 2)


## Um empurrão do analógico direito para cima.
func _flick() -> void:
	await _hold("look_up", 3)


## Jogadora parada a 0,5 m da parede, virada para ela, encostada pelo G.
func _covered(h := 2.4) -> Player:
	var w: Node3D = await _world_with_wall(h)
	var p: Player = t._spawn_player(w, Vector3(0, 0, -0.2))
	await t._frames(10)
	await _command()
	await t._frames(40)
	return p


func test_command_enters() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0, 0, -0.2))  # virada para a parede, a 0,5 m dela
	await t._frames(60)
	t.check(not p.cover.active and p.model.state == "idle", "parada perto da parede: não encosta sozinha", p.model.state)
	await _command()
	await t._frames(40)
	t.check(p.cover.active and p.model.state in ["cover_l", "cover_r"], "G perto da parede: encosta", p.model.state)
	t.check(absf(p.global_position.z - _wall_z()) < 0.03, "na distância da pose (%.2f m do plano)" % Moves.cover().wall,
		"z %.3f, esperado %.3f" % [p.global_position.z, _wall_z()])
	t.check((-p.global_basis.z).dot(Vector3.BACK) > 0.97, "de costas para a parede", str(-p.global_basis.z))
	await t._frames(40)
	var hips: Vector3 = await _bone(p, "Hips")
	# o glúteo fica ~0,11 m atrás do osso do quadril: com o quadril a isso da parede, ela está escorada
	t.check(hips.z - WALL_FACE > 0.06 and hips.z - WALL_FACE < 0.17, "o quadril vai para trás até a parede (escorada)",
		"osso do quadril a %.3f m da parede" % (hips.z - WALL_FACE))
	var x0 := p.global_position.x
	await t._frames(60)
	t.check(absf(p.global_position.x - x0) < 0.01 and absf(p.global_position.z - _wall_z()) < 0.02, "parada encostada não escorrega")
	await _command()
	await t._frames(10)
	t.check(not p.cover.active and not p.model.state.begins_with("cover"), "outro G: solta", p.model.state)
	p.global_position = Vector3(0, 0, 1.0)  # parede a 1,7 m: longe
	await t._frames(5)
	await _command()
	await t._frames(20)
	t.check(not p.cover.active, "longe da parede (mais de %.1f m): o G não faz nada" % PlayerCover.REACH)


func test_double_flick() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0, 0, -0.2))
	await t._frames(10)
	await _flick()
	await t._frames(40)
	t.check(not p.cover.active, "um empurrão do analógico direito para cima: não encosta")
	await _flick()
	await t._frames(6)
	await _flick()
	await t._frames(40)
	t.check(p.cover.active, "dois empurrões rápidos para cima: encosta")
	await _flick()
	await t._frames(40)
	t.check(p.cover.active, "um empurrão só (encostada): continua")
	await _flick()
	await t._frames(6)
	await _flick()
	await t._frames(10)
	t.check(not p.cover.active, "dois empurrões de novo: solta")


## O que embolava os movimentos: andar contra a parede/caixa não vira mais de costas sozinha.
func test_no_auto_cover() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0.3, 0, 1.5))
	await t._frames(5)
	Input.action_press("move_forward")
	await t._frames(90)
	t.check(not p.cover.active and (-p.global_basis.z).dot(Vector3.FORWARD) > 0.9, "andando contra a parede: segue de frente para ela, sem encostar",
		"%s %s" % [p.model.state, str(-p.global_basis.z)])
	await _command()
	await t._frames(40)
	t.check(p.cover.active and absf(p.global_position.z - _wall_z()) < 0.03 and Vector2(p.velocity.x, p.velocity.z).length() < 0.05,
		"G: encosta e fica com o direcional ainda para dentro da parede",
		"z %.3f, vel %.2f" % [p.global_position.z, Vector2(p.velocity.x, p.velocity.z).length()])
	Input.action_release("move_forward")
	await t._frames(5)


func test_slide_to_edge() -> void:
	var p: Player = await _covered()
	# direita da câmera (+X) = esquerda dela, que está de costas para a parede
	Input.action_press("move_right")
	await t._frames(20)
	t.check(p.cover.active and p.model.state == "strafe_l" and p.global_position.x > 0.15, "direcional para o lado: anda de lado colada",
		"%s x %.2f" % [p.model.state, p.global_position.x])
	t.check(absf(p.global_position.z - _wall_z()) < 0.03 and (-p.global_basis.z).dot(Vector3.BACK) > 0.97,
		"sem sair da parede nem virar", "z %.3f" % p.global_position.z)
	t.check(p.model.head_look.yaw > 0.5, "a cabeça vira para onde ela vai", "%.2f" % p.model.head_look.yaw)
	var edge := {"x": 0.0, "state": ""}
	for i in 240:  # até chegar na beirada
		await t._frames(1)
		if p.cover.at_edge:
			edge.x = p.global_position.x
			edge.state = p.model.state
			break
	t.check(p.cover.active and p.cover.at_edge and edge.x > 1.55 and edge.x < 1.95,
		"para na beirada com metade do corpo ainda encostada", "x %.2f (beirada em 2,0)" % edge.x)
	t.check(edge.state == "cover_l", "e fica olhando para a beirada", edge.state)
	Input.action_release("move_right")
	await t._frames(30)
	t.check(p.cover.active and p.model.state == "cover_l" and absf(p.model.head_look.yaw) < 0.05 and absf(p.global_position.x - edge.x) < 0.02,
		"soltou: fica na beirada, pose encostada olhando para lá", p.model.state)
	await _hold("move_right", 70)
	t.check(not p.cover.active and p.global_position.x > 2.1, "seguindo empurrando para o lado: sai e contorna a quina",
		"x %.2f" % p.global_position.x)


func test_walk_away() -> void:
	var p: Player = await _covered()
	Input.action_press("move_back")  # para trás da câmera = para longe da parede
	await t._frames(30)
	Input.action_release("move_back")
	t.check(not p.cover.active and p.global_position.z > _wall_z() + 0.4 and not p.model.state.begins_with("cover"),
		"direcional para longe da parede: sai andando", "%s z %.2f" % [p.model.state, p.global_position.z])
	await t._frames(60)
	t.check(not p.cover.active, "parada de novo perto da parede: não volta a encostar sozinha")


func test_low_crate() -> void:
	var p: Player = await _covered(1.0)  # caixa de 1 m: cobre as costas dela só agachada
	t.check(not p.cover.active, "caixa de 1 m em pé: G não encosta (não cobre as costas)")
	p.crouching = true
	await t._frames(10)
	await _command()
	await t._frames(40)
	t.check(p.cover.active and p.model.state.begins_with("cover_crouch_"), "agachada: encosta na caixa baixa", p.model.state)
	p.crouching = false
	await t._frames(10)
	t.check(not p.cover.active, "levantou: a caixa não serve mais, sai", p.model.state)
	var p2: Player = await _covered(1.5)  # caixa baixa do galpão (Level.LOW_CRATE_H)
	t.check(p2.cover.active and p2.model.state.begins_with("cover_") and not p2.model.state.begins_with("cover_crouch"),
		"caixa de 1,5 m: encosta em pé", p2.model.state)
	p2.crouching = true
	await t._frames(10)
	t.check(p2.cover.active and p2.model.state.begins_with("cover_crouch_"), "agachar encostada troca a pose", p2.model.state)
	p2.crouching = false
	await t._frames(10)


func test_aim_leaves() -> void:
	var p: Player = await _covered()
	Input.action_press("aim")
	await t._frames(10)
	t.check(not p.cover.active and p.aiming, "mirar sai da parede")
	Input.action_release("aim")
	await t._frames(60)
	t.check(not p.cover.active, "parou de mirar: não volta a encostar sozinha")


## Encostada, quem está do outro lado da parede a vê de HIDE_MULT do alcance; do lado aberto, igual.
func test_hidden_behind() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0, 0, -0.2))
	await t._frames(8)
	var behind := Vector3(3.0, 1.6, -6.0)
	var front := Vector3(0.5, 1.6, 6.0)
	t.check(is_equal_approx(p.visibility_from(behind), p.visibility()), "solta: a mesma de qualquer lado")
	await _command()
	await t._frames(40)
	t.check(p.cover.active and is_equal_approx(p.visibility_from(behind), p.visibility() * PlayerCover.HIDE_MULT),
		"encostada: quem está atrás da caixa a vê menos", "%.2f de %.2f" % [p.visibility_from(behind), p.visibility()])
	t.check(is_equal_approx(p.visibility_from(front), p.visibility()), "quem está do lado aberto a vê normal")
	var s := Soldier.new()
	s.position = Vector3(behind.x, 0, behind.z)
	s.target = p
	w.add_child(s)
	await t._frames(3)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	t.check(is_equal_approx(s._sight_range(), s.sight_range * p.visibility() * PlayerCover.HIDE_MULT),
		"o alcance da visão do guarda de trás cai junto", "%.2f" % s._sight_range())


func test_arcade_off() -> void:
	var p: Player = await _covered()
	t.check(not p.cover.active and p.model.state == "idle", "arcade: o G não encosta (jogo de antes)", p.model.state)
