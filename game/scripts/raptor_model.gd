class_name RaptorModel
extends Node3D
## Modelo do velociraptor: materiais PS1, animações tocadas direto no AnimationPlayer (com mistura curta)
## e ragdoll para a morte (corpo, pescoço, cauda e pernas; braços, dedos, mandíbula e a ponta da cauda seguem o osso pai).
## O raptor vem do modelo de referência (art/build_raptor.py, CC BY): pele no atlas (cores do jogo) e olhos, dentes e
## garras na textura de peças (material "RaptorParts").
## Os sons acompanham as animações (Sfx): cada uma que começa toca a voz ou o golpe dela (ANIM_SOUNDS, no quadro
## certo), os passos tocam quando a garra do pé desce até o chão, andando ele dá uns piados de vez em quando, e a
## morte grita e cai. Golpe que acertou (sinal `attacked` do Raptor): pancada de garra onde pegou.

const SCENE := preload("res://assets/characters/raptor.glb")
# o atlas direto (não a cópia dentro do .glb): 512 com mipmaps para o visual PS2
const ATLAS := preload("res://assets/characters/raptor_atlas.png")
const PARTS := preload("res://assets/characters/raptor_parts.png")  # olhos, dentes e garras (textura da referência)
const LOOPS := ["Idle", "Walk", "Run", "Jog", "Stalk", "Study", "Shake"]
# mesmo formato de Ragdoll.BONES; pernas com cone (joelho e tornozelo dobram em sentidos opostos)
const RAGDOLL := {
	"Hips": {"child": "Spine", "len": 0.31, "box": Vector3(0.30, 0.34, 0.32), "joint": "none", "mass": 20.0},
	"Spine": {"child": "Chest", "len": 0.29, "box": Vector3(0.30, 0.38, 0.30), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 15.0},
	"Chest": {"child": "Neck1", "len": 0.22, "box": Vector3(0.26, 0.34, 0.24), "joint": "cone", "swing": 15.0, "twist": 10.0, "mass": 10.0},
	"Neck1": {"child": "Neck2", "len": 0.175, "radius": 0.09, "joint": "cone", "swing": 30.0, "twist": 12.0, "mass": 2.5},
	"Neck2": {"child": "Neck3", "len": 0.19, "radius": 0.085, "joint": "cone", "swing": 30.0, "twist": 12.0, "mass": 2.0},
	"Neck3": {"child": "Head", "len": 0.175, "radius": 0.08, "joint": "cone", "swing": 30.0, "twist": 12.0, "mass": 2.0},
	"Head": {"child": "", "len": 0.47, "radius": 0.08, "joint": "cone", "swing": 30.0, "twist": 20.0, "mass": 4.0},
	"Tail1": {"child": "Tail2", "len": 0.25, "radius": 0.09, "joint": "cone", "swing": 20.0, "twist": 8.0, "mass": 3.5},
	"Tail2": {"child": "Tail3", "len": 0.29, "radius": 0.075, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 3.0},
	"Tail3": {"child": "Tail4", "len": 0.27, "radius": 0.06, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 2.5},
	"Tail4": {"child": "Tail5", "len": 0.19, "radius": 0.05, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 1.5},
	"Tail5": {"child": "Tail6", "len": 0.17, "radius": 0.042, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 1.0},
	"Tail6": {"child": "Tail7", "len": 0.155, "radius": 0.036, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 0.8},
	"Tail7": {"child": "Tail8", "len": 0.135, "radius": 0.03, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 0.6},
	"Tail8": {"child": "Tail9", "len": 0.115, "radius": 0.025, "joint": "cone", "swing": 22.0, "twist": 8.0, "mass": 0.4},
	"Thigh_L": {"child": "Shin_L", "len": 0.37, "radius": 0.11, "joint": "cone", "swing": 50.0, "twist": 15.0, "mass": 8.0},
	"Thigh_R": {"child": "Shin_R", "len": 0.37, "radius": 0.11, "joint": "cone", "swing": 50.0, "twist": 15.0, "mass": 8.0},
	"Shin_L": {"child": "Meta_L", "len": 0.32, "radius": 0.06, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 3.0},
	"Shin_R": {"child": "Meta_R", "len": 0.32, "radius": 0.06, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 3.0},
	"Meta_L": {"child": "Toe_L", "len": 0.275, "radius": 0.04, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 1.5},
	"Meta_R": {"child": "Toe_R", "len": 0.275, "radius": 0.04, "joint": "cone", "swing": 45.0, "twist": 5.0, "mass": 1.5},
}

