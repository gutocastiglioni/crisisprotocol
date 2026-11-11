extends RefCounted
## Testes das torres de guarda do portão do pátio (GuardTower, Yard.TOWERS), dos snipers delas (fora de cena até os 3
## raptors da emboscada morrerem), da queda do último (cambaleia até a cerca, debruça no abdome e cai) com o fuzil e o
## cartão do painel do portão só depois que o corpo para, da rendição (os 3 raptors mortos: cena, lasers nela, rendida até
## se mexer; rolar = tiros que erram, mirar = tiros que acertam, depois a mira de 5 s) e da chave da M79 com a etiqueta
## "0M79". Chamado por
## run_tests.gd (usa check/_frames de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_m79_key_tag()
	await test_towers_and_hidden_snipers()
	await test_last_sniper_falls_with_card()
	await test_no_shot_from_roof_or_offstage()
	await test_standoff()
	await test_tower_zone()


func _main() -> Node:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	return main


func _kill_yard_raptors(main: Node, standoff := false) -> void:
	main.corpse.armed = false  # como no jogo: os 3 só morrem depois da emboscada (perto do morto a cena não toca de novo)
	main.standoff_armed = standoff  # a rendição só no teste dela
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
	# dois raptors mortos: ainda não; o terceiro: sobem nas torres (como no jogo, depois da emboscada: perto do morto a cena
	# não toca de novo, e numa cena ninguém a vê)
	main.corpse.armed = false
	main.standoff_armed = false  # a rendição tem o teste dela (test_standoff)
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


## Sniper fora de cena (invisível, mas o ragdoll segue a animação) não vira alvo nem leva tiro; do telhado (onde
## ninguém a percebe) ela também não alcança ninguém, nem com eles em cena. Da estrada, sim.
func test_no_shot_from_roof_or_offstage() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var s: Sniper = main.tower_snipers[0]
	main.smelled = true  # o aviso do cheiro na beira oeste pausaria o jogo
	var aim_at := func(at: Vector3) -> Dictionary:
		p.global_position = at
		p.reset_physics_interpolation()
		p.camera_rig._snapped = false  # a câmera vai direto para ela (senão vem deslizando de onde estava)
		await t._frames(5)
		var best := {}
		for i in 20:  # ele se mexe: mira no peito de novo a cada quadro e guarda o que a mira pegou
			p.camera_rig.look_at_point(s.model.ragdoll.bodies["Chest"].global_position)
			await t._frames(1)
			best = p.aim_target_info()
			if best.target == s:
				break
		return best
	Input.action_press("aim")
	var roof_edge := Vector3(-Roof.EDGE + 1.0, Roof.Y, clampf(s.global_position.z, -Roof.EDGE + 1.0, Roof.EDGE - 1.0))
	t.check(Roof.has(roof_edge), "ponto de teste na beira oeste do telhado")
	var info: Dictionary = await aim_at.call(roof_edge)
	t.check(info.target != s, "sniper fora de cena: a mira não acusa nada", str(info))
	# sem a regra do telhado (ela fora da laje, mas a câmera no mesmo lugar) a mira pega o ragdoll dele: a linha está livre
	var ray: Array = p.camera_rig.aim_ray()
	var space := t.get_root().get_world_3d().direct_space_state
	var own: Array[RID] = [p.get_rid()]
	own.append_array(p.model.ragdoll.body_rids())
	var bare := space.intersect_ray(PhysicsRayQueryParameters3D.create(ray[0], ray[0] + ray[1] * 80.0, Player.SHOT_MASK, own))
	t.check(bare and bare.collider is PhysicalBone3D and Ragdoll.owner_of(bare.collider) == s,
		"do telhado a linha até o sniper está livre (o teste mira de verdade)", str(bare.get("collider")))
	var hp := s.health
	p.fire()
	await t._frames(2)
	t.check(s.health == hp and not s.dead, "sniper fora de cena não leva tiro", "vida=%d" % s.health)
	_kill_yard_raptors(main)
	await t._frames(3)
	t.check(not s.lurking, "com os raptors mortos ele aparece")
	info = await aim_at.call(roof_edge)
	t.check(info.target != s, "do telhado a mira não pega o sniper em cena", str(info))
	await t._frames(int(Player.SHOT_COOLDOWN * 60) + 5)
	p.fire()
	await t._frames(2)
	t.check(s.health == hp and not s.dead, "do telhado o tiro não chega nele", "vida=%d" % s.health)
	# da estrada, a uns 10 m da torre: mira e tiro valem
	info = await aim_at.call(Vector3(main.towers[0].global_position.x + 10.0, 0, s.global_position.z))
	t.check(info.target == s, "da estrada a mira pega o sniper", str(info))
	Input.action_release("aim")
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


