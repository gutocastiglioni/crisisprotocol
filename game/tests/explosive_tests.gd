extends "res://tests/ai_tests.gd"
## Caixotes de explosivos do posto da porta do pátio (ExplosiveCrate): só o guarda 7 mexe no detonador (3 e 4 na porta,
## 5 vigiando a ronda 0), bala comum só faz HARDENED e alerta, granada detona a cadeia que pega o posto inteiro, fogo no
## chão e nos corpos (Fire) e o R põe tudo de volta. Usa os auxiliares de ai_tests.gd; chamado por run_tests.gd.

const POST := [3, 4, 5, 7]


func run(runner: SceneTree) -> void:
	t = runner
	await test_layout()
	await test_bullet_pings()
	await test_grenade_chain()
	await test_fire_hurts()


## Só o 7 trabalha nos caixotes; os outros do posto ficam onde eram. As pilhas encadeiam (cada uma ao alcance de outra)
## e cada guarda do posto fica ao alcance do dano de alguma.
func test_layout() -> void:
	var main: Node = await _main_scene()
	await t._frames(30)
	var g7: Dictionary = Soldier.GUARDS[7]
	var spot := ExplosiveCrate.work_spot(g7.work)
	check(Enemy._flat(g7.pos - spot.pos).length() < 0.02 and absf(angle_difference(g7.rot_y, spot.rot_y)) < 0.01,
		"guarda 7 no lugar de trabalho do caixote (work_spot)", "%s / %s" % [g7.pos, spot.pos])
	var workers: Array = POST.filter(func(i: int) -> bool: return main.soldiers[i].distracted)
	check(workers == [7], "só o 7 mexe nos caixotes", str(workers))
	check(main.soldiers[7].is_distracted() and main.soldiers[7].model.state == "console", "o 7 está no detonador (animação Console)",
		"%s %s" % [main.soldiers[7].state, main.soldiers[7].model.state])
	check(main.soldiers[7]._stowed != null and main.soldiers[7]._stowed.visible and not main.soldiers[7].model.is_weapon_visible("m16"),
		"o fuzil do 7 fica encostado no caixote enquanto ele trabalha")
	var olds := {3: Vector3(-11.4, 0, -6.6), 4: Vector3(-11.4, 0, -10.4), 5: Vector3(-10.6, 0, -1.6)}
	for i: int in olds:
		check(Enemy._flat(main.soldiers[i].global_position - olds[i]).length() < 0.2, "guarda %d no lugar de antes" % i, str(main.soldiers[i].global_position))
	var crates := t.get_nodes_in_group("explosives").filter(func(c: Node) -> bool: return Level.room_of((c as Node3D).global_position.x) == 0)  # os do túnel são outros
	var n := 0
	for s in ExplosiveCrate.STACKS:
		n += int(s[1])
	check(crates.size() == n, "um caixote por lugar das pilhas", "%d de %d" % [crates.size(), n])
	# cadeia ligada: a partir da primeira pilha, cada uma alcança outra
	var reached := [0]
	var grew := true
	while grew:
		grew = false
		for j in ExplosiveCrate.STACKS.size():
			if j in reached:
				continue
			for k: int in reached:
				if (ExplosiveCrate.STACKS[j][0] as Vector2).distance_to(ExplosiveCrate.STACKS[k][0]) - ExplosiveCrate.SIZE * 0.5 <= ExplosiveCrate.CHAIN_RADIUS:
					reached.append(j)
					grew = true
					break
	check(reached.size() == ExplosiveCrate.STACKS.size(), "as pilhas encadeiam (uma explode, todas explodem)", "%d de %d" % [reached.size(), ExplosiveCrate.STACKS.size()])
	for i: int in POST:
		var p: Vector3 = main.soldiers[i].global_position
		var near := ExplosiveCrate.STACKS.any(func(s: Array) -> bool: return Vector2(p.x, p.z).distance_to(s[0]) < ExplosiveCrate.RADIUS - 1.5)
		check(near, "guarda %d do posto ao alcance da explosão de alguma pilha" % i)
		# ninguém encostado nos caixotes (a cápsula de 0,3 m livre)
		var touching := ExplosiveCrate.STACKS.any(func(s: Array) -> bool:
			return absf(p.x - s[0].x) < ExplosiveCrate.SIZE * 0.5 + 0.3 and absf(p.z - s[0].y) < ExplosiveCrate.SIZE * 0.5 + 0.3)
		check(not touching, "guarda %d não encosta nos caixotes" % i, str(p))
	main.queue_free()
	await t.process_frame


