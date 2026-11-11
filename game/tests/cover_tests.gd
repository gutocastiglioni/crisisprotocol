extends RefCounted
## Testes do encostar de costas na caixa/parede (PlayerCover, survival), por comando: parada ou andando contra a parede ela
## NÃO encosta sozinha; o V/L3 (ação "lean", que no survival não esgueira sozinho) encosta na parede mais perto (de costas,
## na distância da pose, glúteo na parede) e solta; anda de lado colada na velocidade do andar agachada e para na beirada
## olhando para ela, sai andando para longe, caixa baixa só serve agachada; mirar encostada esgueira pela beirada, mira em pé
## por cima da caixa baixa ou mira normal, e soltou a mira volta a ficar encostada; andando de lado a arma fica junto ao
## corpo, quem está atrás da caixa a vê menos (do lado aberto, igual) e no arcade o V volta a ser só esgueirar.
## Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá).

const WALL_FACE := -0.7  # frente da parede (z, normal +Z); a parede vai de x = -2 a x = 2

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	GameMode.set_mode(GameMode.SURVIVAL)
	await test_command_enters()
	await test_button_is_cover()
	await test_no_auto_cover()
	await test_slide_to_edge()
	await test_walk_away()
	await test_low_crate()
	await test_aim_returns()
	await test_aim_at_edge()
	await test_aim_over_low_crate()
	await test_aim_open_side()
	await test_slide_keeps_gun_close()
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


## Um toque no V / L3 (encostar/soltar no survival).
func _command() -> void:
	await _hold("lean", 2)


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
	t.check(p.cover.active and p.model.state in ["cover_l", "cover_r"], "V/L3 perto da parede: encosta", p.model.state)
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
	t.check(not p.cover.active and not p.model.state.begins_with("cover"), "outro V/L3: solta", p.model.state)
	p.global_position = Vector3(0, 0, 1.0)  # parede a 1,7 m: longe
	await t._frames(5)
	await _command()
	await t._frames(20)
	t.check(not p.cover.active, "longe da parede (mais de %.1f m): o V/L3 não faz nada" % PlayerCover.REACH)


## No survival o botão de esgueirar (V/L3) é o de encostar: perto da parede encosta e não se inclina; outro toque solta.
func test_button_is_cover() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0.8, 0, -0.2))  # perto da beirada (onde o arcade esgueiraria)
	await t._frames(10)
	await _command()
	await t._frames(40)
	t.check(p.cover.active and p.lean.side == 0 and p.lean.amount == 0.0, "V/L3 perto da parede: encosta, sem esgueirar",
		"encostada %s, lado %d" % [p.cover.active, p.lean.side])
	await _command()
	await t._frames(10)
	t.check(not p.cover.active and p.lean.side == 0, "outro toque: solta")


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
		"V/L3: encosta e fica com o direcional ainda para dentro da parede",
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
	var x0 := p.global_position.x
	await t._frames(12)
	var v := (p.global_position.x - x0) / (12.0 / 60.0)
	var crouch_v := Moves.speed("crouch_walk") * Player.CROUCH_WALK_SCALE * GameMode.move_scale()
	var cap := Moves.speed("strafe") * PlayerCover.STEP_RATE
	t.check(absf(v - minf(crouch_v, cap)) < 0.08 and absf(PlayerCover.slide_speed() - minf(crouch_v, cap)) < 0.001,
		"anda colada na velocidade do andar agachada, sem o passo passar de %.2fx o ciclo" % PlayerCover.STEP_RATE,
		"%.2f m/s (agachada %.2f, teto %.2f)" % [v, crouch_v, cap])
	t.check(p.model.tree.get("parameters/strafe_l_speed/scale") <= PlayerCover.STEP_RATE + 0.01,
		"o passo lateral toca no máximo a %.2fx (sem trotinho)" % PlayerCover.STEP_RATE,
		"%.2f" % float(p.model.tree.get("parameters/strafe_l_speed/scale")))
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
	t.check(not p.cover.active, "caixa de 1 m em pé: V/L3 não encosta (não cobre as costas)")
	p.crouching = true
	await t._frames(10)
	await _command()
	await t._frames(40)
	t.check(p.cover.active and p.model.state.begins_with("cover_crouch_"), "agachada: encosta na caixa baixa", p.model.state)
	p.crouching = false
	await t._frames(10)
	t.check(not p.cover.active and p.cover.held, "levantou: a caixa não serve em pé, pausa", p.model.state)
	p.crouching = true
	await t._frames(30)
	t.check(p.cover.active and p.model.state.begins_with("cover_crouch_"), "agachou de novo no lugar: volta a encostar", p.model.state)
	p.crouching = false
	await t._frames(5)
	await _hold("move_right", 20)
	p.crouching = true
	await t._frames(30)
	t.check(not p.cover.active and not p.cover.held, "levantou e andou dali: agachar não encosta sozinha", p.model.state)
	p.crouching = false
	var p2: Player = await _covered(1.5)  # caixa baixa do galpão (Level.LOW_CRATE_H)
	t.check(p2.cover.active and p2.model.state.begins_with("cover_") and not p2.model.state.begins_with("cover_crouch"),
		"caixa de 1,5 m: encosta em pé", p2.model.state)
	p2.crouching = true
	await t._frames(10)
	t.check(p2.cover.active and p2.model.state.begins_with("cover_crouch_"), "agachar encostada troca a pose", p2.model.state)
	p2.crouching = false
	await t._frames(10)


