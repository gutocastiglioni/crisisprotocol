extends RefCounted
## Testes do menu de pausa (PauseMenu): START do controle e ESC abrem o menu em vez de reiniciar; escolher com
## cima/baixo, CONTINUAR / REINICIAR / SAIR DO JOGO, não abre por cima de tela de inspeção nem no game over.
## Chamado por run_tests.gd (usa check/_frames de lá).

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	test_bindings()
	await test_pause_menu()


func _has_event(action: String, match_fn: Callable) -> bool:
	for e in InputMap.action_get_events(action):
		if match_fn.call(e):
			return true
	return false


func test_bindings() -> void:
	var start := func(e: InputEvent) -> bool: return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_START
	var esc := func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_ESCAPE
	var r := func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_R
	t.check(not _has_event("reset", start), "START não reinicia mais")
	t.check(_has_event("pause", start) and _has_event("pause", esc), "START e ESC = pausa")
	t.check(_has_event("reset", r), "R no teclado segue reiniciando")


func _start_button() -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = JOY_BUTTON_START
		e.pressed = pressed
		Input.parse_input_event(e)
		await t._frames(2)


func _tap(action: String) -> void:
	Input.action_press(action)
	await t._frames(2)
	Input.action_release(action)
	await t._frames(2)


func test_pause_menu() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var menu: PauseMenu = main.pause_menu
	var quit_asked := [false]
	for c in menu.quit.get_connections():
		menu.quit.disconnect(c.callable)
	menu.quit.connect(func() -> void: quit_asked[0] = true)

	await _start_button()
	t.check(menu.is_open and t.paused and menu._title.visible, "START abre o menu de pausa e para o jogo")
	t.check(menu.selected == 0 and menu._rows[0].text.contains("CONTINUAR"), "começa em CONTINUAR", menu._rows[0].text)
	var held := p.global_position
	Input.action_press("move_forward")
	await t._frames(30)
	Input.action_release("move_forward")
	await t._frames(2)
	t.check(p.global_position == held, "pausado: ela não anda")
	# o "frente" apertado ali em cima foi para o menu: cima no começo passa para o fim
	t.check(menu.selected == 2, "cima no começo = SAIR DO JOGO", str(menu.selected))
	await _tap("move_back")
	t.check(menu.selected == 0, "baixo no fim volta ao começo", str(menu.selected))
	await _tap("move_back")
	t.check(menu.selected == 1, "baixo = REINICIAR", str(menu.selected))
	await _tap("move_forward")
	t.check(menu.selected == 0, "cima = CONTINUAR", str(menu.selected))
	await _tap("interact")
	t.check(not menu.is_open and not t.paused and not menu._title.visible, "CONTINUAR fecha e o jogo volta")
	t.check(not p.crouching and p.global_position.distance_to(held) < 0.05, "o botão do menu não chega nela")

	await _start_button()
	t.check(menu.is_open, "START de novo abre")
	await _start_button()
	t.check(not menu.is_open and not t.paused, "START com o menu aberto volta ao jogo")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await t._frames(2)
	esc = esc.duplicate()
	esc.pressed = false
	Input.parse_input_event(esc)
	await t._frames(2)
	t.check(menu.is_open and t.paused, "ESC abre o menu")
	await _tap("crouch")
	t.check(not menu.is_open and not t.paused and not p.crouching, "bola (agachar) volta ao jogo sem agachar", "aberto=%s pausado=%s agachada=%s" % [menu.is_open, t.paused, p.crouching])

	# REINICIAR: volta ao começo do telhado com a vida cheia
	p.global_position = Roof.START + Vector3(2.0, 0.0, 1.0)
	p.reset_physics_interpolation()
	p.health = 40
	await t._frames(2)
	await _start_button()
	await _tap("move_back")
	await _tap("interact")
	await t._frames(3)
	t.check(not menu.is_open and not t.paused, "REINICIAR fecha o menu")
	t.check(p.global_position.distance_to(Roof.START) < 0.3 and p.health == Player.MAX_HEALTH,
		"REINICIAR = jogo do começo", "%s vida %d" % [p.global_position, p.health])

	await _start_button()
	await _tap("move_forward")
	await _tap("interact")
	t.check(quit_asked[0], "SAIR DO JOGO pede para fechar o jogo")
	menu.close()
	await t._frames(2)

	# não abre por cima de outra tela que parou o jogo nem no game over
	main.inspect.show_message("TESTE")
	await t._frames(2)
	await _start_button()
	t.check(main.inspect.busy and not menu.is_open, "com a mensagem na tela o START não abre o menu")
	await t._frames(int((Inspect.MIN_SHOW + 0.2) * 60.0))
	await _tap("interact")
	t.check(not main.inspect.busy and not t.paused, "mensagem fechada")
	main.game_over = true
	await _start_button()
	t.check(not menu.is_open and not t.paused, "no game over o START não abre o menu")
	main.reset_all()
	await t._frames(2)
	main.queue_free()
	await t._frames(2)
