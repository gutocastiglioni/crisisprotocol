class_name Inspect
extends Node
## Telas de "jogo de sobrevivência" que param o jogo (árvore pausada; este nó roda mesmo assim):
##   - `lock_zoom`: a câmera sai de onde a dela está e chega perto do cadeado do baú trancado; sem a chave ele chacoalha e
##     aparece o aviso "TRANCADO / precisa de uma chave"; com a chave ele abre e cai. Volta para a câmera dela no fim;
##   - `show_item` / `show_drop`: fundo escurecido com o item pego (chave, cartão; a pistola com silenciador da caixa de
##     paraquedas) girando no meio (numa SubViewport com mundo próprio), o nome e a descrição;
##   - `show_message`: só o texto na faixa de baixo, com o jogo congelado atrás (o cheiro de sangue na beira do telhado).
## Todas esperam ela apertar confirmar (E / X / atirar / pular) depois de MIN_SHOW s. Enquanto isso o HUD do jogo some.
## Captura e testes: `auto_close` (s) fecha sozinho e `on_shown` é chamado quando a tela termina de aparecer.

signal closed

const MIN_SHOW := 0.5  # s antes de aceitar o botão (o mesmo E que abriu não fecha)
const ZOOM_IN := 0.55
const ZOOM_OUT := 0.35
const LOCK_FOV := 38.0
const CONFIRM := ["interact", "shoot", "roll", "jump", "ui_accept"]
const TEXT := Color(0.9, 0.92, 0.85)
const TITLE := Color(1.0, 0.85, 0.3)
const VIEW := Vector2(150, 96)  # tamanho do item na tela (unidades do HUD de 320x240)
const PLATE_FOV := 40.0
const KEYPAD_FOV := 34.0
const CODE_LEN := 4
const KEYPAD_OK := ["interact", "ui_accept"]
const KEYPAD_EXIT := ["crouch", "ui_cancel"]
const WRONG_TIME := 0.9  # s com o "CODIGO INCORRETO" antes de zerar

var player: Player
var hud: CanvasLayer  # HUD do jogo, escondido enquanto a tela está aberta
var busy := false
var auto_close := -1.0
var on_shown := Callable()
var auto_code := ""  # testes e captura: digita este código sozinho quando o painel acende (e confirma)
var code_tries := 0  # códigos confirmados na última tela do teclado
var layer: CanvasLayer
var _cam: Camera3D
var _band: ColorRect
var _title: Label
var _body: Label
var _ok: Label
var _shade: ColorRect
var _view: SubViewportContainer
var _pivot: Node3D
var _elapsed := 0.0
var _code_pad: ColorRect
var _code: Label
var _digits: Array[int] = []
var _cursor := 0
var _typing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cam = Camera3D.new()
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_cam.near = 0.02
	_cam.far = 80.0
	add_child(_cam)
	layer = CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_shade = ColorRect.new()
	_shade.color = Color(0, 0, 0, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_shade)
	_view = _build_view()
	layer.add_child(_view)
	_band = ColorRect.new()
	_band.color = Color(0, 0, 0, 0.72)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_band)
	_title = _label(TITLE)
	_body = _label(TEXT)
	_ok = _label(Color(0.4, 1.0, 0.5))
	_ok.text = "OK (E)"
	_code_pad = ColorRect.new()
	_code_pad.color = Color(0.02, 0.06, 0.03, 0.9)
	_code_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_code_pad)
	_code = _label(Color(0.4, 1.0, 0.5))
	_code.add_theme_font_size_override("font_size", 16)
	_hide_all()


func _label(color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(l)
	return l


## Item girando num mundo à parte (fundo transparente, luz própria): pixelado como o resto do HUD.
func _build_view() -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size = VIEW
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	box.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.6
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 200, 0)
	fill.light_energy = 0.6
	fill.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 0.03, 0.3)
	cam.current = true
	vp.add_child(cam)
	_pivot = Node3D.new()
	vp.add_child(_pivot)
	return box


func _hide_all() -> void:
	for c in [_shade, _view, _band, _title, _body, _ok, _code_pad, _code]:
		c.visible = false


## Escala do HUD (main.apply_gfx): as telas foram feitas para 320x240 como ele.
func set_ui_scale(k: float) -> void:
	layer.scale = Vector2(k, k)


func _area() -> Vector2:
	return get_viewport().get_visible_rect().size / layer.scale


func _process(delta: float) -> void:
	_elapsed += delta
	if _view.visible:
		_pivot.rotation.y += delta * 1.4
	var area := _area()
	_shade.size = area
	_band.position = Vector2(8, area.y - 70)
	_band.size = Vector2(area.x - 16, 62)
	_view.position = Vector2(roundf((area.x - VIEW.x) * 0.5), roundf(area.y * 0.5 - VIEW.y * 0.5 - 30))
	for l: Label in [_title, _body, _ok]:
		l.size.x = area.x - 24
		l.position.x = 12
	_title.position.y = area.y - 66
	_body.position.y = area.y - 54
	_ok.position.y = area.y - 19
	_code.size.x = area.x - 24
	_code.position = Vector2(12, roundf(area.y * 0.5) - 40)
	_code_pad.size = Vector2(120, 30)
	_code_pad.position = Vector2(roundf((area.x - 120.0) * 0.5), roundf(area.y * 0.5) - 44)


