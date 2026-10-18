extends RefCounted
## Testes do sangue (esguicho, respingos, rastro, poça) e do tiro na cabeça, chamados por run_tests.gd (usa
## check/_fresh_world/_frames/_spawn_player de lá).

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_blood_texture()
	await test_splash_marks_floor_and_wall()
	await test_splat_rules()
	await test_trail()
	await test_player_bleeds()
	await test_headshot_soldier()
	await test_headshot_raptor()
	await test_headshot_dummy()
	await test_corpse_pool()
	Blood.clear()


func _wall(w: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	b.add_child(col)
	b.position = pos
	w.add_child(b)
	return b


## (pelo grupo: irmãos com o mesmo nome são renomeados pelo Godot)
func _splats_on(body: Node) -> Array:
	return body.get_children().filter(func(n: Node) -> bool: return n.is_in_group("blood") and not n.is_queued_for_deletion())


func _pools() -> Array:
	return t.get_nodes_in_group("blood").filter(
		func(m: Node) -> bool: return (m as MeshInstance3D).mesh == Blood._mesh(Blood.POOL) and not m.is_queued_for_deletion())


## Jogadora em `pos` mirando de verdade (câmera no ombro) em `point`.
func _aim(w: Node3D, pos: Vector3, point: Vector3) -> Player:
	var p: Player = t._spawn_player(w, pos)
	await t._frames(10)
	Input.action_press("aim")
	await t._frames(30)
	for i in 3:
		p.camera_rig.look_at_point(point)
		await t._frames(2)
	return p


## Centro da cabeça de quem tem ragdoll (a parte "Head" acompanha a animação enquanto está vivo).
func _head(model: Node) -> Vector3:
	return model.ragdoll.bodies["Head"].global_position


func test_blood_texture() -> void:
	var img: Image = Blood.TEX.get_image()
	if img.is_compressed():
		img.decompress()
	t.check(img.get_width() == 256 and img.get_height() == 256 and img.detect_alpha() != Image.ALPHA_NONE,
		"blood_fx.png 256x256 com alfa", "%dx%d" % [img.get_width(), img.get_height()])
	var empty := []
	for f in 4:
		var x0 := (f % 2) * 128
		var y0 := (f / 2) * 128
		var solid := 0
		var magenta := false
		for y in range(y0, y0 + 128, 2):
			for x in range(x0, x0 + 128, 2):
				var c := img.get_pixel(x, y)
				solid += 1 if c.a > 0.5 else 0
				magenta = magenta or (c.r > 0.9 and c.b > 0.9 and c.g < 0.2)
		if solid < 200 or magenta:
			empty.append(f)
	t.check(empty.is_empty(), "4 quadros de sangue desenhados, fundo sem magenta", str(empty))


func test_splash_marks_floor_and_wall() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var wall := _wall(w, Vector3(0, 1.5, -1.6), Vector3(6, 3, 0.4))
	await t._frames(2)
	var floor: Node = w.get_child(0)
	Blood.splash(w, Vector3(0, 1.2, 0), Vector3.FORWARD, Vector3.BACK, 1.0)
	await t._frames(3)
	var sprays := w.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	t.check(sprays.size() >= 3, "esguicho: quadros e gotas voando", str(sprays.size()))
	await t._frames(70)
	t.check(_splats_on(wall).size() >= 1, "o sangue que atravessa respinga na parede atrás", str(_splats_on(wall).size()))
	t.check(_splats_on(floor).size() >= 1, "respingo no chão embaixo do ferimento", str(_splats_on(floor).size()))
	var ok_wall := true
	for s: Node3D in _splats_on(wall):
		ok_wall = ok_wall and absf(s.global_position.z - (-1.4)) < 0.02 and s.global_basis.z.normalized().dot(Vector3.BACK) > 0.99
	t.check(ok_wall, "respingo rente à parede, virado para fora")
	var sprays_left := w.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D and not n.is_queued_for_deletion())
	t.check(sprays_left.is_empty(), "esguicho e gotas somem depois", str(sprays_left.size()))
	var head0 := Blood.count()
	Blood.splash(w, Vector3(0, 1.2, 0), Vector3.FORWARD, Vector3.BACK, 1.0, true)
	await t._frames(70)
	t.check(Blood.count() - head0 >= 3, "tiro na cabeça: mais respingos", str(Blood.count() - head0))


