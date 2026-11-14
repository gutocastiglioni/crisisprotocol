extends RefCounted
## Testes da tela de título (TitleScreen), da tela CONTROLES (ControlsScreen: desenho do controle e do teclado) e da pista
## de treino (Tutorial): passos na ordem, vão baixo só agachada (cápsula Player.CROUCH_H), caixas, baú, botão do portão,
## encostar/esgueirar e os alvos; fim do treino volta ao título. Chamado por run_tests.gd (usa check/_frames de lá).

var t: SceneTree  # o runner (run_tests.gd)
var main: Node


func run(runner: SceneTree) -> void:
	t = runner
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	GameMode.set_mode(GameMode.SURVIVAL)  # o perfil padrão do jogo (o resto da suíte roda no arcade)
	await test_title_and_controls()
	await test_course()
	GameMode.set_mode(GameMode.ARCADE)
	t.get_root().remove_child(main)
	main.queue_free()
	await t._frames(2)


func _tap(action: String) -> void:
	Input.action_press(action)
	await t._frames(2)
	Input.action_release(action)
	await t._frames(2)


func _hints(c: ControlsScreen) -> Array[UiStyle.Hint]:
	var out: Array[UiStyle.Hint] = []
	for n in c.board.get_children():
		if n is UiStyle.Hint and not n.is_queued_for_deletion():
			out.append(n)
	return out


## Nenhuma legenda sai da tela nem cobre outra nem o desenho.
func _check_layout(c: ControlsScreen, name: String) -> void:
	var area: Vector2 = c.board.get_viewport().get_visible_rect().size / c.layer.scale
	var rects: Array[Rect2] = []
	var bad := []
	for h in _hints(c):
		var r := Rect2(h.position, h.size)
		if not Rect2(Vector2.ZERO, area).encloses(r):
			bad.append("fora: " + h.text())
		if r.intersects(c.board.device_rect.grow(-1.0)):
			bad.append("no desenho: " + h.text())
		for o in rects:
			if r.intersects(o):
				bad.append("encosta: " + h.text())
		rects.append(r)
	t.check(bad.is_empty(), name + ": legendas na tela, sem cobrir umas às outras nem o desenho", str(bad))


