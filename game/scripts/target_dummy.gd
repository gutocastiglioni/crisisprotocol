class_name TargetDummy
extends StaticBody3D
## Alvo de treino: o mesmo modelo, acinzentado. Leva 3 tiros (ou 1 na cabeça) e cai como ragdoll na direção do tiro.
## Pode esconder um item (`loot`, uma KeyItem): ao morrer, ele cai no chão onde o alvo estava.

signal killed

@export var pose := "idle"  # "idle" ou "aim"
@export var max_health := 100

var model: HeroineModel
var health := 100
var dead := false
var head_mult := 4.0
var loot: KeyItem
var _shape: CollisionShape3D
var _spawn: Transform3D


func _ready() -> void:
	add_to_group("dummies")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.72
	_shape.shape = cap
	_shape.position.y = 0.86
	add_child(_shape)
	model = HeroineModel.new()
	model.tint = Color(0.62, 0.7, 0.85)
	model.desaturate = 0.85
	add_child(model)
	_spawn = global_transform
	health = max_health
	_apply_pose.call_deferred()


func _apply_pose() -> void:
	model.set_aim(pose == "aim")


func take_hit(amount: int, dir: Vector3, at: Vector3) -> void:
	if dead:
		return
	health -= amount
	if health > 0:
		model.hit()
		return
	dead = true
	_shape.set_deferred("disabled", true)
	model.start_ragdoll(dir.normalized() * 14.0 + Vector3.UP * 2.5, at)
	if loot:
		loot.drop(global_position + Vector3.UP * 1.1)
	killed.emit()


func take_headshot(amount: int, dir: Vector3, at: Vector3) -> void:
	take_hit(amount, dir, at)


func stealth_lock(_on: bool) -> void:
	pass


func can_crit_strike(_p: Player) -> bool:
	return false


## Abate furtivo disponível nos bonecos de treino: vivo, a até Enemy.ASSASSINATE_RANGE e sem parede no meio.
func can_assassinate(p: Player) -> bool:
	if dead or not is_instance_valid(p) or p.dead:
		return false
	var to := Enemy._flat(p.global_position - global_position)
	var d := to.length()
	if d > Enemy.ASSASSINATE_RANGE or d < 0.05:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, p.global_position + Vector3.UP * 1.2, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Recebe o abate furtivo letal: cai imediatamente como ragdoll na direção do golpe (e solta a chave se tiver).
func assassinate(dir := Vector3.ZERO, at: Variant = null) -> void:
	if dead:
		return
	var hit: Vector3 = at if at is Vector3 else global_position + Vector3.UP * 1.2
	var d := dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	Sfx.play(model, "impact_flesh", hit)
	take_hit(max_health, d, hit)


func reset() -> void:
	model.stop_ragdoll()
	global_transform = _spawn
	reset_physics_interpolation()
	health = max_health
	dead = false
	_shape.set_deferred("disabled", false)
	_apply_pose()
