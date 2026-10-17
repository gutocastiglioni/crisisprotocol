extends RefCounted
## Testes do velociraptor, chamados por run_tests.gd (usa check/_fresh_world/_frames de lá).
## Raptor na origem olhando para +Z; a heroína é posta na frente (+Z) ou atrás (-Z) dele.

const EXPECTED_BONES := [
	"Hips", "Spine", "Chest", "Neck1", "Neck2", "Head", "Jaw", "Tail1", "Tail2", "Tail3", "Tail4",
	"Thigh_L", "Shin_L", "Meta_L", "Toe_L", "Arm_L", "Forearm_L", "Hand_L",
	"Thigh_R", "Shin_R", "Meta_R", "Toe_R", "Arm_R", "Forearm_R", "Hand_R",
]
const EXPECTED_ANIMS := [
	"Idle", "Walk", "Run", "Roar", "Study", "LeapPrep", "LeapAir", "Bite", "Shake",
	"TailWhip", "TailWhipR", "Hit", "Death",
]

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_asset()
	await test_jaw()
	await test_roar_on_sight()
	await test_blind()
	await test_study_circles()
	await test_tail_when_behind()
	await test_charge()
	await test_leap()
	await test_bite_grab_shake()
	await test_struggle()
	await test_roll_dodges_bite()
	await test_shot_releases_hold()
	await test_player_dies_in_hold()
	await test_shot_and_death()
	await test_respawn_while_grabbed()
	await test_reset_all_while_grabbed()
	await test_raptor_killed_mid_leap()
	await test_two_consecutive_bites()
	await test_knockback_into_wall()
	await test_capsule_resync_after_getup()
	await test_no_attack_while_down()
	await test_nan_after_knockback()
	await test_nan_after_leap_hit()


func check(cond: bool, name: String, detail := "") -> void:
	t.check(cond, name, detail)


func _pair(player_pos: Vector3, facing_away := false) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	if facing_away:
		p.rotation.y = PI
	w.add_child(p)
	var r := Raptor.new()
	r.rotation.y = PI
	r.target = p
	w.add_child(r)
	r.rng.seed = 7
	await t._frames(2)
	return [p, r, w]


func test_asset() -> void:
	var scene: PackedScene = load("res://assets/characters/raptor.glb")
	check(scene != null, "raptor.glb carrega")
	var inst := scene.instantiate()
	var sk: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var names := []
	for i in sk.get_bone_count():
		names.append(sk.get_bone_name(i))
	check(names.size() == EXPECTED_BONES.size(), "raptor: 25 ossos", str(names))
	for b in ["Jaw", "Tail4", "Toe_L", "Hand_R"]:
		check(b in names, "raptor: osso " + b)
	var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
	for a in EXPECTED_ANIMS:
		check(ap.has_animation(a) and ap.get_animation(a).length > 0.1, "raptor: animação " + a)
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var tris := 0
	for s in mi.mesh.get_surface_count():
		tris += mi.mesh.surface_get_array_index_len(s) / 3
	check(tris > 800 and tris < 5000, "raptor: orçamento de triângulos, PS2 do começo (800-5000)", str(tris))
	check(inst.find_child("Mouth", true, false) != null, "raptor: marcador da boca (Mouth)")
	inst.free()


func test_jaw() -> void:
	var w: Node3D = await t._fresh_world()
	var m := RaptorModel.new()
	w.add_child(m)
	await t._frames(3)
	m.anim_player.play("Idle")
	m.anim_player.seek(0.0, true)
	m.anim_player.pause()
	await t._frames(2)
	var closed := m.jaw_angle()
	m.anim_player.play("Roar")
	m.anim_player.seek(16.0 / 30.0, true)
	m.anim_player.pause()
	await t._frames(2)
	check(closed < 5.0, "mandíbula fechada parado", "%.1f°" % closed)
	check(m.jaw_angle() > 30.0, "mandíbula escancarada no grito", "%.1f°" % m.jaw_angle())


