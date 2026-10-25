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


## No jogo: a caixa no fundo do teto da sala dos clones, dá para subir lá do telhado, a neblina a esconde de longe,
## a tela do item aparece e o R desfaz.
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
	t.check(is_equal_approx(at.y, Roof.LAB_Y) and at.z < CloneLab.Z_NEAR - 8.0 and absf(at.x) < Roof.LAB_X - 1.0,
		"caixa no teto da sala dos clones, no fundo", str(at))
	t.check(Roof.has(at) and Roof.has(drop.front_point()), "teto dos clones conta como telhado (fora da vista dos inimigos)")
	# lona e caixa dentro do teto, longe da mureta
	for c: Vector3 in [Vector3(SupplyDrop.CHUTE[0], 0, SupplyDrop.CHUTE[3]), Vector3(SupplyDrop.CHUTE[1], 0, SupplyDrop.CHUTE[3])]:
		var g := drop.global_transform * c
		t.check(absf(g.x) < Roof.LAB_X - Roof.PARAPET_T and g.z > Roof.LAB_Z1 + Roof.PARAPET_T, "lona dentro da mureta", str(g))
	# neblina: rala sobre o galpão, grossa sobre o anexo
	var fogs := main.find_children("*", "FogVolume", true, false).filter(func(f: FogVolume) -> bool: return f.global_position.y > Roof.Y)
	t.check(fogs.size() == 2, "neblina do telhado (galpão e anexo)", str(fogs.size()))
	var dist := Roof.START.distance_to(at)
	var lab_part := absf(at.z - CloneLab.Z_NEAR)
	var far := exp(-(Roof.FOG_DENSITY * dist + Roof.LAB_FOG_DENSITY * lab_part))
	var near := exp(-(Roof.FOG_DENSITY + Roof.LAB_FOG_DENSITY) * 2.0)
	t.check(far < 0.01 and near > 0.4, "do começo a caixa some na neblina; a 2 m aparece", "longe %.3f perto %.2f" % [far, near])
	t.check(exp(-Roof.FOG_DENSITY * Roof.START.distance_to(main.hatch.global_position)) > 0.3, "o alçapão segue visível do começo")
	# sobe do telhado do galpão para o teto do anexo (escalada de 1,5 m na parede do fundo)
	p.global_position = Vector3(-3.0, Roof.Y, CloneLab.Z_NEAR + 0.75)
	p.rotation.y = 0.0
	p.reset_physics_interpolation()
	await t._frames(8)
	var ledge := p.moves.find_ledge(Vector3.FORWARD)
	t.check(not ledge.is_empty() and absf(ledge.top - Roof.LAB_Y) < 0.05, "parede do anexo: borda escalável", str(ledge))
	t.check(p.moves.try_ledge(Vector3.FORWARD) and p.moves.mode == "mantle", "escala para o teto dos clones", p.moves.mode)
	for i in 120:
		await t.physics_frame
		if p.moves.mode == "":
			break
	await t._frames(10)
	t.check(absf(p.global_position.y - Roof.LAB_Y) < 0.1 and Roof.has(p.global_position), "de pé no teto dos clones", str(p.global_position))
	# mureta do fundo segura: correndo para o fundo ela não cai
	p.global_position = Vector3(2.0, Roof.LAB_Y, Roof.LAB_Z1 + 2.0)
	p.reset_physics_interpolation()
	Input.action_press("move_forward")
	p.camera_rig.yaw = 0.0
	await t._frames(120)
	Input.action_release("move_forward")
	t.check(p.global_position.y > Roof.LAB_Y - 0.1 and p.global_position.z > Roof.LAB_Z1, "mureta do fundo segura", str(p.global_position))
	# abre, tela do item, pistola com silenciador
	main.inspect.auto_close = 0.0
	p.global_position = drop.front_point()
	p.reset_physics_interpolation()
	await t._frames(5)
	main._process(0.016)
	t.check(main._prompt.visible and main._prompt_text.text == "ABRIR CAIXA (E)", "aviso ABRIR CAIXA", main._prompt_text.text)
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(int(float(Moves.data().pistol_pickup.frames) / Moves.fps() * 60.0) + 8)
	t.check(p.silencer and main.inspect.busy, "pegou e levantou: tela do item")
	while main.inspect.busy:
		await t.process_frame
	main._process(0.016)
	t.check(main._hud_weapon.text.begins_with("PISTOLA SIL."), "HUD: PISTOLA SIL.", main._hud_weapon.text)
	main.reset_all()
	await t._frames(3)
	t.check(not p.silencer and drop.has_item(), "R: caixa fechada com a pistola, ela com a pistola comum")
	main.queue_free()
	await t._frames(2)
