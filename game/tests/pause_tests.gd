extends RefCounted
## Testes do menu de pausa (PauseMenu): START do controle e ESC abrem o menu em vez de reiniciar; escolher com
## cima/baixo, CONTINUAR / REINICIAR / SHOWROOM / TELA CHEIA / VIBRAÇÃO / SAIR DO JOGO, não abre por cima de tela de inspeção nem no game over.
## Showroom: lista de animações do bicho, troca de bicho/modo/velocidade, anda na roda sem patinar, volta ao menu.
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
	t.check(menu.selected == PauseMenu.ITEMS.size() - 1 and PauseMenu.ITEMS[menu.selected] == "SAIR DO JOGO", "cima no começo = SAIR DO JOGO", str(menu.selected))
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

	await test_fullscreen(menu)
	await test_vibration(menu, p)
	main.reset_all()
	await t._frames(2)
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
	await t._frames(3)
	t.check(not main.inspect.busy and not t.paused, "mensagem fechada")
	# fechar a tela com o X (ou pular/atirar) não chega nela: nada de esquiva/cambalhota ao voltar ao jogo
	for a in ["crouch", "jump", "shoot"]:
		main.inspect.show_message("TESTE")
		await t._frames(int((Inspect.MIN_SHOW + 0.2) * 60.0))
		Input.action_press(a)
		var seen := {"busy": false}
		for i in 12:
			await t._frames(1)
			if p.moves.busy() or p.rolling or p.crouching:
				seen.busy = true
		Input.action_release(a)
		t.check(not main.inspect.busy and not t.paused and not seen.busy, "fechar a mensagem com %s não faz ela agir" % a, p.moves.mode)
		await t._frames(10)
	main.game_over = true
	await _start_button()
	t.check(not menu.is_open and not t.paused, "no game over o START não abre o menu")
	main.reset_all()
	main.game_over = false
	await t._frames(2)
	await test_showroom(main)
	main.queue_free()
	await t._frames(2)


## TELA CHEIA: confirmar troca SIM/NÃO, grava no arquivo (um de teste, não a config de verdade) e o jogo relê ao abrir.
func test_fullscreen(menu: PauseMenu) -> void:
	var real_path := Settings.path
	var real_full := Settings.fullscreen
	Settings.path = "user://test_settings.cfg"
	DirAccess.remove_absolute(Settings.path)
	Settings.load_file()
	t.check(not Settings.fullscreen, "sem arquivo de config = janela")
	await _start_button()
	for i in PauseMenu.ITEMS.find("TELA CHEIA"):
		await _tap("move_back")
	t.check(menu._rows[menu.selected].text == "> TELA CHEIA: NÃO <", "menu mostra TELA CHEIA: NÃO", menu._rows[menu.selected].text)
	await _tap("interact")
	t.check(menu.is_open and Settings.fullscreen and menu._rows[menu.selected].text.contains("SIM"),
		"confirmar liga a tela cheia e o menu segue aberto", menu._rows[menu.selected].text)
	var cfg := ConfigFile.new()
	t.check(cfg.load(Settings.path) == OK and cfg.get_value("video", "fullscreen", false) == true, "tela cheia salva no arquivo")
	Settings.fullscreen = false
	Settings.load_file()
	t.check(Settings.fullscreen, "ao abrir de novo o jogo lê SIM do arquivo")
	await _tap("interact")
	Settings.load_file()
	t.check(not Settings.fullscreen and menu._rows[menu.selected].text.contains("NÃO"), "confirmar de novo desliga e salva NÃO")
	menu.close()
	await t._frames(3)
	DirAccess.remove_absolute(Settings.path)
	Settings.path = real_path
	Settings.fullscreen = real_full


