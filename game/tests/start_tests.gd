extends RefCounted
## Testes do começo da fase: telhado e alçapão (Roof, Hatch, animação HatchOpen), escada do canto, labirinto de caixas
## (Level.MAZE), dano de queda e o tiro do sniper que derruba da escada, sala dos clones (CloneLab: portão, tubos com
## raptors parados) e a cena do choque (Cutscene). Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player
## de lá; perfil "arcade").

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_maze_layout()
	await test_roof_and_hatch()
	await test_fall_damage()
	await test_sniper_ladder_window()
	await test_roof_unnoticed()
	await test_sniper_knocks_off_ladder()
	await test_clone_lab_and_cutscene()
	await test_sniper_patrol_in_level()
	await test_blood_smell()


func _level_world() -> Node3D:
	var w: Node3D = await t._fresh_world()
	for c in w.get_children():
		c.free()
	return w


func _release_all() -> void:
	for a in ["interact", "move_forward", "move_back", "jump"]:
		Input.action_release(a)


## Célula (coluna, linha) do labirinto é corredor?
func _open(c: int, r: int) -> bool:
	return r >= 0 and r < Level.MAZE.size() and c >= 0 and c < Level.MAZE[r].length() and Level.MAZE[r][c] != "#"


## Vizinha `n` de `cur` é passagem? (atrás da escada do mezanino há a parede de caixas: Level._seal)
func _link(cur: Vector2i, n: Vector2i) -> bool:
	var lad := Level.maze_ladder_cell()
	if (cur == lad and n == lad + Vector2i(0, 1)) or (n == lad and cur == lad + Vector2i(0, 1)):
		return false
	return _open(n.x, n.y)


## Células alcançáveis a partir de `from` andando pelos corredores.
func _reach(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var cur: Vector2i = todo.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if _link(cur, n) and not seen.has(n):
				seen[n] = true
				todo.append(n)
	return seen


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi((p.x - Level.MAZE_X0) / Level.MAZE_CELL), roundi((p.z - Level.MAZE_Z0) / Level.MAZE_CELL))


