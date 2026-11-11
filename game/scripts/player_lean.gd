class_name PlayerLean
extends RefCounted
## Esgueirar pela quina (ação "lean": L3 / V; o L3 também é a corrida forte segurando; em pé ou agachada, com e sem mira). Liga e desliga com um toque (não precisa
## segurar): com uma parede/caixa logo à frente da câmera (`REACH`), ela procura a beirada dessa cobertura para os dois lados (`SCAN`) e se esgueira para
## a mais perto: vira para a frente da câmera, inclina o tronco (LeanTilt, até `ANGLE`) e, se a beirada está longe para só
## inclinar, dá um passo de lado (`step`, até `STEP_MAX`) até a cabeça passar dela por `CLEAR`. A câmera vai para o lado da
## quina (`cam_side`). Outro toque, volta ao lugar de onde saiu; empurrar o direcional (`WALK_OUT`) sai da quina e ela anda dali
## mesmo, sem voltar. Sem quina por perto, o toque não faz nada.
## Os inimigos olham e miram no que ficou de fora (`sight_point`: a cabeça), não no peito escondido atrás da quina.

const HEIGHT := 1.45  # altura dos raios que procuram a quina (perto da cabeça), em pé
const CROUCH_HEIGHT := 1.1  # agachada
const REACH := 1.0  # parede/caixa a até isto à frente (do centro dela) é cobertura
const PAST := 0.5  # um raio que vai pelo menos isto além da cobertura já passou da beirada
const SCAN := 0.8  # procura a beirada até isto para cada lado
const SCAN_STEP := 0.1
const BODY := 0.3  # o corpo dela para o lado (o caminho até a beirada tem que estar livre)
const ANGLE := deg_to_rad(30.0)  # inclinação do tronco esgueirada
const HEAD_REACH := 0.18  # quanto a cabeça vai para o lado com o tronco em ANGLE (medido no teste)
const HEAD_Y := 1.55  # altura da cabeça em pé / agachada (para onde os inimigos olham)
const CROUCH_HEAD_Y := 1.2
const CLEAR := 0.25  # a cabeça passa da beirada por isto
const STEP_MAX := 0.6
const STEP_SPEED := 2.2
const TIME := 0.18  # para inclinar e para voltar
const CAM_SIDE := 0.75  # desvio da câmera para o lado da quina
const WALK_OUT := 0.5  # direcional empurrado pelo menos isto: sai da quina andando (menos que isto é folga do analógico)

var p: Player
var side := 0  # lado em que está esgueirada agora (1 = direita, -1 = esquerda, 0 = não está)
var amount := 0.0  # 0..1: quanto da inclinação está ligada (sobe e desce em TIME)
var step := 0.0  # passo de lado até a beirada (m)
var returning := false
var _last_side := 1
var _anchor := Vector3.ZERO  # onde ela estava ao começar
var _forward := Vector3.FORWARD  # frente da câmera ao começar (ela fica virada para lá)


func _init(player: Player) -> void:
	p = player


## Quina mais perto na frente da câmera: {"side": 1|-1, "edge": distância do centro dela até a beirada} ou {}.
func find() -> Dictionary:
	var fwd := -p.camera_rig.yaw_basis().z
	var right := fwd.cross(Vector3.UP)
	var base := p.global_position + Vector3.UP * (CROUCH_HEIGHT if p.crouching else HEIGHT)
	var near := _ray(base, base + fwd * REACH)
	if near == INF:
		return {}
	var best := {}
	for s: int in [1, -1]:
		var o := SCAN_STEP
		while o <= SCAN + 0.001:
			var from := base + right * (s * o)
			# parede do lado (corredor, canto fechado): o corpo não passa até ali
			if _ray(base, from + right * (s * BODY)) != INF:
				break
			if _ray(from, from + fwd * (near + PAST)) == INF:
				var edge := o - SCAN_STEP * 0.5
				if best.is_empty() or edge < float(best.edge):
					best = {"side": s, "edge": edge}
				break
			o += SCAN_STEP
	return best