func _open() -> void:
	busy = true
	_elapsed = 0.0
	get_tree().paused = true
	if hud:
		hud.visible = false


func _close() -> void:
	_hide_all()
	get_tree().paused = false
	if hud:
		hud.visible = true
	busy = false
	closed.emit()


func _text(title: String, body: String) -> void:
	_title.text = title
	_body.text = body
	for c in [_band, _title, _body]:
		c.visible = true
	_ok.visible = false


## Espera o botão de confirmar (ou `auto_close`), depois de MIN_SHOW s com a tela pronta.
func _wait_confirm() -> void:
	_elapsed = 0.0
	var shown := false
	while true:
		await get_tree().process_frame
		if _elapsed >= MIN_SHOW:
			_ok.visible = true
			if not shown:
				shown = true
				if on_shown.is_valid():
					on_shown.call()
			if auto_close >= 0.0 and _elapsed >= MIN_SHOW + auto_close:
				return
			for a in CONFIRM:
				if InputMap.has_action(a) and Input.is_action_just_pressed(a):
					return


func _fly(from: Transform3D, to: Transform3D, fov0: float, fov1: float, time: float) -> void:
	var qa := from.basis.get_rotation_quaternion()
	var qb := to.basis.get_rotation_quaternion()
	var step := func(t: float) -> void:
		var k := t * t * (3.0 - 2.0 * t)
		_cam.global_transform = Transform3D(Basis(qa.slerp(qb, k)), from.origin.lerp(to.origin, k))
		_cam.fov = lerpf(fov0, fov1, k)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, time)
	await tw.finished


## Ela tentou abrir o baú trancado: zoom no cadeado. `has_key` = está com a chave (o cadeado abre e cai).
func lock_zoom(chest: Chest, has_key: bool) -> void:
	if busy:
		return
	_open()
	await _zoom_to(chest.lock_view(), LOCK_FOV)
	if has_key:
		Sfx.ui(self, "unlock")
		var t := chest.unlock()
		await get_tree().create_timer(t, true).timeout  # o aviso só depois de o cadeado cair
		_text("USOU A CHAVE DO CONTAINER", "O cadeado abriu.")
	else:
		Sfx.ui(self, "lock_rattle")
		chest.rattle()
		_text("ESTA TRANCADO", "Um cadeado grosso prende a tampa.\nPrecisa de uma chave.")
	await _wait_confirm()
	await _zoom_back()


## A câmera sai de onde a dela está e chega em `view` (com o `fov`).
func _zoom_to(view: Transform3D, fov: float) -> void:
	var eye := player.camera_rig.camera
	_cam.global_transform = eye.global_transform
	_cam.fov = eye.fov
	_cam.current = true
	await _fly(eye.global_transform, view, eye.fov, fov, ZOOM_IN)


## Some com os textos, volta para a câmera dela e fecha a tela.
func _zoom_back() -> void:
	var eye := player.camera_rig.camera
	_hide_all()
	await _fly(_cam.global_transform, eye.global_transform, _cam.fov, eye.fov, ZOOM_OUT)
	_cam.current = false
	eye.current = true
	_close()


## Plaqueta de um tubo de perto: número, espécie e estado.
func plate_zoom(plate: SubjectPlate) -> void:
	if busy:
		return
	_open()
	await _zoom_to(plate.view(), PLATE_FOV)
	_text(plate.title(), plate.body())
	await _wait_confirm()
	await _zoom_back()


## Teclado de uma porta trancada por código. `has_key` = ela tem a chave que liga o painel. Devolve true se digitou o
## código certo (quem chamou gasta a chave e destranca).
func keypad(door: Door, has_key: bool) -> bool:
	if busy:
		return false
	_open()
	code_tries = 0
	await _zoom_to(door.keypad_view(), KEYPAD_FOV)
	var ok := false
	if not has_key:
		Sfx.ui(self, "lock_rattle")
		_text("PAINEL DESLIGADO", "O teclado tem uma fechadura do lado.\nPrecisa de uma chave para ligar.")
		await _wait_confirm()
	else:
		Sfx.ui(self, "keypad_beep")
		door.keypad_power(true)
		ok = await _enter_code(door.code)
		if ok:
			_text("CODIGO ACEITO", "O portao destrancou.")
			await _wait_confirm()
		else:
			door.keypad_power(false)
	await _zoom_back()
	return ok


