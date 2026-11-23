extends RefCounted
## Testes da caixa de paraquedas do telhado (SupplyDrop), da pistola com silenciador (Player.silencer) e da neblina do
## telhado. Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_assets()
	await test_model_swap()
	await test_quiet_shot()
	await test_open_and_take()
	await test_ammo_bonus()
	await test_main_layout()


## Ouvido de inimigo de mentira: guarda o raio e a força de cada barulho.
func _ear(w: Node3D) -> Node:
	var src := GDScript.new()
	src.source_code = "extends Node3D\nvar dead := false\nvar heard := []\nfunc hear_noise(_pos, radius, power):\n\theard.append([radius, power])\n"
	src.reload()
	var ear := Node3D.new()
	ear.set_script(src)
	ear.add_to_group("enemies")
	w.add_child(ear)
	return ear


func test_assets() -> void:
	var inst := (load("res://assets/characters/heroine.glb") as PackedScene).instantiate()
	for n in ["PistolSD", "SDMuzzle", "Pistol", "Muzzle"]:
		t.check(inst.find_child(n, true, false) != null, "heroine.glb tem " + n)
	inst.free()
	var item := (SupplyDrop.ITEM as PackedScene).instantiate()
	var meshes := item.find_children("*", "MeshInstance3D", true, false)
	var box := AABB()
	for mi: MeshInstance3D in meshes:
		box = mi.get_aabb() if box.size == Vector3.ZERO else box.merge(mi.get_aabb())
	# pistola (~20 cm) + silenciador (15 cm) ao longo de X, deitada no meio da origem
	t.check(meshes.size() > 0 and box.size.x > 0.3 and box.size.x < 0.42 and box.size.x > box.size.y * 1.6,
		"pistol_sd.glb: cano em +X, pistola com silenciador", str(box))
	t.check(absf(box.get_center().x) < 0.06, "pistol_sd.glb: origem no meio", str(box.get_center()))
	item.free()
	t.check(Sfx.SOUNDS.has("pistol_sd_shot") and ResourceLoader.exists(Sfx.DIR + "pistol_sd_shot.wav"), "som do tiro abafado")
	t.check(Level.TEX.has("drop_crate") and Level.TEX.has("chute"), "texturas da caixa e da lona")


## Com silenciador: só a malha PistolSD aparece e o cano (SDMuzzle) fica ~15 cm à frente, na linha da mira.
func test_model_swap() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	var m := p.model
	var plain := m.muzzle_position()
	t.check(m.gun() == "pistol" and m._meshes["pistol"].visible and not m._meshes["pistol_sd"].visible, "sem silenciador: pistola comum")
	p.silencer = true
	await t._frames(2)
	t.check(m.gun() == "pistol_sd" and m._meshes["pistol_sd"].visible and m._meshes["pistol"].visible and m.is_weapon_visible("pistol"),
		"com silenciador: pistola e silenciador na mão")
	var sd := m.muzzle_position()
	t.check(absf(sd.distance_to(plain) - 0.15) < 0.02, "cano do silenciador 15 cm à frente", "%.3f" % sd.distance_to(plain))
	Input.action_press("aim")
	await t._frames(40)
	var aim_dir := -p.global_basis.z
	var plain_muzzle: Node3D = m._muzzles["pistol"]
	var along := (m.muzzle_position() - plain_muzzle.global_position).normalized()
	t.check(along.dot(aim_dir) > 0.85, "mirando: o silenciador aponta para a frente dela", "%.2f" % along.dot(aim_dir))
	Input.action_release("aim")
	m.holster(true)
	t.check(not m._meshes["pistol_sd"].visible and not m._meshes["pistol"].visible, "guardada: nenhuma das duas")
	m.holster(false)
	p.give_weapon("m16")
	t.check(m._meshes["m16"].visible and not m._meshes["pistol_sd"].visible and not m._meshes["pistol"].visible,
		"com o M16 na mão a pistola e o silenciador somem")
	p.reset_loadout()
	t.check(not p.silencer and not m.silenced and m._meshes["pistol"].visible, "reinício: volta a pistola comum")
	# o guerrilheiro (mesmo modelo, sem a malha) segue com a pistola comum
	var g := HeroineModel.new()
	g.scene = load("res://assets/characters/guerrilla.glb")
	w.add_child(g)
	await t._frames(2)
	g.silenced = true
	t.check(g.gun() == "pistol", "corpo sem PistolSD: continua com a pistola comum")


