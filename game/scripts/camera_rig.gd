class_name CameraRig
extends Node3D
## Câmera em 3ª pessoa. Perfil "arcade" (GameMode): atrás e acima dela; mirando, chega por cima do ombro direito; parado o
## controle, volta devagar para trás dela (jeito Syphon Filter). Perfil "survival": por cima do ombro direito (jeito RE4
## Remake: ela no terço esquerdo da tela, enquadrada da coxa para cima, câmera na altura da cabeça), sem voltar sozinha;
## andando não troca de ombro; sem mirar, só passa para o ombro esquerdo quando o direito fica cego (`SIDE_*`: parede/caixa
## fechando um lado da frente do corpo dela, o ombro vai para o lado aberto) e volta para a direita quando acaba; girando a
## câmera para o lado dela na tela, uma mola a puxa quase para o centro e abre o quadro (`SWING_*`) e, parou de girar, volta ao
## ombro; mirando, sempre o direito, chega mais perto e a mira fica lenta; o tiro dá coice (`kick`).
## Mira Sniper telescópica: ao mirar com a Sniper, a câmera entra em 1ª pessoa alinhada à mira, oculta o modelo para visão desobstruída,
## reduz a sensibilidade proporcionalmente ao zoom (2x / 4x / 8x / 16x) e projeta alcance de até 120 metros.
## Mouse/analógico giram.

const HEIGHT := 1.45
const MOUSE_SENS := 0.0035
const PAD_SENS := 2.6
const FOLLOW_DELAY := 1.5
## por cima do ombro (survival): distância atrás dela, desvio para a direita e campo de visão, andando e mirando;
## altura do pivô (no lugar de HEIGHT) e inclinação inicial (quase reta, olhando o caminho e não o chão)
const SHOULDER := {"length": 1.35, "length_aim": 1.1, "side": 0.6, "side_aim": 0.52, "fov": 55.0, "fov_aim": 44.0,
	"height": 1.62, "pitch": -0.1}
const PORTRAIT_SIDE := 0.5  # tela em pé: fração do desvio do ombro
const PORTRAIT_FOV := 62.0  # tela em pé: campo de visão mínimo (o da largura)
const SHOULDER_AIM_SENS := 0.6  # mirando, o mouse/analógico giram a esta fração
const RECOIL_RECOVER := 0.4  # radianos por segundo: o quanto do coice a câmera desfaz
const RECOIL_KEEP := 0.4  # fração de cada coice que fica (tiros seguidos sobem a mira)
const PITCH := -0.22  # inclinação inicial no arcade (no survival, SHOULDER.pitch)
## Até onde a câmera inclina para cima (rad): de dentro do labirinto de caixas dá para mirar no mezanino logo acima.
const PITCH_UP := 0.95
## survival sem mirar: ombro da câmera (+1 direito = o padrão, -1 esquerdo; ela fica do lado contrário da tela e abre o
## lado do ombro)
const SIDE_HOLD := 0.6  # s seguidos com a parede do mesmo lado até trocar
## parede/caixa fechando um lado da frente dela (do lado do peito até a frente na diagonal: colada ao lado ou a caixa em que
## ela se esconde, na frente e para um lado): esse lado fecha, o ombro vai para o lado aberto. Raios em leque de cada lado do
## corpo dela, a estes ângulos (graus a partir da frente DELA, não da câmera) e até SIDE_WALL m; lado fechado = SIDE_BLOCKED
## raios batendo e o outro no máximo SIDE_OPEN. O lado aberto vira ombro pela câmera (SIDE_ALIGN: de frente para a câmera não vale)
const SIDE_WALL := 2.0
const SIDE_FAN := [15.0, 35.0, 55.0, 75.0, 90.0]
const SIDE_BLOCKED := 3
const SIDE_OPEN := 1
const SIDE_ALIGN := 0.3  # o lado aberto dela tem que apontar pelo menos isto para um lado da câmera
const SIDE_SPRING := 3.5  # mola da troca (rad/s): sai devagar, acelera e chega sem tranco (~1,2 s de um ombro ao outro)
const SIDE_MOVE := 0.5  # m/s no plano: abaixo disso ela está parada
const SIDE_RELAX := 1.0  # s sem motivo para o ombro esquerdo até voltar ao direito
## survival sem mirar, girando a câmera (analógico direito/mouse) para o lado em que ela está na tela (com o ombro direito,
## para a esquerda): a câmera é puxada quase para o centro e se afasta/abre, dando amplitude; parou, volta com a mola
const SWING_RATE := 2.0  # rad/s de giro para o efeito cheio (o analógico todo gira PAD_SENS)
const SWING_CENTER := 0.85  # fração do desvio do ombro tirada no efeito cheio (quase no centro)
const SWING_FOV := 8.0  # graus a mais de campo de visão
const SWING_BACK := 0.3  # m a mais atrás dela
const SWING_SPRING := 5.0  # mola (rad/s)
const SWING_DAMP := 0.7  # amortecimento (< 1: na volta passa um pouco do ponto, o repuxo da mola)

