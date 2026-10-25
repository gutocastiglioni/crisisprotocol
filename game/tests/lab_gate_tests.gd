extends RefCounted
## Testes da sala dos clones com as plaquetas (SubjectPlate), o tanque vazio do alossauro, a chave do painel no console e o
## portão da pedreira trancado por chave + código (Door.add_keypad, Inspect.keypad). Chamado por run_tests.gd (usa
## check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_lab_contents()
	await test_gate_keypad()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _press(action: String) -> void:
	Input.action_press(action)
	await t._frames(2)
	Input.action_release(action)
	await t._frames(3)


## Põe a jogadora em `at` olhando para -Z local de `yaw` (frente = -Z), parada.
func _stand(p: Player, at: Vector3, yaw: float) -> void:
	p.global_position = at
	p.rotation.y = yaw
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await t._frames(3)


func test_lab_contents() -> void:
	var main: Node = await _main()
	var lab: CloneLab = main.lab
	var p: Player = main.player
	lab.gate.open()
	lab.played = true  # sem a cena do choque
	# uma plaqueta por tubo + a do tanque, números diferentes; a do alossauro fora da sequência dos raptors
	t.check(lab.plates.size() == lab.clones.size() + 1, "uma plaqueta por tubo e a do tanque", str(lab.plates.size()))
	var numbers := lab.plates.map(func(pl: SubjectPlate) -> String: return pl.number)
	var unique := {}
	for n in numbers:
		unique[n] = true
	t.check(unique.size() == numbers.size(), "números SUBJECT diferentes", str(numbers))
	var allo: SubjectPlate = lab.plates[-1]
	t.check(allo.number == CloneLab.ALLO_SUBJECT and allo.empty and not allo.number in CloneLab.SUBJECTS, "plaqueta do tanque vazio com o número do alossauro")
	t.check(lab.plates.slice(0, -1).all(func(pl: SubjectPlate) -> bool: return not pl.empty), "as dos raptors marcam o tubo cheio")
	# cada plaqueta fica entre o tubo e o corredor, virada para quem vem pelo corredor, dentro da sala
	for i in lab.clones.size():
		var pl: SubjectPlate = lab.plates[i]
		var front := pl.global_transform * Vector3(0, 0, 0.8)
		t.check(CloneLab.inside(front) and absf(front.x) < absf(pl.global_position.x), "plaqueta %s de frente para o corredor" % pl.number, str(front))
	# tanque no canto do fundo à esquerda, dentro das paredes, sem encostar nos tubos nem no console
	var c := lab.tank.global_position
	var r := CloneLab.TANK_R + 0.2
	t.check(c.x < 0.0 and c.z < CloneLab.TUBE_Z[-1] and c.x - r > -CloneLab.HALF_W + 0.15 and c.z - r > CloneLab.Z_FAR + 0.15,
		"tanque no canto do fundo à esquerda, dentro da sala", str(c))
	var tube_far := Vector2(-CloneLab.TUBE_X, CloneLab.TUBE_Z[-1])
	t.check(Vector2(c.x, c.z).distance_to(tube_far) > r + CloneLab.TUBE_R + 0.15 + 1.0, "passagem entre o tanque e o último tubo")
	t.check(c.x + r < -1.6 - 0.3, "tanque longe do console do fundo")
	t.check(lab.tank.find_children("*", "RaptorModel", true, false).is_empty() and lab.tank.find_children("*", "CPUParticles3D", true, false).is_empty(),
		"tanque vazio: sem clone nem bolhas")
	# o corpo não atravessa o vidro nem a porta aberta
	var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 1.5, 0) + (lab.tank.global_basis.z + lab.tank.global_basis.x * 0.9).normalized() * 4.0,
		c + Vector3(0, 1.5, 0), 1)
	t.check(not main.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "o tanque tem colisão")
	# ler a plaqueta: E na frente dela abre a tela, pausa e mostra o número
	var pl0: SubjectPlate = lab.plates[0]
	await _stand(p, pl0.global_transform * Vector3(0, 0, 0.8), pl0.global_rotation.y)
	t.check(p.pick_plate() == pl0, "na frente da plaqueta: pode ler")
	var seen := {"title": "", "paused": false, "cam": false}
	main.inspect.on_shown = func() -> void:
		seen.title = main.inspect._title.text
		seen.paused = t.paused
		seen.cam = main.inspect._cam.current and main.inspect._cam.global_position.distance_to(pl0.view().origin) < 0.05
	main.inspect.auto_close = 0.0
	await _press("interact")
	while main.inspect.busy:
		await t.process_frame
	t.check(seen.title == "SUBJECT " + pl0.number and seen.paused and seen.cam, "E mostra a plaqueta de perto com o jogo pausado", str(seen))
	t.check(not t.paused and p.camera_rig.camera.current, "fecha e volta para a câmera dela")
	await _stand(p, pl0.global_transform * Vector3(0, 0, -0.8), pl0.global_rotation.y)
	t.check(p.pick_plate() == null, "por trás da plaqueta não lê")
	# a chave do painel em cima do console: E na frente da mesa pega
	var key: KeyItem = main.lab_key
	t.check(key.state == "held" and key.id == Yard.GATE_KEY and key.global_position.distance_to(lab.key_spot().origin) < 0.01, "chave do painel em cima do console")
	t.check(absf(key.global_position.y - (CloneLab.FLOOR_Y + 0.9)) < 0.02, "deitada no tampo da mesa", str(key.global_position))
	await _stand(p, Vector3(key.global_position.x, CloneLab.FLOOR_Y, key.global_position.z + 0.8), 0.0)
	t.check(p.pick_key() == key, "na frente do console: pode pegar a chave")
	main.inspect.on_shown = Callable()
	await _press("interact")
	while main.inspect.busy:
		await t.process_frame
	t.check(p.has_key(Yard.GATE_KEY) and key.state == "taken", "E pega a chave do painel")
	main.reset_all()
	await t._frames(3)
	t.check(key.state == "held" and key.global_position.distance_to(lab.key_spot().origin) < 0.01 and not p.has_key(Yard.GATE_KEY),
		"R: a chave volta para o console")
	main.inspect.auto_close = -1.0
	main.queue_free()
	await t._frames(2)


