extends RefCounted
## Testes das torres de guarda do portão do pátio (GuardTower, Yard.TOWERS), dos snipers delas (fora de cena até os 3
## raptors da emboscada morrerem), da queda do último (cambaleia até a cerca, debruça no abdome e cai) com o fuzil e o
## cartão do painel do portão só depois que o corpo para, e da chave da M79 com a etiqueta "0M79". Chamado por
## run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_m79_key_tag()
	await test_towers_and_hidden_snipers()
	await test_last_sniper_falls_with_card()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _kill_yard_raptors(main: Node) -> void:
	for r: Raptor in main.yard_raptors:
		r.lurking = false
		r.take_hit(999, Vector3.FORWARD, r.global_position)


## Maior dobra de joelho (graus) do ragdoll.
func _knee(b: Dictionary) -> float:
	var k := 0.0
	for side in ["L", "R"]:
		k = maxf(k, rad_to_deg(b["UpperLeg_" + side].global_basis.y.angle_to(b["LowerLeg_" + side].global_basis.y)))
	return k


func test_m79_key_tag() -> void:
	var main: Node = await _main()
	var key: KeyItem = main.key
	t.check(key.id == main.locker.lock and key.kind == "key" and key.tag == "0M79", "chave do container da M79 com etiqueta 0M79", "%s %s %s" % [key.id, key.kind, key.tag])
	var labels: Array = key.find_children("*", "Label3D", true, false).filter(func(l: Label3D) -> bool: return l.text == "0M79")
	t.check(labels.size() == 1, "o 0M79 está escrito na etiqueta da chave (no chão/na mão)")
	t.check("0M79" in key.description, "a tela do item fala da etiqueta", key.description)
	var holder := Node3D.new()
	t.get_root().add_child(holder)
	var m := KeyItem.build_model(holder, key.kind, key.tag, key.card_color)
	t.check(m.find_children("*", "Label3D", true, false).size() == 1, "o modelo da tela do item também tem a etiqueta escrita")
	holder.queue_free()
	main.queue_free()
	await t._frames(2)


