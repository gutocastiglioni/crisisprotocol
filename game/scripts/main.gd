extends Node3D
## Cena de teste: sala, heroína, alvos de treino, baús com M16 e escopeta, um velociraptor, HUD e pós-processo PS1.
## Captura para conferência:  godot --path game -- --capture=out.png [--shot=idle|aim|run|ragdoll|front|roll|crouch|face]
##   movimentos:  --shot=walk|crouch_walk|crouch_aim|jump|hang|climb|mantle|pickup|rifle|rifle_aim  (--at=segundos)
##   armas:  --shot=pickup_shotgun|shotgun|shotgun_aim|fire_pistol|fire_m16|fire_shotgun|pump  (tiros: --at=segundos)
##   raptor:  --shot=raptor_idle|raptor_roar|raptor_study|raptor_bite|raptor_tail|raptor_leap|raptor_charge|raptor_dead
##            (câmera de revisão em volta dele; --yaw=graus gira a câmera; --playercam usa a câmera dela)
##   sangue:  --shot=soldier_headshot|soldier_wounded|raptor_blood  (esguicho/poça: --at=segundos)
##   alossauro:  --shot=allo_idle|allo_roar|allo_roar_at|allo_stomp|allo_headbutt|allo_tail|allo_bite|allo_dead|allo_end
##               (na pedreira; --yaw, --playercam)
##   pedreira:  --shot=arena (a câmera dela olhando a sala da entrada; --pos=x,z[,graus] para outro ponto)
##   --pitch=graus inclina a câmera dela junto com --yaw (> 0 = para cima; mirando, a arma acompanha)
## Visual:  --gfx=ps1|ps2  (F2 alterna no jogo; ver Gfx)

const POST_SHADER := preload("res://shaders/psx_post.gdshader")
const MOVE_SHOTS := [
	"walk", "crouch_walk", "crouch_aim", "jump", "hang", "climb", "mantle", "pickup", "rifle", "rifle_aim",
	"pickup_shotgun", "shotgun", "shotgun_aim", "fire_pistol", "fire_m16", "fire_shotgun", "pump",
]
const HEADSHOT_TIME := 1.0  # quanto tempo o aviso de tiro na cabeça fica na tela
const END_DELAY := 3.0  # depois que o alossauro cai, a tela de fim aparece (dá tempo de ver o corpo tombar)
const HELP := "WASD mover  SHIFT andar  MOUSE-D mirar  MOUSE-E atirar\nESPACO cambalhota  C agachar  F pular/agarrar\nE pegar (triangulo)  Q trocar arma (select)\nH dano  K morrer  R reiniciar  F1 ajuda  F2 PS1/PS2"