func test_maze_layout() -> void:
	var w := await _level_world()
	var built: Dictionary = Level.build(w)
	var catwalk := Catwalk.new()
	w.add_child(catwalk)
	await t._frames(3)
	var hatch: Hatch = built.hatch
	var cols: int = Level.MAZE[0].length()
	var rows: int = Level.MAZE.size()
	var start := _cell_of(hatch.ladder.bottom_pos + hatch.ladder.ladder_out * 0.45)
	var exit := Vector2i(0, rows - 1)
	t.check(start == Vector2i(cols - 1, rows - 1) and _open(start.x, start.y), "a escada do telhado desce no canto do fundo à direita do labirinto", str(start))
	var lad := Level.maze_ladder_cell()
	var front_open := []
	for c in cols:
		if _open(c, 0):
			front_open.append(c)
	t.check(front_open == [lad.x], "a frente do labirinto só tem a fresta do nicho da escada do mezanino", str(front_open))
	var reach := _reach(start)
	t.check(reach.has(exit), "do pé da escada do telhado dá para chegar à saída")
	# a única saída: a coluna 0 só tem corredor na linha do fundo (por baixo do mezanino, à esquerda)
	var exits := []
	for r in rows:
		if _open(0, r):
			exits.append(r)
	var exit_x := Level.maze_cell(0, rows - 1).x
	t.check(exits == [rows - 1] and exit_x < -Catwalk.PLATFORM_W * 0.5 + 0.5, "saída única à esquerda, na linha de baixo do mezanino", str(exits))
	var spur := _cell_of(catwalk.ladder.bottom_pos + catwalk.ladder.ladder_out * 0.45)
	var niche := _reach(Vector2i(lad.x, 0))
	t.check(spur == lad and not reach.has(spur), "de dentro do labirinto não se chega à escada do mezanino", str(spur))
	t.check(niche.has(spur) and not niche.has(start), "a escada do mezanino só se alcança pela fresta da frente (do galpão)", str(niche.keys()))
	var pistol: Vector3 = Pickup.LAYOUT[0].pos
	t.check(reach.has(_cell_of(pistol)), "a munição do galpão fica num corredor do labirinto")
	# corredores livres, pilhas altas demais para pendurar e subir (labirinto não se pula por cima)
	var space := w.get_world_3d().direct_space_state
	var grab_top: float = Moves.data().hang.top + PlayerMoves.GRAB_MAX
	var blocked := []
	var low := []
	# as escadas ficam dentro de células de corredor (encostadas na beira): não contam como obstáculo
	var ladders: Array[RID] = []
	for node: Node in w.get_tree().get_nodes_in_group("ladders"):
		for b: StaticBody3D in node.find_children("*", "StaticBody3D", false, false):
			ladders.append(b.get_rid())
	for r in rows:
		for c in cols:
			var at := Level.maze_cell(c, r)
			if _open(c, r):
				var q := PhysicsShapeQueryParameters3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.6, 1.2, 0.6)
				q.shape = box
				q.collision_mask = 1
				q.transform = Transform3D(Basis(), at + Vector3.UP * 0.7)
				q.exclude = ladders
				if not space.intersect_shape(q, 1).is_empty():
					blocked.append(Vector2i(c, r))
			else:
				var top := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 2.74, at + Vector3.DOWN, 1))
				if top.is_empty() or top.position.y <= grab_top:
					low.append([Vector2i(c, r), top.get("position", Vector3.ZERO).y])
	t.check(blocked.is_empty(), "corredores do labirinto livres para ela passar", str(blocked))
	# atrás da escada do mezanino a parede de caixas fecha o vão para o corredor de baixo (raio e corpo não passam)
	var behind := space.intersect_ray(PhysicsRayQueryParameters3D.create(Level.maze_cell(lad.x, lad.y) + Vector3(0.5, 0.9, 0),
		Level.maze_cell(lad.x, lad.y + 1) + Vector3(0.5, 0.9, 0), 1))
	t.check(not behind.is_empty() and behind.collider.get_meta("surface", "") == "crate", "atrás da escada do mezanino, caixas fecham o vão")
	t.check(low.is_empty(), "pilhas do labirinto acima do alcance de pendurar (%.2f m)" % grab_top, str(low))
	# a borda esquerda fecha (fora da saída): vindo de fora, o raio bate em caixa
	for r in rows - 1:
		var z := Level.maze_cell(0, r).z
		var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-9.0, 0.9, z), Vector3(-3.0, 0.9, z), 1))
		t.check(not side.is_empty() and side.collider.get_meta("surface", "") == "crate", "lateral esquerda do labirinto fechada (linha %d)" % r)
	# a cápsula dela passa célula a célula pelo caminho do labirinto (por baixo das vigas do mezanino) e sai para o galpão
	var route := _route(start, exit)
	var stuck := []
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	var pts: Array[Vector3] = []
	for cell in route + [Vector2i(-1, rows - 1)]:  # e fora, à esquerda
		var at := Level.maze_cell(cell.x, cell.y)
		# debaixo do mezanino as vigas diagonais descem para a frente: ela passa rente à parede, e ao lado da viga
		if at.z + Level.MAZE_CELL * 0.5 > Catwalk.FRONT_Z + 1.0:
			at.z += 0.35
		for bx in [-4.0, 0.0, 4.0]:
			if absf(at.x - bx) < 0.3:
				at.x += 0.45
		pts.append(at)
	for i in pts.size() - 1:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = 1
		q.transform = Transform3D(Basis(), pts[i] + Vector3.UP * 0.9)
		q.motion = pts[i + 1] - pts[i]
		var frac := space.cast_motion(q)
		if frac.is_empty() or frac[0] < 1.0:
			stuck.append(pts[i])
	t.check(route.size() > 1 and stuck.is_empty(), "ela passa pelo labirinto até a saída (%d células)" % route.size(), str(stuck))


