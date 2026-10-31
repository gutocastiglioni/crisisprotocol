class_name TurnSway
extends SkeletonModifier3D
## Inércia dos dinossauros ao virar, depois da animação e antes dos pés presos (FootPlant):
## - a cabeça entra na curva antes do corpo (pescoço e cabeça giram para o lado da virada);
## - a cauda fica para trás no mundo e volta com mola (base e ponta com molas próprias: a ponta chicoteia atrasada);
## - o corpo inclina para dentro da curva conforme a velocidade (o FootPlant segura os pés no chão).
## Medidas pela perna do esqueleto, como no FootPlant: o alossauro (~3x) tem molas mais lentas.

const LEAD := 0.22  # s: quanto a cabeça adianta a virada (rad de pescoço por rad/s)
const LEAD_MAX := 0.6
const HEAD_SHARE := {"Neck1": 0.3, "Neck2": 0.3, "Head": 0.4}
const TAIL_SHARE := {"Tail1": 0.2, "Tail2": 0.3}  # base (mola 1)
const TIP_SHARE := {"Tail3": 0.3, "Tail4": 0.4}  # ponta (mola 2, atrás da base)
const TAIL_K := 55.0  # mola (1/s²) e amortecimento (1/s) da cauda do raptor
const TAIL_C := 7.0
const TAIL_MAX := 0.7
const BANK := 0.6  # da inclinação de uma curva de verdade (atan(v·ω/g))
const BANK_MAX := 0.16

var _bones := {}
var _size := 1.0
var _yaw := NAN
var _pos := Vector3.ZERO
var _rate := 0.0  # rad/s da virada, suavizado
var _speed := 0.0
var _tail := 0.0
var _tail_v := 0.0
var _tip := 0.0
var _tip_v := 0.0


## Esquece o embalo (reinício, teleporte, ragdoll).
func reset() -> void:
	_yaw = NAN
	_rate = 0.0
	_speed = 0.0
	_tail = 0.0
	_tail_v = 0.0
	_tip = 0.0
	_tip_v = 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		for n in ["Hips", "Thigh_L", "Shin_L", "Meta_L", "Toe_L"] + HEAD_SHARE.keys() + TAIL_SHARE.keys() + TIP_SHARE.keys():
			_bones[n] = sk.find_bone(n)
		var leg := 0.0
		for pair in [["Thigh_L", "Shin_L"], ["Shin_L", "Meta_L"], ["Meta_L", "Toe_L"]]:
			leg += sk.get_bone_global_rest(_bones[pair[0]]).origin.distance_to(sk.get_bone_global_rest(_bones[pair[1]]).origin)
		_size = leg / FootPlant.RAPTOR_LEG
	var dt := clampf(get_process_delta_time(), 0.0, 0.1)
	var xf := sk.get_global_transform_interpolated()
	var yaw := xf.basis.get_euler().y
	if is_nan(_yaw) or dt <= 0.0:
		_yaw = yaw
		_pos = xf.origin
		return
	var dyaw := wrapf(yaw - _yaw, -PI, PI)
	var moved := Vector2(xf.origin.x - _pos.x, xf.origin.z - _pos.z).length()
	_yaw = yaw
	_pos = xf.origin
	if absf(dyaw) > 1.0 or moved > 2.0 * _size:  # teleporte/reinício: sem chicotada
		reset()
		_yaw = yaw
		_pos = xf.origin
		return
	var k := 1.0 - exp(-8.0 * dt)
	_rate = lerpf(_rate, dyaw / dt, k)
	_speed = lerpf(_speed, moved / dt, k)
	# molas da cauda: no mundo ela fica onde estava (-dyaw) e volta para trás do corpo; a ponta segue a base atrasada
	var stiff := TAIL_K / _size
	var damp := TAIL_C / sqrt(_size)
	_tail -= dyaw
	_tail_v += (-stiff * _tail - damp * _tail_v) * dt
	_tail = clampf(_tail + _tail_v * dt, -TAIL_MAX, TAIL_MAX)
	_tip -= dyaw
	_tip_v += (-stiff * 0.7 * (_tip - _tail) - damp * 0.8 * _tip_v) * dt
	_tip = clampf(_tip + _tip_v * dt, -TAIL_MAX * 1.4, TAIL_MAX * 1.4)
	var bank := clampf(atan(_speed * _rate / 9.8) * BANK, -BANK_MAX, BANK_MAX)
	# no espaço do esqueleto: +X é a esquerda dele, +Y para cima, +Z a frente; +Y positivo = virar para a esquerda
	if absf(bank) > 0.001:
		_turn(sk, "Hips", Basis(Vector3.BACK, -bank))
	var lead := clampf(_rate * LEAD, -LEAD_MAX, LEAD_MAX)
	for n in HEAD_SHARE:
		_turn(sk, n, Basis(Vector3.UP, lead * HEAD_SHARE[n]))
	for n in TAIL_SHARE:
		_turn(sk, n, Basis(Vector3.UP, _tail * TAIL_SHARE[n]))
	for n in TIP_SHARE:
		_turn(sk, n, Basis(Vector3.UP, (_tip - _tail * 0.5) * TIP_SHARE[n]))


## Gira o osso `n` por `r` no espaço do esqueleto (os filhos vão junto).
func _turn(sk: Skeleton3D, n: String, r: Basis) -> void:
	var i: int = _bones[n]
	if i < 0:
		return
	var g := sk.get_bone_global_pose(i).basis
	var p := sk.get_bone_parent(i)
	var parent := sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
	sk.set_bone_pose_rotation(i, (parent.inverse() * r * g).get_rotation_quaternion())
