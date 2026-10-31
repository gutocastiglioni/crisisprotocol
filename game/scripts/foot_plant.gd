class_name FootPlant
extends SkeletonModifier3D
## Pés presos no chão para os dinossauros (raptor e alossauro, mesmos ossos), depois da animação.
## A animação foi feita para o corpo andar reto na velocidade dela; o jogo gira o corpo (`Enemy._face`), anda mais
## devagar ou é empurrado, e o pé de apoio iria junto, patinando. Aqui o pé que a animação põe no chão fica preso no
## lugar do mundo onde tocou (IK de coxa e canela; o metatarso e os dedos mantêm a inclinação da animação) até a
## animação levantá-lo; aí ele volta para onde a animação o leva durante o balanço. Parado ou devagar, quando o corpo
## se afasta demais de um pé preso (girando no lugar), ele dá um passo: levanta e vai até onde a animação o quer, um pé
## de cada vez. No ar (salto) os pés seguem a animação. Medidas pela perna do esqueleto (o alossauro é ~3x).

signal stepped(foot: Vector3)  ## passo dado por aqui (não pela animação): o modelo toca o som

const LEGS := ["L", "R"]
const RAPTOR_LEG := 1.05  # coxa + canela + metatarso do raptor (m): as medidas abaixo são para ela
const CONTACT := 0.035  # acima da altura da bola do pé em repouso: ainda está no chão
const STEP_DIST := 0.17  # pé preso a esta distância de onde a animação o quer: passo
const STEP_TIME := 0.2
const STEP_LIFT := 0.1
const RELEASE_TIME := 0.12  # pé solto volta para a animação neste tempo
const LOST_DIST := 1.2  # mais longe que isto (reinício, teleporte): solta sem passo

enum { FREE, PLANTED, STEPPING }

var grounded := true  ## o dono está no chão (o modelo atualiza)
var _size := 1.0
var _rest_h := 0.05
var _bones := {}  # lado -> [coxa, canela, metatarso, dedo]
var _hips := -1
var _mode := [FREE, FREE]
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # mundo
var _offset: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]  # mundo: alvo - animação, some no balanço
var _from: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _step_t := [0.0, 0.0]


func _setup(sk: Skeleton3D) -> void:
	_hips = sk.find_bone("Hips")
	var leg := 0.0
	for s in LEGS:
		var ids: Array[int] = []
		for b in ["Thigh_", "Shin_", "Meta_", "Toe_"]:
			ids.append(sk.find_bone(b + s))
		_bones[s] = ids
	var ids: Array[int] = _bones["L"]
	for k in 3:
		leg += sk.get_bone_global_rest(ids[k]).origin.distance_to(sk.get_bone_global_rest(ids[k + 1]).origin)
	_size = leg / RAPTOR_LEG
	_rest_h = sk.get_bone_global_rest(ids[3]).origin.y


## Esquece os pés presos (reinício, ragdoll, teleporte): voltam a seguir a animação na hora.
func reset() -> void:
	for i in 2:
		_mode[i] = FREE
		_offset[i] = Vector3.ZERO


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		_setup(sk)
	var dt := clampf(get_process_delta_time(), 0.0, 0.1)
	var xf := sk.get_global_transform_interpolated()
	var ground_y := xf.origin.y
	var targets: Array[Vector3] = []
	for i in 2:
		var ids: Array[int] = _bones[LEGS[i]]
		targets.append(_follow(i, xf * sk.get_bone_global_pose(ids[3]).origin, ground_y, dt))
	for i in 2:
		var ids: Array[int] = _bones[LEGS[i]]
		var t := xf.affine_inverse() * targets[i]
		if t.distance_squared_to(sk.get_bone_global_pose(ids[3]).origin) > 1e-8:
			_solve(sk, ids, t)