func test_splat_rules() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var box := _wall(w, Vector3(0, 0.5, -2), Vector3(1, 1, 1))
	await t._frames(2)
	t.check(Blood.splat(box, Vector3(0, 1.0, -2), Vector3.UP, 0.3) != null, "respingo em cima da caixa")
	var edge := Blood.splat(box, Vector3(0.42, 1.0, -2), Vector3.UP, 0.5)
	t.check(edge == null or edge.scale.x < 0.3, "na quina não fica pendurado (encolhe ou não marca)", str(edge.scale.x if edge else 0.0))
	var dummy := TargetDummy.new()
	w.add_child(dummy)
	await t._frames(2)
	t.check(Blood.splat(dummy, Vector3(0, 1, 0.3), Vector3.BACK, 0.2) == null, "personagem não leva respingo no corpo")
	t.check(Blood.splat(dummy.model.ragdoll.bodies["Chest"], Vector3(0, 1.2, 0.2), Vector3.BACK, 0.2) == null, "ragdoll não leva respingo")
	var c := Chest.new()
	c.position = Vector3(3, 0, 0)
	w.add_child(c)
	await t._frames(2)
	t.check(Blood.splat(c, Vector3(3, 0.3, 0.29), Vector3.BACK, 0.1) == null, "baú (no_decals) não leva respingo")
	var floor: Node = w.get_child(0)
	for i in Blood.MAX_SPLATS + 15:
		Blood.splat(floor, Vector3(randf_range(-4, 4), 0, randf_range(2, 6)), Vector3.UP, 0.2, Blood.DROPS)
	await t._frames(1)
	t.check(Blood.count() == Blood.MAX_SPLATS, "limite de respingos (os mais antigos somem)", str(Blood.count()))
	# poça marcada para depois e reinício antes dela aparecer: não aparece
	var marker := Node3D.new()
	w.add_child(marker)
	marker.position = Vector3(-3, 0.2, 0)
	Blood.pool(marker, 1.0, 0.2)
	Blood.clear()
	await t._frames(30)
	t.check(Blood.count() == 0 and _pools().is_empty(), "reinício apaga o sangue e cancela a poça pendente", str(Blood.count()))
	box.free()  # o corpo some com o sangue dele
	t.check(Blood.count() == 0, "corpo apagado: os respingos dele saem da lista sem erro")


func test_trail() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var who := Node3D.new()
	w.add_child(who)
	await t._frames(2)
	var trail := Blood.Trail.new()
	var drops := 0
	for i in 120:
		who.position.x = i * 0.05  # 6 m em 2 s
		drops += 1 if trail.update(who, 1.0 / 60.0, 0.0) else 0
	t.check(drops == 0, "sem ferimento, sem rastro", str(drops))
	var light := 0
	for i in 120:
		who.position.x = 6.0 + i * 0.05
		light += 1 if trail.update(who, 1.0 / 60.0, 0.2) else 0
	var heavy := 0
	for i in 120:
		who.position.x = 12.0 + i * 0.05
		heavy += 1 if trail.update(who, 1.0 / 60.0, 0.9) else 0
	t.check(light >= 2 and heavy > light * 2, "ferido deixa rastro; quanto pior, mais gotas", "%d leve, %d grave" % [light, heavy])
	var idle := 0
	for i in 180:
		idle += 1 if trail.update(who, 1.0 / 60.0, 0.9) else 0
	t.check(idle >= 2 and idle <= 4, "parado, pinga de tempos em tempos", str(idle))


func test_player_bleeds() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	p.take_hit(30, Vector3.BACK, p.global_position + Vector3.UP * 1.2)
	await t._frames(40)
	var after_hit := Blood.count()
	t.check(after_hit >= 1, "levar golpe espirra sangue no chão", str(after_hit))
	p.take_hit(40, Vector3.BACK, p.global_position + Vector3.UP * 1.2)  # 30 de vida: ferida grave
	await t._frames(40)
	var n0 := Blood.count()
	Input.action_press("move_forward")
	await t._frames(120)
	Input.action_release("move_forward")
	t.check(Blood.count() - n0 >= 3, "ferida, deixa rastro de sangue correndo", str(Blood.count() - n0))
	p.take_hit(999, Vector3.BACK, p.global_position + Vector3.UP * 1.2)
	await t._frames(int((Blood.POOL_DELAY + 0.5) * 60))
	t.check(_pools().size() == 1, "morta: poça embaixo do corpo", str(_pools().size()))
	p.respawn()
	Blood.clear()


