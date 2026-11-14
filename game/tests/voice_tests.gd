extends "res://tests/ai_tests.gd"
## Testes das falas dos guerrilheiros (Voice): arquivos gerados batem com a tabela, cada momento do alerta diz a sua fala,
## uma fala por vez (a mais importante corta), intervalo por tipo, bicho não fala, longe/cena não fala. Usa os auxiliares
## de ai_tests.gd; chamado por run_tests.gd.


func run(runner: SceneTree, _picks: Array = []) -> void:
	t = runner
	test_files()
	await test_spot_once()
	await test_suspicious_then_priority()
	await test_shouts()
	await test_gives_up()
	await test_taunt()
	await test_kill_call()
	await test_silent_cases()


func _said(cat: String) -> int:
	return int(Voice.played.get(cat, 0))


func _soldier(w: Node3D, p: Player, pos: Vector3, yaw := PI) -> Soldier:
	var s := Soldier.new()
	s.position = pos
	s.rotation.y = yaw
	s.target = p
	w.add_child(s)
	s.rng.seed = 3
	return s


## Ela atrás do guerrilheiro (que olha para +Z): ninguém a vê sozinho; o teste manda nos estados.
func _setup(player_pos := Vector3(0, 0, -8)) -> Array:
	var w: Node3D = await t._fresh_world()
	var p := Player.new()
	p.position = player_pos
	w.add_child(p)
	var s := _soldier(w, p, Vector3.ZERO)
	await t._frames(2)
	Voice.reset()
	return [p, s, w]


func test_files() -> void:
	var expected := {}
	var bad := []
	for v: String in Voice.VOICES:
		for cat: String in Voice.LINES:
			for i in range(1, int(Voice.LINES[cat]) + 1):
				var file := Voice.path(v, cat, i)
				expected[file.get_file()] = true
				var st := load(file) as AudioStreamWAV
				if st == null or st.stereo or st.mix_rate != 22050 or st.get_length() < 0.2 or st.get_length() > 3.0:
					bad.append(file.get_file())
	check(bad.is_empty(), "falas da tabela existem (WAV mono 22050 Hz, 0,2 a 3 s)", str(bad))
	var extra := []
	for f in DirAccess.get_files_at(Voice.DIR):
		if f.ends_with(".wav") and not expected.has(f):
			extra.append(f)
	check(extra.is_empty(), "nenhuma fala fora da tabela (make_voices.py e Voice.LINES batem)", str(extra))
	check(Voice.PRIORITY.size() == Voice.LINES.size() and Voice.GAP.size() == Voice.LINES.size(),
		"toda fala tem prioridade e intervalo")


func test_spot_once() -> void:
	var pr := await _setup()
	var p: Player = pr[0]
	var a: Soldier = pr[1]
	var b := _soldier(pr[2], p, Vector3(3, 0, 0))
	await t._frames(2)
	check(a.voice != "" and b.voice != "" and a.voice != b.voice, "cada guerrilheiro com uma voz", "%s %s" % [a.voice, b.voice])
	Voice.reset()
	a.spot()
	b.spot()
	await t._frames(2)
	check(_said("spot") == 1, "dois a veem juntos: um \"Ali!\" só", str(Voice.played))
	await t._frames(int(Voice.GAP.spot * 60) + 70)
	b.state = "idle"
	b.spot()
	check(_said("spot") == 2, "passado o intervalo, outro pode gritar", str(Voice.played))


func test_suspicious_then_priority() -> void:
	var pr := await _setup()
	var p: Player = pr[0]
	var a: Soldier = pr[1]
	var b := _soldier(pr[2], p, Vector3(3, 0, 0))
	await t._frames(2)
	Voice.reset()
	a.start_suspicious()
	check(_said("huh") == 1, "desconfiou: \"Ahn?\"", str(Voice.played))
	b.start_suspicious()
	check(_said("huh") == 1, "o segundo desconfiado na mesma hora fica quieto", str(Voice.played))
	a.spot()
	check(_said("spot") == 1, "\"Ali!\" corta o murmúrio que estava tocando", str(Voice.played))
	var players := a.find_children("*", "AudioStreamPlayer3D", false, false).filter(func(n: Node) -> bool:
		return not n.is_queued_for_deletion())
	check(players.size() == 1, "só a fala nova toca", str(players.size()))