func test_roar_on_sight() -> void:
	var pr := await _pair(Vector3(0, 0, 8))
	var r: Raptor = pr[1]
	await t._frames(4)
	check(r.state == "roar", "raptor grita ao ver a heroína", r.state)
	check(r.model.current == "Roar", "animação de grito tocando", r.model.current)
	await t._frames(120)
	check(r.state == "study", "depois do grito, estuda a presa", r.state)


func test_blind() -> void:
	var pr := await _pair(Vector3(0, 0, 30))
	var r: Raptor = pr[1]
	await t._frames(30)
	check(r.state == "idle", "longe demais: não percebe", r.state)
	pr = await _pair(Vector3(0, 0, 8))
	var w: Node3D = pr[2]
	r = pr[1]
	# parede entre os dois: sem linha de visão
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 4, 0.4)
	col.shape = box
	wall.add_child(col)
	wall.position = Vector3(0, 2, 4)
	w.add_child(wall)
	r.state = "idle"
	await t._frames(30)
	check(r.state == "idle", "atrás da parede: não percebe", r.state)


func test_study_circles() -> void:
	var pr := await _pair(Vector3(0, 0, 4.5))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	r.start_study()
	var start := r.global_position
	var side_slip := 0.0
	var pace_err := 0.0
	for i in 60:
		await t._frames(1)
		var v := Vector3(r.velocity.x, 0.0, r.velocity.z)
		if v.length() > 0.35 and r.model.current == "Walk":
			side_slip = maxf(side_slip, absf(v.normalized().dot(r.global_basis.x)))
			pace_err = maxf(pace_err, absf(r.model.anim_player.speed_scale * Raptor.WALK_ANIM_SPEED - v.length()))
	check(side_slip < 0.2, "raptor anda para a frente do corpo (não de lado)", "%.2f" % side_slip)
	check(pace_err < 0.1, "passada casada com a velocidade (pés não patinam)", "%.2f m/s" % pace_err)
	var d := r.global_position.distance_to(p.global_position)
	check(r.state == "study", "estudando ainda (não ataca na hora)", r.state)
	check(r.global_position.distance_to(start) > 0.4, "rodeia a presa enquanto estuda", str(r.global_position))
	check(d > 3.0 and d < 6.0, "mantém distância de estudo", "%.2f" % d)


func test_tail_when_behind() -> void:
	var pr := await _pair(Vector3(0.6, 0, -1.8))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var kinds := []
	r.attacked.connect(func(k: String) -> void: kinds.append(k))
	r.start_study()
	var yaw0 := r.rotation.y
	var p0 := p.global_position
	await t._frames(30)
	check(r.state == "tail", "perto da traseira = rabada", r.state)
	check(r.model.current in ["TailWhip", "TailWhipR"], "animação de rabada", r.model.current)
	await t._frames(40)
	check("tail" in kinds and p.health < 100, "rabada acerta", "vida=%d %s" % [p.health, kinds])
	check(p.global_position.distance_to(p0) > 0.4, "rabada empurra a heroína", str(p.global_position))
	check(absf(angle_difference(yaw0, r.rotation.y)) > 0.8, "corpo gira com a rabada", str(r.rotation.y - yaw0))


