class_name HitFlinch
extends SkeletonModifier3D
## Tranco do tiro nos dinossauros: o tronco, o pescoço e a cabeça são empurrados para o lado de onde veio o golpe e
## voltam com mola (por cima de qualquer animação, sem parar o que ele está fazendo: o tiro não interrompe ataque),
## com um giro da cabeça para um lado. Modificador do RaptorModel (antes do FootPlant: as pernas seguem plantadas).

const SHARE := {"Spine": 0.25, "Chest": 0.3, "Neck1": 0.2, "Neck2": 0.15, "Head": 0.25}
const K := 170.0  # mola (1/s²) e amortecimento (1/s): volta em ~0,4 s, sem quicar
const C := 16.0
const KICK := 8.0  # rad/s por golpe de força 1 (pistola ~0,7: a cabeça recua ~7 cm)
const MAX := 0.45  # rad

var _bones := {}
var _axis := Vector3.RIGHT  # eixo do tranco no espaço do esqueleto
var _a := 0.0
var _v := 0.0
var _twist := 0.0


## Golpe vindo na direção `dir` (do atirador para ele, no mundo), força ~1 para um tiro de pistola.
func hit(dir: Vector3, strength: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var d := sk.global_basis.inverse() * dir
	d.y = 0.0
	if d.length() < 0.01:
		return
	# girar em volta de cima x direção leva o alto do corpo para o lado do golpe (para longe do atirador)
	_axis = Vector3.UP.cross(d.normalized()).normalized()
	_v += KICK * clampf(strength, 0.3, 2.0)
	_twist = randf_range(-0.6, 0.6)


func reset() -> void:
	_a = 0.0
	_v = 0.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		for n in SHARE:
			_bones[n] = sk.find_bone(n)
	var dt := clampf(get_process_delta_time(), 0.0, 0.1)
	_v += (-K * _a - C * _v) * dt
	_a = clampf(_a + _v * dt, -MAX, MAX)
	if absf(_a) < 0.001 and absf(_v) < 0.01:
		return
	for n in SHARE:
		var i: int = _bones[n]
		if i < 0:
			continue
		var r := Basis(_axis, _a * SHARE[n])
		if n == "Head":
			r = Basis(Vector3.UP, _a * _twist) * r
		var g := sk.get_bone_global_pose(i).basis
		var p := sk.get_bone_parent(i)
		var parent := sk.get_bone_global_pose(p).basis if p >= 0 else Basis()
		sk.set_bone_pose_rotation(i, (parent.inverse() * r * g).get_rotation_quaternion())
