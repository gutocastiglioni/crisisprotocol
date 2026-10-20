class_name PlayerMoves
extends RefCounted
## Ações da heroína que seguem um caminho da raiz (Moves) e tomam o controle enquanto duram: cambalhota com
## projeção, pulinho de esquiva (survival), pulo até a borda (fica pendurada), subir da borda, escalar obstáculo baixo e pegar arma no baú.
## A cápsula anda pelo mesmo caminho que o corpo animado (gerado com a animação), então nada escorrega.

const LEDGE_REACH := 0.9  # distância máxima até a parede para agarrar/escalar
const GRAB_MAX := 0.85  # o pulo até a borda sobe os pés até essa altura (borda alta: até hang.top + isso)
const GRAB_TIME := 0.38  # duração do pulo até a borda
const DROP_PUSH := 0.14  # ao soltar da borda, afasta da parede (pendurada, a cápsula encosta nela)
const ROLL_TURN := 18.0  # rapidez com que vira para a direção da cambalhota
const KNEEL_WALK := 8.0  # quadros até chegar ao lugar de ajoelhar na frente do baú
const DODGE_BACK_COS := cos(deg_to_rad(50.0))  # direção pedida até 50° das costas dela: pulinho para trás
const DOUBLE_TAP := 0.2  # segundo X até este tempo depois do primeiro = clique duplo = cambalhota (sem pulinho antes)
const WAIT_BRAKE := 25.0  # m/s² com que ela freia esperando o segundo clique (planta os pés para pular)

var p: Player
var mode := ""  # "", "roll", "dodge_wait", "dodge", "grab", "hang", "climb", "mantle", "pickup"
var t := 0.0
var _base := Vector3.ZERO  # origem do caminho da ação
var _fwd := Vector3.FORWARD  # frente do caminho (para a parede, ou para onde rola)
var _path: Array = []
var _frames := 0.0
var _prev := 0.0
var _ledge := {}
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _climb_from := 0.0
var _armed := false  # pendurada: o direcional precisa voltar ao centro antes de valer de novo
var _chest: Node
var _kneel: Transform3D
var _yaw0 := 0.0
var _got_item := false
var _landed := false  # pulinho: já tocou a aterrissagem
var _enemy: Node3D
var _hit_done := false
var _hit_frame := 0.0


func _init(player: Player) -> void:
	p = player


func busy() -> bool:
	return mode != ""


func hanging() -> bool:
	return mode == "hang"


func update(delta: float) -> void:
	t += delta
	match mode:
		"roll": _roll(delta)
		"dodge_wait": _dodge_wait(delta)
		"dodge": _dodge(delta)
		"grab": _grab()
		"hang": _hang()
		"climb", "mantle": _follow()
		"pickup": _pickup()
		"assassinate", "crit_strike": _strike_move(delta)


## Interrompe a ação (golpe, mordida, morte, reinício). Pegando a arma antes das mãos chegarem nela, a arma fica.
func cancel() -> void:
	if mode in ["grab", "hang", "climb", "mantle", "assassinate", "crit_strike"] or (mode == "pickup" and not _got_item):
		p.model.holster(false)
	if is_instance_valid(_enemy):
		_enemy.stealth_lock(false)
		_enemy = null
	mode = ""
	p.rolling = false
	p.hopping = false


# ------------------------------------------------------------------ cambalhota
func start_roll(dir: Vector3) -> void:
	var d: Dictionary = Moves.data().roll
	mode = "roll"
	t = 0.0
	_fwd = dir
	_path = d.path
	_frames = float(d.frames)
	_prev = 0.0
	p.rolling = true
	p.crouching = false
	p.model.play("roll")


func _roll(delta: float) -> void:
	var f := t * Moves.fps()
	var d := Moves.path_at(_path, f).x
	var v := _fwd * (d - _prev) / delta
	_prev = d
	p.velocity.x = v.x
	p.velocity.z = v.z
	if not p.is_on_floor():
		p.velocity.y -= Player.GRAVITY * delta
	var yaw := atan2(-_fwd.x, -_fwd.z)
	p.rotation.y = lerp_angle(p.rotation.y, yaw, 1.0 - exp(-ROLL_TURN * delta))
	p.move_and_slide()
	if f >= _frames:
		mode = ""
		p.rolling = false


