class_name Inspect
extends Node
## Telas de "jogo de sobrevivência" que param o jogo (árvore pausada; este nó roda mesmo assim):
##   - `lock_zoom`: a câmera sai de onde a dela está e chega perto do cadeado do baú trancado; sem a chave ele chacoalha e
##     aparece o aviso "TRANCADO / precisa de uma chave"; com a chave ele abre e cai. Volta para a câmera dela no fim;
##   - `show_item`: fundo escurecido com o item pego girando no meio (numa SubViewport com mundo próprio), o nome e a
##     descrição.
## As duas esperam ela apertar confirmar (E / X / atirar / pular) depois de MIN_SHOW s. Enquanto isso o HUD do jogo some.
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

var player: Player
var hud: CanvasLayer  # HUD do jogo, escondido enquanto a tela está aberta
var busy := false
var auto_close := -1.0
var on_shown := Callable()
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
	for c in [_shade, _view, _band, _title, _body, _ok]:
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
	var eye := player.camera_rig.camera
	var from := eye.global_transform
	_cam.global_transform = from
	_cam.fov = eye.fov
	_cam.current = true
	await _fly(from, chest.lock_view(), eye.fov, LOCK_FOV, ZOOM_IN)
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
	_hide_all()
	await _fly(_cam.global_transform, eye.global_transform, _cam.fov, eye.fov, ZOOM_OUT)
	_cam.current = false
	eye.current = true
	_close()


## Pegou um item: ele aparece girando no meio da tela com o nome e a descrição.
func show_item(item: KeyItem) -> void:
	if busy:
		return
	_open()
	for c in _pivot.get_children():
		c.queue_free()
	var model := KeyItem.build_model(_pivot)
	model.rotation = Vector3(PI * 0.5, 0.0, 0.0)  # em pé, de frente para a câmera
	model.scale = Vector3.ONE * 2.2
	model.position.x = 0.02
	_pivot.rotation = Vector3(0.0, -0.6, 0.0)
	_shade.visible = true
	_view.visible = true
	Sfx.ui(self, "item_get")
	_text("PEGOU: " + item.display_name, item.description)
	await _wait_confirm()
	_close()
