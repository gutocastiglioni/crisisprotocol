extends RefCounted
## Testes do container trancado da M79, da chave escondida no alvo, das telas de inspeção e da M79 (granada em arco,
## explosão em área). Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_m79_assets()
	await test_locked_chest()
	await test_lock_zoom_and_unlock()
	await test_key_drop_and_pickup()
	await test_aim_velocity()
	await test_grenade_explodes()
	await test_grenade_dud_and_cover()
	await test_grenade_hurts_player()
	await test_m79_fire()
	await test_main_layout()


func _release_all() -> void:
	for a in ["aim", "shoot", "interact", "move_forward"]:
		Input.action_release(a)


func _wall(w: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	b.add_child(col)
	w.add_child(b)
	b.global_position = pos
	return b


func _locker(w: Node3D, pos: Vector3) -> Chest:
	var c := Chest.new()
	c.item = "m79"
	c.lock = "container"
	c.position = pos
	c.rotation.y = PI
	w.add_child(c)
	return c


func _inspect(w: Node3D, p: Player) -> Inspect:
	var i := Inspect.new()
	i.player = p
	i.auto_close = 0.0
	w.add_child(i)
	return i


func test_m79_assets() -> void:
	var inst := (load("res://assets/characters/heroine.glb") as PackedScene).instantiate()
	for n in ["M79", "M79Muzzle"]:
		t.check(inst.find_child(n, true, false) != null, "heroine.glb tem " + n)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	t.check(ap.has_animation("M79Shoot") and ap.get_animation("M79Shoot").length > 0.6, "animação M79Shoot (coice forte)")
	inst.free()
	t.check(Chest.ITEMS.has("m79") and Level.TEX.has("chest_m79"), "baú da M79 com textura própria (sem estêncil)")
	var w: Node3D = await t._fresh_world()
	var m := HeroineModel.new()
	w.add_child(m)
	await t._frames(3)
	m.set_weapon("m79")
	t.check(m.is_weapon_visible("m79") and not m.is_weapon_visible("m16") and not m.is_weapon_visible("shotgun"), "M79 na mão: só ela aparece")
	t.check("m79" in HeroineModel.LONG_GUNS, "M79 usa as poses de arma longa")
	var muzzle := m.muzzle_position()
	t.check(muzzle.distance_to(m.global_position + Vector3.UP * 1.2) < 1.0, "cano da M79 perto das mãos", str(muzzle))
	for s in ["m79_shot", "explosion", "key_drop", "lock_rattle", "unlock", "item_get"]:
		t.check(Sfx.SOUNDS.has(s) and ResourceLoader.exists(Sfx.DIR + s + ".wav"), "som " + s)


## Trancado: o aviso aparece, interagir avisa o main (sinal `locked`) e não começa a pegar a arma.
func test_locked_chest() -> void:
	var w: Node3D = await t._fresh_world()
	var c := _locker(w, Vector3(0, 0, 0))
	var p: Player = t._spawn_player(w, c.kneel_transform().origin)
	await t._frames(10)
	t.check(c.is_locked() and c.has_item(), "container começa trancado com a M79")
	t.check(p.pick_target() == c, "trancado também dá o aviso de interação")
	var got := []
	p.locked.connect(func(ch: Node) -> void: got.append(ch))
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(20)
	t.check(got == [c], "interagir no trancado avisa (sinal locked)", str(got))
	t.check(p.moves.mode != "pickup" and p.weapon() == "pistol" and c.has_item(), "trancado não abre nem dá a arma")
	t.check(not c.is_open(), "a tampa continua fechada")


func test_lock_zoom_and_unlock() -> void:
	var w: Node3D = await t._fresh_world()
	var c := _locker(w, Vector3(0, 0, 0))
	var p: Player = t._spawn_player(w, c.kneel_transform().origin + c.global_basis.z * 0.3)
	await t._frames(10)
	var ins := _inspect(w, p)
	var view := c.lock_view()
	t.check(view.origin.distance_to(c.global_position + Vector3.UP * 0.4) < 1.0, "câmera do zoom perto do cadeado", str(view.origin))
	# sem a chave: pausa, câmera vai até o cadeado, aviso, volta
	var state := {"paused": false, "cam": false, "text": ""}
	ins.on_shown = func() -> void:
		state.paused = t.paused
		state.cam = ins._cam.current and ins._cam.global_position.distance_to(view.origin) < 0.05
		state.text = ins._title.text
	await ins.lock_zoom(c, false)
	t.check(state.paused and state.cam, "zoom no cadeado com o jogo pausado", str(state))
	t.check(state.text == "ESTA TRANCADO", "aviso de trancado", state.text)
	t.check(not t.paused and not ins.busy and p.camera_rig.camera.current, "fecha: jogo volta e a câmera é a dela")
	t.check(c.is_locked(), "sem chave continua trancado")
	# com a chave: o cadeado abre e cai
	await ins.lock_zoom(c, true)
	t.check(not c.is_locked() and state.text == "USOU A CHAVE DO CONTAINER", "com a chave destranca", state.text)
	t.check(c._padlock.position.y < 0.1, "o cadeado caiu no chão", str(c._padlock.position))
	# agora pega a M79 como nos outros baús (arcade: sem limite de munição)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(int(Moves.data().rifle.pickup_frames) * 2 + 20)
	t.check(p.weapon() == "m79" and "m79" in p.weapons and not c.has_item(), "destrancado: pega a M79", p.weapon())
	c.reset()
	t.check(c.is_locked() and c.has_item() and c._padlock.position.y > 0.3, "reinício tranca de novo com o cadeado no lugar")


func test_key_drop_and_pickup() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, 0)
	w.add_child(d)
	var k := KeyItem.new()
	w.add_child(k)
	d.loot = k
	await t._frames(10)
	t.check(k.state == "hidden" and not k.visible, "chave escondida com o alvo")
	var picked := []
	k.picked.connect(func(it: KeyItem) -> void: picked.append(it))
	d.take_hit(999, Vector3.FORWARD, d.global_position + Vector3.UP)
	await t._frames(int(KeyItem.FALL_TIME * 60) + 10)
	t.check(k.state == "dropped" and k.visible, "alvo morto: a chave cai", k.state)
	t.check(absf(k.global_position.y) < 0.05 and Vector2(k.global_position.x, k.global_position.z).length() < 0.1, "no chão onde ele estava", str(k.global_position))
	var bright := 0.0
	for i in 90:
		await t.process_frame
		bright = maxf(bright, k.twinkle())
	t.check(bright > 0.8 and k._glow.visible, "brilha piscando no chão", str(bright))
	t.check(picked.is_empty() and not p.has_key("container"), "longe: não pega")
	p.global_position = k.global_position + Vector3(0.5, 0, 0.3)
	await t._frames(3)
	t.check(picked == [k] and p.has_key("container") and k.state == "taken" and not k.visible, "chegando perto pega sozinha", k.state)
	p.use_key("container")
	t.check(not p.has_key("container"), "usar a chave a gasta")
	p.add_key("container")
	p.respawn()
	t.check(p.keys.is_empty(), "reinício: sem chaves")
	k.reset()
	d.reset()
	t.check(k.state == "hidden" and not k.visible, "reinício: a chave volta para o alvo")
	# tela do item
	var ins := _inspect(w, p)
	var seen := {}
	ins.on_shown = func() -> void: seen.merge({"view": ins._view.visible, "title": ins._title.text, "paused": t.paused})
	await ins.show_item(k)
	t.check(seen.get("view", false) and seen.get("paused", false), "item na tela com o jogo pausado", str(seen))
	t.check(seen.get("title", "") == "PEGOU: CHAVE DO CONTAINER", "nome do item", str(seen))
	t.check(not t.paused and not ins._view.visible, "tela do item fecha")