## Ela digita até acertar `code` (true) ou sair (false).
func _enter_code(code: String) -> bool:
	_digits.clear()
	_digits.resize(CODE_LEN)
	_digits.fill(0)
	_cursor = 0
	_text("DIGITE O CODIGO", "0-9 ou setas: escolher   E: confirmar   C: sair")
	_code_pad.visible = true
	_code.visible = true
	_show_code(Color(0.4, 1.0, 0.5))
	_elapsed = 0.0
	_typing = true
	var wrong_t := -1.0
	var shown := false
	while true:
		await get_tree().process_frame
		if wrong_t >= 0.0:
			if _elapsed < wrong_t:
				continue
			wrong_t = -1.0
			_digits.fill(0)
			_cursor = 0
			_text("DIGITE O CODIGO", "0-9 ou setas: escolher   E: confirmar   C: sair")
			_show_code(Color(0.4, 1.0, 0.5))
		if _elapsed < MIN_SHOW:
			continue
		if not shown:
			shown = true
			if on_shown.is_valid() and auto_code == "":
				on_shown.call()
		var submit := false
		if auto_code != "":
			for i in CODE_LEN:
				_digits[i] = int(auto_code[i]) if i < auto_code.length() else 0
			submit = true
		if _just(KEYPAD_EXIT):
			_typing = false
			return false
		var step := int(_just(["move_right"])) - int(_just(["move_left"]))
		var turn := int(_just(["move_forward"])) - int(_just(["move_back"]))
		if step != 0:
			_cursor = clampi(_cursor + step, 0, CODE_LEN - 1)
			Sfx.ui(self, "keypad_beep")
		if turn != 0:
			_digits[_cursor] = posmod(_digits[_cursor] + turn, 10)
			Sfx.ui(self, "keypad_beep")
		if step != 0 or turn != 0:
			_show_code(Color(0.4, 1.0, 0.5))
		if _just(KEYPAD_OK):
			submit = true
		if not submit:
			continue
		code_tries += 1
		if _entered() == code:
			_typing = false
			Sfx.ui(self, "keypad_ok")
			_cursor = -1  # sem a casa marcada: acabou de digitar
			_show_code(Color(0.6, 1.0, 1.0))
			return true
		Sfx.ui(self, "keypad_error")
		_text("CODIGO INCORRETO", "")
		_show_code(Color(1.0, 0.3, 0.25))
		wrong_t = _elapsed + WRONG_TIME
		if auto_code != "":
			auto_code = ""  # o automático só tenta uma vez; depois sai sozinho (testes)
			_typing = false
			await get_tree().create_timer(WRONG_TIME, true).timeout
			return false
	return false


## Algarismo do teclado de cima ou do numérico: vai na casa marcada e passa para a próxima.
func _input(event: InputEvent) -> void:
	if not _typing or _elapsed < MIN_SHOW or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	var d := -1
	if k >= KEY_0 and k <= KEY_9:
		d = k - KEY_0
	elif k >= KEY_KP_0 and k <= KEY_KP_9:
		d = k - KEY_KP_0
	if d < 0:
		return
	_digits[_cursor] = d
	_cursor = mini(_cursor + 1, CODE_LEN - 1)
	Sfx.ui(self, "keypad_beep")
	_show_code(Color(0.4, 1.0, 0.5))
	get_viewport().set_input_as_handled()


func _just(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _entered() -> String:
	var s := ""
	for d in _digits:
		s += str(d)
	return s


## O código no visor do meio da tela, com a casa marcada entre colchetes.
func _show_code(color: Color) -> void:
	var s := ""
	for i in CODE_LEN:
		s += ("[%d]" if i == _cursor else " %d ") % _digits[i]
	_code.text = s
	_code.add_theme_color_override("font_color", color)


## Pegou um item: ele aparece girando no meio da tela com o nome e a descrição.
func show_item(item: KeyItem) -> void:
	if busy:
		return
	_open()
	for c in _pivot.get_children():
		c.queue_free()
	var model := KeyItem.build_model(_pivot, item.kind)
	if item.kind == "keycard":
		model.rotation = Vector3(PI * 0.5, 0.0, 0.0)  # em pé como a chave; deitado, girando, só aparecia a quina
		model.scale = Vector3.ONE * 1.7
		model.position = Vector3(0.0, 0.03, 0.0)  # na altura da câmera: em pé, no 2,0 de antes cortava embaixo
	else:
		model.rotation = Vector3(PI * 0.5, 0.0, 0.0)  # em pé, de frente para a câmera
		model.scale = Vector3.ONE * 2.2
		model.position.x = 0.02
	await _present(item.display_name, item.description)


## Abriu a caixa de paraquedas: a pistola com silenciador aparece girando, de lado, com o nome e a descrição.
func show_drop(drop: SupplyDrop) -> void:
	if busy:
		return
	_open()
	for c in _pivot.get_children():
		c.queue_free()
	var model := SupplyDrop.build_item(_pivot)
	model.scale = Vector3.ONE * 0.62
	await _present(drop.NAME, drop.DESCRIPTION)


## Mensagem de jogo antigo (RE/Dino Crisis): o jogo para, o texto aparece na faixa de baixo e sai ao confirmar.
func show_message(body: String) -> void:
	if busy:
		return
	_open()
	_text("", body)
	await _wait_confirm()
	_close()


## Item pronto no `_pivot`: mostra girando com o título e o texto e espera confirmar.
func _present(title: String, body: String) -> void:
	_pivot.rotation = Vector3(0.0, -0.6, 0.0)
	_shade.visible = true
	_view.visible = true
	Sfx.ui(self, "item_get")
	_text("PEGOU: " + title, body)
	await _wait_confirm()
	_close()