var target: Node3D
var yaw := 0.0
var pitch := PITCH
var spring: SpringArm3D
var camera: Camera3D
var _idle_look := 0.0
var _snapped := false
var _shake := 0.0
var _shake_t := 0.0
var _recoil := 0.0  # coice ainda por desfazer (radianos)
var side := 1.0  # ombro da câmera sem mirar no survival, deslizando para `side_goal`
var side_goal := 1.0
var _side_relax := 0.0  # há quanto tempo nada pede o ombro esquerdo
var _side_wall_t := 0.0  # há quanto tempo a parede está só de um lado (com sinal do lado livre)
var _side_vel := 0.0  # velocidade da troca de lado (mola)
var swing := 0.0  # 0..1: quanto do efeito do giro está valendo (SWING_*)
var _swing_vel := 0.0
var _turn := 0.0  # giro da câmera (rad, + = para a direita) desde o último quadro
## Ações (alçapão, porta abrindo, pegar item em pé, detonador; pegar arma no baú/caixa não): a câmera gira em volta dela
## até um ângulo que mostra a ação (perfil / 3/4 de frente: rosto, mãos e o objeto), mais perto e de cima, e no fim volta
## devagar ao enquadramento de antes (o giro do jogador fica guardado em `yaw`). Lado escolhido no começo da ação: o mais
## livre de parede (`_pick_side`); o SpringArm segue encurtando se algo entrar no meio.
## angle = graus em volta dela a partir das costas (180 = de frente), length, pitch (rad), fov, fwd = m que o ponto
## olhado avança para a frente dela (para as mãos/o objeto), drop = m abaixo do osso da cabeça (peito/mãos).
const ACTIONS := {
	"hatch": {"angle": 95.0, "length": 2.1, "pitch": -0.42, "fov": 50.0, "fwd": 0.0, "drop": 0.15},
	"door": {"angle": 40.0, "length": 2.6, "pitch": -0.3, "fov": 52.0, "fwd": 0.8, "drop": 0.3},
	"pulse": {"angle": 140.0, "length": 1.8, "pitch": -0.3, "fov": 48.0, "fwd": 0.3, "drop": 0.3},
}
const ACTION_IN := 0.6  # s para girar até o ângulo da ação
const ACTION_OUT := 1.2  # s para voltar ao normal (mais devagar que a chegada)
const ACT_LOWS := [0.8, 0.3]  # alturas (acima dos pés) do ponto olhado ajoelhada/debruçada, para escolher o lado
const PULSE_HOLD := 0.9  # ação sem animação (pegar item em pé, detonador): s no ângulo antes de voltar
var _act_lin := 0.0  # 0..1 linear; o peso usado é o smoothstep dele
var _act_cfg: Dictionary = ACTIONS.pulse
var _act_kind := ""
var _act_side := 1.0  # +1/-1: de que lado dela a câmera gira
var _pulse := 0.0
var _head_bone := -1


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
	camera.far = 140.0
	spring.add_child(camera)
	camera.current = true
	if GameMode.shoulder_cam():
		pitch = SHOULDER.pitch


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative * MOUSE_SENS)