## Caminho mais curto (células) entre duas células do labirinto.
func _route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var cur: Vector2i = todo.pop_front()
		if cur == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if _link(cur, n) and not prev.has(n):
				prev[n] = cur
				todo.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c := to
	while c != from:
		out.push_front(c)
		c = prev[c]
	out.push_front(from)
	return out


func test_roof_and_hatch() -> void:
	var w := await _level_world()
	var built: Dictionary = Level.build(w)
	var hatch: Hatch = built.hatch
	var p: Player = t._spawn_player(w, Roof.START)
	await t._frames(30)
	t.check(p.is_on_floor() and absf(p.global_position.y - Roof.Y) < 0.05 and p.health == 100, "começa em pé no telhado", str(p.global_position))
	# fechado: não dá para descer; ajoelhar e abrir
	t.check(not hatch.opened and not hatch.ladder.can_mount(hatch.kneel_point()).get("can", false), "alçapão fechado: a escada não monta pelo topo")
	p.global_position = hatch.kneel_point() + Vector3(0.2, 0, -0.2)
	await t._frames(3)
	t.check(p.pick_hatch() == hatch and p.pick_ladder() == null, "na frente do alçapão: abrir (e não descer)")
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	t.check(p.moves.mode == "hatch" and p.model.state == "hatch_open", "abrir: ajoelha e toca HatchOpen", "%s %s" % [p.moves.mode, p.model.state])
	t.check(p.global_position.distance_to(hatch.kneel_point()) < 0.1 and p.model.holstered, "ajoelha no lugar certo, de arma guardada")
	await t._frames(int(Hatch.GRAB_FRAME / Hatch.FPS * 60.0) - 6)
	t.check(not hatch.opened, "a tampa espera as mãos chegarem na alça")
	# enquanto a tampa sobe, as duas mãos ficam na alça (que gira com ela)
	var sk: Skeleton3D = p.model.skeleton
	var palm := func(side: String) -> Vector3:
		var pose := sk.get_bone_global_pose(sk.find_bone("Hand_" + side))
		return sk.global_transform * (pose.origin + pose.basis.y.normalized() * 0.05)
	var worst := 0.0
	var samples := 0
	var rose := 0.0
	for i in 120:
		await t._frames(1)
		var at_t: float = p.moves.t
		if at_t > Hatch.LET_GO_FRAME / Hatch.FPS - 0.02:
			break
		if at_t < Hatch.GRAB_FRAME / Hatch.FPS + 0.03:
			continue
		var mid: Vector3 = (palm.call("L") + palm.call("R")) * 0.5
		worst = maxf(worst, mid.distance_to(hatch.handle_point()))
		rose = hatch._hinge.rotation_degrees.x
		samples += 1
	# até 10 cm do centro da alça: punho fechado embaixo da barra de 5 cm, com 1-2 quadros entre a animação e o giro da tampa
	t.check(samples > 10 and rose > 30.0 and worst < 0.1, "abrindo: as mãos seguram a alça enquanto a tampa sobe",
		"%d quadros, tampa %.0f°, longe %.3f m" % [samples, rose, worst])
	await t._frames(int((Hatch.UP_FRAME - Hatch.LET_GO_FRAME) / Hatch.FPS * 60.0) + 12)
	t.check(hatch.opened and hatch._hinge.rotation_degrees.x > Hatch.OPEN_ANGLE - 1.0, "a tampa sobe junto com as mãos e fica em pé", str(hatch._hinge.rotation_degrees.x))
	await t._frames(int((Hatch.ANIM_FRAMES - Hatch.UP_FRAME) / Hatch.FPS * 60.0) + 4)
	t.check(p.moves.mode == "" and not p.model.holstered and p.pick_ladder() == hatch.ladder, "levantou: agora a escada desce")
	# descer até o labirinto: vira de costas para o furo e entra pela beirada (LadderIn: agacha, joelho e mãos na
	# moldura, desce até agarrar a escada), sem pulo
	var yaw0 := p.rotation.y
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	t.check(p.moves.mode == "ladder_mount", "entrar na escada: animação de virar e entrar", p.moves.mode)
	var top_y := p.global_position.y
	var peak := top_y
	var entered := false
	for i in 240:
		await t._frames(1)
		peak = maxf(peak, p.global_position.y)
		entered = entered or (p.moves.mode == "ladder_in" and p.model.state == "ladder_in")
		if p.moves.mode == "ladder":
			break
	var face: Vector3 = hatch.ladder.ladder_fwd
	t.check(entered and p.moves.mode == "ladder", "desce pelo alçapão pela beirada (LadderIn)")
	t.check(absf(angle_difference(yaw0, p.rotation.y)) > PI * 0.8 and absf(angle_difference(p.rotation.y, atan2(-face.x, -face.z))) < 0.05,
		"virou meia volta e ficou de frente para os degraus", "%.2f -> %.2f" % [yaw0, p.rotation.y])
	var rise := float(Moves.data().ladder.rise)
	t.check(peak - top_y < 0.01 and absf(p.global_position.y - (top_y - rise)) < 0.05,
		"entra sem pulo e fica agarrada no alto da escada", "pico %.2f fim %.2f" % [peak - top_y, p.global_position.y - top_y])
	Input.action_press("move_back")
	var bottom := false
	for i in 600:
		await t._frames(1)
		if p.moves.mode == "":
			bottom = true
			break
	Input.action_release("move_back")
	await t._frames(10)
	t.check(bottom and absf(p.global_position.y) < 0.1 and p.health == 100, "chega ao chão do galpão inteira", "%s %d" % [p.global_position, p.health])
	t.check(_cell_of(p.global_position) == Vector2i(Level.MAZE[0].length() - 1, Level.MAZE.size() - 1), "sai da escada dentro do labirinto", str(p.global_position))
	# e sobe de novo: no alto da escada as mãos vão para a beirada e ela sai pela moldura (LadderOut), de pé ao lado
	# do alçapão (não em cima do parapeito)
	p.moves.start_ladder(hatch.ladder, false)
	p.moves._ladder_y = hatch.ladder.height - rise - 0.05
	Input.action_press("move_forward")
	await t._frames(12)
	Input.action_release("move_forward")
	t.check(p.moves.mode == "ladder_out" and p.model.state == "ladder_out", "no alto da escada: sai pela beirada (LadderOut)", "%s %s" % [p.moves.mode, p.model.state])
	for i in 200:
		await t._frames(1)
		if p.moves.mode == "":
			break
	await t._frames(10)
	t.check(p.moves.mode == "" and absf(p.global_position.y - Roof.Y) < 0.1 and p.global_position.distance_to(hatch.kneel_point()) < 0.3,
		"subindo, sai no telhado na frente do alçapão", str(p.global_position))
	# o parapeito é baixo: correr e pular contra ele, ela escala, cai para fora do telhado e morre na queda
	p.global_position = Vector3(0, Roof.Y, Level.SIZE * 0.5 - 1.2)
	p.rotation.y = PI
	p.camera_rig.yaw = PI
	await t._frames(3)
	Input.action_press("move_forward")
	var climbed := false
	for k in 6:
		Input.action_press("jump")
		await t._frames(3)
		Input.action_release("jump")
		climbed = climbed or p.moves.mode == "mantle"
		await t._frames(25)
		if p.dead:
			break
	Input.action_release("move_forward")
	for i in 120:
		if p.dead:
			break
		await t._frames(1)
	t.check(climbed and p.dead and p.death_cause == "fall" and p.global_position.z > Roof.EDGE,
		"escala o parapeito, se joga do telhado e morre na queda", "%s %s %s" % [climbed, p.global_position, p.death_cause])
	p.respawn()
	hatch.reset()
	t.check(not hatch.opened and hatch._hinge.rotation.x == 0.0 and not hatch.ladder.top_open, "reinício fecha o alçapão")
	_release_all()


