class_name Showroom
extends Node
## Showroom dos dinossauros (menu de pausa > SHOWROOM): palco 3D próprio (SubViewport com mundo à parte, chão
## quadriculado, luz com sombra) com o raptor ou o alossauro e a lista de animações dele. Roda com o jogo pausado.
## - cima/baixo (W/S, setas, analógico, direcional) ou clique escolhe a animação; as que não são ciclo repetem;
## - A/D, analógico direito ou arrastar com o mouse gira a câmera em volta (e inclina); roda do mouse, Z/X ou L1/R1 = zoom;
## - Q/TAB/SELECT troca o bicho; F/quadrado troca o modo: NO LUGAR (a animação pura, pés soltos), EM CÍRCULO (os
##   ciclos de andar/correr/espreitar andam numa roda na velocidade em que foram feitos: pés presos e inércia como no
##   jogo) e GIRANDO (vira no lugar: passos do FootPlant e cauda com mola); ESPAÇO/X troca a velocidade (1x, 1/2,
##   1/4, parado);
## - ESC/START/C/bola volta ao menu.
## Testes e capturas: `open(bicho, animação, modo)` e `pick`/`set_mode`/`set_creature` direto.

signal closed

const CREATURES := ["raptor", "allosaurus"]
const CREATURE_NAMES := {"raptor": "VELOCIRAPTOR", "allosaurus": "ALOSSAURO"}
const MODES := ["NO LUGAR", "EM CÍRCULO", "GIRANDO"]
const SPEEDS := [1.0, 0.5, 0.25, 0.0]
## nome no jogo de cada animação (as que não estão aqui aparecem com o nome do arquivo)
const NAMES := {
	"Idle": "PARADO", "Walk": "ANDAR", "Run": "CORRER", "Stalk": "ESPREITAR", "Study": "ESTUDAR A PRESA",
	"Roar": "RUGIDO", "RoarAt": "RUGIDO NA LUTA", "LeapPrep": "PREPARA O SALTO", "LeapAir": "SALTO NO AR",
	"Bite": "MORDIDA", "Shake": "SACODE A PRESA", "TailWhip": "RABADA (ESQ.)", "TailWhipR": "RABADA (DIR.)",
	"Headbutt": "CABEÇADA (ESQ.)", "HeadbuttR": "CABEÇADA (DIR.)", "Stomp": "PISADA", "Throw": "ARREMESSO",
	"Hit": "LEVA TIRO", "Death": "MORTE",
}
## ciclos de locomoção: m/s em velocidade 1 (o mesmo que o jogo usa) = andam no modo EM CÍRCULO
const GAITS := {
	"raptor": {"Walk": Raptor.WALK_ANIM_SPEED, "Run": Raptor.RUN_ANIM_SPEED, "Stalk": Raptor.STALK_ANIM_SPEED},
	"allosaurus": {"Walk": Allosaurus.WALK_ANIM_SPEED, "Run": Allosaurus.RUN_ANIM_SPEED},
}
const SIZE := {"raptor": 1.0, "allosaurus": 3.0}  # escala do palco (câmera, roda, alvo)
const CIRCLE_R := 2.6  # raio da roda (m, raptor), corrida com o dobro
const TURN_RATE := deg_to_rad(90.0)  # GIRANDO
const REPEAT_GAP := 0.6  # s parado no fim de uma animação que não é ciclo, antes de repetir
const ROW := 10.0  # altura de cada linha da lista (unidades do HUD de 240)
const LIST_W := 120.0
const UP := ["move_forward", "ui_up"]
const DOWN := ["move_back", "ui_down"]
const BACK := ["crouch"]  # ESC / START chegam como "pause" (_input)
## botões em duas fileiras (numa só não cabe na tela 16:9)
const HINT_ROWS := [
	[{"keys": ["SETAS"], "pad": "dpad", "text": "ANIMAÇÃO"}, {"keys": ["A", "D"], "text": "GIRAR"},
		{"keys": ["RODA", "Z", "X"], "pad_action": "aim", "text": "ZOOM"}],
	[{"action": "switch_weapon", "text": "BICHO"}, {"action": "jump", "text": "MODO"}, {"action": "roll", "text": "VELOCIDADE"},
		{"action": "pause", "text": "VOLTAR"}],
]

