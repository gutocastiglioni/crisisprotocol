extends "res://tests/ai_tests.gd"
## Testes dos efeitos sonoros (Sfx, Soundscape): arquivos gerados batem com a tabela, o tocador fica no lugar certo e
## some no fim, limite por quadro, e cada evento do jogo toca o seu som (tiro, telha, passos no concreto e na grama,
## baú, raptor, guerrilheiro, avisos de furtividade e ambiente). Usa os auxiliares de ai_tests.gd; chamado por run_tests.gd.


func run(runner: SceneTree) -> void:
	t = runner
	test_files()
	await test_player_node()
	await test_frame_cap()
	await test_shots_and_pump()
	await test_footsteps()
	await test_grass_steps()
	await test_chest_and_pickup()
	await test_raptor_sounds()
	await test_soldier_sounds()
	await test_soundscape()


func _count(name: String) -> int:
	return int(Sfx.played.get(name, 0))


func test_files() -> void:
	var expected := {}
	var bad := []
	for name: String in Sfx.SOUNDS:
		var s: Dictionary = Sfx.SOUNDS[name]
		var n := int(s.n)
		for i in range(1, n + 1) if n > 0 else [0]:
			var file := name + ("_%d" % i if n > 0 else "") + ".wav"
			expected[file] = true
			var st := load(Sfx.DIR + file) as AudioStreamWAV
			if st == null or st.stereo or st.mix_rate != 22050 or st.get_length() < 0.15:
				bad.append(file)
	check(bad.is_empty(), "sons da tabela existem (WAV mono 22050 Hz)", str(bad))
	var extra := []
	for f in DirAccess.get_files_at(Sfx.DIR):
		if f.ends_with(".wav") and not expected.has(f):
			extra.append(f)
	check(extra.is_empty(), "nenhum WAV fora da tabela (make_sounds.py e sfx.gd batem)", str(extra))
	var amb := Sfx.stream("amb_yard")
	check(amb.loop_mode == AudioStreamWAV.LOOP_FORWARD and amb.loop_end > 22050 * 5, "ambiente em loop", str(amb.loop_end))


func test_player_node() -> void:
	var w: Node3D = await t._fresh_world()
	var at := Vector3(3, 1, -2)
	var p := Sfx.play(w, "impact_concrete", at)
	check(p != null and p.get_parent() == w and p.global_position.distance_to(at) < 0.01 and p.playing,
		"Sfx.play: tocador 3D no ponto pedido, tocando", str(p.global_position if p else null))
	check(p.stream.resource_path.begins_with(Sfx.DIR + "impact_concrete_"), "variação sorteada do som", p.stream.resource_path)
	await t._frames(int((p.stream.get_length() / p.pitch_scale + 0.3) * 60))
	check(not is_instance_valid(p), "tocador some quando o som acaba")


func test_frame_cap() -> void:
	var w: Node3D = await t._fresh_world()
	await t._frames(1)
	var made := 0
	for i in 8:
		if Sfx.play(w, "impact_metal", Vector3(i, 0, 0)):
			made += 1
	check(made == Sfx.MAX_PER_FRAME, "8 iguais no mesmo quadro (chumbos) tocam no máximo %d" % Sfx.MAX_PER_FRAME, str(made))
	await t._frames(1)
	check(Sfx.play(w, "impact_metal", Vector3.ZERO) != null, "no quadro seguinte volta a tocar")


func test_shots_and_pump() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 3))
	await t._frames(10)
	Sfx.played.clear()
	p.fire()
	check(_count("pistol_shot") == 1, "tiro da pistola toca pistol_shot", str(Sfx.played))
	await t._frames(80)
	check(_count("casing_brass") == 1, "cápsula de latão bate no chão", str(Sfx.played))
	p.give_weapon("shotgun")
	await t._frames(20)
	Sfx.played.clear()
	p.fire()
	check(_count("shotgun_shot") == 1, "tiro da escopeta toca shotgun_shot", str(Sfx.played))
	await t._frames(50)
	check(_count("shotgun_pump_back") == 1 and _count("shotgun_pump_fwd") == 1, "bombeamento: ida e volta da telha", str(Sfx.played))
	await t._frames(70)
	check(_count("casing_shell") == 1, "cartucho da escopeta bate no chão", str(Sfx.played))
	Sfx.played.clear()
	p.switch_weapon()
	await t._frames(2)
	check(_count("weapon_switch") == 1, "trocar de arma faz o clique", str(Sfx.played))
	Sfx.played.clear()
	p.take_hit(10, Vector3.FORWARD, p.global_position + Vector3.UP)
	check(_count("impact_flesh") == 1, "levar golpe toca a pancada", str(Sfx.played))