func test_fall_damage() -> void:
	t.check(Player.fall_damage(3.0) == 0 and Player.fall_damage(Catwalk.FLOOR_Y + 0.55) == 0, "pular do mezanino não machuca")
	var mid := Player.fall_damage(4.3)
	t.check(mid > 0 and mid < Player.MAX_HEALTH, "queda média machuca", str(mid))
	t.check(Player.fall_damage(Roof.Y) >= Player.MAX_HEALTH, "do telhado ao chão: morte")
	t.check(Player.fall_damage(2.0) == 0 and Player.fall_damage(2.0, true) >= Player.MAX_HEALTH, "derrubada da escada (sem controle) morre de altura menor")
	for case in [[3.0, 100, false], [4.3, -1, false], [Roof.Y + 0.1, 0, true]]:
		var w: Node3D = await t._fresh_world()
		var p: Player = t._spawn_player(w, Vector3(0, case[0], 0))
		await t._frames(90)
		if case[1] == 100:
			t.check(p.health == 100 and not p.dead, "caiu %.1f m: sem dano" % case[0], str(p.health))
		elif case[1] == -1:
			t.check(p.health > 0 and p.health < 100 and not p.dead, "caiu %.1f m: ferida" % case[0], str(p.health))
		else:
			t.check(p.dead and p.death_cause == "fall", "caiu %.1f m: morreu na queda" % case[0], "%d %s" % [p.health, p.death_cause])
	# fora do mapa (sem chão embaixo, como do telhado para fora do galpão): não cai para sempre, morre na queda
	var w: Node3D = await t._fresh_world()
	var p: Player = t._spawn_player(w, Vector3(60.0, Roof.Y, 0))
	await t._frames(120)
	t.check(p.dead and p.death_cause == "fall" and p.health == 0, "caiu para fora do mapa: morreu na queda",
		"%s %d %s" % [p.global_position, p.health, p.death_cause])