var player: Player
var dummies: Array[TargetDummy] = []
var chest: Chest
var chests: Array[Chest] = []
var raptors: Array[Raptor] = []
var soldiers: Array[Soldier] = []
var allosaurus: Allosaurus
var _hud_daze: Label
var _end: Control
var _end_stats: Label
var _play_t := 0.0  # tempo de jogo até o fim (tela de fim)
var _end_t := -1.0  # > 0: contando para mostrar a tela de fim
var ended := false
var _hud: CanvasLayer
var _post: ColorRect
var _hud_health: Label
var _hud_help: Label
var _hud_weapon: Label
var _hud_stealth: Label
var _hud_headshot: Label
var _headshot_t := 0.0
var _prompt: Control
var _prompt_text: Label
var _crosshair: Label
var _capture := ""
var _shot := "idle"
var _t := 0.0
var _until := 1.5
var _saving := false
var _yaw := NAN
var _pitch := -0.15
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
	# baú com o M16 perto do começo, de frente para ela
	chest = Chest.new()
	chest.position = Vector3(2.6, 0, 3.6)
	chest.rotation.y = atan2(-2.6, 2.4)
	add_child(chest)
	chests.append(chest)
	# baú com a escopeta do outro lado, perto da coluna da esquerda, de frente para ela; a frente fica mais para +Z
	# que para +X (menos de 45°): a textura do cenário é projetada pelo mundo e, virada para +X, o estêncil sai espelhado
	var sg := Chest.new()
	sg.item = "shotgun"
	sg.position = Vector3(-3.0, 0, 2.6)
	sg.rotation.y = atan2(3.0, 3.4)
	add_child(sg)
	chests.append(sg)
	# os velociraptors ficam no pátio da mata (segunda sala, pela porta oeste) e na pedreira (última sala, junto com o
	# alossauro), cada um patrulhando a sua rota
	for post in Yard.POSTS + Arena.POSTS:
		var r := Raptor.new()
		_place(r, post)
		raptors.append(r)
	allosaurus = Allosaurus.new()
	_place(allosaurus, Arena.ALLO)
	allosaurus.killed.connect(func() -> void: _end_t = END_DELAY)
	# soldados de guarda no galpão, cada um com a sua ronda (alarme em comum com os raptors: grupo "enemies")
	for g in Soldier.GUARDS:
		var sd := Soldier.new()
		sd.target = player
		sd.position = g.route[0]
		var next: Vector3 = g.route[1] - g.route[0]
		sd.rotation.y = atan2(-next.x, -next.z)
		for p in g.route:
			sd.route.append(p)
		add_child(sd)
		soldiers.append(sd)
	Yard.bake_nav(self)
	var sound := Soundscape.new()
	sound.target = player
	add_child(sound)
	_build_post()
	_build_hud()
	player.health_changed.connect(func(v: int) -> void: _hud_health.text = "VIDA %d" % v)
	player.headshot.connect(func(_who: Node) -> void: _headshot_t = HEADSHOT_TIME)
	apply_gfx(Gfx.mode)
	_parse_args()
	if _capture == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().create_timer(10.0).timeout.connect(func() -> void: _hud_help.visible = false)


## Põe o inimigo no começo da rota, olhando para o próximo ponto, com a rota dele.
func _place(e: Enemy, post: Dictionary) -> void:
	e.target = player
	e.position = post.pos
	var first: Vector3 = post.route[1] - post.pos
	e.rotation.y = atan2(-first.x, -first.z)
	for p in post.route:
		e.route.append(p)
	add_child(e)


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
	_hud_weapon = _label(layer, "PISTOLA", Vector2.ZERO)
	_hud_weapon.size.x = 64
	_hud_weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud_stealth = _label(layer, "", Vector2.ZERO)
	# aviso de tiro na cabeça, logo abaixo da mira
	_hud_headshot = _label(layer, "HEADSHOT", Vector2.ZERO)
	_hud_headshot.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_hud_headshot.visible = false
	_prompt = _build_prompt(layer)
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
	# atordoada pelo rugido do alossauro: aviso piscando acima do centro
	_hud_daze = _label(layer, "ATORDOADA", Vector2.ZERO)
	_hud_daze.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_hud_daze.visible = false
	_end = _build_end(layer)
	add_child(layer)


## Tela de fim (o alossauro caiu): faixa escura no meio com "FIM", o tempo e os tiros, e como jogar de novo.
func _build_end(layer: CanvasLayer) -> Control:
	var box := Control.new()
	box.visible = false
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.72)
	box.add_child(band)
	var title := _label(box, "FIM", Vector2.ZERO)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.name = "Title"
	_end_stats = _label(box, "", Vector2.ZERO)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(box)
	return box


func show_end() -> void:
	ended = true
	_end_t = -1.0
	var t := int(_play_t)
	_end_stats.text = "O ALOSSAURO CAIU\nTEMPO %02d:%02d   TIROS %d   VIDA %d\n\nR PARA JOGAR DE NOVO" % [t / 60, t % 60, player.shots_fired, player.health]
	_end.visible = true


## Centraliza a tela de fim e o aviso de atordoada na área do HUD (320x240 ampliado, qualquer proporção).
func _layout_overlays(area: Vector2) -> void:
	_hud_daze.position = Vector2(roundf((area.x - _hud_daze.size.x) * 0.5), roundf(area.y * 0.32))
	var band: ColorRect = _end.get_child(0)
	band.position = Vector2(0, area.y * 0.5 - 40)
	band.size = Vector2(area.x, 80)
	var title: Label = _end.get_node("Title")
	title.position = Vector2(roundf((area.x - title.size.x) * 0.5), area.y * 0.5 - 38)
	_end_stats.position = Vector2(roundf((area.x - _end_stats.size.x) * 0.5), area.y * 0.5 - 6)


