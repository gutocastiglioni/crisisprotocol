extends "res://tests/ai_tests.gd"
## Testes do guerrilheiro encapuzado (Soldier): modelo próprio, patrulha, combate com tiros, morte, recuo, alarme em
## comum com os raptors e perda de rastro. Usa os auxiliares de ai_tests.gd; chamado por run_tests.gd.


func run(runner: SceneTree) -> void:
	t = runner
	await test_guerrilla_asset()
	await test_soldier_patrol_and_spot()
	await test_soldier_shoots_and_misses()
	await test_soldier_presses_fire()
	await test_soldier_dies()
	await test_soldier_backs_off()
	await test_shared_alarm()
	await test_soldier_loses_target()
	await test_soldier_drops()


func _spawn_soldier(player_pos: Vector3, soldier_pos := Vector3.ZERO, yaw := PI) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	w.add_child(p)
	var s := Soldier.new()
	s.position = soldier_pos
	s.rotation.y = yaw
	s.target = p
	w.add_child(s)
	s.rng.seed = 3
	await t._frames(2)
	return [p, s, w]


func test_guerrilla_asset() -> void:
	# o guerrilheiro encapuzado: mesmo esqueleto e animações da heroína (o HeroineModel serve aos dois), visual próprio
	var inst: Node = Soldier.BODY.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	var base: Node = (load("res://assets/characters/heroine.glb") as PackedScene).instantiate()
	var base_sk: Skeleton3D = base.find_children("*", "Skeleton3D", true, false)[0]
	var base_names := []
	for i in base_sk.get_bone_count():
		if not base_sk.get_bone_name(i).begins_with("Braid"):  # a trança dela é só dela
			base_names.append(base_sk.get_bone_name(i))
	check(names == base_names, "guerrilheiro: mesmo esqueleto da heroína (sem a trança)", str(names))
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	var base_ap: AnimationPlayer = base.find_children("*", "AnimationPlayer", true, false)[0]
	var missing := []
	for a in base_ap.get_animation_list():
		if not ap.has_animation(a):
			missing.append(a)
	check(missing.is_empty(), "guerrilheiro: todas as animações da heroína", str(missing))
	for w in ["Pistol", "M16", "Shotgun", "ShotgunPump", "Muzzle", "RifleMuzzle", "ShotgunMuzzle"]:
		check(inst.find_child(w, true, false) != null, "guerrilheiro: " + w)
	var tris := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.name in ["Pistol", "M16", "Shotgun", "ShotgunPump"]:
			continue
		var arr: Array = mi.mesh.surface_get_arrays(0)
		tris += (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	check(tris >= 800 and tris <= 5000, "guerrilheiro: orçamento de triângulos do PS2", str(tris))
	var img: Image = Soldier.ATLAS.get_image()
	check(img.get_size() == Vector2i(512, 512), "atlas do guerrilheiro 512x512", str(img.get_size()))
	var magenta := 0
	for y in range(0, 512, 8):
		for x in range(0, 512, 8):
			var c := img.get_pixel(x, y)
			if c.r > 0.95 and c.g < 0.05 and c.b > 0.95:
				magenta += 1
	check(magenta == 0, "atlas do guerrilheiro sem fundo magenta", str(magenta))
	# a cabeça é o capuz preto (nada de cabelo ruivo da heroína): o retângulo da cabeça é escuro
	var dark := 0.0
	var n := 0
	for y in range(8, 120, 6):
		for x in range(264, 504, 6):
			dark += img.get_pixel(x, y).get_luminance()
			n += 1
	check(dark / n < 0.25, "guerrilheiro: cabeça coberta por capuz escuro", str(dark / n))
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var s: Soldier = pr[1]
	check(s.model.scene == Soldier.BODY and s.model.atlas == Soldier.ATLAS, "soldado usa o modelo do guerrilheiro, não o da heroína")
	check(s.model.is_weapon_visible("m16") and not s.model.is_weapon_visible("pistol"), "guerrilheiro empunha o M16")
	inst.free()
	base.free()


func test_soldier_patrol_and_spot() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 19), Vector3(-5, 0, -5), -PI * 0.5)
	var s: Soldier = pr[1]
	s.route = [Vector3(-5, 0, -5), Vector3(5, 0, -5)]
	var states := {}
	var max_x := -99.0
	for i in 900:
		await t._frames(1)
		states[s.state] = true
		max_x = maxf(max_x, s.global_position.x)
	check(states.has("patrol") and states.has("look") and max_x > 4.0, "soldado patrulha a rota e para para olhar", "%s %.1f" % [str(states.keys()), max_x])
	check(s.model.state in ["idle", "walk"], "animação de andar/parado", s.model.state)
	# ela à vista a 8 m: desconfia, ergue a arma e entra em combate
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	s = pr[1]
	var seen := {}
	for i in 400:
		await t._frames(1)
		seen[s.state] = true
		if s.state == "engage":
			break
	check(seen.has("suspicious") and seen.has("alert") and s.state == "engage", "soldado: desconfia, reage, combate", str(seen.keys()))
	check(s.alert_level() == 2 and s._marker.text == "!", "soldado alertado mostra !", s._marker.text)