## Ela só aparece para o sniper na parte de baixo da escada do telhado, e só se ele estiver olhando para o canto.
func test_sniper_ladder_window() -> void:
	var w := await _level_world()
	var built: Dictionary = Level.build(w)
	var hatch: Hatch = built.hatch
	w.add_child(Catwalk.new())
	var p: Player = t._spawn_player(w, Roof.START)
	var s := Sniper.new()
	s.target = p
	s.position = Vector3(1.0, Catwalk.FLOOR_Y, 11.7)
	w.add_child(s)
	await t._frames(5)
	s.process_mode = Node.PROCESS_MODE_DISABLED  # a cabeça fica onde o teste põe
	hatch.open(0.01)
	p.moves.start_ladder(hatch.ladder, true)
	var at := func(y: float) -> void:
		p.moves._ladder_y = y
		p.moves._update_ladder_pos()
		p.stealth.update(0.016)
	s.rotation.y = 0.0
	s.head_yaw = -0.85  # olhando para o canto da escada
	# agarrou a escada (alto do ciclo, peito já abaixo do forro) e os primeiros degraus: escondida, mesmo com ele alertado
	var top := hatch.ladder.height - float(Moves.data().ladder.rise)
	var hide := hatch.ladder.hidden_top
	t.check(is_equal_approx(hide, Hatch.HIDDEN_RUNGS * Ladder.RUNG_SPACING) and Hatch.HIDDEN_RUNGS >= 3, "escada do alçapão: os primeiros degraus escondem", str(hide))
	s.alert_t = Enemy.ALERT_TIME
	for y in [top, top - hide * 0.5, top - hide + 0.05]:
		at.call(y)
		t.check(not s._sees_target() and not s._combat_sees(), "agarrou a escada, %.2f m abaixo do topo: o sniper ainda não vê" % (top - y))
	s.alert_t = 0.0
	at.call(top - hide - 0.1)
	t.check(s._sees_target(), "desceu os degraus escondidos, sniper olhando para o canto: vê")
	s.head_yaw = 0.85
	t.check(not s._sees_target(), "sniper olhando para o outro lado: não vê (é a hora de descer)")
	s.head_yaw = -0.85
	at.call(4.6)
	t.check(not s._sees_target(), "ainda no alto (peito acima do forro): a laje esconde")
	at.call(1.5)
	t.check(not s._sees_target(), "embaixo, entre as caixas e no ponto cego do mezanino: não vê")
	p.moves.cancel()