## Os 3 raptors da emboscada mortos com ela no pátio: a cena da rendição (os dois lasers nela, mãos ao alto, as três
## falas) e depois ela rendida, sem perigo no sensor e sem tiro; andando devagar de mãos ao alto, os lasers a seguem.
## Rolar: os dois atiram na hora e erram; a mira seguinte leva Sniper.STANDOFF_LOCK s, com o sensor enchendo nesse
## tempo. Mirar ou correr: os dois atiram na hora e acertam. R arma a cena de novo.
func test_standoff() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var cs: Cutscene = main.cutscene
	var snipers: Array[Sniper] = main.tower_snipers
	p.health = 100000  # os tiros dos snipers não a matam aqui
	await _to_yard(main, p)
	_kill_yard_raptors(main, true)
	await t._frames(int(main.STANDOFF_DELAY * 60) - 20)
	t.check(not cs.busy and snipers.all(func(s: Sniper) -> bool: return not s.lurking), "os snipers sobem; a cena espera um instante")
	var started := false
	for i in 60:
		await t._frames(1)
		if cs.busy:
			started = true
			break
	t.check(started and cs.scene == "standoff" and p.cutscene, "com os 3 mortos e ela no pátio: a cena da rendição", cs.scene)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.in_standoff()), "os dois a pegam na mira")
	var lines := {}
	var crossed := false
	var hands := false
	while cs.busy:
		await t._frames(1)
		if cs._sub.visible:
			lines[cs._sub.text] = true
		if cs.t > Cutscene.STAND_CLOSE_AT and snipers.all(func(s: Sniper) -> bool: return s.laser.visible and s.laser.end.distance_to(p.sight_point()) < 0.3):
			crossed = true
		if cs.t > Cutscene.STAND_HANDS_AT + 0.1 and p.model.state in ["surrender", "surrender_hold"]:
			hands = true
	t.check(crossed, "os dois lasers chegam ao peito dela (cruzando nela)")
	t.check(hands, "ela levanta as mãos (Surrender)")
	t.check(Cutscene.STAND_LINES.all(func(l: String) -> bool: return lines.has(l)), "as três falas", str(lines.keys()))
	await t._frames(2)
	t.check(p.surrendered and not p.cutscene and p.model.state == "surrender_hold" and p.model.holstered, "no fim: rendida, mãos ao alto, sem arma na mão", p.model.state)
	var hp := p.health
	await t._frames(120)
	t.check(p.surrendered and p.health == hp and snipers.all(func(s: Sniper) -> bool: return s.in_standoff() and s.shots_fired == 0 and s.laser.visible),
		"parada, ninguém atira e os lasers seguem nela")
	var early := DangerMeter.sample(t.get_root().get_tree())
	t.check(early > 0.05 and early < 0.25, "rendida: o perigo começa a crescer devagar (15 s até o tiro)", "%.2f" % early)
	# rolar: os dois atiram na hora e erram; depois a mira de 5 s
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	await t._frames(1)
	t.check(not p.surrendered and p.rolling, "rolar acaba com a rendição")
	t.check(snipers.all(func(s: Sniper) -> bool: return s.shots_fired == 1) and p.health == hp, "os dois atiram na hora e erram (rolando)",
		"%s %d" % [snipers.map(func(s: Sniper) -> int: return s.shots_fired), hp - p.health])
	t.check(snipers.all(func(s: Sniper) -> bool: return s.state == "aim_lock" and is_equal_approx(s._lock_time, Sniper.STANDOFF_LOCK)),
		"e miram de novo, devagar", str(snipers.map(func(s: Sniper) -> String: return s.state)))
	await t._frames(150)
	var mid := DangerMeter.sample(t.get_root().get_tree())
	t.check(mid > 0.25 and mid < 0.75 and snipers.all(func(s: Sniper) -> bool: return s.shots_fired == 1),
		"na metade da mira lenta o sensor está pela metade e ninguém atirou", "%.2f" % mid)
	var shot_at := -1.0
	for i in 240:
		await t._frames(1)
		if snipers.any(func(s: Sniper) -> bool: return s.shots_fired > 1):
			shot_at = (150 + i + 3) / 60.0
			break
	t.check(shot_at > Sniper.STANDOFF_LOCK - 0.5 and shot_at < Sniper.STANDOFF_LOCK + 0.8, "o tiro seguinte sai uns 5 s depois de ela se mexer", "%.2f s" % shot_at)
	await t._frames(30)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.state != "aim_lock" or is_equal_approx(s._lock_time, Sniper.AIM_LOCK_TIME)), "depois, o ritmo de sempre")
	# R: a cena arma de novo; desta vez ela mira (a cena é pulada)
	main.reset_all()
	await t._frames(3)
	t.check(main.standoff_armed and not p.surrendered and snipers.all(func(s: Sniper) -> bool: return s.lurking), "R: rendição armada de novo, ela livre")
	p.health = 100000
	hp = p.health
	await _surrendered(main, p)
	t.check(p.surrendered and snipers.all(func(s: Sniper) -> bool: return s.in_standoff() and s.laser.visible), "pulando a cena: rendida e os lasers já acesos")
	var fired: Array = snipers.map(func(s: Sniper) -> int: return s.shots_fired)
	Input.action_press("aim")
	await t._frames(3)
	Input.action_release("aim")
	await t._frames(1)
	t.check(not p.surrendered and snipers.all(func(s: Sniper) -> bool: return s.shots_fired == fired[snipers.find(s)] + 1) and p.health < hp, "mirar: os dois atiram na hora e acertam", str(hp - p.health))
	# R de novo; desta vez ela anda devagar (os lasers a seguem) e depois corre (os dois acertam)
	main.reset_all()
	await t._frames(3)
	p.health = 100000
	hp = p.health
	await _surrendered(main, p)
	fired = snipers.map(func(s: Sniper) -> int: return s.shots_fired)
	var walk_btn := "walk_slow" if GameMode.sprint() else "walk"
	var from := p.global_position
	Input.action_press(walk_btn)
	Input.action_press("move_left")
	var followed := true
	for i in 60:
		await t._frames(1)
		followed = followed and snipers.all(func(s: Sniper) -> bool: return s.laser.visible and s.laser.end.distance_to(p.sight_point()) < 0.45)
	var walked := p.global_position.distance_to(from)
	t.check(p.surrendered and p.model.hands_up and p.model.state == "walk" and walked > 0.5, "rendida, anda devagar de mãos ao alto", "%.2f m %s" % [walked, p.model.state])
	t.check(followed and snipers.all(func(s: Sniper) -> bool: return s.in_standoff() and s.shots_fired == fired[snipers.find(s)]) and p.health == hp,
		"andando devagar: os lasers a seguem e ninguém atira")
	t.check(DangerMeter.sample(t.get_root().get_tree()) < 0.25, "andando devagar: o perigo segue crescendo devagar")
	Input.action_release(walk_btn)
	await t._frames(3)
	Input.action_release("move_left")
	await t._frames(1)
	t.check(not p.surrendered and snipers.all(func(s: Sniper) -> bool: return s.shots_fired == fired[snipers.find(s)] + 1) and p.health < hp,
		"correr: os dois atiram na hora e acertam", "%s %d" % [snipers.map(func(s: Sniper) -> int: return s.shots_fired), hp - p.health])
	t.check(snipers.all(func(s: Sniper) -> bool: return s.state == "aim_lock" and is_equal_approx(s._lock_time, Sniper.STANDOFF_LOCK)), "e depois a mira lenta")
	# R de novo; desta vez ela fica parada na mira: o perigo enche em 15 s e eles atiram
	main.reset_all()
	await t._frames(3)
	p.health = 100000
	hp = p.health
	await _surrendered(main, p)
	fired = snipers.map(func(s: Sniper) -> int: return s.shots_fired)
	await t._frames(int(Sniper.STANDOFF_TIMEOUT * 30))
	var half := DangerMeter.sample(t.get_root().get_tree())
	t.check(p.surrendered and half > 0.35 and half < 0.65 and p.health == hp, "na metade dos 15 s o perigo está pela metade", "%.2f" % half)
	var timed_out := -1.0
	for i in int(Sniper.STANDOFF_TIMEOUT * 30) + 60:
		await t._frames(1)
		if snipers.any(func(s: Sniper) -> bool: return s.shots_fired > fired[snipers.find(s)]):
			timed_out = Sniper.STANDOFF_TIMEOUT * 0.5 + (i + 1) / 60.0
			break
	await t._frames(2)
	t.check(timed_out > Sniper.STANDOFF_TIMEOUT - 0.5 and timed_out < Sniper.STANDOFF_TIMEOUT + 0.5 and not p.surrendered and p.health < hp,
		"15 s na mira: os dois atiram e acertam", "%.2f s %d" % [timed_out, hp - p.health])
	main.queue_free()
	await t._frames(2)