func test_soldier_shoots_and_misses() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	s.start_engage()
	await t._frames(5)
	for i in 600:
		await t._frames(1)
	check(s.shots_fired > 4, "no combate ele atira em rajadas", str(s.shots_fired))
	check(p.health < 100, "alguns tiros acertam", str(p.health))
	# rolando ela esquiva de todos
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	p = pr[0]
	s = pr[1]
	s.start_engage()
	p.rolling = true
	for i in 40:
		s._fire()
	check(p.health == 100, "cambalhota esquiva dos tiros", str(p.health))
	p.rolling = false
	# parede no meio: tiros batem nela
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	p = pr[0]
	s = pr[1]
	_wall(pr[2], Vector3(0, 2, 4))
	await t._frames(2)
	for i in 40:
		s._fire()
	check(p.health == 100, "parede no meio: nenhum tiro chega", str(p.health))


## Rajadas longas com descanso curto (sem pausas de segundos) e, quando ela some atrás de algo, um pouco de fogo de
## supressão onde ela estava, que não a acerta.
func test_soldier_presses_fire() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	p.health = 100000
	var clock := [0]
	var times: Array[int] = []
	s.fired.connect(func() -> void: times.append(clock[0]))
	s.start_engage()
	for i in 360:
		await t._frames(1)
		clock[0] = i
	var first := 0
	while first + 1 < times.size() and times[first + 1] - times[first] < 12:
		first += 1
	var longest := 0
	for i in range(1, times.size()):
		longest = maxi(longest, times[i] - times[i - 1])
	check(first + 1 >= Soldier.BURST_SHOTS[0], "rajada de pelo menos %d tiros" % Soldier.BURST_SHOTS[0], str(first + 1))
	check(times.size() >= 15, "atira muito em 6 s", str(times.size()))
	check(longest < 60, "nunca para mais de 1 s entre rajadas", "%d quadros" % longest)
	check(not times.is_empty() and times[0] < 45, "primeiro tiro logo depois de vê-la", str(times[0] if times.size() else -1))
	# ela some atrás de uma parede: ele ainda atira ali um pouco, sem acertar, e depois para
	var hp := p.health
	_wall(pr[2], Vector3(0, 2, 4))
	await t._frames(2)
	times.clear()
	for i in 150:
		await t._frames(1)
		clock[0] = i
	var early := times.filter(func(f: int) -> bool: return f < 70).size()
	var late := times.filter(func(f: int) -> bool: return f >= 100).size()
	check(early > 0, "perdeu de vista: fogo de supressão onde ela estava", str(times))
	check(late == 0, "supressão acaba", str(times))
	check(p.health == hp, "supressão bate na parede, não nela", str(hp - p.health))


func test_soldier_dies() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var s: Soldier = pr[1]
	var killed := [false]
	s.killed.connect(func() -> void: killed[0] = true)
	s.take_hit(34, Vector3.BACK, s.global_position + Vector3.UP)
	check(not s.dead and s.state == "hit" and s.alert_t > 0.0, "levou um tiro: reage e fica alerta", s.state)
	await t._frames(40)
	s.take_hit(34, Vector3.BACK, s.global_position + Vector3.UP)
	check(s.dead and s.state == "dead" and killed[0], "morre com a vida zerada")
	check(s.collision_layer == 0 and s.model.is_ragdoll(), "vira ragdoll e sai da física")
	check(s.alert_level() == 0 and not s._marker.visible, "morto não alerta")
	await t._frames(30)
	check(is_finite(s.model.ragdoll.bodies["Hips"].global_position.y), "ragdoll sem NaN")
	await t._frames(180)
	check(s.global_position.y > -0.5 and s.model.skeleton.global_position.y > -0.5, "morto não afunda no chão (o corpo não some)", str(s.global_position))
	s.reset()
	await t._frames(3)
	check(not s.dead and s.health == Soldier.MAX_HEALTH and s.collision_layer == 2 and not s.model.is_ragdoll(), "reset: de pé e vivo")


func test_soldier_backs_off() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 3.2))
	var p: Player = pr[0]
	p.health = 100000
	var s: Soldier = pr[1]
	s.start_engage()
	var d0 := s.global_position.distance_to(p.global_position)
	await t._frames(90)
	check(s.global_position.distance_to(p.global_position) > d0 + 0.5, "ela chega perto: ele recua", "%.1f -> %.1f" % [d0, s.global_position.distance_to(p.global_position)])
	check(s.model.state in ["walk", "strafe_l", "strafe_r", "idle"], "recua sem virar de costas (mirando)", s.model.state)