func test_title_and_controls() -> void:
	var title: TitleScreen = main.title
	var controls: ControlsScreen = main.pause_menu.controls
	var p: Player = main.player
	t.check(not title.is_open, "testes não abrem a tela de título sozinhos")
	# nenhum texto embolado de ajuda no HUD
	var long := []
	for l: Label in main._hud.find_children("*", "Label", true, false):
		if l.visible and l.text.length() > 60:
			long.append(l.text.left(30))
	t.check(long.is_empty(), "HUD sem o texto de ajuda do começo", str(long))

	title.open()
	await t._frames(3)
	t.check(t.paused and title._title.visible and title._title.text == TitleScreen.NAME, "título: jogo pausado, nome do jogo")
	t.check(Array(TitleScreen.ITEMS) == ["JOGAR", "TUTORIAL", "CONTROLES", "OPÇÕES", "SAIR DO JOGO"],
		"título: JOGAR / TUTORIAL / CONTROLES / OPÇÕES / SAIR", str(TitleScreen.ITEMS))
	await _tap("move_back")
	await _tap("move_back")
	t.check(TitleScreen.ITEMS[title.selected] == "CONTROLES", "baixo, baixo = CONTROLES")
	await _tap("interact")
	await t._frames(2)
	t.check(controls.is_open and not title._title.visible and t.paused, "CONTROLES abre por cima do título")
	controls.set_view(true)
	await t._frames(2)
	var verbs := " ".join(_hints(controls).map(func(h: UiStyle.Hint) -> String: return h.text()))
	for v in ["MOVER", "CÂMERA", "MIRAR", "ATIRAR", "PULAR", "ROLAR", "AGACHAR", "PEGAR", "TROCAR ARMA", "PAUSA"]:
		t.check(v in verbs, "controle: legenda " + v, verbs)
	var shapes := []
	for h in _hints(controls):
		for it: Dictionary in h.items:
			for g: Dictionary in it.get("glyphs", []):
				shapes.append(g.get("shape", g.get("text", "")))
	for s in ["triangle", "circle", "cross", "square", "L1", "L2", "R1", "R2", "L3", "R3", "SELECT", "START", "stick_l", "stick_r"]:
		t.check(s in shapes, "controle: botão " + s + " desenhado na legenda", str(shapes))
	_check_layout(controls, "controle")
	await _tap("switch_weapon")
	t.check(not controls.view_pad, "Q / SELECT troca para o teclado")
	await t._frames(2)
	verbs = " ".join(_hints(controls).map(func(h: UiStyle.Hint) -> String: return h.text()))
	for v in ["MOVER", "CORRER", "AGACHAR", "ROLAR", "PULAR", "PEGAR", "TROCAR ARMA", "PAUSA", "ATIRAR", "MIRAR", "CONTROLES"]:
		t.check(v in verbs, "teclado: legenda " + v, verbs)
	for k in ["W", "A", "S", "D", "E", "F", "C", "Q", "ESPAÇO", "ESC", "F1"]:
		t.check(k in controls.board.lit, "teclado: tecla " + k + " acesa no desenho", str(controls.board.lit))
	_check_layout(controls, "teclado")
	await _tap("interact")
	await t._frames(3)
	t.check(not controls.is_open and title.is_open and title._title.visible and t.paused, "VOLTAR dos controles devolve o título")
	# OPÇÕES: a mesma tela da pausa, por cima do título; VOLTAR devolve o título
	var options: OptionsScreen = main.pause_menu.options
	t.check(title.options == options, "título e pausa usam a mesma tela de opções")
	title._select(TitleScreen.ITEMS.find("OPÇÕES"), false)
	await _tap("interact")
	await t._frames(2)
	t.check(options.is_open and not title._title.visible and t.paused, "OPÇÕES abre por cima do título")
	var rows := options._rows.map(func(l: Label) -> String: return l.text)
	for it in ["TELA CHEIA", "VOLUME", "VIBRAÇÃO", "VOLTAR"]:
		t.check(rows.any(func(r: String) -> bool: return r.contains(it)), "opções: " + it, str(rows))
	for i in OptionsScreen.ITEMS.find("VOLTAR"):
		await _tap("move_back")
	await _tap("interact")
	await t._frames(3)
	t.check(not options.is_open and title.is_open and title._title.visible and t.paused, "VOLTAR das opções devolve o título")
	# JOGAR: o título some e a fase começa no telhado
	title._select(0, false)
	await _tap("interact")
	await t._frames(4)
	t.check(not title.is_open and not t.paused and main.tutorial == null, "JOGAR fecha o título e o jogo anda")
	t.check(Roof.has(p.global_position), "JOGAR: ela no telhado")
	# F1 no jogo abre os controles; voltar devolve o jogo
	main._unhandled_input(_action_event("toggle_help"))
	await t._frames(2)
	t.check(controls.is_open and t.paused, "F1 abre os controles no jogo")
	await _tap("roll")
	await t._frames(4)
	t.check(not controls.is_open and not t.paused, "bola / espaço volta ao jogo")
	# pausa: CONTROLES e MENU INICIAL
	var menu: PauseMenu = main.pause_menu
	t.check("CONTROLES" in PauseMenu.ITEMS and "MENU INICIAL" in PauseMenu.ITEMS, "pausa com CONTROLES e MENU INICIAL")
	menu.open()
	await t._frames(2)
	menu._select(PauseMenu.ITEMS.find("MENU INICIAL"), false)
	await _tap("interact")
	await t._frames(4)
	t.check(title.is_open and t.paused and not menu.is_open, "MENU INICIAL volta ao título (pausado)")


func _action_event(action: String) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _in(tu: Tutorial, step: String, frames := 120) -> bool:
	for i in frames:
		if tu.current() == step and tu._flash <= 0.0:
			return true
		await t._frames(1)
	return tu.current() == step


