extends RefCounted
## Testes do alossauro e da pedreira (última sala), chamados por run_tests.gd (usa check/_fresh_world/_frames de lá).
## Alossauro na origem olhando para +Z; a heroína é posta na frente (+Z) dele.

const EXPECTED_ANIMS := [
	"Idle", "Walk", "Run", "Roar", "RoarAt", "Study", "Stomp", "Bite", "Shake", "Throw", "Hit",
	"Headbutt", "HeadbuttR", "TailWhip", "TailWhipR", "HopL", "HopR",
]

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_asset()
	await test_roar_dazes()
	await test_roar_out_of_range()
	await test_hit_ends_daze()
	await test_roar_at_front_only()
	await test_headbutt_side()
	await test_tail_behind()
	await test_stomp()
	await test_roll_dodges_stomp()
	await test_bite_grab_throw()
	await test_shot_never_interrupts()
	await test_hardened()
	await test_hop_faces_her()
	await test_hop_dodges_aim()
	await test_death_and_reset()
	await test_arena()
	await test_end_screen()


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func _pair(player_pos: Vector3, facing_away := false) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	if facing_away:
		p.rotation.y = PI
	w.add_child(p)
	var a := Allosaurus.new()
	a.rotation.y = PI
	a.target = p
	w.add_child(a)
	a.rng.seed = 7
	await t._frames(2)
	return [p, a, w]


## Espera até `cond` virar verdade (no máximo `frames` quadros de física).
func _until(cond: Callable, frames: int) -> bool:
	for i in frames:
		if cond.call():
			return true
		await t._frames(1)
	return cond.call()


func test_asset() -> void:
	var scene: PackedScene = load("res://assets/characters/allosaurus.glb")
	check(scene != null, "allosaurus.glb carrega")
	var inst := scene.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	check(sk.get_bone_count() == 25, "alossauro: mesmos 25 ossos do raptor", str(sk.get_bone_count()))
	for b in ["Jaw", "Head", "Tail4", "Toe_R", "Hand_L"]:
		check(sk.find_bone(b) >= 0, "alossauro: osso " + b)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for anim in EXPECTED_ANIMS:
		check(ap.has_animation(anim) and ap.get_animation(anim).length > 0.1, "alossauro: animação " + anim)
	var tris := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	# chefe: cabeça e corpo medidos na referência (crânio, mandíbula, dentes, membros com 12 lados) = teto próprio
	check(tris > 800 and tris < 12000, "alossauro: orçamento de triângulos do chefe (800-12000)", str(tris))
	check(inst.find_child("Mouth", true, false) != null, "alossauro: marcador da boca (Mouth)")
	var atlas: Texture2D = load("res://assets/characters/allosaurus_atlas.png")
	check(atlas != null and atlas.get_width() == 1024 and atlas.get_height() == 1024, "alossauro: atlas 1024x1024 (chefe)")
	inst.free()
	var heroine: Node = (load("res://assets/characters/heroine.glb") as PackedScene).instantiate()
	var hap: AnimationPlayer = heroine.find_children("*", "AnimationPlayer", true, false)[0]
	check(hap.has_animation("Dazed"), "heroína: animação de atordoada (Dazed)")
	heroine.free()


func test_roar_dazes() -> void:
	var pr := await _pair(Vector3(0, 0, 9))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_roar()
	var dazed := await _until(func() -> bool: return p.is_dazed(), 70)
	check(dazed, "rugido atordoa quem está perto (%.0f m)" % 9.0)
	await t._frames(2)
	check(p.model.state == "dazed", "atordoada: animação das mãos nos ouvidos", p.model.state)
	var before := p.global_position
	Input.action_press("move_forward")
	await t._frames(40)
	Input.action_release("move_forward")
	check(p.global_position.distance_to(before) < 0.1, "atordoada não anda", "%.2f m" % p.global_position.distance_to(before))
	check(p.health == 100, "rugido não fere", str(p.health))
	await t._frames(int(Allosaurus.DAZE_TIME * 60.0) - 30)
	check(not p.is_dazed(), "atordoada por %.0f s e passa" % Allosaurus.DAZE_TIME)


func test_roar_out_of_range() -> void:
	var pr := await _pair(Vector3(0, 0, Allosaurus.ROAR_RANGE + 6.0))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_roar()
	await t._frames(70)
	check(not p.is_dazed(), "longe do rugido não atordoa")