## Vibração (`Rumble`): tiro da pistola só no motor fraco, escopeta e dano também no forte, a pausa para tudo; VIBRAÇÃO no
## menu troca SIM/NÃO, grava no arquivo de teste e, desligada, nada chega aos motores.
func test_vibration(menu: PauseMenu, p: Player) -> void:
	var real_path := Settings.path
	var real_vib := Settings.vibration
	Settings.path = "user://test_settings.cfg"
	DirAccess.remove_absolute(Settings.path)
	Settings.load_file()
	t.check(Settings.vibration, "sem arquivo de config = com vibração")
	p.give_weapon("pistol")
	await t._frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	Rumble.last = {}
	p.fire()
	var pistol := Rumble.last.duplicate()
	t.check(pistol.get("weak", 0.0) > 0.2 and pistol.get("strong", 1.0) == 0.0, "tiro da pistola: só o motor fraco", str(pistol))
	p.give_weapon("shotgun")
	await t._frames(60)
	Rumble.last = {}
	p.fire()
	var shotgun := Rumble.last.duplicate()
	t.check(shotgun.get("strong", 0.0) > 0.3 and shotgun.get("weak", 0.0) > pistol.get("weak", 0.0), "tiro da escopeta: os dois motores, mais forte",
		str(shotgun))
	await t._frames(30)
	Rumble.last = {}
	p.take_hit(10, Vector3.FORWARD, p.global_position + Vector3.UP)
	t.check(Rumble.last.get("strong", 0.0) > 0.3 and Rumble.last.get("time", 0.0) >= 0.2, "levar golpe vibra", str(Rumble.last))
	await _start_button()
	t.check(menu.is_open and Rumble._until == 0, "abrir a pausa para a vibração")
	for i in PauseMenu.ITEMS.find("VIBRAÇÃO"):
		await _tap("move_back")
	t.check(menu._rows[menu.selected].text == "> VIBRAÇÃO: SIM <", "menu mostra VIBRAÇÃO: SIM", menu._rows[menu.selected].text)
	await _tap("interact")
	t.check(menu.is_open and not Settings.vibration and menu._rows[menu.selected].text.contains("NÃO"),
		"confirmar desliga a vibração e o menu segue aberto", menu._rows[menu.selected].text)
	var cfg := ConfigFile.new()
	t.check(cfg.load(Settings.path) == OK and cfg.get_value("input", "vibration", true) == false, "vibração desligada salva no arquivo")
	Settings.vibration = true
	Settings.load_file()
	t.check(not Settings.vibration, "ao abrir de novo o jogo lê NÃO do arquivo")
	menu.close()
	await t._frames(3)
	Rumble.last = {}
	p.take_hit(10, Vector3.FORWARD, p.global_position + Vector3.UP)
	p.camera_rig.shake(0.3, 0.5)
	t.check(Rumble.last.is_empty(), "desligada: golpe e tremor não vibram", str(Rumble.last))
	await _start_button()
	for i in PauseMenu.ITEMS.find("VIBRAÇÃO"):
		await _tap("move_back")
	await _tap("interact")
	Settings.load_file()
	t.check(Settings.vibration and not Rumble.last.is_empty() and menu._rows[menu.selected].text.contains("SIM"),
		"confirmar de novo liga, dá um toque e salva SIM", str(Rumble.last))
	menu.close()
	await t._frames(3)
	Rumble.stop()
	DirAccess.remove_absolute(Settings.path)
	Settings.path = real_path
	Settings.vibration = real_vib


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await t._frames(2)