## Um passo da física com ela no chão e no controle normal; devolve true se a esgueirada está mandando no movimento
## (aí `locomotion` diz a velocidade).
func update(delta: float, wish: Vector3) -> bool:
	# no survival o V/L3 encosta (PlayerCover): esgueirar vem da mira encostada na beirada (`peek`)
	var tap := Input.is_action_just_pressed("lean") and not PlayerCover.enabled()
	if tap and side != 0:
		side = 0
		returning = true
	elif tap:
		var q := find()
		if not q.is_empty():
			side = q.side
			_last_side = side
			step = clampf(float(q.edge) + CLEAR - HEAD_REACH, 0.0, STEP_MAX)
			_anchor = p.global_position if not returning else _anchor
			_forward = -p.camera_rig.yaw_basis().z
			returning = false
	if wish.length() > WALK_OUT and (side != 0 or returning):
		# andou: sai da quina e segue dali (sem voltar ao lugar)
		side = 0
		returning = false
	amount = move_toward(amount, 1.0 if side != 0 else 0.0, delta / TIME)
	p.model.set_lean(ANGLE * amount * _last_side)
	if returning and amount <= 0.0 and _flat(_anchor - p.global_position).length() < 0.03:
		returning = false
	return side != 0 or returning


## Esgueira pela beirada `s` (1 = direita, -1 = esquerda de quem olha para `fwd`) a `edge` m dela, virada para `fwd`
## (PlayerCover: mirou encostada na beirada).
func peek(s: int, edge: float, fwd: Vector3) -> void:
	side = s
	_last_side = s
	step = clampf(edge + CLEAR - HEAD_REACH, 0.0, STEP_MAX)
	_anchor = p.global_position if not returning else _anchor
	_forward = Vector3(fwd.x, 0.0, fwd.z).normalized()
	returning = false


## Volta da quina para o lugar de onde saiu (soltou a mira).
func unpeek() -> void:
	if side != 0:
		side = 0
		returning = true


## Velocidade no plano enquanto esgueira (passo de lado até a beirada) ou volta (até o lugar de onde saiu). Sem mira, ela
## fica virada para a frente da câmera do começo; mirando, quem a vira é a mira.
func locomotion(delta: float) -> Vector3:
	var goal := _anchor
	if side != 0:
		goal += _forward.cross(Vector3.UP) * (side * step)
	var to := _flat(goal - p.global_position)
	var hv := Vector3.ZERO
	if to.length() > 0.01:
		hv = to.normalized() * minf(STEP_SPEED, to.length() / delta)
	if not p.aiming:
		p._face(_forward, delta)
	var prefix := "crouch_" if p.crouching else ""
	if hv.length() > 0.2:
		var local := p.global_basis.inverse() * hv
		p.model.set_state(prefix + ("strafe_r" if local.x > 0.0 else "strafe_l"), hv.length() / Moves.speed(prefix + "strafe"))
	else:
		p.model.set_state("crouch" if p.crouching else "idle")
	return hv


## Sai na hora (cambalhota, pulo, golpe, movimento com caminho, reinício): sem inclinação e sem voltar ao lugar.
func cancel() -> void:
	side = 0
	returning = false
	amount = 0.0
	if p.model:
		p.model.set_lean(0.0)


## Desvio da câmera para o lado da quina (-1..1: esquerda..direita, pela inclinação).
func cam_side() -> float:
	return amount * _last_side


## Para onde os inimigos olham e miram: o peito; esgueirada, a cabeça que saiu da cobertura.
func sight_point() -> Vector3:
	if amount < 0.3:
		return p.global_position + Vector3.UP * (0.8 if p.crouching else 1.2)
	var head := p.global_position + Vector3.UP * (CROUCH_HEAD_Y if p.crouching else HEAD_Y)
	return head + p.global_basis.x * (_last_side * HEAD_REACH * amount)


func _ray(from: Vector3, to: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return from.distance_to(hit.position) if hit else INF


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