func test_hit_ends_daze() -> void:
	var pr := await _pair(Vector3(0, 0, 9))
	var p: Player = pr[0]
	p.daze(3.0)
	p.knockback(Vector3(0, 0, 5))
	check(not p.is_dazed(), "golpe tira do atordoamento")
	p.daze(3.0)
	p.grab(pr[1])
	check(not p.is_dazed(), "mordida tira do atordoamento")
	p.release(Vector3.ZERO)


func test_roar_at_front_only() -> void:
	var pr := await _pair(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_roar_at()
	check(a.model.current == "RoarAt", "rugido na batalha: abaixado, voltado para ela", a.model.current)
	var dazed := await _until(func() -> bool: return p.is_dazed(), 50)
	check(dazed, "rugido direcionado atordoa quem está na frente")
	var pr2 := await _pair(Vector3(0, 0, -8))
	var p2: Player = pr2[0]
	var a2: Allosaurus = pr2[1]
	a2.start_roar_at()
	await t._frames(50)
	check(not p2.is_dazed(), "rugido direcionado não pega quem está atrás/de lado")


func test_headbutt_side() -> void:
	# ela do lado esquerdo dele (olhando para +Z, a esquerda dele é +X), perto da cabeça
	var pr := await _pair(Vector3(2.2, 0, 2.2))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.choose_attack()
	check(a.state == "headbutt" and a.model.current == "Headbutt", "do lado da cabeça: cabeçada para esse lado", a.state)
	var hit := await _until(func() -> bool: return p.health < 100, 40)
	check(hit and p.health == 100 - Allosaurus.DAMAGE.headbutt, "cabeçada fere", str(p.health))
	check(p.model.is_ragdoll(), "cabeçada derruba")
	await t._frames(20)
	check(p.model.ragdoll.bodies["Hips"].global_position.x > 3.0, "derrubada para o lado do golpe",
		"%.2f" % p.model.ragdoll.bodies["Hips"].global_position.x)


func test_tail_behind() -> void:
	var pr := await _pair(Vector3(1.5, 0, -4.5))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.choose_attack()
	check(a.state == "tail", "ela atrás dele: rabada", a.state)
	var hit := await _until(func() -> bool: return p.health < 100, 60)
	check(hit and p.health == 100 - Allosaurus.DAMAGE.tail, "rabada fere", str(p.health))
	check(p.model.is_ragdoll(), "rabada arremessa")


func test_stomp() -> void:
	var pr := await _pair(Vector3(0, 0, 2.6))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_stomp()
	await t._frames(int(Allosaurus.STOMP_HIT * 60.0) + 10)
	check(p.health == 100 - Allosaurus.DAMAGE.stomp, "pisada fere", str(p.health))
	check(p.model.is_ragdoll() and p.is_dodging(), "pisada arremessa e derruba")
	await t._frames(150)
	check(not p.model.is_ragdoll() and t._body_ok(p.model).finite, "levanta depois da pisada")


func test_roll_dodges_stomp() -> void:
	var pr := await _pair(Vector3(0, 0, 2.6), true)
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_stomp()
	await t._frames(26)
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	await t._frames(40)
	check(p.health == 100, "rolar esquiva da pisada", "vida=%d" % p.health)


func test_bite_grab_throw() -> void:
	var pr := await _pair(Vector3(0, 0, 4.2))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	a.start_bite()
	var got := await _until(func() -> bool: return p.grabbed, 60)
	check(got and p.grabber == a and a.state == "hold", "mordida agarra", a.state)
	check(a.model.current == "Shake", "animação de sacudir", a.model.current)
	await t._frames(20)
	var waist: PhysicalBone3D = p.model.ragdoll.bodies[a.grab_bone]
	check(waist.global_position.distance_to(a.model.mouth_position()) < 0.6, "agarrada pelo corpo (cintura na boca dele)",
		"%.2f m" % waist.global_position.distance_to(a.model.mouth_position()))
	var arm: PhysicalBone3D = p.model.ragdoll.bodies[Player.BITTEN_BONE]
	# a boca segura a cintura, não o braço: a cintura fica mais perto da boca que o antebraço (a distância absoluta
	# depende do comprimento do braço de cada corpo)
	var arm_d := arm.global_position.distance_to(a.model.mouth_position())
	var waist_d := waist.global_position.distance_to(a.model.mouth_position())
	check(arm_d > waist_d + 0.05, "não é pelo braço (como o raptor)", "antebraço %.2f m, cintura %.2f m" % [arm_d, waist_d])
	var released := await _until(func() -> bool: return not p.grabbed, 150)
	check(released and a.state in ["throw", "recover"], "solta arremessando", a.state)
	check(p.health < 100 - Allosaurus.DAMAGE.throw, "sacudida e arremesso tiram vida", str(p.health))
	var mouth := a.model.mouth_position()
	await t._frames(40)
	var hips: Vector3 = p.model.ragdoll.bodies["Hips"].global_position
	# esquerda dele (olhando para +Z) = +X do mundo
	check(hips.x - mouth.x > 1.5, "arremessada para o lado (esquerda dele)", "%.2f m" % (hips.x - mouth.x))
	check(t._body_ok(p.model).finite, "ragdoll arremessado sem NaN")
	a.process_mode = Node.PROCESS_MODE_DISABLED  # senão ele volta a atacar e a derruba de novo
	var up := await _until(func() -> bool: return not p.model.is_ragdoll() and not p.is_dodging(), 400)
	check(up, "levanta depois do arremesso")


func test_shot_never_interrupts() -> void:
	var pr := await _pair(Vector3(0, 0, 12))
	var a: Allosaurus = pr[1]
	a.start_stalk()
	for i in ceili(float(Allosaurus.GROWL_DAMAGE) / Player.DAMAGE) + 1:
		a.take_hit(Player.DAMAGE, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	check(not a.dead and a.state == "stalk", "dano acumulado não faz o alossauro parar", a.state)


## Casco (HARDENED): o tiro de verdade (Player._pellet_hit, a parte achada pelo ragdoll que acompanha a animação) tira
## o dano cheio nas costelas e quase nada na cabeça, no pescoço, nas pernas e na cauda; a mira escreve HARDENED nelas.
func test_hardened() -> void:
	var pr := await _pair(Vector3(8, 0, 2))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	await t._frames(5)
	var stats := p.weapon_stats("pistol")
	var shot := func(bone: String) -> Dictionary:
		var pt: Vector3 = a.model.ragdoll.bodies[bone].global_position
		var side := a.global_basis.x  # de lado, de fora para dentro
		var hits := {}
		p._pellet_hit({"collider": a, "position": pt + side * 1.0, "normal": side}, -side, stats, hits)
		var part := p.body_part(a, pt + side * 1.0, -side)
		return {"damage": hits[a].damage if hits.has(a) else 0, "part": part}
	var full := int(stats.damage)
	for bone in ["Spine", "Chest"]:
		var r: Dictionary = shot.call(bone)
		check(r.part in Allosaurus.RIBS and r.damage >= full * 0.9, "costelas (%s): dano cheio" % bone, str(r))
		check(a.armor_tag(r.part) == "", "costelas: o tiro não marca casco", r.part)
	for bone in ["Head", "Neck1", "Thigh_L", "Shin_R", "Tail1", "Tail2", "Tail4"]:
		var r: Dictionary = shot.call(bone)
		check(not r.part in Allosaurus.RIBS and r.damage <= maxi(1, roundi(full * Allosaurus.HARDENED_MULT)),
			"casco (%s): dano ridículo" % bone, str(r))
		check(a.armor_tag(r.part) == Allosaurus.HARDENED_TEXT, "casco (%s): o tiro marca HARDENED" % bone, r.part)
	check(not Player._has_headshot(a), "cabeça de casco: sem headshot")
	# a granada não passa pelo casco: dano cheio chamado direto
	var hp := a.health
	a.take_hit(60, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	check(hp - a.health == 60, "explosão/golpe direto: sem desconto do casco", str(hp - a.health))


## Ela fora da frente dele (sem estar atrás): pulinho de lado que termina de frente para ela; no ar os pés soltam.
func test_hop_faces_her() -> void:
	# alossauro olhando para +Z; ela à esquerda dele (+X), ~56° fora da frente, a 7 m
	var pr := await _pair(Vector3(6, 0, 4))
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	var start := a.global_position
	a.start_stalk()
	var hopped := await _until(func() -> bool: return a.state == "hop", 10)
	check(hopped and a.model.current == "HopL", "ela do lado: pulinho para o lado dela", "%s %s" % [a.state, a.model.current])
	var air := await _until(func() -> bool: return a.airborne, 30)
	check(air and not a.model.feet.grounded, "no ar: pés soltos da animação (FootPlant)")
	await _until(func() -> bool: return a.state != "hop", 90)
	var to := a._to_target()
	var off := absf(angle_difference(a.rotation.y, atan2(-to.x, -to.z)))
	check(rad_to_deg(off) < 15.0, "depois do pulinho está de frente para ela", "%.0f°" % rad_to_deg(off))
	var moved := Enemy._flat(a.global_position - start).length()
	check(moved > Allosaurus.HOP_DIST * 0.7 and moved < Allosaurus.HOP_DIST * 1.6, "pulinho leva ~2 m de lado", "%.2f m" % moved)
	check(not a.airborne and a.model.feet.grounded, "pousou: pés presos de novo")
	check(a._hop_cd > 0.0 and a.state != "hop", "não emenda outro pulinho na hora")
	p.global_position = a.global_position + Vector3(0, 0, 9)


## Ela de frente mirando nele: de vez em quando o pulinho vira esquiva (sai da linha de tiro e continua de frente).
func test_hop_dodges_aim() -> void:
	var pr := await _pair(Vector3(0, 0, 12), true)
	var p: Player = pr[0]
	var a: Allosaurus = pr[1]
	var spot := a.global_position
	p.rotation.y = 0.0  # ela olhando para -Z, para ele
	p.aiming = true
	check(a._aimed_at(), "ela de frente com a arma apontada = mirando nele")
	Input.action_press("aim")
	a.start_stalk()
	var seen := {"aimed": true}
	var dodged := await _until(func() -> bool:
		if a.state == "hop":
			return true
		# segura os dois no lugar (ele não chega à distância da mordida nem escolhe golpe; ela não gira com a câmera)
		a.global_position = spot
		a._t = 0.0
		p.camera_rig.look_at_point(spot + Vector3.UP * 2.0)
		seen.aimed = a._aimed_at()
		return false, 360)
	Input.action_release("aim")
	check(dodged, "mirando nele: pulinho de esquiva", "%s mirando=%s" % [a.state, seen.aimed])
	p.aiming = false
	p.rotation.y = PI
	check(not a._aimed_at(), "de costas para ele: não está mirando nele")


func test_death_and_reset() -> void:
	var pr := await _pair(Vector3(0, 0, 8))
	var a: Allosaurus = pr[1]
	var kills := [0]
	a.killed.connect(func() -> void: kills[0] += 1)
	a.take_hit(Allosaurus.MAX_HEALTH, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	await t._frames(60)
	check(a.dead and kills[0] == 1, "morre e avisa (sinal killed)")
	var finite := true
	for b: PhysicalBone3D in a.model.ragdoll.bodies.values():
		finite = finite and b.global_position.is_finite()
	check(a.model.is_ragdoll() and finite, "morte em ragdoll sem NaN")
	var hips: Vector3 = a.model.ragdoll.bodies["Hips"].global_position
	check(hips.y < 1.4, "corpo tomba (quadril em pé a 1,93 m)", "%.2f" % hips.y)
	a.reset()
	await t._frames(2)
	check(not a.dead and a.health == Allosaurus.MAX_HEALTH and not a.model.is_ragdoll(), "reinicia vivo, sem ragdoll")


func test_arena() -> void:
	var w: Node3D = await t._fresh_world()
	for c in w.get_children():
		c.free()
	Level.build(w)
	Yard.bake_nav(w)
	var map := w.get_world_3d().navigation_map
	# a sincronização do mapa roda em outra thread: espera por relógio (como em ai_tests.test_yard_nav)
	var probe: Vector3 = Arena.ALLO.pos
	var until := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < until and NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) > 0.5:
		await t._frames(1)
	check(NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) <= 0.5, "malha de navegação da pedreira sincronizada")
	var space := w.get_world_3d().direct_space_state
	var gz: float = Yard.ROAD[Yard.ROAD.size() - 1].y
	var through := PhysicsRayQueryParameters3D.create(Vector3(-52, 1.0, gz), Vector3(-62, 1.0, gz), 1)
	check(not space.intersect_ray(through).is_empty(), "portão do pátio começa fechado")
	for d: Door in w.get_tree().get_nodes_in_group("doors"):
		d.open()
	await t._frames(3)
	check(space.intersect_ray(through).is_empty(), "portão do pátio aberto para a pedreira")
	var beside := PhysicsRayQueryParameters3D.create(Vector3(-52, 1.0, gz + 5.0), Vector3(-62, 1.0, gz + 5.0), 1)
	check(not space.intersect_ray(beside).is_empty(), "do lado do portão continua fechado")
	for post in Arena.POSTS + [Arena.ALLO]:
		for pt: Vector3 in post.route:
			var q := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.9
			q.shape = sphere
			q.transform = Transform3D(Basis(), pt + Vector3.UP * 1.4)
			q.collision_mask = 1
			check(space.intersect_shape(q).is_empty(), "rota da pedreira em chão livre", str(pt))
	var path := NavigationServer3D.map_get_path(map, Yard.POSTS[0].pos, Arena.ALLO.pos, true)
	check(path.size() > 1 and path[path.size() - 1].distance_to(Arena.ALLO.pos) < 1.5, "caminho do pátio até a pedreira",
		str(path[path.size() - 1]) if path.size() > 0 else "vazio")


func test_end_screen() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t.process_frame
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(3)
	var a: Allosaurus = main.allosaurus
	check(a != null and a.global_position.x < Arena.X_NEAR, "cena principal: alossauro na pedreira", str(a.global_position) if a else "-")
	check(main.raptors.size() == Yard.POSTS.size() + Arena.POSTS.size() + Yard.WAVES.reduce(func(n: int, w: Dictionary) -> int: return n + w.entries.size(), 0) + Yard.CLIFF_RAPTORS.size(), "cena principal: raptors do pátio (trilha) e da pedreira", str(main.raptors.size()))
	check(not main.ended and not main.game_over, "jogo começa sem a tela de fim ou game over")
	a.take_hit(Allosaurus.MAX_HEALTH, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	await t._frames(int((main.END_DELAY + 0.3) * 60.0))
	var title: Label = main._end.get_node("Title")
	var shade: ColorRect = main._end.get_node("Shade")
	check(main.ended and main._end.visible and title.text == "FIM" and not shade.visible, "alossauro morto: tela de fim")
	main.reset_all()
	await t._frames(2)
	check(not main.ended and not main._end.visible and not a.dead, "R reinicia: sem tela de fim, alossauro vivo")
	# Morte da heroína -> atraso para ver o ragdoll cair -> tela de Game Over -> recomeçar com E / Espaço / R
	var p: Player = main.player
	p.shots_fired = 7
	p.take_hit(999, Vector3.BACK, p.global_position + Vector3.UP * 1.2)
	await t._frames(10)
	check(p.dead and not main.game_over and not main._end.visible, "morte: espera o corpo cair antes do Game Over")
	await t._frames(int((main.GAME_OVER_DELAY + 0.2) * 60.0))
	check(main.game_over and main._end.visible and title.text == "GAME OVER" and shade.visible, "após GAME_OVER_DELAY: tela de Game Over visível com fundo avermelhado", title.text)
	check("VOCÊ MORREU" in main._end_stats.text and "TIROS 7" in main._end_stats.text, "tela de Game Over mostra VOCE MORREU e estatísticas", main._end_stats.text)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(2)
	check(not main.game_over and not main._end.visible and not p.dead and p.health == 100 and p.shots_fired == 0, "apertar E (interact) na tela de Game Over recomeça a partida")
	# Morrer de novo e recomeçar com o X do controle (agachar, RESTART_ACTIONS)
	p.take_hit(999, Vector3.BACK, p.global_position + Vector3.UP * 1.2)
	await t._frames(int((main.GAME_OVER_DELAY + 0.3) * 60.0))
	check(main.game_over and main._end.visible, "segunda morte mostra Game Over novamente")
	Input.action_press("crouch")
	await t._frames(2)
	Input.action_release("crouch")
	await t._frames(2)
	check(not main.game_over and not p.dead and p.health == 100 and not p.rolling and not p.crouching,
		"apertar X (agachar) na tela de Game Over recomeça sem sair agachada nem rolando",
		"game_over %s, morta %s, vida %d, rolando %s, agachada %s" % [main.game_over, p.dead, p.health, p.rolling, p.crouching])
	main.queue_free()
	await t.process_frame
