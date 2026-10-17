extends Node3D
## Cena de teste: sala, heroína, alvos de treino, um velociraptor, HUD e pós-processo PS1.
## Captura para conferência:  godot --path game -- --capture=out.png [--shot=idle|aim|run|ragdoll|front|roll|crouch|face]
##   raptor:  --shot=raptor_idle|raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead
##            (câmera de revisão em volta dele; --yaw=graus gira a câmera; --playercam usa a câmera dela)
## Visual:  --gfx=ps1|ps2  (F2 alterna no jogo; ver Gfx)

const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const HELP := "WASD mover  SHIFT andar  MOUSE-D mirar  MOUSE-E atirar\nESPACO rolar  C agachar  H dano  K morrer\nR reiniciar  F1 ajuda  F2 visual PS1/PS2"

var player: Player
var dummies: Array[TargetDummy] = []
var raptors: Array[Raptor] = []
var _hud: CanvasLayer
var _post: ColorRect
var _hud_health: Label
var _hud_help: Label
var _crosshair: Label
var _capture := ""
var _shot := "idle"
var _t := 0.0
var _until := 1.5
var _saving := false
var _yaw := NAN
var _review_cam: Camera3D
var _player_cam := false


func _ready() -> void:
	InputSetup.register()
	Level.build(self)
	player = Player.new()
	player.position = Vector3(0, 0, 6)
	add_child(player)
	for d in [[Vector3(0, 0, -3), 0.0, "aim"], [Vector3(-3.5, 0, -6), 0.4, "idle"], [Vector3(4, 0, -5.5), -0.5, "aim"]]:
		var t := TargetDummy.new()
		t.pose = d[2]
		t.position = d[0]
		# os alvos olham para a heroína (+Z)
		t.rotation.y = PI + d[1]
		add_child(t)
		dummies.append(t)
	# raptor no fundo do galpão, fora da vista dela no começo
	var r := Raptor.new()
	r.target = player
	r.position = Vector3(7, 0, -9)
	r.rotation.y = atan2(7.0, -15.0)
	add_child(r)
	raptors.append(r)
	_build_post()
	_build_hud()
	player.health_changed.connect(func(v: int) -> void: _hud_health.text = "VIDA %d" % v)
	apply_gfx(Gfx.mode)
	_parse_args()
	if _capture == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().create_timer(10.0).timeout.connect(func() -> void: _hud_help.visible = false)


func _build_post() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	var rect := ColorRect.new()
	_post = rect
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = POST_SHADER
	rect.material = m
	layer.add_child(rect)
	add_child(layer)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	_hud = layer
	_hud_health = _label(layer, "VIDA 100", Vector2(6, 4))
	# mira numa camada sem escala: ancorada no centro, a escala do HUD (apply_gfx) a jogaria para o canto
	var cross_layer := CanvasLayer.new()
	cross_layer.layer = 1
	add_child(cross_layer)
	_crosshair = _label(cross_layer, "+", Vector2.ZERO)
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crosshair.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_crosshair.grow_vertical = Control.GROW_DIRECTION_BOTH
	_crosshair.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_crosshair.visible = false
	# no topo, logo abaixo da vida: embaixo ficava por cima das pernas dela em telas 4:3
	_hud_help = _label(layer, HELP, Vector2(6, 16))
	add_child(layer)


func _label(parent: Node, text: String, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 2)
	parent.add_child(l)
	return l


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("reset"):
		reset_all()
	elif event.is_action_pressed("toggle_help"):
		_hud_help.visible = not _hud_help.visible
	elif event.is_action_pressed("toggle_gfx"):
		apply_gfx("ps2" if Gfx.mode == "ps1" else "ps1")


## Aplica o modo de visual (ver Gfx): materiais e luzes, resolução interna, pós-processo de PS1 e HUD.
func apply_gfx(m: String) -> void:
	Gfx.set_mode(m, self)
	get_window().content_scale_size = Gfx.RES[m]
	_post.visible = m == "ps1"
	# o HUD foi feito para 320x240: na resolução maior é ampliado para manter o tamanho na tela
	var k := float(Gfx.RES[m].y) / 240.0
	_hud.scale = Vector2(k, k)
	_crosshair.add_theme_font_size_override("font_size", int(8 * k))


func reset_all() -> void:
	player.respawn()
	for d in dummies:
		d.reset()
	for r in raptors:
		r.reset()


# ------------------------------------------------------------------ captura de tela para revisão
func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			# ferramenta de desenvolvimento: só em build de debug, só .png, sem caminho de rede
			var path := a.trim_prefix("--capture=")
			if OS.is_debug_build() and path.get_extension().to_lower() == "png" and not path.replace("\\", "/").begins_with("//"):
				_capture = path
			else:
				push_warning("--capture ignorado (só .png local em build de debug): " + path)
		elif a.begins_with("--shot="):
			_shot = a.get_slice("=", 1)
		elif a.begins_with("--at="):
			_until = float(a.get_slice("=", 1))
		elif a.begins_with("--gfx="):
			var g := a.get_slice("=", 1)
			if g in Gfx.MODES:
				apply_gfx(g)
		elif a == "--playercam":
			_player_cam = true
		elif a.begins_with("--yaw="):
			_yaw = deg_to_rad(float(a.get_slice("=", 1)))
	if _capture == "":
		return
	_hud_help.visible = _shot == "idle"
	if _shot.begins_with("raptor_"):
		_setup_raptor_shot()
	elif _shot == "face":
		# close do rosto (--yaw gira em volta dela: 0 = de frente)
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 30.0
		add_child(_review_cam)
		_review_cam.current = true
	match _shot:
		"aim":
			Input.action_press("aim")
		"run":
			Input.action_press("move_forward")
		"crouch":
			Input.action_press("crouch")