var is_open := false
var creature := "raptor"
var anims: Array[String] = []
var selected := 0
var mode := 0
var speed_i := 0
var yaw := 0.6
var pitch := -0.25
var dist := 4.6
var model: RaptorModel
var body: Node3D  # leva o modelo (anda na roda, gira)
var _ui: CanvasLayer
var _view_layer: CanvasLayer
var _view: SubViewportContainer
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _band: ColorRect
var _title: Label
var _info: Label
var _hints: Array[UiStyle.Hint] = []
var _rows: Array[Label] = []
var _ui_scale := 1.0
var _opened_frame := -1
var _around := 0.0  # ângulo na roda
var _repeat_t := 0.0
var _drag := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view_layer = CanvasLayer.new()
	_view_layer.layer = 5
	add_child(_view_layer)
	_view = SubViewportContainer.new()
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_layer.add_child(_view)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_view.add_child(_vp)
	_build_stage()
	_ui = CanvasLayer.new()
	_ui.layer = 6
	add_child(_ui)
	_band = UiStyle.rect(_ui, UiStyle.BAND)
	_title = UiStyle.label(_ui, "SHOWROOM", UiStyle.ACCENT, UiStyle.M)
	_info = UiStyle.label(_ui, "", UiStyle.INK, UiStyle.S)
	for items in HINT_ROWS:
		var h := UiStyle.Hint.new()
		_ui.add_child(h)
		h.set_items(items)
		_hints.append(h)
	_set_visible(false)


func _build_stage() -> void:
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.57, 0.62)
	env.environment.ambient_light_energy = 0.8
	_stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_stage.add_child(sun)
	# chão: placa clara com linhas a cada 0,5 m e mais grossas a cada 2 m (dá para ver o pé parado ou patinando)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor.mesh = plane
	floor.material_override = _flat(Color(0.42, 0.43, 0.45))
	_stage.add_child(floor)
	var thin := _flat(Color(0.3, 0.31, 0.33))
	var thick := _flat(Color(0.22, 0.23, 0.25))
	for k in range(-80, 81):
		var major := k % 4 == 0
		for axis in 2:
			var line := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var w := 0.03 if major else 0.012
			bm.size = Vector3(w, 0.002, 80) if axis == 0 else Vector3(80, 0.002, w)
			line.mesh = bm
			line.position = Vector3(k * 0.5, 0.002, 0) if axis == 0 else Vector3(0, 0.002, k * 0.5)
			line.material_override = thick if major else thin
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_stage.add_child(line)
	body = Node3D.new()
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stage.add_child(body)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 200.0
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stage.add_child(_cam)
	_cam.current = true


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


## Escala do HUD (main.apply_gfx, pelo menu de pausa): a lista e os botões em unidades de 240 de altura.
func set_ui_scale(k: float) -> void:
	_ui_scale = k
	_ui.scale = Vector2(k, k)


func open(which := creature, anim := "", move := -1) -> void:
	is_open = true
	_opened_frame = Engine.get_process_frames()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if move >= 0:
		mode = move
	set_creature(which, anim)
	_set_visible(true)
	_layout()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_drag = false
	_set_visible(false)
	if model:
		model.queue_free()
		model = null
	closed.emit()


func _set_visible(v: bool) -> void:
	_view_layer.visible = v
	_ui.visible = v
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if v else SubViewport.UPDATE_DISABLED


