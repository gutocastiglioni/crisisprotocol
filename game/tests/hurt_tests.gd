extends RefCounted
## Testes dos golpes na heroína (art/heroine_hurt.py): reação aditiva ao tiro por direção (não endireita o corpo),
## cambaleio do empurrão, queda que machuca e derruba, e o levantar (GetUpFront/GetUpBack) a partir do ragdoll.
## Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá; perfil "arcade").

const ANIMS := ["HitFront", "HitBack", "HitL", "HitR", "StaggerBack", "StaggerFwd", "GetUpFront", "GetUpBack"]

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_assets()
	await test_hit_side()
	await test_hit_keeps_pose()
	await test_knockback_staggers()
	await test_launch_gets_up()
	await test_hard_fall_collapses()


func _hips_y(p: Player) -> float:
	var sk := p.model.skeleton
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hips"))).origin.y - p.global_position.y


func test_assets() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(2)
	var missing := ANIMS.filter(func(a: String) -> bool: return not p.model.anim_player.has_animation(a))
	t.check(missing.is_empty(), "animações de golpe e de levantar no heroine.glb", str(missing))
	var g := HeroineModel.new()
	g.scene = Soldier.BODY
	w.add_child(g)
	missing = ANIMS.filter(func(a: String) -> bool: return not g.anim_player.has_animation(a))
	t.check(missing.is_empty(), "e no guerrilla.glb (mesma árvore de animação)", str(missing))


func test_hit_side() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(2)
	var m := p.model  # olhando para -Z, direita dela em +X
	var got := [m.hit_side(Vector3.BACK), m.hit_side(Vector3.FORWARD), m.hit_side(Vector3.RIGHT), m.hit_side(Vector3.LEFT)]
	t.check(got == ["front", "back", "left", "right"], "golpe pela frente/costas/esquerda/direita", str(got))


## Agachada (ou mirando) o golpe soma por cima: o quadril não sobe para a pose em pé e os ossos voltam ao fim.
func test_hit_keeps_pose() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	var stand := _hips_y(p)
	p.crouching = true
	await t._frames(20)
	var crouch := _hips_y(p)
	p.take_hit(10, Vector3.BACK, p.global_position + Vector3.UP * 1.2)
	var peak := crouch
	var moved := 0.0
	var sk := p.model.skeleton
	var chest := sk.find_bone("Chest")
	var rest_q := sk.get_bone_pose_rotation(chest)
	for i in 8:
		await t._frames(1)
		peak = maxf(peak, _hips_y(p))
		moved = maxf(moved, sk.get_bone_pose_rotation(chest).angle_to(rest_q))
	t.check(p.model.state == "crouch" and peak < stand - 0.2, "levando tiro agachada continua agachada (sem pose em pé)",
		"em pé %.2f, agachada %.2f, máx no golpe %.2f" % [stand, crouch, peak])
	t.check(moved > deg_to_rad(5.0), "o tronco reage ao golpe", "%.1f°" % rad_to_deg(moved))
	await t._frames(30)
	t.check(absf(_hips_y(p) - crouch) < 0.02, "depois do golpe volta à pose de antes", "%.2f" % _hips_y(p))
	# dois golpes seguidos não travam a árvore
	p.take_hit(5, Vector3.RIGHT, p.global_position + Vector3.UP)
	await t._frames(2)
	p.take_hit(5, Vector3.RIGHT, p.global_position + Vector3.UP)
	await t._frames(30)
	t.check(p.health == 80 and absf(_hips_y(p) - crouch) < 0.02, "golpes seguidos somam e voltam", str(p.health))


func test_knockback_staggers() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	p.knockback(Vector3(0, 0, 4))  # para trás dela
	await t._frames(2)
	t.check(p.model.state == "stagger_back", "empurrada para trás: cambaleia para trás", p.model.state)
	await t._frames(40)
	p.knockback(Vector3(0, 0, -4))
	await t._frames(2)
	t.check(p.model.state == "stagger_fwd", "empurrada pelas costas: cambaleia para a frente", p.model.state)
	await t._frames(40)
	t.check(p.model.state == "idle", "depois do cambaleio volta ao normal", p.model.state)


func test_launch_gets_up() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	p.launch(Vector3(0, 3, 5), p.global_position + Vector3.UP)
	for i in 300:
		if p.is_getting_up():
			break
		await t._frames(1)
	t.check(p.is_getting_up() and p.model.state in HeroineModel.GETUP, "depois de caída toca o levantar", p.model.state)
	t.check(not p.model.is_weapon_visible("pistol"), "levantando sem a arma na mão")
	t.check(p.is_dodging(), "levantando não leva golpe")
	# cápsula de frente para onde a cabeça do corpo ficou
	await t._frames(1)
	var shown := p.model.state
	var len := p.model.getup_length(shown == "getup_front")
	t.check(len > 1.0 and len < 2.5, "levantar leva entre 1 e 2,5 s", "%.2f s" % len)
	var frames := 0
	while p.is_getting_up() and frames < 300:
		await t._frames(1)
		frames += 1
	t.check(not p.is_getting_up() and p.model.state == "idle" and p.model.is_weapon_visible("pistol"),
		"termina em pé, com a arma na mão", "%s em %d quadros" % [p.model.state, frames])
	t.check(t._body_ok(p.model).finite and p.is_on_floor(), "em pé no chão, sem NaN")


func test_hard_fall_collapses() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, Player.FALL_SAFE + 0.6, 0))
	await t._frames(1)
	var down := false
	for i in 120:
		await t._frames(1)
		if p.model.is_ragdoll():
			down = true
			break
	t.check(down and not p.dead and p.health < 100, "queda que machuca: ela desaba", "vida %d" % p.health)
	var up := false
	for i in 400:
		await t._frames(1)
		if not p.model.is_ragdoll() and not p.is_getting_up():
			up = true
			break
	t.check(up and p.model.state == "idle", "e levanta depois", p.model.state)