func _look(d: Vector2) -> void:
	# numa cena (Cutscene) a câmera dela não está na tela: mouse/analógico não a giram por trás
	if target and target.get("cutscene"):
		return
	if target and target.has_method("is_sniper_zoomed") and target.is_sniper_zoomed():
		var zoom_factor: float = target.call("sniper_zoom")
		d *= clampf(1.0 / zoom_factor, 0.05, 0.5)
	elif GameMode.shoulder_cam() and target and target.get("aiming"):
		d *= SHOULDER_AIM_SENS
	yaw -= d.x
	pitch = clampf(pitch - d.y, -1.1, PITCH_UP)
	_idle_look = 0.0
	_turn += d.x


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
	var in_sniper: bool = target.has_method("is_sniper_zoomed") and target.is_sniper_zoomed()
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
	var goal := focus + Vector3.UP * (SHOULDER.height if shoulder else HEIGHT)
	if target.get("crouching"):
		goal.y -= 0.45
	var act := _update_action(delta, in_sniper)
	if act > 0.0:
		goal = goal.lerp(_act_pivot(), act)
	if in_sniper:
		goal.y = focus.y + (1.15 if target.get("crouching") else 1.52)
	global_position = goal if not _snapped else global_position.lerp(goal, 1.0 - exp(-14.0 * delta))
	_snapped = true
	rotation = Vector3(lerpf(pitch, float(_act_cfg.pitch), act), lerp_angle(yaw, _act_yaw(), act) if act > 0.0 else yaw, 0.0)
	var k := 1.0 - exp(-10.0 * delta)

	if in_sniper:
		var zoom_mag: float = target.call("sniper_zoom")
		var target_fov := 60.0 / zoom_mag
		spring.spring_length = lerpf(spring.spring_length, 0.0, k * 2.0)
		spring.position.x = lerpf(spring.position.x, 0.0, k * 2.0)
		camera.fov = lerpf(camera.fov, target_fov, k * 2.0)
		if target.get("model") != null:
			target.model.visible = false
	else:
		if target.get("model") != null and not target.model.visible and not target.get("dead"):
			target.model.visible = true
		# esgueirando pela quina (PlayerLean): a câmera passa para o lado da quina, para ver o que está depois dela
		var lean: float = target.call("lean_side") if target.has_method("lean_side") else 0.0
		if shoulder:
			var portrait := vp.y > vp.x
			_update_side(delta, aiming)
			_update_swing(delta, aiming)
			var off: float = (SHOULDER.side_aim if aiming else SHOULDER.side * side * (1.0 - SWING_CENTER * swing)) * (PORTRAIT_SIDE if portrait else 1.0)
			var fov: float = SHOULDER.fov_aim if aiming else SHOULDER.fov + SWING_FOV * swing
			var length: float = SHOULDER.length_aim if aiming else SHOULDER.length + SWING_BACK * swing
			if act > 0.0:
				off = lerpf(off, 0.0, act)
				fov = lerpf(fov, float(_act_cfg.fov), act)
				length = lerpf(length, float(_act_cfg.length), act)
			spring.spring_length = lerpf(spring.spring_length, length, k)
			spring.position.x = lerpf(spring.position.x, lerpf(off, signf(lean) * PlayerLean.CAM_SIDE, absf(lean)), k)
			camera.fov = lerpf(camera.fov, maxf(fov, PORTRAIT_FOV) if portrait else fov, k)
		else:
			var off := lerpf(0.62 if aiming else 0.0, 0.0, act)
			spring.spring_length = lerpf(spring.spring_length, lerpf(1.6 if aiming else 3.0, float(_act_cfg.length), act), k)
			spring.position.x = lerpf(spring.position.x, lerpf(off, signf(lean) * PlayerLean.CAM_SIDE, absf(lean)), k)
			camera.fov = lerpf(camera.fov, lerpf(50.0 if aiming else 62.0, float(_act_cfg.fov), act), k)
	_shake_t = maxf(0.0, _shake_t - delta)
	var amp := _shake if _shake_t > 0.0 else 0.0
	camera.h_offset = randf_range(-amp, amp)
	camera.v_offset = randf_range(-amp, amp)
	_turn = 0.0


## Giro da câmera para o lado em que ela está na tela (sem mirar): a mola puxa `swing` para a rapidez do giro; parou, volta.
func _update_swing(delta: float, aiming: bool) -> void:
	var rate := _turn / maxf(delta, 0.001)
	var want := 0.0 if aiming else clampf(-rate * signf(side) / SWING_RATE, 0.0, 1.0)
	_swing_vel += ((want - swing) * SWING_SPRING * SWING_SPRING - 2.0 * SWING_DAMP * SWING_SPRING * _swing_vel) * delta
	swing = clampf(swing + _swing_vel * delta, -0.3, 1.2)


## Peso (0..1) do enquadramento de ação: sobe em ACTION_IN enquanto ela faz uma ação de `ACTIONS` (ou num `focus_pulse`),
## desce em ACTION_OUT quando acaba; curva suave nas duas pontas.
func _update_action(delta: float, in_sniper: bool) -> float:
	var kind: String = target.call("camera_action") if target.has_method("camera_action") else ""
	_pulse = maxf(0.0, _pulse - delta)
	if kind == "" and _pulse > 0.0:
		kind = "pulse"
	if in_sniper or target.get("dead") or target.get("cutscene"):
		kind = ""
		_pulse = 0.0
	if kind != "":
		if kind != _act_kind:
			_act_kind = kind
			_act_cfg = ACTIONS[kind]
			_pick_side()
		_act_lin = minf(1.0, _act_lin + delta / ACTION_IN)
	else:
		_act_kind = ""
		_act_lin = maxf(0.0, _act_lin - delta / ACTION_OUT)
	return smoothstep(0.0, 1.0, _act_lin)