## Troca o bicho no palco e refaz a lista; `anim` escolhe a animação (vazio = a primeira).
func set_creature(which: String, anim := "") -> void:
	creature = which
	if model:
		body.remove_child(model)
		model.queue_free()
	model = AllosaurusModel.new() if which == "allosaurus" else RaptorModel.new()
	model.showroom = true
	model.chirps = false
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.add_child(model)
	dist = 4.6 * SIZE[which]
	anims.clear()
	var loops: Array[String] = []
	var rest: Array[String] = []
	for a in model.anim_player.get_animation_list():
		if a == "RESET":
			continue
		(loops if a in model.loops else rest).append(a)
	for a in model.loops:  # ciclos primeiro, na ordem do modelo
		if a in loops:
			anims.append(a)
	rest.sort()
	anims.append_array(rest)
	_build_rows()
	pick(maxi(anims.find(anim), 0), false)


func _build_rows() -> void:
	for l in _rows:
		l.queue_free()
	_rows.clear()
	for i in anims.size():
		var l := UiStyle.label(_ui, "", UiStyle.INK, UiStyle.S)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.gui_input.connect(_on_row_input.bind(i))
		_rows.append(l)


## Toca a animação `i` da lista do começo.
func pick(i: int, beep := true) -> void:
	if beep and i != selected:
		Sfx.ui(self, "keypad_beep")
	selected = i
	_repeat_t = 0.0
	model.feet.reset()
	model.sway.reset()
	model.play(anims[i], 0.2, SPEEDS[speed_i], true)
	for k in _rows.size():
		var a := anims[k]
		var name: String = NAMES.get(a, a.to_upper())
		_rows[k].text = ("> %s" if k == selected else "  %s") % name
		_rows[k].add_theme_color_override("font_color", UiStyle.ACCENT if k == selected else UiStyle.INK)
	_apply_mode()


func set_mode(m: int) -> void:
	mode = posmod(m, MODES.size())
	_apply_mode()


func set_speed(i: int) -> void:
	speed_i = posmod(i, SPEEDS.size())
	model.anim_player.speed_scale = SPEEDS[speed_i]


## NO LUGAR mostra a animação pura (sem pés presos nem inércia: a esteira de andar ficaria brigando com os pés);
## nos outros modos o corpo anda/gira e os modificadores trabalham como no jogo.
func _apply_mode() -> void:
	var live := mode != 0
	model.feet.active = live
	model.sway.active = live
	model.feet.reset()
	model.sway.reset()
	if mode == 0:
		body.position = Vector3.ZERO
		body.rotation = Vector3.ZERO
		_around = 0.0


func current_anim() -> String:
	return anims[selected] if selected < anims.size() else ""


## m/s do ciclo de locomoção que está tocando (0 = não anda).
func gait_speed() -> float:
	return float(GAITS[creature].get(current_anim(), 0.0))


func _process(delta: float) -> void:
	if not is_open or model == null:
		return
	_layout()
	var s: float = SPEEDS[speed_i]
	_move_body(delta * s)
	_repeat(delta)
	_aim_camera()
	if Engine.get_process_frames() == _opened_frame:
		return  # o botão que abriu não conta
	var step := int(_just(DOWN)) - int(_just(UP))
	if step != 0:
		pick(posmod(selected + step, anims.size()))
	if _just(["switch_weapon"]):
		Sfx.ui(self, "keypad_ok")
		set_creature(CREATURES[posmod(CREATURES.find(creature) + 1, CREATURES.size())], current_anim())
	if _just(["jump"]):
		Sfx.ui(self, "keypad_beep")
		set_mode(mode + 1)
	if _just(["roll"]):
		Sfx.ui(self, "keypad_beep")
		set_speed(speed_i + 1)
	if _just(BACK):
		close()
		return
	yaw -= (Input.get_axis("move_left", "move_right") + Input.get_axis("look_left", "look_right")) * 2.0 * delta
	pitch = clampf(pitch - Input.get_axis("look_up", "look_down") * 1.5 * delta, -1.3, 0.25)
	var zoom := 0.0
	if Input.is_key_pressed(KEY_Z) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER):
		zoom -= 1.0
	if Input.is_key_pressed(KEY_X) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER):
		zoom += 1.0
	if zoom != 0.0:
		dist = clampf(dist * exp(zoom * 1.2 * delta), 1.2 * SIZE[creature], 14.0 * SIZE[creature])