## Onde o pé `i` fica neste quadro (mundo), dado onde a animação o põe (`a`).
func _follow(i: int, a: Vector3, ground_y: float, dt: float) -> Vector3:
	var on_ground := grounded and a.y - ground_y < (_rest_h + CONTACT) * _size
	var other := 1 - i
	match _mode[i]:
		PLANTED:
			var err := _flat(_lock[i] - a).length()
			if not on_ground or err > LOST_DIST * _size:
				_release(i, Vector3(_lock[i].x, a.y, _lock[i].z) - a if err <= LOST_DIST * _size else Vector3.ZERO)
			elif err > STEP_DIST * _size and _mode[other] != STEPPING:
				_mode[i] = STEPPING
				_step_t[i] = 0.0
				_from[i] = _lock[i]
				return Vector3(_lock[i].x, a.y, _lock[i].z)
			else:
				return Vector3(_lock[i].x, a.y, _lock[i].z)
		STEPPING:
			_step_t[i] += dt / (STEP_TIME * sqrt(_size))
			var s := smoothstep(0.0, 1.0, _step_t[i])
			var p := _from[i].lerp(a, s)
			p.y = a.y + STEP_LIFT * _size * sin(PI * minf(_step_t[i], 1.0))
			if not grounded or _step_t[i] >= 1.0:
				if _step_t[i] >= 1.0:
					stepped.emit(a)
				_release(i, p - a)
				if on_ground:
					_plant(i, a)
				return p
			return p
	# solto: segue a animação, com a diferença de onde estava sumindo aos poucos
	_offset[i] *= exp(-dt / (RELEASE_TIME * 0.35))
	var p := a + _offset[i]
	if on_ground and _offset[i].length() < 0.02 * _size:
		_plant(i, p)
	return p


func _plant(i: int, p: Vector3) -> void:
	_mode[i] = PLANTED
	_lock[i] = p
	_offset[i] = Vector3.ZERO


func _release(i: int, offset: Vector3) -> void:
	_mode[i] = FREE
	_offset[i] = offset


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## IK da perna no espaço do esqueleto: a bola do pé (início do osso Toe) em `target`; o metatarso mantém a direção
## da animação, o joelho fica no plano em que a animação o dobrou; coxa e canela giram o mínimo para chegar.
func _solve(sk: Skeleton3D, ids: Array[int], target: Vector3) -> void:
	var g0 := sk.get_bone_global_pose(ids[0])
	var g1 := sk.get_bone_global_pose(ids[1])
	var g2 := sk.get_bone_global_pose(ids[2])
	var hip := g0.origin
	var knee := g1.origin
	var ankle := g2.origin
	var meta := sk.get_bone_global_pose(ids[3]).origin - ankle
	var l1 := hip.distance_to(knee)
	var l2 := knee.distance_to(ankle)
	var want := target - meta
	var to := want - hip
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var u := to.normalized()
	want = hip + u * d
	# lado para onde o joelho dobra: o da animação, tirado o componente ao longo de quadril-tornozelo
	var bend := (knee - hip) - u * (knee - hip).dot(u)
	if bend.length_squared() < 1e-8:
		bend = (knee - hip) - (ankle - hip).normalized() * (knee - hip).dot((ankle - hip).normalized())
	if bend.length_squared() < 1e-8:
		return
	bend = bend.normalized()
	var along := (l1 * l1 + d * d - l2 * l2) / (2.0 * d)
	var new_knee := hip + u * along + bend * sqrt(maxf(l1 * l1 - along * along, 0.0))
	var r0 := Basis(Quaternion((knee - hip).normalized(), (new_knee - hip).normalized()))
	var b0 := r0 * g0.basis
	var shin_dir := r0 * (ankle - knee)
	var r1 := Basis(Quaternion(shin_dir.normalized(), (want - new_knee).normalized()))
	var b1 := r1 * r0 * g1.basis
	var parent := sk.get_bone_global_pose(_hips).basis if _hips >= 0 else Basis()
	sk.set_bone_pose_rotation(ids[0], (parent.inverse() * b0).get_rotation_quaternion())
	sk.set_bone_pose_rotation(ids[1], (b0.inverse() * b1).get_rotation_quaternion())
	sk.set_bone_pose_rotation(ids[2], (b1.inverse() * g2.basis).get_rotation_quaternion())