## animação -> [som, segundos depois do começo (na velocidade 1), chance]
const ANIM_SOUNDS := {
	"Roar": ["raptor_roar", 0.0, 1.0],
	"LeapPrep": ["raptor_screech", 0.0, 1.0],
	"Bite": ["raptor_bite", 0.47, 1.0],  # a boca fecha (Raptor.BITE_SNAP)
	"Shake": ["raptor_shake", 0.0, 1.0],
	"TailWhip": ["tail_whoosh", 0.28, 1.0],  # a cauda passa no quadro 12 (Raptor.TAIL_HIT)
	"TailWhipR": ["tail_whoosh", 0.28, 1.0],
	"Hit": ["raptor_hurt", 0.0, 1.0],
	"Study": ["raptor_hiss", 0.2, 0.5],
	"Run": ["raptor_snarl", 0.0, 0.5],
}
## passo: a bola do pé (início do osso Toe_*) subiu acima de STEP_UP e voltou abaixo de STEP_DOWN (m); apoiada fica em ~0,1
const STEP_UP := 0.14
const STEP_DOWN := 0.115
const STEP_DB := {"Walk": -4.0, "Run": 2.0, "Stalk": -9.0}
const CHIRP_GAP := Vector2(6.0, 14.0)  # segundos entre um piado e outro, andando ou parado

## O alossauro (AllosaurusModel) troca estes valores no _init; o padrão é o raptor.
var scene: PackedScene = SCENE
var atlas: Texture2D = ATLAS
var parts: Texture2D = PARTS  # superfícies do material "RaptorParts" (o alossauro não tem)
var loops: Array = LOOPS
var ragdoll_bones: Dictionary = RAGDOLL
var anim_sounds: Dictionary = ANIM_SOUNDS
var step_up := STEP_UP
var step_down := STEP_DOWN
var step_db: Dictionary = STEP_DB
var voice_pitch := 1.0  # vozes e passos (bicho maior = mais grave)
var chirps := true  # piados de vez em quando, andando ou parado
var claw_len := 0.28  # da bola do pé até a ponta da garra do dedo do meio (osso Toe_*)
var showroom := false  # no palco do Showroom: pés presos e inércia ligados sem corpo de física (sempre no chão)

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var mouth: Node3D
var ragdoll: Ragdoll
var sway: TurnSway  # cabeça guia a curva, cauda com mola, corpo inclina (antes dos pés presos)
var flinch: HitFlinch  # tranco do tiro no tronco, pescoço e cabeça (antes dos pés presos)
var feet: FootPlant  # pés presos no chão ao girar/andar (só com dono que anda: o clone do tubo não)
var current := ""
var _toe_bones: Array[int] = []
var _toe_up := [false, false]
var _chirp_t := 0.0


func _ready() -> void:
	var inst := scene.instantiate()
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
			var is_parts := src != null and src.resource_name == "RaptorParts"
			m.set_shader_parameter("albedo_tex", parts if is_parts else atlas)
			mi.set_surface_override_material(i, m)
	for a in loops:
		if anim_player.has_animation(a):  # o alossauro não tem a espreita
			anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("Idle", 0.0)
	var walks := _walks()
	sway = TurnSway.new()
	sway.name = "TurnSway"
	sway.active = walks
	skeleton.add_child(sway)
	flinch = HitFlinch.new()
	flinch.name = "HitFlinch"
	skeleton.add_child(flinch)
	feet = FootPlant.new()
	feet.name = "FootPlant"
	feet.active = walks
	skeleton.add_child(feet)  # antes do ragdoll: a física, quando liga, manda na pose
	feet.stepped.connect(func(at: Vector3) -> void: Sfx.play(self, "raptor_step", at, step_db.get("Walk", 0.0) - 4.0, voice_pitch))
	ragdoll = Ragdoll.create(skeleton, ragdoll_bones)
	ragdoll.hit_owner = get_parent()
	_toe_bones = [skeleton.find_bone("Toe_L"), skeleton.find_bone("Toe_R")]
	_chirp_t = randf_range(CHIRP_GAP.x, CHIRP_GAP.y)
	if get_parent().has_signal("attacked"):
		get_parent().attacked.connect(_on_attacked)