# ------------------------------------------------------------------ pulinho de esquiva
## Primeiro X: espera DOUBLE_TAP pelo segundo antes de decidir, já invulnerável e freando o embalo de antes. Veio o
## segundo: cambalhota direto (o pulinho nem começa), para o direcional ou para `dir`. Não veio: pulinho para `dir`
## (ou para o direcional, se ele foi apertado durante a espera).
func request_dodge(dir: Vector3) -> void:
	mode = "dodge_wait"
	t = 0.0
	_fwd = dir
	p.hopping = true
	p.crouching = false
	p.model.set_state("idle")


func _dodge_wait(delta: float) -> void:
	var wish := p.move_wish()
	if wish.length() > 0.1:
		_fwd = wish.normalized()
	if Input.is_action_just_pressed("roll"):
		p.hopping = false
		start_roll(_fwd)
		return
	var h := Vector2(p.velocity.x, p.velocity.z).move_toward(Vector2.ZERO, WAIT_BRAKE * delta)
	p.velocity.x = h.x
	p.velocity.z = h.y
	if not p.is_on_floor():
		p.velocity.y -= Player.GRAVITY * delta
	p.move_and_slide()
	if t >= DOUBLE_TAP:
		start_dodge(_fwd)


## Pulinho curto para `dir` (no chão, normalizada) sem rolar: para trás se `dir` está até 50° das costas dela; senão de
## lado, virando só o necessário para `dir` ficar à esquerda ou à direita dela. Invulnerável até o quadro "guard".
func start_dodge(dir: Vector3) -> void:
	var d: Dictionary = Moves.data().dodge
	var fwd := -p.global_basis.z
	var face := -dir
	var anim := "dodge_back"
	_path = d.back
	if dir.dot(-fwd) < DODGE_BACK_COS:
		# das duas frentes que deixam `dir` de lado, a mais perto de para onde ela já olha
		face = Vector3(-dir.z, 0.0, dir.x)
		if face.dot(fwd) < 0.0:
			face = -face
		anim = "dodge_r" if dir.dot(face.cross(Vector3.UP)) > 0.0 else "dodge_l"
		_path = d.side
	mode = "dodge"
	t = 0.0
	_fwd = dir
	_yaw0 = atan2(-face.x, -face.z)
	_frames = float(d.frames)
	_prev = 0.0
	_landed = false
	p.hopping = true
	p.crouching = false
	p.model.play(anim)


func _dodge(delta: float) -> void:
	var d: Dictionary = Moves.data().dodge
	var f := t * Moves.fps()
	var dist := Moves.path_at(_path, f).x
	var v := _fwd * (dist - _prev) / delta
	_prev = dist
	p.velocity.x = v.x
	p.velocity.z = v.z
	if not p.is_on_floor():
		p.velocity.y -= Player.GRAVITY * delta
	p.rotation.y = lerp_angle(p.rotation.y, _yaw0, 1.0 - exp(-ROLL_TURN * delta))
	p.move_and_slide()
	p.hopping = f < float(d.guard)
	if not _landed and f >= float(d.land):
		_landed = true
		Sfx.play(p.model, "land")
	if f >= _frames:
		mode = ""
		p.hopping = false


# ------------------------------------------------------------------ bordas
## Borda à frente (até LEDGE_REACH): parede quase vertical, topo plano e espaço para ficar de pé em cima.
## Devolve {n: normal da parede (para fora), face: ponto da parede na linha dela, top: altura do topo,
## height: topo - pés} ou {}.
func find_ledge(fwd: Vector3) -> Dictionary:
	fwd = Vector3(fwd.x, 0.0, fwd.z).normalized()
	var space := p.get_world_3d().direct_space_state
	var feet := p.global_position
	var ex: Array[RID] = [p.get_rid()]
	var hit := {}
	for h in [0.4, 0.9, 1.4, 1.9, 2.4]:
		var from: Vector3 = feet + Vector3.UP * h
		hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + fwd * LEDGE_REACH, 1, ex))
		if hit and absf(hit.normal.y) < 0.3 and hit.normal.dot(fwd) < -0.5:
			break
		hit = {}
	if hit.is_empty():
		return {}
	var n := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
	var probe: Vector3 = hit.position - n * 0.15
	var top_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(probe.x, feet.y + 3.3, probe.z), Vector3(probe.x, feet.y + 0.3, probe.z), 1, ex))
	if top_hit.is_empty() or top_hit.normal.y < 0.85:
		return {}
	var top: float = top_hit.position.y
	# parede logo abaixo do topo (a de baixo pode ser outra caixa, um pouco mais para dentro ou para fora)
	var y := top - 0.08
	var near := Vector3(feet.x, y, feet.z) + n * 0.3
	var face_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(near, near - n * (LEDGE_REACH + 0.6), 1, ex))
	if face_hit.is_empty() or absf(face_hit.normal.y) > 0.3:
		return {}
	var face: Vector3 = face_hit.position
	n = Vector3(face_hit.normal.x, 0.0, face_hit.normal.z).normalized()
	# espaço para ficar de pé em cima
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.7
	q.shape = cap
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), Vector3(face.x, top + 0.9, face.z) - n * 0.5)
	if not space.intersect_shape(q, 1).is_empty():
		return {}
	return {"n": n, "face": Vector3(face.x, top, face.z), "top": top, "height": top - feet.y}


