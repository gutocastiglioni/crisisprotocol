class_name AimPitch
extends SkeletonModifier3D
## Mirando, inclina a coluna e o peito para cima/para baixo depois da animação: braços, arma e cabeça acompanham
## a altura do ponto mirado (as poses de mira têm o cano na horizontal). `influence` = quanto da mira está ligada.

const SHARE := {"Spine": 0.4, "Chest": 0.6}  # quanto da inclinação cada osso faz (soma 1)

var pitch := 0.0  # radianos, > 0 = arma para cima
var _bones := {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(pitch) < 0.0005:
		return
	if _bones.is_empty():
		for n in SHARE:
			_bones[n] = sk.find_bone(n)
	for n in SHARE:
		var i: int = _bones[n]
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis
		var g := sk.get_bone_global_pose(i).basis
		# no espaço do esqueleto (glTF) +X é a esquerda dela e +Z a frente: girar em -X levanta a frente
		var r := Basis(Vector3.RIGHT, -pitch * SHARE[n])
		sk.set_bone_pose_rotation(i, (parent.inverse() * r * g).get_rotation_quaternion())