## No telhado ela está fora do alcance de todos: passos, tiro e vista não atravessam a laje (nem alertados).
func test_roof_unnoticed() -> void:
	var w := await _level_world()
	var built: Dictionary = Level.build(w)
	var hatch: Hatch = built.hatch
	w.add_child(Catwalk.new())
	t.check(Roof.START.distance_to(hatch.kneel_point()) > 8.0, "ela começa longe do alçapão", "%.1f m" % Roof.START.distance_to(hatch.kneel_point()))
	var p: Player = t._spawn_player(w, Roof.START)
	var s := Sniper.new()
	s.target = p
	s.position = Vector3(Roof.START.x, Catwalk.FLOOR_Y, Roof.START.z + 2.0)
	s.rotation.y = 0.0
	w.add_child(s)
	await t._frames(5)
	p.make_noise(10.0, 1.0)  # passos de corrida
	p.make_noise(26.0, 1.0)  # tiro
	await t._frames(30)
	t.check(s.aware == 0.0 and s.alert_level() == 0, "no telhado: passos e tiro não chamam quem está embaixo", "aware=%.2f nível=%d" % [s.aware, s.alert_level()])
	s.alert_t = Enemy.ALERT_TIME
	t.check(not s._sees_target() and not s._combat_sees(), "nem alertado ele a vê no telhado")
	s.alert_t = 0.0
	# controle: o mesmo tiro dentro do galpão ele ouve
	s.hear_noise(Vector3(Roof.START.x, Catwalk.FLOOR_Y, Roof.START.z), 26.0, 1.0)
	t.check(s.aware > 0.5, "o mesmo tiro dentro do galpão ele ouve", "aware=%.2f" % s.aware)


func test_sniper_knocks_off_ladder() -> void:
	var w := await _level_world()
	var built: Dictionary = Level.build(w)
	var hatch: Hatch = built.hatch
	w.add_child(Catwalk.new())
	var p: Player = t._spawn_player(w, Roof.START)
	var s := Sniper.new()
	s.target = p
	s.position = Vector3(1.0, Catwalk.FLOOR_Y, 11.7)
	s.rotation.y = -PI * 0.5
	w.add_child(s)
	await t._frames(5)
	hatch.open(0.01)
	p.moves.start_ladder(hatch.ladder, true)
	p.moves._ladder_y = hatch.ladder.height - float(Moves.data().ladder.rise) - hatch.ladder.hidden_top - 0.1
	p.moves._update_ladder_pos()
	s.spot()
	var knocked := false
	for i in 300:
		await t._frames(1)
		if s.shots_fired > 0 and p.moves.mode != "ladder":
			knocked = true
			break
	t.check(knocked and not p.dead and p.health < 100, "o tiro do sniper na escada a derruba (o tiro sozinho não mata no arcade)", "tiros=%d modo=%s vida=%d" % [s.shots_fired, p.moves.mode, p.health])
	await t._frames(90)
	t.check(p.dead and p.death_cause == "fall", "e ela morre na queda", "vida=%d causa=%s" % [p.health, p.death_cause])