## Passos tocados por `p` em `frames` quadros segurando frente (com `extra` apertado).
func _walk_steps(p: Player, frames: int, extra := "") -> Dictionary:
	if extra != "":
		Input.action_press(extra)
	Input.action_press("move_forward")
	await t._frames(20)
	Sfx.played.clear()
	var vols: Array[float] = []
	var seen := {}
	for i in frames:
		await t._frames(1)
		for c in p.model.get_children():
			if c is AudioStreamPlayer3D and not seen.has(c) and str(c.stream.resource_path).contains("step_"):
				seen[c] = true
				vols.append(c.volume_db)
	Input.action_release("move_forward")
	if extra != "":
		Input.action_release(extra)
	await t._frames(20)
	return {"n": _count("step_concrete") + _count("step_grass"), "grass": _count("step_grass"), "db": vols}


func test_footsteps() -> void:
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	var run: Dictionary = await _walk_steps(p, 64)  # 64 quadros = 2 ciclos de corrida (0,53 s cada) = 4 passos
	check(run.n >= 3 and run.n <= 5, "correndo: um passo por pé que desce (4 em 2 ciclos)", str(run))
	var walk: Dictionary = await _walk_steps(p, 120, "walk")  # 2 s andando = 2 ciclos = 4 passos
	check(walk.n >= 3 and walk.n <= 5, "andando: um passo por pé que desce", str(walk))
	p.crouching = true
	var crouch: Dictionary = await _walk_steps(p, 128)
	p.crouching = false
	check(crouch.n >= 3, "agachada também faz passos", str(crouch))
	var loud := func(d: Dictionary) -> float: return (d.db as Array).max() if not (d.db as Array).is_empty() else -99.0
	check(loud.call(run) > loud.call(walk) and loud.call(walk) > loud.call(crouch), "correndo > andando > agachada (volume)",
		"%s %s %s" % [run.db, walk.db, crouch.db])
	# parada não faz passo
	Sfx.played.clear()
	await t._frames(60)
	check(_count("step_concrete") == 0, "parada: sem passos", str(Sfx.played))


func test_grass_steps() -> void:
	var w: Node3D = await t._fresh_world()
	for c in w.get_children():
		if c is StaticBody3D:
			c.set_meta("step", "grass")
	var p: Player = t._spawn_player(w)
	await t._frames(10)
	var run: Dictionary = await _walk_steps(p, 64)
	check(run.n >= 3 and run.grass == run.n, "chão com meta step=grass: passos na grama", str(run))


func test_chest_and_pickup() -> void:
	var w: Node3D = await t._fresh_world()
	var c := Chest.new()
	w.add_child(c)
	var p: Player = t._spawn_player(w, c.kneel_transform().origin + Vector3(0, 0, 0.3))
	await t._frames(10)
	Sfx.played.clear()
	p.moves.start_pickup(c)
	await t._frames(2)
	check(_count("chest_open") == 1, "abrir o baú range a tampa", str(Sfx.played))
	await t._frames(int(float(Moves.data().rifle.pickup_frames) / Moves.fps() * 60) + 10)
	check(_count("weapon_pickup") == 1 and p.weapon() == "m16", "pegar a arma faz o barulho do fuzil", str(Sfx.played))
	check(_count("weapon_switch") == 0, "pegar a arma do baú não faz o clique de troca", str(Sfx.played))