## Aviso de interação embaixo, no centro: triângulo verde (o botão do controle) + "PEGAR <arma> (E)".
func _build_prompt(layer: CanvasLayer) -> Control:
	var box := Control.new()
	var tri := Line2D.new()
	tri.points = PackedVector2Array([Vector2(6, 1), Vector2(11, 10), Vector2(1, 10), Vector2(6, 1)])
	tri.width = 1.5
	tri.default_color = Color(0.4, 1.0, 0.5)
	box.add_child(tri)
	_prompt_text = _label(box, "", Vector2(15, 0))
	box.visible = false
	layer.add_child(box)
	_set_prompt(box, "M16")
	return box


func _set_prompt(box: Control, weapon_name: String) -> void:
	var text := "PEGAR %s (E)" % weapon_name
	if _prompt_text.text == text:
		return
	_prompt_text.text = text
	var font := _prompt_text.get_theme_font("font")
	box.size = Vector2(15.0 + font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, 12.0)


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


## Furtividade embaixo à esquerda: o quanto ela aparece (barras) e o estado dos raptors (calmos, desconfiados, alertados).
func _update_stealth_hud(area: Vector2) -> void:
	var level := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		level = maxi(level, e.alert_level())
	var bars := clampi(roundi(player.visibility() * 5.0), 1, 5)
	var status: String = ["", "  DESCONFIADOS", "  ALERTA!"][level]
	_hud_stealth.text = "VISIVEL %s%s%s" % ["#".repeat(bars), ".".repeat(5 - bars), status]
	_hud_stealth.add_theme_color_override("font_color", [Color(0.85, 0.9, 0.8), Color(1.0, 0.85, 0.3), Color(1.0, 0.3, 0.25)][level])
	_hud_stealth.position = Vector2(6, area.y - 14)


func reset_all() -> void:
	player.respawn()
	for c in chests:
		c.reset()
	Fx.clear_decals()
	Blood.clear()
	for d in dummies:
		d.reset()
	for r in raptors:
		r.reset()
	for sd in soldiers:
		sd.reset()
	allosaurus.reset()
	ended = false
	_end_t = -1.0
	_end.visible = false
	_play_t = 0.0
	player.shots_fired = 0


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
		elif a.begins_with("--pitch="):
			_pitch = deg_to_rad(float(a.get_slice("=", 1)))
		elif a.begins_with("--pos=") and OS.is_debug_build():
			# ferramenta de revisão: começa em x,z (e olhando para `graus`, 0 = para -Z)
			var v := a.get_slice("=", 1).split(",")
			player.global_position = Vector3(float(v[0]), 0.0, float(v[1]))
			player.rotation.y = deg_to_rad(float(v[2])) if v.size() > 2 else 0.0
			player.camera_rig.yaw = player.rotation.y
			player.reset_physics_interpolation()
	if _capture == "":
		return
	_hud_help.visible = _shot == "idle"
	if _shot.begins_with("soldier"):
		_setup_soldier_shot()
	else:
		# nas outras capturas os guardas do galpão ficam parados (senão atiram na jogadora)
		for sd in soldiers:
			sd.process_mode = Node.PROCESS_MODE_DISABLED
	if _shot.begins_with("raptor_"):
		_setup_raptor_shot()
	elif _shot.begins_with("allo_"):
		_setup_allo_shot()
	elif _shot == "arena":
		# da entrada da pedreira (logo depois do portão), olhando para dentro
		if not "--pos=" in " ".join(OS.get_cmdline_user_args()):
			player.global_position = Vector3(-60, 0, -3)
			player.rotation.y = PI * 0.5
			player.reset_physics_interpolation()
		player.camera_rig.yaw = player.rotation.y
		allosaurus.process_mode = Node.PROCESS_MODE_DISABLED
		for r in raptors:
			r.process_mode = Node.PROCESS_MODE_DISABLED
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
	if _shot in MOVE_SHOTS:
		_setup_move_shot()


