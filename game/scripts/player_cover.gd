class_name PlayerCover
extends RefCounted
## Encostada de costas na cobertura (só no survival, `GameMode.cover`), por comando: G no teclado (ação "cover") ou dois
## empurrões rápidos do analógico direito para cima (`DOUBLE_FLICK`). Com uma caixa/parede a até `REACH` (em qualquer
## direção; a mais perto), ela vai até ela, vira de costas para a parede, chega a `Moves.cover().wall` do plano e escora o quadril e as omoplatas (CoverL/CoverR em pé,
## CoverCrouchL/R agachada; L/R = olhando para a esquerda/direita dela, de começo para a beirada mais perto, `EDGE_SCAN`).
## A parede tem que existir atrás do glúteo e das omoplatas (`back_stand`/`back_crouch` do heroine_moves.json, gerados com a
## pose): caixa baixa demais para ela em pé (o baú) não serve; a de 1,5 m serve em pé e agachada.
## Direcional para os lados = anda de lado colada na parede (passos laterais, a cabeça virada para onde vai) e para na
## beirada (`EDGE_MARGIN`): dali o V/L3 esgueira pela quina; seguindo empurrando para o lado (`EDGE_HOLD`) sai e contorna. Direcional para fora da parede sai andando; para dentro, fica.
## O mesmo comando solta. Mirar, esgueirar, rolar, pular ou levar golpe também saem; agachar/levantar troca a pose se a parede ainda serve.
## Ocultação: encostada, quem está do outro lado do plano da parede (atrás da caixa) a vê de `HIDE_MULT` do alcance
## (`hides_from`); quem a vê do lado aberto vê normal.

const REACH := 1.0  # parede a até isto do centro dela (distância até o plano)
const DOUBLE_FLICK := 0.35  # segundo empurrão do analógico direito para cima até isto depois do primeiro: encosta/solta
const FAN := [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0, 180.0]  # raios em volta dela (graus a partir da frente)
const RAY_Y := 1.2  # altura dos raios que acham a parede (em pé; agachada `CROUCH_RAY_Y`)
const CROUCH_RAY_Y := 0.75
const PLANE_TOL := 0.08  # glúteo e omoplatas no mesmo plano (caixa reta)
const MAX_SLOPE := 0.3  # normal com componente vertical acima disto não é parede
const GLIDE := 1.6  # m/s até o lugar encostado
const WALK_OUT := 0.3  # direcional empurrado pelo menos isto para fora da parede: sai andando
const SLIDE_MIN := 0.2  # direcional para o lado pelo menos isto: anda colada
const SLIDE_SCALE := 0.8  # da velocidade do passo lateral
const EDGE_MARGIN := 0.18  # para quando a parede acaba a isto do centro dela (meio corpo ainda encostado)
const EDGE_HOLD := 0.6  # na beirada, segue empurrando para o lado por isto: sai e contorna a quina andando
const EDGE_SCAN := 2.5  # procura a beirada mais perto até isto para cada lado
const LOOK := 0.9  # cabeça virada para onde anda (radianos)
const LOOK_RATE := 5.0
const LOST := 0.25  # a parede sumiu de trás dela (porta abriu) a mais que isto do lugar: sai
const HIDE_MULT := 0.7

var p: Player
var active := false
var side := 1  # olha para a esquerda (1) ou para a direita (-1) dela
var normal := Vector3.ZERO  # da parede para ela (horizontal)
var point := Vector3.ZERO  # um ponto do plano da parede
var at_edge := false  # andando de lado, chegou na beirada
var _crouched := false
var _flick_t := INF  # desde o último empurrão do analógico direito para cima
var _look := 0.0  # giro da cabeça andando de lado
var _edge_t := 0.0


func _init(player: Player) -> void:
	p = player


static func enabled() -> bool:
	return GameMode.value("cover") and not Moves.cover().is_empty()


## Um passo da física com ela no chão, no controle normal, sem mirar nem esgueirar; devolve true se está encostada (aí
## `locomotion` diz a velocidade).
func update(delta: float, wish: Vector3) -> bool:
	if not enabled():
		return false
	var toggle := _command(delta)
	if active and toggle:
		cancel()
		return false
	if active:
		if wish.dot(normal) > WALK_OUT and wish.dot(normal) > absf(wish.dot(_right())):
			cancel()  # andou para longe da parede: sai e segue andando
			return false
		if p.crouching != _crouched:
			if not _fits(p.global_position, normal, point, p.crouching):
				cancel()
				return false
			_crouched = p.crouching
		if _wall_gone() or _edge_t >= EDGE_HOLD:
			cancel()
			return false
		return true
	if not toggle:
		return false
	var w := find()
	return not w.is_empty() and _enter(w)


## O comando de encostar/soltar neste passo: G, ou o segundo empurrão do analógico direito para cima até DOUBLE_FLICK depois
## do primeiro.
func _command(delta: float) -> bool:
	_flick_t += delta
	var hit := Input.is_action_just_pressed("cover")
	if Input.is_action_just_pressed("look_up"):
		if _flick_t <= DOUBLE_FLICK:
			hit = true
			_flick_t = INF
		else:
			_flick_t = 0.0
	return hit