## O arco calculado passa pelo ponto mirado (perto, longe, acima e abaixo).
func test_aim_velocity() -> void:
	var worst := 0.0
	for target in [Vector3(0, 0, -6), Vector3(3, -1.2, -25), Vector3(-8, 2, -40), Vector3(0, -1.4, -2.5)]:
		var from := Vector3(0, 1.4, 0)
		var v := Grenade.aim_velocity(from, target, Grenade.SPEED, Grenade.GRAVITY)
		var flat := Vector2(target.x - from.x, target.z - from.z)
		var tt := flat.length() / Vector2(v.x, v.z).length()
		var y := from.y + v.y * tt - 0.5 * Grenade.GRAVITY * tt * tt
		worst = maxf(worst, absf(y - target.y))
	t.check(worst < 0.01 and absf(Grenade.aim_velocity(Vector3.ZERO, Vector3(0, 0, -10), 32.0, 9.8).length() - 32.0) < 0.01, "arco da granada cai no ponto mirado", str(worst))


func test_grenade_explodes() -> void:
	var w: Node3D = await t._fresh_world()
	var near := TargetDummy.new()
	near.position = Vector3(0, 0, -10)
	w.add_child(near)
	var mid := TargetDummy.new()
	mid.position = Vector3(3.5, 0, -10)
	w.add_child(mid)
	var far := TargetDummy.new()
	far.position = Vector3(9, 0, -10)
	w.add_child(far)
	await t._frames(10)
	var heard := []
	var g := Grenade.launch(w, Vector3(0, 1.4, 0), Vector3(0, 0, -9.5), null)
	await t._frames(60)
	t.check(not is_instance_valid(g) or g.is_queued_for_deletion(), "granada explode ao bater no chão")
	t.check(near.dead, "alvo ao lado morre na explosão")
	t.check(not mid.dead and mid.health < 100, "a 3,5 m machuca menos", "vida=%d" % mid.health)
	t.check(not far.dead and far.health == 100, "longe (fora do raio) não machuca", "vida=%d" % far.health)
	t.check(Fx.decal_count() > 0, "mancha de queimado no chão")
	t.check(Sfx.played.get("explosion", 0) > 0, "som da explosão")