func test_towers_and_hidden_snipers() -> void:
	var main: Node = await _main()
	var towers: Array[GuardTower] = main.towers
	var snipers: Array[Sniper] = main.tower_snipers
	var gate: Door = main._code_door()
	t.check(towers.size() == 2 and snipers.size() == 2, "duas torres, um sniper em cada")
	var gz := gate.global_position.z
	t.check(towers.all(func(tw: GuardTower) -> bool: return Level.room_of(tw.global_position.x) == 1 and absf(tw.global_position.x - gate.global_position.x) < 3.0),
		"as torres ficam no pátio, encostadas no portão do fundo")
	t.check((towers[0].global_position.z - gz) * (towers[1].global_position.z - gz) < 0.0, "uma de cada lado do portão")
	var gap_free := towers.all(func(tw: GuardTower) -> bool: return absf(tw.global_position.z - gz) - GuardTower.SIZE * 0.5 > Yard.GATE_GAP * 0.5 + 0.8)
	t.check(gap_free, "nenhuma fecha o vão do portão nem o teclado")
	# nada sólido do pátio (árvore, moita, pedra, tronco) atravessando a torre
	var space := t.get_root().get_world_3d().direct_space_state
	for tw in towers:
		var own: Array[RID] = []
		for b: StaticBody3D in tw.find_children("*", "StaticBody3D", true, false):
			own.append(b.get_rid())
		var q := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(GuardTower.SIZE + 0.2, GuardTower.ROOF_Y - 0.4, GuardTower.SIZE + 0.2)
		q.shape = box
		q.transform = Transform3D(Basis.IDENTITY, tw.global_position + Vector3.UP * (GuardTower.ROOF_Y * 0.5 + 0.2))
		q.collision_mask = 1
		q.exclude = own
		var hits := space.intersect_shape(q, 8).filter(func(h: Dictionary) -> bool: return (h.collider as Node).get_parent() is not Door)
		t.check(hits.is_empty(), "torre em %s sem mata atravessando" % tw.global_position.snapped(Vector3.ONE * 0.1), str(hits.map(func(h: Dictionary) -> String: return str((h.collider as Node3D).global_position))))
	# antes da emboscada: fora de cena, sem corpo, sem IA, surdos
	t.check(snipers.all(func(s: Sniper) -> bool: return s.lurking and not s.visible and s.collision_layer == 0), "os snipers começam fora de cena")
	t.check(main.gate_card.state == "hidden" and main.gate_card.kind == "keycard" and main.gate_card.id == Yard.GATE_KEY, "o cartão do painel começa escondido")
	var console_keys := t.get_nodes_in_group("keys").filter(func(k: KeyItem) -> bool: return k.id == Yard.GATE_KEY)
	t.check(console_keys == [main.gate_card], "o painel só tem o cartão (a chave saiu do console da sala dos clones)")
	t.get_root().get_tree().call_group("enemies", "hear_noise", towers[0].global_position, 30.0, 1.0)
	await t._frames(10)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.lurking and s.state == "idle"), "fora de cena não ouvem tiro", str(snipers.map(func(s: Sniper) -> String: return s.state)))
	# dois raptors mortos: ainda não; o terceiro: sobem nas torres
	var rs: Array[Raptor] = main.yard_raptors
	for i in 2:
		rs[i].lurking = false
		rs[i].take_hit(999, Vector3.FORWARD, rs[i].global_position)
	await t._frames(2)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.lurking), "com raptor vivo, ninguém nas torres")
	rs[2].lurking = false
	rs[2].take_hit(999, Vector3.FORWARD, rs[2].global_position)
	await t._frames(3)
	t.check(snipers.all(func(s: Sniper) -> bool: return not s.lurking and s.visible and s.collision_layer == 2), "com os 3 raptors mortos, os snipers aparecem")
	for i in 2:
		var s := snipers[i]
		var on := s.perch.grow(0.01).has_point(Vector2(s.global_position.x, s.global_position.z)) and absf(s.global_position.y - (GuardTower.FLOOR_Y)) < 0.05
		t.check(on and (-s.global_basis.z).dot(Vector3.RIGHT) > 0.95, "sniper %d em cima da torre, olhando para o pátio" % i, str(s.global_position))
	# ela parada na estrada a uns 12 m da torre: ele a vê e mira (laser)
	main.player.global_position = Vector3(towers[0].global_position.x + 12.0, 0, -3.0)
	main.player.reset_physics_interpolation()
	var aimed := false
	for i in 240:
		await t._frames(1)
		if snipers.any(func(s: Sniper) -> bool: return s.state == "aim_lock"):
			aimed = true
			break
	t.check(aimed, "da torre ele a vê na estrada e mira", str(snipers.map(func(s: Sniper) -> String: return s.state)))
	main.reset_all()
	await t._frames(3)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.lurking and not s.visible and s.global_position.distance_to(main.towers[snipers.find(s)].post()) < 0.01),
		"R: de volta para fora de cena, no posto")
	main.queue_free()
	await t._frames(2)