## EM CÍRCULO: ciclo de locomoção anda numa roda na velocidade em que foi feito (os pés não patinam), virado para a
## frente do caminho; GIRANDO: vira no lugar. `dt` já vem com a velocidade escolhida.
func _move_body(dt: float) -> void:
	match mode:
		1:
			var v := gait_speed()
			if v <= 0.0:
				return
			var r: float = CIRCLE_R * SIZE[creature] * (2.0 if current_anim() == "Run" else 1.0)
			_around += v / r * dt
			body.position = Vector3(cos(_around) * r, 0.0, -sin(_around) * r) - Vector3(r, 0.0, 0.0)
			# andando no sentido anti-horário visto de cima: a frente (-Z do modelo) na tangente da roda
			body.rotation.y = _around
		2:
			body.rotation.y += TURN_RATE * dt


## Animação que não é ciclo: no fim fica parada um instante e começa de novo.
func _repeat(delta: float) -> void:
	var a := current_anim()
	if a in model.loops or model.anim_player.speed_scale == 0.0:
		return
	if not model.anim_player.is_playing() or model.anim_player.current_animation_position >= model.length_of(a) - 0.001:
		_repeat_t += delta
		if _repeat_t >= REPEAT_GAP:
			_repeat_t = 0.0
			model.play(a, 0.15, SPEEDS[speed_i], true)


func _aim_camera() -> void:
	var k: float = SIZE[creature]
	var target := body.global_position + Vector3.UP * 0.6 * k
	var off := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * dist
	_cam.look_at_from_position(target + off, target)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			dist = maxf(dist * 0.9, 1.2 * SIZE[creature])
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			dist = minf(dist * 1.1, 14.0 * SIZE[creature])
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_drag = event.pressed
	elif event is InputEventMouseMotion and _drag:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch - event.relative.y * 0.006, -1.3, 0.25)


func _on_row_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pick(i)
		_drag = false
		get_viewport().set_input_as_handled()


func _just(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _layout() -> void:
	var full := get_viewport().get_visible_rect().size
	_view.position = Vector2.ZERO
	_view.size = full
	var area := full / _ui.scale
	var top := 22.0
	_band.position = Vector2(4, top - 4)
	_band.size = Vector2(LIST_W, ROW * anims.size() + 8)
	_title.position = Vector2(6, 4)
	for i in _rows.size():
		_rows[i].position = Vector2(8, top + ROW * i)
		_rows[i].size = Vector2(LIST_W - 8, ROW)
	var a := current_anim()
	var length := model.length_of(a) if model and a != "" else 0.0
	var speed_txt := "PARADO" if SPEEDS[speed_i] == 0.0 else "%sx" % ("1" if SPEEDS[speed_i] == 1.0 else ("1/2" if SPEEDS[speed_i] == 0.5 else "1/4"))
	var move_txt: String = MODES[mode]
	if mode == 1 and gait_speed() <= 0.0:
		move_txt += " (SÓ ANDAR/CORRER)"
	_info.text = "%s   %s (%s)   %.2f s%s   %s   %s" % [CREATURE_NAMES[creature], NAMES.get(a, a.to_upper()), a, length,
		" CICLO" if model and a in model.loops else "", move_txt, speed_txt]
	_info.position = Vector2(LIST_W + 12, 6)
	for i in _hints.size():
		_hints[i].position = Vector2(roundf((area.x - _hints[i].size.x) * 0.5), area.y - 14.0 * (_hints.size() - i) - 2.0)