func test_grenade_dud_and_cover() -> void:
	var w: Node3D = await t._fresh_world()
	# perto demais: não arma, só a pancada
	var close := TargetDummy.new()
	close.position = Vector3(0, 0, -2)
	w.add_child(close)
	await t._frames(10)
	var played: int = Sfx.played.get("explosion", 0)
	Grenade.launch(w, Vector3(0, 1.2, 0), Vector3(0, 1.2, -2), null, 60)
	await t._frames(30)
	t.check(not close.dead and close.health == 40, "antes de armar: só a pancada", "vida=%d" % close.health)
	t.check(Sfx.played.get("explosion", 0) == played, "antes de armar não explode")
	close.queue_free()
	# atrás de uma parede: a explosão do outro lado não chega
	_wall(w, Vector3(0, 1.5, -10), Vector3(6, 3, 0.4))
	var hidden := TargetDummy.new()
	hidden.position = Vector3(0, 0, -11.5)
	w.add_child(hidden)
	await t._frames(5)
	Grenade.explode(w, Vector3(0, 0.3, -9.0))
	await t._frames(3)
	t.check(not hidden.dead and hidden.health == 100, "parede protege da explosão", "vida=%d" % hidden.health)


func test_grenade_hurts_player() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 0))
	await t._frames(10)
	Grenade.explode(w, Vector3(1.0, 0.1, 0))
	await t._frames(5)
	var max_hit := roundi(Grenade.DAMAGE * Grenade.PLAYER_SHARE)
	t.check(p.health < 100 and p.health >= 100 - max_hit, "a própria granada machuca (parte do dano)", "vida=%d" % p.health)
	t.check(p.model.is_ragdoll() and not p.dead, "perto da explosão ela é arremessada")
	await t._frames(150)
	t.check(not p.model.is_ragdoll() and not p.dead, "levanta depois")