func test_last_sniper_falls_with_card() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var snipers: Array[Sniper] = main.tower_snipers
	var card: KeyItem = main.gate_card
	p.global_position = Vector3(-30, 0, 10)
	p.reset_physics_interpolation()
	_kill_yard_raptors(main)
	await t._frames(3)
	for s in snipers:
		s.sight_range = 0.0
	# o primeiro morre lá em cima (não cai) e fica com o fuzil: não larga nada
	var first := snipers[1]
	first.take_hit(999, Vector3.LEFT, first.global_position + Vector3.UP * 1.3)
	await t._frames(90)
	var hips0: PhysicalBone3D = first.model.ragdoll.bodies["Hips"]
	t.check(not first.falls and hips0.global_position.y > GuardTower.FLOOR_Y - 0.6, "o primeiro morre em cima da torre", str(hips0.global_position))
	var drops := t.get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool: return pk.is_drop and pk.kind == "sniper")
	t.check(drops.is_empty() and not first.model.holstered, "o que não cai não larga o fuzil (fica na mão dele)", str(drops.size()))
	t.check(card.state == "hidden", "o cartão não cai do primeiro")
	var last := snipers[0]
	t.check(last.falls and last.loot == card, "o que sobrou fica com o cartão e vai cair da torre")
	# o último: tiro de frente (empurraria para dentro da torre); ele cambaleia até a cerca, debruça e cai para fora
	var bar := last.ledge
	var out := Vector3.RIGHT
	last.take_hit(999, Vector3.LEFT, last.global_position + Vector3.UP * 1.3)
	var b: Dictionary = last.model.ragdoll.bodies
	var gun_on := true
	var staggered := false
	var folded := false
	var worst_knee := 0.0
	var early_drop := false
	var n_drops := t.get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool: return pk.is_drop and pk.kind == "sniper").size()
	var landed_at := -1.0
	for i in 360:
		await t._frames(1)
		if last._staggering:
			staggered = staggered or last.model.state == "stagger_fwd"
			gun_on = gun_on and not last.model.holstered
		var hips: Vector3 = b["Hips"].global_position
		var chest: Vector3 = b["Chest"].global_position
		if last.model.is_ragdoll() and hips.y > bar.y - 0.15:
			# debruçado na barra: a dobra é na cintura (peito para fora e abaixo da barra, quadril na altura dela) e as
			# pernas penduradas esticadas (amolecendo, a perna ainda está no meio do passo do cambaleio)
			worst_knee = maxf(worst_knee, _knee(b))
			folded = folded or (out.dot(chest - bar) > 0.1 and chest.y < bar.y - 0.1)
		if hips.y > 1.0 and (card.state != "hidden" or t.get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool: return pk.is_drop and pk.kind == "sniper").size() > n_drops):
			early_drop = true
		if card.state == "dropped":
			landed_at = i / 60.0
			break
	var hips_end: Vector3 = b["Hips"].global_position
	t.check(staggered and gun_on, "morto, cambaleia para a frente (StaggerFwd) com o fuzil ainda na mão")
	t.check(folded, "debruça na cerca pelo abdome (peito passa para fora e abaixo da barra)")
	t.check(worst_knee < 35.0, "debruçado, as pernas ficam esticadas (sem dobrar o joelho)", "%.0f graus" % worst_knee)
	t.check(hips_end.y < 0.5 and out.dot(hips_end - bar) > 0.3, "cai da torre para o pátio", str(hips_end))
	t.check(not early_drop and landed_at > 0.0, "o fuzil e o cartão só aparecem depois que o corpo chega ao chão", "%.2f s" % landed_at)
	var rifles := t.get_nodes_in_group("pickups").filter(func(pk: Pickup) -> bool: return pk.is_drop and pk.kind == "sniper")
	t.check(rifles.size() == 1 and (rifles[0] as Pickup).global_position.distance_to(hips_end) < 1.6, "o fuzil do que caiu fica no chão do lado dele", str(rifles.size()))
	t.check(card.global_position.y < 0.3 and card.global_position.distance_to(hips_end) < 1.6, "o cartão fica no chão do lado do corpo", str(card.global_position))
	t.check(last.model.holstered, "o fuzil saiu da mão dele quando parou")
	var tw: GuardTower = main.towers[0]
	var flat := Vector2(card.global_position.x - tw.global_position.x, card.global_position.z - tw.global_position.z)
	t.check(maxf(absf(flat.x), absf(flat.y)) > GuardTower.SIZE * 0.5, "fora da base da torre (dá para pegar)", str(flat))
	# ela pega o cartão: tela do item
	main.inspect.auto_close = 0.0
	var seen := {"title": ""}
	main.inspect.on_shown = func() -> void: seen.title = main.inspect._title.text
	await t._frames(int(KeyItem.FALL_TIME * 60) + 5)
	p.global_position = card.global_position + Vector3(0.4, 0, 0)
	p.reset_physics_interpolation()
	await t._frames(3)
	t.check(p.pick_key() == card, "chegando perto, pode pegar o cartão")
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	while main.inspect.busy:
		await t.process_frame
	t.check(p.has_key(Yard.GATE_KEY) and seen.title.ends_with("CARTÃO DO PAINEL"), "E pega o cartão do painel", seen.title)
	# R: tudo de volta
	main.inspect.on_shown = Callable()
	main.inspect.auto_close = -1.0
	main.reset_all()
	await t._frames(3)
	t.check(card.state == "hidden" and not p.has_key(Yard.GATE_KEY), "R: o cartão volta a ficar escondido")
	t.check(snipers.all(func(s: Sniper) -> bool: return s.lurking and not s.dead and not s.falls and s.loot == null and not s.model.is_ragdoll()),
		"R: snipers vivos fora de cena, ninguém com o cartão")
	var rb: Dictionary = last.model.ragdoll.bodies
	var swing := float(rb["Spine"].get("joint_constraints/swing_span"))
	var knee := float(rb["LowerLeg_L"].get("joint_constraints/angular_limit_upper"))
	t.check(absf(swing - float(Ragdoll.BONES["Spine"].swing)) < 0.01 and absf(knee - float(Ragdoll.BONES["LowerLeg_L"].upper)) < 0.01 and absf(rb["Chest"].angular_damp - 2.0) < 0.01,
		"R: o ragdoll dele volta ao normal (juntas e amortecimento)", "%s %s" % [swing, knee])
	main.queue_free()
	await t._frames(2)
