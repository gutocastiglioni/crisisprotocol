extends RefCounted
## Testes da escopeta (baú próprio, chumbos, bombeamento, cartucho), dos buracos de bala no cenário e da
## diferença entre os disparos, chamados por run_tests.gd (usa check/_fresh_world/_frames de lá).

var t: SceneTree  # o runner (run_tests.gd)


## Alvo que só conta os golpes (para ver que os chumbos chegam juntos, numa reação só).
class HitCounter:
	extends StaticBody3D
	var calls := 0
	var total := 0

	func _ready() -> void:
		collision_layer = 2
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.2, 2.0, 0.4)
		col.shape = box
		col.position.y = 1.0
		add_child(col)

	func take_hit(amount: int, _dir: Vector3, _at: Vector3) -> void:
		calls += 1
		total += amount


func run(runner: SceneTree) -> void:
	t = runner
	await test_assets()
	await test_shotgun_chest()
	await test_shotgun_pellets_and_pump()
	await test_m16_bloom()
	await test_decals()
	await test_decal_rules()


func _wall(w: Node3D, pos: Vector3, size: Vector3, surface: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.set_meta("surface", surface)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	b.add_child(col)
	b.position = pos
	w.add_child(b)
	return b


## Jogadora mirando para -Z com a arma `weapon`, olhando para `point`.
func _armed(w: Node3D, weapon: String, point: Vector3) -> Player:
	var p: Player = t._spawn_player(w, Vector3(0, 0, 3))
	await t._frames(10)
	p.give_weapon(weapon)
	Input.action_press("aim")
	await t._frames(30)
	for i in 3:
		p.camera_rig.look_at_point(point)
		await t._frames(2)
	return p


func test_assets() -> void:
	var inst: Node3D = HeroineModel.SCENE.instantiate()
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	t.check(ap.has_animation("ShotgunShoot") and ap.get_animation("ShotgunShoot").length > 0.5, "animação ShotgunShoot (coice + bombeamento)")
	for n in ["Shotgun", "ShotgunMuzzle", "ShotgunPump"]:
		t.check(inst.find_child(n, true, false) != null, "nó " + n + " no modelo")
	var pump: Node = inst.find_child("ShotgunPump", true, false)
	t.check(pump != null and pump.get_parent() is BoneAttachment3D, "telha presa ao osso da mão (BoneAttachment3D)")
	inst.free()
	var sg: Node = load("res://assets/characters/shotgun.glb").instantiate()
	var mesh: MeshInstance3D = sg.find_children("*", "MeshInstance3D", true, false)[0]
	t.check(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size() > 0, "shotgun.glb (escopeta do baú) com UV para o atlas")
	sg.free()
	var d: Dictionary = Moves.data().shotgun
	t.check(d.pump.size() >= 3 and float(d.stroke) > 0.05, "bombeamento em heroine_moves.json", str(d))


func test_shotgun_chest() -> void:
	var w: Node3D = await t._fresh_world()
	var c := Chest.new()
	c.item = "shotgun"
	c.position = Vector3(0, 0, -2)
	w.add_child(c)
	var p: Player = t._spawn_player(w, Vector3(0, 0, 1.5))
	await t._frames(10)
	var aabb := AABB()
	for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
		if mi.get_parent() != c and mi.get_parent().get_parent() == c and mi.mesh is ArrayMesh:
			aabb = c.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
	var inner := AABB(Vector3(-Chest.SIZE.x / 2 + Chest.WALL, Chest.PALLET + Chest.WALL, -Chest.SIZE.z / 2 + Chest.WALL),
		Vector3(Chest.SIZE.x - 2 * Chest.WALL, Chest.SIZE.y - Chest.WALL, Chest.SIZE.z - 2 * Chest.WALL))
	t.check(aabb.size.x > 0.8 and inner.grow(0.005).encloses(aabb), "escopeta deitada dentro do outro baú", "%s em %s" % [aabb, inner])
	p.global_position = c.kneel_transform().origin
	await t._frames(3)
	t.check(p.pick_target() == c and c.item == "shotgun", "perto do baú da escopeta: aviso de pegar a escopeta")
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	var grab := float(Moves.data().rifle.grab_frame) / 30.0
	await t._frames(int(grab * 60.0) + 4)
	var muzzle := p.model.muzzle_position()
	t.check(p.weapon() == "shotgun" and not c.has_item(), "pega a escopeta no quadro das mãos")
	t.check((c.global_transform * aabb).grow(0.06).has_point(muzzle), "escopeta passa do baú para as mãos sem pular", "cano %s" % muzzle)
	await t._frames(70)
	t.check(p.model.is_weapon_visible("shotgun") and not p.model.is_weapon_visible("m16"), "empunha a escopeta")
	t.check(p.model._pump.visible, "telha aparece junto com a escopeta")
	t.check(float(p.model.tree.get("parameters/carry/blend_amount")) > 0.5, "escopeta na pose de carregar")
	t.check(Array(p.weapons) == ["pistol", "shotgun"], "inventário: pistola e escopeta", str(p.weapons))
	p.model.set_weapon("pistol")
	t.check(not p.model._pump.visible, "pistola na mão: telha some")
	p.respawn()
	c.reset()
	await t._frames(3)
	t.check(c.item == "shotgun" and c.has_item(), "reinício: o baú volta com a escopeta")


func test_shotgun_pellets_and_pump() -> void:
	var w: Node3D = await t._fresh_world()
	var target := HitCounter.new()
	target.position = Vector3(0, 0, 0)
	w.add_child(target)
	var p := await _armed(w, "shotgun", Vector3(0, 1.2, 0))
	var shells := [0]
	p.model.shell_ejected.connect(func(_a: Vector3, _v: Vector3) -> void: shells[0] += 1)
	var stats: Dictionary = Player.WEAPON_STATS.shotgun
	var shots := p.shots_fired
	p.fire()
	await t._frames(1)
	t.check(target.calls == 1, "chumbos no mesmo alvo = um golpe só", str(target.calls))
	t.check(target.total == int(stats.pellets) * int(stats.damage), "todos os chumbos somam o dano de perto",
		"%d de %d" % [target.total, int(stats.pellets) * int(stats.damage)])
	t.check(target.total > Player.DAMAGE * 2, "escopeta de perto: bem mais que a pistola")
	p.fire()
	await t._frames(1)
	t.check(p.shots_fired == shots + 1, "bombeando: não atira de novo antes da cadência da escopeta")
	# telha no fundo do curso (quadros 10-12 da animação, a 30 fps; o tiro saiu há 2 quadros de física)
	await t._frames(20)
	var pump: Node3D = p.model._pump
	var back := (pump.transform.origin - p.model._pump_rest.origin).length()
	t.check(absf(back - float(Moves.data().shotgun.stroke)) < 0.015, "telha vai para trás no bombeamento", "%.3f m" % back)
	t.check(shells[0] == 1, "cartucho sai ao bombear", str(shells[0]))
	await t._frames(30)
	t.check(pump.transform.is_equal_approx(p.model._pump_rest), "telha volta para a frente")
	await t._frames(int(float(stats.cooldown) * 60.0))
	p.fire()
	await t._frames(1)
	t.check(p.shots_fired == shots + 2, "depois de bombear, atira de novo")
	# troca no meio do bombeamento: a telha volta, nenhum cartucho; voltando à escopeta, bombeia de novo
	await t._frames(8)
	p.switch_weapon()
	t.check(pump.transform.is_equal_approx(p.model._pump_rest) and not pump.visible, "troca no meio do bombeamento: telha volta e some")
	await t._frames(40)
	var shells0: int = shells[0]
	t.check(shells0 == 1, "trocando de arma não sai cartucho", str(shells0))
	p.switch_weapon()
	await t._frames(int(float(stats.cooldown) * 60.0))
	p.fire()
	await t._frames(40)
	t.check(p.shots_fired == shots + 3 and shells[0] == 2, "de volta à escopeta: atira e bombeia", "%d tiros, %d cartuchos" % [p.shots_fired - shots, shells[0]])
	# longe, os chumbos abrem e o dano cai
	p.global_position = Vector3(0, 0, 18)
	p.reset_physics_interpolation()
	await t._frames(3)
	for i in 3:
		p.camera_rig.look_at_point(Vector3(0, 1.0, 0))
		await t._frames(2)
	await t._frames(int(float(stats.cooldown) * 60.0))
	var before := target.total
	p.fire()
	await t._frames(1)
	t.check(target.total - before < int(stats.pellets) * int(stats.damage) / 2, "de longe: chumbos abrem e o dano cai",
		str(target.total - before))
	Input.action_release("aim")


func test_m16_bloom() -> void:
	var w: Node3D = await t._fresh_world()
	var p := await _armed(w, "m16", Vector3(0, 1.2, -6))
	t.check(p._bloom == 0.0, "M16: primeiro tiro sem dispersão")
	for i in 6:
		p.fire()
		await t._frames(int(Player.WEAPON_STATS.m16.cooldown * 60) + 1)
	t.check(p._bloom > 1.0 and p._bloom <= Player.WEAPON_STATS.m16.max_spread, "M16: rajada abre a dispersão", str(p._bloom))
	await t._frames(60)
	t.check(p._bloom == 0.0, "M16: soltando o gatilho a mira volta", str(p._bloom))
	Input.action_release("aim")


func test_decals() -> void:
	Fx.clear_decals()
	var w: Node3D = await t._fresh_world()
	var wall := _wall(w, Vector3(0, 1.5, -1), Vector3(6, 3, 0.4), "wall")
	var p := await _armed(w, "pistol", Vector3(0.3, 1.4, -0.8))
	var n0 := Fx.decal_count()
	p.fire()
	await t._frames(1)
	var holes := wall.find_children("BulletHole", "", false, false)
	t.check(Fx.decal_count() == n0 + 1 and holes.size() == 1, "tiro na parede deixa um buraco de bala", "%d %d" % [Fx.decal_count(), holes.size()])
	if holes.size() == 1:
		var h: Node3D = holes[0]
		var face_z := -1.0 + 0.2
		t.check(absf(h.global_position.z - face_z) < 0.01 and h.global_basis.z.normalized().dot(Vector3.BACK) > 0.99,
			"buraco rente à parede, virado para fora", str(h.global_position))
	p.give_weapon("shotgun")
	await t._frames(int(Player.SHOT_COOLDOWN * 60) + 2)
	n0 = Fx.decal_count()
	p.fire()
	await t._frames(1)
	var made := Fx.decal_count() - n0
	t.check(made >= 4 and made <= int(Player.WEAPON_STATS.shotgun.pellets), "escopeta: um buraco por chumbo", str(made))
	Input.action_release("aim")
	Fx.clear_decals()
	await t._frames(1)
	t.check(Fx.decal_count() == 0 and wall.find_children("BulletHole", "", false, false).is_empty(), "reinício apaga os buracos")


func test_decal_rules() -> void:
	Fx.clear_decals()
	var w: Node3D = await t._fresh_world()
	var box := _wall(w, Vector3(0, 0.5, -2), Vector3(1, 1, 1), "crate")
	await t._frames(2)
	var face := Vector3(0, 0.5, -1.5)
	t.check(Fx.decal(box, face, Vector3.BACK, 0.07) != null, "buraco no meio da caixa")
	t.check(Fx.decal(box, Vector3(0.49, 0.5, -1.5), Vector3.BACK, 0.07) == null, "na quina não fica pendurado")
	var dummy := TargetDummy.new()
	w.add_child(dummy)
	await t._frames(2)
	t.check(Fx.decal(dummy, Vector3(0, 1, 0.3), Vector3.BACK, 0.07) == null, "alvo/personagem não leva buraco no corpo")
	var c := Chest.new()
	c.position = Vector3(3, 0, 0)
	w.add_child(c)
	await t._frames(2)
	t.check(Fx.decal(c, Vector3(3, 0.3, 0.29), Vector3.BACK, 0.07) == null, "baú não leva buraco (colisão maior que a caixa)")
	for i in Fx.MAX_DECALS + 20:
		Fx.decal(box, face + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3), 0), Vector3.BACK, 0.05)
	await t._frames(1)
	t.check(Fx.decal_count() == Fx.MAX_DECALS, "limite de buracos (os mais antigos somem)", str(Fx.decal_count()))
	box.free()  # o corpo some com os buracos dele
	t.check(Fx.decal_count() == 0, "corpo apagado: os buracos dele saem da lista sem erro")
	Fx.clear_decals()