func test_shared_alarm() -> void:
	# o grito de um raptor chama o soldado, e o soldado que a vê chama o raptor
	var pr := await _spawn(Vector3(0, 0, 8))
	var w: Node3D = pr[2]
	var r: Raptor = pr[1]
	var s := Soldier.new()
	s.position = Vector3(-18, 0, -10)
	s.target = pr[0]
	w.add_child(s)
	await t._frames(2)
	for i in 300:
		await t._frames(1)
		if r.state == "roar":
			break
	for i in 120:
		await t._frames(1)
		if s.state == "hunt":
			break
	check(s.state == "hunt" and s.alert_level() == 2, "raptor grita: o soldado vem caçar", s.state)
	pr = await _spawn_soldier(Vector3(0, 0, 8))
	w = pr[2]
	s = pr[1]
	r = Raptor.new()
	r.position = Vector3(-18, 0, -10)
	r.target = pr[0]
	w.add_child(r)
	await t._frames(2)
	for i in 400:
		await t._frames(1)
		if s.state in Soldier.COMBAT:
			break
	for i in 120:
		await t._frames(1)
		if r.state == "hunt":
			break
	check(r.state == "hunt" and r.alert_level() == 2, "soldado a vê: o raptor vem caçar", r.state)


func test_soldier_loses_target() -> void:
	var pr := await _spawn_soldier(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	_wall(pr[2], Vector3(0, 2, 12))
	s.start_engage()
	await t._frames(5)
	p.health = 100000
	p.global_position = Vector3(0, 0, 19)
	p.reset_physics_interpolation()
	var hunted := false
	for i in 600:
		await t._frames(1)
		if s.state == "hunt":
			hunted = true
			break
	check(hunted, "perde a heroína de vista: vai ao último lugar", s.state)
	var searched := false
	for i in 900:
		await t._frames(1)
		if s.state == "search":
			searched = true
			break
	check(searched, "chega e procura", s.state)


func test_soldier_drops() -> void:
	GameMode.set_mode(GameMode.SURVIVAL)
	var pr := await _spawn_soldier(Vector3(0, 0, -6))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	var w: Node3D = pr[2]
	p.reset_loadout()
	check(p.weapons == ["pistol"], "comeca apenas com pistola")
	s.take_hit(100, Vector3.BACK, s.global_position + Vector3.UP)
	await t._frames(10)
	check(s.dead and s.model.holstered, "soldado morre e solta a arma da mao")
	var drops := w.find_children("*", "Pickup", true, false)
	check(drops.size() >= 1, "soldado dropa item no mundo", str(drops.size()))
	var drop: Pickup = drops[0]
	check(drop.is_weapon and drop.kind == "m16" and drop.amount == 15, "drop e o fuzil M16 com 15 balas")
	# Jogadora passa por cima e pega a arma
	p.global_position = drop.global_position
	await t._frames(5)
	check("m16" in p.weapons and p.weapon() == "m16", "jogadora pegou o fuzil dropado do soldado")
	check(p.ammo_of("m16") == 15, "jogadora recebeu as 15 balas da arma dropada", str(p.ammo_of("m16")))
	# Segundo soldado dropa municao
	var s2 := Soldier.new()
	s2.position = Vector3(5, 0, 0)
	s2.drop_is_weapon = false
	s2.drop_kind = "shotgun"
	s2.drop_amount = 6
	s2.target = p
	w.add_child(s2)
	s2.take_hit(100, Vector3.BACK, s2.global_position + Vector3.UP)
	await t._frames(10)
	var drops2 := w.find_children("*", "Pickup", true, false)
	var ammo_drop: Pickup = null
	for d in drops2:
		if not d.is_weapon and d.kind == "shotgun":
			ammo_drop = d
			break
	check(ammo_drop != null and ammo_drop.amount == 6, "segundo soldado dropou caixa de municao de escopeta")
	p.global_position = ammo_drop.global_position
	await t._frames(5)
	check(p.ammo_of("shotgun") == 6, "jogadora coletou a municao dropada", str(p.ammo_of("shotgun")))
	# Sniper dropa o rifle Sniper
	var sn := Sniper.new()
	sn.position = Vector3(-5, 0, 0)
	sn.target = p
	w.add_child(sn)
	sn.take_hit(100, Vector3.BACK, sn.global_position + Vector3.UP)
	await t._frames(10)
	check(sn.dead and sn.model.holstered, "sniper morre e solta o fuzil de precisao")
	var drops3 := w.find_children("*", "Pickup", true, false)
	var sniper_drop: Pickup = null
	for d in drops3:
		if d.is_weapon and d.kind == "sniper":
			sniper_drop = d
			break
	check(sniper_drop != null and sniper_drop.amount == 5, "sniper dropou o fuzil Sniper com 5 balas")
	p.global_position = sniper_drop.global_position
	await t._frames(5)
	check("sniper" in p.weapons and p.weapon() == "sniper", "jogadora pegou o rifle Sniper dropado")
	check(p.ammo_of("sniper") == 5, "jogadora recebeu municao do Sniper", str(p.ammo_of("sniper")))
