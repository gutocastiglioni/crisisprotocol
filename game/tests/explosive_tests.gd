extends "res://tests/ai_tests.gd"
## Caixotes de explosivos (ExplosiveCrate) no fundo do túnel da mina (Tunnel.STACKS): os 4 guardas do fundo mexem nos
## caixotes de trabalho, bala comum só faz HARDENED e alerta quem está perto, granada detona a cadeia do lado em que cai
## (e arromba o portão da pedreira), fogo no chão e nos corpos (Fire) e o R põe tudo de volta. O posto da porta do pátio
## do galpão voltou a ser o de antes dos explosivos (nenhum caixote lá). Usa os auxiliares de ai_tests.gd; chamado por
## run_tests.gd.

const WORKERS := [2, 3, 4, 5]  # índices em Tunnel.GUARDS dos que mexem nos caixotes


func run(runner: SceneTree) -> void:
	t = runner
	await test_layout()
	await test_bullet_pings()
	await test_grenade_chain()
	await test_fire_hurts()


## Lado da pilha `s` de Tunnel.STACKS: -1 = parede norte, 1 = parede sul.
static func _side(s: Array) -> float:
	return signf((s[0] as Vector2).y - Tunnel.Z)


## Pilhas do mesmo lado encadeiam (cada uma ao alcance de outra) a partir da primeira daquele lado.
static func _chained(side: float) -> bool:
	var idx: Array = []
	for i in Tunnel.STACKS.size():
		if _side(Tunnel.STACKS[i]) == side:
			idx.append(i)
	var reached := [idx[0]]
	var grew := true
	while grew:
		grew = false
		for j: int in idx:
			if j in reached:
				continue
			for k: int in reached:
				if (Tunnel.STACKS[j][0] as Vector2).distance_to(Tunnel.STACKS[k][0]) - ExplosiveCrate.SIZE * 0.5 <= ExplosiveCrate.CHAIN_RADIUS:
					reached.append(j)
					grew = true
					break
	return reached.size() == idx.size()


## Galpão sem caixote de explosivos (o posto como era); no túnel, os 4 do fundo no trabalho, as pilhas encadeiam de cada
## lado até as do portão e ninguém encosta nos caixotes.
func test_layout() -> void:
	var main: Node = await _main_scene()
	await t._frames(30)
	var tn: Tunnel = main.tunnel
	var crates := t.get_nodes_in_group("explosives")
	check(crates.all(func(c: Node) -> bool: return Level.room_of((c as Node3D).global_position.x) == 2), "caixotes de explosivos só no túnel (o posto do galpão sem eles)")
	var n := 0
	for s in Tunnel.STACKS:
		n += int(s[1])
	check(crates.size() == n and tn.crates.size() == n, "um caixote por lugar das pilhas do túnel", "%d de %d" % [crates.size(), n])
	var g7: Soldier = main.soldiers[7]
	check(Enemy._flat(g7.global_position - Vector3(-8.2, 0, -12.0)).length() < 0.2 and not g7.distracted, "guarda 7 do galpão no canto, de posto (sem detonador)", str(g7.global_position))
	for i: int in WORKERS:
		var s: Soldier = tn.guards[i]
		var spot := Tunnel.guard_spot(i)
		check(Enemy._flat(s.global_position - spot.pos).length() < 0.1 and s.is_distracted() and s.model.state == "console",
			"guarda %d do fundo no caixote de trabalho (Console)" % i, "%s %s" % [s.global_position, s.model.state])
		check(s._stowed != null and s._stowed.visible and not s.model.is_weapon_visible("m16"), "o fuzil do %d encostado no caixote" % i)
		var p := s.global_position
		var touching := Tunnel.STACKS.any(func(st: Array) -> bool:
			return absf(p.x - st[0].x) < ExplosiveCrate.SIZE * 0.5 + 0.3 and absf(p.y - 0.0) < 0.1 and absf(p.z - st[0].y) < ExplosiveCrate.SIZE * 0.5 + 0.3)
		check(not touching, "guarda %d não encosta nos caixotes" % i, str(p))
	check(_chained(-1.0) and _chained(1.0), "as pilhas de cada lado encadeiam até as do portão")
	var g := Tunnel.gate_center() + Vector3.UP
	for side in [-1.0, 1.0]:
		check(tn.crates.any(func(c: ExplosiveCrate) -> bool: return signf(c.global_position.z - Tunnel.Z) == side and c.global_position.distance_to(g) < Tunnel.BREACH_RADIUS),
			"pilha do lado %d ao alcance do portão (arromba)" % side)
	main.queue_free()
	await t.process_frame