## Tiro de verdade: mira, a granada sai do cano e cai onde a retícula aponta; cadência de arma de um tiro.
func test_m79_fire() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 6))
	var d := TargetDummy.new()
	d.position = Vector3(0, 0, -4)
	w.add_child(d)
	await t._frames(10)
	p.give_weapon("m79")
	Input.action_press("aim")
	await t._frames(30)
	p.camera_rig.look_at_point(d.global_position + Vector3.UP * 0.9)
	await t._frames(2)
	p.fire()
	await t._frames(1)
	var nades := t.get_nodes_in_group("grenades")
	t.check(nades.size() == 1 and p.shots_fired == 1, "M79 lança uma granada", str(nades.size()))
	p.fire()
	t.check(p.shots_fired == 1, "um tiro por vez (cadência longa)")
	await t._frames(60)
	_release_all()
	t.check(d.dead, "a granada acerta o alvo mirado e ele morre")
	t.check(p.health == 100, "a 10 m ela não se machuca", "vida=%d" % p.health)
	# survival: munição da M79 e o andar mirando
	GameMode.set_mode(GameMode.SURVIVAL)
	t.check(GameMode.START_AMMO.m79 == 0 and GameMode.WEAPON_AMMO.m79 > 0 and GameMode.AMMO_CAP.m79 >= GameMode.WEAPON_AMMO.m79, "survival: M79 vem com poucas granadas")
	var cap := func(k: String) -> float: return GameMode.weapon_stats(k, Player.WEAPON_STATS[k]).aim_speed
	t.check(cap.call("m79") < cap.call("m16") and cap.call("m79") > 0.0, "survival: com a M79 anda devagar mirando")
	var has_box := false
	for e in Pickup.LAYOUT:
		has_box = has_box or e.kind == "m79"
	t.check(has_box, "survival: tem caixa de granadas pelo caminho")
	GameMode.set_mode(GameMode.ARCADE)


## Na fase: o container fica atrás de onde ela começa, trancado, e a chave está com um dos alvos.
func test_main_layout() -> void:
	# sem o mundo do teste anterior (a jogadora dele também está no grupo "player")
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var locker: Chest = main.locker
	var start: Vector3 = main.player._spawn.origin
	var behind: Vector3 = (locker.global_position - start)
	t.check(behind.z > 2.0 and absf(behind.x) < 1.0, "container atrás de onde ela começa", str(behind))
	t.check(locker.is_locked() and locker.item == "m79" and locker.lock == main.key.id, "trancado, com a M79, abre com a chave do alvo")
	t.check(locker.global_basis.z.dot((start - locker.global_position).normalized()) > 0.9, "de frente para ela")
	var holder: TargetDummy = null
	for d: TargetDummy in main.dummies:
		if d.loot == main.key:
			holder = d
	t.check(holder != null and main.key.state == "hidden", "a chave está escondida num alvo")
	# matar o alvo, pegar a chave, abrir (zoom fecha sozinho), reiniciar
	main.inspect.auto_close = 0.0
	holder.take_hit(999, Vector3.FORWARD, holder.global_position + Vector3.UP)
	await t._frames(40)
	t.check(main.key.state == "dropped", "alvo da chave morto: ela cai brilhando")
	main.player.global_position = main.key.global_position
	await t._frames(3)
	t.check(main.player.has_key("container") and main.inspect.busy, "pegou: tela do item", "pos=%s chave=%s morta=%s mov=%s" % [main.player.global_position, main.key.global_position, main.player.dead, main.player.moves.mode])
	while main.inspect.busy:
		await t.process_frame
	await main._on_locked(locker)
	t.check(not locker.is_locked() and not main.player.has_key("container"), "abriu o container e gastou a chave")
	main.reset_all()
	await t._frames(3)
	t.check(locker.is_locked() and main.key.state == "hidden" and main.player.keys.is_empty(), "R: tranca de novo e a chave volta ao alvo")
	main.queue_free()
	await t._frames(2)
