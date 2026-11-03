extends RefCounted
## Testes do esgueirar pela quina (PlayerLean, R3 / V): acha a beirada mais perto da cobertura à frente, inclina o tronco
## e dá o passo até a cabeça passar dela, câmera para o lado da quina; um toque liga e outro desliga (volta ao lugar),
## andar sai da quina, nada sem quina, agachada e mirando, e os inimigos passam a vê-la pela cabeça que ficou de fora.
## Chamado por run_tests.gd (usa check/_fresh_world/_frames/_spawn_player de lá; perfil "arcade").

const WALL_FACE := -0.7  # frente da parede (z); a parede vai de x = -1 a x = 1

var t: SceneTree  # o runner (run_tests.gd)


func run(runner: SceneTree) -> void:
	t = runner
	await test_lean_right()
	await test_lean_left()
	await test_no_corner()
	await test_crouch_aim()
	await test_enemy_sees_head()


## Parede de 2 m de largura, 2,4 m de altura e 0,6 m de fundo, com a frente em z = WALL_FACE.
func _world_with_wall() -> Node3D:
	var w: Node3D = await t._fresh_world()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 2.4, 0.6)
	col.shape = box
	body.add_child(col)
	body.position = Vector3(0, 1.2, WALL_FACE - 0.3)
	w.add_child(body)
	return w


## Um toque no botão de esgueirar (liga/desliga: não precisa segurar).
func _tap() -> void:
	Input.action_press("lean")
	await t._frames(2)
	Input.action_release("lean")


## Posição final da cabeça (depois dos modificadores: só aparece no desenho, não no get_bone_global_pose de fora).
func _head(p: Player) -> Vector3:
	var sk := p.model.skeleton
	var m := {"at": Vector3.ZERO}  # a lambda copia variável local
	var grab := func() -> void:
		m.at = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head")).origin
	sk.skeleton_updated.connect(grab)
	await t._frames(2)
	sk.skeleton_updated.disconnect(grab)
	return m.at


func test_lean_right() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0.8, 0, 0))  # beirada direita 0,2 m à direita dela
	await t._frames(20)
	var rest: Vector3 = await _head(p)
	var q := p.lean.find()
	t.check(q.get("side", 0) == 1 and absf(float(q.get("edge", 9.0)) - 0.2) < 0.08, "acha a beirada da direita (a mais perto)", str(q))
	await _tap()
	await t._frames(40)
	var head: Vector3 = await _head(p)
	var tilt := (head.x - p.global_position.x) - (rest.x - 0.8)
	t.check(p.lean.side == 1 and p.lean.amount > 0.99, "um toque no R3/V perto da quina: esgueira para a direita e fica, sem segurar", "%d %.2f" % [p.lean.side, p.lean.amount])
	t.check(head.x > 1.0 + 0.15, "a cabeça passa da beirada", "cabeça em x = %.2f (beirada em 1,0)" % head.x)
	t.check(absf(tilt - PlayerLean.HEAD_REACH) < 0.05, "HEAD_REACH = o quanto a inclinação leva a cabeça para o lado",
		"%.3f medido, %.3f na constante" % [tilt, PlayerLean.HEAD_REACH])
	t.check(p.global_position.x > 0.8 + 0.1 and p.global_position.x < 1.2, "deu o passo de lado até a quina", "%.2f" % p.global_position.x)
	t.check(absf(p.global_position.z) < 0.05 and absf(p.rotation.y) < 0.05, "ficou rente à cobertura, virada para a frente da câmera",
		"z %.2f, %.0f°" % [p.global_position.z, rad_to_deg(p.rotation.y)])
	t.check(p.camera_rig.spring.position.x > 0.6, "a câmera vai para o lado da quina", "%.2f" % p.camera_rig.spring.position.x)
	await _tap()
	await t._frames(40)
	t.check(p.lean.side == 0 and p.lean.amount == 0.0 and not p.lean.returning, "outro toque: endireita")
	t.check(absf(p.global_position.x - 0.8) < 0.05, "e volta ao lugar de onde saiu", "%.2f" % p.global_position.x)
	t.check(absf(p.camera_rig.spring.position.x) < 0.1, "a câmera volta para trás dela", "%.2f" % p.camera_rig.spring.position.x)


