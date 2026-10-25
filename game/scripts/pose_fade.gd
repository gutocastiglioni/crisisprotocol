class_name PoseFade
extends SkeletonModifier3D
## Saída do ragdoll sem tranco: enquanto o ragdoll manda no esqueleto, guarda a pose em que ele deixou o corpo; ao
## levantar, o esqueleto parte dessa pose e vai para a da animação em TIME segundos. Fica depois do Ragdoll na lista de
## modificadores. A trança fica de fora (a mola cuida dela).

const TIME := 0.35

var recording := false
var weight := 0.0  # 1 = pose guardada, 0 = animação
var _poses: Array[Transform3D] = []
var _bones: Array[int] = []


func _process(delta: float) -> void:
	weight = maxf(0.0, weight - delta / TIME)


## Começa a passagem para a animação. `old_skeleton` = transformação global do esqueleto quando a pose foi guardada
## (a cápsula pode ter girado e andado até o corpo): os ossos sem pai são levados para o lugar novo.
func begin(old_skeleton: Transform3D) -> void:
	recording = false
	var sk := get_skeleton()
	if sk == null or _poses.is_empty():
		return
	var fix := sk.global_transform.affine_inverse() * old_skeleton
	for i in _bones:
		if sk.get_bone_parent(i) < 0:
			_poses[i] = fix * _poses[i]
	weight = 1.0


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bones.is_empty():
		_poses.resize(sk.get_bone_count())
		for i in sk.get_bone_count():
			if not sk.get_bone_name(i).begins_with("Braid"):
				_bones.append(i)
	if recording:
		for i in _bones:
			_poses[i] = sk.get_bone_pose(i)
		return
	if weight <= 0.0:
		return
	var w := smoothstep(0.0, 1.0, weight)
	for i in _bones:
		var a := sk.get_bone_pose(i)
		var b := _poses[i]
		sk.set_bone_pose_position(i, a.origin.lerp(b.origin, w))
		sk.set_bone_pose_rotation(i, a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(), w))
