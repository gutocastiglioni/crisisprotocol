class_name CameraRig
extends Node3D
## Câmera em 3ª pessoa: atrás e acima dela; mirando, chega por cima do ombro direito.
## Mouse/analógico giram; parado o controle, volta devagar para trás dela (jeito Syphon Filter).

const HEIGHT := 1.45
const MOUSE_SENS := 0.0035
const PAD_SENS := 2.6
const FOLLOW_DELAY := 1.5

var target: Node3D
var yaw := 0.0
var pitch := -0.22
var spring: SpringArm3D
var camera: Camera3D
var _idle_look := 0.0
var _snapped := false
var _shake := 0.0
var _shake_t := 0.0


func _ready() -> void:
	top_level = true
	spring = SpringArm3D.new()
	spring.spring_length = 3.0
	spring.collision_mask = 1
	spring.margin = 0.15
	var probe := SphereShape3D.new()
	probe.radius = 0.15
	spring.shape = probe
	add_child(spring)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.05
	camera.far = 80.0
	spring.add_child(camera)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * MOUSE_SENS)


func _look(d: Vector2) -> void:
	yaw -= d.x
	pitch = clampf(pitch - d.y, -1.1, 0.55)
	_idle_look = 0.0


func _process(delta: float) -> void:
	if target == null:
		return
	var pad := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if pad.length() > 0.0:
		_look(pad * PAD_SENS * delta)
	# tela em pé: mantém a largura do campo de visão para ela não sair do quadro ao mirar
	var vp := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	var aiming: bool = target.get("aiming")
	var moving: bool = target.get("velocity").length() > 0.5
	_idle_look += delta
	if not aiming and moving and _idle_look > FOLLOW_DELAY:
		yaw = lerp_angle(yaw, target.global_rotation.y, 1.0 - exp(-1.2 * delta))
	var focus: Vector3 = target.call("camera_focus") if target.has_method("camera_focus") else target.global_position
	var goal := focus + Vector3.UP * HEIGHT
	if target.get("crouching"):
		goal.y -= 0.45
	global_position = goal if not _snapped else global_position.lerp(goal, 1.0 - exp(-14.0 * delta))
	_snapped = true
	rotation = Vector3(pitch, yaw, 0.0)
	var k := 1.0 - exp(-10.0 * delta)
	spring.spring_length = lerpf(spring.spring_length, 1.6 if aiming else 3.0, k)
	spring.position.x = lerpf(spring.position.x, 0.62 if aiming else 0.0, k)
	camera.fov = lerpf(camera.fov, 50.0 if aiming else 62.0, k)
	_shake_t = maxf(0.0, _shake_t - delta)
	var amp := _shake if _shake_t > 0.0 else 0.0
	camera.h_offset = randf_range(-amp, amp)
	camera.v_offset = randf_range(-amp, amp)


## Treme a câmera por `time` segundos (golpes, mordida).
func shake(strength: float, time: float) -> void:
	_shake = maxf(strength, _shake if _shake_t > 0.0 else 0.0)
	_shake_t = maxf(_shake_t, time)


## Gira a câmera para que o centro da tela (a retícula) fique sobre `point`.
func look_at_point(point: Vector3) -> void:
	var d := point - camera.global_position
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.1, 0.55)
	_idle_look = 0.0


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func aim_ray() -> Array[Vector3]:
	return [camera.global_position, -camera.global_basis.z]