## Ela na estrada do pátio, de frente para o portão (perto do morto: a emboscada já passou).
func _to_yard(main: Node, p: Player) -> void:
	main.corpse.armed = false
	p.global_position = Vector3(-43.0, 0, -4.0)
	p.rotation.y = PI * 0.5
	p.reset_physics_interpolation()
	await t._frames(3)


## Os 3 raptors mortos, a cena da rendição pulada: ela rendida na mira dos dois.
func _surrendered(main: Node, p: Player) -> void:
	await _to_yard(main, p)
	_kill_yard_raptors(main, true)
	for i in 150:
		await t._frames(1)
		if main.cutscene.busy:
			break
	main.cutscene.stop()
	await t._frames(2)


## Snipers das torres de Flak Jacket; embaixo da plataforma da torre ela não fica escondida (a torre não tapa a vista, o
## tiro nem o laser deles) e perto demais do portão do fundo ou das torres eles a veem e atiram.
func test_tower_zone() -> void:
	var main: Node = await _main()
	var p: Player = main.player
	var snipers: Array[Sniper] = main.tower_snipers
	_kill_yard_raptors(main)
	await t._frames(3)
	t.check(snipers.all(func(s: Sniper) -> bool: return s.flak and is_equal_approx(s.armor, Soldier.FLAK_MULT) and s.armor_name == Soldier.FLAK_TEXT),
		"snipers das torres de Flak Jacket")
	t.check(not main.sniper.flak and main.sniper.armor_name == "", "o do mezanino segue de colete comum")
	t.check(not main.in_tower_zone(Vector3(-43.0, 0, -4.0)), "da estrada: longe do portão")
	p.health = 100000
	var hp := p.health
	p.global_position = main.towers[0].global_position + Vector3(0.5, 0, 0.4)
	p.reset_physics_interpolation()
	await t._frames(3)
	t.check(main.in_tower_zone(p.global_position), "embaixo da torre: perto demais")
	t.check(snipers.all(func(s: Sniper) -> bool: return s._line_clear(p)), "embaixo da plataforma ela não fica escondida (sem ponto cego)")
	var shot := false
	for i in 240:
		await t._frames(1)
		if snipers.any(func(s: Sniper) -> bool: return s.shots_fired > 0) and p.health < hp:
			shot = true
			break
	t.check(shot, "perto demais do portão/torres: eles atiram e acertam", str(snipers.map(func(s: Sniper) -> String: return s.state)))
	main.queue_free()
	await t._frames(2)