## Ponto olhado na ação: abaixo da cabeça dela (desce junto quando ajoelha) e um pouco à frente, nas mãos/no objeto.
func _act_pivot() -> Vector3:
	var at: Vector3 = target.global_position
	var head := _head_y()
	at.y = (head if not is_nan(head) else at.y + 1.5) - float(_act_cfg.drop)
	return at - target.global_basis.z * float(_act_cfg.fwd)


## Giro da câmera na ação: o do corpo dela (as costas) mais `angle` para o lado escolhido.
func _act_yaw() -> float:
	return target.global_rotation.y + _act_side * deg_to_rad(float(_act_cfg.angle))


## Lado da ação: o que deixa a câmera mais longe de parede/caixa/mureta (raios do ponto olhado até onde a câmera iria,
## com o ponto na altura de agora e nas de ajoelhada/debruçada: a pose ainda vai mudar); empate = o mais perto do giro atual.
func _pick_side() -> void:
	var top := _act_pivot()
	var froms: Array[Vector3] = [top]
	for h: float in ACT_LOWS:
		froms.append(Vector3(top.x, minf(top.y, target.global_position.y + h), top.z))
	var space := get_world_3d().direct_space_state
	var best := -INF
	var length := float(_act_cfg.length)
	for sgn: float in [1.0, -1.0]:
		var y: float = target.global_rotation.y + sgn * deg_to_rad(float(_act_cfg.angle))
		var back := Basis.from_euler(Vector3(float(_act_cfg.pitch), y, 0.0)) * Vector3(0, 0, length)
		var free := length
		for from: Vector3 in froms:
			var q := PhysicsRayQueryParameters3D.create(from, from + back, 1)
			if target is CollisionObject3D:
				q.exclude = [target.get_rid()]
			var hit := space.intersect_ray(q)
			if hit:
				free = minf(free, from.distance_to(hit.position))
		free -= 0.05 * absf(angle_difference(yaw, y))  # empate: prefere girar menos
		if free > best:
			best = free
			_act_side = sgn


## Altura do osso da cabeça dela no mundo (pose da animação); NAN sem modelo.
func _head_y() -> float:
	var m = target.get("model")
	if m == null or m.get("skeleton") == null:
		return NAN
	var sk: Skeleton3D = m.skeleton
	if _head_bone < 0:
		_head_bone = sk.find_bone("Head")
		if _head_bone < 0:
			return NAN
	return (sk.global_transform * sk.get_bone_global_pose(_head_bone)).origin.y


## Ação sem animação (pegar item em pé, armar o detonador): gira até o ângulo da ação, fica PULSE_HOLD e volta. `snap` =
## corta direto para o ângulo (antes de uma tela que pausa o jogo: ao fechar ela, a câmera já está lá e só volta).
func focus_pulse(snap := false) -> void:
	_pulse = PULSE_HOLD
	_act_kind = "pulse"
	_act_cfg = ACTIONS.pulse
	if target == null or not is_inside_tree():
		return
	_pick_side()
	if not snap:
		return
	_act_lin = 1.0
	global_position = _act_pivot()
	rotation = Vector3(float(_act_cfg.pitch), _act_yaw(), 0.0)
	spring.spring_length = float(_act_cfg.length)
	spring.position.x = 0.0
	camera.fov = float(_act_cfg.fov)