func test_headshot_soldier() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	# soldado de costas para ela, parado (sem rota)
	var s := Soldier.new()
	s.position = Vector3(0, 0, -5)
	s.rotation.y = 0.0  # olha para -Z, longe dela
	w.add_child(s)
	await t._frames(5)
	var p := await _aim(w, Vector3(0, 0, 1), _head(s.model))
	s.target = p
	var heads := []
	p.headshot.connect(func(who: Node) -> void: heads.append(who))
	p.camera_rig.look_at_point(_head(s.model))
	await t._frames(1)
	p.fire()
	await t._frames(3)
	t.check(heads == [s], "tiro na cabeça do soldado conta como headshot", str(heads))
	t.check(s.dead, "headshot de pistola mata o soldado na hora", "vida=%d" % s.health)
	await t._frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	# outro soldado, tiro no peito: não é headshot e não mata
	var s2 := Soldier.new()
	s2.position = Vector3(2.5, 0, -5)
	w.add_child(s2)
	await t._frames(10)
	s2.target = p
	for i in 3:
		p.camera_rig.look_at_point(s2.global_position + Vector3.UP * 1.2)
		await t._frames(2)
	heads.clear()
	p.fire()
	await t._frames(3)
	t.check(heads.is_empty() and not s2.dead and s2.health == Soldier.MAX_HEALTH - Player.DAMAGE,
		"tiro no peito: dano normal, sem headshot", "vida=%d %s" % [s2.health, str(heads)])
	Input.action_release("aim")


func test_headshot_raptor() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	# raptor de lado para ela (olhando para +X), a 5 m: a cabeça fica à mostra
	var r := Raptor.new()
	r.position = Vector3(0, 0, -5)
	r.rotation.y = -PI * 0.5
	w.add_child(r)
	await t._frames(5)
	var p := await _aim(w, Vector3(0, 0, 0), _head(r.model))
	r.target = p
	var heads := []
	p.headshot.connect(func(who: Node) -> void: heads.append(who))
	p.camera_rig.look_at_point(_head(r.model))
	await t._frames(1)
	p.fire()
	await t._frames(3)
	var expect := Raptor.MAX_HEALTH - Player.DAMAGE
	t.check(heads.is_empty() and r.health == expect, "raptor cabeçudo: tiro na cabeça vale como no corpo, sem headshot", "vida=%d (esperado %d) %s" % [r.health, expect, str(heads)])
	t.check(not r.dead and r.state == "hit", "raptor leva o tiro e reage", r.state)
	t.check(r.wound() > 0.1, "raptor ferido (vai deixar rastro)", str(r.wound()))
	Input.action_release("aim")


func test_headshot_dummy() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, -3)
	d.rotation.y = PI
	w.add_child(d)
	await t._frames(5)
	var p := await _aim(w, Vector3(0, 0, 3), _head(d.model))
	var heads := []
	p.headshot.connect(func(who: Node) -> void: heads.append(who))
	p.camera_rig.look_at_point(_head(d.model))
	await t._frames(1)
	p.fire()
	await t._frames(3)
	t.check(heads == [d] and d.dead, "alvo de treino cai com um tiro na cabeça", "vida=%d %s" % [d.health, str(heads)])
	Input.action_release("aim")
	await t._frames(40)
	t.check(Blood.count() >= 2, "headshot espalha sangue no chão", str(Blood.count()))


func test_corpse_pool() -> void:
	Blood.clear()
	var w: Node3D = await t._fresh_world()
	var r := Raptor.new()
	r.position = Vector3(0, 0, -4)
	w.add_child(r)
	await t._frames(5)
	r.take_hit(999, Vector3.FORWARD, r.global_position + Vector3.UP)
	await t._frames(int((Blood.POOL_DELAY + 0.2) * 60))
	var pools := _pools()
	t.check(pools.size() == 1, "raptor morto: poça embaixo do corpo", str(pools.size()))
	if pools.size() >= 1:
		var pool: Node3D = pools[0]
		var s0 := pool.scale.x
		await t._frames(120)
		t.check(is_instance_valid(pool) and pool.scale.x > s0 * 1.3, "a poça cresce", "%.2f -> %.2f" % [s0, pool.scale.x if is_instance_valid(pool) else 0.0])
		var hips: Vector3 = r.model.ragdoll.bodies["Spine"].global_position
		t.check(absf(pool.global_position.y) < 0.02 and Vector2(pool.global_position.x - hips.x, pool.global_position.z - hips.z).length() < 0.9,
			"poça no chão, embaixo do corpo", str(pool.global_position))
	r.reset()
	await t._frames(3)
	t.check(r.wound() == 0.0, "reiniciado: sem ferimento, sem rastro")
