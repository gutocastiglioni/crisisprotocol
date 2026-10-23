class_name HeadLook
extends SkeletonModifier3D
## Move o pescoço e a cabeça do personagem para vigiar os arredores.
## Distribui a rotação suavemente entre Neck e Head sem deslizar o corpo.

const SHARE := {"Neck": 0.35, "Head": 0.65}

var yaw := 0.0    # radianos (> 0 = esquerda, < 0 = direita)
var pitch := 0.0  # radianos (> 0 = cima, < 0 = baixo)

var _bones := {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or (absf(yaw) < 0.0005 and absf(pitch) < 0.0005):
		return
	if _bones.is_empty():
		for n in SHARE:
			_bones[n] = sk.find_bone(n)
	for n in SHARE:
		var i: int = _bones[n]
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis
		var g := sk.get_bone_global_pose(i).basis
		# no espaço do esqueleto: +X é a esquerda dela, +Y para cima, +Z a frente
		var r := Basis(Vector3.UP, yaw * SHARE[n]) * Basis(Vector3.RIGHT, -pitch * SHARE[n])
		sk.set_bone_pose_rotation(i, (parent.inverse() * r * g).get_rotation_quaternion())
