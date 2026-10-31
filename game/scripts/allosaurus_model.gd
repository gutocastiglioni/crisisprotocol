class_name AllosaurusModel
extends RaptorModel
## Modelo do alossauro: o mesmo do raptor (mesmos ossos, materiais, animações no AnimationPlayer, ragdoll na morte,
## passos pela garra do pé) com o arquivo, a textura, o ragdoll e os sons dele. Vozes do raptor bem mais graves.

const ALLO_SCENE := preload("res://assets/characters/allosaurus.glb")
const ALLO_ATLAS := preload("res://assets/characters/allosaurus_atlas.png")
## comprimentos dos ossos do art/allosaurus_spec.py; massas ~10x as do raptor
const ALLO_RAGDOLL := {
	"Hips": {"child": "Spine", "len": 0.65, "box": Vector3(1.0, 1.3, 0.7), "joint": "none", "mass": 200.0},
	"Spine": {"child": "Chest", "len": 0.56, "box": Vector3(1.05, 1.45, 0.6), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 150.0},
	"Chest": {"child": "Neck1", "len": 0.5, "box": Vector3(0.9, 1.3, 0.55), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 100.0},
	"Neck1": {"child": "Neck2", "len": 0.68, "radius": 0.32, "joint": "cone", "swing": 30.0, "twist": 15.0, "mass": 30.0},
	"Neck2": {"child": "Head", "len": 0.40, "radius": 0.3, "joint": "cone", "swing": 30.0, "twist": 15.0, "mass": 30.0},
	"Head": {"child": "", "len": 1.10, "radius": 0.3, "joint": "cone", "swing": 25.0, "twist": 20.0, "mass": 60.0},
	"Tail1": {"child": "Tail2", "len": 1.16, "radius": 0.35, "joint": "cone", "swing": 20.0, "twist": 10.0, "mass": 40.0},
	"Tail2": {"child": "Tail3", "len": 1.3, "radius": 0.26, "joint": "cone", "swing": 25.0, "twist": 10.0, "mass": 30.0},
	"Tail3": {"child": "Tail4", "len": 1.3, "radius": 0.18, "joint": "cone", "swing": 25.0, "twist": 10.0, "mass": 20.0},
	"Tail4": {"child": "", "len": 1.61, "radius": 0.09, "joint": "cone", "swing": 25.0, "twist": 10.0, "mass": 10.0},
	"Thigh_L": {"child": "Shin_L", "len": 0.82, "radius": 0.3, "joint": "cone", "swing": 45.0, "twist": 15.0, "mass": 80.0},
	"Thigh_R": {"child": "Shin_R", "len": 0.82, "radius": 0.3, "joint": "cone", "swing": 45.0, "twist": 15.0, "mass": 80.0},
	"Shin_L": {"child": "Meta_L", "len": 0.64, "radius": 0.18, "joint": "cone", "swing": 40.0, "twist": 5.0, "mass": 30.0},
	"Shin_R": {"child": "Meta_R", "len": 0.64, "radius": 0.18, "joint": "cone", "swing": 40.0, "twist": 5.0, "mass": 30.0},
	"Meta_L": {"child": "Toe_L", "len": 0.48, "radius": 0.14, "joint": "cone", "swing": 40.0, "twist": 5.0, "mass": 15.0},
	"Meta_R": {"child": "Toe_R", "len": 0.48, "radius": 0.14, "joint": "cone", "swing": 40.0, "twist": 5.0, "mass": 15.0},
}
## animação -> [som, segundos depois do começo, chance] (quadros em art/allosaurus_anims.py)
const ALLO_SOUNDS := {
	"Roar": ["raptor_roar", 0.0, 1.0],
	"Bite": ["raptor_bite", 0.5, 1.0],  # quadro 15: a boca fecha
	"Shake": ["raptor_shake", 0.0, 1.0],
	"Throw": ["tail_whoosh", 0.2, 1.0],
	"Stomp": ["body_fall", 0.62, 1.0],  # quadro 20: o pé bate no chão
	"Hit": ["raptor_hurt", 0.0, 1.0],
	"Study": ["raptor_hiss", 0.3, 0.6],
	"Run": ["raptor_snarl", 0.0, 0.6],
	"RoarAt": ["raptor_roar", 0.2, 1.0],
	"Headbutt": ["tail_whoosh", 0.28, 1.0],
	"HeadbuttR": ["tail_whoosh", 0.28, 1.0],
	"TailWhip": ["tail_whoosh", 0.4, 1.0],
	"TailWhipR": ["tail_whoosh", 0.4, 1.0],
}
## golpes que batem no corpo dela (pancada onde pegou); rugido e tremor da pisada não
const IMPACTS := ["stomp", "charge", "headbutt", "tail", "throw"]


func _init() -> void:
	scene = ALLO_SCENE
	atlas = ALLO_ATLAS
	ragdoll_bones = ALLO_RAGDOLL
	anim_sounds = ALLO_SOUNDS
	# ponta do pé apoiada a ~0,16 m; no passo ela sobe bem mais que a do raptor
	step_up = 0.32
	step_down = 0.22
	step_db = {"Walk": 4.0, "Run": 8.0}
	voice_pitch = 0.55
	chirps = false
	claw_len = 0.6


func _on_attacked(kind: String) -> void:
	if kind in IMPACTS:
		Sfx.play(self, "claw_hit", get_parent().get("last_hit_at"))


## Ponto no osso `bone` (a base dele, ou `along` metros ao longo dele), no mundo: cabeça e cauda nos golpes.
func bone_point(bone: String, along := 0.0) -> Vector3:
	var pose := skeleton.get_bone_global_pose(skeleton.find_bone(bone))
	return skeleton.global_transform * (pose.origin + pose.basis.y * along)