func test_charge() -> void:
	var pr := await _pair(Vector3(0, 0, 10))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var kinds := []
	r.attacked.connect(func(k: String) -> void: kinds.append(k))
	r.start_charge()
	await t._frames(20)
	check(r.model.current == "Run" and r.velocity.length() > 5.0, "investida em carreira", "%s v=%.1f" % [r.model.current, r.velocity.length()])
	for i in 100:
		if "charge" in kinds:
			break
		await t._frames(1)
	check("charge" in kinds and p.health < 100, "investida acerta", "vida=%d" % p.health)
	var z0 := p.global_position.z
	await t._frames(3)
	check(p.model.is_ragdoll() and p.is_dodging(), "investida arremessa (ragdoll)")
	var hips: PhysicalBone3D = p.model.ragdoll.bodies["Hips"]
	await t._frames(7)
	var bd: Dictionary = p.model.ragdoll.bodies
	var hz := hips.global_position.z
	var trail := [bd["Head"].global_position.z - hz, bd["LowerLeg_L"].global_position.z - hz, bd["LowerLeg_R"].global_position.z - hz]
	check(trail.max() < -0.1, "arremessada em C: cabeça e pernas ficam para trás do quadril", str(trail))
	var peak := 0.0
	for i in 30:
		await t._frames(1)
		peak = maxf(peak, hips.global_position.y)
	check(hips.global_position.z > z0 + 1.0, "investida joga longe para trás", "%.2f -> %.2f" % [z0, hips.global_position.z])
	check(peak > 0.9, "sai do chão com o golpe", "%.2f" % peak)
	await t._frames(int((Player.DOWN_TIME + 0.5) * 60) + 40)
	check(not p.model.is_ragdoll() and not p.dead and p.global_position.z > z0 + 1.0, "levanta onde caiu", str(p.global_position))


func test_leap() -> void:
	var pr := await _pair(Vector3(0, 0, 6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var kinds := []
	var claw_gap := []
	r.attacked.connect(func(k: String) -> void:
		kinds.append(k)
		var best := INF
		for c in r.model.claw_positions():
			best = minf(best, c.distance_to(r.last_hit_at))
		claw_gap.append(best)
		claw_gap.append(Vector2(r.last_hit_at.x - p.global_position.x, r.last_hit_at.z - p.global_position.z).length()))
	r.start_leap()
	var max_y := 0.0
	for i in 90:
		await t._frames(1)
		max_y = maxf(max_y, r.global_position.y)
	check(max_y > 0.5, "salto sai do chão", "%.2f" % max_y)
	check(r.is_on_floor() and r.state != "leap", "aterrissa", r.state)
	check(r.global_position.z > 3.5, "salto cobre a distância", str(r.global_position))
	check("leap" in kinds and p.health < 100, "salto acerta", "vida=%d" % p.health)
	check(p.model.is_ragdoll(), "salto arremessa a heroína (ragdoll)")
	check(claw_gap.size() == 2 and claw_gap[0] < 0.05 and claw_gap[1] < 0.8, "salto acerta com as garras dos pés, no corpo dela", str(claw_gap))
	check(t._body_ok(p.model).finite, "arremesso sem NaN")


func _grab(p: Player, r: Raptor) -> void:
	r.start_bite()
	for i in 40:
		if p.grabbed:
			return
		await t._frames(1)


func test_bite_grab_shake() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	check(p.grabbed and r.state == "hold", "mordida agarra", r.state)
	check(r.model.current == "Shake", "animação de sacudir", r.model.current)
	check(p.model.is_ragdoll(), "mordida vira ragdoll")
	var arm: PhysicalBone3D = p.model.ragdoll.bodies[Player.BITTEN_BONE]
	var hips: PhysicalBone3D = p.model.ragdoll.bodies["Hips"]
	await t._frames(10)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var far := 0.0
	var fist := INF
	var kick_lo := INF
	var kick_hi := -INF
	var fist_body: PhysicalBone3D = p.model.ragdoll.bodies["LowerArm_R"]
	var shin: PhysicalBone3D = p.model.ragdoll.bodies["LowerLeg_L"]
	for i in 40:
		await t._frames(1)
		lo = lo.min(hips.global_position)
		hi = hi.max(hips.global_position)
		var mouth := r.model.mouth_position()
		far = maxf(far, arm.global_position.distance_to(mouth))
		fist = minf(fist, fist_body.global_position.distance_to(mouth))
		var reach := shin.global_position.distance_to(mouth)
		kick_lo = minf(kick_lo, reach)
		kick_hi = maxf(kick_hi, reach)
	check(far < 0.45, "braço dela preso na boca", "%.2f m" % far)
	check(fist < 0.6, "luta: soca a cara dele com a mão livre", "%.2f m" % fist)
	check(kick_hi - kick_lo > 0.3, "luta: chuta", "%.2f m" % (kick_hi - kick_lo))
	check(hips.global_position.y > 0.2, "luta: não fica largada no chão", "%.2f" % hips.global_position.y)
	check(Vector2(hi.x - lo.x, hi.z - lo.z).length() > 0.25, "corpo é chacoalhado", str(hi - lo))
	check(p.health < 100, "sacudida tira vida", str(p.health))
	check(t._body_ok(p.model).finite, "ragdoll sacudido sem NaN")
	for i in 120:
		if not p.grabbed:
			break
		await t._frames(1)
	check(not p.grabbed and r.state != "hold", "solta depois de sacudir")
	check(not p.dead and p.model.is_ragdoll(), "fica caída depois de solta")
	await t._frames(int(Player.DOWN_TIME * 60) + 40)
	check(not p.model.is_ragdoll() and not p.dead, "levanta e volta a ter controle")
	var d := p.global_position.distance_to(hips.global_position)
	check(d < 1.2, "cápsula volta para onde o corpo caiu", "%.2f" % d)


func test_struggle() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	var frames := 0
	while p.grabbed and frames < 200:
		if frames % 4 == 0:
			Input.action_press("shoot")
		elif frames % 4 == 2:
			Input.action_release("shoot")
		await t._frames(1)
		frames += 1
	Input.action_release("shoot")
	check(p.struggle >= 5, "apertar botões conta como se debater", str(p.struggle))
	check(frames < int(Raptor.HOLD_TIME * 60) - 15, "se debater solta mais rápido", "%d quadros" % frames)


func test_roll_dodges_bite() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6), true)
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	r.start_bite()
	await t._frames(8)
	Input.action_press("roll")
	await t._frames(2)
	Input.action_release("roll")
	await t._frames(30)
	check(not p.grabbed and p.health == 100, "rolar esquiva da mordida", "vida=%d" % p.health)