## Só quem anda pelo chão usa pés presos e inércia (o clone do tubo, preso no lugar, não).
func _walks() -> bool:
	return showroom or get_parent() is CharacterBody3D


func _process(delta: float) -> void:
	if not anim_player.active:
		return
	var body := get_parent() as CharacterBody3D
	if body:
		feet.grounded = body.is_on_floor() and body.get("airborne") != true  # pulinho do alossauro: pés soltos
	if step_db.has(current):
		for i in 2:
			var toe := skeleton.global_transform * skeleton.get_bone_global_pose(_toe_bones[i]).origin
			var h := toe.y - global_position.y
			if h > step_up:
				_toe_up[i] = true
			elif h < step_down and _toe_up[i]:
				_toe_up[i] = false
				Sfx.play(self, "raptor_step", toe, step_db[current], voice_pitch)
	else:
		_toe_up = [false, false]
	if chirps and current in ["Walk", "Idle"]:
		_chirp_t -= delta
		if _chirp_t <= 0.0:
			_chirp_t = randf_range(CHIRP_GAP.x, CHIRP_GAP.y)
			Sfx.play(self, "raptor_chirp", mouth_position())


## Golpe que acertou a presa: pancada de garra/cabeça onde pegou (a mordida tem o som da sacudida).
func _on_attacked(kind: String) -> void:
	if kind != "bite":
		Sfx.play(self, "claw_hit", get_parent().get("last_hit_at"))


## Toca `anim` misturando a partir da pose atual. Sem `restart`, pedir a mesma animação só ajusta a velocidade.
func play(anim: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	if anim == current and not restart:
		anim_player.speed_scale = speed
		return
	if anim_sounds.has(anim):
		var snd: Array = anim_sounds[anim]
		if randf() < float(snd[2]):
			Sfx.play(self, snd[0], mouth_position(), 0.0, voice_pitch, float(snd[1]) / maxf(speed, 0.1))
	current = anim
	anim_player.speed_scale = speed
	if restart and anim_player.current_animation == anim:
		anim_player.seek(0.0, true)
		return
	anim_player.play(anim, blend)


## Liga o ragdoll com o corpo todo a `vel` (embalo) e um golpe `impulse` na parte mais perto de `at`.
func start_ragdoll(vel: Vector3, impulse := Vector3.ZERO, at: Variant = null) -> void:
	Sfx.play(self, "raptor_death", mouth_position(), 0.0, voice_pitch)
	Sfx.play(self, "body_fall", null, 3.0, 0.7, 0.55)  # corpo pesado: mais grave
	anim_player.active = false
	feet.active = false
	feet.reset()
	sway.active = false
	sway.reset()
	flinch.active = false
	flinch.reset()
	await ragdoll.fling(vel)
	if impulse != Vector3.ZERO:
		var hit: PhysicalBone3D = ragdoll.closest(at) if at is Vector3 else ragdoll.bodies["Chest"]
		hit.apply_central_impulse(impulse)


func stop_ragdoll() -> void:
	ragdoll.stop()
	anim_player.active = true
	feet.reset()
	feet.active = _walks()
	sway.reset()
	sway.active = feet.active
	flinch.reset()
	flinch.active = true
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
		out.append(skeleton.global_transform * (pose.origin + pose.basis.y * claw_len))
	return out


func mouth_position() -> Vector3:
	return mouth.global_position if mouth else global_position + Vector3.UP * 1.3 - global_basis.z * 1.2


## Abertura da mandíbula em graus (0 = fechada como na pose de descanso).
func jaw_angle() -> float:
	var j := skeleton.find_bone("Jaw")
	var rest := skeleton.get_bone_rest(j).basis.get_rotation_quaternion()
	var pose := skeleton.get_bone_pose_rotation(j)
	return rad_to_deg((rest.inverse() * pose).get_angle())