func _process(delta: float) -> void:
	_crosshair.visible = player.aiming and player.model.is_aimed()
	var target := player.pick_target()
	_prompt.visible = target != null
	if target:
		_set_prompt(_prompt, Player.WEAPON_STATS[target.item].name)
	_hud_weapon.text = Player.WEAPON_STATS[player.weapon()].name
	# HUD ampliado (apply_gfx): arma no canto de cima à direita e aviso embaixo no centro, em qualquer proporção
	var area := get_viewport().get_visible_rect().size / _hud.scale
	_hud_weapon.position = Vector2(area.x - _hud_weapon.size.x - 6, 4)
	_update_stealth_hud(area)
	_headshot_t = maxf(_headshot_t - delta, 0.0)
	_hud_headshot.visible = _headshot_t > 0.0
	_hud_headshot.position = Vector2(roundf((area.x - _hud_headshot.size.x) * 0.5), roundf(area.y * 0.5) + 10)
	_prompt.position = Vector2(roundf((area.x - _prompt.size.x) * 0.5), area.y - 34)
	# atordoada: o aviso pisca enquanto dura
	_hud_daze.visible = player.is_dazed() and fmod(_play_t, 0.5) < 0.32
	_layout_overlays(area)
	if not ended:
		_play_t += delta
	if _end_t > 0.0:
		_end_t -= delta
		if _end_t <= 0.0:
			show_end()
	if _capture == "":
		return
	var prev := _t
	_t += delta
	var at := func(sec: float) -> bool: return prev < sec and _t >= sec
	if not is_nan(_yaw) and (_shot != "ragdoll" or _t > 2.3):
		# ângulo fixo de câmera relativo à frente dela (0 = atrás, 180 = de frente)
		player.camera_rig.yaw = player.rotation.y + _yaw
		player.camera_rig.pitch = _pitch
	if _review_cam and _shot == "face":
		var a := player.rotation.y + PI + (0.0 if is_nan(_yaw) else _yaw)
		var head := player.global_position + Vector3.UP * 1.6
		_review_cam.global_position = head + Vector3(sin(a), 0.03, cos(a)) * 0.75
		_review_cam.look_at(head)
	elif _review_cam and _shot.begins_with("raptor_"):
		_raptor_shot(at)
	elif _shot.begins_with("allo_"):
		_allo_shot(at)
	if _shot.begins_with("soldier"):
		_soldier_shot(at)
	if _shot in MOVE_SHOTS:
		_move_shot(at)
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


## Revisão dos movimentos novos: põe a jogadora na frente do obstáculo/baú e aperta os botões na hora certa.
func _setup_move_shot() -> void:
	for d in dummies:
		d.visible = false
	var spots := {
		"hang": [Vector3(-2.5, 0, -0.35), 0.0], "climb": [Vector3(-2.5, 0, -0.35), 0.0],
		"mantle": [Vector3(0, 0, -9.95), 0.0], "pickup": [chest.kneel_transform().origin + chest.global_basis.z * 0.5, chest.rotation.y],
		"pickup_shotgun": [chests[1].kneel_transform().origin + chests[1].global_basis.z * 0.5, chests[1].rotation.y],
		# de frente para a pilha de caixas de madeira, com a coluna de metal à esquerda
		"fire_pistol": [Vector3(-2.4, 0, 1.6), 0.0], "fire_m16": [Vector3(-2.4, 0, 1.6), 0.0],
		"fire_shotgun": [Vector3(-2.4, 0, 1.6), 0.0], "pump": [Vector3(-2.4, 0, 1.6), 0.0],
	}
	if _shot in spots:
		player.global_position = spots[_shot][0]
		player.rotation.y = spots[_shot][1]
		player.reset_physics_interpolation()
		player.camera_rig.yaw = player.rotation.y
	if _shot.begins_with("rifle") or _shot == "fire_m16":
		player.give_weapon("m16")
	if _shot.begins_with("shotgun") or _shot in ["fire_shotgun", "pump"]:
		player.give_weapon("shotgun")
	if _shot == "pump":
		# de lado, perto das mãos, para ver a telha indo e voltando
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 40.0
		add_child(_review_cam)
		_review_cam.current = true