## Pulo com borda à frente: obstáculo baixo = escala; borda alta = pula até ela e fica pendurada.
## Devolve false se não há borda ao alcance (aí é um pulo normal).
func try_ledge(fwd: Vector3) -> bool:
	var l := find_ledge(fwd)
	if l.is_empty():
		return false
	var m: Dictionary = Moves.data().mantle
	var hang: Dictionary = Moves.data().hang
	if l.height >= m.min and l.height <= m.max:
		_start_mantle(l)
		return true
	if l.height > m.max and l.height <= hang.top + GRAB_MAX:
		_start_grab(l)
		return true
	return false


func _face_wall(n: Vector3) -> void:
	p.rotation.y = atan2(n.x, n.z)
	_fwd = -n


func _start_mantle(l: Dictionary) -> void:
	var m: Dictionary = Moves.data().mantle
	_face_wall(l.n)
	var k: Vector3 = l.face + l.n * m.wall
	k.y = l.top - m.top
	var start := p.global_position
	var along := maxf(0.0, (start - k).dot(l.n))
	_base = k + l.n * along
	_base.y = start.y
	_path = Moves.mantle_path(along, k.y - start.y)
	_frames = float(m.frames)
	_begin("mantle")


func _start_grab(l: Dictionary) -> void:
	var hang: Dictionary = Moves.data().hang
	var climb: Dictionary = Moves.data().climb
	_face_wall(l.n)
	_ledge = l
	var root: Vector3 = l.face + l.n * hang.wall
	root.y = l.top - hang.top
	_base = root
	_climb_from = 0.0
	var floor_y := p.global_position.y
	# borda baixa demais para ficar pendurada (pés no chão): o pulo entra direto na subida, no quadro em que
	# os pés já estão acima do chão
	while root.y + Moves.path_at(climb.path, _climb_from).y < floor_y + 0.2 and _climb_from < float(climb.frames):
		_climb_from += 1.0
	var o := Moves.path_at(climb.path, _climb_from)
	_from = p.global_position
	_to = root + _fwd * o.x + Vector3.UP * o.y
	_begin("grab")
	p.model.play("jump")


func _begin(m: String) -> void:
	mode = m
	t = 0.0
	p.crouching = false
	p.aiming = false
	p.velocity = Vector3.ZERO
	p.model.set_aim(false)
	p.model.holster(true)
	if m != "grab":
		p.model.play(m)


func _grab() -> void:
	var s := clampf(t / GRAB_TIME, 0.0, 1.0)
	var flat := _from.lerp(_to, s * s * (3.0 - 2.0 * s))
	flat.y = _from.y + (_to.y - _from.y) * (1.0 - (1.0 - s) * (1.0 - s))  # sobe freando, como num pulo
	p.global_position = flat
	if s < 1.0:
		return
	if _climb_from > 0.0:
		_start_climb(_climb_from)
	else:
		mode = "hang"
		_armed = false
		p.model.set_state("hang")


func _hang() -> void:
	p.velocity = Vector3.ZERO
	var toward := p.move_wish().dot(_fwd)
	if absf(toward) < 0.3:
		_armed = true
	if Input.is_action_just_pressed("jump") or (_armed and toward > 0.5):
		_start_climb(0.0)
	elif Input.is_action_just_pressed("crouch") or (_armed and toward < -0.5):
		drop()


## Solta da borda e cai.
func drop() -> void:
	p.global_position += -_fwd * DROP_PUSH
	p.reset_physics_interpolation()
	mode = ""
	p.model.holster(false)
	p.model.set_state("fall")