## Tiro com silenciador: o barulho chega a poucos metros, fraco, e o clarão não a deixa à vista; o resto da pistola igual.
func test_quiet_shot() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	var ear := _ear(w)
	await t._frames(10)
	p.fire()
	await t._frames(2)
	t.check(ear.heard.size() == 1 and is_equal_approx(ear.heard[0][0], Player.SHOT_NOISE), "tiro comum ouvido a 26 m", str(ear.heard))
	t.check(p.stealth.loud_t > 0.0, "tiro comum: o clarão a mostra")
	p.stealth.loud_t = 0.0
	p.silencer = true
	await t._frames(40)
	ear.heard.clear()
	p.fire()
	await t._frames(2)
	t.check(ear.heard.size() == 1 and ear.heard[0][0] <= 4.0 and ear.heard[0][1] < 1.0, "silenciador: ouvido só de perto, fraco", str(ear.heard))
	t.check(is_equal_approx(p.stealth.loud_t, 0.0), "silenciador: o tiro não a deixa à vista")
	var s := p.weapon_stats("pistol")
	var base := p.weapon_stats("m16")
	t.check(s.name == "PISTOLA SIL." and int(s.damage) == Player.DAMAGE and base.name == "M16", "mesmo dano da pistola; outro nome no HUD")
	GameMode.set_mode(GameMode.SURVIVAL)
	var sv := p.weapon_stats("pistol")
	GameMode.set_mode(GameMode.ARCADE)
	t.check(sv.name == "PISTOLA SIL." and is_equal_approx(float(sv.cooldown), float(GameMode.SURVIVAL_WEAPONS.pistol.cooldown)),
		"sobrevivência: cadência da pistola de lá, com o silenciador")


