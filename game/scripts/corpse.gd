class_name Corpse
extends Node3D
## Guerrilheiro morto por raptor no meio do pátio da mata (Yard.CORPSE): deitado de costas, rasgado de garra, numa poça
## de sangue, com a mão direita estendida segurando a chave do container da M79 (`hold_key`: o KeyItem fica preso na
## mão, sem brilhar até os raptors da emboscada morrerem). É o `HeroineModel` do guerrilheiro com a árvore de animação
## desligada e a pose (POSE, mesma convenção de art/heroine_anims.py: graus XYZ sobre o repouso do osso) posta direto
## no esqueleto. Ela chegando perto (NOTICE_RANGE, com linha livre até ele) emite `noticed` uma vez: o main toca a cena
## da emboscada (Cutscene.play_ambush). Reinício (`reset`): sangue e chave de volta, e a cena volta a valer.

signal noticed

const NOTICE_RANGE := 5.5
const LIFT := 0.13  # as costas encostam no chão (o modelo deitado gira em volta dos pés)
## de costas, cabeça virada para a mão da chave, joelho esquerdo dobrado e caído para fora, braços abertos no chão
## (deitado, X > 0 = para o céu; Z < 0 abre o braço/a perna para o lado)
const POSE := {
	"Head": [0, -38, 8], "Neck": [-6, -10, 0],
	"Chest": [-4, 0, -4], "Spine": [-3, 0, 0],
	"UpperArm_R": [6, 0, -72], "LowerArm_R": [12, 0, 0], "Hand_R": [-10, 0, 0],
	"UpperArm_L": [-4, 0, -30], "LowerArm_L": [10, 0, 0], "Hand_L": [10, 0, 0],
	"UpperLeg_L": [30, 0, -26], "LowerLeg_L": [-58, 0, 0], "Foot_L": [20, 0, 0],
	"UpperLeg_R": [4, 0, -8], "LowerLeg_R": [-6, 0, 0], "Foot_R": [-30, 0, -10],
}
## onde a chave fica na mão direita (em relação ao osso Hand_R, ângulos em radianos): dentes dentro do punho, argola e
## etiqueta para fora dele
const KEY_ROT := Vector3.ZERO
const KEY_POS := Vector3(-0.03, 0.07, 0.0)

var model: HeroineModel
var target: Player
var key: KeyItem
var armed := true  # ainda não foi notado (a cena não tocou)


func _ready() -> void:
	add_to_group("corpses")
	model = HeroineModel.new()
	model.scene = Soldier.BODY
	model.atlas = Soldier.ATLAS
	model.rotation.x = PI * 0.5  # deitado de costas: a frente (-Z) para cima, a cabeça para +Z
	model.position.y = LIFT
	add_child(model)
	model.holster(true)
	model.tree.active = false
	model.head_look.influence = 0.0
	model.aim_pitch.influence = 0.0
	_pose()
	_bleed.call_deferred()


func _pose() -> void:
	var sk := model.skeleton
	sk.reset_bone_poses()
	for bone: String in POSE:
		var i := sk.find_bone(bone)
		if i < 0:
			continue
		var e: Vector3 = Vector3(POSE[bone][0], POSE[bone][1], POSE[bone][2]) * (PI / 180.0)
		sk.set_bone_pose_rotation(i, sk.get_bone_rest(i).basis.get_rotation_quaternion() * Quaternion.from_euler(e))


## Ponto (no mundo) do osso `bone`, na pose deitada.
func bone_point(bone: String) -> Vector3:
	var sk := model.skeleton
	return sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone)).origin


## Onde a chave fica (mão direita, ver KEY_IN_HAND).
func key_transform() -> Transform3D:
	var sk := model.skeleton
	var hand := sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Hand_R"))
	return Transform3D(hand.basis.orthonormalized(), hand.origin) * Transform3D(Basis.from_euler(KEY_ROT), KEY_POS)


## Ponto onde ela para para olhar a mão (além da mão da chave, um pouco para o lado da cabeça dele: o close da mão
## é do lado dos pés e a pega agachada no fundo).
func stand_point() -> Vector3:
	var hand := bone_point("Hand_R")
	var out := Vector3(hand.x - global_position.x, 0.0, hand.z - global_position.z).normalized()
	return Vector3(hand.x, global_position.y, hand.z) + out * 0.8 + global_basis.z * 0.35


func hold_key(k: KeyItem) -> void:
	key = k
	k.hold(key_transform())


## Sangue embaixo do corpo e as marcas da luta em volta (o Blood.clear do reinício apaga: `reset` pinta de novo).
func _bleed() -> void:
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var spots := [
		[bone_point("Chest") - global_basis.x * 0.35, 1.3, Blood.POOL], [bone_point("Hips"), 0.8, Blood.POOL],
		[bone_point("Head") + global_basis.x * 0.5, 0.9, Blood.SPLAT],
		[global_position + global_basis.x * 1.4 + global_basis.z * 0.8, 1.0, Blood.SPLAT],
		[global_position - global_basis.x * 1.2 + global_basis.z * 1.6, 0.8, Blood.SPLAT],
		[global_position + global_basis.z * -0.9 + global_basis.x * 0.3, 0.6, Blood.DROPS],
		[global_position + global_basis.z * -2.0 - global_basis.x * 0.6, 0.5, Blood.DROPS],
	]
	for s in spots:
		var from: Vector3 = s[0] + Vector3.UP * 0.5
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0, 1))
		if not hit.is_empty():
			Blood.splat(hit.collider, hit.position, hit.normal, s[1], s[2])


## Ela chegou perto e o vê (main chama a cada quadro enquanto `armed`).
func check_notice() -> bool:
	if not armed or not is_instance_valid(target) or target.dead or target.cutscene or target.grabbed or target.moves.busy():
		return false
	if not target.is_on_floor() or target.model.is_ragdoll():
		return false
	var to := target.global_position - global_position
	if Vector2(to.x, to.z).length() > NOTICE_RANGE or absf(to.y) > 1.5:
		return false
	var eye := target.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(eye, bone_point("Chest") + Vector3.UP * 0.2, 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return false
	armed = false
	noticed.emit()
	return true


func reset() -> void:
	armed = true
	if key:
		key.reset()
		hold_key(key)
	_bleed.call_deferred()
