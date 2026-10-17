class_name Ragdoll
extends PhysicalBoneSimulator3D
## Ragdoll montado em código a partir de um esqueleto (da heroína por padrão; o raptor passa o dele).
## Corpos ficam na camada 4 e só colidem com o cenário (camada 1): sem colisão entre partes,
## os limites das juntas é que seguram a pose.

const LAYER := 1 << 3
const WORLD_MASK := 1

# len = comprimento do corpo ao longo do osso; child = osso que dá a direção
const BONES := {
	"Hips": {"child": "Spine", "len": 0.12, "box": Vector3(0.30, 0.20, 0.24), "joint": "none", "mass": 10.0},
	"Spine": {"child": "Chest", "len": 0.18, "radius": 0.10, "joint": "cone", "swing": 20.0, "twist": 15.0, "mass": 8.0},
	"Chest": {"child": "Neck", "len": 0.24, "box": Vector3(0.30, 0.20, 0.26), "joint": "cone", "swing": 20.0, "twist": 15.0, "mass": 10.0},
	"Head": {"child": "", "len": 0.20, "radius": 0.095, "joint": "cone", "swing": 35.0, "twist": 30.0, "mass": 4.0},
	"UpperArm_L": {"child": "LowerArm_L", "len": 0.25, "radius": 0.05, "joint": "cone", "swing": 70.0, "twist": 40.0, "mass": 2.0},
	"UpperArm_R": {"child": "LowerArm_R", "len": 0.25, "radius": 0.05, "joint": "cone", "swing": 70.0, "twist": 40.0, "mass": 2.0},
	"LowerArm_L": {"child": "Hand_L", "len": 0.30, "radius": 0.045, "joint": "hinge", "lower": -140.0, "upper": 5.0, "mass": 1.5},
	"LowerArm_R": {"child": "Hand_R", "len": 0.30, "radius": 0.045, "joint": "hinge", "lower": -140.0, "upper": 5.0, "mass": 1.5},
	"UpperLeg_L": {"child": "LowerLeg_L", "len": 0.40, "radius": 0.075, "joint": "cone", "swing": 55.0, "twist": 20.0, "mass": 7.0},
	"UpperLeg_R": {"child": "LowerLeg_R", "len": 0.40, "radius": 0.075, "joint": "cone", "swing": 55.0, "twist": 20.0, "mass": 7.0},
	"LowerLeg_L": {"child": "Foot_L", "len": 0.41, "radius": 0.055, "joint": "hinge", "lower": -5.0, "upper": 140.0, "mass": 4.0},
	"LowerLeg_R": {"child": "Foot_R", "len": 0.41, "radius": 0.055, "joint": "hinge", "lower": -5.0, "upper": 140.0, "mass": 4.0},
}

var skeleton: Skeleton3D
var config: Dictionary = BONES
var bodies: Dictionary = {}  # nome do osso -> PhysicalBone3D
## Quem recebe o dano quando um tiro acerta um destes corpos (com a física desligada eles seguem a animação
## e servem de hitbox por parte do corpo).
var hit_owner: Node


static func create(skel: Skeleton3D, bone_config: Dictionary = BONES) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Ragdoll"
	r.skeleton = skel
	r.config = bone_config
	skel.add_child(r)
	r._build()
	return r


