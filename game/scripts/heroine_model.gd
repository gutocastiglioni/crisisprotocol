class_name HeroineModel
extends Node3D
## Modelo da heroína: materiais PS1, árvore de animação (corpo + mira/tiro na parte de cima) e ragdoll.

const SCENE := preload("res://assets/characters/heroine.glb")
# o atlas direto (não a cópia dentro do .glb): tem o alfa das pontas do cabelo e mipmaps para o visual PS2
const ATLAS := preload("res://assets/characters/heroine_atlas.png")

const LOOPS := ["Idle", "Walk", "Run", "AimIdle", "Crouch", "StrafeL", "StrafeR"]
const UPPER_BODY := [
	"Spine", "Chest", "Neck", "Head",
	"UpperArm_L", "LowerArm_L", "Hand_L", "UpperArm_R", "LowerArm_R", "Hand_R",
]
const STATES := {
	"idle": "Idle", "walk": "Walk", "run": "Run", "crouch": "Crouch", "roll": "Roll",
	"strafe_l": "StrafeL", "strafe_r": "StrafeR", "death": "Death",
}

@export var tint := Color.WHITE
@export var desaturate := 0.0

var skeleton: Skeleton3D
var anim_player: AnimationPlayer
var tree: AnimationTree
var muzzle: Node3D
var ragdoll: Ragdoll
var state := "idle"
var _aim := 0.0
var _aim_target := 0.0


func _ready() -> void:
	var inst := SCENE.instantiate()
	inst.rotation.y = PI  # o glTF olha para +Z; no Godot a frente é -Z
	add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	anim_player = inst.find_children("*", "AnimationPlayer", true, false)[0]
	muzzle = inst.find_child("Muzzle", true, false)
	_apply_materials(inst)
	for a in LOOPS:
		anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_build_tree()
	ragdoll = Ragdoll.create(skeleton)
	ragdoll.hit_owner = get_parent()


func _apply_materials(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var m := ShaderMaterial.new()
			var two_sided := src != null and src.cull_mode == BaseMaterial3D.CULL_DISABLED
			m.shader = Gfx.shader(two_sided)
			m.set_shader_parameter("rim", 0.35)
			m.set_shader_parameter("albedo_tex", ATLAS)
			m.set_shader_parameter("tint", tint)
			m.set_shader_parameter("desaturate", desaturate)
			mi.set_surface_override_material(i, m)


func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	anim_player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(anim_player)
	var bt := AnimationNodeBlendTree.new()

	var base := AnimationNodeTransition.new()
	base.xfade_time = 0.15
	for s in STATES:
		base.add_input(s)
		bt.add_node("a_" + s, _anim(STATES[s]))
	bt.add_node("base", base)
	bt.add_node("walk_speed", AnimationNodeTimeScale.new())
	bt.connect_node("walk_speed", 0, "a_walk")
	var i := 0
	for s in STATES:
		bt.connect_node("base", i, "walk_speed" if s == "walk" else "a_" + s)
		# rolar/morrer sempre começam do quadro 0
		base.set_input_reset(i, true)
		i += 1

	var aim := AnimationNodeBlend2.new()
	var shoot := AnimationNodeOneShot.new()
	shoot.fadein_time = 0.02
	shoot.fadeout_time = 0.08
	var hit := AnimationNodeOneShot.new()
	hit.fadein_time = 0.05
	hit.fadeout_time = 0.15
	_filter_upper_body(aim)
	_filter_upper_body(shoot)
	bt.add_node("a_aim", _anim("AimIdle"))
	bt.add_node("a_shoot", _anim("Shoot"))
	bt.add_node("a_hit", _anim("Hit"))
	bt.add_node("aim", aim)
	bt.add_node("shoot", shoot)
	bt.add_node("hit", hit)
	bt.connect_node("aim", 0, "base")
	bt.connect_node("aim", 1, "a_aim")
	bt.connect_node("shoot", 0, "aim")
	bt.connect_node("shoot", 1, "a_shoot")
	bt.connect_node("hit", 0, "shoot")
	bt.connect_node("hit", 1, "a_hit")
	bt.connect_node("output", 0, "hit")
	tree.tree_root = bt
	tree.active = true
	state = ""
	set_state("idle")


func _anim(name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = name
	return n


func _filter_upper_body(node: AnimationNode) -> void:
	node.filter_enabled = true
	var a := anim_player.get_animation("Idle")
	for t in a.get_track_count():
		var path := a.track_get_path(t)
		if path.get_concatenated_subnames() in UPPER_BODY:
			node.set_filter_path(path, true)


func _process(delta: float) -> void:
	if tree == null or not tree.active:
		return
	_aim = move_toward(_aim, _aim_target, delta * 8.0)
	tree.set("parameters/aim/blend_amount", _aim)


func set_state(s: String, walk_scale := 1.0) -> void:
	tree.set("parameters/walk_speed/scale", walk_scale)
	if s == state:
		return
	state = s
	tree.set("parameters/base/transition_request", s)


func set_aim(on: bool) -> void:
	_aim_target = 1.0 if on else 0.0


func is_aimed() -> bool:
	return _aim > 0.9


func shoot() -> void:
	tree.set("parameters/shoot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func hit() -> void:
	tree.set("parameters/hit/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func muzzle_position() -> Vector3:
	return muzzle.global_position if muzzle else global_position + Vector3.UP * 1.3


func start_ragdoll(impulse: Vector3, at: Variant = null) -> void:
	tree.active = false
	ragdoll.start(impulse, at)


## Ragdoll com o corpo todo voando a `vel` (arremessada por um golpe).
func fling_ragdoll(vel: Vector3, at: Variant = null) -> void:
	tree.active = false
	await ragdoll.fling(vel, at)


func stop_ragdoll() -> void:
	ragdoll.stop()
	tree.active = true
	state = ""
	set_state("idle")
	set_aim(false)
	_aim = 0.0


func is_ragdoll() -> bool:
	return ragdoll.is_simulating_physics()