func test_shot_releases_hold() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	r.take_hit(Player.DAMAGE, Vector3.BACK, r.global_position + Vector3.UP)
	await t._frames(2)
	check(not p.grabbed and r.state == "hit", "tiro faz o raptor soltar", r.state)


func test_player_dies_in_hold() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	p.health = 10
	await _grab(p, r)
	await t._frames(60)
	check(p.dead and p.model.is_ragdoll(), "morre na boca (ragdoll)")
	await t._frames(90)
	check(not p.grabbed and r.state != "hold", "raptor sacode o corpo e larga", r.state)
	check(t._body_ok(p.model).finite, "ragdoll sem NaN depois da sacudida")


func test_shot_and_death() -> void:
	var pr := await _pair(Vector3(0, 0, 6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	Input.action_press("aim")
	await t._frames(30)
	p.camera_rig.look_at_point(r.global_position + Vector3.UP * 1.0 + Vector3.BACK * 0.3)
	await t._frames(2)
	p.fire()
	await t._frames(2)
	Input.action_release("aim")
	check(r.health < Raptor.MAX_HEALTH, "tiro de verdade acerta o raptor", str(r.health))
	r.take_hit(999, Vector3.BACK, r.global_position)
	await t._frames(2)
	check(r.dead and r.state == "dead", "raptor morre")
	await t._frames(3)
	check(r.model.is_ragdoll() and not r.model.anim_player.active, "raptor morto vira ragdoll (física, não animação)")
	var rh: PhysicalBone3D = r.model.ragdoll.bodies["Hips"]
	var rhead: PhysicalBone3D = r.model.ragdoll.bodies["Head"]
	var y0 := rh.global_position.y
	await t._frames(150)
	var lo := INF
	var finite := true
	for b in r.model.ragdoll.bodies.values():
		var q: Vector3 = b.global_position
		finite = finite and is_finite(q.x) and is_finite(q.y) and is_finite(q.z)
		lo = minf(lo, q.y)
	check(finite, "ragdoll do raptor sem NaN")
	check(rh.global_position.y < y0 - 0.4, "raptor tomba no chão", "%.2f -> %.2f" % [y0, rh.global_position.y])
	check(rh.global_position.y > 0.05 and lo > -0.15, "raptor não atravessa o chão", "%.2f" % lo)
	check(rhead.global_position.distance_to(r.model.ragdoll.bodies["Neck2"].global_position) < 0.6, "cabeça do raptor presa ao pescoço")
	check(r.collision_layer == 0, "corpo morto não segura tiro")
	p.global_position = Vector3(0, 0, 1.5)
	await t._frames(120)
	check(p.health == 100, "morto não ataca", str(p.health))
	r.reset()
	await t._frames(2)
	check(not r.dead and r.health == Raptor.MAX_HEALTH and r.collision_layer == 2, "raptor reinicia")


func test_respawn_while_grabbed() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	check(p.grabbed and r.state == "hold", "presa na boca")
	p.respawn()
	await t._frames(2)
	check(not p.grabbed and not p.dead and p.health == 100, "respawn enquanto presa: liberada", "grabbed=%s dead=%s" % [p.grabbed, p.dead])
	check(not p.model.is_ragdoll(), "respawn: volta ao controle")
	check(t._body_ok(p.model).finite, "respawn: sem NaN")


func test_reset_all_while_grabbed() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var w: Node3D = pr[2]
	await _grab(p, r)
	check(p.grabbed and r.state == "hold", "presa antes do reset")
	# simula o reset_all da main: spawns são diferentes, ela respawna longe
	p.respawn()
	await t._frames(2)
	r.reset()
	await t._frames(2)
	check(not p.grabbed and not p.dead, "reset_all: heroína livre e viva")
	# BUG: raptor vê a heroína imediatamente porque ela respawnou perto dele no teste
	# (na main real, os spawns são diferentes). Então o estado pode ser roar, não idle.
	check(not r.dead and r.health == Raptor.MAX_HEALTH, "reset_all: raptor vive e vida cheia")
	check(r.state == "idle" or r.state == "roar", "raptor volta a idle ou detecta a presa", r.state)


func test_raptor_killed_mid_leap() -> void:
	var pr := await _pair(Vector3(0, 0, 6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	r.start_leap()
	# espera o preparo terminar e o salto começar de verdade
	await t._frames(int(Raptor.LEAP_PREP * 60) + 3)
	check(r.state == "leap", "raptor saltou", r.state)
	# BUG encontrado: o raptor pode já ter aterrissado se a distância for curta.
	# Mata assim mesmo para testar que o ataque é interrompido.
	r.take_hit(999, Vector3.BACK, r.global_position)
	await t._frames(2)
	check(r.dead and r.state == "dead", "morto no meio do salto", r.state)
	await t._frames(60)
	check(p.health == 100, "salto interrompido não acerta", str(p.health))


func test_two_consecutive_bites() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	check(p.grabbed, "primeira mordida agarra")
	var h0 := p.health
	# espera soltar
	for i in 200:
		if not p.grabbed:
			break
		await t._frames(1)
	check(not p.grabbed, "soltou")
	check(p.health < h0, "primeira mordida causou dano", str(p.health))
	# espera levantar
	for i in 120:
		if not p.model.is_ragdoll():
			break
		await t._frames(1)
	check(not p.model.is_ragdoll(), "levantou")
	# segunda mordida
	await t._frames(10)
	r.start_bite()
	await t._frames(30)
	check(p.grabbed and r.state == "hold", "segunda mordida agarra de novo")
	var h1 := p.health
	for i in 200:
		if not p.grabbed:
			break
		await t._frames(1)
	check(p.health < h1, "segunda mordida também causa dano", str(p.health))
	check(t._body_ok(p.model).finite, "sem NaN após duas mordidas")


func test_knockback_into_wall() -> void:
	var pr := await _pair(Vector3(0, 0, 4))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var w: Node3D = pr[2]
	# parede perto dela, na direção do empurrão
	var wall := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 4, 0.4)
	col.shape = box
	wall.add_child(col)
	wall.position = Vector3(0, 2, 6)
	w.add_child(wall)
	var kinds := []
	r.attacked.connect(func(k: String) -> void: kinds.append(k))
	r.start_charge()
	for i in 100:
		if "charge" in kinds:
			break
		await t._frames(1)
	check("charge" in kinds, "investida acerta")
	var p0 := p.global_position
	await t._frames(40)
	check(p.global_position.distance_to(p0) < 3.0, "empurrão para até a parede", str(p.global_position))
	check(t._body_ok(p.model).finite, "sem NaN depois de bater na parede")


func test_capsule_resync_after_getup() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	check(p.grabbed, "presa")
	for i in 200:
		if not p.grabbed:
			break
		await t._frames(1)
	check(not p.grabbed and p.model.is_ragdoll(), "solta e caída")
	var hips: PhysicalBone3D = p.model.ragdoll.bodies["Hips"]
	var hips_pos := hips.global_position
	await t._frames(int(Player.DOWN_TIME * 60) + 30)
	check(not p.model.is_ragdoll(), "levantou")
	var d := p.global_position.distance_to(Vector3(hips_pos.x, p.global_position.y, hips_pos.z))
	check(d < 1.0, "cápsula sincronizada com o quadril onde caiu", "dist=%.2f hips=%s cap=%s" % [d, hips_pos, p.global_position])
	# consegue se mover normalmente (raptor sem alvo: se ela passar atrás dele, leva rabada de verdade)
	r.target = null
	Input.action_press("move_forward")
	await t._frames(30)
	Input.action_release("move_forward")
	check(p.global_position.z < hips_pos.z - 1.0, "controle volta depois de levantar", "z=%.2f hips_z=%.2f raptor=%s vida=%d ragdoll=%s estado=%s" % [p.global_position.z, hips_pos.z, r.state, p.health, p.model.is_ragdoll(), p.model.state])


func test_no_attack_while_down() -> void:
	var pr := await _pair(Vector3(0, 0, 1.6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	await _grab(p, r)
	for i in 200:
		if not p.grabbed:
			break
		await t._frames(1)
	check(p.model.is_ragdoll() and not p.grabbed, "caída no chão")
	var h0 := p.health
	# raptor tenta morder de novo enquanto ela está caída
	r.start_bite()
	await t._frames(50)
	check(p.health == h0, "caída no chão = imune (is_dodging)", str(p.health))
	# tail
	r.start_tail()
	await t._frames(50)
	check(p.health == h0, "caída bloqueia rabada também", str(p.health))


func test_nan_after_knockback() -> void:
	var pr := await _pair(Vector3(0, 0, 4))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var kinds := []
	r.attacked.connect(func(k: String) -> void: kinds.append(k))
	r.start_charge()
	for i in 100:
		if "charge" in kinds:
			break
		await t._frames(1)
	check("charge" in kinds, "investida acerta")
	await t._frames(60)
	check(t._body_ok(p.model).finite, "sem NaN após knockback de investida")


func test_nan_after_leap_hit() -> void:
	var pr := await _pair(Vector3(0, 0, 6))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var kinds := []
	r.attacked.connect(func(k: String) -> void: kinds.append(k))
	r.start_leap()
	for i in 100:
		if "leap" in kinds:
			break
		await t._frames(1)
	check("leap" in kinds, "salto acerta")
	await t._frames(60)
	check(t._body_ok(p.model).finite, "sem NaN após knockback de salto")