## Na frente da caixa: aviso, E = ajoelha (PickupPistol), a tampa abre, a mão pega a pistola com silenciador no quadro
## da pegada e ela levanta com ela; R fecha e devolve.
func test_open_and_take() -> void:
	var w: Node3D = await t._fresh_world()
	var drop := SupplyDrop.new()
	w.add_child(drop)
	var p: Player = t._spawn_player(w, drop.front_point() + Vector3(0, 0, 2.5))
	await t._frames(10)
	t.check(p.pick_drop() == null, "longe da caixa: sem aviso")
	var got := [0]
	drop.picked.connect(func(_d: SupplyDrop) -> void: got[0] += 1)
	p.global_position = drop.front_point()
	await t._frames(3)
	t.check(p.pick_drop() == drop, "na frente da caixa: aviso de abrir")
	p.give_weapon("m16")
	var box := AABB()
	for mi: MeshInstance3D in drop._pistol.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if box.size == Vector3.ZERO else box.merge(b)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	t.check(p.moves.mode == "pickup" and p.model.state == "pickup_pistol", "E = ajoelha para pegar (PickupPistol)", p.model.state)
	await t._frames(20)
	t.check(drop._lid.rotation_degrees.x < -60.0 and drop.has_item() and not p.silencer, "tampa abre; a pistola ainda na caixa")
	t.check(not p.model.is_weapon_visible("pistol") and not p.model.is_weapon_visible("m16"), "mão vazia para pegar")
	# no quadro em que a mão pega, a pistola da mão está onde estava a da caixa
	var grab := float(Moves.data().pistol_pickup.grab_frame) / Moves.fps()
	await t._frames(int(grab * 60.0) - 22 + 3)
	var muzzle := p.model.muzzle_position()
	t.check(p.silencer and p.weapon() == "pistol" and not drop.has_item() and not drop._pistol.visible, "pega a pistola com silenciador no quadro da mão")
	t.check(box.grow(0.05).has_point(muzzle), "pistola passa da caixa para a mão sem pular", "cano %s caixa %s" % [muzzle, box])
	t.check(got[0] == 0, "a tela do item só depois de levantar")
	await t._frames(70)
	t.check(p.moves.mode == "" and p.model.state == "idle" and got[0] == 1, "levanta de pé com a pistola e mostra o item", "%s %s %d" % [p.moves.mode, p.model.state, got[0]])
	t.check(p.model.is_weapon_visible("pistol") and p.model.gun() == "pistol_sd", "empunha a pistola com silenciador")
	t.check(p.weapons.count("pistol") == 1 and "m16" in p.weapons, "troca a pistola (não é arma nova)", str(p.weapons))
	t.check(p.pick_drop() == null, "vazia: sem aviso")
	drop.reset()
	p.respawn()
	await t._frames(3)
	t.check(drop.has_item() and drop._pistol.visible and is_zero_approx(drop._lid.rotation_degrees.x) and not p.silencer, "reinício: fechada, com a pistola")
	# reinício no meio do ajoelhar: a pistola fica na caixa e não vai para a mão depois
	p.global_position = drop.front_point()
	await t._frames(3)
	p.moves.start_pickup(drop)
	await t._frames(20)
	drop.reset()
	p.respawn()
	await t._frames(int(grab * 60.0) + 70)
	t.check(not p.silencer and drop.has_item() and got[0] == 1, "R no meio de pegar: nada muda depois")


## Sobrevivência: a pistola da caixa vem com SupplyDrop.AMMO balas a mais (até o teto de munição).
func test_ammo_bonus() -> void:
	GameMode.set_mode(GameMode.SURVIVAL)
	var w: Node3D = await t._fresh_world()
	var drop := SupplyDrop.new()
	w.add_child(drop)
	var p: Player = t._spawn_player(w, drop.front_point())
	await t._frames(10)
	var before := p.ammo_of("pistol")
	p.moves.start_pickup(drop)
	var grab := float(Moves.data().pistol_pickup.grab_frame) / Moves.fps()
	await t._frames(int(grab * 60.0) + 5)
	t.check(p.silencer and p.ammo_of("pistol") == before + SupplyDrop.AMMO, "pistola da caixa: +%d balas" % SupplyDrop.AMMO,
		"%d -> %d" % [before, p.ammo_of("pistol")])
	await t._frames(80)
	drop.reset()
	p.respawn()
	p.ammo["pistol"] = int(GameMode.AMMO_CAP["pistol"])
	await t._frames(3)
	p.moves.start_pickup(drop)
	await t._frames(int(grab * 60.0) + 5)
	t.check(p.ammo_of("pistol") == int(GameMode.AMMO_CAP["pistol"]), "com a munição cheia não passa do teto", str(p.ammo_of("pistol")))
	await t._frames(80)
	GameMode.set_mode(GameMode.ARCADE)