func test_aim_returns() -> void:
	var p: Player = await _covered()
	Input.action_press("aim")
	await t._frames(20)
	t.check(not p.cover.active and p.cover.held and p.aiming, "mirar sai da pose encostada (pausa)")
	Input.action_release("aim")
	await t._frames(40)
	t.check(p.cover.active and p.model.state in ["cover_l", "cover_r"] and absf(p.global_position.z - _wall_z()) < 0.03
		and (-p.global_basis.z).dot(Vector3.BACK) > 0.97,
		"soltou a mira: volta a ficar encostada, de costas para a parede", "%s z %.3f" % [p.model.state, p.global_position.z])
	p.crouching = true
	await t._frames(20)
	Input.action_press("aim")
	await t._frames(20)
	Input.action_release("aim")
	await t._frames(40)
	t.check(p.cover.active and p.model.state.begins_with("cover_crouch_"), "agachada: mira e volta encostada agachada", p.model.state)
	p.crouching = false
	await t._frames(20)
	# mirando, andou para longe da parede: soltou a mira longe dela, não volta
	Input.action_press("aim")
	await t._frames(10)
	await _hold("move_back", 40)
	await t._frames(5)
	Input.action_release("aim")
	await t._frames(40)
	t.check(not p.cover.active and not p.cover.held, "mirou e saiu de perto da parede: não volta a encostar",
		"z %.2f" % p.global_position.z)


## Na beirada, mirar esgueira pela quina (sem botão de esgueirar); soltou a mira, volta e fica encostada no mesmo lugar.
func test_aim_at_edge() -> void:
	var p: Player = await _covered()
	Input.action_press("move_right")
	for i in 240:
		await t._frames(1)
		if p.cover.at_edge:
			break
	Input.action_release("move_right")
	await t._frames(20)
	var at := p.global_position
	var turn := {"go": 0.0, "back": 0.0, "go_signs": {}, "back_signs": {}, "last": p.rotation.y}
	var track := func(key: String) -> void:
		var d := wrapf(p.rotation.y - float(turn.last), -PI, PI)
		turn[key] = float(turn[key]) + d
		if absf(d) > 0.002:
			turn[key + "_signs"][signf(d)] = float(turn[key + "_signs"].get(signf(d), 0.0)) + absf(d)
		turn.last = p.rotation.y
	Input.action_press("aim")
	for f in 40:
		await t._frames(1)
		track.call("go")
	t.check(p.aiming and p.cover.aim_mode == "edge" and p.lean.side != 0 and p.lean.amount > 0.99,
		"na beirada, mirar esgueira pela quina", "modo %s, lado %d, %.2f" % [p.cover.aim_mode, p.lean.side, p.lean.amount])
	t.check(p.global_position.x > at.x + 0.1 and (-p.global_basis.z).dot(Vector3.FORWARD) > 0.8,
		"deu o passo para fora da beirada, virada para o lado da caixa", "x %.2f (de %.2f)" % [p.global_position.x, at.x])
	# a beirada fica à esquerda dela (+X): o giro até a parede passa por ela (yaw subindo), meia volta, um lado só
	t.check(float(turn.go) > deg_to_rad(140.0) and float(turn.go) < deg_to_rad(200.0)
		and float(turn.go_signs.get(-1.0, 0.0)) < deg_to_rad(5.0),
		"mirar na beirada: meia volta pelo lado da beirada", "%.0f° %s" % [rad_to_deg(float(turn.go)), str(turn.go_signs)])
	Input.action_release("aim")
	for f in 60:
		await t._frames(1)
		track.call("back")
	t.check(absf(float(turn.go) + float(turn.back)) < deg_to_rad(10.0) and float(turn.back_signs.get(1.0, 0.0)) < deg_to_rad(5.0),
		"soltou: desfaz o giro pelo mesmo caminho (sem volta inteira)",
		"ida %.0f°, volta %.0f° %s" % [rad_to_deg(float(turn.go)), rad_to_deg(float(turn.back)), str(turn.back_signs)])
	t.check(p.lean.side == 0 and not p.lean.returning and p.cover.active and p.model.state in ["cover_l", "cover_r"],
		"soltou a mira: volta da quina e fica encostada de novo", p.model.state)
	t.check(Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() < 0.05
		and (-p.global_basis.z).dot(Vector3.BACK) > 0.97, "no mesmo lugar, de costas para a parede", str(p.global_position))