func test_gate_keypad() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var ins: Inspect = main.inspect
	var gate: Door = main._code_door()
	t.check(gate != null and gate.room == 1 and gate.lock == Yard.GATE_KEY and gate.code == CloneLab.ALLO_SUBJECT,
		"portão da pedreira trancado por chave + código (o número do tanque vazio)")
	t.check(gate.is_locked() and gate.collision_layer == 1 and not Level.connected(t, 1, 2), "começa trancado e fechado")
	t.check(gate._keypad != null and gate._keypad.global_basis.z.dot(Vector3.RIGHT) > 0.99, "teclado no pilar, virado para o pátio")
	var front := gate.global_position + Vector3(1.2, 0, Yard.GATE_GAP * 0.5 - 0.2)
	await _stand(p, front, PI * 0.5)
	t.check(p.pick_door() == gate, "na frente do portão: aviso do painel")
	ins.auto_close = 0.0
	# sem a chave: o painel não liga
	var seen := {"title": ""}
	ins.on_shown = func() -> void: seen.title = ins._title.text
	await _press("interact")
	while ins.busy:
		await t.process_frame
	t.check(seen.title == "PAINEL DESLIGADO" and gate.is_locked() and not gate.opened, "sem a chave o painel não liga", seen.title)
	t.check(not t.paused and p.camera_rig.camera.current, "fecha e volta para a câmera dela")
	# com a chave e o código errado: continua trancado e ela fica com a chave
	p.add_key(Yard.GATE_KEY)
	ins.auto_code = "1234"
	await main._on_keypad(gate)
	t.check(ins.code_tries == 1 and gate.is_locked() and not gate.opened and p.has_key(Yard.GATE_KEY), "código errado: trancado, a chave fica")
	t.check(gate._keypad_screen.albedo_color.g < 0.2, "sem acertar, o visor apaga")
	# saindo sem confirmar (C): nada muda
	ins.auto_code = ""
	main._on_keypad(gate)
	await t._frames(int(Inspect.ZOOM_IN * 60) + int(Inspect.MIN_SHOW * 60) + 5)
	t.check(ins._typing and gate._keypad_screen.albedo_color.g > 0.8, "com a chave o painel liga e espera o código")
	await _press("crouch")
	while ins.busy:
		await t.process_frame
	t.check(gate.is_locked() and p.has_key(Yard.GATE_KEY), "saiu do painel (C): continua trancado")
	# o código certo pelas setas (direita passa de casa, cima/baixo mudam o número) e E: destranca, gasta a chave, abre
	main._on_keypad(gate)
	await t._frames(int(Inspect.ZOOM_IN * 60) + int(Inspect.MIN_SHOW * 60) + 5)
	for a in ["move_right", "move_back", "move_right", "move_forward", "move_forward", "move_right", "move_back", "move_back", "move_back"]:
		await _press(a)
	t.check(ins._entered() == CloneLab.ALLO_SUBJECT, "setas: 0 -> 9, 2 e 7", ins._entered())
	await _press("interact")
	while ins.busy:
		await t.process_frame
	await t._frames(int(Door.OPEN_TIME * 60) + 5)
	t.check(not gate.is_locked() and gate.opened and gate.collision_layer == 0 and not p.has_key(Yard.GATE_KEY), "código certo: destranca, gasta a chave e abre")
	t.check(Level.connected(t, 1, 2), "pátio e pedreira ligados")
	main.reset_all()
	await t._frames(3)
	t.check(gate.is_locked() and not gate.opened and gate.collision_layer == 1 and gate._keypad_screen.albedo_color.g < 0.2, "R: tranca de novo com o visor apagado")
	ins.auto_code = ""
	ins.auto_close = -1.0
	ins.on_shown = Callable()
	main.queue_free()
	await t._frames(2)