func _move_shot(at: Callable) -> void:
	var tap := func(action: String, sec: float) -> void:
		if at.call(sec):
			Input.action_press(action)
		if at.call(sec + 0.05):
			Input.action_release(action)
	match _shot:
		"walk":
			Input.action_press("walk")
			Input.action_press("move_forward")
		"crouch_walk", "crouch_aim":
			tap.call("crouch", 0.05)
			if _t > 0.3:
				Input.action_press("move_forward" if _shot == "crouch_walk" else "move_left")
			if _shot == "crouch_aim":
				Input.action_press("aim")
		"jump", "hang", "mantle":
			tap.call("jump", 0.4)
		"climb":
			tap.call("jump", 0.4)
			tap.call("jump", 1.2)
		"pickup", "pickup_shotgun":
			tap.call("interact", 0.3)
		"rifle_aim", "shotgun_aim":
			Input.action_press("aim")
		"fire_pistol", "fire_m16", "fire_shotgun", "pump":
			Input.action_press("aim")
			var gap: float = {"fire_pistol": 0.3, "fire_m16": 0.12, "fire_shotgun": 0.85, "pump": 9.0}[_shot]
			var n: int = {"fire_pistol": 6, "fire_m16": 12, "fire_shotgun": 3, "pump": 1}[_shot]
			if _t < 0.6 + gap * n:
				# pistola: tiros espalhados pela caixa (a mira anda antes do próximo); os outros, no mesmo ponto
				# (a dispersão é da arma)
				var spread := (player.shots_fired - 2.5) * 0.05 if _shot == "fire_pistol" else 0.0
				# mira na face da caixa de baixo da pilha
				player.camera_rig.look_at_point(Vector3(-2.5, 0.7, -0.9))
				player.camera_rig.yaw += spread + (0.0 if is_nan(_yaw) else _yaw)
			for k in n:
				if at.call(0.6 + k * gap):
					player.fire()
			if _shot == "pump":
				var right := player.global_basis.x
				var hands := player.global_position + Vector3.UP * 1.35 - player.global_basis.z * 0.35
				_review_cam.global_position = hands + right * 1.1 + Vector3.UP * 0.1 - player.global_basis.z * 0.2
				_review_cam.look_at(hands)


## Revisão do soldado: de frente para ela, a 4 m (soldier = ele a vê e atira; soldier_dead = leva um tiro e cai;
## soldier_headshot = ela acerta a cabeça dele; soldier_wounded = ferido, luta e deixa rastro de sangue).
func _setup_soldier_shot() -> void:
	for d in dummies:
		d.visible = false
	var sd := soldiers[0]
	sd.route.clear()
	for other in soldiers.slice(1):
		other.process_mode = Node.PROCESS_MODE_DISABLED
	sd.global_position = player.global_position + Vector3(0, 0, -4.0)
	sd.rotation.y = PI
	sd.reset_physics_interpolation()
	# câmera de revisão perto dele (--yaw gira em volta: 0 = de frente); --playercam usa a dela
	if not _player_cam:
		_review_cam = Camera3D.new()
		_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_review_cam.fov = 45.0
		add_child(_review_cam)
		_review_cam.current = true


func _soldier_shot(at: Callable) -> void:
	var sd := soldiers[0]
	if _shot == "soldier_headshot":
		if at.call(0.1):
			Input.action_press("aim")
		if _t < 0.6 and not sd.dead:
			player.camera_rig.look_at_point(sd.model.ragdoll.bodies["Head"].global_position)
		if at.call(0.6):
			player.fire()
	elif at.call(0.1):
		if _shot == "soldier_dead":
			sd.take_hit(999, Vector3.BACK, sd.global_position + Vector3.UP)
		elif _shot == "soldier_wounded":
			player.health = 1000  # só para a revisão: ela aguenta os tiros dele enquanto ele anda sangrando
			sd.take_hit(45, Vector3.BACK, sd.global_position + Vector3.UP * 1.2)
		else:
			sd.spot()
	if _review_cam:
		var body: Vector3 = sd.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if sd.dead else sd.global_position
		var a := sd.rotation.y + PI + (deg_to_rad(25.0) if is_nan(_yaw) else _yaw)
		_review_cam.global_position = body + Vector3(sin(a), 0.0, cos(a)) * (2.6 if not sd.dead else 2.2) + Vector3.UP * 1.45
		_review_cam.look_at(body + Vector3.UP * (1.05 if not sd.dead else 0.2))