func test_course() -> void:
	var title: TitleScreen = main.title
	var p: Player = main.player
	title._select(TitleScreen.ITEMS.find("TUTORIAL"), false)
	await _tap("interact")
	await t._frames(4)
	var tu: Tutorial = main.tutorial
	t.check(tu != null and not title.is_open and not t.paused, "TUTORIAL monta a pista e o jogo anda")
	if tu == null:
		return
	t.check(p.global_position.distance_to(Tutorial.ORIGIN) < 0.3 and tu.current() == "move", "começa no corredor, passo MOVER")
	t.check(tu._text.text != "" and tu._hint.text().contains("MOVER") and tu._band.visible, "aviso do passo na tela", tu._text.text)
	var far := true
	for e in main.all_enemies():
		if e.global_position.distance_to(p.global_position) < 40.0:
			far = false
	t.check(far, "nenhum inimigo a menos de 40 m da pista")
	# corredor: em pé, a parede do vão segura
	Input.action_press("move_forward")
	t.check(await _in(tu, "crouch", 200), "andou: passo AGACHAR", tu.current())
	await t._frames(90)
	var lp := tu.local_pos()
	t.check(lp.x < Tutorial.LOW_X - 0.2, "em pé ela não passa pelo vão baixo", "%.2f" % lp.x)
	Input.action_release("move_forward")
	await _tap("crouch")
	await t._frames(4)
	var cap := p._shape.shape as CapsuleShape3D
	t.check(p.crouching and is_equal_approx(cap.height, Player.CROUCH_H), "agachada: cápsula baixa", "%.2f" % cap.height)
	Input.action_press("move_forward")
	for i in 240:
		if tu.local_pos().x > Tutorial.LOW_X:
			break
		await t._frames(1)
	Input.action_release("move_forward")
	await t._frames(2)
	t.check(absf(tu.local_pos().x - Tutorial.LOW_X) < 0.5, "agachada entra debaixo do vão", "%.2f" % tu.local_pos().x)
	await _tap("crouch")
	await t._frames(4)
	t.check(p.crouching and is_equal_approx(cap.height, Player.CROUCH_H), "debaixo do vão o agachar não a levanta")
	Input.action_press("move_forward")
	t.check(await _in(tu, "climb", 300), "passou por baixo: passo SUBIR", tu.current())
	Input.action_release("move_forward")
	await _tap("crouch")
	await t._frames(4)
	t.check(not p.crouching and is_equal_approx(cap.height, Player.STAND_H), "fora do vão levanta, cápsula em pé")
	# caixa A: anda até ela e escala
	Input.action_press("move_forward")
	for i in 240:
		if tu.local_pos().x > Tutorial.CRATE_A.x - 0.9:
			break
		await t._frames(1)
	Input.action_press("jump")
	await t._frames(3)
	Input.action_release("jump")
	Input.action_release("move_forward")
	t.check(await _in(tu, "leap", 240), "escalou a caixa: passo PULAR", "%s %s" % [tu.current(), tu.local_pos()])
	# pula para a caixa B
	Input.action_press("move_forward")
	for i in 200:
		if tu.local_pos().x > Tutorial.CRATE_A.y - 0.45:
			break
		await t._frames(1)
	Input.action_press("jump")
	await t._frames(3)
	Input.action_release("jump")
	t.check(await _in(tu, "chest", 240), "pulou para a outra caixa: passo BAÚ", "%s %s" % [tu.current(), tu.local_pos()])
	Input.action_release("move_forward")
	# baú: ajoelha na frente e pega a M16
	await t._frames(30)
	p.global_transform = tu.chest.kneel_transform()
	p.reset_physics_interpolation()
	await t._frames(3)
	await _tap("interact")
	t.check(await _in(tu, "button", 360), "pegou a M16: passo BOTÃO", tu.current())
	t.check("m16" in p.weapons and p.ammo_of("m16") == int(GameMode.AMMO_CAP.m16), "M16 com munição cheia no treino", str(p.ammo_of("m16")))
	t.check(not tu.gate.opened, "portão fechado antes do botão")
	for i in 300:
		if not p.moves.busy():
			break
		await t._frames(1)
	p.global_position = tu.button.global_position
	p.rotation.y = 0.0
	p.reset_physics_interpolation()
	await t._frames(3)
	t.check(main._prompt.visible and main._prompt.text().contains("APERTAR BOTÃO"), "aviso APERTAR BOTÃO perto do botão", main._prompt.text())
	await _tap("interact")
	await t._frames(3)
	t.check(tu.gate.opened, "o botão abre o portão")
	t.check(await _in(tu, "cover", 90), "passo ENCOSTAR", tu.current())
	# encosta na caixa alta (de frente para ela, perto)
	var face_x := Tutorial.COVER_AT.x - Tutorial.COVER_SIZE.x * 0.5
	p.global_position = Tutorial.ORIGIN + Vector3(face_x - 0.7, 0, -0.5)
	p.rotation.y = -PI * 0.5
	p.camera_rig.reset_view(p.rotation.y)
	p.reset_physics_interpolation()
	await t._frames(3)
	await _tap("lean")
	t.check(await _in(tu, "peek", 120), "encostou: passo ESGUEIRAR E ATIRAR", "%s ativo=%s" % [tu.current(), p.cover.active])
	# o alvo escondido: atrás da caixa, não se vê do lugar em que ela encostou
	var target: TargetDummy = tu.targets[0]
	var eye := p.global_position + Vector3.UP * 1.5
	var hit := p.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target.global_position + Vector3.UP * 1.2, 1))
	t.check(not hit.is_empty(), "o alvo fica escondido atrás da caixa")
	p.cover.cancel()
	p.global_position = Tutorial.ORIGIN + Vector3(face_x - 0.6, 0, -Tutorial.COVER_SIZE.z * 0.5 - 1.4)  # fora da quina
	p.reset_physics_interpolation()
	await _shoot_until_dead(p, target)
	t.check(target.dead and await _in(tu, "switch", 90), "acertou o alvo escondido: passo TROCAR ARMA", tu.current())
	var was := p.weapon()
	await _tap("switch_weapon")
	t.check(p.weapon() != was and await _in(tu, "final", 90), "trocou de arma: passo ALVO DO FIM", "%s -> %s" % [was, p.weapon()])
	p.global_position = Tutorial.ORIGIN + Vector3(30.0, 0, 2.2)  # sala aberta, com vista do fundo
	p.reset_physics_interpolation()
	await t._frames(3)
	await _shoot_until_dead(p, tu.targets[1])
	t.check(tu.targets[1].dead, "acertou o alvo do fim")
	for i in 60:
		if tu.finished_t >= 0.0:
			break
		await t._frames(1)
	t.check(tu.finished_t >= 0.0 and tu._text.text.contains("COMPLETO"), "TUTORIAL COMPLETO", tu._text.text)
	# R no meio do treino recomeça a pista
	main.reset_all()
	await t._frames(3)
	t.check(main.tutorial == tu and tu.current() == "move" and p.global_position.distance_to(Tutorial.ORIGIN) < 0.3 and not tu.gate.opened
		and not tu.targets[0].dead and tu.chest.has_item(), "R no treino recomeça a pista do primeiro passo")
	# fim: volta ao título e a pista some
	tu.finished_t = Tutorial.END_TIME - 0.05
	tu.player = p
	await t._frames(10)
	t.check(main.tutorial == null and title.is_open and Roof.has(p.global_position), "fim do treino: volta ao título, pista apagada, ela no telhado")
	title.close()
	await t._frames(4)


## Mira no peito do alvo e atira até ele cair (no máximo uns 3 s).
func _shoot_until_dead(p: Player, target: TargetDummy) -> void:
	Input.action_press("aim")
	for i in 40:
		if target.dead:
			break
		p.camera_rig.look_at_point(target.global_position + Vector3.UP * 1.2)
		await t._frames(2)
		p.fire()
		await t._frames(4)
	Input.action_release("aim")
	await t._frames(2)
