class_name HangAim
extends SkeletonModifier3D
## Pendurada na borda mirando com a pistola (PlayerMoves "hang", `Player.hang_aiming`): a mão esquerda segue presa na
## borda (a animação Hang); o braço direito vem da pose de mira da pistola (nó "hang_aim" do HeroineModel, só o braço) e
## aqui o tronco gira para o lado do alvo (até MAX_TWIST, TWIST do giro pedido) e o braço aponta a mão para ele: a pistola
## fica na linha do ponto mirado. `amount` = quanto está ligado (0..1, sobe e desce suave), `target` = ponto no mundo.

const TWIST := 0.5  # fração do giro até o alvo que o tronco faz (o braço faz o resto)
const MAX_TWIST := 0.9  # rad
const SHARE := {"Spine": 0.4, "Chest": 0.6}

var amount := 0.0
var target := Vector3.ZERO
var _bones := {}


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or amount < 0.01:
		return
	if _bones.is_empty():
		for n in ["Spine", "Chest", "UpperArm_R", "Hand_R"]:
			_bones[n] = sk.find_bone(n)
		if _bones.values().has(-1):
			_bones.clear()
			return
	var t := sk.global_transform.affine_inverse() * target  # no espaço do esqueleto (+Y para cima)
	# giro do tronco em volta do vertical, para o lado do alvo
	var chest: Transform3D = sk.get_bone_global_pose(_bones.Chest)
	var fwd := chest.basis.z  # glTF: +Z = a frente dela
	var to := t - chest.origin
	var yaw := Vector2(fwd.x, fwd.z).angle_to(Vector2(to.x, to.z)) if Vector2(to.x, to.z).length() > 0.01 else 0.0
	var twist := clampf(-yaw * TWIST, -MAX_TWIST, MAX_TWIST) * amount
	for n in SHARE:
		var i: int = _bones[n]
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(i)).basis
		var g := sk.get_bone_global_pose(i).basis
		sk.set_bone_pose_rotation(i, (parent.inverse() * Basis(Vector3.UP, twist * SHARE[n]) * g).get_rotation_quaternion())
	# braço: o ombro → mão passa a apontar para o alvo
	var ua: int = _bones.UpperArm_R
	var upper := sk.get_bone_global_pose(ua)
	var hand := sk.get_bone_global_pose(_bones.Hand_R).origin
	var cur := (hand - upper.origin).normalized()
	var want := (t - upper.origin).normalized()
	if cur.length() < 0.5 or want.length() < 0.5:
		return
	var q := Quaternion(cur, want).slerp(Quaternion.IDENTITY, 1.0 - amount) if cur.dot(want) > -0.99 else Quaternion.IDENTITY
	var parent_b := sk.get_bone_global_pose(sk.get_bone_parent(ua)).basis
	sk.set_bone_pose_rotation(ua, (parent_b.inverse() * Basis(q) * upper.basis).get_rotation_quaternion())