## Pistola no caixote: não explode, mira escreve HARDENED, mossa de metal no caixote e o posto em volta entra em alerta
## (o 7 larga o detonador).
func test_bullet_pings() -> void:
	var main: Node = await _main_scene()
	await t._frames(20)
	for e: Node in t.get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED  # parados: não a veem nem atiram (o alerta é marcado mesmo assim)
	var p: Player = main.player
	p.health = 1000
	p.global_position = Vector3(-10.15, 0, -9.6)
	p.rotation.y = 0.0
	p.camera_rig.yaw = 0.0
	p.reset_physics_interpolation()
	var crate: ExplosiveCrate = null
	for c: ExplosiveCrate in t.get_nodes_in_group("explosives"):
		if Vector2(c.position.x, c.position.z).distance_to(Vector2(-10.15, -12.25)) < 0.05:
			crate = c
	var tags := []
	p.armor_hit.connect(func(who: Node, tag: String) -> void: tags.append([who, tag]))
	var holes := Fx.decal_count()
	Input.action_press("aim")
	for i in 20:
		p.camera_rig.look_at_point(crate.global_position + Vector3(0, 0.1, 0.5))
		await t._frames(1)
	p.fire()
	await t._frames(3)
	Input.action_release("aim")
	check(tags.size() == 1 and tags[0][0] == crate and tags[0][1] == ExplosiveCrate.TEXT, "tiro no caixote: a mira escreve HARDENED", str(tags))
	check(not crate.exploded and t.get_nodes_in_group("explosives").all(func(c: ExplosiveCrate) -> bool: return not c.exploded),
		"bala comum não explode o caixote")
	check(Fx.decal_count() > holes, "a bala deixa mossa no caixote", "%d -> %d" % [holes, Fx.decal_count()])
	for i: int in POST:
		check(main.soldiers[i].alert_t > 0.0, "guarda %d do posto em alerta com a bala no metal" % i, str(main.soldiers[i].alert_t))
	check(not main.soldiers[7].is_distracted(), "o 7 larga o detonador")
	main.queue_free()
	await t.process_frame


## Granada na pilha do canto: a cadeia explode todos os caixotes, mata os 4 do posto, o chão e os corpos pegam fogo, os
## corpos não voam longe; a jogadora no mezanino nem sente. R põe tudo de volta.
func test_grenade_chain() -> void:
	var main: Node = await _main_scene()
	await t._frames(20)
	# os de longe ouvem a explosão e viriam atirar nela no mezanino: parados (o teste é só o alcance da explosão)
	for e: Node in t.get_nodes_in_group("enemies"):
		if not (e is Soldier and main.soldiers.find(e) in [0, 3, 4, 5, 6, 7]):
			e.process_mode = Node.PROCESS_MODE_DISABLED
	var p: Player = main.player
	p.global_position = Vector3(0.5, Catwalk.FLOOR_Y, 11.3)
	p.reset_physics_interpolation()
	await t._frames(2)
	var hp := p.health
	var start := {}
	for i: int in POST:
		start[i] = main.soldiers[i].global_position
	Grenade.explode(main, Vector3(-11.2, 1.5, -11.74), Vector3.BACK)
	await t._frames(60 * 2)
	var crates := t.get_nodes_in_group("explosives").filter(func(c: Node) -> bool: return Level.room_of((c as Node3D).global_position.x) == 0)  # os do túnel são outros
	var left: Array = crates.filter(func(c: ExplosiveCrate) -> bool: return not c.exploded)
	check(left.is_empty(), "a cadeia explode todos os caixotes", "%d sobraram" % left.size())
	for i: int in POST:
		var s: Soldier = main.soldiers[i]
		check(s.dead, "guarda %d do posto morre na explosão" % i, "vida %d" % s.health)
		check(s.burning, "o corpo do %d pega fogo" % i)
		var hips: Vector3 = s.model.ragdoll.bodies["Hips"].global_position
		check(Enemy._flat(hips - start[i]).length() < 7.0 and hips.y > -0.5, "o corpo do %d não voa longe" % i, str(hips))
	check(t.get_nodes_in_group("fires").size() >= ExplosiveCrate.STACKS.size(), "fogo no chão de cada pilha", str(t.get_nodes_in_group("fires").size()))
	check(not main.soldiers[2].dead and not main.soldiers[12].dead, "guardas longe do canto não morrem")
	check(p.health == hp, "a explosão não alcança a jogadora no mezanino", "%d -> %d" % [hp, p.health])
	main.reset_all()
	await t._frames(3)
	check(crates.all(func(c: ExplosiveCrate) -> bool: return not c.exploded and c.visible and not c._shape.disabled), "R: caixotes de volta")
	check(t.get_nodes_in_group("fires").is_empty(), "R: o fogo apaga")
	check(POST.all(func(i: int) -> bool: return not main.soldiers[i].dead and not main.soldiers[i].burning), "R: o posto de volta, sem fogo")
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