func test_shouts() -> void:
	var pr := await _setup()
	var s: Soldier = pr[1]
	var dead := _soldier(pr[2], pr[0], Vector3(1.5, 0, -3.0))  # atrás dele: não o vê cair (a morte vista grita na hora, Enemy.witness_death)
	await t._frames(2)
	dead.die(Vector3.FORWARD, dead.global_position + Vector3.UP, false, true)  # sem o baque: ele não se vira para ela
	await t._frames(2)
	Voice.reset()
	s._alarm_from(dead.global_position, dead)
	check(_said("corpse") == 0, "o grito do corpo sai depois de SHOUT_DELAY, não na hora")
	await t._frames(int(Enemy.SHOUT_DELAY * 60) + 5)
	check(_said("corpse") == 1, "achou o corpo: \"Homem no chão!\"", str(Voice.played))
	pr = await _setup()
	s = pr[1]
	s._alarm_from(s.global_position + Vector3(0, 0, -6))
	await t._frames(int(Enemy.SHOUT_DELAY * 60) + 5)
	check(_said("hit") == 1, "ferido sem tê-la visto: \"Fui atingido!\"", str(Voice.played))
	s.die(Vector3.FORWARD, s.global_position + Vector3.UP)
	Voice.reset()
	s.start_suspicious()
	check(Voice.played.is_empty(), "morto não fala", str(Voice.played))


func test_gives_up() -> void:
	for active in [true, false]:
		var pr := await _setup()
		var s: Soldier = pr[1]
		s.active_search = active
		s._sweeps_left = 0
		s._search_center = s.global_position + Vector3(0, 0, 3)
		s.start_search()
		s._dur = 0.0
		await t._frames(3)
		var cat := "giveup" if active else "nothing"
		check(_said(cat) == 1, "fim da busca %s: \"%s\"" % ["ativa" if active else "amarela", cat], str(Voice.played))


## No tiroteio, com ela à vista, às vezes ele provoca no começo de uma rajada ("Morre!"), sem virar falatório (GAP).
func test_taunt() -> void:
	var pr := await _setup(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	p.health = 100000
	seed(11)
	s.start_engage()
	Voice.reset()
	var secs := 16.0
	await t._frames(int(secs * 60))
	var n := _said("taunt")
	check(s.shots_fired > 0 and n >= 1, "no tiroteio ele provoca às vezes", "tiros=%d provocações=%d" % [s.shots_fired, n])
	check(n <= int(secs / Voice.GAP.taunt) + 1, "provocação respeita o intervalo", str(n))


## O tiro que a mata: quem atirou avisa "Alvo abatido!", por cima de qualquer fala.
func test_kill_call() -> void:
	var pr := await _setup(Vector3(0, 0, 8))
	var p: Player = pr[0]
	var s: Soldier = pr[1]
	p.health = 1
	s.start_engage()
	Voice.reset()
	for i in 600:
		await t._frames(1)
		if p.dead:
			break
	check(p.dead and _said("down") == 1, "matou ela: \"Alvo abatido!\"", "morta=%s %s" % [p.dead, Voice.played])


func test_silent_cases() -> void:
	# raptor não fala
	var pr := await _spawn(Vector3(0, 0, -8))
	Voice.reset()
	(pr[1] as Raptor).spot()
	(pr[1] as Raptor).start_suspicious()
	check(Voice.played.is_empty(), "raptor não fala", str(Voice.played))
	# longe demais dela
	pr = await _setup(Vector3(0, 0, -(Voice.MAX_DIST + 5.0)))
	(pr[1] as Soldier).start_suspicious()
	check(Voice.played.is_empty(), "longe dela não fala", str(Voice.played))
	# numa cena (ela sem controle) não fala
	pr = await _setup()
	(pr[0] as Player).cutscene = true
	(pr[1] as Soldier).start_suspicious()
	check(Voice.played.is_empty(), "na cena não fala", str(Voice.played))
	(pr[0] as Player).cutscene = false