func test_lean_left() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(-0.8, 0, 0))
	await t._frames(20)
	await _tap()
	await t._frames(40)
	var head: Vector3 = await _head(p)
	t.check(p.lean.side == -1, "beirada da esquerda mais perto: esgueira para a esquerda", str(p.lean.side))
	t.check(head.x < -1.0 - 0.15, "a cabeça passa da beirada da esquerda", "%.2f" % head.x)
	t.check(p.camera_rig.spring.position.x < -0.6, "a câmera passa para o ombro esquerdo", "%.2f" % p.camera_rig.spring.position.x)
	# esgueirada, andar sai da quina e ela segue dali (não é puxada de volta ao lugar)
	var stepped := p.global_position.x
	Input.action_press("move_back")
	await t._frames(20)
	Input.action_release("move_back")
	t.check(p.lean.side == 0 and not p.lean.returning and p.global_position.z > 0.3 and absf(p.global_position.x - stepped) < 0.05,
		"andar sai da quina e segue dali", "lado %d, x %.2f (esgueirada %.2f), z %.2f" % [p.lean.side, p.global_position.x, stepped, p.global_position.z])
	await t._frames(15)
	t.check(p.lean.amount == 0.0 and p.model.lean_tilt.roll == 0.0, "e endireita andando")


func test_no_corner() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0, 0, 0))  # as duas beiradas a 1 m: longe para esgueirar
	await t._frames(20)
	await _tap()
	await t._frames(30)
	t.check(p.lean.side == 0 and p.lean.amount == 0.0 and absf(p.global_position.x) < 0.02, "no meio da parede: nada")
	p.global_position = Vector3(0, 0, 3)  # nada à frente
	await t._frames(5)
	await _tap()
	await t._frames(30)
	t.check(p.lean.side == 0 and p.model.lean_tilt.roll == 0.0, "sem cobertura à frente: nada")
	# esgueirada, a cambalhota a tira da quina na hora
	p.global_position = Vector3(0.8, 0, 0)
	await t._frames(5)
	await _tap()
	await t._frames(30)
	Input.action_press("roll")
	await t._frames(3)  # o physics_frame chega antes do _physics_process dela
	Input.action_release("roll")
	t.check(p.rolling and p.lean.amount == 0.0 and p.model.lean_tilt.roll == 0.0, "rolar sai da quina na hora",
		"rolando %s, %.2f, %.2f, lado %d" % [p.rolling, p.lean.amount, p.model.lean_tilt.roll, p.lean.side])
	await t._frames(60)


func test_crouch_aim() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0.8, 0, 0))
	await t._frames(10)
	p.crouching = true
	await t._frames(20)
	var rest: Vector3 = await _head(p)
	Input.action_press("aim")
	await _tap()
	await t._frames(40)
	var head: Vector3 = await _head(p)
	t.check(p.lean.side == 1 and p.aiming and p.crouching, "agachada e mirando também esgueira")
	t.check(head.x > 1.0 + 0.1 and head.y < rest.y + 0.1, "a cabeça sai da quina e ela continua agachada",
		"x %.2f, y %.2f (agachada %.2f)" % [head.x, head.y, rest.y])
	var shots := p.shots_fired
	Input.action_press("shoot")
	await t._frames(3)
	Input.action_release("shoot")
	t.check(p.shots_fired == shots + 1, "atira esgueirada")
	await _tap()
	Input.action_release("aim")
	p.crouching = false
	await t._frames(30)


## Atrás da parede o guarda não a vê; esgueirada, ele vê (e mira) a cabeça que ficou de fora.
func test_enemy_sees_head() -> void:
	var w: Node3D = await _world_with_wall()
	var p: Player = t._spawn_player(w, Vector3(0.8, 0, 0))
	var s := Soldier.new()
	s.position = Vector3(1.6, 0, -6)
	s.target = p
	w.add_child(s)
	await t._frames(5)
	s.process_mode = Node.PROCESS_MODE_DISABLED
	t.check(not s._line_clear(p), "atrás da parede: o guarda não tem linha até ela")
	await _tap()
	await t._frames(40)
	t.check(s._line_clear(p), "esgueirada: o guarda a vê pela cabeça", str(p.sight_point()))
	t.check(p.sight_point().y > 1.4 and s._aim_point(true).is_equal_approx(p.sight_point()), "e mira na cabeça")
	await _tap()
	await t._frames(40)
	t.check(not s._line_clear(p), "voltou para trás da parede: sumiu de novo")
