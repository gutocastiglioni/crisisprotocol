class_name LeanTilt
extends SkeletonModifier3D
## Esgueirando pela quina (PlayerLean): inclina coluna, peito e pescoço para o lado depois da animação (e da AimPitch),
## em pé, agachada, com e sem mira: a cabeça e a arma saem da cobertura e as pernas ficam onde estão.

const SHARE := {"Spine": 0.45, "Chest": 0.4, "Neck": 0.15}  # quanto da inclinação cada osso faz (soma 1)

var roll := 0.0  # radianos, > 0 = para a direita dela
var _bones := {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or absf(roll) < 0.0005:
		return
	if _bones.is_empty():
		for n in SHARE:
			_bones[n] = sk.find_bone(n)
	for n in SHARE:
		var i: int = _bones[n]
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis
		var g := sk.get_bone_global_pose(i).basis
		# no espaço do esqueleto (glTF) +X é a esquerda dela e +Z a frente: girar em +Z leva o alto para -X (a direita)
		var r := Basis(Vector3.BACK, roll * SHARE[n])
		sk.set_bone_pose_rotation(i, (parent.inverse() * r * g).get_rotation_quaternion())