func test_clone_lab_and_cutscene() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var lab: CloneLab = main.lab
	var gate: Door = lab.gate
	var cs: Cutscene = main.cutscene
	t.check(absf(p.global_position.y - Roof.Y) < 0.1 and p.global_position.distance_to(Roof.START) < 0.3, "na fase, ela começa no telhado", str(p.global_position))
	t.check(gate != null and gate.room == -1 and not gate.opened, "portão da sala dos clones fechado, fora da corrente de salas")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var through := PhysicsRayQueryParameters3D.create(Vector3(0, 2.5, -11.6), Vector3(0, 2.5, -15.0), 1)
	t.check(not space.intersect_ray(through).is_empty(), "portão fechado bloqueia passagem e visão")
	# os clones: seis raptors parados dentro dos tubos, sem piar
	t.check(lab.clones.size() == 6, "seis tubos com raptors", str(lab.clones.size()))
	var bad := []
	for r: RaptorModel in lab.clones:
		var tube: Node3D = r.get_parent().get_parent()
		var off := r.global_position - tube.global_position
		var still := not r.anim_player.is_playing() and not r.chirps and not r.is_ragdoll()
		if not still or Vector2(off.x, off.z).length() > CloneLab.TUBE_R or not CloneLab.inside(r.global_position + Vector3.UP * 0.01):
			bad.append(tube.global_position)
	t.check(bad.is_empty(), "clones parados (congelados), dentro dos tubos da sala", str(bad))
	var pose := lab.clones[0].skeleton.get_bone_pose_rotation(1)
	await t._frames(30)
	t.check(lab.clones[0].skeleton.get_bone_pose_rotation(1).is_equal_approx(pose), "a pose do clone não muda com o tempo")
	# portão: na plataforma de carga, E abre
	p.global_position = Vector3(0, CloneLab.FLOOR_Y, -11.4)
	await t._frames(5)
	t.check(p.pick_door() == gate, "na plataforma: aviso de abrir o portão")
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(int(Door.OPEN_TIME * 60) + 5)
	t.check(gate.opened and space.intersect_ray(through).is_empty(), "E abre o portão da sala")
	t.check(not cs.busy and not lab.played, "na porta, a cena ainda não começou")
	# entra: a cena do choque
	p.global_position = Vector3(0, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - 0.2)
	await t._frames(3)
	t.check(cs.busy and p.cutscene and not main._hud.visible and cs.layer.visible, "entrou: cena com faixas pretas, sem HUD e sem controle")
	var z0 := p.global_position.z
	p.take_hit(50, Vector3.BACK, p.global_position + Vector3.UP)
	t.check(p.health == 100, "na cena ela não leva dano")
	await t._frames(int(Cutscene.WALK_TIME * 60) - 10)
	t.check(p.global_position.z < z0 - 1.5 and p.model.state == "walk", "anda devagar entre os tubos", "%.2f %s" % [z0 - p.global_position.z, p.model.state])
	await t._frames(int((Cutscene.SUB_AT - Cutscene.WALK_TIME) * 60) + 15)
	t.check(p.model.state == "shocked" and cs._sub.visible and cs._sub.text == "O QUE...?!", "o susto: animação Shocked e a legenda", "%s %s" % [p.model.state, cs._sub.visible])
	t.check(cs._cam.current, "câmera da cena no ar")
	await t._frames(int((Cutscene.END_AT - Cutscene.SUB_AT) * 60) + 5)
	t.check(not cs.busy and not p.cutscene and main._hud.visible and not cs.layer.visible and p.camera_rig.camera.current, "fim da cena: controle, HUD e câmera dela de volta")
	t.check(lab.played and CloneLab.inside(p.global_position), "ela fica dentro da sala")
	# sair e entrar de novo não repete; reiniciar fecha tudo e a cena volta a valer
	p.global_position = Vector3(0, CloneLab.FLOOR_Y, -11.4)
	await t._frames(3)
	p.global_position = Vector3(0, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - 0.4)
	await t._frames(3)
	t.check(not cs.busy, "a cena só toca uma vez")
	main.reset_all()
	await t._frames(3)
	t.check(not gate.opened and not lab.played and not main.hatch.opened and absf(p.global_position.y - Roof.Y) < 0.1, "R: portão e alçapão fechados, cena de novo, ela no telhado")
	# pular a cena com E
	gate.open()
	p.global_position = Vector3(0, CloneLab.FLOOR_Y, CloneLab.ENTER_Z - 0.2)
	await t._frames(int(Cutscene.SKIP_AFTER * 60) + 5)
	t.check(cs.busy, "cena tocando de novo")
	var held := InputEventAction.new()
	held.action = "interact"
	held.pressed = true
	Input.action_press("interact")  # só o estado da ação apertada (sem evento) não pula
	await t._frames(3)
	Input.action_release("interact")
	t.check(cs.busy, "ação apertada sem evento de tecla não pula a cena")
	Input.parse_input_event(held)
	await t._frames(2)
	var up := InputEventAction.new()
	up.action = "interact"
	Input.parse_input_event(up)
	await t._frames(1)
	t.check(not cs.busy and not p.cutscene, "E pula a cena")
	# cair pelo alçapão aberto (do telhado ao chão): morre na queda e o Game Over diz isso
	main.reset_all()
	await t._frames(3)
	main.hatch.open(0.01)
	p.global_position = main.hatch.ladder.top_pos + main.hatch.ladder.ladder_out * 0.45 + Vector3.UP * 0.3
	await t._frames(90 + int((main.GAME_OVER_DELAY + 0.2) * 60.0))
	t.check(p.dead and p.death_cause == "fall" and main.game_over and "NA QUEDA" in main._end_stats.text, "caiu pelo alçapão: Game Over de queda", main._end_stats.text)
	main.reset_all()
	main.queue_free()
	await t._frames(2)
	_release_all()


