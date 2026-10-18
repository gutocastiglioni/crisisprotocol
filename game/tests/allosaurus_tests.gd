extends RefCounted
## Testes do alossauro e da pedreira (última sala), chamados por run_tests.gd (usa check/_fresh_world/_frames de lá).
## Alossauro na origem olhando para +Z; a heroína é posta na frente (+Z) dele.

const EXPECTED_ANIMS := [
	"Idle", "Walk", "Run", "Roar", "RoarAt", "Study", "Stomp", "Bite", "Shake", "Throw", "Hit",
	"Headbutt", "HeadbuttR", "TailWhip", "TailWhipR",
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
	await test_flinch_needs_damage()
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
	check(tris > 800 and tris < 5000, "alossauro: orçamento de triângulos, PS2 do começo (800-5000)", str(tris))
	check(inst.find_child("Mouth", true, false) != null, "alossauro: marcador da boca (Mouth)")
	var atlas: Texture2D = load("res://assets/characters/allosaurus_atlas.png")
	check(atlas != null and atlas.get_width() == 512 and atlas.get_height() == 512, "alossauro: atlas 512x512")
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
	check(arm.global_position.distance_to(a.model.mouth_position()) > 0.3, "não é pelo braço (como o raptor)")
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
	await t._frames(150)
	check(not p.model.is_ragdoll() and not p.is_dodging(), "levanta depois do arremesso")


func test_flinch_needs_damage() -> void:
	var pr := await _pair(Vector3(0, 0, 12))
	var a: Allosaurus = pr[1]
	a.start_stalk()
	a.take_hit(Player.DAMAGE, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	check(a.state != "hit", "um tiro não faz o alossauro se encolher", a.state)
	for i in 4:
		a.take_hit(Player.DAMAGE, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	check(a.state == "hit", "dano acumulado faz reagir (Hit)", a.state)


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
	check(hips.y < 2.4, "corpo tomba", "%.2f" % hips.y)
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
	check(main.raptors.size() == Yard.POSTS.size() + Arena.POSTS.size(), "cena principal: raptors do pátio e da pedreira", str(main.raptors.size()))
	check(not main.ended, "jogo começa sem a tela de fim")
	a.take_hit(Allosaurus.MAX_HEALTH, Vector3.BACK, a.global_position + Vector3.UP * 2.5)
	await t._frames(int((main.END_DELAY + 0.3) * 60.0))
	check(main.ended and main._end.visible, "alossauro morto: tela de fim")
	main.reset_all()
	await t._frames(2)
	check(not main.ended and not main._end.visible and not a.dead, "R reinicia: sem tela de fim, alossauro vivo")
	main.queue_free()
	await t.process_frame