## Parede mais perto em volta dela: {"normal", "point", "dist" (do centro dela ao plano)} ou {}.
func find() -> Dictionary:
	var from := p.global_position + Vector3.UP * (CROUCH_RAY_Y if p.crouching else RAY_Y)
	var fwd := -p.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var best := {}
	for a: float in FAN:
		var hit := _ray(from, from + fwd.rotated(Vector3.UP, deg_to_rad(a)) * (REACH + 0.3))
		if hit.is_empty() or absf(hit.normal.y) > MAX_SLOPE:
			continue
		var n := Vector3(hit.normal.x, 0.0, hit.normal.z).normalized()
		var dist: float = (from - hit.position).dot(n)
		if dist > 0.0 and dist <= REACH and (best.is_empty() or dist < float(best.dist)):
			best = {"normal": n, "point": hit.position, "dist": dist}
	return best


## Encosta na parede `w`: confere que ela cobre as costas no lugar encostado e escolhe o lado para onde olha.
func _enter(w: Dictionary) -> bool:
	var n: Vector3 = w.normal
	var goal := p.global_position + n * (float(Moves.cover().wall) - float(w.dist))
	if not _fits(goal, n, w.point, p.crouching):
		return false
	active = true
	normal = n
	point = w.point
	_crouched = p.crouching
	at_edge = false
	_look = 0.0
	# olha para a beirada mais perto (sem beirada à vista, para a esquerda dela)
	var right := _right()
	var l := _edge_dist(goal, -right, EDGE_SCAN)
	var r := _edge_dist(goal, right, EDGE_SCAN)
	side = -1 if r < l else 1
	return true


## Velocidade no plano enquanto encostada: de costas para a parede, na distância dela; direcional para o lado anda colada.
func locomotion(delta: float, wish: Vector3) -> Vector3:
	var right := _right()
	var dist := (p.global_position - point).dot(normal)
	# chega à distância da parede (de onde parou, ou se algo a empurrou)
	var hv := normal * clampf((float(Moves.cover().wall) - dist) / maxf(delta, 0.001), -GLIDE, GLIDE)
	var tang := wish.dot(right)
	var prefix := "crouch_" if p.crouching else ""
	var look := 0.0
	at_edge = false
	if absf(tang) > SLIDE_MIN:
		var dir := right * signf(tang)
		side = -1 if tang > 0.0 else 1
		look = LOOK * side
		if _edge_dist(p.global_position, dir, EDGE_MARGIN) <= EDGE_MARGIN:
			at_edge = true  # a parede acaba logo ali: para com metade do corpo ainda encostada
			_edge_t += delta
		else:
			var speed := Moves.speed(prefix + "strafe") * SLIDE_SCALE * GameMode.move_scale() * minf(1.0, absf(tang) / 0.6)
			hv += dir * speed
			p.model.set_state(prefix + ("strafe_r" if tang > 0.0 else "strafe_l"), speed / Moves.speed(prefix + "strafe"))
	if not at_edge:
		_edge_t = 0.0
	if absf(tang) <= SLIDE_MIN or at_edge:
		p.model.set_state(state())
	_look = move_toward(_look, look, LOOK_RATE * delta)
	p.model.set_head_look(_look)
	p._face(normal, delta)
	return hv


## Estado do corpo (HeroineModel) encostada e parada.
func state() -> String:
	return ("cover_crouch_" if p.crouching else "cover_") + ("l" if side == 1 else "r")


func cancel() -> void:
	if active and p.model:
		p.model.set_head_look(0.0)
	active = false
	at_edge = false
	_look = 0.0
	_edge_t = 0.0


## Encostada e do outro lado do plano da parede (atrás da caixa) quem olha de `eye`: ela aparece menos.
func hides_from(eye: Vector3) -> bool:
	return active and (eye - point).dot(normal) < 0.0


## A parede cobre as costas dela em `at` (glúteo e omoplatas no mesmo plano, atrás dela).
func _fits(at: Vector3, n: Vector3, on_plane: Vector3, crouched: bool) -> bool:
	var data := Moves.cover()
	for h: float in (data.back_crouch if crouched else data.back_stand):
		var from := Vector3(at.x, at.y + h, at.z)
		var hit := _ray(from, from - n * (float(data.wall) + 0.2))
		if hit.is_empty() or absf((hit.position - on_plane).dot(n)) > PLANE_TOL or absf(hit.normal.y) > MAX_SLOPE:
			return false
	return true


## Distância até onde a parede de trás acaba, andando de `at` na direção `dir` (ao longo dela); INF = não acaba até `upto`.
func _edge_dist(at: Vector3, dir: Vector3, upto: float) -> float:
	var o := 0.0
	while o <= upto + 0.001:
		if not _fits(at + dir * o, normal, point, p.crouching):
			return o
		o += 0.06
	return INF


func _right() -> Vector3:
	# de costas para a parede ela olha para `normal`: a direita dela
	return normal.cross(Vector3.UP).normalized()


func _wall_gone() -> bool:
	var from := p.global_position + Vector3.UP * (CROUCH_RAY_Y if p.crouching else RAY_Y)
	var hit := _ray(from, from - normal * ((p.global_position - point).dot(normal) + LOST))
	return hit.is_empty()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [p.get_rid()])
	return p.get_world_3d().direct_space_state.intersect_ray(q)