## Na fase de verdade (com o telhado e as caixas do labirinto embaixo), o sniper faz a ronda no mezanino de ponta a ponta
## e não vai para a quina (a malha de navegação mais perto dele é a de outro andar: ele anda reto).
func test_sniper_patrol_in_level() -> void:
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	var s: Sniper = main.sniper
	var min_x := INF
	var max_x := -INF
	var corner := false
	for i in 60 * 30:
		await t.physics_frame
		min_x = minf(min_x, s.global_position.x)
		max_x = maxf(max_x, s.global_position.x)
		corner = corner or s.global_position.x < -4.0 or s.global_position.z < Catwalk.FRONT_Z + 0.6
	t.check(min_x < -2.8 and max_x > -0.2 and not corner, "sniper faz a ronda do mezanino sem ir para a quina", "x %.2f..%.2f quina=%s" % [min_x, max_x, corner])
	main.queue_free()
	await t._frames(2)


## Na beira do telhado do lado do pátio (Roof.near_yard), uma vez só: o jogo para com a mensagem do cheiro de sangue
## (Inspect.show_message, como nos jogos antigos) até ela apertar confirmar.
func test_blood_smell() -> void:
	if t._world:
		t._world.queue_free()
		t._world = null
		await t._frames(2)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.get_root().add_child(main)
	await t._frames(5)
	var p: Player = main.player
	var ins: Inspect = main.inspect
	t.check(not Roof.near_yard(Roof.START) and not main.smelled, "no começo do telhado: sem a mensagem do cheiro")
	var edge := Vector3(-Roof.EDGE + 1.0, Roof.Y, Yard.DOOR_Z)
	t.check(Roof.near_yard(edge) and not Roof.near_yard(Vector3(edge.x, 0.0, edge.z)), "a beira oeste conta, o chão embaixo dela não")
	p.global_position = edge
	p.reset_physics_interpolation()
	await t._frames(3)
	t.check(main.smelled and ins.busy and t.paused and ins._body.visible and ins._body.text == Roof.SMELL_TEXT,
		"na beira do lado do pátio: o jogo para com a mensagem do cheiro", ins._body.text)
	var held := p.global_position
	await t._frames(int((Inspect.MIN_SHOW + 1.0) * 60.0))
	t.check(ins.busy and t.paused and p.global_position == held, "a mensagem espera o botão: o jogo segue parado")
	Input.action_press("interact")
	await t._frames(2)
	Input.action_release("interact")
	await t._frames(2)
	t.check(not ins.busy and not t.paused, "confirmar fecha a mensagem e o jogo volta")
	# sai e volta: não repete
	p.global_position = Roof.START
	await t._frames(3)
	p.global_position = edge
	await t._frames(3)
	t.check(not ins.busy and not t.paused, "voltando à beira: a mensagem não repete")
	# reiniciar: vale de novo
	main.reset_all()
	await t._frames(3)
	t.check(not main.smelled, "reiniciar: a mensagem do cheiro volta a valer")
	main.queue_free()
	await t._frames(2)
	_release_all()