## Agachada atrás da caixa de 1 m, mirar = fica em pé e mira por cima dela; soltou, agacha e encosta de novo.
func test_aim_over_low_crate() -> void:
	var w: Node3D = await _world_with_wall(1.0)
	var p: Player = t._spawn_player(w, Vector3(0, 0, -0.2))
	p.crouching = true
	await t._frames(10)
	await _command()
	await t._frames(40)
	t.check(p.cover.active and p.crouching, "agachada encostada na caixa de 1 m")
	Input.action_press("aim")
	await t._frames(40)
	t.check(p.aiming and p.cover.aim_mode == "over" and not p.crouching and p.lean.side == 0,
		"mirar: fica em pé para mirar por cima da caixa", "modo %s, agachada %s" % [p.cover.aim_mode, p.crouching])
	t.check((-p.global_basis.z).dot(Vector3.FORWARD) > 0.9, "virada para o lado da caixa (para onde a câmera olha)")
	var muzzle := p.model.muzzle_position()
	t.check(muzzle.y > 1.0 + 0.1, "a arma fica acima da caixa", "cano a %.2f m" % muzzle.y)
	Input.action_release("aim")
	await t._frames(40)
	t.check(p.cover.active and p.crouching and p.model.state.begins_with("cover_crouch_"),
		"soltou a mira: agacha e fica encostada de novo", p.model.state)
	p.crouching = false
	# caixa de 2,4 m (o meio dela, longe das beiradas): alta demais, mira normal sem levantar nem esgueirar
	var q: Player = await _covered()
	Input.action_press("aim")
	await t._frames(20)
	t.check(q.aiming and q.cover.aim_mode == "open" and q.lean.side == 0, "parede alta e sem beirada: mira normal",
		q.cover.aim_mode)
	Input.action_release("aim")
	await t._frames(40)
	t.check(q.cover.active, "e volta a encostar")


## Câmera olhando para o lado aberto (para longe da parede): mirar é a mira normal, mesmo na beirada.
func test_aim_open_side() -> void:
	var p: Player = await _covered()
	p.global_position.x = 1.75  # perto da beirada
	await t._frames(30)
	p.camera_rig.yaw = PI
	await t._frames(5)
	Input.action_press("aim")
	await t._frames(20)
	t.check(p.aiming and p.cover.aim_mode == "open" and p.lean.side == 0, "câmera para o lado aberto: mira normal",
		p.cover.aim_mode)
	Input.action_release("aim")
	await t._frames(40)
	p.camera_rig.yaw = 0.0


## Andando de lado colada na parede, a arma fica junto ao corpo (a parte de cima é a da pose encostada, não a da mira).
func test_slide_keeps_gun_close() -> void:
	var p: Player = await _covered()
	var fwd := -p.global_basis.z
	var still: Vector3 = await _bone(p, "Hand_R")
	var still_c: Vector3 = await _bone(p, "Chest")
	Input.action_press("move_right")
	await t._frames(30)
	var moving: Vector3 = await _bone(p, "Hand_R")
	var moving_c: Vector3 = await _bone(p, "Chest")
	Input.action_release("move_right")
	var reach_still := (still - still_c).dot(fwd)
	var reach := (moving - moving_c).dot(fwd)
	t.check(p.model.state.begins_with("strafe") and absf(reach - reach_still) < 0.1,
		"andando colada, a mão da arma fica junto ao peito como parada (não estica para a frente)",
		"%s: %.2f m à frente andando, %.2f parada" % [p.model.state, reach, reach_still])
	await t._frames(20)


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
	t.check(not p.cover.active and p.model.state == "idle", "arcade: o V/L3 não encosta (só esgueira, jogo de antes)", p.model.state)
