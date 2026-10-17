class_name TargetDummy
extends StaticBody3D
## Alvo de treino: o mesmo modelo, acinzentado. Leva 3 tiros e cai como ragdoll na direção do tiro.

signal killed

@export var pose := "idle"  # "idle" ou "aim"
@export var max_health := 100

var model: HeroineModel
var health := 100
var dead := false
var _shape: CollisionShape3D
var _spawn: Transform3D


func _ready() -> void:
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
	killed.emit()


func reset() -> void:
	model.stop_ragdoll()
	global_transform = _spawn
	health = max_health
	dead = false
	_shape.set_deferred("disabled", false)
	_apply_pose()