## No jogo: a caixa na parte de trás do telhado (no mesmo nível, sem subida), escondida do começo atrás da casa de
## máquinas da luz vermelha, a telha translúcida da frente é cercada, a tela do item aparece e o R desfaz.
func test_main_layout() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var drop: SupplyDrop = main.drop
	var p: Player = main.player
	var at := drop.global_position
	t.check(is_equal_approx(at.y, Roof.Y) and at.z > Roof.FENCE_Z + 0.5 and at.z < 55.2 and absf(at.x + 0.5) < 1.1,
		"caixa no telhado, no corredor entre a casa de máquinas e o alambrado, no mesmo nível", str(at))
	t.check(Roof.has(at) and Roof.has(drop.front_point()), "em cima do telhado (fora da vista dos inimigos)")
	# lona e caixa dentro da mureta
	for c: Vector3 in [Vector3(SupplyDrop.CHUTE[0], 0, SupplyDrop.CHUTE[3]), Vector3(SupplyDrop.CHUTE[1], 0, SupplyDrop.CHUTE[3])]:
		var g := drop.global_transform * c
		t.check(g.x > Roof.X0 + Roof.PARAPET_T and g.x < Roof.X1 - Roof.PARAPET_T and g.z > Roof.FENCE_Z and g.z < Roof.Z1 - Roof.PARAPET_T,
			"lona dentro da mureta", str(g))
	# do começo a casa de máquinas a tapa (olho dela e câmera por cima do ombro); da frente dela a caixa aparece
	await t._frames(2)
	var space: PhysicsDirectSpaceState3D = (main as Node3D).get_world_3d().direct_space_state
	var seen := func(from: Vector3) -> bool:
		var q := PhysicsRayQueryParameters3D.create(from, at + Vector3.UP * 0.3, 1)
		var hit: Dictionary = space.intersect_ray(q)
		return hit.is_empty() or hit.collider == drop
	for h in [1.6, 2.2]:
		t.check(not seen.call(Roof.START + Vector3.UP * h), "do começo a casa de máquinas esconde a caixa (%.1f m)" % h)
	t.check(seen.call(drop.front_point() + drop.global_basis.z * 1.5 + Vector3.UP * 1.6), "da frente dela a caixa aparece")
	t.check(Roof.has(drop.front_point() + drop.global_basis.z * 0.4), "dá para chegar na frente dela")
	var fogs := main.find_children("*", "FogVolume", true, false).filter(func(f: FogVolume) -> bool: return f.global_position.y > Roof.Y)
	t.check(fogs.size() == 1, "neblina rala do telhado", str(fogs.size()))
	var fog_depth := Roof.FOG_DENSITY * Roof.START.distance_to(main.hatch.global_position)
	t.check(exp(-fog_depth) > 0.3, "o alçapão segue visível do começo")
	# a telha translúcida da frente é cercada: correndo para lá ela não passa do alambrado
	p.global_position = Vector3(-4.0, Roof.Y, Roof.FENCE_Z + 2.0)
	p.rotation.y = 0.0
	p.camera_rig.yaw = 0.0
	p.reset_physics_interpolation()
	Input.action_press("move_forward")
	await t._frames(150)
	Input.action_release("move_forward")
	t.check(p.global_position.z > Roof.FENCE_Z and absf(p.global_position.y - Roof.Y) < 0.2, "a parede da telha translúcida segura", str(p.global_position))
	# abre, tela do item, pistola com silenciador (o aviso do cheiro da beira oeste já visto: a caixa fica perto dela)
	main.smelled = true
	main.inspect.auto_close = 0.0
	p.global_position = drop.front_point()
	p.reset_physics_interpolation()
	await t._frames(5)
	main._process(0.016)
	t.check(main._prompt.visible and main._prompt.text() == "ABRIR CAIXA" and main._prompt.items[0].action == "interact", "aviso <E> ABRIR CAIXA", main._prompt.text())
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(int(float(Moves.data().pistol_pickup.frames) / Moves.fps() * 60.0) + 8)
	t.check(p.silencer and main.inspect.busy, "pegou e levantou: tela do item")
	while main.inspect.busy:
		await t.process_frame
	main._process(0.016)
	t.check(main._weapon_icon.kind == "pistol_sd", "HUD: modelo da pistola com silenciador", main._weapon_icon.kind)
	main.reset_all()
	await t._frames(3)
	t.check(not p.silencer and drop.has_item(), "R: caixa fechada com a pistola, ela com a pistola comum")
	main.queue_free()
	await t._frames(2)