func _process(delta: float) -> void:
	_crosshair.visible = player.aiming and player.model.is_aimed()
	if _capture == "":
		return
	var prev := _t
	_t += delta
	var at := func(sec: float) -> bool: return prev < sec and _t >= sec
	if not is_nan(_yaw) and (_shot != "ragdoll" or _t > 2.3):
		# ângulo fixo de câmera relativo à frente dela (0 = atrás, 180 = de frente)
		player.camera_rig.yaw = player.rotation.y + _yaw
		player.camera_rig.pitch = -0.15
	if _review_cam and _shot == "face":
		var a := player.rotation.y + PI + (0.0 if is_nan(_yaw) else _yaw)
		var head := player.global_position + Vector3.UP * 1.6
		_review_cam.global_position = head + Vector3(sin(a), 0.03, cos(a)) * 0.75
		_review_cam.look_at(head)
	elif _review_cam:
		_raptor_shot(at)
	match _shot:
		"aim":
			# reaplica: o Godot solta ações pressionadas se a janela perde o foco
			Input.action_press("aim")
		"run":
			Input.action_press("move_forward")
		"crouch":
			if at.call(0.05):
				Input.action_release("crouch")
		"roll":
			if at.call(0.4):
				Input.action_press("roll")
			if at.call(0.45):
				Input.action_release("roll")
		"ragdoll", "dummy":
			if at.call(0.3):
				Input.action_press("aim")
			if _t > 0.5 and _t < 2.0:
				player.camera_rig.look_at_point(dummies[0].global_position + Vector3.UP * 1.2)
			for k in 3:
				if at.call(0.9 + k * 0.35):
					player.fire()
			if at.call(2.1):
				Input.action_release("aim")
				if _shot == "ragdoll":
					player.take_hit(999, player.global_basis.z, player.global_position + Vector3.UP * 1.2)
					player.camera_rig.yaw = PI * 0.75
					player.camera_rig.pitch = -0.6
			if _t > 2.1:
				player.camera_rig.camera.fov = 34.0
				if _shot == "dummy" and at.call(2.4):
					# chega perto para ver o alvo caído
					player.global_position = Vector3(2.0, 0, -1.0)
					player.reset_physics_interpolation()
					player.model.visible = false
				if _shot == "dummy" and _t > 2.5:
					player.camera_rig.look_at_point(dummies[0].model.ragdoll.bodies["Hips"].global_position)
	if _t >= _until:
		_save_and_quit()


## Revisão do raptor: posiciona os dois, liga uma câmera própria e força o estado pedido.
func _setup_raptor_shot() -> void:
	var r := raptors[0]
	for d in dummies:
		d.visible = false
	# corredor livre no fundo do galpão (z = 9), ele olhando para +X, ela à frente/atrás dele
	r.global_position = Vector3(-4, 0, 9)
	r.rotation.y = -PI * 0.5
	var fwd := Vector3.RIGHT
	var her := {
		"bite": fwd * 1.7, "tail": -fwd * 1.6 - Vector3.BACK * 1.0, "leap": fwd * 7.0,
		"charge": fwd * 8.0, "idle": fwd * 15.0,
	}
	player.global_position = r.global_position + her.get(_shot.trim_prefix("raptor_"), fwd * 4.0)
	player.rotation.y = PI * 0.5
	player.reset_physics_interpolation()
	r.reset_physics_interpolation()
	player.camera_rig.yaw = 0.0
	_review_cam = Camera3D.new()
	_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_review_cam.fov = 55.0
	add_child(_review_cam)
	_review_cam.current = not _player_cam


func _raptor_shot(at: Callable) -> void:
	var r := raptors[0]
	if at.call(0.15):
		match _shot:
			"raptor_roar": r.start_roar()
			"raptor_study": r.start_study()
			"raptor_bite": r.start_bite()
			"raptor_tail": r.start_tail()
			"raptor_leap": r.start_leap()
			"raptor_charge": r.start_charge()
			"raptor_dead": r.take_hit(999, Vector3.FORWARD, r.global_position)
	if _player_cam:
		# um pouco de lado: atrás dela, em linha reta, o corpo dela tapa o raptor
		player.camera_rig.yaw = player.rotation.y + (0.6 if is_nan(_yaw) else _yaw)
		return
	var vp := get_viewport().get_visible_rect().size
	_review_cam.keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	# segue os corpos de verdade (ragdoll dela arremessada, ragdoll dele morto), não as cápsulas
	var her := player.camera_focus()
	var him: Vector3 = r.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if r.dead else r.global_position
	var mid := him.lerp(her, 0.5)
	var dist := 3.0 + 0.45 * him.distance_to(her)
	var yaw := deg_to_rad(160.0) if is_nan(_yaw) else _yaw
	_review_cam.global_position = mid + Vector3(sin(yaw), 0.0, cos(yaw)) * dist + Vector3.UP * 1.3
	_review_cam.look_at(mid + Vector3.UP * 0.8)


func _save_and_quit() -> void:
	if _saving:
		return
	_saving = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture)
	print("captura salva: ", _capture, " ", img.get_size(), " yaw_cam=", player.camera_rig.yaw, " yaw_player=", player.rotation.y, " estado=", player.model.state, " raptor=", raptors[0].state if raptors else "-")
	get_tree().quit()