func _start_climb(from_frame: float) -> void:
	var climb: Dictionary = Moves.data().climb
	_path = climb.path
	_frames = float(climb.frames)
	mode = "climb"
	t = from_frame / Moves.fps()
	p.model.play_from("climb", t)


## Segue o caminho da raiz (subir da borda, escalar): sem física, o corpo animado é quem encosta no obstáculo.
func _follow() -> void:
	var f := minf(t * Moves.fps(), _frames)
	var o := Moves.path_at(_path, f)
	p.velocity = Vector3.ZERO
	p.global_position = _base + _fwd * o.x + Vector3.UP * o.y
	if f >= _frames:
		mode = ""
		p.model.holster(false)
		p.model.set_state("idle")


# ------------------------------------------------------------------ pegar a arma no baú
func start_pickup(chest: Node) -> void:
	_chest = chest
	_kneel = chest.kneel_transform()
	_from = p.global_position
	_yaw0 = p.rotation.y
	_got_item = false
	_frames = float(Moves.data().rifle.pickup_frames)
	_begin("pickup")
	chest.open()


func _pickup() -> void:
	var f := t * Moves.fps()
	var s := clampf(f / KNEEL_WALK, 0.0, 1.0)
	s = s * s * (3.0 - 2.0 * s)
	p.global_position = _from.lerp(_kneel.origin, s)
	p.rotation.y = lerp_angle(_yaw0, _kneel.basis.get_euler().y, s)
	if not _got_item and f >= float(Moves.data().rifle.grab_frame):
		# as mãos chegaram no fuzil: ele sai do baú e passa para as mãos dela
		_got_item = true
		p.give_weapon(_chest.take_item())
		Sfx.play(p.model, "weapon_pickup", p.global_position + Vector3.UP * 0.8)
	if f >= _frames:
		mode = ""
		p.model.set_state("idle")


# ------------------------------------------------------------------ abate furtivo e golpe crítico
## Inicia o abate furtivo silencioso no inimigo `enemy` (trava o inimigo, guarda a arma, vira para ele e avança).
func start_assassinate(enemy: Node3D) -> void:
	_start_strike("assassinate", enemy, Moves.data().assassinate)


## Inicia o golpe crítico de finalização no inimigo caído `enemy` (pausa o tempo de levantar dele e crava o golpe).
func start_crit_strike(enemy: Node3D) -> void:
	_start_strike("crit_strike", enemy, Moves.data().crit_strike)


func _start_strike(kind: String, enemy: Node3D, d: Dictionary) -> void:
	_enemy = enemy
	_hit_done = false
	_prev = 0.0
	_path = d.path
	_frames = float(d.frames)
	_hit_frame = float(d.hit)
	var to := Enemy._flat(enemy.global_position - p.global_position)
	_fwd = to.normalized() if to.length() > 0.01 else -p.global_basis.z
	_yaw0 = atan2(-_fwd.x, -_fwd.z)
	enemy.stealth_lock(true)
	_begin(kind)
	Sfx.play(p.model, "tail_whoosh", p.global_position + Vector3.UP * 1.2)


func _strike_move(delta: float) -> void:
	var f := t * Moves.fps()
	var dist := Moves.path_at(_path, f).x
	var v := _fwd * (dist - _prev) / delta
	_prev = dist
	p.velocity.x = v.x
	p.velocity.z = v.z
	if not p.is_on_floor():
		p.velocity.y -= Player.GRAVITY * delta
	p.rotation.y = lerp_angle(p.rotation.y, _yaw0, 1.0 - exp(-ROLL_TURN * delta))
	p.move_and_slide()
	if not _hit_done and f >= _hit_frame:
		_hit_done = true
		if is_instance_valid(_enemy) and not bool(_enemy.get("dead")):
			_enemy.stealth_lock(false)
			if mode == "crit_strike":
				_enemy.crit_strike(_fwd, _enemy.global_position + Vector3.UP * 0.5)
				p.camera_rig.shake(0.1, 0.18)
			else:
				_enemy.assassinate(_fwd, _enemy.global_position + Vector3.UP * 1.1)
				p.camera_rig.shake(0.06, 0.12)
	if f >= _frames:
		if is_instance_valid(_enemy):
			_enemy.stealth_lock(false)
			_enemy = null
		mode = ""
		p.model.holster(false)
		p.model.set_state("idle")
