extends RefCounted
## Testes do guerrilheiro morto no meio do pátio (Corpse) com a chave do container na mão e da emboscada dos 3
## raptors do pátio (Cutscene.play_ambush, Raptor.lurk/start_ambush/end_ambush). Chamado por run_tests.gd (usa
## check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_corpse_and_ambush()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _tap_interact() -> void:
	var down := InputEventAction.new()
	down.action = "interact"
	down.pressed = true
	Input.parse_input_event(down)
	await t._frames(2)
	var up := InputEventAction.new()
	up.action = "interact"
	Input.parse_input_event(up)
	await t._frames(2)


func _where(rs: Array[Raptor]) -> String:
	return str(rs.map(func(r: Raptor) -> String: return "%s %s" % [r.state, r.global_position.snapped(Vector3.ONE * 0.1)]))


func test_corpse_and_ambush() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var corpse: Corpse = main.corpse
	var key: KeyItem = main.key
	var cs: Cutscene = main.cutscene
	var rs: Array[Raptor] = main.yard_raptors
	# o morto no meio do pátio, com a chave do container na mão
	t.check(Level.room_of(corpse.global_position.x) == 1 and corpse.global_position.distance_to(Yard.CORPSE) < 0.01, "guerrilheiro morto no meio do pátio da mata", str(corpse.global_position))
	t.check(key.id == main.locker.lock and key.state == "held" and key.visible, "a chave do container está na mão dele", key.state)
	t.check(key.global_position.distance_to(corpse.bone_point("Hand_R")) < 0.15, "presa na mão direita", "%.2f" % key.global_position.distance_to(corpse.bone_point("Hand_R")))
	t.check(key.global_position.y < 0.4 and corpse.bone_point("Head").y < 0.45 and corpse.bone_point("Hips").y < 0.4, "ele está deitado no chão", "%s %s" % [corpse.bone_point("Head"), corpse.bone_point("Hips")])
	t.check(not key.shine and not key._light.visible, "a chave não brilha antes da luta")
	for i in 90:
		await t.process_frame
		if key._sparkle.visible or key._glow.visible:
			break
	t.check(not key._sparkle.visible and not key._glow.visible, "nem a estrela pisca")
	t.check(main.dummies.all(func(d: TargetDummy) -> bool: return d.loot == null), "nenhum alvo do galpão guarda a chave")
	# os 3 raptors do pátio escondidos nas moitas da clareira: sem corpo, sem IA, não ouvem nada
	t.check(rs.size() == 3 and rs.all(func(r: Raptor) -> bool: return r.lurking and not r.visible and r.collision_layer == 0), "os 3 raptors do pátio escondidos na mata")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var blocked := []
	for i in rs.size():
		var from: Vector3 = Yard.LURK[i] + Vector3.UP * 0.6
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, corpse.stand_point() + Vector3.UP * 0.6, 1)).is_empty():
			blocked.append(Yard.LURK[i])
		t.check(rs[i].global_position.distance_to(Yard.LURK[i]) < 0.3, "raptor %d na moita dele" % i, str(rs[i].global_position))
	t.check(blocked.is_empty(), "da moita até ela, nada sólido no caminho", str(blocked))
	p.global_position = corpse.global_position + Vector3(9.0, 0, -6.0)
	await t._frames(3)
	main.soldiers[0].spot()
	p.make_noise(26.0, 2.2)
	await t._frames(20)
	t.check(rs.all(func(r: Raptor) -> bool: return r.lurking and r.alert_level() == 0), "escondidos não ouvem tiro nem alarme")
	t.check(not cs.busy and corpse.armed, "longe dele: nada acontece")
	# chegando perto: a cena
	p.global_position = corpse.global_position + (corpse.stand_point() - corpse.global_position).normalized() * (Corpse.NOTICE_RANGE - 1.0)
	await t._frames(3)
	t.check(cs.busy and cs.scene == "ambush" and p.cutscene and not main._hud.visible and not corpse.armed, "chegou perto do morto: a cena da emboscada", "%s %s" % [cs.busy, p.global_position.distance_to(corpse.global_position)])
	p.take_hit(50, Vector3.BACK, p.global_position + Vector3.UP)
	t.check(p.health == 100, "na cena ela não leva dano")
	await t._frames(int(Cutscene.AMB_WALK * 60) + 10)
	t.check(p.global_position.distance_to(corpse.stand_point()) < 0.35, "anda até a mão dele", "%.2f" % p.global_position.distance_to(corpse.stand_point()))
	await t._frames(int((Cutscene.AMB_SUB_AT - Cutscene.AMB_WALK) * 60) + 10)
	t.check(cs._sub.visible and cs._sub.text == Cutscene.AMB_SUBTITLE and p.model.state == "crouch", "agachada: ELE ESTA SEGURANDO ALGUMA COISA...", "%s %s" % [cs._sub.visible, p.model.state])
	t.check(rs.all(func(r: Raptor) -> bool: return r.lurking), "os raptors ainda escondidos")
	await t._frames(int((Cutscene.AMB_WIDE_AT + 1.2 - Cutscene.AMB_SUB_AT) * 60))
	var ring := []
	for r in rs:
		ring.append(snappedf(Vector2(r.global_position.x - p.global_position.x, r.global_position.z - p.global_position.z).length(), 0.1))
	t.check(rs.all(func(r: Raptor) -> bool: return not r.lurking and r.visible and r.collision_layer == 2 and r.state == "ambush"), "saíram das moitas", _where(rs))
	t.check(ring.all(func(d: float) -> bool: return d > Cutscene.AMB_RING - 1.5 and d < Cutscene.AMB_RING + 1.5), "rodeando ela a uns %.0f m" % Cutscene.AMB_RING, str(ring))
	t.check(rs.all(func(r: Raptor) -> bool: return r.alert_level() == 0), "na roda, sem aviso de alerta ainda")
	t.check(not p.model.holstered, "ela de arma na mão")
	await t._frames(int((Cutscene.AMB_END_AT - Cutscene.AMB_WIDE_AT - 1.2) * 60) + 10)
	t.check(not cs.busy and not p.cutscene and main._hud.visible and p.camera_rig.camera.current, "fim da cena: controle de volta")
	t.check(rs.all(func(r: Raptor) -> bool: return r.in_combat() and r.alert_t > 0.0), "os três já em luta", _where(rs))
	t.check(not p.has_key(key.id) and key.state == "held", "a chave continua na mão dele")
	# a chave pode ser pega no meio da luta (sem brilhar)
	var saved := p.global_position
	p.global_position = key.global_position + Vector3(0.4, 0, 0.2)
	await t._frames(2)
	t.check(p.pick_key() == key, "perto da mão: aviso de pegar a chave")
	p.global_position = saved
	# os três mortos: a chave brilha
	rs[0].take_hit(999, Vector3.FORWARD, rs[0].global_position)
	rs[1].take_hit(999, Vector3.FORWARD, rs[1].global_position)
	await t._frames(2)
	t.check(not key.shine, "com raptor vivo, ainda sem brilho")
	rs[2].take_hit(999, Vector3.FORWARD, rs[2].global_position)
	await t._frames(2)
	var bright := 0.0
	for i in 90:
		await t.process_frame
		bright = maxf(bright, key.twinkle())
	t.check(key.shine and key._light.visible and key._glow.visible and bright > 0.8, "os três mortos: a chave na mão dele brilha")
	main.inspect.auto_close = 0.0
	p.global_position = key.global_position + Vector3(0.4, 0, 0.2)
	await t._frames(3)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(3)
	t.check(p.has_key(key.id) and key.state == "taken" and main.inspect.busy, "E pega a chave da mão dele (tela do item)")
	while main.inspect.busy:
		await t.process_frame
	# R: tudo de volta
	main.reset_all()
	await t._frames(3)
	t.check(corpse.armed and key.state == "held" and not key.shine and not p.has_key(key.id), "R: a chave volta para a mão dele, sem brilho")
	t.check(rs.all(func(r: Raptor) -> bool: return r.lurking and not r.dead and not r.visible), "R: os raptors de volta às moitas")
	t.check(Blood.count() >= 3, "R: o sangue dele volta", str(Blood.count()))
	# pular com E antes de eles saírem: saem já em luta, e o E não pega a chave
	p.global_position = corpse.stand_point() + Vector3(2.0, 0, 0)
	await t._frames(int(Cutscene.SKIP_AFTER * 60) + 10)
	t.check(cs.busy, "cena de novo")
	await _tap_interact()
	await t._frames(2)
	t.check(not cs.busy and not p.cutscene, "E pula a cena")
	t.check(rs.all(func(r: Raptor) -> bool: return not r.lurking and r.visible and r.in_combat()), "pulou: os raptors saem já em luta", _where(rs))
	t.check(not p.has_key(key.id) and not main.inspect.busy, "o E de pular não pega a chave")
	main.queue_free()
	await t._frames(2)
