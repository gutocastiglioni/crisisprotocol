class_name RaptorModel
extends Node3D
## Modelo do velociraptor: materiais PS1, animações tocadas direto no AnimationPlayer (com mistura curta)
## e ragdoll para a morte (corpo, pescoço, cauda e pernas; braços e mandíbula seguem o osso pai).

const SCENE := preload("res://assets/characters/raptor.glb")
# o atlas direto (não a cópia dentro do .glb): 512 com mipmaps para o visual PS2
const ATLAS := preload("res://assets/characters/raptor_atlas.png")
const LOOPS := ["Idle", "Walk", "Run", "Study", "Shake"]
# mesmo formato de Ragdoll.BONES; pernas com cone (joelho e tornozelo dobram em sentidos opostos)
const RAGDOLL := {
	"Hips": {"child": "Spine", "len": 0.25, "box": Vector3(0.32, 0.36, 0.30), "joint": "none", "mass": 20.0},
	"Spine": {"child": "Chest", "len": 0.25, "box": Vector3(0.30, 0.40, 0.26), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 15.0},
	"Chest": {"child": "Neck1", "len": 0.22, "box": Vector3(0.24, 0.30, 0.22), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 10.0},
	"Neck1": {"child": "Neck2", "len": 0.20, "radius": 0.07, "joint": "cone", "swing": 35.0, "twist": 15.0, "mass": 3.0},
	"Neck2": {"child": "Head", "len": 0.19, "radius": 0.065, "joint": "cone", "swing": 35.0, "twist": 15.0, "mass": 3.0},
	"Head": {"child": "", "len": 0.46, "radius": 0.075, "joint": "cone", "swing": 30.0, "twist": 20.0, "mass": 4.0},
	"Tail1": {"child": "Tail2", "len": 0.40, "radius": 0.09, "joint": "cone", "swing": 25.0, "twist": 10.0, "mass": 4.0},
	"Tail2": {"child": "Tail3", "len": 0.40, "radius": 0.065, "joint": "cone", "swing": 30.0, "twist": 10.0, "mass": 3.0},
	"Tail3": {"child": "Tail4", "len": 0.40, "radius": 0.045, "joint": "cone", "swing": 30.0, "twist": 10.0, "mass": 2.0},
	"Tail4": {"child": "", "len": 0.55, "radius": 0.03, "joint": "cone", "swing": 30.0, "twist": 10.0, "mass": 1.0},
	"Thigh_L": {"child": "Shin_L", "len": 0.40, "radius": 0.10, "joint": "cone", "swing": 50.0, "twist": 15.0, "mass": 8.0},
	"Thigh_R": {"child": "Shin_R", "len": 0.40, "radius": 0.10, "joint": "cone", "swing": 50.0, "twist": 15.0, "mass": 8.0},
	"Shin_L": {"child": "Meta_L", "len": 0.48, "radius": 0.045, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 3.0},
	"Shin_R": {"child": "Meta_R", "len": 0.48, "radius": 0.045, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 3.0},
	"Meta_L": {"child": "Toe_L", "len": 0.17, "radius": 0.035, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 1.5},
	"Meta_R": {"child": "Toe_R", "len": 0.17, "radius": 0.035, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 1.5},
}

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var mouth: Node3D
var ragdoll: Ragdoll
var current := ""


func _ready() -> void:
	var inst := SCENE.instantiate()
	inst.rotation.y = PI  # o glTF olha para +Z; no Godot a frente é -Z
	add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	anim_player = inst.find_children("*", "AnimationPlayer", true, false)[0]
	mouth = inst.find_child("Mouth", true, false)
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var m := ShaderMaterial.new()
			var two_sided := src != null and src.cull_mode == BaseMaterial3D.CULL_DISABLED
			m.shader = Gfx.shader(two_sided)
			m.set_shader_parameter("rim", 0.35)
			m.set_shader_parameter("albedo_tex", ATLAS)
			mi.set_surface_override_material(i, m)
	for a in LOOPS:
		anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle", 0.0)
	ragdoll = Ragdoll.create(skeleton, RAGDOLL)
	ragdoll.hit_owner = get_parent()


## Toca `anim` misturando a partir da pose atual. Sem `restart`, pedir a mesma animação só ajusta a velocidade.
func play(anim: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	if anim == current and not restart:
		anim_player.speed_scale = speed
		return
	current = anim
	anim_player.speed_scale = speed
	if restart and anim_player.current_animation == anim:
		anim_player.seek(0.0, true)
		return
	anim_player.play(anim, blend)


## Liga o ragdoll com o corpo todo a `vel` (embalo) e um golpe `impulse` na parte mais perto de `at`.
func start_ragdoll(vel: Vector3, impulse := Vector3.ZERO, at: Variant = null) -> void:
	anim_player.active = false
	await ragdoll.fling(vel)
	if impulse != Vector3.ZERO:
		var hit: PhysicalBone3D = ragdoll.closest(at) if at is Vector3 else ragdoll.bodies["Chest"]
		hit.apply_central_impulse(impulse)


func stop_ragdoll() -> void:
	ragdoll.stop()
	anim_player.active = true
	current = ""
	play("Idle", 0.0)


func is_ragdoll() -> bool:
	return ragdoll.is_simulating_physics()


func length_of(anim: String) -> float:
	return anim_player.get_animation(anim).length


## Pontas das garras dos pés (dedo do pé + o comprimento dele), em coordenadas do mundo.
func claw_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for s in ["L", "R"]:
		var pose := skeleton.get_bone_global_pose(skeleton.find_bone("Toe_" + s))
		out.append(skeleton.global_transform * (pose.origin + pose.basis.y * 0.2))
	return out


func mouth_position() -> Vector3:
	return mouth.global_position if mouth else global_position + Vector3.UP * 1.3 - global_basis.z * 1.2


## Abertura da mandíbula em graus (0 = fechada como na pose de descanso).
func jaw_angle() -> float:
	var j := skeleton.find_bone("Jaw")
	var rest := skeleton.get_bone_rest(j).basis.get_rotation_quaternion()
	var pose := skeleton.get_bone_pose_rotation(j)
	return rad_to_deg((rest.inverse() * pose).get_angle())
