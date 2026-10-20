class_name CameraRig
extends Node3D
## Câmera em 3ª pessoa. Perfil "arcade" (GameMode): atrás e acima dela; mirando, chega por cima do ombro direito; parado o
## controle, volta devagar para trás dela (jeito Syphon Filter). Perfil "survival": sempre por cima do ombro direito (jeito RE4
## Remake), mais perto, sem voltar sozinha; mirando, chega mais perto e a mira fica lenta; o tiro dá coice (`kick`).
## Mouse/analógico giram.

const HEIGHT := 1.45
const MOUSE_SENS := 0.0035
const PAD_SENS := 2.6
const FOLLOW_DELAY := 1.5
## por cima do ombro (survival): distância atrás dela, desvio para a direita e campo de visão, andando e mirando
const SHOULDER := {"length": 2.3, "length_aim": 1.3, "side": 0.5, "side_aim": 0.7, "fov": 60.0, "fov_aim": 46.0}
const PORTRAIT_SIDE := 0.5  # tela em pé: fração do desvio do ombro
const PORTRAIT_FOV := 62.0  # tela em pé: campo de visão mínimo (o da largura)
const SHOULDER_AIM_SENS := 0.6  # mirando, o mouse/analógico giram a esta fração
const RECOIL_RECOVER := 0.4  # radianos por segundo: o quanto do coice a câmera desfaz
const RECOIL_KEEP := 0.4  # fração de cada coice que fica (tiros seguidos sobem a mira)

var target: Node3D
var yaw := 0.0
var pitch := -0.22
var spring: SpringArm3D
var camera: Camera3D
var _idle_look := 0.0
var _snapped := false
var _shake := 0.0
var _shake_t := 0.0
var _recoil := 0.0  # coice ainda por desfazer (radianos)


func _ready() -> void:
	top_level = true
	# movida a cada quadro da tela, não no passo da física (que é interpolado)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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
	if GameMode.shoulder_cam() and target and target.get("aiming"):
		d *= SHOULDER_AIM_SENS
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
	var shoulder := GameMode.shoulder_cam()
	if not shoulder and not aiming and moving and _idle_look > FOLLOW_DELAY:
		yaw = lerp_angle(yaw, target.global_rotation.y, 1.0 - exp(-1.2 * delta))
	if _recoil > 0.0:
		var back := minf(_recoil, RECOIL_RECOVER * delta)
		pitch -= back
		_recoil -= back
	var focus: Vector3 = target.call("camera_focus") if target.has_method("camera_focus") else target.global_position
	var goal := focus + Vector3.UP * HEIGHT
	if target.get("crouching"):
		goal.y -= 0.45
	global_position = goal if not _snapped else global_position.lerp(goal, 1.0 - exp(-14.0 * delta))
	_snapped = true
	rotation = Vector3(pitch, yaw, 0.0)
	var k := 1.0 - exp(-10.0 * delta)
	if shoulder:
		# tela em pé: o campo de visão é o da largura, então o desvio do ombro encolhe e o campo abre (senão ela sai do quadro)
		var portrait := vp.y > vp.x
		var side: float = (SHOULDER.side_aim if aiming else SHOULDER.side) * (PORTRAIT_SIDE if portrait else 1.0)
		var fov: float = SHOULDER.fov_aim if aiming else SHOULDER.fov
		spring.spring_length = lerpf(spring.spring_length, SHOULDER.length_aim if aiming else SHOULDER.length, k)
		spring.position.x = lerpf(spring.position.x, side, k)
		camera.fov = lerpf(camera.fov, maxf(fov, PORTRAIT_FOV) if portrait else fov, k)
	else:
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


## Coice do tiro: a mira sobe `up` radianos e a câmera desfaz a maior parte (tiros seguidos sobem a mira). Só no survival.
func kick(up: float) -> void:
	if up <= 0.0 or not GameMode.shoulder_cam():
		return
	pitch = clampf(pitch + up, -1.1, 0.55)
	_recoil += up * (1.0 - RECOIL_KEEP)


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


## Ponto sob a retícula: o que o raio da câmera acerta (cenário e personagens), ou 30 m à frente.
## Acertos a menos de 2 m da câmera (o ombro dela, uma quina) não contam: a arma viraria de repente.
func aim_point(exclude: Array[RID]) -> Vector3:
	var ray := aim_ray()
	var q := PhysicsRayQueryParameters3D.create(ray[0] + ray[1] * 2.0, ray[0] + ray[1] * 30.0, 1 | 2, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else ray[0] + ray[1] * 30.0