func test_raptor_sounds() -> void:
	# ela na frente dele e à vista: rugido; depois anda (passos com garras); levando tiro: dor; morrendo: grito
	var pr := await _spawn(Vector3(0, 0, 4))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	Sfx.played.clear()
	r.spot()
	await t._frames(2)
	check(_count("raptor_roar") == 1, "raptor vê a presa: rugido", str(Sfx.played))
	# só a animação de corrida (no lugar, durante o rugido): uma investida de verdade podia derrubá-la
	r.model.play("Run", 0.1, 1.0)
	await t._frames(45)
	check(_count("raptor_step") >= 2, "raptor correndo: passos", str(Sfx.played))
	r.start_tail()
	await t._frames(20)
	check(_count("tail_whoosh") == 1, "rabada: assobio da cauda", str(Sfx.played))
	Sfx.played.clear()
	r.start_study()
	r.take_hit(10, Vector3.FORWARD, r.global_position + Vector3.UP)
	await t._frames(2)
	check(_count("raptor_hurt") == 1, "raptor leva tiro: grito de dor", str(Sfx.played))
	r.take_hit(999, Vector3.FORWARD, r.global_position + Vector3.UP)
	await t._frames(45)
	check(_count("raptor_death") == 1 and _count("body_fall") == 1, "raptor morre: grito e o corpo caindo", str(Sfx.played))
	# mordida: estalo dos dentes e sacudida
	pr = await _spawn(Vector3(0, 0, 1.6))
	p = pr[0]
	r = pr[1]
	await t._frames(5)
	Sfx.played.clear()
	r.start_bite()
	await t._frames(40)
	check(_count("raptor_bite") == 1, "mordida: estalo da boca", str(Sfx.played))
	check(p.grabbed == (_count("raptor_shake") == 1), "presa na boca: sacudida com rosnado", str(Sfx.played))


func test_soldier_sounds() -> void:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = Vector3(0, 0, 8)
	w.add_child(p)
	var s := Soldier.new()
	s.rotation.y = PI
	s.target = p
	w.add_child(s)
	await t._frames(5)
	Sfx.played.clear()
	s._fire()
	check(_count("m16_shot") == 1, "guerrilheiro atira: m16_shot", str(Sfx.played))
	s.die(Vector3.FORWARD, s.global_position + Vector3.UP)
	await t._frames(40)
	check(_count("body_fall") == 1, "guerrilheiro morre: corpo caindo", str(Sfx.played))


func test_soundscape() -> void:
	# ela atrás dos dois (fora do cone de visão): ninguém desconfia sozinho antes da hora
	var pr := await _spawn(Vector3(0, 0, -8))
	var p: Player = pr[0]
	var r: Raptor = pr[1]
	var w: Node3D = pr[2]
	var r2 := Raptor.new()
	r2.position = Vector3(6, 0, 0)
	r2.rotation.y = PI
	r2.target = p
	w.add_child(r2)
	var sc := Soundscape.new()
	sc.target = p
	w.add_child(sc)
	await t._frames(2)
	check(sc.yard.playing and sc.warehouse.playing, "os dois ambientes tocando")
	p.global_position = Vector3(Yard.X_NEAR + 5.0, 0, 0)
	await t._frames(2)
	check(sc.yard_mix() == 0.0 and sc.warehouse.volume_db > sc.yard.volume_db + 20.0, "dentro do galpão: ambiente do galpão",
		"%s %s" % [sc.warehouse.volume_db, sc.yard.volume_db])
	p.global_position = Vector3(Yard.X_NEAR - 5.0, 0, 0)
	await t._frames(2)
	check(sc.yard_mix() == 1.0 and sc.yard.volume_db > sc.warehouse.volume_db + 20.0, "no pátio da mata: vento e grilos",
		"%s %s" % [sc.warehouse.volume_db, sc.yard.volume_db])
	p.global_position = Vector3(0, 0, -8)
	await t._frames(2)
	Sfx.played.clear()
	r.start_suspicious()
	await t._frames(2)
	check(_count("suspicious") == 1 and _count("raptor_suspicious") == 1, "desconfiado: aviso \"?\" e o piado do raptor", str(Sfx.played))
	# os dois entram em combate (um vê, o outro ouve o alarme): o acorde de "visto!" toca uma vez só
	r.spot()
	await t._frames(90)
	check(_count("alert") == 1, "visto: um acorde só, mesmo com dois inimigos alertados", str(Sfx.played))