## Revisão do raptor: posiciona os dois, liga uma câmera própria e força o estado pedido.
func _setup_raptor_shot() -> void:
	var r := raptors[0]
	for d in dummies:
		d.visible = false
	# só este raptor entra na cena de revisão, parado no lugar (sem patrulha)
	r.route.clear()
	for other in raptors.slice(1):
		other.process_mode = Node.PROCESS_MODE_DISABLED
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
			"raptor_blood": Input.action_press("aim")
	if _shot == "raptor_blood":
		# tiros de pistola no tronco até cair (esguicho, respingos, poça)
		if not r.dead and _t < 3.5:
			player.camera_rig.look_at_point(r.model.ragdoll.bodies["Chest"].global_position)
		for k in 5:
			if at.call(0.7 + k * 0.35) and not r.dead:
				player.fire()
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


## Revisão do alossauro: no meio da pedreira, ele olhando para +X, ela à frente na distância de cada golpe.
func _setup_allo_shot() -> void:
	var a := allosaurus
	a.route.clear()
	for r in raptors:
		r.process_mode = Node.PROCESS_MODE_DISABLED
	a.global_position = Vector3(-80, 0, -3)
	a.rotation.y = -PI * 0.5
	var fwd := Vector3.RIGHT
	var left := Vector3.FORWARD  # olhando para +X, a esquerda dele é -Z
	var her := {
		"stomp": fwd * 2.6, "bite": fwd * 4.2, "roar": fwd * 9.0, "roar_at": fwd * 7.0, "idle": fwd * 14.0,
		"headbutt": fwd * 2.2 + left * 2.2, "tail": -fwd * 4.5 + left * 1.5, "dead": fwd * 8.0, "end": fwd * 8.0,
	}
	player.global_position = a.global_position + her.get(_shot.trim_prefix("allo_"), fwd * 8.0)
	player.rotation.y = PI * 0.5
	player.reset_physics_interpolation()
	a.reset_physics_interpolation()
	player.camera_rig.yaw = 0.0
	_review_cam = Camera3D.new()
	_review_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_review_cam.fov = 55.0
	add_child(_review_cam)
	_review_cam.current = not _player_cam


func _allo_shot(at: Callable) -> void:
	var a := allosaurus
	if at.call(0.15):
		match _shot:
			"allo_roar": a.start_roar()
			"allo_roar_at": a.start_roar_at()
			"allo_headbutt": a.start_headbutt()
			"allo_tail": a.start_tail()
			"allo_stomp": a.start_stomp()
			"allo_bite": a.start_bite()
			"allo_dead", "allo_end": a.take_hit(9999, Vector3.FORWARD, a.global_position + Vector3.UP * 2.5)
	if _shot == "allo_end" and at.call(0.2):
		_end_t = 0.3  # na revisão a tela de fim não espera o corpo cair
	if _player_cam:
		player.camera_rig.yaw = player.rotation.y + (0.6 if is_nan(_yaw) else _yaw)
		return
	var vp := get_viewport().get_visible_rect().size
	_review_cam.keep_aspect = Camera3D.KEEP_WIDTH if vp.y > vp.x else Camera3D.KEEP_HEIGHT
	var her := player.camera_focus()
	var him: Vector3 = a.model.ragdoll.bodies["Hips"].global_position * Vector3(1, 0, 1) if a.dead else a.global_position - a.global_basis.z * 1.2
	var mid := him.lerp(her, 0.4)
	var dist := 8.0 + 0.4 * him.distance_to(her)
	var yaw := deg_to_rad(155.0) if is_nan(_yaw) else _yaw
	_review_cam.global_position = mid + Vector3(sin(yaw), 0.0, cos(yaw)) * dist + Vector3.UP * 2.6
	_review_cam.look_at(mid + Vector3.UP * 1.6)


func _save_and_quit() -> void:
	if _saving:
		return
	_saving = true
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_capture)
	print("captura salva: ", _capture, " ", img.get_size(), " yaw_cam=", player.camera_rig.yaw, " yaw_player=", player.rotation.y, " estado=", player.model.state, " raptor=", raptors[0].state if raptors else "-", " buracos=", Fx.decal_count())
	get_tree().quit()