func test_showroom(main: Node) -> void:
	var menu: PauseMenu = main.pause_menu
	var room := menu.showroom
	await _start_button()
	for i in PauseMenu.ITEMS.find("SHOWROOM"):
		await _tap("move_back")
	t.check(PauseMenu.ITEMS[menu.selected] == "SHOWROOM", "menu: SHOWROOM", str(menu.selected))
	await _tap("interact")
	await t._frames(3)
	t.check(room.is_open and t.paused and not menu._title.visible and room._view_layer.visible, "SHOWROOM abre o palco por cima do menu (jogo pausado)")
	t.check(room.model is RaptorModel and not room.model is AllosaurusModel, "começa no raptor")
	for a in ["Idle", "Walk", "Run", "Stalk", "Roar", "Bite", "TailWhip", "LeapAir"]:
		t.check(a in room.anims, "showroom: lista tem " + a)
	t.check(room.anims[0] == "Idle" and room.model.current == "Idle" and room.model.anim_player.is_playing(), "a primeira animação toca", room.model.current)
	await _tap("move_back")
	t.check(room.selected == 1 and room.model.current == room.anims[1], "baixo escolhe a próxima e ela toca", room.model.current)
	t.check(menu.is_open and PauseMenu.ITEMS[menu.selected] == "SHOWROOM", "o baixo do showroom não mexe no menu")
	await _tap("switch_weapon")
	await t._frames(2)
	t.check(room.model is AllosaurusModel and "Stomp" in room.anims and not "Stalk" in room.anims, "trocar bicho = alossauro e a lista dele")
	await _tap("switch_weapon")
	await t._frames(2)
	t.check(room.model is RaptorModel, "trocar de novo = raptor")

	# EM CÍRCULO: o ciclo anda na roda na velocidade em que foi feito; o pé de apoio fica parado no chão
	room.pick(room.anims.find("Walk"), false)
	room.set_mode(1)
	await t._frames(20)
	var sk := room.model.skeleton
	var toes := [sk.find_bone("Toe_L"), sk.find_bone("Toe_R")]
	var m := {"drag": 0.0, "planted": 0, "seen": [Vector3.ZERO, Vector3.ZERO]}  # a lambda copia variável local
	var grab := func() -> void:
		var xf := sk.get_global_transform_interpolated()
		for i in 2:
			var now: Vector3 = xf * sk.get_bone_global_pose(toes[i]).origin
			var on: bool = room.model.feet._mode[i] == FootPlant.PLANTED
			if on and m.seen[i] != Vector3.ZERO:
				m.drag = maxf(m.drag, Vector2(now.x - m.seen[i].x, now.z - m.seen[i].z).length())
				m.planted += 1
			m.seen[i] = now if on else Vector3.ZERO
	sk.skeleton_updated.connect(grab)
	var start := room.body.position
	await t._frames(60)
	sk.skeleton_updated.disconnect(grab)
	var went := room.body.position.distance_to(start)
	t.check(absf(went - Raptor.WALK_ANIM_SPEED) < 0.25, "EM CÍRCULO: anda na velocidade do ciclo", "%.2f m em 1 s" % went)
	t.check(m.planted > 30 and m.drag < 0.01, "EM CÍRCULO: pé de apoio parado no chão", "%d %.3f m" % [m.planted, m.drag])
	await _tap("jump")
	t.check(room.mode == 2, "MODO troca para GIRANDO", str(room.mode))
	var yaw0 := room.body.rotation.y
	await t._frames(30)
	t.check(room.body.rotation.y - yaw0 > 0.5, "GIRANDO: vira no lugar", "%.2f" % (room.body.rotation.y - yaw0))
	await _tap("jump")
	t.check(room.mode == 0 and room.body.position == Vector3.ZERO and not room.model.feet.active, "NO LUGAR: animação pura, parado na origem")
	await _tap("roll")
	t.check(room.speed_i == 1 and is_equal_approx(room.model.anim_player.speed_scale, 0.5), "VELOCIDADE: metade", str(room.model.anim_player.speed_scale))
	room.set_speed(0)
	var cam0 := room._cam.global_position
	Input.action_press("move_right")
	await t._frames(20)
	Input.action_release("move_right")
	await t._frames(2)
	t.check(room._cam.global_position.distance_to(cam0) > 0.5, "girar a câmera em volta")
	await _tap("crouch")
	t.check(not room.is_open and menu.is_open and menu._title.visible and t.paused, "bola volta ao menu (pausado, menu na tela)")
	await t._frames(3)
	t.check(menu.is_open, "o botão que fechou o showroom não fecha o menu")
	await _tap("interact")
	await t._frames(3)
	t.check(room.is_open, "SHOWROOM de novo")
	await _key(KEY_ESCAPE)
	t.check(not room.is_open and menu.is_open and t.paused, "ESC no showroom volta ao menu, não ao jogo")
	menu.close()
	await t._frames(3)
	t.check(not t.paused, "menu fechado, jogo volta")