## Pistola no caixote: não explode, mira escreve HARDENED, mossa de metal e os do fundo em volta entram em alerta (o do
## detonador larga o trabalho).
func test_bullet_pings() -> void:
	var main: Node = await _main_scene()
	await t._frames(20)
	var tn: Tunnel = main.tunnel
	tn.talk_armed = false
	for e: Node in t.get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED  # parados: não a veem nem atiram (o alerta é marcado mesmo assim)
	var p: Player = main.player
	p.health = 1000
	# no meio da câmara, de frente para a primeira pilha do lado norte (a câmera atrás dela fica no corredor, livre)
	var crate := tn.crate_of(0)
	var aim_at := crate.global_position + Vector3(0.0, 0.1, ExplosiveCrate.SIZE * 0.5)  # face virada para ela
	p.global_position = Vector3(-101.0, 0, Tunnel.Z - 1.0)
	var to := aim_at - p.global_position
	p.rotation.y = atan2(-to.x, -to.z)
	p.camera_rig.yaw = p.rotation.y
	p.reset_physics_interpolation()
	var tags := []
	p.armor_hit.connect(func(who: Node, tag: String) -> void: tags.append([who, tag]))
	var holes := Fx.decal_count()
	Input.action_press("aim")
	for i in 20:
		p.camera_rig.look_at_point(aim_at)
		await t._frames(1)
	p.fire()
	await t._frames(3)
	Input.action_release("aim")
	check(tags.size() == 1 and tags[0][0] == crate and tags[0][1] == ExplosiveCrate.TEXT, "tiro no caixote: a mira escreve HARDENED", str(tags))
	check(not crate.exploded and tn.crates.all(func(c: ExplosiveCrate) -> bool: return not c.exploded), "bala comum não explode o caixote")
	check(Fx.decal_count() > holes, "a bala deixa mossa no caixote", "%d -> %d" % [holes, Fx.decal_count()])
	for i: int in WORKERS:
		check(tn.guards[i].alert_t > 0.0, "guarda %d do fundo em alerta com a bala no metal" % i, str(tn.guards[i].alert_t))
	check(not tn.guards[Tunnel.TALKERS[0]].is_distracted(), "o do detonador larga o trabalho")
	main.queue_free()
	await t.process_frame


## Granada na pilha do portão (lado norte): a cadeia daquele lado explode, mata os dois do fundo daquele lado, o chão e os
## corpos pegam fogo, os corpos não voam longe e o portão da pedreira arromba; a jogadora longe nem sente. R põe tudo de volta.
func test_grenade_chain() -> void:
	var main: Node = await _main_scene()
	await t._frames(20)
	var tn: Tunnel = main.tunnel
	tn.talk_armed = false
	for e: Node in t.get_nodes_in_group("enemies"):
		if not (e is Soldier and tn.guards.find(e) in WORKERS):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Player = main.player
	p.global_position = Vector3(-80.0, 0, Tunnel.Z)
	p.reset_physics_interpolation()
	await t._frames(2)
	var hp := p.health
	var north: Array = WORKERS.filter(func(i: int) -> bool: return tn.guards[i].global_position.z < Tunnel.Z)
	var start := {}
	for i: int in north:
		start[i] = tn.guards[i].global_position
	Grenade.explode(main, Vector3(-114.0, 1.2, Tunnel.Z - 4.0), Vector3.RIGHT)
	await t._frames(60 * 2)
	var side: Array = tn.crates.filter(func(c: ExplosiveCrate) -> bool: return c.global_position.z < Tunnel.Z)
	var left: Array = side.filter(func(c: ExplosiveCrate) -> bool: return not c.exploded)
	check(left.is_empty(), "a cadeia explode os caixotes do lado da granada", "%d sobraram" % left.size())
	check(north.size() == 2, "dois do fundo do lado norte", str(north))
	for i: int in north:
		var s: Soldier = tn.guards[i]
		check(s.dead, "guarda %d do fundo morre na explosão" % i, "vida %d" % s.health)
		check(s.burning, "o corpo do %d pega fogo" % i)
		var hips: Vector3 = s.model.ragdoll.bodies["Hips"].global_position
		check(Enemy._flat(hips - start[i]).length() < 7.0 and hips.y > -0.5, "o corpo do %d não voa longe" % i, str(hips))
	var stacks := Tunnel.STACKS.filter(func(s: Array) -> bool: return _side(s) < 0.0).size()
	check(t.get_nodes_in_group("fires").size() >= stacks, "fogo no chão de cada pilha", str(t.get_nodes_in_group("fires").size()))
	check(tn.is_breached and tn.gate.opened, "a explosão das pilhas do portão o arromba")
	check(p.health == hp, "a explosão não alcança a jogadora longe", "%d -> %d" % [hp, p.health])
	main.reset_all()
	await t._frames(3)
	check(tn.crates.all(func(c: ExplosiveCrate) -> bool: return not c.exploded and c.visible and not c._shape.disabled), "R: caixotes de volta")
	check(t.get_nodes_in_group("fires").is_empty(), "R: o fogo apaga")
	check(WORKERS.all(func(i: int) -> bool: return not tn.guards[i].dead and not tn.guards[i].burning), "R: os do fundo de volta, sem fogo")
	check(not tn.is_breached and not tn.gate.opened, "R: portão inteiro de novo")
	main.queue_free()
	await t.process_frame


## Fogo do chão machuca quem fica dentro; o preso num corpo, não. Explosão longe dos caixotes não os detona.
func test_fire_hurts() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	w.add_child(p)
	await t._frames(3)
	var hp := p.health
	Fire.burn(w, Vector3.ZERO, 0.7)
	await t._frames(70)
	check(p.health < hp, "fogo do chão machuca a jogadora dentro dele", "%d -> %d" % [hp, p.health])
	Fire.clear(t)
	var crate := ExplosiveCrate.new()
	w.add_child(crate)
	crate.position = Vector3(10, 0.5, 0)
	await t._frames(2)
	Grenade.explode(w, Vector3(10 - Grenade.RADIUS - 1.0, 0.2, 0))
	await t._frames(30)
	check(not crate.exploded, "granada fora do alcance não detona o caixote")
	Grenade.explode(w, Vector3(10 - 2.0, 0.2, 0))
	await t._frames(30)
	check(crate.exploded, "granada perto detona o caixote")
	Fire.clear(t)
	await t.process_frame
