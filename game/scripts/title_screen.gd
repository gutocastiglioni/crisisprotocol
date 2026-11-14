class_name TitleScreen
extends Node
## Tela de título (menu inicial), por cima do telhado do começo da fase com o jogo pausado: JOGAR (a fase, do telhado) /
## TUTORIAL (a pista de treino, `Tutorial`) / CONTROLES (`ControlsScreen`) / OPÇÕES (`OptionsScreen`: tela cheia, volume,
## vibração; as duas são as do menu de pausa e voltar delas devolve o título) / SAIR DO JOGO.
## Aparece ao abrir o jogo (não nas capturas nem nos testes) e pelo MENU INICIAL do menu de pausa; quem decide o que cada
## opção faz é o `main` (sinais). Cima/baixo escolhe, E / X / ENTER confirma; o mouse também escolhe e clica.

signal chosen(item: String)

const ITEMS := ["JOGAR", "TUTORIAL", "CONTROLES", "OPÇÕES", "SAIR DO JOGO"]
const UP := ["move_forward", "ui_up"]
const DOWN := ["move_back", "ui_down"]
const CONFIRM := ["interact", "crouch", "ui_accept", "jump"]
const NAME := "CRISIS PROTOCOL"
const ROW := 15.0
const HINT_ITEMS := [{"keys": ["SETAS"], "pad": "dpad", "text": "ESCOLHER"}, {"action": "interact", "pad_action": "crouch", "text": "CONFIRMAR"}]

var is_open := false
var selected := 0
var on_shown := Callable()
var controls: ControlsScreen
var options: OptionsScreen
var layer: CanvasLayer
var _shade: ColorRect
var _band: ColorRect
var _title: Label
var _tag: Label
var _hint: UiStyle.Hint
var _rows: Array[Label] = []
var _opened_frame := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_shade = UiStyle.rect(layer, UiStyle.SHADE)
	_band = UiStyle.rect(layer, UiStyle.BAND)
	_title = UiStyle.label(layer, NAME, UiStyle.ACCENT, UiStyle.L, HORIZONTAL_ALIGNMENT_CENTER)
	_tag = UiStyle.label(layer, "", UiStyle.MUTED, UiStyle.S, HORIZONTAL_ALIGNMENT_CENTER)
	_hint = UiStyle.Hint.new()
	layer.add_child(_hint)
	_hint.set_items(HINT_ITEMS)
	for i in ITEMS.size():
		var l := UiStyle.label(layer, ITEMS[i], UiStyle.INK, UiStyle.M, HORIZONTAL_ALIGNMENT_CENTER)
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_select.bind(i))
		l.gui_input.connect(_on_row_input.bind(i))
		_rows.append(l)
	if controls:
		controls.closed.connect(_on_controls_closed)
	if options:
		options.closed.connect(_on_controls_closed)
	_set_visible(false)


func set_ui_scale(k: float) -> void:
	layer.scale = Vector2(k, k)


func _set_visible(v: bool) -> void:
	for c: CanvasItem in [_shade, _band, _title, _tag, _hint]:
		c.visible = v
	for l in _rows:
		l.visible = v


func open() -> void:
	if is_open:
		return
	is_open = true
	_opened_frame = Engine.get_process_frames()
	get_tree().paused = true
	Rumble.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_tag.text = "MODO: " + ("SOBREVIVÊNCIA" if GameMode.is_survival() else "ARCADE")
	_select(0, false)
	_layout()
	_set_visible(true)
	if on_shown.is_valid():
		on_shown.call()


## Some e devolve o jogo (dois passos de física depois: o botão que confirmou não chega nela).
func close() -> void:
	if not is_open:
		return
	is_open = false
	_set_visible(false)
	for a in CONFIRM + ["roll", "pause"]:
		if InputMap.has_action(a):
			Input.action_release(a)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 2:
		await get_tree().physics_frame
	if not is_open:
		get_tree().paused = false


func _select(i: int, beep := true) -> void:
	if beep and i != selected:
		Sfx.ui(self, "keypad_beep")
	selected = i
	for k in _rows.size():
		_rows[k].text = ("> %s <" if k == selected else "%s") % ITEMS[k]
		_rows[k].add_theme_color_override("font_color", UiStyle.ACCENT if k == selected else UiStyle.INK)


func _on_row_input(e: InputEvent, i: int) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_select(i)
		choose()


## Confirma a opção escolhida. CONTROLES e OPÇÕES abrem a tela por cima (o título volta quando ela fecha); as outras fecham o título
## e o `main` faz o resto pelo sinal.
func choose() -> void:
	if not is_open:
		return
	Sfx.ui(self, "keypad_ok")
	var item: String = ITEMS[selected]
	if item == "CONTROLES" and controls:
		_set_visible(false)
		controls.open()
		return
	if item == "OPÇÕES" and options:
		_set_visible(false)
		options.open()
		return
	if item != "SAIR DO JOGO":
		close()
	chosen.emit(item)


func _on_controls_closed() -> void:
	if not is_open:
		return
	_opened_frame = Engine.get_process_frames()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layout()
	_set_visible(true)


func _process(_delta: float) -> void:
	if not is_open or (controls and controls.is_open) or (options and options.is_open):
		return
	_layout()
	if Engine.get_process_frames() == _opened_frame:
		return
	var step := int(_just(DOWN)) - int(_just(UP))
	if step != 0:
		_select(posmod(selected + step, ITEMS.size()))
	elif _just(CONFIRM):
		choose()


func _just(actions: Array) -> bool:
	for a in actions:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			return true
	return false


func _layout() -> void:
	var area := get_viewport().get_visible_rect().size / layer.scale
	_shade.size = area
	var h := 56.0 + ROW * ITEMS.size() + 22.0
	var top := roundf(area.y * 0.5 - h * 0.5)
	_band.position = Vector2(0, top)
	_band.size = Vector2(area.x, h)
	for l: Label in [_title, _tag] + _rows:
		l.position.x = 0
		l.size.x = area.x
	_title.position.y = top + 6
	_tag.position.y = top + 36
	for i in _rows.size():
		_rows[i].position.y = top + 56 + ROW * i
	_hint.position = Vector2(roundf((area.x - _hint.size.x) * 0.5), top + h - 16)