## Ombro da câmera sem mirar (survival): o direito, a não ser que parede/caixa feche um lado da frente do corpo dela; aí o
## ombro do lado aberto (pela câmera). Andar não troca de ombro. Sem nada pedindo por `SIDE_RELAX`, volta ao direito.
## Mirando, nada muda aqui.
func _update_side(delta: float, aiming: bool) -> void:
	if aiming:
		return
	var chest: Vector3 = target.global_position + Vector3.UP * (0.9 if target.get("crouching") else 1.3)
	var body := Basis(Vector3.UP, target.global_rotation.y)
	var r := _hits(chest, body, 1.0)
	var l := _hits(chest, body, -1.0)
	var free := 0.0
	var open_dir := Vector3.ZERO  # lado aberto dela, no mundo
	if r >= SIDE_BLOCKED and l <= SIDE_OPEN:
		open_dir = -body.x
	elif l >= SIDE_BLOCKED and r <= SIDE_OPEN:
		open_dir = body.x
	var along := open_dir.dot(yaw_basis().x)
	if absf(along) > SIDE_ALIGN:
		free = signf(along)
	if free != 0.0:
		_side_wall_t = (_side_wall_t if signf(_side_wall_t) == free else 0.0) + free * delta
	else:
		_side_wall_t = 0.0
	var need := 0.0
	if absf(_side_wall_t) > SIDE_HOLD:
		need = signf(_side_wall_t)
	if need != 0.0:
		side_goal = need
		_side_relax = 0.0
	else:
		_side_relax += delta
		if _side_relax > SIDE_RELAX:
			side_goal = 1.0
	# mola criticamente amortecida: começa e termina devagar, sem passar do ponto
	_side_vel += ((side_goal - side) * SIDE_SPRING * SIDE_SPRING - 2.0 * SIDE_SPRING * _side_vel) * delta
	side = clampf(side + _side_vel * delta, -1.0, 1.0)


## Quantos raios do leque de um lado do corpo dela (`body` = o giro dela; `sgn` +1 direita, -1 esquerda) batem no cenário.
func _hits(from: Vector3, body: Basis, sgn: float) -> int:
	var space := get_world_3d().direct_space_state
	var n := 0
	for deg: float in SIDE_FAN:
		var dir := body * Vector3(sin(deg_to_rad(deg)) * sgn, 0.0, -cos(deg_to_rad(deg)))
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * SIDE_WALL, 1)
		if not space.intersect_ray(q).is_empty():
			n += 1
	return n


## Ela andando pelo direcional (não empurrada, não numa cena, não esgueirando pela quina).
func _walking() -> bool:
	if target.get("cutscene") or target.get("dead"):
		return false
	if target.has_method("lean_side") and target.call("lean_side") != 0.0:
		return false
	if Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() < 0.2:
		return false
	var v: Vector3 = target.get("velocity")
	return Vector2(v.x, v.z).length() > SIDE_MOVE


## Enquadramento padrão (fim de cena): atrás dela olhando para `new_yaw`, na inclinação inicial, sem coice; o pivô
## pula para ela em vez de vir deslizando.
func reset_view(new_yaw: float) -> void:
	yaw = new_yaw
	pitch = SHOULDER.pitch if GameMode.shoulder_cam() else PITCH
	_recoil = 0.0
	_idle_look = 0.0
	_snapped = false
	side = 1.0
	side_goal = 1.0
	_side_relax = 0.0
	swing = 0.0
	_swing_vel = 0.0
	_turn = 0.0
	_side_wall_t = 0.0
	_side_vel = 0.0
	_act_lin = 0.0
	_act_kind = ""
	_pulse = 0.0


## Treme a câmera por `time` segundos (golpes, mordida).
func shake(strength: float, time: float) -> void:
	_shake = maxf(strength, _shake if _shake_t > 0.0 else 0.0)
	_shake_t = maxf(_shake_t, time)
	Rumble.shake(strength, time)


## Coice do tiro: a mira sobe `up` radianos e a câmera desfaz a maior parte (tiros seguidos sobem a mira). Só no survival.
func kick(up: float) -> void:
	if up <= 0.0 or not GameMode.shoulder_cam():
		return
	pitch = clampf(pitch + up, -1.1, PITCH_UP)
	_recoil += up * (1.0 - RECOIL_KEEP)


## Gira a câmera para que o centro da tela (a retícula) fique sobre `point`.
func look_at_point(point: Vector3) -> void:
	var d := point - camera.global_position
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.1, PITCH_UP)
	_idle_look = 0.0


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


func aim_ray() -> Array[Vector3]:
	return [camera.global_position, -camera.global_basis.z]


## Ponto sob a retícula: o que o raio da câmera acerta (cenário e personagens), ou até 120 m à frente.
## Acertos a menos de 2 m da câmera (o ombro dela, uma quina) não contam: a arma viraria de repente.
func aim_point(exclude: Array[RID]) -> Vector3:
	var ray := aim_ray()
	var in_sniper: bool = target and target.has_method("is_sniper_zoomed") and target.is_sniper_zoomed()
	var max_range: float = 120.0 if in_sniper else 30.0
	var q := PhysicsRayQueryParameters3D.create(ray[0] + ray[1] * (0.5 if in_sniper else 2.0), ray[0] + ray[1] * max_range, 1 | 2, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else ray[0] + ray[1] * max_range