func _build() -> void:
	for bone_name in config:
		var cfg: Dictionary = config[bone_name]
		var idx := skeleton.find_bone(bone_name)
		assert(idx >= 0, "osso não encontrado: %s" % bone_name)
		var dir := Vector3.UP
		if cfg.child != "":
			dir = skeleton.get_bone_rest(skeleton.find_bone(cfg.child)).origin.normalized()
		var length: float = cfg.len
		# mesmo cálculo do editor ("Create Physical Skeleton"): -Z do corpo aponta para o filho
		var up := Vector3.UP if not Vector3.UP.cross(dir).is_zero_approx() else Vector3.BACK
		var basis := Basis.looking_at(dir, up)
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name
		pb.bone_name = bone_name
		pb.body_offset = Transform3D(basis, basis * Vector3(0, 0, -length * 0.5))
		# X da junta (eixo de torção do cone) ao longo do osso; Z da junta (eixo da dobradiça) = lateral
		pb.joint_offset = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, length * 0.5))
		pb.mass = cfg.mass
		pb.friction = 0.8
		pb.bounce = 0.0
		pb.linear_damp = 0.1
		pb.angular_damp = 2.0
		pb.collision_layer = LAYER
		pb.collision_mask = WORLD_MASK
		var shape := CollisionShape3D.new()
		if cfg.has("box"):
			var box := BoxShape3D.new()
			box.size = cfg.box
			shape.shape = box
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = cfg.radius
			cap.height = maxf(length, cfg.radius * 2.0 + 0.01)
			shape.shape = cap
			shape.transform.basis = Basis(Vector3.RIGHT, -PI * 0.5)
		pb.add_child(shape)
		add_child(pb)
		_set_joint(pb, cfg)
		bodies[bone_name] = pb


func _set_joint(pb: PhysicalBone3D, cfg: Dictionary) -> void:
	match cfg.joint:
		"none":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		"cone":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", cfg.swing)
			pb.set("joint_constraints/twist_span", cfg.twist)
		"hinge":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_lower", cfg.lower)
			pb.set("joint_constraints/angular_limit_upper", cfg.upper)


## Liga a física. O impulso vai no corpo mais perto de `at` (ou no peito, se `at` for nulo).
func start(impulse: Vector3 = Vector3.ZERO, at: Variant = null) -> void:
	physical_bones_start_simulation()
	if impulse == Vector3.ZERO:
		return
	await get_tree().physics_frame
	var target: PhysicalBone3D = bodies["Chest"]
	if at is Vector3:
		target = closest(at)
	target.apply_central_impulse(impulse)


## Liga a física com o corpo todo já em movimento (arremessado por um golpe). Com `at`, a parte atingida
## sai mais rápido que as pontas (cabeça, mãos, pés), e o corpo dobra em C em volta do golpe.
func fling(vel: Vector3, at: Variant = null) -> void:
	physical_bones_start_simulation()
	await get_tree().physics_frame
	var flat := Vector3(vel.x, 0.0, vel.z)
	for b in bodies.values():
		var k := 1.0
		if at is Vector3:
			k = lerpf(1.25, 0.45, clampf(b.global_position.distance_to(at) / 0.9, 0.0, 1.0))
		var v := flat * k + Vector3.UP * vel.y
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)
		PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)


func stop() -> void:
	physical_bones_stop_simulation()


## Empurra uma parte do corpo caído. Acorda todas as partes antes: corpo parado "dorme" na física
## e ignoraria o impulso.
static func push(body: PhysicalBone3D, impulse: Vector3, at: Vector3) -> void:
	var r := body.get_parent() as Ragdoll
	if r:
		for b in r.bodies.values():
			PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)
	body.apply_impulse(impulse, at - body.global_position)


## Puxa uma parte do corpo para `goal` (ex.: o braço preso na boca do raptor); as juntas levam o resto junto.
static func drag(body: PhysicalBone3D, goal: Vector3, gain := 18.0, max_speed := 14.0, base := Vector3.ZERO) -> void:
	var r := body.get_parent() as Ragdoll
	if r:
		for b in r.bodies.values():
			PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_SLEEPING, false)
	var v := base + ((goal - body.global_position) * gain).limit_length(max_speed)
	PhysicsServer3D.body_set_state(body.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, v)


func body_rids() -> Array[RID]:
	var out: Array[RID] = []
	for b in bodies.values():
		out.append(b.get_rid())
	return out


static func owner_of(body: PhysicalBone3D) -> Node:
	var r := body.get_parent() as Ragdoll
	return r.hit_owner if r else null


func closest(point: Vector3) -> PhysicalBone3D:
	var best: PhysicalBone3D = null
	var best_d := INF
	for b in bodies.values():
		var d: float = b.global_position.distance_squared_to(point)
		if d < best_d:
			best_d = d
			best = b
	return best
